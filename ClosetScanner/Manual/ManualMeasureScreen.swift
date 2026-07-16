import SwiftUI
import RealityKit

struct ARMeasureContainer: UIViewRepresentable {
    let controller: ManualMeasureController
    func makeUIView(context: Context) -> ARView { controller.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ManualMeasureScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var controller = ManualMeasureController()
    @State private var logTarget: LogInfo?

    var body: some View {
        ZStack {
            ARMeasureContainer(controller: controller).ignoresSafeArea()

            VStack {
                HStack {
                    Circle().fill(controller.trackingText.hasPrefix("Tracking") ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(controller.trackingText).font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(controller.pointCount)/2 points").font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())

                Spacer()

                if let d = controller.distanceMeters {
                    VStack(spacing: 4) {
                        Text(ImperialLength(meters: d).fractionString())
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(String(format: "%.1f mm · %.3f in", d * 1000, Units.metersToInches(d)))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("Tap the two endpoints of the span you want to measure.")
                        .font(.footnote)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Button {
                        controller.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity).padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let d = controller.distanceMeters {
                        Button {
                            logTarget = LogInfo(measuredMM: d * 1000)
                        } label: {
                            Label("Log trial", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity).padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.top, 6)
            }
            .padding()
        }
        .navigationTitle("Manual Measure")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onDisappear { controller.pause() }
        .sheet(item: $logTarget) { info in
            LogTrialSheet(label: "Manual", measuredMM: info.measuredMM) { trueMM in
                model.logger.add(label: "Manual", method: .manual, trueMM: trueMM, measuredMM: info.measuredMM)
            }
        }
    }

    struct LogInfo: Identifiable { let id = UUID(); let measuredMM: Double }
}
