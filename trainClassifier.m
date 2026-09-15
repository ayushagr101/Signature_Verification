function clf = trainClassifier(trainDir, nRefs, method)

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));

if nargin < 1 || isempty(trainDir), trainDir = fullfile(root, 'data_train'); end
if nargin < 2 || isempty(nRefs),    nRefs    = 6; end
if nargin < 3 || isempty(method),   method   = 'auto'; end

modelDir = fullfile(root, 'models');
if ~exist(modelDir, 'dir'), mkdir(modelDir); end
resultsDir = fullfile(root, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

writers = dir(fullfile(trainDir, 'writer*'));
writers = writers([writers.isdir]);
if isempty(writers)
    fprintf('No training set found - generating one (seed 23, separate from data/)...\n');
    makeSignatureDataset(trainDir, 8, 8, 6, 23);
    writers = dir(fullfile(trainDir, 'writer*'));
    writers = writers([writers.isdir]);
end

fprintf('\nBuilding pair features from %d training writers...\n', numel(writers));
perWriter = struct('X', {}, 'y', {}, 'name', {});

for w = 1:numel(writers)
    wdir = fullfile(trainDir, writers(w).name);
    gen  = dir(fullfile(wdir, 'genuine_*.png'));
    frg  = dir(fullfile(wdir, 'forged_*.png'));
    gen  = fullfile(wdir, {gen.name});
    frg  = fullfile(wdir, {frg.name});
    if numel(gen) < nRefs + 1
        warning('Skipping %s: not enough genuine samples.', writers(w).name);
        continue;
    end

    model = enrollUser(gen(1:nRefs), writers(w).name, struct());

    probes = [gen(nRefs+1:end), frg];
    y      = [ones(numel(gen) - nRefs, 1); zeros(numel(frg), 1)];
    X      = [];
    for i = 1:numel(probes)
        B = preprocessSignature(probes{i}, model.prep);
        f = extractFeatures(B);
        S = signatureScore(model, f, B);
        X(i, :) = S.pairFeat(:)';
    end

    L = looScores(model);
    for i = 1:numel(L)
        X(end+1, :) = L(i).pairFeat(:)';
        y(end+1, 1) = 1;
    end

    perWriter(end+1) = struct('X', X, 'y', y, 'name', writers(w).name);
end

nW = numel(perWriter);
if nW < 2
    error('trainClassifier:tooFew', 'Need at least 2 training writers.');
end

fprintf('Leave-one-writer-out cross-validation (%d folds)...\n', nW);
cvScores = []; cvLabels = [];
for k = 1:nW
    Xtr = []; ytr = [];
    for j = 1:nW
        if j == k, continue; end
        Xtr = [Xtr; perWriter(j).X];
        ytr = [ytr; perWriter(j).y];
    end
    c = fitModel(Xtr, ytr, method, false);
    p = classifierScore(c, perWriter(k).X);
    cvScores = [cvScores; p(:)];
    cvLabels = [cvLabels; perWriter(k).y(:)];
end
cvEER = equalErrorRate(cvScores', cvLabels');
cvACC = mean((cvScores >= 0.5) == (cvLabels == 1));

Xall = []; yall = [];
for j = 1:nW
    Xall = [Xall; perWriter(j).X];
    yall = [yall; perWriter(j).y];
end
clf = fitModel(Xall, yall, method, true);
clf.featDim   = size(Xall, 2);
clf.nTrain    = numel(yall);
clf.nWriters  = nW;
clf.trainedOn = trainDir;
clf.trainedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');
clf.cvEER     = 100 * cvEER;
clf.cvACC     = 100 * cvACC;

save(fullfile(modelDir, 'classifier.mat'), 'clf');

fprintf('\n==================== CLASSIFIER ====================\n');
fprintf('  type                 : %s\n', clf.type);
fprintf('  training pairs       : %d  (%d genuine, %d forged)\n', ...
        numel(yall), sum(yall == 1), sum(yall == 0));
fprintf('  pair feature dim     : %d\n', clf.featDim);
fprintf('  writers              : %d\n', nW);
fprintf('  leave-one-writer-out : EER %.2f %%   accuracy@0.5 %.2f %%\n', ...
        clf.cvEER, clf.cvACC);
fprintf('====================================================\n');
fprintf('Saved models/classifier.mat - main_signature_verification and the GUI\n');
fprintf('will now evaluate dsp / ml / hybrid modes.\n');

BG = [0.08 0.08 0.10]; FG = [0.92 0.92 0.94]; GR = [0.35 0.35 0.40];
figure('Name', 'Classifier cross-validation', 'Color', BG, ...
       'InvertHardcopy', 'off', 'Position', [140 140 520 400]);
edges = 0:0.04:1;
histogram(cvScores(cvLabels == 1), edges, 'FaceColor', [0.25 0.85 0.45], ...
          'EdgeColor', BG, 'FaceAlpha', 0.75); hold on;
histogram(cvScores(cvLabels == 0), edges, 'FaceColor', [0.95 0.35 0.30], ...
          'EdgeColor', BG, 'FaceAlpha', 0.75);
xlabel('classifier probability of genuine', 'Color', FG);
ylabel('count', 'Color', FG);
title(sprintf('Leave-one-writer-out   EER %.2f %%', clf.cvEER), 'Color', FG);
lg = legend('genuine', 'forged', 'Location', 'north');
set(lg, 'TextColor', FG, 'Color', BG, 'EdgeColor', GR);
grid on;
set(gca, 'Color', BG, 'XColor', FG, 'YColor', FG, 'GridColor', GR, 'GridAlpha', 0.5);
saveas(gcf, fullfile(resultsDir, 'classifier_cv.png'));
end

function clf = fitModel(X, y, method, calibrate)
mu = mean(X, 1);
sd = std(X, 0, 1);
sd(sd < 1e-8) = 1;
Xs = bsxfun(@rdivide, bsxfun(@minus, X, mu), sd);
y  = double(y(:));

clf.mu = mu; clf.sd = sd;

useSVM = any(strcmpi(method, {'auto', 'svm'}));
if useSVM
    try
        svm = fitcsvm(Xs, y, 'KernelFunction', 'rbf', 'KernelScale', 'auto', ...
                      'BoxConstraint', 1, 'ClassNames', [0 1], ...
                      'Standardize', false);
        if calibrate, svm = fitPosterior(svm); end
        clf.type = 'svm';
        clf.calibrated = calibrate;
        clf.svm  = svm;
        return;
    catch ME
        if strcmpi(method, 'svm')
            rethrow(ME);
        end
        fprintf('  (fitcsvm unavailable: %s -> using built-in logistic regression)\n', ...
                ME.message);
    end
end

[n, d] = size(Xs);
Xb = [ones(n, 1), Xs];
npos = max(sum(y == 1), 1); nneg = max(sum(y == 0), 1);
sw = (y == 1) * (n / (2*npos)) + (y == 0) * (n / (2*nneg));

w = zeros(d + 1, 1);
lambda = 1e-2;
lr = 0.1;
for it = 1:5000
    p = 1 ./ (1 + exp(-(Xb * w)));
    g = (Xb' * (sw .* (p - y))) / n + lambda * [0; w(2:end)];
    w = w - lr * g;
end

clf.type = 'logistic';
clf.w    = w;
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
