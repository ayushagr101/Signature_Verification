clear; close all; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

dataDir    = fullfile(pwd, 'data');
resultsDir = fullfile(pwd, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

nRefs = 4;

enrolOpts = struct();
tunedFile = fullfile(resultsDir, 'tunedParams.mat');
if exist(tunedFile, 'file')
    T = load(tunedFile, 'best');
    enrolOpts.weights = T.best.weights;
    enrolOpts.kThresh = T.best.kThresh;
    fprintf('Using tuned parameters: weights [%.1f %.1f], kThresh %.2f\n', ...
            enrolOpts.weights(1), enrolOpts.weights(2), enrolOpts.kThresh);
else
    fprintf('Using default parameters - run tuneParameters to tune them.\n');
end

clfFile = fullfile(pwd, 'models', 'classifier.mat');
modes = {'dsp'};
clf = [];
if exist(clfFile, 'file')
    C = load(clfFile, 'clf');
    clf = C.clf;
    modes = {'dsp', 'ml', 'hybrid'};
    fprintf('Classifier found (%s, CV EER %.2f %%) - evaluating dsp / ml / hybrid.\n', ...
            clf.type, clf.cvEER);
else
    fprintf('No classifier found - DSP-only evaluation. Run trainClassifier to add ML.\n');
end

writers = dir(fullfile(dataDir, 'writer*'));
writers = writers([writers.isdir]);
hasImages = false;
for w = 1:numel(writers)
    if ~isempty(dir(fullfile(dataDir, writers(w).name, '*.png')))
        hasImages = true; break;
    end
end
if ~hasImages
    fprintf('No dataset found - generating a synthetic one...\n\n');
    makeSignatureDataset(dataDir, 3, 8, 5, 7);
end

E = cell(1, numel(modes));
for m = 1:numel(modes)
    o = enrolOpts;
    o.mode = modes{m};
    if ~strcmp(modes{m}, 'dsp'), o.classifier = clf; end
    fprintf('\n================ mode: %s ================\n', upper(modes{m}));
    E{m} = evaluateSystem(dataDir, nRefs, o);
end

fprintf('\n==================== SYSTEM PERFORMANCE ====================\n');
fprintf('  test samples: %d genuine, %d forged\n\n', E{1}.nGenuine, E{1}.nForged);
fprintf('  %-8s %8s %8s %8s %8s %10s %10s\n', 'mode', 'FRR%', 'FAR%', 'ACC%', ...
        'EER%', 'skilledFAR', 'randomFAR');
for m = 1:numel(modes)
    fprintf('  %-8s %8.2f %8.2f %8.2f %8.2f %10.2f %10.2f\n', modes{m}, ...
            E{m}.FRR, E{m}.FAR, E{m}.ACC, E{m}.EER, E{m}.skilledFAR, E{m}.randomFAR);
end
fprintf('============================================================\n');

P = E{end};
primaryMode = modes{end};

verifySignature(P.example.model, P.example.genuine, true);
saveas(gcf, fullfile(resultsDir, 'example_genuine.png'));
if ~isempty(P.example.forged)
    verifySignature(P.example.model, P.example.forged, true);
    saveas(gcf, fullfile(resultsDir, 'example_skilled_forgery.png'));
end

BG = [0.08 0.08 0.10];
FG = [0.92 0.92 0.94];
GR = [0.35 0.35 0.40];
CG = [0.25 0.85 0.45];
CF = [0.95 0.35 0.30];
CB = [0.30 0.75 1.00];
CM = {[0.30 0.75 1.00], [1.00 0.60 0.20], [0.25 0.85 0.45]};

gIdx = P.labels == 1; fIdx = P.labels == 0;

figure('Name', sprintf('Score distribution (%s)', primaryMode), ...
       'Color', BG, 'InvertHardcopy', 'off');
edges = 0:0.025:1;
histogram(P.scores(gIdx), edges, 'FaceColor', CG, 'EdgeColor', BG, 'FaceAlpha', 0.75);
hold on;
histogram(P.scores(fIdx), edges, 'FaceColor', CF, 'EdgeColor', BG, 'FaceAlpha', 0.75);
yl = ylim; plot([P.th(P.ke) P.th(P.ke)], yl, '--', 'Color', FG, 'LineWidth', 2);
xlabel('fused similarity score', 'Color', FG); ylabel('count', 'Color', FG);
lg = legend('genuine', 'forged', 'EER threshold', 'Location', 'northwest');
set(lg, 'TextColor', FG, 'Color', BG, 'EdgeColor', GR);
title(sprintf('Genuine vs forged score separation  [%s]', primaryMode), 'Color', FG);
grid on;
set(gca, 'Color', BG, 'XColor', FG, 'YColor', FG, 'GridColor', GR, 'GridAlpha', 0.5);
saveas(gcf, fullfile(resultsDir, 'score_distribution.png'));

figure('Name', 'FAR / FRR / ROC', 'Color', BG, 'InvertHardcopy', 'off', ...
       'Position', [100 100 1000 420]);
subplot(1,2,1);
plot(P.th, 100*P.far, 'Color', CF, 'LineWidth', 1.8); hold on;
plot(P.th, 100*P.frr, 'Color', CB, 'LineWidth', 1.8);
plot(P.th(P.ke), 100*P.far(P.ke), 'o', 'Color', FG, 'MarkerFaceColor', FG);
xlabel('threshold', 'Color', FG); ylabel('error rate (%)', 'Color', FG);
lg = legend('FAR', 'FRR', 'EER', 'Location', 'best');
set(lg, 'TextColor', FG, 'Color', BG, 'EdgeColor', GR);
title(sprintf('[%s]  EER = %.2f %%', primaryMode, P.EER), 'Color', FG); grid on;
set(gca, 'Color', BG, 'XColor', FG, 'YColor', FG, 'GridColor', GR, 'GridAlpha', 0.5);

subplot(1,2,2);
hold on;
names = cell(1, numel(modes));
for m = 1:numel(modes)
    plot(100*E{m}.far, 100*(1-E{m}.frr), 'Color', CM{m}, 'LineWidth', 2);
    names{m} = sprintf('%s  (EER %.1f%%)', modes{m}, E{m}.EER);
end
plot([0 100], [0 100], ':', 'Color', GR, 'LineWidth', 1.2);
xlabel('FAR (%)', 'Color', FG); ylabel('genuine acceptance rate (%)', 'Color', FG);
title('ROC curve', 'Color', FG); grid on; axis([0 100 0 100]);
lg = legend(names, 'Location', 'southeast');
set(lg, 'TextColor', FG, 'Color', BG, 'EdgeColor', GR);
set(gca, 'Color', BG, 'XColor', FG, 'YColor', FG, 'GridColor', GR, 'GridAlpha', 0.5);
saveas(gcf, fullfile(resultsDir, 'roc_far_frr.png'));

summary = struct();
for m = 1:numel(modes)
    summary.(modes{m}) = rmfield(E{m}, {'models', 'example'});
end
save(fullfile(resultsDir, 'results.mat'), 'summary', 'modes', 'nRefs', 'enrolOpts');
fprintf('\nFigures and results.mat saved in %s\n', resultsDir);
fprintf('Launch the GUI with:  signatureGUI\n');
