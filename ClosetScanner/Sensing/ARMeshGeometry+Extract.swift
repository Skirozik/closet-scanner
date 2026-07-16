import Foundation
import ARKit
import simd

/// Low-level readers for `ARMeshGeometry`'s Metal buffers.
///
/// These follow Apple's documented layout (see the "Visualizing and Interacting
/// with a Reconstructed Scene" sample). We `memcpy` exactly the bytes we need so
/// we are robust to a vertex stride that isn't 16.
extension ARMeshGeometry {

    func vertex(at index: UInt32) -> SIMD3<Float> {
        let base = vertices.buffer.contents()
            .advanced(by: vertices.offset + vertices.stride * Int(index))
        var v = SIMD3<Float>(0, 0, 0)
        memcpy(&v, base, MemoryLayout<Float>.size * 3)
        return v
    }

    /// The three vertex indices of a face.
    func vertexIndices(ofFace faceIndex: Int) -> (UInt32, UInt32, UInt32) {
        let perFace = faces.indexCountPerPrimitive          // 3 for triangles
        let base = faces.buffer.contents()
            .advanced(by: faces.bytesPerIndex * perFace * faceIndex)
        func idx(_ o: Int) -> UInt32 {
            var value: UInt32 = 0
            memcpy(&value, base.advanced(by: o * faces.bytesPerIndex), faces.bytesPerIndex)
            return value
        }
        return (idx(0), idx(1), idx(2))
    }

    /// ARKit's semantic label for a face (requires `.meshWithClassification`).
    func classification(ofFace faceIndex: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        let base = classification.buffer.contents()
            .advanced(by: classification.offset + classification.stride * faceIndex)
        let raw = base.assumingMemoryBound(to: UInt8.self).pointee
        return ARMeshClassification(rawValue: Int(raw)) ?? .none
    }

    var faceCount: Int { faces.count }
}
