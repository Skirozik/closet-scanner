import SwiftUI
import RealityKit

/// Bridges the RealityKit ARView (owned by the controller) into SwiftUI.
struct ARScanContainer: UIViewRepresentable {
    let controller: ScanController
    func makeUIView(context: Context) -> ARView { controller.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ScanScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var controller = ScanController()

    @State private var result: ScanResult?
    @State private var buckets: MeshBuckets?
    @State private var goToResults = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ARScanContainer(controller: controller).ignoresSafeArea()

            VStack {
                statusBar
                Spacer()
                instructions
                finishButton
            }
            .padding()
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onDisappear { controller.pause() }
        .alert("Couldn't measure", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(isPresented: $goToResults) {
            if let result, let buckets {
                ResultsScreen(result: result, buckets: buckets)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Circle().fill(controller.trackingState.hasPrefix("Tracking") ? .green : .orange)
                .frame(width: 10, height: 10)
            Text(controller.trackingState).font(.caption.weight(.semibold))
            Spacer()
            Text("\(controller.anchorCount) mesh tiles").font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var instructions: some View {
        Text("Pan slowly across every wall, the floor, and the ceiling. Keep ~0.4–1 m from surfaces. Loop back to where you started before finishing.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Label("Finish & Measure", systemImage: "ruler")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private func finish() {
        controller.pause()
        let snap = controller.snapshot()
        guard let solution = ClosetSolver.solve(cloud: snap.cloud, calibration: model.calibration) else {
            errorMessage = "Not enough surface captured. Re-scan the walls, floor, and ceiling more thoroughly."
            controller.start()
            return
        }
        let res = ScanResult(dimensions: solution.dimensions,
                             removedCategories: [],
                             calibration: model.calibration,
                             wallPlaneCount: solution.wallPlanes.count,
                             hasCeiling: solution.ceiling != nil,
                             capturedAt: Date())
        model.lastResult = res
        model.lastBuckets = snap.buckets
        result = res
        buckets = snap.buckets
        goToResults = true
    }
}
