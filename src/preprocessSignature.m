function [B, info] = preprocessSignature(I, opts)
%PREPROCESSSIGNATURE  Clean, normalize and binarize a signature image.
%
%   [B, info] = preprocessSignature(I)
%   [B, info] = preprocessSignature(I, opts)
%
%   Pipeline (Section 3 of the synopsis):
%       colour -> grayscale -> median (impulse-noise) filtering
%       -> Otsu thresholding -> polarity fix (ink = 1)
%       -> small-blob removal -> slant/rotation correction (principal axis)
%       -> bounding-box cropping (position invariance)
%       -> resize to a fixed canvas (size invariance)
%
%   INPUT
%       I     : filename, or a grayscale/RGB/logical image matrix
%       opts  : struct with optional fields
%                 .size        [rows cols] output canvas   (default [128 256])
%                 .medianSize  median filter window        (default [3 3])
%                 .minBlob     min connected-component area (default 20)
%                 .deskew      logical, rotate to principal axis (default true)
%                 .pad         border padding in pixels    (default 4)
%
%   OUTPUT
%       B     : logical image, ink = true, size opts.size
%       info  : struct of preprocessing diagnostics (angle, bbox, inkPixels...)

if nargin < 2, opts = struct(); end
opts = setDefault(opts, 'size',       [128 256]);
opts = setDefault(opts, 'medianSize', [3 3]);
opts = setDefault(opts, 'minBlob',    20);
opts = setDefault(opts, 'deskew',     true);
opts = setDefault(opts, 'pad',        4);

% ---------------------------------------------------------------- load ---
if ischar(I) || isstring(I)
    info.file = char(I);
    I = imread(char(I));
else
    info.file = '<matrix>';
end

% ------------------------------------------------------ grayscale stage ---
if ndims(I) == 3
    I = rgb2gray(I);
end
if islogical(I)
    G = double(I);
else
    G = im2double(I);
end

% ------------------------------------------- noise reduction (filtering) --
% Median filtering removes salt-and-pepper scanner noise while preserving
% the thin stroke edges that carry the signature's identity.
G = medianFilter(G, opts.medianSize);

% Contrast stretch so faint pen strokes survive thresholding.
lo = min(G(:)); hi = max(G(:));
if hi - lo > eps
    G = (G - lo) / (hi - lo);
end

% ---------------------------------------------- Otsu global thresholding --
level = otsuLevel(G);
B = G > level;                            % background bright, ink dark

% Ink must be the MINORITY class and equal to logical true. Scanned paper is
% mostly white background, so if more than half the pixels are 1 we invert.
if mean(B(:)) > 0.5
    B = ~B;
end
info.otsuLevel = level;

% ------------------------------------------------- morphological cleanup --
B = despeckle(B, opts.minBlob);           % drop speckles / stray dots
B = bridgeGaps(B);                        % close 1-px stroke breaks

if ~any(B(:))
    warning('preprocessSignature:empty', 'No ink found after thresholding.');
    B = false(opts.size);
    info.angle = 0; info.bbox = [1 1 1 1]; info.inkPixels = 0;
    info.aspectRaw = 1;
    return;
end

% ------------------------------------------- orientation (deskew) stage ---
% The dominant stroke direction is estimated from the second-order central
% moments of the ink distribution (principal axis) and rotated to horizontal.
angle = 0;
if opts.deskew
    [r, c] = find(B);
    r = r - mean(r); c = c - mean(c);
    mu20 = mean(c.^2); mu02 = mean(r.^2); mu11 = mean(r.*c);
    angle = 0.5 * atan2(2*mu11, mu20 - mu02) * 180/pi;
    angle = max(min(angle, 30), -30);     % clamp: never over-rotate
    if abs(angle) > 1
        B = rotateImg(B, angle);
        B = despeckle(B, opts.minBlob);
    end
end
info.angle = angle;

% -------------------------------------------------- crop bounding box -----
[r, c] = find(B);
r1 = min(r); r2 = max(r); c1 = min(c); c2 = max(c);
B = B(r1:r2, c1:c2);
info.bbox = [c1 r1 c2-c1+1 r2-r1+1];
info.aspectRaw = size(B,2) / size(B,1);

% --------------------------------------------- size normalization ---------
% Aspect-preserving resize into the canvas, then centre. This keeps the
% stroke geometry undistorted while giving every sample identical dimensions.
target = opts.size;
inner  = target - 2*opts.pad;
s = min(inner(1)/size(B,1), inner(2)/size(B,2));
Bs = resizeImg(B, s) > 0.4;

canvas = false(target);
r0 = floor((target(1) - size(Bs,1))/2) + 1;
c0 = floor((target(2) - size(Bs,2))/2) + 1;
r0 = max(r0,1); c0 = max(c0,1);
rEnd = min(r0+size(Bs,1)-1, target(1));
cEnd = min(c0+size(Bs,2)-1, target(2));
canvas(r0:rEnd, c0:cEnd) = Bs(1:(rEnd-r0+1), 1:(cEnd-c0+1));
B = canvas;

info.inkPixels = sum(B(:));
info.scale     = s;
end

% ======================================================================= %
%                          local helper functions                         %
% ======================================================================= %

function s = setDefault(s, f, v)
if ~isfield(s, f) || isempty(s.(f)), s.(f) = v; end
end

function Y = medianFilter(X, wsz)
%MEDIANFILTER  2-D median filter; uses MEDFILT2 when the toolbox is present.
try
    Y = medfilt2(X, wsz, 'symmetric');
    return;
catch
    % fall through to the sliding-window implementation below
end
m = wsz(1); n = wsz(end);
pr = floor(m/2); pc = floor(n/2);
P  = padReplicate(X, pr, pc);
[h, w] = size(X);
stack = zeros(h, w, m*n);
k = 0;
for i = 1:m
    for j = 1:n
        k = k + 1;
        stack(:,:,k) = P(i:i+h-1, j:j+w-1);
    end
end
Y = median(stack, 3);
end

function P = padReplicate(X, pr, pc)
P = X([ones(1,pr) 1:size(X,1) size(X,1)*ones(1,pr)], :);
P = P(:, [ones(1,pc) 1:size(X,2) size(X,2)*ones(1,pc)]);
end

function level = otsuLevel(G)
%OTSULEVEL  Otsu's global threshold from the 256-bin image histogram.
%   Equivalent to GRAYTHRESH but implemented locally so the preprocessing
%   stage runs without the Image Processing Toolbox.
x = G(:);
x = x(isfinite(x));
if isempty(x), level = 0.5; return; end
nb = 256;
counts = histc(min(max(round(x*(nb-1)), 0), nb-1), 0:nb-1); %#ok<HISTC>
counts = counts(:);
p = counts / max(sum(counts), eps);
idx = (0:nb-1)' / (nb-1);
omega = cumsum(p);
mu    = cumsum(p .* idx);
muT   = mu(end);
denom = omega .* (1 - omega);
sigmaB = zeros(nb,1);
ok = denom > eps;
sigmaB(ok) = (muT*omega(ok) - mu(ok)).^2 ./ denom(ok);
[~, k] = max(sigmaB);
level = idx(k);
end

function B = despeckle(B, minArea)
%DESPECKLE  Remove connected components smaller than minArea pixels.
if minArea <= 1 || ~any(B(:)), return; end
try
    B = bwareaopen(B, minArea);
    return;
catch
    % fall through to the flood-fill implementation below
end
L = labelComponents(B);
if max(L(:)) == 0, return; end
counts = histc(L(L > 0), 1:max(L(:))); %#ok<HISTC>
small  = find(counts(:) < minArea);
if ~isempty(small)
    B(ismember(L, small)) = false;
end
end

function L = labelComponents(B)
%LABELCOMPONENTS  8-connected labelling (BWLABEL replacement).
try
    L = bwlabel(B, 8);
    return;
catch
    % fall through to the iterative implementation below
end
[h, w] = size(B);
L = zeros(h, w);
lab = 0;
for s = find(B(:))'
    if L(s) ~= 0, continue; end
    lab = lab + 1;
    stack = s;
    while ~isempty(stack)
        p = stack(end); stack(end) = [];
        if L(p) ~= 0, continue; end
        L(p) = lab;
        [i, j] = ind2sub([h w], p);
        for di = -1:1
            for dj = -1:1
                a = i + di; b = j + dj;
                if a >= 1 && a <= h && b >= 1 && b <= w
                    q = sub2ind([h w], a, b);
                    if B(q) && L(q) == 0, stack(end+1) = q; end %#ok<AGROW>
                end
            end
        end
    end
end
end

function B = bridgeGaps(B)
%BRIDGEGAPS  Morphological closing with a 3x3 structuring element.
try
    B = imclose(B, strel('disk', 1));
    return;
catch
    % fall through to the convolution-based implementation below
end
k = ones(3);
D = conv2(double(B), k, 'same') > 0;              % dilation
E = conv2(double(D), k, 'same') >= sum(k(:));     % erosion
B = E | B;
end

function Y = resizeImg(X, s)
%RESIZEIMG  Bilinear rescaling by factor s; uses IMRESIZE when available.
try
    Y = imresize(X, s, 'bilinear');
    return;
catch
    % fall through to the INTERP2 implementation below
end
[h, w] = size(X);
nh = max(round(h*s), 1); nw = max(round(w*s), 1);
[xi, yi] = meshgrid(linspace(1, w, nw), linspace(1, h, nh));
Y = interp2(1:w, (1:h)', double(X), xi, yi, 'linear', 0);
end

function Y = rotateImg(X, angDeg)
%ROTATEIMG  Rotate about the image centre; uses IMROTATE when available.
try
    Y = imrotate(X, angDeg, 'nearest', 'loose');
    return;
catch
    % fall through to the inverse-mapping implementation below
end
[h, w] = size(X);
t = -angDeg*pi/180;                    % inverse mapping angle
R = [cos(t) -sin(t); sin(t) cos(t)];
corners = R * [1 1 w w; 1 h 1 h];
nw = ceil(max(corners(1,:)) - min(corners(1,:))) + 1;
nh = ceil(max(corners(2,:)) - min(corners(2,:))) + 1;
[xo, yo] = meshgrid(1:nw, 1:nh);
xc = xo - nw/2; yc = yo - nh/2;
xs =  cos(t)*xc + sin(t)*yc + w/2;
ys = -sin(t)*xc + cos(t)*yc + h/2;
Y = interp2(1:w, (1:h)', double(X), xs, ys, 'nearest', 0) > 0.5;
end
