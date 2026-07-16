import Foundation

/// Computes a scale correction from known-length references.
///
/// The dominant *systematic* error in ARKit/LiDAR distances is a multiplicative
/// scale bias (typically 0.5–2%). We remove it with a least-squares slope through
/// the origin over (measured, true) pairs — measured · factor ≈ true — and report
/// the residual fractional error as the calibrated scale uncertainty.
///
/// Calibrate on some references and *validate on others* (or on the real closet
/// with a laser) so you never report accuracy against the data you tuned on.
enum CalibrationManager {

    struct Sample: Identifiable {
        let id = UUID()
        var trueMM: Double
        var measuredMM: Double
    }

    static func compute(_ samples: [Sample]) -> ScaleCalibration? {
        let valid = samples.filter { $0.trueMM > 0 && $0.measuredMM > 0 }
        guard !valid.isEmpty else { return nil }

        let num = valid.reduce(0.0) { $0 + $1.trueMM * $1.measuredMM }
        let den = valid.reduce(0.0) { $0 + $1.measuredMM * $1.measuredMM }
        guard den > 0 else { return nil }
        let factor = num / den

        let uncertainty: Double
        if valid.count >= 2 {
            let fracErrors = valid.map { (($0.measuredMM * factor) - $0.trueMM) / $0.trueMM }
            let rms = sqrt(fracErrors.map { $0 * $0 }.reduce(0, +) / Double(fracErrors.count))
            uncertainty = max(rms, 0.001)      // never claim better than 0.1%
        } else {
            uncertainty = 0.003                // single point → assume ~0.3% residual
        }

        return ScaleCalibration(factor: factor, residualUncertainty: uncertainty, isCalibrated: true)
    }
}
