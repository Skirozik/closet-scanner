import Foundation
import Combine
import UIKit

/// One validation measurement: what the app said vs. ground truth.
struct Trial: Identifiable, Codable {
    var id = UUID()
    var timestamp: Date
    var label: String        // e.g. "Width", "Ref 600 mm"
    var method: String
    var trueMM: Double
    var measuredMM: Double
    var device: String
    var errorMM: Double { measuredMM - trueMM }
}

/// Persists validation trials and exports them as CSV for the Gage R&R study.
final class TrialLogger: ObservableObject {
    @Published private(set) var trials: [Trial] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("trials.json")
        load()
    }

    func add(label: String, method: MeasurementMethod, trueMM: Double, measuredMM: Double) {
        let trial = Trial(timestamp: Date(), label: label, method: method.rawValue,
                          trueMM: trueMM, measuredMM: measuredMM,
                          device: UIDevice.current.model)
        trials.append(trial)
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        trials.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        trials.removeAll()
        save()
    }

    // MARK: Stats

    func overallStats() -> ErrorStats? {
        ErrorStats.compute(errorsMM: trials.map { $0.errorMM })
    }

    func stats(forLabel label: String) -> ErrorStats? {
        ErrorStats.compute(errorsMM: trials.filter { $0.label == label }.map { $0.errorMM })
    }

    var labels: [String] {
        Array(Set(trials.map { $0.label })).sorted()
    }

    // MARK: CSV export

    func exportCSV() -> URL? {
        var csv = "timestamp,label,method,true_mm,measured_mm,error_mm,device\n"
        let iso = ISO8601DateFormatter()
        for t in trials {
            csv += "\(iso.string(from: t.timestamp)),\(t.label),\(t.method),"
            csv += String(format: "%.3f,%.3f,%.3f,", t.trueMM, t.measuredMM, t.errorMM)
            csv += "\(t.device)\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("closet_validation_\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Trial].self, from: data) else { return }
        trials = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(trials) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
