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

## Registering a customer

Registration (enrolment) happens once, when the account is opened. The
customer gives 3–6 specimen signatures; the system reduces them to a
statistical model stored under `models/<accountId>.mat`. Later, any cheque
is checked against that stored model.

```matlab
>> registerPerson('ACC-1001', 'data/writer01')   % folder of specimens
>> registerPerson('ACC-1002')                    % or pick files in a dialog

>> listRegistered                                % who is on file

>> R = checkSignature('ACC-1001', 'cheque_scan.png', true);
>> R.decision      % 'AUTHENTIC' or 'FORGED'
>> R.score, R.threshold, R.confidence
```

What the model actually stores: the feature matrix of the specimens, the
per-feature mean and standard deviation (that writer's natural variability),
the intra-class distance scale `d0`, the calibrated threshold, and the
preprocessed specimen images (needed by the cross-correlation term).

## Files

| File | Role |
|---|---|
| `registerPerson.m` | Enrol an account and save its model to `models/` |
| `checkSignature.m` | Verify a questioned signature against a saved account |
| `listRegistered.m` | List enrolled accounts |
| `main_signature_verification.m` | Driver: enrol → verify → FAR/FRR/EER/ROC |
| `signatureGUI.m` | GUI: enrol writer, load test image, verify |
| `src/preprocessSignature.m` | Grayscale, median filter, Otsu, despeckle, deskew, crop, resize |
| `src/extractFeatures.m` | 137-D feature vector across 9 DSP families |
| `src/enrollUser.m` | Builds the reference model + calibrates the threshold |
| `src/classStats.m`, `src/looScores.m` | Per-writer statistics and leak-free leave-one-out scoring |
| `src/evaluateSystem.m` | Enrol → verify → FAR/FRR/EER for one scoring mode |
| `src/classifierScore.m` | Probability from the trained pair classifier |
| `trainClassifier.m` | Writer-independent classifier on pair difference vectors |
| `tuneParameters.m` | Grid-search fusion weights and threshold tightness |
| `importCEDAR.m` | Convert the CEDAR database into the project layout |
| `src/signatureScore.m` | Feature distance + normalized cross-correlation fusion |
| `src/verifySignature.m` | AUTHENTIC / FORGED decision + analysis plots |
| `src/makeSignatureDataset.m` | Synthetic signature generator |

## Method

**Preprocessing** — grayscale → 3×3 median filter (impulse noise) → contrast
stretch → Otsu global threshold → polarity fix → small-blob removal →
morphological closing → principal-axis deskew → bounding-box crop →
aspect-preserving resize to a 128×256 canvas. Position, size and slant
invariance all come from this stage.

**Feature extraction** (137 features):

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
`thr = mean(LOO) − k·std(LOO)`, clamped to [0.05, 0.95], where the LOO statistics (σ, d₀) are rebuilt from the other references each time so the held-out sample is not favoured. Consistent
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

## Tuning the global parameters

The fusion weights and threshold tightness are the only hand-set numbers in
the system. `tuneParameters` grid-searches them on a **separate** tuning set
(`data_tune/`, generated with a different seed) so the evaluation numbers
from `main_signature_verification` stay honest:

```matlab
>> tuneParameters                   % writes results/tunedParams.mat + tuning.png
>> main_signature_verification      % now picks up the tuned values automatically
```

It sweeps feature weight 0..1 and `kThresh` 0..3, reporting FAR / FRR / HTER
per grid point and the threshold-free EER per weight setting.

## Adding the ML classifier (writer-independent)

The DSP system is *writer-dependent*: each account has its own template and
nothing is learned across writers. `trainClassifier` adds a
*writer-independent* layer on top of the same DSP features:

1. For every (enrolled model, test signature) pair it builds a 142-D
   **difference vector** — the z-scored |f_test − μ_ref| for all 137 features,
   plus min/median/max reference distance, feature similarity and
   cross-correlation.
2. It trains one classifier on those vectors: label 1 = genuine pair,
   0 = forgery pair. RBF-SVM (`fitcsvm`, Statistics Toolbox) when available,
   otherwise a built-in L2-regularised logistic regression.
3. Because the classifier learns "how do genuine pairs differ from forged
   pairs" *in general*, a new customer needs no retraining — enrol as usual.

```matlab
>> trainClassifier                  % trains on data_train/ (synthetic, seed 23)
>> main_signature_verification      % now reports dsp / ml / hybrid side by side
```

Three scoring modes exist from then on (`opts.mode` in `enrollUser`):

| mode | score |
|---|---|
| `dsp` | 0.6·featureSim + 0.4·corrSim (original) |
| `ml` | classifier probability |
| `hybrid` | mean of the two (default once a classifier exists) |

The per-writer leave-one-out threshold calibration works unchanged in every
mode. `trainClassifier` reports **leave-one-writer-out** EER, which is the
honest number for a writer-independent model.

### Real data (CEDAR)

Synthetic forgeries come from the same generator as the genuine samples, so a
classifier trained on them learns the generator, not real forgers. For
meaningful ML numbers use the CEDAR database (55 writers × 24 genuine × 24
skilled forgeries, free from cedar.buffalo.edu or the Kaggle mirror):

```matlab
>> importCEDAR('C:\path\to\signatures', 'data_train', 1:35)   % training writers
>> importCEDAR('C:\path\to\signatures', 'data',       36:55)  % held-out writers
>> trainClassifier('data_train', 6)
>> main_signature_verification
```

The train/test split is by **writer**, so no test writer is ever seen during
training.
