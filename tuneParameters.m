function best = tuneParameters(tuneDir, nRefs)

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));

if nargin < 1 || isempty(tuneDir)
    tuneDir = fullfile(root, 'data_train');
    if ~exist(tuneDir, 'dir'), tuneDir = fullfile(root, 'data_tune'); end
end
if nargin < 2 || isempty(nRefs),   nRefs   = 6; end

resultsDir = fullfile(root, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

writers = dir(fullfile(tuneDir, 'writer*'));
writers = writers([writers.isdir]);
if isempty(writers)
    fprintf('No tuning set found - generating one (separate seed from data/)...\n');
    makeSignatureDataset(tuneDir, 6, 8, 5, 11);
    writers = dir(fullfile(tuneDir, 'writer*'));
    writers = writers([writers.isdir]);
end

W1 = 0:0.1:1;
K  = 0:0.25:6;
minThr = 0.05; maxThr = 0.95;

fprintf('\nCollecting score components for %d writers...\n', numel(writers));
data = struct('looF', {}, 'looC', {}, 'pF', {}, 'pC', {}, 'lab', {});

for w = 1:numel(writers)
    wdir = fullfile(tuneDir, writers(w).name);
    gen  = dir(fullfile(wdir, 'genuine_*.png'));
    frg  = dir(fullfile(wdir, 'forged_*.png'));
    gen  = fullfile(wdir, {gen.name});
    frg  = fullfile(wdir, {frg.name});
    if numel(gen) < nRefs + 1
        warning('Skipping %s: not enough genuine samples.', writers(w).name);
        continue;
    end

    model = enrollUser(gen(1:nRefs), writers(w).name, struct());

    L = looScores(model);
    looF = [L.featureSim]; looC = [L.corrSim];

    probes = [gen(nRefs+1:end), frg];
    lab    = [ones(1, numel(gen) - nRefs), zeros(1, numel(frg))];
    pF = zeros(size(probes)); pC = zeros(size(probes));
    for i = 1:numel(probes)
        B = preprocessSignature(probes{i}, model.prep);
        f = extractFeatures(B);
        S = signatureScore(model, f, B);
        pF(i) = S.featureSim; pC(i) = S.corrSim;
    end

    data(end+1) = struct('looF', looF, 'looC', looC, 'pF', pF, 'pC', pC, 'lab', lab);
end

nW = numel(W1); nK = numel(K);
FAR  = zeros(nW, nK); FRR = zeros(nW, nK); HTER = zeros(nW, nK);
EER  = zeros(nW, 1);

fprintf('Sweeping %d weight settings x %d threshold settings...\n', nW, nK);
for a = 1:nW
    w1 = W1(a); w2 = 1 - w1;

    allS = []; allL = [];
    for d = 1:numel(data)
        allS = [allS, w1*data(d).pF + w2*data(d).pC];
        allL = [allL, data(d).lab];
    end
    EER(a) = equalErrorRate(allS, allL);

    for b = 1:nK
        k = K(b);
        acc = false(size(allL)); idx = 0;
        for d = 1:numel(data)
            loo = w1*data(d).looF + w2*data(d).looC;
            thr = mean(loo) - k*std(loo);
            thr = min(max(thr, minThr), maxThr);
            sc  = w1*data(d).pF + w2*data(d).pC;
            n   = numel(sc);
            acc(idx+1:idx+n) = sc >= thr;
            idx = idx + n;
        end
        FAR(a,b)  = mean(acc(allL == 0));
        FRR(a,b)  = mean(~acc(allL == 1));
        HTER(a,b) = (FAR(a,b) + FRR(a,b)) / 2;
    end
end

[~, ia] = min(EER);
[hmin, ib] = min(HTER(ia, :));
[gmin, gi] = min(HTER(:));
[ga, gb] = ind2sub(size(HTER), gi);

best.weights  = [W1(ga), 1 - W1(ga)];
best.kThresh  = K(gb);
best.minThr   = minThr;
best.maxThr   = maxThr;
best.HTER     = gmin;
best.FAR      = FAR(ga, gb);
best.FRR      = FRR(ga, gb);
best.EER      = EER(ga);
best.grid     = struct('W1', W1, 'K', K, 'FAR', FAR, 'FRR', FRR, ...
                       'HTER', HTER, 'EER', EER);
best.tunedOn  = tuneDir;
best.tunedAt  = datestr(now, 'yyyy-mm-dd HH:MM:SS');

fprintf('\n==================== TUNING RESULT ====================\n');
fprintf('  tuned on           : %s  (%d writers)\n', tuneDir, numel(data));
fprintf('  best-EER weights   : [%.1f %.1f]  ->  EER %.2f %%\n', ...
        W1(ia), 1-W1(ia), 100*EER(ia));
fprintf('     with kThresh %.2f ->  HTER %.2f %%\n', K(ib), 100*hmin);
fprintf('  best-HTER setting  : weights [%.1f %.1f], kThresh %.2f\n', ...
        best.weights(1), best.weights(2), best.kThresh);
fprintf('     FAR %.2f %%   FRR %.2f %%   HTER %.2f %%\n', ...
        100*best.FAR, 100*best.FRR, 100*best.HTER);
fprintf('=======================================================\n');
fprintf('  current defaults   : weights [0.6 0.4], kThresh 1.40\n');
a0 = find(abs(W1 - 0.6) < 1e-9); b0 = find(abs(K - 1.4) < 0.13, 1);
if ~isempty(a0) && ~isempty(b0)
    fprintf('     nearest grid point -> HTER %.2f %%\n', 100*HTER(a0, b0));
end

save(fullfile(resultsDir, 'tunedParams.mat'), 'best');
fprintf('\nSaved results/tunedParams.mat - main_signature_verification will use it.\n');

BG = [0.08 0.08 0.10]; FG = [0.92 0.92 0.94]; GR = [0.35 0.35 0.40];
figure('Name', 'Parameter tuning', 'Color', BG, 'InvertHardcopy', 'off', ...
       'Position', [120 120 1000 420]);

subplot(1,2,1);
imagesc(K, W1, 100*HTER); hold on;
plot(K(gb), W1(ga), 'o', 'MarkerSize', 12, 'LineWidth', 2, 'Color', FG);
plot(min(1.4, max(K)), 0.6, 'x', 'MarkerSize', 12, 'LineWidth', 2, 'Color', [1 0.6 0.2]);
set(gca, 'YDir', 'normal', 'Color', BG, 'XColor', FG, 'YColor', FG);
colormap(gca, flipud(parula));
cb = colorbar; set(cb, 'Color', FG); ylabel(cb, 'HTER (%)', 'Color', FG);
xlabel('kThresh (threshold tightness)', 'Color', FG);
ylabel('feature weight  (correlation weight = 1 - this)', 'Color', FG);
title('Half total error rate over the parameter grid', 'Color', FG);
lg = legend('best', 'current default', 'Location', 'southoutside', ...
            'Orientation', 'horizontal');
set(lg, 'TextColor', FG, 'Color', BG, 'EdgeColor', GR);

subplot(1,2,2);
plot(W1, 100*EER, '-o', 'Color', [0.30 0.75 1.00], 'LineWidth', 1.8, ...
     'MarkerFaceColor', [0.30 0.75 1.00]); hold on;
plot(W1(ia), 100*EER(ia), 'o', 'MarkerSize', 12, 'LineWidth', 2, 'Color', FG);
xlabel('feature weight', 'Color', FG); ylabel('EER (%)', 'Color', FG);
title('Threshold-free error vs fusion weight', 'Color', FG);
grid on;
set(gca, 'Color', BG, 'XColor', FG, 'YColor', FG, 'GridColor', GR, 'GridAlpha', 0.5);
saveas(gcf, fullfile(resultsDir, 'tuning.png'));
end

function eer = equalErrorRate(scores, labels)
th = linspace(0, 1, 501);
far = zeros(size(th)); frr = zeros(size(th));
for k = 1:numel(th)
    far(k) = mean(scores(labels == 0) >= th(k));
    frr(k) = mean(scores(labels == 1) <  th(k));
end
[~, i] = min(abs(far - frr));
eer = (far(i) + frr(i)) / 2;
end
