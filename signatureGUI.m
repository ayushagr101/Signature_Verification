function signatureGUI()

rootDir = fileparts(mfilename('fullpath'));
addpath(fullfile(rootDir, 'src'));

logDir = fullfile(rootDir, 'logs');
if ~exist(logDir, 'dir'), mkdir(logDir); end
logFile = fullfile(logDir, 'signatureGUI.log');

BG   = [0.07 0.07 0.09];
PANEL = [0.12 0.12 0.15];
CARD  = [0.16 0.16 0.20];
BTN   = [0.22 0.22 0.27];
ACC   = [0.24 0.52 0.96];
FG    = [0.94 0.94 0.96];
DIM   = [0.60 0.60 0.66];
INK   = [0.96 0.96 0.98];
COK   = [0.25 0.85 0.45];
CBAD  = [0.95 0.35 0.30];
CREF  = [1.00 0.50 0.35];
CTST  = [0.30 0.75 1.00];
CBUSY = [0.98 0.75 0.25];
DOT  = ['   ' char(183) '   '];

model    = [];
testPath = '';
lastR    = [];

fig = uifigure('Name', 'DSP Bank Signature Verification', ...
    'Color', BG, 'Position', [80 40 1120 860]);

root = uigridlayout(fig, [5 1]);
root.RowHeight   = {52, '1x', 236, 120, 64};
root.ColumnWidth = {'1x'};
root.BackgroundColor = BG;
root.Padding    = [18 14 18 14];
root.RowSpacing = 14;

hdr = uigridlayout(root, [1 2]);
hdr.Layout.Row = 1;
hdr.ColumnWidth = {'1x', 320};
hdr.BackgroundColor = BG;
hdr.Padding = [0 0 0 0];

ttl = uilabel(hdr, 'Text', 'DSP Bank Signature Verification', ...
    'FontSize', 22, 'FontWeight', 'bold', 'FontColor', FG, ...
    'VerticalAlignment', 'center');
ttl.Layout.Column = 1;

chipPanel = uipanel(hdr, 'BackgroundColor', CARD, 'BorderType', 'none');
chipPanel.Layout.Column = 2;
chipGrid = uigridlayout(chipPanel, [1 2]);
chipGrid.ColumnWidth = {14, '1x'};
chipGrid.BackgroundColor = CARD;
chipGrid.Padding = [12 6 12 6];
chipGrid.ColumnSpacing = 10;
chipDot = uilabel(chipGrid, 'Text', char(9679), 'FontSize', 16, ...
    'FontColor', DIM, 'HorizontalAlignment', 'center');
chipDot.Layout.Column = 1;
chipTxt = uilabel(chipGrid, 'Text', 'No account enrolled', ...
    'FontSize', 13, 'FontColor', FG, 'VerticalAlignment', 'center');
chipTxt.Layout.Column = 2;

mid = uigridlayout(root, [1 2]);
mid.Layout.Row = 2;
mid.ColumnWidth = {'1x', '1x'};
mid.BackgroundColor = BG;
mid.Padding = [0 0 0 0];
mid.ColumnSpacing = 14;

[axRef,  capRef]  = makeImagePanel(mid, 1, 'REFERENCE SPECIMEN');
[axTest, capTest] = makeImagePanel(mid, 2, 'QUESTIONED SIGNATURE');

decPanel = uipanel(root, 'BackgroundColor', PANEL, 'BorderType', 'none');
decPanel.Layout.Row = 3;
dec = uigridlayout(decPanel, [1 3]);
dec.ColumnWidth = {230, '1x', 330};
dec.BackgroundColor = PANEL;
dec.Padding = [18 14 18 14];
dec.ColumnSpacing = 20;

gauge = uigauge(dec, 'circular');
gauge.Layout.Column = 1;
gauge.Limits = [0 100];
gauge.Value  = 0;
gauge.MajorTicks = 0:20:100;
gauge.MinorTicks = 0:5:100;
gauge.BackgroundColor = PANEL;
gauge.FontColor = FG;
gauge.ScaleColors = [CBAD; COK];
gauge.ScaleColorLimits = [0 50; 50 100];

dblk = uigridlayout(dec, [4 1]);
dblk.Layout.Column = 2;
dblk.RowHeight = {24, 48, 26, '1x'};
dblk.BackgroundColor = PANEL;
dblk.Padding = [0 0 0 0];
dblk.RowSpacing = 4;

lblKicker = uilabel(dblk, 'Text', 'DECISION', 'FontSize', 11, ...
    'FontWeight', 'bold', 'FontColor', DIM);
lblKicker.Layout.Row = 1;
lblDecision = uilabel(dblk, 'Text', char(8212), 'FontSize', 36, ...
    'FontWeight', 'bold', 'FontColor', DIM);
lblDecision.Layout.Row = 2;
lblConf = uilabel(dblk, 'Text', 'Enrol a writer, load a test signature, then verify.', ...
    'FontSize', 13, 'FontColor', DIM);
lblConf.Layout.Row = 3;

barAx = uiaxes(dblk);
barAx.Layout.Row = 4;
styleBarAxes(barAx);

mblk = uipanel(dec, 'BackgroundColor', CARD, 'BorderType', 'none');
mblk.Layout.Column = 3;
mg = uigridlayout(mblk, [7 2]);
mg.ColumnWidth = {'1x', 90};
mg.RowHeight = repmat({'1x'}, 1, 7);
mg.BackgroundColor = CARD;
mg.Padding = [16 10 16 10];
mg.RowSpacing = 2;

metricNames = {'Fused score', 'DSP score', 'ML probability', 'Threshold', ...
               'Feature similarity', 'Cross-correlation', 'Confidence'};
metricVals  = gobjects(1, 7);
for i = 1:7
    n = uilabel(mg, 'Text', metricNames{i}, 'FontSize', 13, 'FontColor', DIM);
    n.Layout.Row = i; n.Layout.Column = 1;
    v = uilabel(mg, 'Text', char(8212), 'FontSize', 14, 'FontColor', FG, ...
        'FontName', 'Consolas', 'HorizontalAlignment', 'right');
    v.Layout.Row = i; v.Layout.Column = 2;
    metricVals(i) = v;
end

logPanel = uipanel(root, 'BackgroundColor', PANEL, 'BorderType', 'none');
logPanel.Layout.Row = 4;
lgg = uigridlayout(logPanel, [2 1]);
lgg.RowHeight = {16, '1x'};
lgg.BackgroundColor = PANEL;
lgg.Padding = [16 8 16 10];
lgg.RowSpacing = 4;
uilabel(lgg, 'Text', 'ACTIVITY LOG', 'FontSize', 11, ...
    'FontWeight', 'bold', 'FontColor', DIM);
logBox = uitextarea(lgg, 'Editable', 'off', 'FontName', 'Consolas', ...
    'FontSize', 11, 'BackgroundColor', CARD, 'FontColor', FG);

ftr = uigridlayout(root, [1 5]);
ftr.Layout.Row = 5;
ftr.ColumnWidth = {'1x', 170, 170, 150, 210};
ftr.BackgroundColor = BG;
ftr.Padding = [0 0 0 0];
ftr.ColumnSpacing = 10;

lblStatus = uilabel(ftr, 'Text', 'Step 1: enrol a writer from a folder of genuine specimens.', ...
    'FontSize', 12, 'FontColor', DIM, 'VerticalAlignment', 'center');
lblStatus.Layout.Column = 1;

btnEnrol = uibutton(ftr, 'push', 'Text', '1  Enrol writer', ...
    'FontSize', 13, 'BackgroundColor', BTN, 'FontColor', FG, ...
    'ButtonPushedFcn', @onEnrol);
btnEnrol.Layout.Column = 2;

btnLoad = uibutton(ftr, 'push', 'Text', '2  Load test image', ...
    'FontSize', 13, 'BackgroundColor', BTN, 'FontColor', FG, ...
    'ButtonPushedFcn', @onLoad);
btnLoad.Layout.Column = 3;

btnVerify = uibutton(ftr, 'push', 'Text', ['3  Verify  ' char(9654)], ...
    'FontSize', 13, 'FontWeight', 'bold', ...
    'BackgroundColor', ACC, 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @onVerify);
btnVerify.Layout.Column = 4;

btnDetail = uibutton(ftr, 'push', 'Text', 'DSP analysis figure', ...
    'FontSize', 13, 'BackgroundColor', BTN, 'FontColor', FG, ...
    'ButtonPushedFcn', @onDetail);
btnDetail.Layout.Column = 5;

showPlaceholder(axRef,  'no reference loaded');
showPlaceholder(axTest, 'no test signature loaded');
logMsg('INFO', 'GUI started. Log file: %s', logFile);

    function logMsg(level, varargin)
        line = sprintf('%s  %-5s %s', datestr(now, 'HH:MM:SS'), level, ...
                       sprintf(varargin{:}));
        v = logBox.Value;
        if isequal(v, {''}), v = {}; end
        logBox.Value = [{line}; v(:)];   % newest first, no scrolling needed
        fid = fopen(logFile, 'a');
        if fid > 0
            fprintf(fid, '%s %s\n', datestr(now, 'yyyy-mm-dd'), line);
            fclose(fid);
        end
    end

    function setStatus(msg, color)
        if nargin < 2, color = DIM; end
        lblStatus.Text = msg;
        lblStatus.FontColor = color;
    end

    % Loading state: lock the buttons, show a progress dialog and an amber
    % status line. Everything is restored when the returned object dies.
    function c = busy(title, msg)
        btns = [btnEnrol btnLoad btnVerify btnDetail];
        set(btns, 'Enable', 'off');
        setStatus([msg ' ...'], CBUSY);
        dlg = uiprogressdlg(fig, 'Title', title, 'Message', msg, ...
                            'Indeterminate', 'on');
        drawnow;
        c = onCleanup(@() unbusy(btns, dlg));
    end

    function unbusy(btns, dlg)
        if isvalid(dlg), close(dlg); end
        if isvalid(fig), set(btns, 'Enable', 'on'); end
    end

    % Error state: red status line, full error in the log, alert dialog.
    function reportError(where, ME)
        logMsg('ERROR', '%s failed: %s', where, ME.message);
        if ~isempty(ME.identifier), logMsg('ERROR', '  id: %s', ME.identifier); end
        if ~isempty(ME.stack)
            logMsg('ERROR', '  at %s (line %d)', ME.stack(1).name, ME.stack(1).line);
        end
        setStatus(sprintf('%s failed: %s', where, ME.message), CBAD);
        uialert(fig, ME.message, [where ' failed'], 'Icon', 'error');
    end

    function warnUser(msg, ttl)
        logMsg('WARN', '%s', msg);
        setStatus(msg, CBUSY);
        uialert(fig, msg, ttl, 'Icon', 'warning');
    end

    function [ax, cap] = makeImagePanel(parent, col, titleText)
        p = uipanel(parent, 'BackgroundColor', PANEL, 'BorderType', 'none');
        p.Layout.Column = col;
        pg = uigridlayout(p, [3 1]);
        pg.RowHeight = {20, '1x', 22};
        pg.BackgroundColor = PANEL;
        pg.Padding = [16 12 16 12];
        pg.RowSpacing = 8;
        t = uilabel(pg, 'Text', titleText, 'FontSize', 11, ...
            'FontWeight', 'bold', 'FontColor', DIM);
        t.Layout.Row = 1;
        ax = uiaxes(pg);
        ax.Layout.Row = 2;
        ax.Color = PANEL;
        ax.XColor = 'none'; ax.YColor = 'none';
        ax.XTick = []; ax.YTick = [];
        ax.Box = 'off';
        try, ax.Toolbar.Visible = 'off'; catch, end
        try, disableDefaultInteractivity(ax); catch, end
        cap = uilabel(pg, 'Text', '', 'FontSize', 12, 'FontColor', FG);
        cap.Layout.Row = 3;
    end

    function styleBarAxes(ax)
        ax.Color = PANEL;
        ax.XColor = DIM; ax.YColor = 'none';
        ax.YTick = [];
        ax.XLim = [0 1]; ax.YLim = [0.5 1.5];
        ax.XTick = 0:0.25:1;
        ax.GridColor = [0.35 0.35 0.40];
        ax.GridAlpha = 0.5;
        ax.XGrid = 'on';
        ax.Box = 'off';
        ax.FontSize = 10;
        try, ax.Toolbar.Visible = 'off'; catch, end
        try, disableDefaultInteractivity(ax); catch, end
    end

    function showInk(ax, B, inkColor)
        cla(ax);
        RGB = zeros([size(B) 3]);
        for c = 1:3
            ch = PANEL(c) * ones(size(B));
            ch(B) = inkColor(c);
            RGB(:,:,c) = ch;
        end
        image(ax, RGB);
        axis(ax, 'image');
        ax.XColor = 'none'; ax.YColor = 'none';
        ax.XTick = []; ax.YTick = [];
    end

    function showPlaceholder(ax, msg)
        cla(ax);
        ax.XLim = [0 1]; ax.YLim = [0 1];
        text(ax, 0.5, 0.5, msg, 'Color', DIM, 'FontSize', 13, ...
            'HorizontalAlignment', 'center');
        ax.XColor = 'none'; ax.YColor = 'none';
        ax.XTick = []; ax.YTick = [];
    end

    function resetDecision()
        gauge.Value = 0;
        lblDecision.Text = char(8212);
        lblDecision.FontColor = DIM;
        lblConf.Text = 'Enrol a writer, load a test signature, then verify.';
        lblConf.FontColor = DIM;
        for i = 1:7, metricVals(i).Text = char(8212); metricVals(i).FontColor = FG; end
        cla(barAx); styleBarAxes(barAx);
        lastR = [];
    end

    function onEnrol(~, ~)
        d = uigetdir(pwd, 'Select the folder holding the genuine specimens');
        try, figure(fig); catch, end
        if isequal(d, 0), logMsg('INFO', 'Enrolment cancelled.'); return; end
        files = dir(fullfile(d, 'genuine_*.png'));
        if numel(files) < 3
            files = [dir(fullfile(d,'*.png')); dir(fullfile(d,'*.jpg')); ...
                     dir(fullfile(d,'*.jpeg')); dir(fullfile(d,'*.bmp')); ...
                     dir(fullfile(d,'*.tif'))];
        end
        if numel(files) < 3
            warnUser(sprintf('Need at least 3 genuine signature images in %s (found %d).', ...
                     d, numel(files)), 'Enrolment');
            return;
        end
        paths = fullfile(d, {files.name});
        [~, uid] = fileparts(d);
        logMsg('INFO', 'Enrolling "%s" from %d specimens in %s', uid, numel(paths), d);

        opts = struct();
        clfFile = fullfile(rootDir, 'models', 'classifier.mat');
        if exist(clfFile, 'file')
            opts.classifier = clfFile;
            opts.mode = 'hybrid';
            logMsg('INFO', 'Trained classifier found, using hybrid DSP + ML scoring.');
        end
        tunedFile = fullfile(rootDir, 'results', 'tunedParams.mat');
        if exist(tunedFile, 'file')
            T = load(tunedFile, 'best');
            opts.weights = T.best.weights;
            opts.minThr  = T.best.minThr;
            opts.maxThr  = T.best.maxThr;
            opts.kThresh = T.best.kThresh;
            if isfield(opts, 'classifier') && isfield(T.best, 'kThreshHybrid') ...
                    && ~isnan(T.best.kThreshHybrid)
                opts.kThresh = T.best.kThreshHybrid;
            end
            logMsg('INFO', 'Tuned parameters: weights [%.1f %.1f], kThresh %.2f', ...
                   opts.weights(1), opts.weights(2), opts.kThresh);
        end

        c = busy('Enrolling writer', sprintf( ...
            'Preprocessing and extracting features from %d specimens', numel(paths)));
        t0 = tic;
        try
            newModel = enrollUser(paths, uid, opts);
        catch ME
            delete(c);
            chipDot.FontColor = CBAD;
            reportError('Enrolment', ME);
            return;
        end
        delete(c);
        model = newModel;
        logMsg('OK', 'Enrolled "%s" [%s] in %.1f s: %d features, threshold %.3f', ...
               uid, model.mode, toc(t0), size(model.F, 1), model.thr);
        logMsg('INFO', 'Leave-one-out genuine scores: %s', ...
               strtrim(sprintf('%.3f ', model.looScores)));

        showInk(axRef, model.refImgs{1}, INK);
        capRef.Text = sprintf(['%s' DOT '%d specimens on file' DOT 'threshold %.3f'], ...
                              uid, model.nSamples, model.thr);
        chipDot.FontColor = COK;
        modeTxt = 'DSP';
        if ~isempty(model.clf), modeTxt = 'DSP + ML hybrid'; end
        chipTxt.Text = sprintf('Account: %s   [%s]', uid, modeTxt);
        t = model.thr * 100;
        gauge.ScaleColorLimits = [0 t; t 100];
        resetDecision();
        if isempty(testPath)
            setStatus('Step 2: load the questioned signature image.');
        else
            setStatus('Step 3: verify.');
        end
    end

    function onLoad(~, ~)
        [fn, pn] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
                              'Signature images'}, 'Select the test signature');
        try, figure(fig); catch, end
        if isequal(fn, 0), logMsg('INFO', 'Load cancelled.'); return; end
        p = fullfile(pn, fn);
        prep = struct();
        if ~isempty(model), prep = model.prep; end

        c = busy('Loading signature', sprintf('Reading and preprocessing %s', fn));
        try
            [Bt, info] = preprocessSignature(p, prep);
        catch ME
            delete(c);
            testPath = '';
            capTest.Text = '';
            resetDecision();
            showPlaceholder(axTest, 'could not read this image');
            reportError('Loading image', ME);
            return;
        end
        delete(c);
        testPath = p;
        showInk(axTest, Bt, INK);
        capTest.Text = fn;
        resetDecision();
        logMsg('OK', 'Loaded %s: Otsu level %.3f, deskew %.1f deg, %d ink pixels', ...
               fn, info.otsuLevel, info.angle, info.inkPixels);
        if info.inkPixels == 0
            warnUser('No ink was found in this image. Is it a blank scan?', 'Load image');
            return;
        end
        if isempty(model)
            setStatus('Now enrol a writer (step 1), then verify.');
        else
            setStatus('Step 3: verify.');
        end
    end

    function onVerify(~, ~)
        if isempty(model)
            warnUser('Enrol a writer first.', 'Verify'); return;
        end
        if isempty(testPath)
            warnUser('Load a test signature first.', 'Verify'); return;
        end
        c = busy('Verifying', sprintf('Scoring %s against account %s', ...
                 capTest.Text, model.userId));
        t0 = tic;
        try
            R = verifySignature(model, testPath, false, true);
        catch ME
            delete(c);
            resetDecision();
            lblDecision.Text = 'ERROR';
            lblDecision.FontColor = CBAD;
            lblConf.Text = 'Verification could not be completed. See the activity log.';
            lblConf.FontColor = CBAD;
            reportError('Verification', ME);
            return;
        end
        delete(c);
        lastR = R;

        col = CBAD; word = 'FORGED';
        if R.isAuthentic, col = COK; word = 'AUTHENTIC'; end

        gauge.Value = R.score * 100;
        lblDecision.Text = word;
        lblDecision.FontColor = col;
        lblConf.Text = sprintf(['%.1f%% confidence' DOT 'score %.3f vs threshold %.3f'], ...
                               R.confidence, R.score, R.threshold);
        lblConf.FontColor = FG;

        cla(barAx); styleBarAxes(barAx); hold(barAx, 'on');
        barh(barAx, 1, 1, 'FaceColor', CARD, 'EdgeColor', 'none', 'BarWidth', 0.55);
        barh(barAx, 1, R.score, 'FaceColor', col, 'EdgeColor', 'none', 'BarWidth', 0.55);
        plot(barAx, [R.threshold R.threshold], [0.6 1.4], '--', ...
             'Color', FG, 'LineWidth', 2);
        hold(barAx, 'off');

        mlTxt = char(8212);
        if ~isnan(R.mlProb), mlTxt = sprintf('%.3f', R.mlProb); end
        vals = {sprintf('%.3f', R.score), sprintf('%.3f', R.dspScore), mlTxt, ...
                sprintf('%.3f', R.threshold), sprintf('%.3f', R.featureSim), ...
                sprintf('%.3f', R.corrSim), sprintf('%.1f %%', R.confidence)};
        for i = 1:7, metricVals(i).Text = vals{i}; metricVals(i).FontColor = FG; end
        metricVals(1).FontColor = col;
        metricVals(7).FontColor = col;

        showInk(axTest, R.B, ternary(R.isAuthentic, CTST, CREF));
        logMsg(ternary(R.isAuthentic, 'OK', 'ALERT'), ...
               '%s vs %s: %s (score %.3f, threshold %.3f, confidence %.1f%%) in %.2f s', ...
               capTest.Text, model.userId, word, R.score, R.threshold, ...
               R.confidence, toc(t0));
        setStatus(sprintf('Verified %s against account %s: %s.', ...
                  capTest.Text, model.userId, word), col);
    end

    function onDetail(~, ~)
        if isempty(model) || isempty(testPath)
            warnUser('Enrol a writer and load a test image first.', 'Analysis');
            return;
        end
        c = busy('DSP analysis', 'Building the analysis figure');
        try
            verifySignature(model, testPath, true, true);
        catch ME
            delete(c);
            reportError('Analysis figure', ME);
            return;
        end
        delete(c);
        logMsg('INFO', 'Opened DSP analysis figure for %s.', capTest.Text);
        setStatus('DSP analysis figure opened in a separate window.');
    end

    function v = ternary(c, a, b)
        if c, v = a; else, v = b; end
    end
end
