function model = enrollUser(samples, userId, opts)

if nargin < 2 || isempty(userId), userId = 'unknown'; end
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'prep'),    opts.prep    = struct(); end
if ~isfield(opts, 'weights'), opts.weights = [0.6 0.4]; end
if ~isfield(opts, 'kThresh'), opts.kThresh = 1.4; end
if ~isfield(opts, 'minThr'),  opts.minThr  = 0.05; end
if ~isfield(opts, 'maxThr'),  opts.maxThr  = 0.95; end
if ~isfield(opts, 'mode'),    opts.mode    = 'dsp'; end
if ~isfield(opts, 'classifier'), opts.classifier = []; end

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

F = [];
refImgs = cell(1, N);
for i = 1:N
    B = preprocessSignature(samples{i}, opts.prep);
    fi = extractFeatures(B);
    if isempty(F), F = zeros(numel(fi), N); end
    F(:, i)   = fi;
    refImgs{i} = B;
end
[~, featNames] = extractFeatures(refImgs{1});

mu = mean(F, 2);
[sigma, d0, dlist] = classStats(F);

model.userId    = userId;
model.F         = F;
model.mu        = mu;
model.sigma     = sigma;
model.refImgs   = refImgs;
model.featNames = featNames;
model.weights   = opts.weights;
model.prep      = opts.prep;
model.nSamples  = N;
model.createdAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');

model.d0 = d0;
model.intraDistances = dlist;

model.mode = 'dsp';
model.clf  = [];
if ~isempty(opts.classifier)
    c = opts.classifier;
    if ischar(c) || isstring(c)
        T = load(char(c), 'clf');
        c = T.clf;
    end
    model.clf  = c;
    model.mode = opts.mode;
    if strcmpi(model.mode, 'dsp'), model.mode = 'hybrid'; end
end

L = looScores(model);
loo = [L.score];
thr = mean(loo) - opts.kThresh * std(loo);
thr = min(max(thr, opts.minThr), opts.maxThr);

model.looScores = loo;
model.thr       = thr;

fprintf(['Enrolled "%s" [%s]: %d reference samples, %d features, ' ...
         'threshold = %.3f\n'], userId, model.mode, N, size(F,1), thr);
fprintf('  genuine leave-one-out scores: %s\n', ...
        strtrim(sprintf('%.3f ', loo)));
end

function files = listImages(folder)
exts = {'*.png','*.jpg','*.jpeg','*.bmp','*.tif','*.tiff'};
files = {};
for k = 1:numel(exts)
    d = dir(fullfile(folder, exts{k}));
    for i = 1:numel(d)
        files{end+1} = fullfile(folder, d(i).name);
    end
end
files = sort(files);
end
