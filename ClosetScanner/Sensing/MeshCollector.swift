import Foundation
import ARKit
import simd

/// Which structural surface a mesh face belongs to. `other` = closet *contents*
/// (clothing, shelving, boxes) — the stuff we digitally remove.
enum SurfaceClass {
    case wall, floor, ceiling, other
}

/// An object's oriented bounding box in world space (from a RoomPlan `CapturedRoom.Object`).
/// Used to subtract detected contents from the measurement cloud.
struct OrientedBox {
    var transform: simd_float4x4      // object-local → world
    var halfExtents: SIMD3<Float>

    func contains(_ worldPoint: SIMD3<Float>, shrink: Float = 0.95) -> Bool {
        let local4 = transform.inverse * SIMD4<Float>(worldPoint, 1)
        let local = SIMD3<Float>(local4.x, local4.y, local4.z)
        let h = halfExtents * shrink
        return abs(local.x) <= h.x && abs(local.y) <= h.y && abs(local.z) <= h.z
    }
}

/// Triangle soup grouped by surface class, in world space, for rendering the
/// before/after "contents removed" view.
struct MeshBuckets {
    var wall: [SIMD3<Float>] = []
    var floor: [SIMD3<Float>] = []
    var ceiling: [SIMD3<Float>] = []
    var other: [SIMD3<Float>] = []   // hidden when "remove contents" is on
}

/// Accumulates ARKit reconstruction mesh across a scan, then snapshots it into a
/// classified point cloud (for measurement) and triangle buckets (for display).
///
/// Classification prefers ARKit's per-face label when it is a definitive
/// wall/floor/ceiling, and falls back to geometry (surface orientation + height)
/// otherwise — so it still works if classification is sparse.
final class MeshCollector {

    private var anchors: [UUID: ARMeshAnchor] = [:]
    private let lock = NSLock()

    func update(_ anchor: ARMeshAnchor) { lock.lock(); anchors[anchor.identifier] = anchor; lock.unlock() }
    func remove(_ anchor: ARMeshAnchor) { lock.lock(); anchors[anchor.identifier] = nil; lock.unlock() }
    func reset() { lock.lock(); anchors.removeAll(); lock.unlock() }
    var anchorCount: Int { lock.lock(); defer { lock.unlock() }; return anchors.count }

    struct Snapshot {
        var cloud: ClassifiedCloud
        var buckets: MeshBuckets
        var faceCount: Int
    }

    private struct FaceRecord {
        var v0, v1, v2: SIMD3<Float>
        var centroid: SIMD3<Float>
        var normalY: Float          // |normal.y|, for orientation test
        var arClass: ARMeshClassification
    }

    /// - Parameters:
    ///   - objectBoxes: RoomPlan object boxes to treat as contents (removed).
    ///   - voxel: downsample grid (m) for the measurement cloud.
    func snapshot(objectBoxes: [OrientedBox] = [], voxel: Double = 0.01) -> Snapshot {
        lock.lock(); let snapshotAnchors = Array(anchors.values); lock.unlock()

        // ---- Pass 1: gather faces in world space, find vertical bounds ----
        var records: [FaceRecord] = []
        records.reserveCapacity(4096)
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude

        for anchor in snapshotAnchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let count = geometry.faceCount
            for f in 0..<count {
                let (i0, i1, i2) = geometry.vertexIndices(ofFace: f)
                let p0 = worldPoint(geometry.vertex(at: i0), transform)
                let p1 = worldPoint(geometry.vertex(at: i1), transform)
                let p2 = worldPoint(geometry.vertex(at: i2), transform)
                let centroid = (p0 + p1 + p2) / 3
                let n = simd_cross(p1 - p0, p2 - p0)
                let nLen = simd_length(n)
                let normalY = nLen > 1e-9 ? abs(n.y / nLen) : 0
                records.append(FaceRecord(v0: p0, v1: p1, v2: p2, centroid: centroid,
                                          normalY: normalY, arClass: geometry.classification(ofFace: f)))
                minY = min(minY, centroid.y)
                maxY = max(maxY, centroid.y)
            }
        }

        let midY = (minY + maxY) * 0.5

        // ---- Pass 2: classify + fill buckets and (voxel-downsampled) cloud ----
        var buckets = MeshBuckets()
        var wallVox = VoxelAccumulator(size: voxel)
        var floorVox = VoxelAccumulator(size: voxel)
        var ceilVox = VoxelAccumulator(size: voxel)
        var otherVox = VoxelAccumulator(size: voxel)

        for r in records {
            let cls = classify(r, midY: midY, objectBoxes: objectBoxes)
            switch cls {
            case .wall:
                buckets.wall.append(contentsOf: [r.v0, r.v1, r.v2]); wallVox.add(r.centroid)
            case .floor:
                buckets.floor.append(contentsOf: [r.v0, r.v1, r.v2]); floorVox.add(r.centroid)
            case .ceiling:
                buckets.ceiling.append(contentsOf: [r.v0, r.v1, r.v2]); ceilVox.add(r.centroid)
            case .other:
                buckets.other.append(contentsOf: [r.v0, r.v1, r.v2]); otherVox.add(r.centroid)
            }
        }

        var cloud = ClassifiedCloud()
        cloud.wall = wallVox.points()
        cloud.floor = floorVox.points()
        cloud.ceiling = ceilVox.points()
        cloud.other = otherVox.points()

        return Snapshot(cloud: cloud, buckets: buckets, faceCount: records.count)
    }

    private func classify(_ r: FaceRecord, midY: Float, objectBoxes: [OrientedBox]) -> SurfaceClass {
        if !objectBoxes.isEmpty, objectBoxes.contains(where: { $0.contains(r.centroid) }) {
            return .other
        }
        switch r.arClass {
        case .wall: return .wall
        case .floor: return .floor
        case .ceiling: return .ceiling
        default: break
        }
        if r.normalY > 0.85 { return r.centroid.y < midY ? .floor : .ceiling }
        if r.normalY < 0.35 { return .wall }
        return .other
    }

    private func worldPoint(_ local: SIMD3<Float>, _ transform: simd_float4x4) -> SIMD3<Float> {
        let w = transform * SIMD4<Float>(local, 1)
        return SIMD3<Float>(w.x, w.y, w.z)
    }
}

/// Averages points that fall in the same voxel — denoises and bounds cloud size.
private struct VoxelAccumulator {
    let size: Double
    private var sums: [Int64: (SIMD3<Double>, Int)] = [:]

    init(size: Double) { self.size = size }

    mutating func add(_ p: SIMD3<Float>) {
        let d = SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z))
        let key = voxelKey(d)
        if let existing = sums[key] {
            sums[key] = (existing.0 + d, existing.1 + 1)
        } else {
            sums[key] = (d, 1)
        }
    }

    func points() -> [SIMD3<Double>] {
        sums.values.map { $0.0 / Double($0.1) }
    }

    private func voxelKey(_ p: SIMD3<Double>) -> Int64 {
        let x = Int64((p.x / size).rounded())
        let y = Int64((p.y / size).rounded())
        let z = Int64((p.z / size).rounded())
        return (x &* 73_856_093) ^ (y &* 19_349_663) ^ (z &* 83_492_791)
    }
}
