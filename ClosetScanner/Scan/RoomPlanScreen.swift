import SwiftUI
import RoomPlan

/// OPTIONAL cross-check. RoomPlan gives a polished coaching UI, ML object
/// detection (what to call "contents"), and a clean parametric USDZ. It is NOT on
/// the measurement critical path — reported dimensions always come from the ARKit
/// LiDAR plane-fit pipeline, because RoomPlan's parametric walls are only ±2–5 cm.
struct RoomPlanScreen: View {
    var body: some View {
        if RoomCaptureSession.isSupported {
            RoomPlanCaptureScreen()
        } else {
            ContentUnavailableView("RoomPlan unavailable",
                                   systemImage: "arkit",
                                   description: Text("This device doesn't support RoomPlan (needs LiDAR)."))
        }
    }
}

private struct RoomPlanCaptureScreen: View {
    @StateObject private var controller = RoomPlanController()
    @State private var exportURL: URL?

    var body: some View {
        ZStack {
            RoomCaptureContainer(view: controller.roomCaptureView).ignoresSafeArea()

            VStack {
                Spacer()
                if controller.finished {
                    resultCard
                } else {
                    Button {
                        controller.stop()
                    } label: {
                        Label("Finish RoomPlan Scan", systemImage: "stop.circle")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("RoomPlan (cross-check)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected structure").font(.subheadline.weight(.bold))
            Text("\(controller.wallCount) walls · \(controller.doorCount) doors · \(controller.openingCount) openings")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Contents detected & removed").font(.subheadline.weight(.bold))
            if controller.objectCategories.isEmpty {
                Text("None").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(controller.objectCategories.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let url = exportURL {
                ShareLink(item: url) { Label("Share empty room (USDZ)", systemImage: "square.and.arrow.up") }
            } else {
                Button("Export empty room (USDZ)") { exportURL = controller.exportUSDZ() }
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct RoomPlanContainerFallback: View { var body: some View { EmptyView() } }
