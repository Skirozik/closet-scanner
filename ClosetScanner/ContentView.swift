import SwiftUI
import ARKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                if !ScanController.isSupported {
                    Section {
                        Label("This device has no LiDAR scene reconstruction. Run on an iPhone 12 Pro or newer Pro / a LiDAR iPad Pro.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Measure") {
                    NavigationLink { ScanScreen() } label: {
                        row("Scan Closet", "Auto scan → empty shell + dimensions", "camera.viewfinder")
                    }
                    NavigationLink { ManualMeasureScreen() } label: {
                        row("Manual Precision Measure", "Tap two points for the tightest number", "hand.point.up.left.and.text")
                    }
                }

                Section("Accuracy") {
                    NavigationLink { CalibrationScreen() } label: {
                        row("Scale Calibration", calibrationSubtitle, "scalemass")
                    }
                    NavigationLink { ValidationScreen() } label: {
                        row("Validation Log", "Gage R&R trials → CSV + stats", "chart.bar.doc.horizontal")
                    }
                }

                Section("Optional") {
                    NavigationLink { RoomPlanScreen() } label: {
                        row("RoomPlan Cross-check", "Object labels + parametric empty-room USDZ", "arkit")
                    }
                }

                if let result = model.lastResult {
                    Section("Last Scan") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.headline).font(.headline)
                            Text("captured \(result.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("ClosetScanner")
        }
    }

    private var calibrationSubtitle: String {
        model.calibration.isCalibrated
            ? String(format: "calibrated · factor %.4f · ±%.2f%%", model.calibration.factor, model.calibration.residualUncertainty * 100)
            : "uncalibrated (assumes ±0.5% scale)"
    }

    private func row(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
