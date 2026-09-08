function [f, names, parts] = extractFeatures(B)

B = logical(B);
[H, W] = size(B);
X = double(B);
n = sum(X(:));
if n == 0, n = 1; end

f = []; names = {};

inkDensity = sum(X(:)) / (H*W);
[r, c] = find(B);
if isempty(r), r = H/2; c = W/2; end
cy = mean(r)/H;  cx = mean(c)/W;
sy = std(r)/H;   sx = std(c)/W;
aspect  = (max(c)-min(c)+1) / max(max(r)-min(r)+1, 1);

lenSk = max(skeletonLength(B), 1);
thickness = sum(X(:)) / lenSk / max(H, W);

holes = holeCount(B);

g  = [inkDensity; cx; cy; sx; sy; aspect; thickness; holes/10];
gn = {'inkDensity','centroidX','centroidY','spreadX','spreadY', ...
      'aspectRatio','strokeThickness','holeCount'};
[f, names] = addBlock(f, names, g, gn);
parts.geometric = g;

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

hu = huMoments(X);
hu = sign(hu) .* log10(abs(hu) + 1e-30);
hu = hu / 30;
hn = arrayfun(@(k) sprintf('hu%d', k), 1:7, 'UniformOutput', false);
[f, names] = addBlock(f, names, hu(:), hn);
parts.hu = hu(:);

pv  = sum(X, 1)';
ph  = sum(X, 2);
pvN = pv / max(max(pv), 1);
phN = ph / max(max(ph), 1);

PV = resampleSig(pvN, 32);
PH = resampleSig(phN, 16);
[f, names] = addBlock(f, names, PV, prefixNames('projV', 32));
[f, names] = addBlock(f, names, PH, prefixNames('projH', 16));
parts.projV = PV; parts.projH = PH;
parts.projVfull = pvN; parts.projHfull = phN;

Ev = sum(pvN.^2) / numel(pvN);
Eh = sum(phN.^2) / numel(phN);
Hv = sigEntropy(pvN);
Hh = sigEntropy(phN);
Dv = sum(diff(pvN).^2) / numel(pvN);
Dh = sum(diff(phN).^2) / numel(phN);
e  = [Ev; Eh; Hv; Hh; Dv; Dh];
[f, names] = addBlock(f, names, e, ...
    {'energyV','energyH','entropyV','entropyH','diffEnergyV','diffEnergyH'});
parts.energy = e;

Fv = fftMag(pvN, 16);
Fh = fftMag(phN, 8);
[f, names] = addBlock(f, names, Fv, prefixNames('fftV', 16));
[f, names] = addBlock(f, names, Fh, prefixNames('fftH', 8));
parts.fftV = Fv; parts.fftH = Fh;

S = abs(fftshift(fft2(X)));
S(round(H/2)+1, round(W/2)+1) = 0;
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

W3 = haarEnergy2(X, 3);
wn = [prefixNames('wvA', 1), prefixNames('wvD', numel(W3)-1)];
[f, names] = addBlock(f, names, W3, wn);
parts.wavelet = W3;

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

function [f, names] = addBlock(f, names, v, vn)
f = [f; v(:)];
names = [names, vn(:)'];
end

function c = prefixNames(p, n)
c = arrayfun(@(k) sprintf('%s%02d', p, k), 1:n, 'UniformOutput', false);
end

function y = resampleSig(x, n)
x = x(:);
if numel(x) == n, y = x; return; end
t = linspace(1, numel(x), n);
y = interp1(1:numel(x), x, t, 'linear')';
y(~isfinite(y)) = 0;
end

function H = sigEntropy(x)
x = abs(x(:));
s = sum(x);
if s <= eps, H = 0; return; end
p = x / s; p = p(p > 0);
H = -sum(p .* log2(p)) / log2(numel(x));
end

function m = fftMag(x, k)
x = x(:) - mean(x);
X = abs(fft(x));
X = X(2:min(k+1, numel(X)));
X = [X; zeros(k - numel(X), 1)];
m = X / max(sum(X), eps);
end

function hu = huMoments(X)
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
E = [];
A = X;
for L = 1:levels
    [A, Hd, Vd, Dd] = haarStep(A);
    E = [E; sum(Hd(:).^2); sum(Vd(:).^2); sum(Dd(:).^2)];
end
E = [sum(A(:).^2); E];
E = E / max(sum(E), eps);
end

function [A, Hd, Vd, Dd] = haarStep(X)
[h, w] = size(X);
if mod(h,2), X(end+1,:) = 0; end
if mod(w,2), X(:,end+1) = 0; end
s  = 1/sqrt(2);
L  = s*(X(1:2:end,:) + X(2:2:end,:));
Hh = s*(X(1:2:end,:) - X(2:2:end,:));
A  = s*(L(:,1:2:end)  + L(:,2:2:end));
Vd = s*(L(:,1:2:end)  - L(:,2:2:end));
Hd = s*(Hh(:,1:2:end) + Hh(:,2:2:end));
Dd = s*(Hh(:,1:2:end) - Hh(:,2:2:end));
end

function [up, lo] = contourSignals(B)
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
L = 0;
try
    L = sum(sum(bwmorph(B, 'thin', Inf)));
catch
    D = diff([false(1, size(B,2)); B], 1, 1) > 0;
    L = max(sum(D(:)) * 3, 1);
end
if L == 0, L = 1; end
end

function h = holeCount(B)
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
