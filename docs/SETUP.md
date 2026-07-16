# SETUP — from these files to a running app on your iPhone

You're an experienced iOS dev, so this is terse. It assumes macOS + Xcode 15+ and a LiDAR iPhone (12 Pro or newer Pro) on iOS 17+.

## 0. Fastest path — generate the project with XcodeGen (recommended)

The repo ships a [`project.yml`](../project.yml), so you can skip the manual project creation:

```bash
brew install xcodegen        # if you don't have it
cd closet-scanner
xcodegen generate
open ClosetScanner.xcodeproj
```

Then jump to **§4 Sign & run**. (The generated `.xcodeproj` is reproducible from `project.yml`; commit it or git-ignore it, your call.) If you'd rather not install XcodeGen, use the manual steps below.

## 1. Create the Xcode project (manual alternative)

1. Xcode → **File ▸ New ▸ Project ▸ iOS ▸ App**.
2. Product Name: **ClosetScanner**. Interface: **SwiftUI**. Language: **Swift**. Storage: **None**.
3. Set the **iOS Deployment Target to 17.0** (target ▸ General ▸ Minimum Deployments).

## 2. Add the source

1. Delete the auto-generated `ContentView.swift` and `ClosetScannerApp.swift` from the new project (we provide our own).
2. Drag the folders inside [`ClosetScanner/`](../ClosetScanner) (App, Model, Geometry, Sensing, Scan, Render, Manual, Calibration, Validation, Results, plus `ContentView.swift`) into the Xcode project navigator. Choose **Create groups** and check **Copy items if needed** and your app target.
3. Add the test files under [`ClosetScannerTests/`](../ClosetScannerTests) to the **ClosetScannerTests** target (create a Unit Testing bundle if you skipped it: File ▸ New ▸ Target ▸ Unit Testing Bundle).

## 3. Permissions

Modern SwiftUI app targets generate their `Info.plist` from build settings, so the simplest path is:

- Target ▸ **Info** tab ▸ add **“Privacy - Camera Usage Description”** = `ClosetScanner uses the camera and LiDAR to scan the closet and measure its dimensions.`

(Or wire in the provided [`Info.plist`](../ClosetScanner/Info.plist) by setting `INFOPLIST_FILE` and turning off *Generate Info.plist File*. The `arkit` required-capability is optional but recommended.)

Frameworks (RoomPlan, ARKit, RealityKit, SceneKit) link automatically via `import`; no manual "Link Binary" step is needed on modern Xcode.

## 4. Sign & run

1. Plug in your iPhone; trust the Mac.
2. Target ▸ **Signing & Capabilities** ▸ check **Automatically manage signing** ▸ select your **Team**.
   - **Free path:** sign in with your Apple ID → a *Personal Team*. Provisioning lasts 7 days; just re-run from Xcode before the demo.
   - **Recommended:** enroll in the **Apple Developer Program ($99/yr)** for a stable profile + **TestFlight** as a backup install. Enrollment activation can take hours — start it early if you want it.
3. If the bundle identifier is taken, change it to something unique (e.g. `com.yourname.closetscanner`).
4. Select your device as the run destination and **⌘R**.
5. First launch: accept the camera permission. On device, trust the developer profile under **Settings ▸ General ▸ VPN & Device Management** if prompted.

## 5. Run the unit tests (no device needed)

**⌘U** — the geometry/accuracy core (`GeometryTests`, `MeasurementTests`, `StatisticsTests`) runs on the Mac and proves the plane-fitting, unit conversion, and stats.

## 6. Git → GitHub (the deliverable)

```bash
cd ClosetScanner
git init
printf "*.xcuserstate\nxcuserdata/\n.DS_Store\nbuild/\nDerivedData/\n" > .gitignore
git add .
git commit -m "ClosetScanner: LiDAR closet measurement + empty-shell + validation"
gh repo create closet-scanner --private --source=. --push   # or create on github.com and push
```

Share the repo link before the interview.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ARWorldTrackingConfiguration.supportsSceneReconstruction` is false | You're not on a LiDAR device. Use an iPhone 12 Pro+ / LiDAR iPad Pro. |
| Black AR view | Camera permission denied, or running in the Simulator. Must run on a real device. |
| Mesh overlay not visible | Confirm the run added `showSceneUnderstanding` and you're moving the phone so tiles build. |
| Manual tap doesn't register a point | You tapped past the reconstructed mesh; scan the surface first so mesh exists there, then tap. |
| RoomPlan screen says "unavailable" | Non-LiDAR device — RoomPlan needs LiDAR. Core measurement still works via ARKit. |
| Provisioning expired mid-day | Re-run from Xcode (free team) or install the TestFlight build (paid). |
