import Foundation
import ARKit
import RealityKit
import Combine

/// Owns the ARKit scene-reconstruction session used for measurement.
///
/// We run our own `ARWorldTrackingConfiguration` with `.meshWithClassification`
/// and `.smoothedSceneDepth`, render the live mesh via RealityKit's
/// `showSceneUnderstanding` debug overlay, and stream mesh anchors into a
/// `MeshCollector`. The reported dimensions come entirely from this pipeline —
/// RoomPlan is a separate, optional cross-check (see `RoomPlanScanView`).
final class ScanController: NSObject, ObservableObject, ARSessionDelegate {

    let arView = ARView(frame: .zero)
    let collector = MeshCollector()

    @Published var anchorCount = 0
    @Published var faceEstimate = 0
    @Published var trackingState: String = "Starting…"
    @Published var isRunning = false

    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
            || ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func start() {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        config.environmentTexturing = .none
        config.planeDetection = [.horizontal, .vertical]

        // Stop RealityKit from overriding our frameSemantics / environmentTexturing.
        arView.automaticallyConfigureSession = false
        arView.session.delegate = self
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.environment.sceneUnderstanding.options.insert(.collision)   // enables mesh raycast in manual mode
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func pause() {
        arView.session.pause()
        isRunning = false
    }

    func reset() {
        collector.reset()
        anchorCount = 0
        faceEstimate = 0
        start()
    }

    /// Snapshot the accumulated mesh into a classified cloud + display buckets.
    func snapshot(objectBoxes: [OrientedBox] = []) -> MeshCollector.Snapshot {
        collector.snapshot(objectBoxes: objectBoxes)
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        ingest(anchors, removing: false)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        ingest(anchors, removing: false)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        ingest(anchors, removing: true)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            switch camera.trackingState {
            case .normal: self?.trackingState = "Tracking OK"
            case .limited(let reason): self?.trackingState = "Limited: \(reason)"
            case .notAvailable: self?.trackingState = "No tracking"
            }
        }
    }

    private func ingest(_ anchors: [ARAnchor], removing: Bool) {
        var meshCount = 0
        for anchor in anchors {
            guard let mesh = anchor as? ARMeshAnchor else { continue }
            if removing { collector.remove(mesh) } else { collector.update(mesh); meshCount += 1 }
        }
        if meshCount > 0 || removing {
            let count = collector.anchorCount
            DispatchQueue.main.async { [weak self] in self?.anchorCount = count }
        }
    }
}
