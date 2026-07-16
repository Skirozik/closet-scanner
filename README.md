# ClosetScanner

An iPhone app that scans a closet with LiDAR, **digitally removes the contents to show the clean empty space**, and **measures the closet's dimensions** — reporting each number in inches at 1/16" resolution with an honest ± confidence.

Built for a live demo. Native SwiftUI + Apple **RoomPlan** + **ARKit LiDAR** (scene reconstruction with classification).

---

## The honest thesis

> RoomPlan gives us the empty closet and a live app *for free* by separating furniture from structure; raw LiDAR plane-fitting gives us the best honest few-millimeter measurement; and a caliper-certified Gage R&R study lets us state exactly how close to 1/16" we are — without pretending we're there.

**1/16" (1.588 mm) is below the physical resolution of iPhone LiDAR.** Best case on a flat matte wall at close range is ~±5 mm RMSE. This app is engineered to get as close as the hardware allows — fitting planes over thousands of points (noise falls ~1/√N), calibrating scale with a fiducial of known size, and averaging across frames — and then it **validates and reports accuracy honestly** rather than faking a number. See [docs/VALIDATION.md](docs/VALIDATION.md).

## How it meets the challenge

| Requirement | How |
|---|---|
| Scan with iPhone sensors | RoomPlan `RoomCaptureView` live scan on a shared ARKit session with `.mesh` reconstruction + `.smoothedSceneDepth`. |
| Remove/hide contents | The reported model is a clean parametric shell built from **structure-classified** surfaces only (walls/floor/ceiling); everything RoomPlan labels as an object (clothing, shelving, furniture) is excluded. A "Show contents" toggle demonstrates the before/after. |
| Calculate + display dimensions | Width/Depth/Height computed as the **perpendicular distance between opposing fitted planes** (the most averaging-robust estimator), shown in inches at 1/16". |
| 1/16" accuracy + validation | Fiducial scale calibration + RANSAC/PCA plane fitting + multi-frame averaging, validated against a caliper-certified reference box (Gage R&R study). Every dimension carries a ± confidence. |
| Live on iPhone | On-device native app; measures in real time; deploys to a LiDAR iPhone. |

## Requirements

- **Device:** iPhone 12 Pro or newer **Pro/Pro Max** (LiDAR required), or a LiDAR iPad Pro. iOS 17+.
- **Build:** macOS + Xcode 15+.

## Getting started

See [docs/SETUP.md](docs/SETUP.md) for creating the Xcode project, dropping in this source, signing, and deploying to your phone.

Quick version:
1. On your Mac, create a new iOS App (SwiftUI, iOS 17) named `ClosetScanner`.
2. Replace the generated files with the contents of [`ClosetScanner/`](ClosetScanner/) (drag the groups into Xcode).
3. Add the `NSCameraUsageDescription` key (already in the provided `Info.plist`).
4. Select your phone, sign with your team, and Run.

## Architecture

```
Scan (RoomPlan)                Measure (ARKit LiDAR)              Present
─────────────────              ──────────────────────            ──────────────
RoomCaptureView  ──shared──▶   MeshCollector (classified mesh)   EmptyRoomScene
   │             ARSession     PlaneFitter (RANSAC + PCA)         ResultsView
   ▼                           ClosetSolver (planes → W·D·H)      DimensionCard
CapturedRoom  ───labels───▶    CalibrationManager (fiducial)      TrialLogger → CSV
(what to hide)                 ManualMeasure (tap → raycast)
```

- **RoomPlan owns the visual/UX story.** Its parametric wall dimensions are *sketch-grade* (±2–5 cm) and are **never** reported as measurements.
- **Raw ARKit LiDAR owns the numbers.** Scene reconstruction gives a classified mesh; we fit planes to the wall/floor/ceiling faces and measure between them.

## Repo layout

```
ClosetScanner/            App source (drop into an Xcode target)
  Model/                  Plain value types (dimensions, results)
  Geometry/               Pure-Swift accuracy core (unit-tested, no UIKit)
  Sensing/                ARKit session + classified-mesh collection
  Scan/                   RoomPlan capture flow
  Render/                 SceneKit empty-shell rendering
  Manual/                 Tap-to-measure precision mode
  Calibration/            Fiducial scale calibration
  Validation/             CSV trial logging
  Results/ + ContentView  UI
ClosetScannerTests/       Unit tests for the geometry/stats core
docs/                     SETUP, VALIDATION, TALK_TRACK, CSV template
```

## Accuracy & validation

Read [docs/VALIDATION.md](docs/VALIDATION.md). Short version: measured against a caliper-certified reference, report **bias, RMSE, σ (repeatability), max error, % within ±1.588 mm, and a 95% bound** — never a bare "1/16 inch" claim. The app exports a per-trial CSV to drive the study.
