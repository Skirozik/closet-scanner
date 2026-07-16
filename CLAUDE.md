# ClosetScanner — Claude Code project guide

Native iOS app (SwiftUI + ARKit LiDAR, with an optional RoomPlan module) that scans a
closet, digitally removes its contents to show a clean empty shell, and measures
Width × Depth × Height in inches at 1/16" with an honest per-dimension ± confidence.
Built for a live technical-interview demo.

## Read first
- `docs/HANDOFF.md` — full context: research findings, decisions, accuracy reality, next steps.
- `docs/SETUP.md` — build/run on device.
- `docs/VALIDATION.md` — the accuracy validation protocol (heavily graded).
- `README.md` — architecture overview.

## Build
Generate the Xcode project from the spec (loose Swift files → project):
```bash
brew install xcodegen && xcodegen generate && open ClosetScanner.xcodeproj
```
Requires iOS 17+ and a LiDAR device (iPhone 12 Pro or newer Pro / LiDAR iPad Pro).
Run unit tests with ⌘U (the `Geometry/` core runs on the Mac, no device needed).

## Architecture
- `Geometry/` — pure-Swift, unit-tested accuracy core: RANSAC+PCA plane fit,
  opposing-plane solver, 1/16" imperial formatting, MSA statistics, scale calibration. No UIKit.
- `Sensing/` — ARKit scene-reconstruction mesh extraction + surface classification.
- `Scan/` — auto scan (ARKit) + optional, isolated RoomPlan cross-check.
- `Manual/` — tap-two-points raycast measurement against the LiDAR mesh.
- `Render/`, `Results/` — empty-shell 3D view (with "remove contents" toggle) + dimension cards.
- `Calibration/`, `Validation/` — scale calibration + CSV trial logger + Gage R&R stats.

## Core principle
Reported dimensions come ONLY from the ARKit LiDAR plane-fit pipeline — **never** from
RoomPlan's parametric walls (those are ±2–5 cm, sketch-grade). 1/16" (1.588 mm) is below
iPhone LiDAR's physical resolution; the app is engineered for best-effort few-mm accuracy
and is honest about it, validating against a caliper-certified reference.

## Conventions
- Git commits: author under the user's own name only. Do NOT add a "Co-Authored-By: Claude" trailer.
- Keep RoomPlan off the measurement critical path.
- Any dimension shown to the user must carry a ± confidence; never claim finer than the reference.
