import Foundation
import simd

/// Classified point clouds harvested from the ARKit reconstruction mesh.
/// Structure (wall/floor/ceiling) drives measurement; everything else is "contents".
struct ClassifiedCloud {
    var wall: [SIMD3<Double>] = []
    var floor: [SIMD3<Double>] = []
    var ceiling: [SIMD3<Double>] = []
    var other: [SIMD3<Double>] = []   // furniture/clothing/etc. — what we digitally remove

    var isEmpty: Bool { wall.isEmpty && floor.isEmpty && ceiling.isEmpty }
}

/// A scale correction derived from a fiducial marker of known physical size.
/// `factor` multiplies raw distances; `residualUncertainty` is the fractional
/// scale error that remains after calibration (feeds the ± confidence).
struct ScaleCalibration {
    var factor: Double = 1.0
    var residualUncertainty: Double = 0.005   // 0.5% when uncalibrated
    var isCalibrated: Bool = false

    static let uncalibrated = ScaleCalibration()
}

/// Everything produced by one scan, ready to present and log.
struct ScanResult: Identifiable {
    let id = UUID()
    var dimensions: ClosetDimensions
    var removedCategories: [String]     // object categories RoomPlan detected and we hid
    var calibration: ScaleCalibration
    var wallPlaneCount: Int
    var hasCeiling: Bool
    var capturedAt: Date

    /// e.g. "37 5/8\" W × 23 1/2\" D × 96 1/8\" H"
    var headline: String {
        "\(dimensions.width.display) W × \(dimensions.depth.display) D × \(dimensions.height.display) H"
    }
}
