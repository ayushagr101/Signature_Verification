function model = registerPerson(accountId, samples, opts)

if nargin < 1 || isempty(accountId)
    error('registerPerson:noId', 'An account identifier is required.');
end
if nargin < 2, samples = []; end
if nargin < 3, opts = struct(); end

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
modelDir = fullfile(root, 'models');
if ~exist(modelDir, 'dir'), mkdir(modelDir); end

accountId = char(accountId);
target = fullfile(modelDir, [safeName(accountId) '.mat']);

if exist(target, 'file')
    ans_ = input(sprintf(['Account "%s" is already registered. ' ...
                          'Overwrite? [y/N]: '], accountId), 's');
    if isempty(ans_) || lower(ans_(1)) ~= 'y'
        fprintf('Registration cancelled.\n');
        model = [];
        return;
    end
end

if isempty(samples)
    [fn, pn] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Signature images'}, ...
        sprintf('Select 3 or more genuine specimens for %s', accountId), ...
        'MultiSelect', 'on');
    if isequal(fn, 0), model = []; fprintf('Cancelled.\n'); return; end
    if ischar(fn), fn = {fn}; end
    samples = fullfile(pn, fn);
end

model = enrollUser(samples, accountId, opts);

model.accountId    = accountId;
model.registeredOn = datestr(now, 'yyyy-mm-dd HH:MM:SS');

save(target, 'model');

fprintf('Registered "%s" -> %s\n', accountId, target);
fprintf('Verify a cheque with:  checkSignature(''%s'', ''scan.png'')\n', ...
        accountId);
end

function s = safeName(s)
s = regexprep(s, '[^A-Za-z0-9_\-]', '_');
end
