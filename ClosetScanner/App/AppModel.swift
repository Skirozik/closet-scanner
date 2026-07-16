import Foundation
import Combine

/// Shared app state: the active scale calibration, the most recent scan, and the
/// validation trial log.
final class AppModel: ObservableObject {
    @Published var calibration: ScaleCalibration = .uncalibrated
    @Published var lastResult: ScanResult?
    @Published var lastBuckets: MeshBuckets?
    let logger = TrialLogger()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-publish the logger's changes so views observing AppModel refresh when
        // trials are added/removed (the logger is a separate ObservableObject).
        logger.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func applyCalibration(_ cal: ScaleCalibration) {
        calibration = cal
    }
}
