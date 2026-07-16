import Foundation
import simd

/// Robustly fits a plane to a noisy point cloud.
///
/// Strategy: RANSAC to find the largest inlier set (rejects clutter / mixed
/// surfaces), then a PCA (total-least-squares) refit over those inliers. The PCA
/// refit is what buys accuracy — averaging N points drives the plane's random
/// error down by ~1/√N, which is how we push a ~5–10 mm per-point sensor toward
/// low-mm surface estimates.
enum PlaneFitter {

    struct Fit {
        let plane: Plane
        let inliers: [SIMD3<Double>]
        let rmsResidual: Double      // RMS of inlier perpendicular distances (meters)
        var inlierCount: Int { inliers.count }
    }

    /// - Parameters:
    ///   - points: candidate points (meters, world space).
    ///   - inlierThreshold: max perpendicular distance to count as an inlier (default 12 mm).
    ///   - iterations: RANSAC samples.
    ///   - maxSampleForScoring: cap on points scored per iteration (downsampled for speed on huge meshes).
    static func ransacFit(points: [SIMD3<Double>],
                          inlierThreshold: Double = 0.012,
                          iterations: Int = 240,
                          maxSampleForScoring: Int = 6000,
                          seed: UInt64 = 0xC10_5E7) -> Fit? {
        guard points.count >= 3 else { return nil }
        var rng = SplitMix64(seed: seed)

        // Downsample the scoring set so each RANSAC iteration is cheap; the final
        // refit still uses every real inlier from the full cloud.
        let scoringPoints: [SIMD3<Double>]
        if points.count > maxSampleForScoring {
            let stride = points.count / maxSampleForScoring
            scoringPoints = Swift.stride(from: 0, to: points.count, by: max(1, stride)).map { points[$0] }
        } else {
            scoringPoints = points
        }

        var bestPlane: Plane?
        var bestInlierCount = 0

        for _ in 0..<iterations {
            let i = Int(rng.next() % UInt64(points.count))
            let j = Int(rng.next() % UInt64(points.count))
            let k = Int(rng.next() % UInt64(points.count))
            if i == j || j == k || i == k { continue }

            let a = points[i], b = points[j], c = points[k]
            let n = simd_cross(b - a, c - a)
            let len = simd_length(n)
            if len < 1e-9 { continue }              // degenerate / collinear sample
            let plane = Plane(normal: n / len, throughPoint: a)

            var count = 0
            for p in scoringPoints where abs(plane.signedDistance(to: p)) <= inlierThreshold {
                count += 1
            }
            if count > bestInlierCount {
                bestInlierCount = count
                bestPlane = plane
            }
        }

        guard let coarse = bestPlane else { return nil }

        // Collect true inliers from the FULL cloud, then PCA-refit.
        let inliers = points.filter { abs(coarse.signedDistance(to: $0)) <= inlierThreshold }
        guard inliers.count >= 3 else { return nil }
        return pcaFit(inliers, orientLike: coarse)
    }

    /// Total-least-squares plane fit: the plane through the centroid whose normal
    /// is the eigenvector of the smallest covariance eigenvalue.
    static func pcaFit(_ points: [SIMD3<Double>], orientLike reference: Plane? = nil) -> Fit? {
        guard points.count >= 3 else { return nil }
        let (cov, centroid) = LinearAlgebra.covariance(points)
        let (values, vectors) = LinearAlgebra.jacobiEigenSymmetric3(cov)

        // Smallest eigenvalue → normal direction (least variance).
        var minIdx = 0
        if values[1] < values[minIdx] { minIdx = 1 }
        if values[2] < values[minIdx] { minIdx = 2 }
        var normal = SIMD3<Double>(vectors[0][minIdx], vectors[1][minIdx], vectors[2][minIdx])
        normal = simd_normalize(normal)

        var plane = Plane(normal: normal, throughPoint: centroid)
        if let ref = reference { plane = plane.oriented(toward: ref.normal) }

        var sumSq = 0.0
        for p in points {
            let dist = plane.signedDistance(to: p)
            sumSq += dist * dist
        }
        let rms = (sqrt(sumSq / Double(points.count)))
        return Fit(plane: plane, inliers: points, rmsResidual: rms)
    }

    /// Perpendicular separation between two (roughly parallel) planes, measured by
    /// projecting both inlier sets onto a shared axis and differencing the means.
    /// Because it averages every inlier, its standard error is far below per-point noise.
    static func separation(between a: Fit, and b: Fit) -> (distance: Double, standardError: Double)? {
        guard !a.inliers.isEmpty, !b.inliers.isEmpty else { return nil }

        // Shared axis: bisector of the two (anti-parallel) normals.
        var axis = a.plane.normal - b.plane.normal
        if simd_length(axis) < 1e-6 { axis = a.plane.normal }
        axis = simd_normalize(axis)

        let projA = a.inliers.map { simd_dot(axis, $0) }
        let projB = b.inliers.map { simd_dot(axis, $0) }

        let meanA = projA.reduce(0, +) / Double(projA.count)
        let meanB = projB.reduce(0, +) / Double(projB.count)
        let distance = abs(meanA - meanB)

        let seA = standardErrorOfMean(projA, mean: meanA)
        let seB = standardErrorOfMean(projB, mean: meanB)
        return (distance, sqrt(seA * seA + seB * seB))
    }

    private static func standardErrorOfMean(_ values: [Double], mean: Double) -> Double {
        let n = values.count
        guard n > 1 else { return 0 }
        var ss = 0.0
        for v in values { let d = v - mean; ss += d * d }
        let variance = ss / Double(n - 1)
        return sqrt(variance / Double(n))
    }
}
