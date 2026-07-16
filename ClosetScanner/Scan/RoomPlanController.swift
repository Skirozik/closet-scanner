import Foundation
import SwiftUI
import RoomPlan

struct RoomCaptureContainer: UIViewRepresentable {
    let view: RoomCaptureView
    func makeUIView(context: Context) -> RoomCaptureView { view }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// Drives a RoomPlan capture and surfaces the parametric result for the cross-check.
final class RoomPlanController: NSObject, ObservableObject, RoomCaptureViewDelegate {

    let roomCaptureView = RoomCaptureView(frame: .zero)

    @Published var finished = false
    @Published var wallCount = 0
    @Published var doorCount = 0
    @Published var openingCount = 0
    @Published var objectCategories: [String] = []

    private var capturedRoom: CapturedRoom?

    override init() {
        super.init()
        roomCaptureView.delegate = self
    }

    func start() {
        roomCaptureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    func stop() {
        roomCaptureView.captureSession.stop()
    }

    /// Export the clean parametric room (walls/floor, contents excluded) as USDZ.
    func exportUSDZ() -> URL? {
        guard let room = capturedRoom else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty_closet_\(Int(Date().timeIntervalSince1970)).usdz")
        do {
            try room.export(to: url, exportOptions: .parametric)
            return url
        } catch {
            return nil
        }
    }

    // MARK: RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        capturedRoom = processedResult
        wallCount = processedResult.walls.count
        doorCount = processedResult.doors.count
        openingCount = processedResult.openings.count
        objectCategories = summarize(processedResult.objects)
        finished = true
    }

    private func summarize(_ objects: [CapturedRoom.Object]) -> [String] {
        var counts: [String: Int] = [:]
        for object in objects {
            let name = String(describing: object.category)
            counts[name, default: 0] += 1
        }
        return counts.map { $0.value > 1 ? "\($0.key) ×\($0.value)" : $0.key }.sorted()
    }
}
