function E = evaluateSystem(dataDir, nRefs, enrolOpts)

if nargin < 2 || isempty(nRefs),     nRefs     = 4; end
if nargin < 3 || isempty(enrolOpts), enrolOpts = struct(); end

writers = dir(fullfile(dataDir, 'writer*'));
writers = writers([writers.isdir]);

E.scores = []; E.labels = []; E.types = {}; E.dec = [];
E.dsp = []; E.ml = [];
E.models = {};
E.example = struct('model', [], 'genuine', '', 'forged', '');

for w = 1:numel(writers)
    wdir = fullfile(dataDir, writers(w).name);
    gen  = dir(fullfile(wdir, 'genuine_*.png'));
    skf  = dir(fullfile(wdir, 'forged_skilled_*.png'));
    rnf  = dir(fullfile(wdir, 'forged_random_*.png'));
    gen  = fullfile(wdir, {gen.name});
    skf  = fullfile(wdir, {skf.name});
    rnf  = fullfile(wdir, {rnf.name});

    if numel(gen) < nRefs + 1
        warning('Skipping %s: not enough genuine samples.', writers(w).name);
        continue;
    end

    refs  = gen(1:nRefs);
    tests = gen(nRefs+1:end);

    model = enrollUser(refs, writers(w).name, enrolOpts);
    E.models{end+1} = model;

    probes = [tests, skf, rnf];
    labels = [ones(1, numel(tests)), zeros(1, numel(skf) + numel(rnf))];
    types  = [repmat({'genuine'}, 1, numel(tests)), ...
              repmat({'skilled'}, 1, numel(skf)), ...
              repmat({'random'},  1, numel(rnf))];

    dec = false(size(probes));
    for i = 1:numel(probes)
        R = verifySignature(model, probes{i}, false, true);
        dec(i) = R.isAuthentic;
        E.scores(end+1) = R.score;
        E.labels(end+1) = labels(i);
        E.types{end+1}  = types{i};
        E.dec(end+1)    = R.isAuthentic;
        E.dsp(end+1)    = R.dspScore;
        E.ml(end+1)     = R.mlProb;
    end

    g = labels == 1;
    fprintf('  %-12s genuine accepted %d/%d   forged rejected %d/%d\n', ...
            writers(w).name, sum(dec(g)), sum(g), sum(~dec(~g)), sum(~g));

    if isempty(E.example.model)
        E.example.model   = model;
        E.example.genuine = tests{1};
        if ~isempty(skf), E.example.forged = skf{1};
        elseif ~isempty(rnf), E.example.forged = rnf{1}; end
    end
end

gIdx = E.labels == 1;
fIdx = E.labels == 0;

E.FRR = 100 * mean(~E.dec(gIdx));
E.FAR = 100 * mean( E.dec(fIdx));
E.ACC = 100 * mean(E.dec == E.labels);

isSk = strcmp(E.types, 'skilled');
isRn = strcmp(E.types, 'random');
E.skilledFAR = NaN; E.randomFAR = NaN;
if any(isSk), E.skilledFAR = 100 * mean(E.dec(isSk)); end
if any(isRn), E.randomFAR  = 100 * mean(E.dec(isRn)); end

E.th  = linspace(0, 1, 501);
E.far = zeros(size(E.th)); E.frr = zeros(size(E.th));
for k = 1:numel(E.th)
    E.far(k) = mean(E.scores(fIdx) >= E.th(k));
    E.frr(k) = mean(E.scores(gIdx) <  E.th(k));
end
[~, E.ke] = min(abs(E.far - E.frr));
E.EER = 100 * (E.far(E.ke) + E.frr(E.ke)) / 2;
E.nGenuine = sum(gIdx);
E.nForged  = sum(fIdx);
end
