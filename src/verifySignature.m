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
bg   = [0.08 0.08 0.10];
fg   = [0.92 0.92 0.94];
gr   = [0.35 0.35 0.40];
cTst = [0.30 0.75 1.00];
cRef = [1.00 0.50 0.35];
cOk  = [0.25 0.85 0.45];
cBad = [0.95 0.35 0.30];

figure('Name', sprintf('Verification - %s', model.userId), ...
       'Color', bg, 'InvertHardcopy', 'off', 'Position', [100 100 1100 620]);

ax = subplot(2,3,1);
imshow(model.refImgs{1});
title('Reference (genuine)'); darkAxes(ax, fg, bg, gr);

ax = subplot(2,3,2);
imshow(R.B);
title('Questioned sample'); darkAxes(ax, fg, bg, gr);

ax = subplot(2,3,3);
Ov = cat(3, double(model.refImgs{1}), double(R.B), zeros(size(R.B)));
imshow(Ov);
title('Overlay  (red = ref, green = test, yellow = match)');
darkAxes(ax, fg, bg, gr);

ax = subplot(2,3,4);
plot(R.parts.projVfull, 'Color', cTst, 'LineWidth', 1.4); hold on;
[~, ~, refParts] = extractFeatures(model.refImgs{1});
plot(refParts.projVfull, '--', 'Color', cRef, 'LineWidth', 1.2);
title('Vertical projection profile'); xlabel('column'); ylabel('ink');
lg = legend('test','reference','Location','best');
set(lg, 'TextColor', fg, 'Color', bg, 'EdgeColor', gr);
grid on; axis tight; darkAxes(ax, fg, bg, gr);

ax = subplot(2,3,5);
stem(R.parts.fftV, 'filled', 'Color', cTst, 'MarkerFaceColor', cTst); hold on;
stem(refParts.fftV, 'Color', cRef);
title('FFT magnitude of profile'); xlabel('harmonic');
grid on; axis tight; darkAxes(ax, fg, bg, gr);

ax = subplot(2,3,6);
barh(1, R.score, 'FaceColor', ternary(R.isAuthentic, cOk, cBad), ...
     'EdgeColor', 'none');
hold on;
plot([model.thr model.thr], [0.5 1.5], '--', 'Color', fg, 'LineWidth', 2);
xlim([0 1]); ylim([0.5 1.5]); set(gca, 'YTick', []);
xlabel('similarity score');
title(sprintf('%s   (%.1f%% confidence)', R.decision, R.confidence), ...
      'Color', ternary(R.isAuthentic, cOk, cBad));
grid on; darkAxes(ax, fg, bg, gr);
set(get(ax, 'Title'), 'Color', ternary(R.isAuthentic, cOk, cBad));
end

function darkAxes(ax, fg, bg, gr)
set(ax, 'Color', bg, 'XColor', fg, 'YColor', fg, 'ZColor', fg, ...
        'GridColor', gr, 'MinorGridColor', gr, 'GridAlpha', 0.5);
set(get(ax, 'Title'),  'Color', fg);
set(get(ax, 'XLabel'), 'Color', fg);
set(get(ax, 'YLabel'), 'Color', fg);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
