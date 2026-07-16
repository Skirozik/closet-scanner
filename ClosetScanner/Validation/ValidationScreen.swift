import SwiftUI

struct ValidationScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var label = ""
    @State private var trueText = ""
    @State private var measuredText = ""
    @State private var exportURL: URL?

    private var logger: TrialLogger { model.logger }

    var body: some View {
        Form {
            if let stats = logger.overallStats() {
                Section("Overall (n = \(stats.n))") {
                    Text(stats.honestSummary)
                        .font(.caption.monospaced())
                    statRow("Bias (correctable)", String(format: "%+.2f mm", stats.biasMM))
                    statRow("RMSE", String(format: "%.2f mm", stats.rmseMM))
                    statRow("σ repeatability", String(format: "%.2f mm", stats.sigmaMM))
                    statRow("Max |error|", String(format: "%.2f mm", stats.maxAbsMM))
                    statRow("Within 1/16\"", String(format: "%.0f%%", stats.pctWithinTolerance))
                    statRow("95% bound", String(format: "±%.2f mm", stats.bound95ParametricMM))
                    statRow("P/T ratio", String(format: "%.2f", stats.ptRatio))
                }
            } else {
                Section { Text("No trials yet. Add measured-vs-true pairs below or from a scan's Results screen.").foregroundStyle(.secondary) }
            }

            Section("Add trial") {
                TextField("Label (e.g. Width, Ref 600 mm)", text: $label)
                TextField("True (mm)", text: $trueText).keyboardType(.decimalPad)
                TextField("Measured (mm)", text: $measuredText).keyboardType(.decimalPad)
                Button("Add") {
                    if let t = Double(trueText), let m = Double(measuredText), !label.isEmpty {
                        logger.add(label: label, method: .manual, trueMM: t, measuredMM: m)
                        trueText = ""; measuredText = ""
                    }
                }
                .disabled(label.isEmpty || Double(trueText) == nil || Double(measuredText) == nil)
            }

            if !logger.labels.isEmpty {
                Section("Per-dimension") {
                    ForEach(logger.labels, id: \.self) { l in
                        if let s = logger.stats(forLabel: l) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l).font(.subheadline.weight(.semibold))
                                Text(String(format: "n=%ld · bias %+.2f · σ %.2f · max %.2f · %.0f%% in tol",
                                            s.n, s.biasMM, s.sigmaMM, s.maxAbsMM, s.pctWithinTolerance))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !logger.trials.isEmpty {
                Section("Trials (\(logger.trials.count))") {
                    ForEach(logger.trials) { t in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(t.label).font(.subheadline)
                                Text(t.method).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%+.2f mm", t.errorMM))
                                .font(.caption.monospaced())
                                .foregroundStyle(abs(t.errorMM) <= Units.metersToMM(Units.toleranceMeters) ? .green : .orange)
                        }
                    }
                    .onDelete { logger.remove(atOffsets: $0) }
                }

                Section {
                    if let url = exportURL {
                        ShareLink(item: url) { Label("Share CSV", systemImage: "square.and.arrow.up") }
                    }
                    Button("Prepare CSV export") { exportURL = logger.exportCSV() }
                    Button("Clear all trials", role: .destructive) { logger.clear(); exportURL = nil }
                }
            }
        }
        .navigationTitle("Validation Log")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).monospacedDigit().foregroundStyle(.secondary) }
    }
}
