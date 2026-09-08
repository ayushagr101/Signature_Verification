function signatureGUI()

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

S.model = [];
S.testPath = '';

S.fig = figure('Name', 'DSP Bank Signature Verification', ...
    'NumberTitle', 'off', 'Color', [0.96 0.96 0.98], ...
    'Position', [120 120 980 600], 'MenuBar', 'none', 'ToolBar', 'none');

uicontrol('Style','text','Parent',S.fig,'Units','normalized', ...
    'Position',[0.02 0.92 0.96 0.06], ...
    'String','A DSP-Based Bank Signature Verification System', ...
    'FontSize',14,'FontWeight','bold', ...
    'BackgroundColor',[0.96 0.96 0.98]);

S.axRef  = axes('Parent',S.fig,'Units','normalized', ...
                'Position',[0.04 0.50 0.42 0.36]);
axis(S.axRef,'off'); title(S.axRef,'Reference specimen');

S.axTest = axes('Parent',S.fig,'Units','normalized', ...
                'Position',[0.52 0.50 0.42 0.36]);
axis(S.axTest,'off'); title(S.axTest,'Questioned signature');

S.axScore = axes('Parent',S.fig,'Units','normalized', ...
                 'Position',[0.06 0.16 0.60 0.22]);
axis(S.axScore,'off');

S.btnEnrol = uicontrol('Style','pushbutton','Parent',S.fig, ...
    'Units','normalized','Position',[0.04 0.04 0.20 0.07], ...
    'String','1. Enrol writer','FontSize',10,'Callback',@onEnrol);

S.btnLoad = uicontrol('Style','pushbutton','Parent',S.fig, ...
    'Units','normalized','Position',[0.26 0.04 0.20 0.07], ...
    'String','2. Load test image','FontSize',10,'Callback',@onLoad);

S.btnVerify = uicontrol('Style','pushbutton','Parent',S.fig, ...
    'Units','normalized','Position',[0.48 0.04 0.20 0.07], ...
    'String','3. Verify','FontSize',10,'FontWeight','bold', ...
    'Callback',@onVerify);

S.btnDetail = uicontrol('Style','pushbutton','Parent',S.fig, ...
    'Units','normalized','Position',[0.70 0.04 0.26 0.07], ...
    'String','Show DSP analysis figure','FontSize',10,'Callback',@onDetail);

S.txt = uicontrol('Style','text','Parent',S.fig,'Units','normalized', ...
    'Position',[0.70 0.16 0.26 0.22],'FontSize',11, ...
    'HorizontalAlignment','left','BackgroundColor',[1 1 1], ...
    'String', sprintf('Status\n------\nNo writer enrolled.'));

guidata(S.fig, S);

    function onEnrol(~,~)
        S = guidata(S.fig);
        d = uigetdir(pwd, 'Select the folder holding the genuine specimens');
        if isequal(d, 0), return; end
        files = dir(fullfile(d, 'genuine_*.png'));
        if numel(files) < 3
            files = [dir(fullfile(d,'*.png')); dir(fullfile(d,'*.jpg')); ...
                     dir(fullfile(d,'*.bmp')); dir(fullfile(d,'*.tif'))];
        end
        if numel(files) < 3
            errordlg('Need at least 3 genuine signature images.','Enrolment');
            return;
        end
        paths = fullfile(d, {files.name});
        set(S.txt,'String','Enrolling... please wait'); drawnow;
        [~, uid] = fileparts(d);
        try
            S.model = enrollUser(paths, uid, struct());
        catch ME
            errordlg(ME.message, 'Enrolment failed'); return;
        end
        imshow(~S.model.refImgs{1}, 'Parent', S.axRef);
        title(S.axRef, sprintf('Reference specimen (%s, %d samples)', ...
              uid, S.model.nSamples), 'Interpreter','none');
        set(S.txt,'String', sprintf(['Status\n------\nEnrolled: %s\n' ...
            'Samples: %d\nFeatures: %d\nThreshold: %.3f'], uid, ...
            S.model.nSamples, size(S.model.F,1), S.model.thr));
        guidata(S.fig, S);
    end

    function onLoad(~,~)
        S = guidata(S.fig);
        [fn, pn] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif', ...
                              'Signature images'}, 'Select the test signature');
        if isequal(fn, 0), return; end
        S.testPath = fullfile(pn, fn);
        I = imread(S.testPath);
        imshow(I, 'Parent', S.axTest);
        title(S.axTest, fn, 'Interpreter', 'none');
        guidata(S.fig, S);
    end

    function onVerify(~,~)
        S = guidata(S.fig);
        if isempty(S.model)
            errordlg('Enrol a writer first.','Verify'); return;
        end
        if isempty(S.testPath)
            errordlg('Load a test signature first.','Verify'); return;
        end
        R = verifySignature(S.model, S.testPath, false);
        S.R = R;

        col = [0.85 0.25 0.20];
        if R.isAuthentic, col = [0.20 0.70 0.30]; end

        cla(S.axScore); axis(S.axScore,'on'); hold(S.axScore,'on');
        barh(S.axScore, 1, R.score, 'FaceColor', col);
        plot(S.axScore, [S.model.thr S.model.thr], [0.5 1.5], ...
             'k--', 'LineWidth', 2);
        xlim(S.axScore, [0 1]); ylim(S.axScore, [0.5 1.5]);
        set(S.axScore, 'YTick', []); grid(S.axScore, 'on');
        xlabel(S.axScore, 'similarity score  (dashed line = threshold)');
        title(S.axScore, sprintf('%s   -   score %.3f, confidence %.1f%%', ...
              R.decision, R.score, R.confidence), 'Color', col, ...
              'FontSize', 13, 'FontWeight', 'bold');
        hold(S.axScore,'off');

        set(S.txt,'String', sprintf([ ...
            'Result\n------\n%s\nScore      : %.3f\nThreshold  : %.3f\n' ...
            'Feature sim: %.3f\nCorrelation: %.3f\nConfidence : %.1f%%'], ...
            R.decision, R.score, R.threshold, R.featureSim, R.corrSim, ...
            R.confidence));
        guidata(S.fig, S);
    end

    function onDetail(~,~)
        S = guidata(S.fig);
        if isempty(S.model) || isempty(S.testPath)
            errordlg('Enrol a writer and load a test image first.','Analysis');
            return;
        end
        verifySignature(S.model, S.testPath, true);
    end
end
