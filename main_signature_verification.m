clear; close all; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

dataDir    = fullfile(pwd, 'data');
resultsDir = fullfile(pwd, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

writers = dir(fullfile(dataDir, 'writer*'));
writers = writers([writers.isdir]);
if isempty(writers)
    fprintf('No dataset found - generating a synthetic one...\n\n');
    makeSignatureDataset(dataDir, 3, 8, 5, 7);
    writers = dir(fullfile(dataDir, 'writer*'));
    writers = writers([writers.isdir]);
end

nRefs = 4;

allScores = [];
allLabels = [];
allTypes  = {};
allDec    = [];

models = struct('userId', {}, 'thr', {});

for w = 1:numel(writers)
    wdir = fullfile(dataDir, writers(w).name);

    gen  = dir(fullfile(wdir, 'genuine_*.png'));
    skf  = dir(fullfile(wdir, 'forged_skilled_*.png'));
    rnf  = dir(fullfile(wdir, 'forged_random_*.png'));
    gen  = fullfile(wdir, {gen.name});
    skf  = fullfile(wdir, {skf.name});
    rnf  = fullfile(wdir, {rnf.name});

    if numel(gen) < nRefs + 1
        warning('Skipping %s: not enough genuine samples.', writers(w).name);
        continue;
    end

    refs  = gen(1:nRefs);
    tests = gen(nRefs+1:end);

    fprintf('\n================ %s ================\n', writers(w).name);
    model = enrollUser(refs, writers(w).name, struct());
    models(end+1) = struct('userId', model.userId, 'thr', model.thr);

    probes = [tests, skf, rnf];
    labels = [ones(1, numel(tests)), zeros(1, numel(skf) + numel(rnf))];
    types  = [repmat({'genuine'}, 1, numel(tests)), ...
              repmat({'skilled'}, 1, numel(skf)), ...
              repmat({'random'},  1, numel(rnf))];

    for i = 1:numel(probes)
        R = verifySignature(model, probes{i}, false);
        allScores(end+1) = R.score;
        allLabels(end+1) = labels(i);
        allTypes{end+1}  = types{i};
        allDec(end+1)    = R.isAuthentic;
    end

    if w == 1
        verifySignature(model, tests{1}, true);
        saveas(gcf, fullfile(resultsDir, 'example_genuine.png'));
        verifySignature(model, skf{1}, true);
        saveas(gcf, fullfile(resultsDir, 'example_skilled_forgery.png'));
        firstModel = model;
    end
end

gIdx = allLabels == 1;
fIdx = allLabels == 0;

FRR = 100 * mean(~allDec(gIdx));
FAR = 100 * mean( allDec(fIdx));
ACC = 100 * mean(allDec == allLabels);

fprintf('\n==================== SYSTEM PERFORMANCE ====================\n');
fprintf('  test samples          : %d genuine, %d forged\n', ...
        sum(gIdx), sum(fIdx));
fprintf('  FRR (false rejection) : %.2f %%\n', FRR);
fprintf('  FAR (false acceptance): %.2f %%\n', FAR);
fprintf('  overall accuracy      : %.2f %%\n', ACC);

isSk = strcmp(allTypes, 'skilled');
isRn = strcmp(allTypes, 'random');
fprintf('  mean score  genuine   : %.3f\n', mean(allScores(gIdx)));
if any(isSk)
    fprintf('  mean score  skilled   : %.3f  (accepted %.1f %%)\n', ...
        mean(allScores(isSk)), 100*mean(allDec(isSk)));
end
if any(isRn)
    fprintf('  mean score  random    : %.3f  (accepted %.1f %%)\n', ...
        mean(allScores(isRn)), 100*mean(allDec(isRn)));
end

th  = linspace(0, 1, 501);
far = zeros(size(th)); frr = zeros(size(th));
for k = 1:numel(th)
    far(k) = mean(allScores(fIdx) >= th(k));
    frr(k) = mean(allScores(gIdx) <  th(k));
end
[~, ke] = min(abs(far - frr));
EER = 100 * (far(ke) + frr(ke)) / 2;
fprintf('  equal error rate (EER): %.2f %%  at threshold %.3f\n', ...
        EER, th(ke));
fprintf('============================================================\n');

figure('Name','Score distribution','Color','w');
edges = 0:0.025:1;
histogram(allScores(gIdx), edges, 'FaceColor', [0.2 0.7 0.3], ...
          'FaceAlpha', 0.65); hold on;
histogram(allScores(fIdx), edges, 'FaceColor', [0.85 0.25 0.2], ...
          'FaceAlpha', 0.65);
yl = ylim; plot([th(ke) th(ke)], yl, 'k--', 'LineWidth', 2);
xlabel('fused similarity score'); ylabel('count');
legend('genuine','forged','EER threshold','Location','northwest');
title('Genuine vs forged score separation'); grid on;
saveas(gcf, fullfile(resultsDir, 'score_distribution.png'));

figure('Name','FAR / FRR / ROC','Color','w');
subplot(1,2,1);
plot(th, 100*far, 'r', 'LineWidth', 1.6); hold on;
plot(th, 100*frr, 'b', 'LineWidth', 1.6);
plot(th(ke), 100*far(ke), 'ko', 'MarkerFaceColor', 'k');
xlabel('threshold'); ylabel('error rate (%)');
legend('FAR','FRR','EER','Location','best');
title(sprintf('EER = %.2f %%', EER)); grid on;

subplot(1,2,2);
plot(100*far, 100*(1-frr), 'b', 'LineWidth', 1.8); hold on;
plot([0 100],[0 100],'k:');
xlabel('FAR (%)'); ylabel('genuine acceptance rate (%)');
title('ROC curve'); grid on; axis([0 100 0 100]);
saveas(gcf, fullfile(resultsDir, 'roc_far_frr.png'));

save(fullfile(resultsDir, 'results.mat'), ...
     'allScores', 'allLabels', 'allTypes', 'allDec', 'FAR', 'FRR', ...
     'ACC', 'EER', 'models');
fprintf('\nFigures and results.mat saved in %s\n', resultsDir);
fprintf('Launch the GUI with:  signatureGUI\n');
