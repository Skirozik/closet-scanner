import Foundation
import simd

/// A plane in Hessian normal form: for a point `p`, the signed distance is
/// `dot(normal, p) + d`. `normal` is unit length.
struct Plane {
    var normal: SIMD3<Double>
    var d: Double

    init(normal: SIMD3<Double>, d: Double) {
        let len = simd_length(normal)
        if len > 0 {
            self.normal = normal / len
            self.d = d / len
        } else {
            self.normal = SIMD3<Double>(0, 1, 0)
            self.d = d
        }
    }

    init(normal: SIMD3<Double>, throughPoint point: SIMD3<Double>) {
        let n = simd_normalize(normal)
        self.normal = n
        self.d = -simd_dot(n, point)
    }

    /// Signed perpendicular distance from the plane to `p`.
    func signedDistance(to p: SIMD3<Double>) -> Double {
        simd_dot(normal, p) + d
    }

    /// Flip so the normal points toward `reference` (used to orient floor/ceiling "up").
    func oriented(toward reference: SIMD3<Double>) -> Plane {
        if simd_dot(normal, reference) < 0 {
            return Plane(normal: -normal, d: -d)
        }
        return self
    }

    /// Horizontal component of the normal (Y is up in ARKit world space), unit length.
    var horizontalNormal: SIMD3<Double> {
        let h = SIMD3<Double>(normal.x, 0, normal.z)
        let len = simd_length(h)
        return len > 1e-9 ? h / len : SIMD3<Double>(1, 0, 0)
    }

    /// How vertical the plane is (1 = perfectly vertical wall, 0 = horizontal floor/ceiling).
    var verticality: Double { simd_length(SIMD3<Double>(normal.x, 0, normal.z)) }
}
