function R = checkSignature(accountId, testImage, showPlot)

if nargin < 3, showPlot = false; end

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));

model = loadRegisteredModel(accountId, root);

if nargin < 2 || isempty(testImage)
    [fn, pn] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Signature images'}, ...
        sprintf('Select the questioned signature for %s', accountId));
    if isequal(fn, 0), R = []; fprintf('Cancelled.\n'); return; end
    testImage = fullfile(pn, fn);
end

R = verifySignature(model, testImage, showPlot);
R.accountId = model.userId;
end

function model = loadRegisteredModel(accountId, root)
f = fullfile(root, 'models', [regexprep(char(accountId), ...
                              '[^A-Za-z0-9_\-]', '_') '.mat']);
if ~exist(f, 'file')
    ids = listRegistered();
    if isempty(ids)
        error('checkSignature:notRegistered', ...
            ['Account "%s" is not registered, and no accounts exist yet. ' ...
             'Run registerPerson first.'], accountId);
    end
    error('checkSignature:notRegistered', ...
        'Account "%s" is not registered. Registered accounts: %s', ...
        accountId, strjoin(ids, ', '));
end
S = load(f, 'model');
model = S.model;
end
