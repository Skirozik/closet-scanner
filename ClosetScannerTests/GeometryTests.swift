import XCTest
import simd
@testable import ClosetScanner

final class GeometryTests: XCTestCase {

    // MARK: Eigen

    func testJacobiEigenDiagonal() {
        let a = [[3.0, 0, 0], [0, 1.0, 0], [0, 0, 2.0]]
        let (values, vectors) = LinearAlgebra.jacobiEigenSymmetric3(a)
        // smallest eigenvalue is 1 (index 1) → eigenvector ≈ e_y
        var minIdx = 0
        if values[1] < values[minIdx] { minIdx = 1 }
        if values[2] < values[minIdx] { minIdx = 2 }
        XCTAssertEqual(values[minIdx], 1.0, accuracy: 1e-6)
        let ev = SIMD3<Double>(vectors[0][minIdx], vectors[1][minIdx], vectors[2][minIdx])
        XCTAssertEqual(abs(ev.y), 1.0, accuracy: 1e-6)
        XCTAssertLessThan(abs(ev.x), 1e-6)
        XCTAssertLessThan(abs(ev.z), 1e-6)
    }

    // MARK: Plane fitting

    func testPlaneFitRecoversNormal() {
        var rng = SplitMix64(seed: 42)
        var points: [SIMD3<Double>] = []
        for _ in 0..<2000 {
            let x = uniform(&rng) * 2 - 1
            let y = uniform(&rng) * 2 - 1
            let z = gaussianNoise(&rng, sigma: 0.001)   // plane z = 0, 1 mm noise
            points.append(SIMD3<Double>(x, y, z))
        }
        let fit = PlaneFitter.ransacFit(points: points)!
        XCTAssertEqual(abs(fit.plane.normal.z), 1.0, accuracy: 1e-2)
        XCTAssertLessThan(fit.rmsResidual, 0.0025)
        XCTAssertGreaterThan(fit.inlierCount, 1900)
    }

    func testPlaneSeparation() {
        var rng = SplitMix64(seed: 7)
        func wall(atX x0: Double) -> PlaneFitter.Fit {
            var pts: [SIMD3<Double>] = []
            for _ in 0..<1500 {
                let y = uniform(&rng) * 2
                let z = uniform(&rng) * 2
                let x = x0 + gaussianNoise(&rng, sigma: 0.001)
                pts.append(SIMD3<Double>(x, y, z))
            }
            return PlaneFitter.pcaFit(pts)!
        }
        let a = wall(atX: 0.0)
        let b = wall(atX: 1.2)
        let sep = PlaneFitter.separation(between: a, and: b)!
        XCTAssertEqual(sep.distance, 1.2, accuracy: 0.002)
        XCTAssertLessThan(sep.standardError, 0.0005)   // averaging beats per-point noise
    }

    // MARK: Full closet solve on a synthetic box

    func testClosetSolverRecoversBox() {
        let W = 1.20, D = 0.60, H = 2.40
        let cloud = makeBoxCloud(width: W, depth: D, height: H, noise: 0.0015, seed: 99)
        let solution = ClosetSolver.solve(cloud: cloud)!
        XCTAssertEqual(solution.dimensions.width.meters, 1.20, accuracy: 0.010)
        XCTAssertEqual(solution.dimensions.depth.meters, 0.60, accuracy: 0.010)
        XCTAssertEqual(solution.dimensions.height.meters, 2.40, accuracy: 0.010)
        XCTAssertEqual(solution.dimensions.width.method, .planePair)
        XCTAssertEqual(solution.dimensions.height.method, .wallHeight)
    }

    // MARK: Helpers

    /// Builds a classified point cloud for a box centered at the origin in X/Z,
    /// floor at y=0, ceiling at y=H. Walls at x=±W/2 and z=±D/2.
    private func makeBoxCloud(width W: Double, depth D: Double, height H: Double,
                              noise: Double, seed: UInt64) -> ClassifiedCloud {
        var rng = SplitMix64(seed: seed)
        var cloud = ClassifiedCloud()
        let grid = 45

        for i in 0..<grid {
            for j in 0..<grid {
                let u = Double(i) / Double(grid - 1)
                let v = Double(j) / Double(grid - 1)
                let xW = (u - 0.5) * W
                let zD = (v - 0.5) * D
                let yH = v * H

                // floor & ceiling
                cloud.floor.append(SIMD3<Double>(xW, gaussianNoise(&rng, sigma: noise), zD))
                cloud.ceiling.append(SIMD3<Double>(xW, H + gaussianNoise(&rng, sigma: noise), zD))

                // walls at x = ±W/2 (normal along X)
                cloud.wall.append(SIMD3<Double>(-W / 2 + gaussianNoise(&rng, sigma: noise), yH, (u - 0.5) * D))
                cloud.wall.append(SIMD3<Double>( W / 2 + gaussianNoise(&rng, sigma: noise), yH, (u - 0.5) * D))
                // walls at z = ±D/2 (normal along Z)
                cloud.wall.append(SIMD3<Double>((u - 0.5) * W, yH, -D / 2 + gaussianNoise(&rng, sigma: noise)))
                cloud.wall.append(SIMD3<Double>((u - 0.5) * W, yH,  D / 2 + gaussianNoise(&rng, sigma: noise)))
            }
        }
        return cloud
    }

    private func uniform(_ rng: inout SplitMix64) -> Double {
        Double(rng.next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// Approximate Gaussian via the central-limit sum of uniforms.
    private func gaussianNoise(_ rng: inout SplitMix64, sigma: Double) -> Double {
        var s = 0.0
        for _ in 0..<12 { s += uniform(&rng) }
        return (s - 6.0) * sigma
    }
}
