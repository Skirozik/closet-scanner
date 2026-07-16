import XCTest
@testable import ClosetScanner

final class MeasurementTests: XCTestCase {

    func testMetersToInches() {
        XCTAssertEqual(Units.metersToInches(1.0), 39.3700787, accuracy: 1e-4)
        XCTAssertEqual(Units.toleranceMeters, 0.0015875, accuracy: 1e-7)
    }

    func testFractionFormatting() {
        XCTAssertEqual(ImperialLength(inches: 38.4375).fractionString(), "38 7/16\"")
        XCTAssertEqual(ImperialLength(inches: 38.0).fractionString(), "38\"")
        XCTAssertEqual(ImperialLength(inches: 0.4375).fractionString(), "7/16\"")
        XCTAssertEqual(ImperialLength(inches: 0.5).fractionString(), "1/2\"")   // 8/16 reduces
        XCTAssertEqual(ImperialLength(inches: 12.25).fractionString(), "12 1/4\"")
    }

    func testQuantization() {
        // 38.44" → nearest 1/16 is 38.4375 (38 7/16)
        XCTAssertEqual(ImperialLength(inches: 38.44).quantizedInches, 38.4375, accuracy: 1e-9)
        XCTAssertEqual(ImperialLength(inches: 38.4375).fractionString(), "38 7/16\"")
    }

    func testFeetInches() {
        XCTAssertEqual(ImperialLength(inches: 38.4375).feetInchesString(), "3' 2 7/16\"")
        XCTAssertEqual(ImperialLength(inches: 10.0).feetInchesString(), "10\"")
    }
}
