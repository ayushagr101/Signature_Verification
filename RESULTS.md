# Results on CEDAR

Dataset: CEDAR signature database, 55 writers x 24 genuine x 24 skilled forgeries.
Split by writer: writers 1-35 for training/tuning, writers 36-55 held out for
evaluation. No test writer is seen during training or tuning. 6 reference
specimens per writer; 18 genuine + 24 forged probes per test writer.

Environment: MATLAB R2026a, no Image Processing or Statistics toolboxes
(all local fallbacks in use; classifier = built-in logistic regression).

## Classifier (writer-independent, trained on writers 1-35)

| | |
|---|---|
| training pairs | 1680 (840 genuine, 840 forged) |
| pair feature dimension | 142 |
| leave-one-writer-out EER | **19.76 %** |
| leave-one-writer-out accuracy @ 0.5 | 79.58 % |

## Tuned parameters (writers 1-35)

| parameter | value |
|---|---|
| fusion weights (feature / correlation) | 0.2 / 0.8 |
| kThresh, dsp mode | 1.75 |
| kThresh, ml mode | 1.50 |
| kThresh, hybrid mode | 1.50 |
| threshold clamp | [0.05, 0.95] |

## Verification on the 20 held-out writers (360 genuine, 480 skilled forgeries)

| mode | FRR % | FAR % | accuracy % | EER % |
|---|---|---|---|---|
| dsp | 18.33 | 11.46 | **85.60** | 23.54 |
| ml | 18.89 | 16.46 | 82.50 | 16.67 |
| hybrid | 18.89 | 12.71 | 84.64 | **16.56** |

- **EER** (threshold-free separability): the ML and hybrid modes are clearly
  stronger, 16.6 % vs 23.5 % for DSP alone. See `results/roc_far_frr.png`.
- **Operating point** (per-writer calibrated thresholds): all three are within
  ~1 point of each other at ~85 %. DSP-only retains a slight edge because its
  cross-correlation term lives on a writer-specific scale that the per-writer
  threshold calibration exploits directly.
- Hybrid gives the best of both: near-best accuracy at the operating point with
  far more headroom if the bank wants to move the FAR/FRR trade-off.

Figures: `results/score_distribution.png`, `results/roc_far_frr.png`,
`results/example_genuine.png`, `results/example_skilled_forgery.png`,
`results/tuning.png`, `results/classifier_cv.png`.

## Reproduce

```matlab
importCEDAR('path\to\signatures', 'data_train', 1:35)
importCEDAR('path\to\signatures', 'data', 36:55)
trainClassifier
tuneParameters
main_signature_verification
```
Total runtime on a laptop without toolboxes: roughly 60 minutes.
