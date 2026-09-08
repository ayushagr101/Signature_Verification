function S = signatureScore(model, f, B, excludeIdx)
%SIGNATURESCORE  Similarity between a probe signature and a reference model.
%
%   S = signatureScore(model, f, B)
%   S = signatureScore(model, f, B, excludeIdx)
%
%   model      : struct produced by ENROLLUSER
%   f          : feature vector of the probe (from EXTRACTFEATURES)
%   B          : preprocessed binary probe image (for the correlation term)
%   excludeIdx : reference index to leave out (used for leave-one-out
%                threshold calibration during enrolment)
%
%   S is a struct with fields
%       .featureDistance  normalized (z-scored) distance to the references
%       .featureSim       distance mapped to a 0..1 similarity
%       .corrSim          peak normalized cross-correlation, 0..1
%       .score            fused similarity in 0..1
%
%   Two complementary DSP measures are fused:
%     (a) a weighted distance in the multi-domain feature space, where each
%         feature is divided by its genuine-class standard deviation so that
%         naturally variable features count less; and
%     (b) the peak of the 2-D normalized cross-correlation between the probe
%         image and each reference image, which captures stroke placement
%         that the summary features may miss.

if nargin < 4, excludeIdx = []; end

keep = true(1, size(model.F, 2));
if ~isempty(excludeIdx), keep(excludeIdx) = false; end

F     = model.F(:, keep);
sigma = model.sigma;
f     = f(:);

% ------------------------------------------- (a) feature-space distance ---
D = bsxfun(@minus, F, f);                  % d x N residuals
D = bsxfun(@rdivide, D, sigma);            % z-score each feature
d = sqrt(mean(D.^2, 1));                   % normalized distance per reference

% The median over the reference set is robust to one atypical enrolment
% sample, unlike the mean or the minimum.
dRef = median(d);

% d0 is the model's own intra-class scale, so the similarity is calibrated
% per user rather than by a global constant.
featureSim = exp(-dRef / max(model.d0, eps));

% ------------------------------------ (b) normalized cross-correlation ----
corrSim = 0;
if ~isempty(B) && isfield(model, 'refImgs')
    idx = find(keep);
    cvals = zeros(1, numel(idx));
    for k = 1:numel(idx)
        cvals(k) = peakNCC(model.refImgs{idx(k)}, B);
    end
    corrSim = max(0, median(cvals));
end

% -------------------------------------------------------- score fusion ---
w = model.weights;                          % [featureWeight corrWeight]
score = w(1)*featureSim + w(2)*corrSim;

S.featureDistance = dRef;
S.featureSim      = featureSim;
S.corrSim         = corrSim;
S.score           = min(max(score, 0), 1);
S.perRefDistance  = d;
end

% ======================================================================= %
function c = peakNCC(A, B)
%PEAKNCC  Peak of the normalized cross-correlation of two binary images.
%   Both images are low-pass filtered first so that small, natural stroke
%   displacements do not destroy the correlation; the FFT gives the full
%   shift surface in one shot and the maximum is the alignment score.
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
%SMOOTHINK  Small Gaussian blur that gives strokes a tolerance band.
h = fspecialGauss(7, 1.6);
Y = conv2(X, h, 'same');
end

function h = fspecialGauss(n, s)
r = (n-1)/2;
[x, y] = meshgrid(-r:r, -r:r);
h = exp(-(x.^2 + y.^2) / (2*s^2));
h = h / sum(h(:));
end
