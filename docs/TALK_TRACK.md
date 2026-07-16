# TALK TRACK — 20-minute live demo

Your one-line thesis, memorized:

> **RoomPlan gives us the empty closet and a live app for free by separating furniture from structure; raw LiDAR plane-fitting gives us the best honest few-millimeter measurement; and a caliper-certified Gage R&R study lets us state exactly how close to 1/16" we are — without pretending we're there.**

## Suggested 20-minute flow

**0:00–2:00 — Frame it.** State the problem and your headline decision: *"1/16" is below iPhone LiDAR's physical resolution, so I engineered for the best honest accuracy and built a real validation study. Let me show it working, then show exactly how accurate it is."*

**2:00–8:00 — Live demo.**
1. Open the app → **Scan Closet**. Pan the walls, floor, ceiling; point out the live mesh building. Finish.
2. **Results**: read Width × Depth × Height in inches at 1/16", each with its ± confidence. Toggle **"Contents removed"** on/off — the red contents disappear, leaving the clean shell. That's requirement (b), demonstrated.
3. **Manual Precision Measure**: tap two corners → live distance. Explain this bypasses auto wall-detection for tight spaces.
4. (Optional) **RoomPlan Cross-check**: show it detects and labels the contents (clothing/storage) and exports a clean parametric empty room — "this is the 'remove contents for free' idea, and why RoomPlan is great for the *concept* but not the *numbers*."

**8:00–12:00 — Accuracy, honestly.** Put up the validation table + two charts. Walk bias vs σ, RMSE, max, % within 1/16", 95% bound, P/T. Do the **live laser side-by-side** on a pre-marked span; compute the delta against ±1.588 mm; repeat once for repeatability. Then the app on a caliper-certified reference (sub-mm truth).

**12:00–16:00 — Architecture & process.** Use the diagram below. Emphasize the split: RoomPlan for visuals/labels, ARKit LiDAR plane-fit for measurement. Explain the accuracy stack (scale calibration → RANSAC/PCA plane fit → parallel-plane distance → multi-frame/voxel averaging). Mention the unit-tested pure-Swift core.

**16:00–20:00 — Limitations, path-to-tighter, Q&A.** Be the person who knows the limits cold.

## Architecture (draw this)

```
        ┌── RoomPlan (optional) ──┐         ┌── ARKit LiDAR (measurement) ──┐
Scan ──▶│ CapturedRoom            │   +     │ scene reconstruction mesh      │
        │  • object labels        │         │  (meshWithClassification)      │
        │  • parametric USDZ      │         └──────────────┬─────────────────┘
        └─────────────────────────┘                        │ classified points
                                                            ▼
                                            MeshCollector → ClassifiedCloud
                                                            ▼
                            RANSAC + PCA plane fit (walls/floor/ceiling)
                                                            ▼
                    ClosetSolver: opposing-plane distance → W · D · H (+ ±)
                                                            ▼
                          Scale calibration · 1/16" formatting · CSV log
```

Why this split: RoomPlan's parametric walls are only ±2–5 cm (it even forces a uniform ~16 cm wall thickness), so they're sketch-grade. Raw LiDAR plane-fitting averages thousands of points, so its *surface* estimate is low-mm. We never report a RoomPlan number.

## Why the accuracy techniques work (know these)

- **Parallel-plane distance, not corner points.** Measuring the perpendicular distance between two fitted wall planes averages every inlier on both walls, so the estimate's standard error is far below per-point noise (~1/√N).
- **RANSAC + PCA.** RANSAC rejects clutter/mixed surfaces; PCA (total least squares) is the optimal plane through the inliers.
- **Voxel averaging.** Points are averaged per ~1 cm voxel — denoises and keeps the cloud uniform so no dense patch dominates the fit.
- **Scale calibration.** The dominant *systematic* error is a multiplicative scale bias (0.5–2%). A least-squares slope through the origin over (measured, true) references removes it. That's the single biggest accuracy win.
- **Confidence that doesn't lie.** The ± combines the (tiny) statistical standard error with a systematic scale-uncertainty term, because ARKit scale — not point noise — is the real limit.

## Q&A prep

**"Why can't you hit 1/16"?"** iPhone LiDAR is a 576-point time-of-flight sensor; per-point precision is ~±5–10 mm at close range, and ARKit adds scale drift. Peer-reviewed best flat-surface results are ~6–8 mm RMSE. We beat per-point noise with plane-fitting and calibration and reach low single-digit mm, but 1.6 mm is below the sensor's resolution. Honesty about that is the right engineering answer; faking it isn't.

**"Then how is your ± sometimes ≤ 1/16"?"** The *statistical* uncertainty of a well-fit plane can be sub-mm, but I deliberately add a systematic scale term so the reported ± reflects the real limit, and I validate against a caliper-certified reference — I never claim finer than my reference.

**"Why not just use RoomPlan's dimensions?"** They're ±2–5 cm and model walls at a fixed thickness — great for a floor-plan sketch, useless for 1/16". I use RoomPlan only for the empty-room visualization and to label contents.

**"Biggest error sources in a closet?"** Dark clothing absorbs IR (sparse/noisy returns); mirrors/glossy panels create phantom depth; tight standoff forces you closer than the sensor's sweet spot; feature-poor walls degrade ARKit tracking. Mitigations: matte, well-lit closet; manual corner-snap over auto-detection; short looped trajectory to bound drift.

**"How would you get to true 1/16"?"** Per-device scale regression, a printed fiducial of certified length to lock absolute scale, more frame/scan averaging, plane-intersection corners (already done), and — to *prove* it — better ground truth than a ±1 mm laser (a tripod scanner/total station).

**"Ceiling?"** RoomPlan doesn't capture ceilings, so I derive height from the ARKit floor↔ceiling plane distance (ARKit's classification does label ceilings), falling back to wall vertical extent if the ceiling is sparse.

**"What did you reuse vs. build?"** ARKit scene reconstruction and RoomPlan are Apple frameworks. The accuracy core (RANSAC/PCA plane fit, opposing-plane solver, calibration, stats, 1/16" formatting) is my own pure-Swift, unit-tested code.
