# VALIDATION — how we test accuracy to 1/16" (and report it honestly)

This is the graded centerpiece. The goal is **not** to claim "accurate to 1/16 inch." It is to *measure* how accurate the app is, against trustworthy ground truth, and state it precisely — including where it falls short and how we'd close the gap.

## The metrology golden rule (say this first)

You cannot validate a **1/16" (1.588 mm)** tolerance unless your ground truth is ~4–10× better than that — roughly **±0.2–0.4 mm**. This is the 4:1 Test Accuracy Ratio. Consequence: a ±1 mm laser meter is **not** an adequate *statistical* reference for a 1.6 mm target (it's only marginally better). So we use two references for two jobs:

- **Caliper-certified reference box → statistical ground truth** (±0.1 mm). Drives the numbers on the slide.
- **Laser distance meter (±1 mm) → the live side-by-side** demo. Persuasive on stage, but we're honest that it's only a ~1 mm reference.

## Kit

| Item | ~Cost | Role |
|---|---|---|
| Digital caliper (0.01 mm resolution) | $25 | Certify the box faces & small references to ±0.1 mm |
| Rigid reference box (melamine / Baltic-birch) with faces ~150 / 600 / 1200 / 2000 mm | $30–60 | The statistical ground truth (bias + linearity) |
| Class I steel tape | $15 | Certify the long span of the box |
| Laser distance meter (Leica DISTO ±1 mm or Bosch GLM ±1.5 mm) | $100 | Live side-by-side demo |
| Blue painter's tape | $5 | Mark identical measurement endpoints |

## Reference-box certification worksheet

Certify each dimension **once**, carefully, and treat those numbers as truth. Fill this in and keep it with the study.

| Face / span | Nominal | Caliper/tape reading 1 | reading 2 | reading 3 | **Certified true (mm)** |
|---|---|---|---|---|---|
| Short A | 150 | | | | |
| Medium B | 600 | | | | |
| Long C | 1200 | | | | |
| Long D | 2000 | | | | |

Certified true = mean of the three readings (they should agree to ~0.1 mm; if not, re-measure).

## The study (Gage R&R / MSA)

Pre-collect this the night before the interview; use the live slot for one fresh demo. ~55 data points.

**A. Repeatability (precision).** Mark the endpoints of each closet dimension with tape crosses so every scan measures the identical span.
- Width, Depth, Height → **10 independent re-scans each** (re-scan every time; never re-read one scan). = 30 points.

**B. Bias / linearity (accuracy vs. known size).** Measure the box's certified faces.
- 5 reference sizes × **5 scans each** = 25 points. Spanning small→large exposes scale error (a fixed % looks tiny in mm at 150 mm and large at 2000 mm).

**C. Controls to state (shows rigor).** Same lighting, same start corner, ~20 °C, phone warmed up and fully tracked ("Tracking OK"), matte surfaces, no mirrors/glass in view.

## Running it in the app

1. **Calibrate first.** Manual Measure the box's certified references, then in **Scale Calibration** enter (true mm, app-measured mm) for several sizes and **Apply**. Best practice: calibrate on some references, then **validate on the others** (and on the real closet with the laser) so you never report accuracy on the data you tuned on.
2. **Collect trials.** For each measurement, use **Scan** (auto) or **Manual Precision Measure**, then **Log** it with the certified/laser true value. Every trial is stored.
3. **Export.** Validation Log ▸ *Prepare CSV export* ▸ *Share CSV*. Columns: `timestamp,label,method,true_mm,measured_mm,error_mm,device`. See [validation_template.csv](validation_template.csv).

## Statistics we report (all in the app + your slide)

For each dimension, error `e = measured − true` (mm):

| Metric | Meaning |
|---|---|
| **Bias** (mean signed e) | Systematic over/under-measure — **correctable** by calibration |
| **MAE** | Typical error magnitude |
| **RMSE** | Overall accuracy (bias + spread) |
| **σ (repeatability)** | Precision independent of bias — the **fundamental** part |
| **Max \|error\|** | Worst case — the honest number that kills over-claims |
| **% within ±1.588 mm** | The direct answer to "is it within 1/16"?" |
| **95% bound** (\|bias\| + 1.96σ) | Defensible "±X mm at 95%" claim |
| **P/T ratio** (5.15σ / tolerance width) | <30% acceptable, <10% excellent (industrial MSA language) |

## Results table (fill with real numbers)

| Dimension / Ref | True (mm) | N | Bias | MAE | RMSE | σ | Max | % ≤1/16" |
|---|---|---|---|---|---|---|---|---|
| Closet width | | 10 | | | | | | |
| Closet height | | 10 | | | | | | |
| Closet depth | | 10 | | | | | | |
| Ref 150 mm | 150.0 | 5 | | | | | | |
| Ref 600 mm | 600.0 | 5 | | | | | | |
| Ref 1200 mm | 1200.0 | 5 | | | | | | |
| **Overall** | — | | | | | | | |

Two charts (build with the repo's data or a notebook):
1. **Error vs. size** scatter with a shaded ±1.588 mm band + trend line (reveals scale error).
2. **Signed-error histogram** with the ±1/16" band overlaid.

## Honest framing (the winning move)

Template — fill with your data:

> "Against a caliper-certified reference, the app achieved **bias −0.1 mm**, **σ = 1.0 mm**, **RMSE 1.0 mm**, **max 3.1 mm**. **84% of measurements fell within 1/16"; our 95% bound is ±2.0 mm.** We do not hit 1/16" on every span — particularly the longest ones, where scale error accumulates. iPhone LiDAR's physical floor is ~±5 mm per point, and we beat that by plane-fitting thousands of points; but 1.6 mm is below the sensor's resolution. Here's the path to close the gap."

Path-to-tighter (know this cold):
1. Calibrate out bias with a per-device scale regression (measured vs true).
2. Anchor absolute scale with a printed fiducial of certified length (`ARReferenceImage.physicalSize`).
3. Average more frames / multiple scans (random error falls ~1/√N).
4. Fit planes and intersect them for corners instead of trusting single points (this app already does this).
5. Upgrade ground truth (total station / tripod scanner) to *prove* sub-mm gains.

Honesty principles to voice: never claim finer than your reference; report **max and % in tolerance**, not just the flattering mean; separate **bias (fixable) from σ (fundamental)**; put a **confidence level** on every ± claim.

## Live demo script (the money moment)

1. Pre-mark a wall span with two tape crosses.
2. Fire the **laser** → read aloud, write on the whiteboard (e.g. 1203.6 mm).
3. Run the app on the same span → read the result (e.g. 1204.4 mm).
4. Compute the **delta live** (+0.8 mm) against the ±1.588 mm target.
5. Repeat once to show **repeatability** in real time.
6. Then show the app on a **caliper-certified small reference** — where you have sub-mm truth and it looks its best.
7. Backup: your pre-collected dataset + a screen-recording of a good scan, in case the live scan misbehaves.
