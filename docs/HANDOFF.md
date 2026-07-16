# PROJECT HANDOFF — everything from the planning session

This captures the research, decisions, and rationale behind ClosetScanner so the full context travels with the repo to any machine — this document *is* the chat in usable form.

> The raw Claude Code session transcript lives on the Windows machine at
> `C:\Users\inyan\.claude\projects\C--Users-inyan\<session-id>.jsonl`.
> It is deliberately **not** in this repo (it's a personal conversation log and the repo is shared with the interviewer). If you want the literal transcript on your Mac, copy that file over manually (AirDrop / iCloud / USB) — do not commit it here.

## The challenge

Build a working iPhone app that (a) scans a closet with the iPhone's sensors, (b) digitally removes/hides the contents to show a clean empty space, (c) calculates and displays the closet's dimensions, (d) targets **1/16" (1.588 mm)** accuracy *and demonstrates how it was tested/validated*, (e) runs live from the iPhone. Deliverable includes a shared GitHub repo. 20-minute live demo.

## The single most important insight

**1/16" (1.588 mm) is below the physical resolution of iPhone LiDAR.** The interviewer is testing engineering judgment, and the winning move is rigorous honesty backed by a real validation study — not a faked "1/16 inch" claim. Everything is built around that.

### Grounded accuracy numbers (from the research)
- iPhone LiDAR per-point precision: ~±5–10 mm at close range on a flat matte wall.
- Peer-reviewed best flat-surface result: ~6–8 mm RMSE (already 4–5× the target).
- RoomPlan *parametric* dimensions: ~±2–5 cm per wall; it forces a uniform ~16 cm wall thickness and ~3 cm XY voxel floor — **sketch-grade, never used for measurement.**
- ARKit VIO scale drift grows with path length (keep the scan short and looped to bound it).
- A closet (dark, tight, fabric, sometimes mirrors) is near the sensor's worst case.

Sources include Luetzenburg 2021 (Scientific Reports), façade/indoor-mapping studies vs. terrestrial laser scanners (2024), and it-jim's RoomPlan analyses. Full source list is in the planning notes; key figures are summarized in the README.

## Architecture decisions (and why)

1. **Split responsibilities.** RoomPlan owns the *visual/UX story* (empty-room concept, object labels, parametric USDZ). Our **own ARKit LiDAR plane-fit pipeline owns the numbers.** Reported dimensions never come from RoomPlan.
2. **RoomPlan is an isolated, optional module.** The live demo's measurements don't depend on RoomPlan's internals — so a RoomPlan hiccup on stage can't break the core result. This was a deliberate de-risking choice.
3. **Measure between fitted planes, not between corner points.** Width/Depth = perpendicular distance between two opposing fitted wall planes. This averages thousands of inliers, so the estimate's standard error is far below per-point noise (~1/√N). Height = fitted floor↔ceiling distance (ARKit classification captures ceilings; RoomPlan does not).
4. **Classify surfaces to "remove contents."** The reconstruction mesh is split into wall/floor/ceiling (structure) vs. other (contents) by ARKit classification + surface orientation/height, optionally subtracting RoomPlan object boxes. The Results view toggles contents off to reveal the empty shell.
5. **Honest confidence.** Each dimension's ± combines the (tiny) statistical standard error with a systematic *scale-uncertainty* term, because ARKit scale — not point noise — is the real limit. The UI badges whether the ± band sits inside 1/16".

## The accuracy stack (in priority order)
1. **Scale calibration** (biggest win): least-squares slope through the origin over (measured, true) references removes the dominant multiplicative scale bias (0.5–2%).
2. **RANSAC + PCA plane fitting**: rejects clutter, then total-least-squares plane through inliers.
3. **Opposing-plane distance**: the averaging-robust estimator for each dimension.
4. **Voxel + multi-frame averaging**: denoises and stabilizes the number.
5. **Manual corner-snap mode**: most reliable in a cramped closet; bypasses auto wall-detection.

## Validation methodology (the graded centerpiece)
- Ground truth must be ~4–10× better than 1.588 mm → need ±0.2–0.4 mm. A ±1 mm laser is only a *live-demo* reference; the **caliper-certified reference box (±0.1 mm) is the statistical truth**.
- Gage R&R / MSA study (~55 points): repeatability (3 dims × 10 re-scans) + bias/linearity (5 reference sizes × 5 scans).
- Report bias, MAE, RMSE, σ, max |error|, % within ±1.588 mm, 95% bound, and P/T ratio.
- The app exports a per-trial CSV; see [VALIDATION.md](VALIDATION.md) for the full protocol, certification worksheet, results-table template, and live-demo script.

## What was built
A complete native SwiftUI app (see the repo tree in the [README](../README.md)):
- Pure-Swift, unit-tested accuracy core (`Geometry/`): RANSAC+PCA plane fit, opposing-plane solver, 1/16" imperial formatting, MSA statistics, scale calibration.
- ARKit sensing (`Sensing/`): mesh buffer extraction + surface classification.
- Auto scan (`Scan/`) + optional RoomPlan cross-check.
- Manual precision measure (`Manual/`): tap two points, raycast to the LiDAR mesh.
- Empty-shell render with a "remove contents" toggle (`Render/`, `Results/`).
- Scale calibration + CSV trial logger + Gage R&R stats screens (`Calibration/`, `Validation/`).

## Status & next steps
- The Swift was written on Windows and **reviewed for API/compile-correctness by three independent passes** (ARKit/RoomPlan, RealityKit/SceneKit/SwiftUI, and Swift type-consistency). No blockers were found; two behavioral fixes and minor polish were applied.
- **It has not yet been compiled** — that happens on your Mac. Follow [SETUP.md](SETUP.md): create the Xcode project, drop in the source, sign, and run on a LiDAR iPhone (iOS 17+). Run `⌘U` for the unit tests (no device needed).
- Acquire the validation kit (digital caliper, reference box, laser measure) and run the study per VALIDATION.md.
- Rehearse the 20-minute demo flow and Q&A (kept in a private, un-committed talk-track file).

## Known limitations to own in the interview
- Not a reliable 1/16" on every span (report the measured tolerance instead).
- Dark/glossy/mirrored/fabric closets degrade LiDAR — demo in a matte, well-lit closet.
- Surface classification is heuristic; the parametric empty box and manual mode are the robust fallbacks.
- The empty-shell "remove contents" uses classification + optional RoomPlan boxes; tidy the closet a bit for the cleanest before/after.
