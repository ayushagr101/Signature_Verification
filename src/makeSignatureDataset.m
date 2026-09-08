function outDir = makeSignatureDataset(outDir, nWriters, nGenuine, nForged, seed)

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
        P = jitterWriter(W{k}, 0.10);
        P.phase = P.phase + (rand(size(P.phase)) - 0.5) * 2.2;
        P.amp   = P.amp  .* (0.55 + 1.0*rand(size(P.amp)));
        P.speed = P.speed * (0.85 + 0.3*rand);
        I = renderSignature(P);
        imwrite(I, fullfile(d, sprintf('forged_skilled_%02d.png', i)));

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

function P = randomWriter()
nh = 5;
P.amp    = 0.35 * rand(1, nh) + 0.05;
P.freq   = sort(1 + 6*rand(1, nh));
P.phase  = 2*pi*rand(1, nh);
P.slant  = (rand - 0.5) * 0.5;
P.speed  = 0.8 + 0.6*rand;
P.thick  = 1.6 + 1.2*rand;
P.loops  = 0.2 + 0.5*rand;
P.baseline = (rand - 0.5) * 0.25;
end

function Q = jitterWriter(P, s)
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
H = 220; Wd = 640;
t = linspace(0, 2*pi, 4000);

x = linspace(0.08, 0.92, numel(t)) * Wd;
y = zeros(size(t));
for k = 1:numel(P.amp)
    y = y + P.amp(k) * sin(P.freq(k)*P.speed*t + P.phase(k));
end
y = y * P.loops;
y = y - mean(y);
y = y / max(max(abs(y)), eps);
y = H/2 + y * (H*0.30) + P.baseline*H;
y = y + P.slant * (x - mean(x)) * 0.15;

lift = false(size(t));
g1 = round(0.33*numel(t)); g2 = round(0.66*numel(t));
lift(g1:g1+40) = true; lift(g2:g2+30) = true;

canvas = zeros(H, Wd);
press  = 0.75 + 0.25*sin(3*t + P.phase(1));
xi = round(x); yi = round(y);
ok = ~lift & xi >= 1 & xi <= Wd & yi >= 1 & yi <= H;
idx = sub2ind([H Wd], yi(ok), xi(ok));
canvas(idx) = max(canvas(idx), press(ok));

r = max(round(P.thick), 1);
[gx, gy] = meshgrid(-r:r, -r:r);
nib = double(gx.^2 + gy.^2 <= r^2);
canvas = conv2(canvas, nib, 'same');
canvas = min(canvas, 1);

paper = 0.93 + 0.03*randn(H, Wd);
I = paper - 0.85*canvas;
I = I + 0.015*randn(H, Wd);
I = min(max(I, 0), 1);
I = im2uint8Local(I);
end

function U = im2uint8Local(I)
U = uint8(round(min(max(I, 0), 1) * 255));
end
