function S = signatureScore(model, f, B, excludeIdx)

if nargin < 4, excludeIdx = []; end

keep = true(1, size(model.F, 2));
if ~isempty(excludeIdx), keep(excludeIdx) = false; end

F     = model.F(:, keep);
sigma = model.sigma;
f     = f(:);

D = bsxfun(@minus, F, f);
D = bsxfun(@rdivide, D, sigma);
d = sqrt(mean(D.^2, 1));

dRef = median(d);

featureSim = exp(-dRef / max(model.d0, eps));

corrSim = 0;
if ~isempty(B) && isfield(model, 'refImgs')
    idx = find(keep);
    cvals = zeros(1, numel(idx));
    for k = 1:numel(idx)
        cvals(k) = peakNCC(model.refImgs{idx(k)}, B);
    end
    corrSim = max(0, median(cvals));
end

w = model.weights;
dsp = min(max(w(1)*featureSim + w(2)*corrSim, 0), 1);

muK = mean(F, 2);
z = abs(f - muK) ./ sigma;
pairFeat = [z; min(d); median(d); max(d); featureSim; corrSim];

S.featureDistance = dRef;
S.featureSim      = featureSim;
S.corrSim         = corrSim;
S.perRefDistance  = d;
S.pairFeat        = pairFeat;
S.dspScore        = dsp;
S.mlProb          = NaN;
S.score           = dsp;

if isfield(model, 'clf') && ~isempty(model.clf)
    p = classifierScore(model.clf, pairFeat');
    S.mlProb = p;
    mode = 'hybrid';
    if isfield(model, 'mode') && ~isempty(model.mode), mode = model.mode; end
    switch lower(mode)
        case 'ml'
            S.score = p;
        case 'hybrid'
            S.score = 0.5*dsp + 0.5*p;
        otherwise
            S.score = dsp;
    end
end
S.score = min(max(S.score, 0), 1);
end

function c = peakNCC(A, B)
A = smoothInk(double(A));
B = smoothInk(double(B));

A = A - mean(A(:));
B = B - mean(B(:));
na = sqrt(sum(A(:).^2)); nb = sqrt(sum(B(:).^2));
if na <= eps || nb <= eps, c = 0; return; end

R = real(ifft2(conj(fft2(A)) .* fft2(B)));
c = max(R(:)) / (na * nb);
c = min(max(c, 0), 1);
end

function Y = smoothInk(X)
h = fspecialGauss(7, 1.6);
Y = conv2(X, h, 'same');
end

function h = fspecialGauss(n, s)
r = (n-1)/2;
[x, y] = meshgrid(-r:r, -r:r);
h = exp(-(x.^2 + y.^2) / (2*s^2));
h = h / sum(h(:));
end
