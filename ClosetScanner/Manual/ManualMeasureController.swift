import Foundation
import ARKit
import RealityKit
import Combine
import simd

/// Tap-to-measure against the LiDAR reconstruction mesh. This is the most reliable
/// path in a cramped closet: the user places the two endpoints directly on real
/// corners, so we bypass automatic wall-vs-shelf classification entirely.
final class ManualMeasureController: NSObject, ObservableObject {

    let arView = ARView(frame: .zero)

    @Published var pointCount = 0
    @Published var distanceMeters: Double?
    @Published var trackingText = "Starting…"

    private var points: [SIMD3<Float>] = []
    private var markerAnchors: [AnchorEntity] = []

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
        config.planeDetection = [.horizontal, .vertical]

        // Stop RealityKit from overriding our frameSemantics.
        arView.automaticallyConfigureSession = false
        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    func pause() { arView.session.pause() }

    func reset() {
        points.removeAll()
        markerAnchors.forEach { arView.scene.removeAnchor($0) }
        markerAnchors.removeAll()
        distanceMeters = nil
        pointCount = 0
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        guard let world = worldPosition(at: location) else { return }

        if points.count >= 2 { reset() }   // start a fresh measurement
        points.append(world)
        placeMarker(at: world)
        pointCount = points.count

        if points.count == 2 {
            distanceMeters = Double(simd_distance(points[0], points[1]))
            drawLine(points[0], points[1])
        }
    }

    /// Prefer a hit against the reconstructed mesh; fall back to an estimated plane.
    private func worldPosition(at point: CGPoint) -> SIMD3<Float>? {
        if let hit = arView.hitTest(point, query: .nearest, mask: .sceneUnderstanding).first {
            return hit.position
        }
        if let query = arView.makeRaycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
           let result = arView.session.raycast(query).first {
            let c = result.worldTransform.columns.3
            return SIMD3<Float>(c.x, c.y, c.z)
        }
        return nil
    }

    private func placeMarker(at position: SIMD3<Float>) {
        let anchor = AnchorEntity(world: position)
        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.008),
                                 materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
        markerAnchors.append(anchor)
    }

    private func drawLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>) {
        let midpoint = (a + b) / 2
        let length = simd_distance(a, b)
        let box = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.004, 0.004, length)),
                              materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)])
        let anchor = AnchorEntity(world: midpoint)
        // Orient the box's local +Z along (b - a).
        let dir = simd_normalize(b - a)
        let z = SIMD3<Float>(0, 0, 1)
        let dot = simd_dot(z, dir)
        if abs(dot) < 0.9999 {
            let axis = simd_normalize(simd_cross(z, dir))
            let angle = acos(max(-1, min(1, dot)))
            anchor.orientation = simd_quatf(angle: angle, axis: axis)
        } else if dot < 0 {
            anchor.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
        }
        anchor.addChild(box)
        arView.scene.addAnchor(anchor)
        markerAnchors.append(anchor)
    }
}

extension ManualMeasureController: ARSessionDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            switch camera.trackingState {
            case .normal: self?.trackingText = "Tracking OK"
            case .limited(let r): self?.trackingText = "Limited: \(r)"
            case .notAvailable: self?.trackingText = "No tracking"
            }
        }
    }
}
