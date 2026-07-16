import XCTest
@testable import ClosetScanner

final class StatisticsTests: XCTestCase {

    func testPerfectMeasurements() {
        let stats = ErrorStats.compute(errorsMM: [0, 0, 0, 0])!
        XCTAssertEqual(stats.biasMM, 0, accuracy: 1e-9)
        XCTAssertEqual(stats.rmseMM, 0, accuracy: 1e-9)
        XCTAssertEqual(stats.pctWithinTolerance, 100, accuracy: 1e-9)
    }

    func testKnownErrors() {
        // symmetric ±2 mm errors: bias 0, σ = sqrt(8) with n-1=1
        let stats = ErrorStats.compute(errorsMM: [2, -2])!
        XCTAssertEqual(stats.biasMM, 0, accuracy: 1e-9)
        XCTAssertEqual(stats.maeMM, 2, accuracy: 1e-9)
        XCTAssertEqual(stats.rmseMM, 2, accuracy: 1e-9)
        XCTAssertEqual(stats.sigmaMM, sqrt(8.0), accuracy: 1e-6)
        XCTAssertEqual(stats.maxAbsMM, 2, accuracy: 1e-9)
        XCTAssertEqual(stats.pctWithinTolerance, 0, accuracy: 1e-9)   // 2 mm > 1.5875 mm
    }

    func testWithinTolerance() {
        // errors well under 1/16" (1.5875 mm)
        let stats = ErrorStats.compute(errorsMM: [0.5, -0.5, 1.0, -1.0])!
        XCTAssertEqual(stats.pctWithinTolerance, 100, accuracy: 1e-9)
    }

    func testBiasIsSigned() {
        let stats = ErrorStats.compute(errorsMM: [3, 3, 3])!
        XCTAssertEqual(stats.biasMM, 3, accuracy: 1e-9)
        XCTAssertEqual(stats.sigmaMM, 0, accuracy: 1e-9)   // constant bias, no spread
    }

    func testCalibrationScaleFactor() {
        let samples = [CalibrationManager.Sample(trueMM: 1000, measuredMM: 1005)]
        let cal = CalibrationManager.compute(samples)!
        XCTAssertTrue(cal.isCalibrated)
        XCTAssertEqual(cal.factor, 1000.0 / 1005.0, accuracy: 1e-6)
    }

    func testCalibrationResidual() {
        let samples = [
            CalibrationManager.Sample(trueMM: 500, measuredMM: 502),
            CalibrationManager.Sample(trueMM: 1000, measuredMM: 1004),
            CalibrationManager.Sample(trueMM: 1500, measuredMM: 1506)
        ]
        let cal = CalibrationManager.compute(samples)!
        // consistent +0.4% scale → factor ≈ 0.996, tiny residual
        XCTAssertEqual(cal.factor, 1.0 / 1.004, accuracy: 1e-3)
        XCTAssertLessThan(cal.residualUncertainty, 0.002)
    }
}
