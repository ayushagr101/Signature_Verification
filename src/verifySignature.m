function R = verifySignature(model, testImage, showPlot)

if nargin < 3, showPlot = false; end

[B, info] = preprocessSignature(testImage, model.prep);
[f, ~, parts] = extractFeatures(B);
S = signatureScore(model, f, B);

isAuth = S.score >= model.thr;

if isAuth
    conf = (S.score - model.thr) / max(1 - model.thr, eps);
else
    conf = (model.thr - S.score) / max(model.thr, eps);
end
conf = min(max(conf, 0), 1) * 100;

R.userId      = model.userId;
R.decision    = ternary(isAuth, 'AUTHENTIC', 'FORGED');
R.isAuthentic = isAuth;
R.score       = S.score;
R.threshold   = model.thr;
R.confidence  = conf;
R.featureSim  = S.featureSim;
R.corrSim     = S.corrSim;
R.distance    = S.featureDistance;
R.B           = B;
R.f           = f;
R.parts       = parts;
R.prepInfo    = info;

fprintf('\n--- Signature verification: account %s ---\n', model.userId);
fprintf('  feature similarity : %.3f  (normalized distance %.3f)\n', ...
        S.featureSim, S.featureDistance);
fprintf('  cross-correlation  : %.3f\n', S.corrSim);
fprintf('  fused score        : %.3f   (threshold %.3f)\n', ...
        S.score, model.thr);
fprintf('  DECISION           : %s   (confidence %.1f%%)\n\n', ...
        R.decision, conf);

if showPlot
    plotVerification(model, R);
end
end

function plotVerification(model, R)
figure('Name', sprintf('Verification - %s', model.userId), ...
       'Color', 'w', 'Position', [100 100 1100 620]);

subplot(2,3,1);
imshow(~model.refImgs{1}); title('Reference (genuine)');

subplot(2,3,2);
imshow(~R.B);
title(sprintf('Questioned sample'));

subplot(2,3,3);
Ov = cat(3, double(~model.refImgs{1}), double(~R.B), ones(size(R.B)));
imshow(Ov); title('Overlay  (red = ref, green = test)');

subplot(2,3,4);
plot(R.parts.projVfull, 'b', 'LineWidth', 1.2); hold on;
[~, ~, refParts] = extractFeatures(model.refImgs{1});
plot(refParts.projVfull, 'r--', 'LineWidth', 1);
title('Vertical projection profile'); xlabel('column'); ylabel('ink');
legend('test','reference','Location','best'); grid on; axis tight;

subplot(2,3,5);
stem(R.parts.fftV, 'b', 'filled'); hold on;
stem(refParts.fftV, 'r');
title('FFT magnitude of profile'); xlabel('harmonic'); grid on; axis tight;

subplot(2,3,6);
barh(1, R.score, 'FaceColor', ternary(R.isAuthentic, [0.2 0.7 0.3], [0.85 0.25 0.2]));
hold on;
plot([model.thr model.thr], [0.5 1.5], 'k--', 'LineWidth', 2);
xlim([0 1]); ylim([0.5 1.5]); set(gca, 'YTick', []);
xlabel('similarity score');
title(sprintf('%s   (%.1f%% confidence)', R.decision, R.confidence));
grid on;
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
