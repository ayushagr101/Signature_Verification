function [f, names, parts] = extractFeatures(B)
%EXTRACTFEATURES  DSP feature vector for a preprocessed signature.
%
%   [f, names, parts] = extractFeatures(B)
%
%   B is the logical image returned by PREPROCESSSIGNATURE.
%   f      : column feature vector (double)
%   names  : cellstr of feature names, same length as f
%   parts  : struct holding each feature block separately (for plots/debug)
%
%   Feature families (Sections 3 and 4 of the synopsis)
%   ---------------------------------------------------
%     1. Geometric + statistical descriptors      (global shape, ink density)
%     2. Zoning grid densities (4x4)              (local mass distribution)
%     3. Hu invariant moments                     (rotation/scale invariants)
%     4. Projection profiles, H and V             (1-D signals from the image)
%     5. Signal energy / entropy of the profiles  (space-domain energy)
%     6. FFT magnitude of the profiles            (frequency-domain shape)
%     7. Radial energy of the 2-D FFT             (spectral stroke texture)
%     8. Wavelet sub-band energies (3 levels)     (multiresolution detail)
%     9. Statistics of the upper/lower contour    (pen-trajectory-like)

B = logical(B);
[H, W] = size(B);
X = double(B);
n = sum(X(:));
if n == 0, n = 1; end

f = []; names = {};

% ---------------------------------------------------------------------- 1
inkDensity = sum(X(:)) / (H*W);
[r, c] = find(B);
if isempty(r), r = H/2; c = W/2; end
cy = mean(r)/H;  cx = mean(c)/W;
sy = std(r)/H;   sx = std(c)/W;
aspect  = (max(c)-min(c)+1) / max(max(r)-min(r)+1, 1);

% stroke-thickness proxy: ink area divided by skeleton length
lenSk = max(skeletonLength(B), 1);
thickness = sum(X(:)) / lenSk / max(H, W);

% number of closed loops in the signature (Euler number)
holes = holeCount(B);

g  = [inkDensity; cx; cy; sx; sy; aspect; thickness; holes/10];
gn = {'inkDensity','centroidX','centroidY','spreadX','spreadY', ...
      'aspectRatio','strokeThickness','holeCount'};
[f, names] = addBlock(f, names, g, gn);
parts.geometric = g;

% ---------------------------------------------------------------------- 2
% 4 x 4 zoning: fraction of total ink falling in each cell.
nz = 4;
Z = zeros(nz);
rEdge = round(linspace(0, H, nz+1));
cEdge = round(linspace(0, W, nz+1));
for i = 1:nz
    for j = 1:nz
        Z(i,j) = sum(sum(X(rEdge(i)+1:rEdge(i+1), cEdge(j)+1:cEdge(j+1))));
    end
end
Z  = Z(:) / n;
zn = arrayfun(@(k) sprintf('zone%02d', k), 1:numel(Z), 'UniformOutput', false);
[f, names] = addBlock(f, names, Z, zn);
parts.zoning = Z;

% ---------------------------------------------------------------------- 3
hu = huMoments(X);
hu = sign(hu) .* log10(abs(hu) + 1e-30);   % log compression, sign preserved
hu = hu / 30;                              % bring roughly into [-1, 1]
hn = arrayfun(@(k) sprintf('hu%d', k), 1:7, 'UniformOutput', false);
[f, names] = addBlock(f, names, hu(:), hn);
parts.hu = hu(:);

% ---------------------------------------------------------------------- 4
% Projection profiles: the image collapsed into two 1-D DSP signals.
pv  = sum(X, 1)';           % vertical projection   (length W)
ph  = sum(X, 2);            % horizontal projection (length H)
pvN = pv / max(max(pv), 1);
phN = ph / max(max(ph), 1);

PV = resampleSig(pvN, 32);
PH = resampleSig(phN, 16);
[f, names] = addBlock(f, names, PV, prefixNames('projV', 32));
[f, names] = addBlock(f, names, PH, prefixNames('projH', 16));
parts.projV = PV; parts.projH = PH;
parts.projVfull = pvN; parts.projHfull = phN;

% ---------------------------------------------------------------------- 5
% Space-domain energy and entropy of the two profile signals.
Ev = sum(pvN.^2) / numel(pvN);
Eh = sum(phN.^2) / numel(phN);
Hv = sigEntropy(pvN);
Hh = sigEntropy(phN);
% first-difference energy: how "busy" the profile is (stroke frequency)
Dv = sum(diff(pvN).^2) / numel(pvN);
Dh = sum(diff(phN).^2) / numel(phN);
e  = [Ev; Eh; Hv; Hh; Dv; Dh];
[f, names] = addBlock(f, names, e, ...
    {'energyV','energyH','entropyV','entropyH','diffEnergyV','diffEnergyH'});
parts.energy = e;

% ---------------------------------------------------------------------- 6
% FFT of each profile. Low-order magnitudes describe the coarse rhythm of
% the signature: stable for a genuine writer, unstable for a forger.
Fv = fftMag(pvN, 16);
Fh = fftMag(phN, 8);
[f, names] = addBlock(f, names, Fv, prefixNames('fftV', 16));
[f, names] = addBlock(f, names, Fh, prefixNames('fftH', 8));
parts.fftV = Fv; parts.fftH = Fh;

% ---------------------------------------------------------------------- 7
% 2-D FFT: energy in concentric radial bands of the magnitude spectrum.
S = abs(fftshift(fft2(X)));
S(round(H/2)+1, round(W/2)+1) = 0;            % suppress the DC term
[cc, rr] = meshgrid(1:W, 1:H);
rad = sqrt(((rr - H/2)/(H/2)).^2 + ((cc - W/2)/(W/2)).^2);
nb  = 8; RB = zeros(nb,1);
edges = linspace(0, 1, nb+1);
for k = 1:nb
    m = rad >= edges(k) & rad < edges(k+1);
    RB(k) = sum(S(m).^2);
end
RB = RB / max(sum(RB), eps);
[f, names] = addBlock(f, names, RB, prefixNames('radBand', nb));
parts.radial = RB;

% ---------------------------------------------------------------------- 8
% Wavelet sub-band energies (Haar, 3 levels), computed with a local
% lifting implementation so no Wavelet Toolbox licence is required.
W3 = haarEnergy2(X, 3);
wn = [prefixNames('wvA', 1), prefixNames('wvD', numel(W3)-1)];
[f, names] = addBlock(f, names, W3, wn);
parts.wavelet = W3;

% ---------------------------------------------------------------------- 9
% Upper and lower contour signals: for each column, the topmost and
% bottommost ink row. These behave like the pen trajectory of an online
% signature and are strongly writer specific.
[up, lo] = contourSignals(B);
cs = [mean(up); std(up); skewness0(up); kurtosis0(up); ...
      mean(lo); std(lo); skewness0(lo); kurtosis0(lo); ...
      mean(abs(diff(up))); mean(abs(diff(lo)))];
cn = {'upMean','upStd','upSkew','upKurt','loMean','loStd','loSkew', ...
      'loKurt','upRough','loRough'};
[f, names] = addBlock(f, names, cs, cn);
parts.contourUp = up; parts.contourLo = lo; parts.contourStats = cs;

f = f(:);
f(~isfinite(f)) = 0;
names = names(:)';
end

% ======================================================================= %
%                          local helper functions                         %
% ======================================================================= %

function [f, names] = addBlock(f, names, v, vn)
f = [f; v(:)];
names = [names, vn(:)'];
end

function c = prefixNames(p, n)
c = arrayfun(@(k) sprintf('%s%02d', p, k), 1:n, 'UniformOutput', false);
end

function y = resampleSig(x, n)
%RESAMPLESIG  Uniform length-n resampling of a 1-D signal (linear interp).
x = x(:);
if numel(x) == n, y = x; return; end
t = linspace(1, numel(x), n);
y = interp1(1:numel(x), x, t, 'linear')';
y(~isfinite(y)) = 0;
end

function H = sigEntropy(x)
%SIGENTROPY  Shannon entropy of a non-negative signal treated as a pdf.
x = abs(x(:));
s = sum(x);
if s <= eps, H = 0; return; end
p = x / s; p = p(p > 0);
H = -sum(p .* log2(p)) / log2(numel(x));
end

function m = fftMag(x, k)
%FFTMAG  First k normalized DFT magnitudes (DC term excluded).
x = x(:) - mean(x);
X = abs(fft(x));
X = X(2:min(k+1, numel(X)));
X = [X; zeros(k - numel(X), 1)];
m = X / max(sum(X), eps);
end

function hu = huMoments(X)
%HUMOMENTS  The seven Hu invariant moments of an intensity image.
[H, W] = size(X);
[x, y] = meshgrid(1:W, 1:H);
m00 = sum(X(:));
if m00 <= eps, hu = zeros(7,1); return; end
xb = sum(sum(x.*X)) / m00;
yb = sum(sum(y.*X)) / m00;
mu = @(p,q) sum(sum(((x-xb).^p) .* ((y-yb).^q) .* X));
nn = @(p,q) mu(p,q) / m00^(1 + (p+q)/2);

n20 = nn(2,0); n02 = nn(0,2); n11 = nn(1,1);
n30 = nn(3,0); n03 = nn(0,3); n12 = nn(1,2); n21 = nn(2,1);

hu = zeros(7,1);
hu(1) = n20 + n02;
hu(2) = (n20 - n02)^2 + 4*n11^2;
hu(3) = (n30 - 3*n12)^2 + (3*n21 - n03)^2;
hu(4) = (n30 + n12)^2 + (n21 + n03)^2;
hu(5) = (n30 - 3*n12)*(n30 + n12)*((n30+n12)^2 - 3*(n21+n03)^2) + ...
        (3*n21 - n03)*(n21 + n03)*(3*(n30+n12)^2 - (n21+n03)^2);
hu(6) = (n20 - n02)*((n30+n12)^2 - (n21+n03)^2) + ...
        4*n11*(n30+n12)*(n21+n03);
hu(7) = (3*n21 - n03)*(n30 + n12)*((n30+n12)^2 - 3*(n21+n03)^2) - ...
        (n30 - 3*n12)*(n21 + n03)*(3*(n30+n12)^2 - (n21+n03)^2);
end

function E = haarEnergy2(X, levels)
%HAARENERGY2  Normalized energy of each 2-D Haar sub-band, `levels` deep.
%   Returns [approximation; (H,V,D) for each level] as a column vector.
E = [];
A = X;
for L = 1:levels
    [A, Hd, Vd, Dd] = haarStep(A);
    E = [E; sum(Hd(:).^2); sum(Vd(:).^2); sum(Dd(:).^2)]; %#ok<AGROW>
end
E = [sum(A(:).^2); E];
E = E / max(sum(E), eps);
end

function [A, Hd, Vd, Dd] = haarStep(X)
%HAARSTEP  One level of the orthonormal 2-D Haar wavelet transform.
[h, w] = size(X);
if mod(h,2), X(end+1,:) = 0; end
if mod(w,2), X(:,end+1) = 0; end
s  = 1/sqrt(2);
L  = s*(X(1:2:end,:) + X(2:2:end,:));      % row lowpass
Hh = s*(X(1:2:end,:) - X(2:2:end,:));      % row highpass
A  = s*(L(:,1:2:end)  + L(:,2:2:end));
Vd = s*(L(:,1:2:end)  - L(:,2:2:end));
Hd = s*(Hh(:,1:2:end) + Hh(:,2:2:end));
Dd = s*(Hh(:,1:2:end) - Hh(:,2:2:end));
end

function [up, lo] = contourSignals(B)
%CONTOURSIGNALS  Normalized upper/lower ink boundary for every column.
[H, W] = size(B);
up = zeros(W,1); lo = zeros(W,1);
last = 0.5;
for j = 1:W
    idx = find(B(:,j), 1, 'first');
    if isempty(idx)
        up(j) = last; lo(j) = last;
    else
        up(j) = idx / H;
        lo(j) = find(B(:,j), 1, 'last') / H;
        last  = (up(j) + lo(j)) / 2;
    end
end
end

function L = skeletonLength(B)
%SKELETONLENGTH  Length of the thinned stroke, with a toolbox-free fallback.
L = 0;
try
    L = sum(sum(bwmorph(B, 'thin', Inf)));
catch
    % Fallback: count vertical stroke transitions per column, which
    % approximates the traced stroke length without morphology functions.
    D = diff([false(1, size(B,2)); B], 1, 1) > 0;
    L = max(sum(D(:)) * 3, 1);
end
if L == 0, L = 1; end
end

function h = holeCount(B)
%HOLECOUNT  Number of enclosed loops, with a toolbox-free fallback.
try
    h = 1 - bweuler(B, 8);
catch
    try
        h = max(numel(unique(bwlabel(~B, 4))) - 2, 0);
    catch
        h = 0;
    end
end
if ~isfinite(h), h = 0; end
end
