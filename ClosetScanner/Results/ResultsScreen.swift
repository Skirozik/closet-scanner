import SwiftUI

struct ResultsScreen: View {
    @EnvironmentObject var model: AppModel
    let result: ScanResult
    let buckets: MeshBuckets

    @State private var showContents = false
    @State private var logTarget: LogTarget?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                preview
                dimensionCards
                accuracyNote
                actions
            }
            .padding()
        }
        .navigationTitle("Empty Closet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logTarget) { target in
            LogTrialSheet(label: target.label, measuredMM: target.measuredMM) { trueMM in
                model.logger.add(label: target.label, method: target.method,
                                 trueMM: trueMM, measuredMM: target.measuredMM)
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 8) {
            MeshSceneView(buckets: buckets, showContents: showContents)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Toggle(isOn: $showContents) {
                Label(showContents ? "Showing contents" : "Contents removed (empty shell)",
                      systemImage: showContents ? "eye" : "eye.slash")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.blue)
            Text("Drag to orbit. Red = contents we detected and hid; gray = walls/ceiling; brown = floor.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dimensionCards: some View {
        VStack(spacing: 12) {
            DimensionCard(title: "Width", estimate: result.dimensions.width)
            DimensionCard(title: "Depth", estimate: result.dimensions.depth)
            DimensionCard(title: "Height", estimate: result.dimensions.height)
            HStack {
                Text("Floor area").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f ft²", result.dimensions.floorAreaSquareFeet))
                    .font(.body.weight(.semibold)).monospacedDigit()
            }
            .padding(.horizontal, 4)
        }
    }

    private var accuracyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Honest accuracy", systemImage: "checkmark.shield")
                .font(.subheadline.weight(.bold))
            Text(calibrationLine)
                .font(.caption).foregroundStyle(.secondary)
            Text("Dimensions come from LiDAR plane fits, not RoomPlan's parametric walls. The ± band reflects statistical spread plus ARKit scale uncertainty. 1/16\" (1.588 mm) is below the sensor's resolution — see the Validation Log for the measured tolerance.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var calibrationLine: String {
        result.calibration.isCalibrated
            ? String(format: "Scale calibrated (factor %.4f, residual ±%.2f%%). %ld wall planes%@.",
                     result.calibration.factor, result.calibration.residualUncertainty * 100,
                     result.wallPlaneCount, result.hasCeiling ? ", ceiling captured" : ", ceiling inferred")
            : String(format: "Uncalibrated (assumes ±0.5%% scale). %ld wall planes%@. Calibrate for tighter numbers.",
                     result.wallPlaneCount, result.hasCeiling ? ", ceiling captured" : ", ceiling inferred")
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Text("Log a dimension as a validation trial (enter the laser/tape ground truth):")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                logButton("Width", result.dimensions.width)
                logButton("Depth", result.dimensions.depth)
                logButton("Height", result.dimensions.height)
            }
        }
    }

    private func logButton(_ label: String, _ e: DimensionEstimate) -> some View {
        Button {
            logTarget = LogTarget(label: label, measuredMM: e.mm, method: e.method)
        } label: {
            Text("Log \(label)")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    struct LogTarget: Identifiable {
        let id = UUID()
        let label: String
        let measuredMM: Double
        let method: MeasurementMethod
    }
}

/// Prompt for the ground-truth value, then record measured-vs-true as a trial.
struct LogTrialSheet: View {
    let label: String
    let measuredMM: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trueText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Measured") {
                    Text(String(format: "%@ = %.2f mm  (%@)", label, measuredMM,
                                ImperialLength(inches: Units.metersToInches(measuredMM / 1000)).fractionString()))
                }
                Section("Ground truth (mm)") {
                    TextField("e.g. 1204.0", text: $trueText)
                        .keyboardType(.decimalPad)
                    if let t = Double(trueText) {
                        Text(String(format: "error = %+.2f mm", measuredMM - t))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Log \(label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let t = Double(trueText) { onSave(t); dismiss() }
                    }.disabled(Double(trueText) == nil)
                }
            }
        }
    }
}
