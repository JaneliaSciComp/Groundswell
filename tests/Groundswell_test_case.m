classdef Groundswell_test_case < matlab.unittest.TestCase
% Groundswell_test_case  Shared fixtures for the groundswell app test suite.
%
% These tests are a back-port of the Python end-to-end tests in
% pygroundswell/tests/ (test_app_open.py, ...).  They drive the *real*
% groundswell.Controller / View through the real menu/button callbacks.  The
% interactive dialogs are handled by the Controller's test mode: a test sets
% c.is_in_test_mode = true, queues the answers a dialog should return in
% c.dialog_responses, and reads any errordlg/msgbox text from c.dialog_messages
% (see @Controller's "dialog wrappers").  A figure is created on the display,
% so a DISPLAY (or xvfb) must be available; each test closes its figures on
% teardown.
%
% Run from the groundswell/ directory:
%   results = runtests('tests');            % whole suite
%   results = runtests('tests/Test_app_open.m')

  properties
    TestFile          % absolute path to a valid 22-channel test.tcs (or '')
    SavedPath         % MATLAB path to restore after the class runs
  end

  methods (TestClassSetup)
    function setupPath(testCase)
      testCase.SavedPath = path();
      here = fileparts(mfilename('fullpath'));   % groundswell/tests
      repo = fileparts(here);                    % groundswell/ (has +groundswell)
      addpath(repo);                             % make modpath + packages visible
      addpath(here);                             % make test_files_dir visible
      modpath();                                 % adds tmt_116, utility, repo
      % The shared sample file lives in a test-files dir near the repo, as in
      % the Python tests.
      td = test_files_dir();
      cand = fullfile(td, 'test.tcs');
      if ~isempty(td) && exist(cand, 'file')
        testCase.TestFile = char(java.io.File(cand).getCanonicalPath());
      else
        testCase.TestFile = '';
      end
    end
  end

  methods (TestClassTeardown)
    function restorePath(testCase)
      path(testCase.SavedPath);
    end
  end

  methods (TestMethodTeardown)
    function closeFigures(~)
      close all force;
    end
  end

  methods (Access = protected)
    function requireTestFile(testCase)
      % Skip (filter) the test if the sample .tcs is not present, mirroring
      % the Python @skipUnless guard.
      testCase.assumeNotEmpty(testCase.TestFile, ...
        'valid test .tcs not present');
    end

    function c = newController(testCase)
      % A Controller in test mode, so its dialog wrappers consume queued
      % responses / record messages instead of opening real modal dialogs.
      c = groundswell.Controller();
      c.is_in_test_mode = true;
    end

    function r = fileResponse(~, p)
      % The response a uigetfile/uiputfile wrapper expects: {filename, dir}.
      [d, n, e] = fileparts(p);
      r = {[n e], [d filesep]};
    end

    function c = openViaMenu(testCase)
      % Build a Controller and drive File > Open through its real menu callback
      % (the analog of triggering the Qt menu action in Python); the queued
      % response is what uigetfile returns.  test.tcs is single-time-base, so no
      % upsample questdlg follows.
      testCase.requireTestFile();
      c = testCase.newController();
      c.dialog_responses = { testCase.fileResponse(testCase.TestFile) };
      testCase.trigger(c.view.open_menu_h);
      testCase.verifyEmpty(c.dialog_messages, ...
        'opening the test .tcs raised error dialog(s)');
    end

    function figs = newFigures(~, before)
      % Figures that appeared since the handle list `before`.
      figs = setdiff(findall(0, 'Type', 'figure'), before);
    end

    function frac = nonWhiteFraction(~, fig, w, h)
      % Render a figure and return the fraction of pixels that aren't
      % near-white -- a proxy for "something was drawn", mirroring the Python
      % _nonwhite_fraction helper.
      if nargin < 3, w = 700; h = 500; end
      set(fig, 'Position', [100 100 w h]);
      drawnow;
      img = frame2im(getframe(fig));
      r = img(:, :, 1); g = img(:, :, 2); b = img(:, :, 3);
      nonwhite = (r < 240) | (g < 240) | (b < 240);
      frac = nnz(nonwhite) / numel(nonwhite);
    end

    function trigger(~, h)
      % Fire a handle's Callback (uimenu/uicontrol) the way a user click would.
      cb = get(h, 'Callback');
      if ~isempty(cb)
        feval(cb, h, []);
      end
    end

    function fireButtonDown(~, h)
      % Fire a graphics object's ButtonDownFcn (used for channel-label clicks).
      cb = get(h, 'ButtonDownFcn');
      if ~isempty(cb)
        feval(cb, h, []);
      end
    end

    function fireMenuItem(testCase, fig, parentLabel, itemLabel)
      % Fire an analysis window's submenu item by label (e.g. 'X axis' >
      % 'Logarithmic'), found on its figure -- the parent label disambiguates
      % the same item label appearing under more than one menu.
      parent = findobj(fig, 'Type', 'uimenu', 'Label', parentLabel);
      item = findobj(parent, 'Type', 'uimenu', 'Label', itemLabel);
      testCase.assertNotEmpty(item, ...
        sprintf('menu item %s > %s not found', parentLabel, itemLabel));
      testCase.trigger(item(1));
    end

    function tf = anyAxisScale(~, fig, whichAxis, value)
      % True if any data axes on the figure has the given 'XScale'/'YScale'.
      axs = findobj(fig, 'Type', 'axes');
      tf = false;
      for k = 1:numel(axs)
        if strcmpi(get(axs(k), [whichAxis 'Scale']), value), tf = true; return; end
      end
    end

    function c = loadedController(testCase, file)
      % A Controller with a .tcs opened through the real open() path, dialogs
      % stubbed.  Defaults to the shared test.tcs.
      if nargin < 2
        testCase.requireTestFile();
        file = testCase.TestFile;
      end
      c = testCase.newController();
      c.open(file);
    end

    function c = importedController(testCase, file, fileTypeStr)
      % A Controller with a file brought in through the real import() path.
      c = testCase.newController();
      if nargin < 3
        c.import(file);
      else
        c.import(file, fileTypeStr);
      end
    end

    function selectChannels(testCase, c, channels)
      % Select one or more channels through the real label-click path: the
      % first as a plain click ('normal'), the rest as ctrl-clicks ('alt'),
      % mirroring the Python _select helper.
      for idx = 1:numel(channels)
        if idx == 1
          set(c.view.fig_h, 'selectiontype', 'normal');
        else
          set(c.view.fig_h, 'selectiontype', 'alt');
        end
        testCase.fireButtonDown(get(c.view.axes_hs(channels(idx)), 'ylabel'));
      end
    end

    function d = modelData(~, c)
      d = double(c.model.data);
    end

    function v = tlView(~, c)
      % The current time-view [lo hi] as a double row.
      v = double(c.view.tl_view(:)');
    end

    function sel = selectedList(~, c)
      sel = sort(double(c.view.i_selected(:)'));
    end
  end
end
