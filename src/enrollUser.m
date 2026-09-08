function model = enrollUser(samples, userId, opts)
%ENROLLUSER  Build a reference model from several genuine signatures.
%
%   model = enrollUser(samples)
%   model = enrollUser(samples, userId, opts)
%
%   samples : cell array of image filenames or image matrices (>= 3 genuine
%             signatures of the same person), OR a folder path containing
%             the genuine samples.
%   userId  : account/customer identifier stored inside the model
%   opts    : struct, optional
%              .prep     preprocessing options (see PREPROCESSSIGNATURE)
%              .weights  [featureWeight corrWeight]  (default [0.6 0.4])
%              .kThresh  threshold tightness, higher = stricter
%                        (default 1.4 standard deviations)
%              .minThr / .maxThr  clamps on the decision threshold
%
%   The model stores, for the enrolled writer:
%       F        d x N matrix of feature vectors
%       mu       mean feature vector
%       sigma    per-feature standard deviation (the natural variability
%                of that writer, used to weight the distance measure)
%       d0       mean intra-class distance, the per-user distance scale
%       thr      decision threshold, calibrated by leave-one-out scoring
%
%   Example
%       model = enrollUser({'g1.png','g2.png','g3.png','g4.png'}, 'ACC-1001');

if nargin < 2 || isempty(userId), userId = 'unknown'; end
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'prep'),    opts.prep    = struct(); end
if ~isfield(opts, 'weights'), opts.weights = [0.6 0.4]; end
if ~isfield(opts, 'kThresh'), opts.kThresh = 1.4; end
if ~isfield(opts, 'minThr'),  opts.minThr  = 0.35; end
if ~isfield(opts, 'maxThr'),  opts.maxThr  = 0.90; end

% Allow a folder of images to be passed directly.
if (ischar(samples) || isstring(samples)) && isfolder(char(samples))
    samples = listImages(char(samples));
end
if ~iscell(samples), samples = {samples}; end

N = numel(samples);
if N < 3
    error('enrollUser:tooFewSamples', ...
        ['At least 3 genuine reference signatures are required ' ...
         '(got %d). Banks typically hold 3-6 specimen signatures.'], N);
end

% ------------------------------------------- preprocess + extract -------
F = [];
refImgs = cell(1, N);
for i = 1:N
    B = preprocessSignature(samples{i}, opts.prep);
    fi = extractFeatures(B);
    if isempty(F), F = zeros(numel(fi), N); end
    F(:, i)   = fi;   %#ok<AGROW>
    refImgs{i} = B;
end
[~, featNames] = extractFeatures(refImgs{1});

% ------------------------------------------- class statistics -----------
mu    = mean(F, 2);
sigma = std(F, 0, 2);

% A feature that never varies across the reference set would otherwise blow
% up the z-scored distance, so the deviation is floored relative to the
% overall spread of that feature block.
floorVal = 0.05 * max(std(F(:)), eps);
sigma = max(sigma, max(floorVal, 1e-3));

model.userId    = userId;
model.F         = F;
model.mu        = mu;
model.sigma     = sigma;
model.refImgs   = refImgs;
model.featNames = featNames;
model.weights   = opts.weights;
model.prep      = opts.prep;
model.nSamples  = N;
model.createdAt = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>

% ------------------------------------------- intra-class distance scale --
% Mean pairwise z-scored distance between the genuine references. This is
% the natural "wobble" of this person's hand and sets the similarity scale.
dsum = []; %#ok<NASGU>
dlist = [];
for i = 1:N
    for j = i+1:N
        D = (F(:,i) - F(:,j)) ./ sigma;
        dlist(end+1) = sqrt(mean(D.^2)); %#ok<AGROW>
    end
end
model.d0 = max(mean(dlist), 1e-3);
model.intraDistances = dlist;

% ------------------------------------------- threshold calibration -------
% Leave-one-out: score each genuine sample against the remaining references.
% The threshold sits kThresh standard deviations below the mean genuine
% score, which adapts automatically to consistent vs. erratic signers.
loo = zeros(1, N);
for i = 1:N
    S = signatureScore(model, F(:, i), refImgs{i}, i);
    loo(i) = S.score;
end
thr = mean(loo) - opts.kThresh * std(loo);
thr = min(max(thr, opts.minThr), opts.maxThr);

model.looScores = loo;
model.thr       = thr;

fprintf(['Enrolled "%s": %d reference samples, %d features, ' ...
         'threshold = %.3f\n'], userId, N, size(F,1), thr);
fprintf('  genuine leave-one-out scores: %s\n', ...
        strtrim(sprintf('%.3f ', loo)));
end

% ======================================================================= %
function files = listImages(folder)
exts = {'*.png','*.jpg','*.jpeg','*.bmp','*.tif','*.tiff'};
files = {};
for k = 1:numel(exts)
    d = dir(fullfile(folder, exts{k}));
    for i = 1:numel(d)
        files{end+1} = fullfile(folder, d(i).name); %#ok<AGROW>
    end
end
files = sort(files);
end
