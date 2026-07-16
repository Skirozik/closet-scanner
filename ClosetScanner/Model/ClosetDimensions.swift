import Foundation

/// How a single dimension was derived, for honest labeling in the UI.
enum MeasurementMethod: String, Codable {
    case planePair = "plane-pair"     // perpendicular distance between two fitted opposing walls (most accurate)
    case floorExtent = "floor-extent" // robust extent of the floor along an axis (used when a side is open)
    case wallHeight = "wall-height"   // floor↔ceiling plane distance
    case manual = "manual"            // user-snapped corner-to-corner

    var displayName: String {
        switch self {
        case .planePair: return "opposing-wall fit"
        case .floorExtent: return "floor extent"
        case .wallHeight: return "floor↔ceiling fit"
        case .manual: return "manual snap"
        }
    }
}

/// One measured dimension with an uncertainty (± half-width, ~95%) and provenance.
struct DimensionEstimate: Codable {
    var meters: Double
    var confidenceMeters: Double        // ± half-width, ~95%
    var method: MeasurementMethod
    var pointSupport: Int               // how many mesh points backed this estimate

    var inches: Double { Units.metersToInches(meters) }
    var confidenceInches: Double { Units.metersToInches(confidenceMeters) }
    var mm: Double { Units.metersToMM(meters) }
    var confidenceMM: Double { Units.metersToMM(confidenceMeters) }

    var display: String { ImperialLength(meters: meters).fractionString() }
    var confidenceDisplay: String { String(format: "±%.2f mm (±%.3f\")", confidenceMM, confidenceInches) }

    /// True only if the uncertainty band sits inside 1/16" — used to badge the number honestly.
    var withinToleranceBand: Bool { confidenceMeters <= Units.toleranceMeters }
}

/// The closet, empty.
struct ClosetDimensions: Codable {
    var width: DimensionEstimate     // side-to-side
    var depth: DimensionEstimate     // front-to-back
    var height: DimensionEstimate    // floor-to-ceiling

    var floorAreaSquareFeet: Double {
        let wFt = width.meters * 3.280839895
        let dFt = depth.meters * 3.280839895
        return wFt * dFt
    }
}
