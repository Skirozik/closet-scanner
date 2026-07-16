import SwiftUI
import SceneKit
import simd

/// Renders the captured mesh, color-coded by surface class, and lets us toggle the
/// closet's *contents* on and off — the visual proof that we "digitally remove"
/// what's inside and leave a clean empty shell.
struct MeshSceneView: UIViewRepresentable {
    let buckets: MeshBuckets
    var showContents: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = buildScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .systemBackground
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene?.rootNode.childNode(withName: "contents", recursively: false)?.isHidden = !showContents
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()

        let wall = node(from: buckets.wall, color: UIColor.systemGray2.withAlphaComponent(0.85), name: "wall")
        let floor = node(from: buckets.floor, color: UIColor.systemBrown.withAlphaComponent(0.9), name: "floor")
        let ceiling = node(from: buckets.ceiling, color: UIColor.systemGray4.withAlphaComponent(0.7), name: "ceiling")
        let contents = node(from: buckets.other, color: UIColor.systemRed.withAlphaComponent(0.9), name: "contents")
        contents.isHidden = !showContents

        for n in [wall, floor, ceiling, contents] { scene.rootNode.addChildNode(n) }

        // Center the camera on the structural mesh.
        let allStructure = buckets.wall + buckets.floor + buckets.ceiling
        if let center = centroid(of: allStructure) {
            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.zFar = 100
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(center.x, center.y + 0.2, center.z + 3.0)
            cameraNode.look(at: SCNVector3(center.x, center.y, center.z))
            scene.rootNode.addChildNode(cameraNode)
        }
        return scene
    }

    private func node(from triangles: [SIMD3<Float>], color: UIColor, name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name
        guard triangles.count >= 3 else { return node }

        let vertices = triangles.map { SCNVector3($0.x, $0.y, $0.z) }
        let source = SCNGeometrySource(vertices: vertices)
        let indices = (0..<Int32(vertices.count)).map { $0 }
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        material.lightingModel = .constant   // no per-vertex normals needed
        geometry.materials = [material]

        node.geometry = geometry
        return node
    }

    private func centroid(of points: [SIMD3<Float>]) -> SIMD3<Float>? {
        guard !points.isEmpty else { return nil }
        var sum = SIMD3<Float>(repeating: 0)
        for p in points { sum += p }
        return sum / Float(points.count)
    }
}
