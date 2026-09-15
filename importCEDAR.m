function n = importCEDAR(cedarRoot, outDir, writerIds)

if nargin < 2 || isempty(outDir), outDir = fullfile(pwd, 'data'); end
if nargin < 3 || isempty(writerIds), writerIds = 1:55; end

orgDir  = findDir(cedarRoot, 'full_org');
forgDir = findDir(cedarRoot, 'full_forg');
if isempty(orgDir) || isempty(forgDir)
    error('importCEDAR:layout', ...
        ['Could not find full_org / full_forg under %s.\n' ...
         'Download CEDAR from https://cedar.buffalo.edu/NIJ/data/signatures.rar\n' ...
         '(or the Kaggle mirror) and extract it, then pass that folder.'], cedarRoot);
end

if ~exist(outDir, 'dir'), mkdir(outDir); end

n = 0;
for k = 1:numel(writerIds)
    wid = writerIds(k);
    dst = fullfile(outDir, sprintf('writer%02d', k));
    if ~exist(dst, 'dir'), mkdir(dst); end

    ng = 0; nf = 0;
    for s = 1:24
        src = fullfile(orgDir, sprintf('original_%d_%d.png', wid, s));
        if exist(src, 'file')
            ng = ng + 1;
            copyfile(src, fullfile(dst, sprintf('genuine_%02d.png', ng)));
        end
        src = fullfile(forgDir, sprintf('forgeries_%d_%d.png', wid, s));
        if exist(src, 'file')
            nf = nf + 1;
            copyfile(src, fullfile(dst, sprintf('forged_skilled_%02d.png', nf)));
        end
    end
    if ng == 0 && nf == 0
        rmdir(dst);
        warning('CEDAR writer %d: no files found.', wid);
        continue;
    end
    n = n + 1;
    fprintf('CEDAR writer %2d -> %s  (%d genuine, %d skilled forgeries)\n', ...
            wid, sprintf('writer%02d', k), ng, nf);
end
fprintf('Imported %d writers into %s\n', n, outDir);
end

function d = findDir(root, name)
d = '';
cands = {fullfile(root, name), fullfile(root, 'signatures', name), ...
         fullfile(root, 'CEDAR', name)};
for i = 1:numel(cands)
    if exist(cands{i}, 'dir'), d = cands{i}; return; end
end
hits = dir(fullfile(root, '**', name));
hits = hits([hits.isdir]);
if ~isempty(hits), d = fullfile(hits(1).folder, hits(1).name); end
end
