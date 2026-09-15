function signatureGUI()

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

BG    = [0.07 0.07 0.09];
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
DOT   = ['   ' char(183) '   '];

model    = [];
testPath = '';
lastR    = [];

fig = uifigure('Name', 'DSP Bank Signature Verification', ...
    'Color', BG, 'Position', [80 60 1120 740]);

root = uigridlayout(fig, [4 1]);
root.RowHeight   = {52, '1x', 236, 64};
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
mg = uigridlayout(mblk, [6 2]);
mg.ColumnWidth = {'1x', 90};
mg.RowHeight = repmat({'1x'}, 1, 6);
mg.BackgroundColor = CARD;
mg.Padding = [16 10 16 10];
mg.RowSpacing = 2;

metricNames = {'Fused score', 'Threshold', 'Feature similarity', ...
               'Cross-correlation', 'Feature distance', 'Confidence'};
metricVals  = gobjects(1, 6);
for i = 1:6
    n = uilabel(mg, 'Text', metricNames{i}, 'FontSize', 13, 'FontColor', DIM);
    n.Layout.Row = i; n.Layout.Column = 1;
    v = uilabel(mg, 'Text', char(8212), 'FontSize', 14, 'FontColor', FG, ...
        'FontName', 'Consolas', 'HorizontalAlignment', 'right');
    v.Layout.Row = i; v.Layout.Column = 2;
    metricVals(i) = v;
end

ftr = uigridlayout(root, [1 5]);
ftr.Layout.Row = 4;
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
        for i = 1:6, metricVals(i).Text = char(8212); metricVals(i).FontColor = FG; end
        cla(barAx); styleBarAxes(barAx);
        lastR = [];
    end

    function onEnrol(~, ~)
        d = uigetdir(pwd, 'Select the folder holding the genuine specimens');
        try, figure(fig); catch, end
        if isequal(d, 0), return; end
        files = dir(fullfile(d, 'genuine_*.png'));
        if numel(files) < 3
            files = [dir(fullfile(d,'*.png')); dir(fullfile(d,'*.jpg')); ...
                     dir(fullfile(d,'*.jpeg')); dir(fullfile(d,'*.bmp')); ...
                     dir(fullfile(d,'*.tif'))];
        end
        if numel(files) < 3
            uialert(fig, 'Need at least 3 genuine signature images in that folder.', ...
                    'Enrolment');
            return;
        end
        paths = fullfile(d, {files.name});
        [~, uid] = fileparts(d);

        dlg = uiprogressdlg(fig, 'Title', 'Enrolling writer', ...
            'Message', sprintf('Preprocessing and extracting features from %d specimens...', ...
            numel(paths)), 'Indeterminate', 'on');
        try
            model = enrollUser(paths, uid, struct());
        catch ME
            close(dlg);
            uialert(fig, ME.message, 'Enrolment failed');
            return;
        end
        close(dlg);

        showInk(axRef, model.refImgs{1}, INK);
        capRef.Text = sprintf('%s   \x00B7   %d specimens on file   \x00B7   threshold %.3f', ...
                              uid, model.nSamples, model.thr);
        chipDot.FontColor = COK;
        chipTxt.Text = sprintf('Account: %s', uid);
        t = model.thr * 100;
        gauge.ScaleColorLimits = [0 t; t 100];
        resetDecision();
        lblStatus.Text = 'Step 2: load the questioned signature image.';
    end

    function onLoad(~, ~)
        [fn, pn] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
                              'Signature images'}, 'Select the test signature');
        try, figure(fig); catch, end
        if isequal(fn, 0), return; end
        testPath = fullfile(pn, fn);
        prep = struct();
        if ~isempty(model), prep = model.prep; end
        try
            Bt = preprocessSignature(testPath, prep);
            showInk(axTest, Bt, INK);
        catch ME
            uialert(fig, ME.message, 'Could not read image');
            return;
        end
        capTest.Text = fn;
        resetDecision();
        if isempty(model)
            lblStatus.Text = 'Now enrol a writer (step 1), then verify.';
        else
            lblStatus.Text = 'Step 3: verify.';
        end
    end

    function onVerify(~, ~)
        if isempty(model)
            uialert(fig, 'Enrol a writer first.', 'Verify'); return;
        end
        if isempty(testPath)
            uialert(fig, 'Load a test signature first.', 'Verify'); return;
        end
        try
            R = verifySignature(model, testPath, false);
        catch ME
            uialert(fig, ME.message, 'Verification failed'); return;
        end
        lastR = R;

        col = CBAD; word = 'FORGED';
        if R.isAuthentic, col = COK; word = 'AUTHENTIC'; end

        gauge.Value = R.score * 100;
        lblDecision.Text = word;
        lblDecision.FontColor = col;
        lblConf.Text = sprintf('%.1f%% confidence   \x00B7   score %.3f vs threshold %.3f', ...
                               R.confidence, R.score, R.threshold);
        lblConf.FontColor = FG;

        cla(barAx); styleBarAxes(barAx); hold(barAx, 'on');
        barh(barAx, 1, 1, 'FaceColor', CARD, 'EdgeColor', 'none', 'BarWidth', 0.55);
        barh(barAx, 1, R.score, 'FaceColor', col, 'EdgeColor', 'none', 'BarWidth', 0.55);
        plot(barAx, [R.threshold R.threshold], [0.6 1.4], '--', ...
             'Color', FG, 'LineWidth', 2);
        hold(barAx, 'off');

        vals = {sprintf('%.3f', R.score), sprintf('%.3f', R.threshold), ...
                sprintf('%.3f', R.featureSim), sprintf('%.3f', R.corrSim), ...
                sprintf('%.3f', R.distance), sprintf('%.1f %%', R.confidence)};
        for i = 1:6, metricVals(i).Text = vals{i}; metricVals(i).FontColor = FG; end
        metricVals(1).FontColor = col;
        metricVals(6).FontColor = col;

        showInk(axTest, R.B, ternary(R.isAuthentic, CTST, CREF));
        lblStatus.Text = sprintf('Verified %s against account %s.', ...
                                 capTest.Text, model.userId);
    end

    function onDetail(~, ~)
        if isempty(model) || isempty(testPath)
            uialert(fig, 'Enrol a writer and load a test image first.', 'Analysis');
            return;
        end
        verifySignature(model, testPath, true);
    end

    function v = ternary(c, a, b)
        if c, v = a; else, v = b; end
    end
end
