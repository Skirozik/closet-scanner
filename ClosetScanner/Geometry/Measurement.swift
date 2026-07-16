import Foundation

enum Units {
    static let inchesPerMeter = 39.370078740157481
    static let mmPerMeter = 1000.0
    /// The challenge tolerance: 1/16 inch, in meters.
    static let toleranceInches = 1.0 / 16.0
    static let toleranceMeters = toleranceInches / inchesPerMeter   // 0.0015875 m

    static func metersToInches(_ m: Double) -> Double { m * inchesPerMeter }
    static func metersToMM(_ m: Double) -> Double { m * mmPerMeter }
    static func inchesToMeters(_ i: Double) -> Double { i / inchesPerMeter }
}

/// Formats a length in inches to the nearest 1/16", as whole + reduced fraction
/// (e.g. `38 7/16"`), plus a feet-and-inches form. Display resolution is trivial;
/// the honesty is in the accompanying ± confidence, not in the digits themselves.
struct ImperialLength {
    let totalInches: Double

    init(meters: Double) { self.totalInches = Units.metersToInches(meters) }
    init(inches: Double) { self.totalInches = inches }

    /// Nearest sixteenth of an inch.
    var quantizedInches: Double {
        (totalInches * 16.0).rounded() / 16.0
    }

    /// e.g. "38 7/16\"", "38\"", "7/16\"", or "0\"".
    func fractionString() -> String {
        let sixteenths = Int((totalInches * 16.0).rounded())
        let whole = sixteenths / 16
        var num = sixteenths % 16
        var den = 16
        if num == 0 {
            return "\(whole)\""
        }
        let g = ImperialLength.gcd(num, den)
        num /= g; den /= g
        if whole == 0 {
            return "\(num)/\(den)\""
        }
        return "\(whole) \(num)/\(den)\""
    }

    /// e.g. "3' 2 7/16\"".
    func feetInchesString() -> String {
        let sixteenths = Int((totalInches * 16.0).rounded())
        let totalWholeInches = sixteenths / 16
        let feet = totalWholeInches / 12
        let remInches = totalInches - Double(feet * 12)
        let inchPart = ImperialLength(inches: remInches).fractionString()
        if feet == 0 { return inchPart }
        return "\(feet)' \(inchPart)"
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = abs(a), b = abs(b)
        while b != 0 { (a, b) = (b, a % b) }
        return max(a, 1)
    }
}
