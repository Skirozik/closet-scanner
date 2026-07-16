import Foundation
import simd

/// Turns a classified point cloud into Width × Depth × Height.
///
/// Accuracy hierarchy (best first):
///   • Width/Depth: perpendicular distance between two opposing fitted wall planes
///     (`plane-pair`). Averages every inlier on both walls → lowest random error.
///   • If a side is open (no opposing wall, common for closets with a doorway),
///     fall back to the robust extent of the floor along that axis (`floor-extent`).
///   • Height: distance between the fitted floor and ceiling planes (`wall-height`),
///     or the vertical extent of the walls if the ceiling wasn't captured.
///
/// The ± confidence is deliberately conservative: it combines the (tiny) statistical
/// standard error with a systematic scale-uncertainty term, because ARKit scale error —
/// not point noise — is the real limit. Fiducial calibration shrinks that term.
enum ClosetSolver {

    struct Config {
        var wallInlierThreshold = 0.012
        var floorInlierThreshold = 0.015
        var minWallInliers = 250
        var minFloorInliers = 400
        var systematicFloorMeters = 0.001     // ~1 mm irreducible bias floor
        var floorExtentExtraMeters = 0.004    // edge-based estimates are noisier
        var extentLowPercentile = 2.5
        var extentHighPercentile = 97.5
    }

    struct Solution {
        var dimensions: ClosetDimensions
        var wallPlanes: [Plane]
        var floor: Plane?
        var ceiling: Plane?
        var centroid: SIMD3<Double>
        var axisA: SIMD3<Double>
        var axisB: SIMD3<Double>
    }

    static let up = SIMD3<Double>(0, 1, 0)

    static func solve(cloud: ClassifiedCloud,
                      calibration: ScaleCalibration = .uncalibrated,
                      config: Config = Config()) -> Solution? {

        // --- Floor & ceiling ---------------------------------------------------
        let floorFit = PlaneFitter.ransacFit(points: cloud.floor,
                                             inlierThreshold: config.floorInlierThreshold)?
                                             .orientedUp()
        let ceilingFit = PlaneFitter.ransacFit(points: cloud.ceiling,
                                               inlierThreshold: config.floorInlierThreshold)?
                                               .orientedUp()

        // --- Walls: iterative RANSAC, removing inliers each round --------------
        var remaining = cloud.wall
        var wallFits: [PlaneFitter.Fit] = []
        for sweep in 0..<4 {
            guard let fit = PlaneFitter.ransacFit(points: remaining,
                                                  inlierThreshold: config.wallInlierThreshold,
                                                  seed: 0xC10_5E7 &+ UInt64(sweep)),
                  fit.inlierCount >= config.minWallInliers,
                  fit.plane.verticality > 0.7          // keep only vertical (wall-like) planes
            else { break }
            wallFits.append(fit)
            let used = Set(fit.inliers.map { hashKey($0) })
            remaining = remaining.filter { !used.contains(hashKey($0)) }
            if remaining.count < config.minWallInliers { break }
        }

        // Need at least a floor or walls to proceed.
        guard floorFit != nil || !wallFits.isEmpty else { return nil }

        // --- Horizontal axes ---------------------------------------------------
        let axisA: SIMD3<Double>
        if let strongest = wallFits.max(by: { $0.inlierCount < $1.inlierCount }) {
            axisA = strongest.plane.horizontalNormal
        } else {
            axisA = SIMD3<Double>(1, 0, 0)
        }
        let axisB = simd_normalize(simd_cross(up, axisA))

        // Group walls by which axis their normal aligns with.
        func group(_ axis: SIMD3<Double>) -> [PlaneFitter.Fit] {
            wallFits.filter { abs(simd_dot($0.plane.horizontalNormal, axis)) > 0.7 }
        }
        let aWalls = group(axisA)
        let bWalls = group(axisB)

        // --- Width (along axisA) & Depth (along axisB) -------------------------
        let sizeA = dimension(alongAxis: axisA, opposingWalls: aWalls,
                              floor: floorFit, calibration: calibration, config: config)
        let sizeB = dimension(alongAxis: axisB, opposingWalls: bWalls,
                              floor: floorFit, calibration: calibration, config: config)

        guard let a = sizeA, let b = sizeB else { return nil }

        // Convention: width is the larger horizontal span.
        let width = a.meters >= b.meters ? a : b
        let depth = a.meters >= b.meters ? b : a

        // --- Height ------------------------------------------------------------
        let height = solveHeight(floor: floorFit, ceiling: ceilingFit, walls: wallFits,
                                 calibration: calibration, config: config)
        guard let heightEstimate = height else { return nil }

        let dims = ClosetDimensions(width: width, depth: depth, height: heightEstimate)

        var centroid = SIMD3<Double>(repeating: 0)
        if let f = floorFit, !f.inliers.isEmpty {
            centroid = f.inliers.reduce(SIMD3<Double>(repeating: 0), +) / Double(f.inliers.count)
        }

        return Solution(dimensions: dims,
                        wallPlanes: wallFits.map { $0.plane },
                        floor: floorFit?.plane, ceiling: ceilingFit?.plane,
                        centroid: centroid, axisA: axisA, axisB: axisB)
    }

    // MARK: - Dimension helpers

    private static func dimension(alongAxis axis: SIMD3<Double>,
                                  opposingWalls walls: [PlaneFitter.Fit],
                                  floor: PlaneFitter.Fit?,
                                  calibration: ScaleCalibration,
                                  config: Config) -> DimensionEstimate? {
        // Best case: two opposing walls whose normals straddle this axis.
        if walls.count >= 2 {
            let sorted = walls.sorted { $0.inlierCount > $1.inlierCount }
            for i in sorted.indices {
                for j in (i + 1)..<sorted.count {
                    let ni = sorted[i].plane.horizontalNormal
                    let nj = sorted[j].plane.horizontalNormal
                    if simd_dot(ni, nj) < -0.5,               // opposing
                       let sep = PlaneFitter.separation(between: sorted[i], and: sorted[j]) {
                        let raw = sep.distance
                        let dist = raw * calibration.factor
                        let conf = confidence(distance: dist, standardError: sep.standardError,
                                              calibration: calibration, config: config, extra: 0)
                        return DimensionEstimate(meters: dist, confidenceMeters: conf,
                                                 method: .planePair,
                                                 pointSupport: sorted[i].inlierCount + sorted[j].inlierCount)
                    }
                }
            }
        }

        // Fallback: robust extent of the floor along this axis (handles open fronts).
        if let f = floor, f.inliers.count >= config.minFloorInliers {
            let projections = f.inliers.map { simd_dot(axis, $0) }
            let lo = ErrorStats.percentile(projections, config.extentLowPercentile)
            let hi = ErrorStats.percentile(projections, config.extentHighPercentile)
            let raw = abs(hi - lo)
            let dist = raw * calibration.factor
            let conf = confidence(distance: dist, standardError: 0,
                                  calibration: calibration, config: config,
                                  extra: config.floorExtentExtraMeters)
            return DimensionEstimate(meters: dist, confidenceMeters: conf,
                                     method: .floorExtent, pointSupport: f.inlierCount)
        }
        return nil
    }

    private static func solveHeight(floor: PlaneFitter.Fit?, ceiling: PlaneFitter.Fit?,
                                    walls: [PlaneFitter.Fit],
                                    calibration: ScaleCalibration,
                                    config: Config) -> DimensionEstimate? {
        if let f = floor, let c = ceiling, let sep = PlaneFitter.separation(between: f, and: c) {
            let dist = sep.distance * calibration.factor
            let conf = confidence(distance: dist, standardError: sep.standardError,
                                  calibration: calibration, config: config, extra: 0)
            return DimensionEstimate(meters: dist, confidenceMeters: conf,
                                     method: .wallHeight,
                                     pointSupport: f.inlierCount + c.inlierCount)
        }
        // No ceiling captured → vertical extent of the wall points above the floor.
        let wallPts = walls.flatMap { $0.inliers }
        if let f = floor, !wallPts.isEmpty {
            let heights = wallPts.map { f.plane.signedDistance(to: $0) }
            let top = ErrorStats.percentile(heights.map { abs($0) }, config.extentHighPercentile)
            let dist = top * calibration.factor
            let conf = confidence(distance: dist, standardError: 0,
                                  calibration: calibration, config: config,
                                  extra: config.floorExtentExtraMeters)
            return DimensionEstimate(meters: dist, confidenceMeters: conf,
                                     method: .floorExtent, pointSupport: wallPts.count)
        }
        return nil
    }

    /// Conservative ± half-width (~95%): statistical error added in quadrature with a
    /// systematic scale term (the real limit) and any method-specific extra.
    private static func confidence(distance: Double, standardError: Double,
                                   calibration: ScaleCalibration, config: Config,
                                   extra: Double) -> Double {
        let random = 1.96 * standardError
        let scale = calibration.residualUncertainty * distance
        return sqrt(random * random + scale * scale
                    + config.systematicFloorMeters * config.systematicFloorMeters
                    + extra * extra)
    }

    // Cheap, collision-tolerant key to subtract inlier sets between RANSAC rounds.
    private static func hashKey(_ p: SIMD3<Double>) -> Int64 {
        let s = 10000.0   // 0.1 mm grid
        let x = Int64((p.x * s).rounded())
        let y = Int64((p.y * s).rounded())
        let z = Int64((p.z * s).rounded())
        return (x &* 73_856_093) ^ (y &* 19_349_663) ^ (z &* 83_492_791)
    }
}

private extension PlaneFitter.Fit {
    /// Ensure floor/ceiling normals point up (+Y) so signed distances read as heights.
    func orientedUp() -> PlaneFitter.Fit {
        PlaneFitter.Fit(plane: plane.oriented(toward: ClosetSolver.up),
                        inliers: inliers, rmsResidual: rmsResidual)
    }
}
