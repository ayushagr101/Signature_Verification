# A DSP-Based Bank Signature Verification System

DSP Lab project — MATLAB implementation.

**Team:** Ashish Singh (20244045), Ayush Agarwal (20244047),
Ayush Jadaun (20244048), Ayush Kaushal (20244049)

## Run it

```matlab
>> cd E:\dsp
>> main_signature_verification      % full pipeline + metrics + figures
>> signatureGUI                     % interactive front-end
```

The first run auto-generates a synthetic dataset in `data/` (3 writers ×
8 genuine + 5 skilled forgeries + 5 random forgeries) so nothing else is
needed to demo it. To use real scans instead, delete `data/` and create:

```
data/writer01/genuine_01.png ... genuine_08.png
data/writer01/forged_skilled_01.png ...
data/writer01/forged_random_01.png ...
```

## Files

| File | Role |
|---|---|
| `main_signature_verification.m` | Driver: enrol → verify → FAR/FRR/EER/ROC |
| `signatureGUI.m` | GUI: enrol writer, load test image, verify |
| `src/preprocessSignature.m` | Grayscale, median filter, Otsu, despeckle, deskew, crop, resize |
| `src/extractFeatures.m` | 121-D feature vector across 9 DSP families |
| `src/enrollUser.m` | Builds the reference model + calibrates the threshold |
| `src/signatureScore.m` | Feature distance + normalized cross-correlation fusion |
| `src/verifySignature.m` | AUTHENTIC / FORGED decision + analysis plots |
| `src/makeSignatureDataset.m` | Synthetic signature generator |

## Method

**Preprocessing** — grayscale → 3×3 median filter (impulse noise) → contrast
stretch → Otsu global threshold → polarity fix → small-blob removal →
morphological closing → principal-axis deskew → bounding-box crop →
aspect-preserving resize to a 128×256 canvas. Position, size and slant
invariance all come from this stage.

**Feature extraction** (121 features):

1. Geometric/statistical — ink density, centroid, spread, aspect, stroke
   thickness, loop count
2. 4×4 zoning densities — local ink distribution
3. Hu invariant moments (7)
4. Horizontal and vertical projection profiles — the image reduced to two
   1-D signals (32 + 16 samples)
5. Signal energy, Shannon entropy and first-difference energy of both
   profiles
6. FFT magnitude spectra of both profiles (16 + 8 harmonics) — the
   quasi-periodic rhythm of the hand
7. Radial energy bands of the 2-D FFT (8) — stroke texture
8. Haar wavelet sub-band energies, 3 levels (10) — multiresolution detail
9. Upper/lower contour signals — mean, std, skewness, kurtosis, roughness

**Matching** — each feature is divided by that writer's own standard
deviation, so naturally variable features count less. The median z-scored
distance to the reference set is mapped to a similarity through
`exp(-d/d0)`, where `d0` is the writer's mean intra-class distance. This is
fused 0.6/0.4 with the peak 2-D normalized cross-correlation between the
test image and the references (computed via FFT, on Gaussian-blurred
strokes so small displacements are tolerated).

**Decision** — the threshold is not a global constant. It is calibrated per
writer by leave-one-out scoring of the enrolment samples:
`thr = mean(LOO) − 1.4·std(LOO)`, clamped to [0.35, 0.90]. Consistent
signers get a strict threshold, erratic signers a lenient one.

**Evaluation** — FAR, FRR, accuracy, EER, score histograms and the ROC
curve, saved to `results/`.

## Toolbox dependencies

The code prefers Image Processing Toolbox functions (`medfilt2`,
`graythresh`, `bwareaopen`, `imclose`, `imrotate`, `imresize`, `bwmorph`,
`bweuler`) but every one of them has a local fallback in the same file, so
it also runs on base MATLAB and on GNU Octave. No Wavelet Toolbox is
needed — the Haar transform is implemented directly.

## Tuning

| Knob | Where | Effect |
|---|---|---|
| `opts.kThresh` | `enrollUser` | Higher = looser (fewer false rejections) |
| `opts.weights` | `enrollUser` | Feature-distance vs correlation balance |
| `opts.prep.size` | preprocessing canvas | Detail vs speed |
| `nRefs` | `main_signature_verification.m` | Specimens held on file |
