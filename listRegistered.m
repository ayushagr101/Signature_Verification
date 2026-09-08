function ids = listRegistered()

root     = fileparts(mfilename('fullpath'));
modelDir = fullfile(root, 'models');
ids      = {};

d = dir(fullfile(modelDir, '*.mat'));
if isempty(d)
    if nargout == 0
        fprintf('No accounts registered yet. Use registerPerson.\n');
    end
    return;
end

rows = cell(numel(d), 4);
for i = 1:numel(d)
    S = load(fullfile(modelDir, d(i).name), 'model');
    m = S.model;
    ids{end+1} = m.userId;
    reg = 'unknown';
    if isfield(m, 'registeredOn'), reg = m.registeredOn; end
    rows(i,:) = {m.userId, m.nSamples, m.thr, reg};
end

if nargout == 0
    fprintf('\n%-20s %9s %12s   %s\n', 'ACCOUNT', 'SPECIMENS', ...
            'THRESHOLD', 'REGISTERED');
    fprintf('%s\n', repmat('-', 1, 72));
    for i = 1:size(rows,1)
        fprintf('%-20s %9d %12.3f   %s\n', rows{i,1}, rows{i,2}, ...
                rows{i,3}, rows{i,4});
    end
    fprintf('\n');
end
end
