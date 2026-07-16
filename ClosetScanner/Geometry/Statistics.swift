import Foundation

/// Measurement-system-analysis statistics for the accuracy validation study.
/// Everything here is what you put on the results slide; nothing over-claims.
struct ErrorStats {
    let n: Int
    let biasMM: Double          // mean signed error (measured − true); correctable
    let maeMM: Double           // mean absolute error
    let rmseMM: Double          // root-mean-square error
    let sigmaMM: Double         // sample std dev of errors (repeatability), n−1
    let maxAbsMM: Double        // worst-case |error| — the honest number
    let pctWithinTolerance: Double   // % of |error| ≤ tolerance
    let bound95ParametricMM: Double  // |bias| + 1.96·σ
    let bound95EmpiricalMM: Double   // 95th percentile of |error|
    let ptRatio: Double         // precision/tolerance = 5.15·σ / toleranceWidth

    /// - Parameters:
    ///   - errorsMM: signed errors (measured − true), millimeters.
    ///   - toleranceMM: half-tolerance (e.g. 1/16" = 1.5875 mm). The full tolerance
    ///     band is ±toleranceMM, so its width is 2·toleranceMM.
    static func compute(errorsMM: [Double], toleranceMM: Double = Units.metersToMM(Units.toleranceMeters)) -> ErrorStats? {
        let n = errorsMM.count
        guard n > 0 else { return nil }

        let sum = errorsMM.reduce(0, +)
        let bias = sum / Double(n)

        let absErrors = errorsMM.map { abs($0) }
        let mae = absErrors.reduce(0, +) / Double(n)
        let rmse = sqrt(errorsMM.map { $0 * $0 }.reduce(0, +) / Double(n))
        let maxAbs = absErrors.max() ?? 0

        let sigma: Double
        if n > 1 {
            let ss = errorsMM.map { let d = $0 - bias; return d * d }.reduce(0, +)
            sigma = sqrt(ss / Double(n - 1))
        } else {
            sigma = 0
        }

        let within = errorsMM.filter { abs($0) <= toleranceMM }.count
        let pct = 100.0 * Double(within) / Double(n)

        let bound95Param = abs(bias) + 1.96 * sigma
        let bound95Emp = percentile(absErrors, 95)
        let pt = (2.0 * toleranceMM) > 0 ? (5.15 * sigma) / (2.0 * toleranceMM) : .infinity

        return ErrorStats(n: n, biasMM: bias, maeMM: mae, rmseMM: rmse, sigmaMM: sigma,
                          maxAbsMM: maxAbs, pctWithinTolerance: pct,
                          bound95ParametricMM: bound95Param, bound95EmpiricalMM: bound95Emp,
                          ptRatio: pt)
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let rank = (p / 100.0) * Double(sorted.count - 1)
        let lo = Int(rank.rounded(.down))
        let hi = Int(rank.rounded(.up))
        let frac = rank - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * frac
    }

    /// One-line honest summary for the interview.
    var honestSummary: String {
        String(format: "bias %+.2f mm, σ %.2f mm, RMSE %.2f mm, max %.2f mm; %.0f%% within 1/16\"; 95%% bound ±%.2f mm (P/T %.2f)",
               biasMM, sigmaMM, rmseMM, maxAbsMM, pctWithinTolerance, bound95ParametricMM, ptRatio)
    }
}
