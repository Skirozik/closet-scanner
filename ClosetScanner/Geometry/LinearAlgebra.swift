import Foundation
import simd

/// Small, dependency-free linear-algebra helpers used by the plane fitter.
/// Kept pure (no UIKit/ARKit) so the whole accuracy core is unit-testable on the Mac.
enum LinearAlgebra {

    // MARK: 3x3 helpers (row-major [[Double]])

    static func matMul(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        var c = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for i in 0..<3 {
            for j in 0..<3 {
                var s = 0.0
                for k in 0..<3 { s += a[i][k] * b[k][j] }
                c[i][j] = s
            }
        }
        return c
    }

    static func transpose(_ a: [[Double]]) -> [[Double]] {
        var t = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for i in 0..<3 { for j in 0..<3 { t[i][j] = a[j][i] } }
        return t
    }

    /// Jacobi eigenvalue algorithm for a symmetric 3x3 matrix.
    /// Returns eigenvalues and eigenvectors (eigenvector k is column k of `vectors`).
    static func jacobiEigenSymmetric3(_ input: [[Double]]) -> (values: [Double], vectors: [[Double]]) {
        var a = input
        var v: [[Double]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

        for _ in 0..<64 {
            // Pick the largest-magnitude off-diagonal element.
            var p = 0, q = 1
            var maxOff = abs(a[0][1])
            if abs(a[0][2]) > maxOff { maxOff = abs(a[0][2]); p = 0; q = 2 }
            if abs(a[1][2]) > maxOff { maxOff = abs(a[1][2]); p = 1; q = 2 }
            if maxOff < 1e-18 { break }

            // Rotation angle that zeroes a[p][q]: tan(2θ) = 2·a_pq / (a_pp − a_qq).
            let phi = 0.5 * atan2(2.0 * a[p][q], a[p][p] - a[q][q])
            let c = cos(phi), s = sin(phi)

            var g: [[Double]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
            g[p][p] = c; g[q][q] = c
            g[p][q] = s; g[q][p] = -s

            a = matMul(matMul(transpose(g), a), g)   // A' = Gᵀ A G
            v = matMul(v, g)                          // accumulate eigenvectors
        }

        return ([a[0][0], a[1][1], a[2][2]], v)
    }

    /// Population covariance (3x3) and centroid of a point set.
    static func covariance(_ points: [SIMD3<Double>]) -> (cov: [[Double]], centroid: SIMD3<Double>) {
        let n = Double(points.count)
        var mean = SIMD3<Double>(repeating: 0)
        for p in points { mean += p }
        mean /= n

        var cov = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for p in points {
            let d = p - mean
            cov[0][0] += d.x * d.x; cov[0][1] += d.x * d.y; cov[0][2] += d.x * d.z
            cov[1][1] += d.y * d.y; cov[1][2] += d.y * d.z
            cov[2][2] += d.z * d.z
        }
        cov[0][0] /= n; cov[0][1] /= n; cov[0][2] /= n
        cov[1][1] /= n; cov[1][2] /= n; cov[2][2] /= n
        // symmetric fill
        cov[1][0] = cov[0][1]; cov[2][0] = cov[0][2]; cov[2][1] = cov[1][2]
        return (cov, mean)
    }
}

/// Deterministic, seedable RNG so RANSAC and unit tests are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
