import SwiftUI

struct CalibrationScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var samples: [CalibrationManager.Sample] = []
    @State private var trueText = ""
    @State private var measuredText = ""

    private var computed: ScaleCalibration? { CalibrationManager.compute(samples) }

    var body: some View {
        Form {
            Section {
                Text("Measure caliper-certified references (use Manual Precision Measure), then enter the true length and what the app read. The fitted scale factor corrects systematic error.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Add reference sample") {
                TextField("True length (mm)", text: $trueText).keyboardType(.decimalPad)
                TextField("App measured (mm)", text: $measuredText).keyboardType(.decimalPad)
                Button("Add sample") {
                    if let t = Double(trueText), let m = Double(measuredText), t > 0, m > 0 {
                        samples.append(.init(trueMM: t, measuredMM: m))
                        trueText = ""; measuredText = ""
                    }
                }
                .disabled(Double(trueText) == nil || Double(measuredText) == nil)
            }

            if !samples.isEmpty {
                Section("Samples") {
                    ForEach(samples) { s in
                        HStack {
                            Text(String(format: "true %.1f", s.trueMM))
                            Spacer()
                            Text(String(format: "meas %.1f", s.measuredMM)).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%+.2f mm", s.measuredMM - s.trueMM))
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .onDelete { samples.remove(atOffsets: $0) }
                }
            }

            if let c = computed {
                Section("Fitted calibration") {
                    LabeledContent("Scale factor", value: String(format: "%.5f", c.factor))
                    LabeledContent("Residual uncertainty", value: String(format: "±%.3f%%", c.residualUncertainty * 100))
                    Button("Apply calibration") { model.applyCalibration(c) }
                        .fontWeight(.semibold)
                }
            }

            Section("Current") {
                if model.calibration.isCalibrated {
                    LabeledContent("Active factor", value: String(format: "%.5f", model.calibration.factor))
                    Button("Reset to uncalibrated", role: .destructive) {
                        model.applyCalibration(.uncalibrated)
                    }
                } else {
                    Text("Uncalibrated — distances assume ±0.5% scale.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Scale Calibration")
        .navigationBarTitleDisplayMode(.inline)
    }
}
