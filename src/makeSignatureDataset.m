function outDir = makeSignatureDataset(outDir, nWriters, nGenuine, nForged, seed)
%MAKESIGNATUREDATASET  Create a synthetic offline-signature dataset.
%
%   outDir = makeSignatureDataset()
%   outDir = makeSignatureDataset(outDir, nWriters, nGenuine, nForged, seed)
%
%   Every "writer" is a parameter vector driving a cursive pen trajectory
%   built from a sum of sinusoids (a natural handwriting model: handwriting
%   is quasi-periodic, which is exactly why the FFT features work). Genuine
%   samples of one writer differ only by small parameter jitter, pen-pressure
%   variation, rotation and scanner noise. Forgeries are produced two ways:
%
%     skilled  : the overall shape is copied but the fine rhythm parameters
%                (harmonic phases and amplitudes) are wrong
%     random   : a different writer's trajectory entirely
%
%   Files are written as   <outDir>/writer01/genuine_01.png
%                          <outDir>/writer01/forged_skilled_01.png
%                          <outDir>/writer01/forged_random_01.png
%
%   Use this when no scanned signature database is available; the pipeline
%   itself works unchanged on real scans (CEDAR, GPDS, MCYT, or your own).

if nargin < 1 || isempty(outDir),   outDir   = fullfile(pwd, 'data'); end
if nargin < 2 || isempty(nWriters), nWriters = 3;  end
if nargin < 3 || isempty(nGenuine), nGenuine = 8;  end
if nargin < 4 || isempty(nForged),  nForged  = 5;  end
if nargin < 5 || isempty(seed),     seed     = 7;  end

rng(seed);

if ~exist(outDir, 'dir'), mkdir(outDir); end

W = cell(1, nWriters);
for k = 1:nWriters
    W{k} = randomWriter();
end

for k = 1:nWriters
    d = fullfile(outDir, sprintf('writer%02d', k));
    if ~exist(d, 'dir'), mkdir(d); end

    for i = 1:nGenuine
        I = renderSignature(jitterWriter(W{k}, 0.06));
        imwrite(I, fullfile(d, sprintf('genuine_%02d.png', i)));
    end

    for i = 1:nForged
        % Skilled forgery: right envelope, wrong micro-dynamics.
        P = jitterWriter(W{k}, 0.10);
        P.phase = P.phase + (rand(size(P.phase)) - 0.5) * 2.2;
        P.amp   = P.amp  .* (0.55 + 1.0*rand(size(P.amp)));
        P.speed = P.speed * (0.85 + 0.3*rand);
        I = renderSignature(P);
        imwrite(I, fullfile(d, sprintf('forged_skilled_%02d.png', i)));

        % Random forgery: a completely different hand.
        other = mod(k + i, nWriters) + 1;
        if other == k, other = mod(other, nWriters) + 1; end
        I = renderSignature(jitterWriter(W{other}, 0.06));
        imwrite(I, fullfile(d, sprintf('forged_random_%02d.png', i)));
    end
    fprintf('writer%02d: %d genuine, %d skilled + %d random forgeries\n', ...
            k, nGenuine, nForged, nForged);
end

fprintf('Dataset written to %s\n', outDir);
end

% ======================================================================= %
function P = randomWriter()
%RANDOMWRITER  A parameter set describing one person's hand.
nh = 5;                                   % number of harmonics
P.amp    = 0.35 * rand(1, nh) + 0.05;     % harmonic amplitudes
P.freq   = sort(1 + 6*rand(1, nh));       % harmonic frequencies
P.phase  = 2*pi*rand(1, nh);              % harmonic phases
P.slant  = (rand - 0.5) * 0.5;            % writing slant
P.speed  = 0.8 + 0.6*rand;                % horizontal advance rate
P.thick  = 1.6 + 1.2*rand;                % pen nib radius, pixels
P.loops  = 0.2 + 0.5*rand;                % vertical loop gain
P.baseline = (rand - 0.5) * 0.25;         % baseline drift
end

function Q = jitterWriter(P, s)
%JITTERWRITER  Natural intra-writer variation of magnitude s.
Q = P;
Q.amp      = P.amp   .* (1 + s*randn(size(P.amp)));
Q.freq     = P.freq  .* (1 + 0.5*s*randn(size(P.freq)));
Q.phase    = P.phase + s*randn(size(P.phase));
Q.slant    = P.slant + s*randn;
Q.speed    = P.speed * (1 + s*randn);
Q.thick    = max(P.thick * (1 + s*randn), 1.0);
Q.loops    = P.loops * (1 + s*randn);
Q.baseline = P.baseline + s*randn*0.3;
end

function I = renderSignature(P)
%RENDERSIGNATURE  Rasterize a pen trajectory into a noisy "scanned" image.
H = 220; Wd = 640;
t = linspace(0, 2*pi, 4000);

% pen trajectory: monotone horizontal advance + harmonic vertical motion
x = linspace(0.08, 0.92, numel(t)) * Wd;
y = zeros(size(t));
for k = 1:numel(P.amp)
    y = y + P.amp(k) * sin(P.freq(k)*P.speed*t + P.phase(k));
end
y = y * P.loops;
y = y - mean(y);
y = y / max(max(abs(y)), eps);
y = H/2 + y * (H*0.30) + P.baseline*H;
y = y + P.slant * (x - mean(x)) * 0.15;         % slant

% pen lifts: two short gaps, as in a real signature
lift = false(size(t));
g1 = round(0.33*numel(t)); g2 = round(0.66*numel(t));
lift(g1:g1+40) = true; lift(g2:g2+30) = true;

% rasterize with pressure-varying intensity
canvas = zeros(H, Wd);
press  = 0.75 + 0.25*sin(3*t + P.phase(1));
xi = round(x); yi = round(y);
ok = ~lift & xi >= 1 & xi <= Wd & yi >= 1 & yi <= H;
idx = sub2ind([H Wd], yi(ok), xi(ok));
canvas(idx) = max(canvas(idx), press(ok)');

% pen nib = disk kernel
r = max(round(P.thick), 1);
[gx, gy] = meshgrid(-r:r, -r:r);
nib = double(gx.^2 + gy.^2 <= r^2);
canvas = conv2(canvas, nib, 'same');
canvas = min(canvas, 1);

% paper: light grey texture + a little sensor noise, ink is dark
paper = 0.93 + 0.03*randn(H, Wd);
I = paper - 0.85*canvas;
I = I + 0.015*randn(H, Wd);
I = min(max(I, 0), 1);
I = im2uint8Local(I);
end

function U = im2uint8Local(I)
U = uint8(round(min(max(I, 0), 1) * 255));
end
