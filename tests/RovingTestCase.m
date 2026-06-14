classdef RovingTestCase < matlab.unittest.TestCase
% RovingTestCase  Shared fixtures for the Roving (imaging/ROI) app tests,
% back-ported from pygroundswell/tests/test_roving_app.py.  Like the
% groundswell AppTestCase, these drive the real roving.Controller / View
% through real menu/button callbacks.  Dialogs are handled by the Controller's
% test mode: set c.is_in_test_mode = true, queue what the input dialogs should
% return in c.dialog_responses, and read any errordlg text from
% c.dialog_messages (see @Controller's "dialog wrappers").
%
% A figure is created on the display, so a DISPLAY (or xvfb) must be available.

  properties
    TifFile        % a 61-frame 256x256 8-bit TIFF (or '')
    RpbFile        % its ROI file (or '')
    JumboFile      % a 4.7 GB ImageJ "jumbo" TIFF (or '')
    Mj2File        % a Motion JPEG 2000 video (or '')
    SavedPath
  end

  methods (TestClassSetup)
    function setupPath(testCase)
      testCase.SavedPath = path();
      here = fileparts(mfilename('fullpath'));
      repo = fileparts(here);                    % groundswell/
      addpath(repo);
      addpath(here);                             % make test_files_dir visible
      modpath();
      td = test_files_dir();
      pick = @(name) iff(exist(fullfile(td, name), 'file'), ...
                         @() char(java.io.File(fullfile(td, name)).getCanonicalPath()), ...
                         @() '');
      testCase.TifFile   = pick('oct8B_8-24 bit.tif');
      testCase.RpbFile   = pick('oct8B_8-24 bit.rpb');
      testCase.JumboFile = pick('imagej_jumbo.tif');
      testCase.Mj2File   = pick('short.mj2');
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
    function requireTif(testCase)
      testCase.assumeNotEmpty(testCase.TifFile, 'test .tif not present');
    end

    function c = newController(testCase)
      c = roving.Controller();
      c.is_in_test_mode = true;
    end

    function r = fileResponse(~, p)
      % What a uigetfile/uiputfile wrapper should return: {filename, dir}, or
      % {0, 0} for "user hit Cancel" (an empty path).
      if isempty(p)
        r = {0, 0};
      else
        [d, n, e] = fileparts(p);
        r = {[n e], [d filesep]};
      end
    end

    function c = openTif(testCase)
      testCase.requireTif();
      c = testCase.newController();
      c.dialog_responses = { testCase.fileResponse(testCase.TifFile) };
      testCase.trigger(c.view.open_video_menu_h);
      testCase.verifyEmpty(c.dialog_messages, ...
        'opening the test .tif raised error dialog(s)');
    end

    function addSquareRoi(~, c, x0, y0, sz)
      if nargin < 3, x0 = 50; end
      if nargin < 4, y0 = 50; end
      if nargin < 5, sz = 40; end
      border = [x0, x0+sz, x0+sz, x0, x0; y0, y0, y0+sz, y0+sz, y0];
      c.add_roi(border);
    end

    function trigger(~, h)
      cb = get(h, 'Callback');
      if ~isempty(cb)
        feval(cb, h, []);
      end
    end

    function setEdit(testCase, h, str)
      % Set an edit uicontrol's text and fire its callback (the analogue of the
      % Python _on_edit_finished()).
      set(h, 'String', str);
      testCase.trigger(h);
    end

    function frac = nonWhiteFraction(~, fig, w, h)
      if nargin < 3, w = 700; h = 500; end
      set(fig, 'Position', [100 100 w h]);
      drawnow;
      img = frame2im(getframe(fig));
      r = img(:, :, 1); g = img(:, :, 2); b = img(:, :, 3);
      frac = nnz((r < 240) | (g < 240) | (b < 240)) / numel(r);
    end
  end
end

function out = iff(cond, ifTrue, ifFalse)
% Tiny ternary helper (cond ? ifTrue() : ifFalse()), used only above.
if cond, out = ifTrue(); else, out = ifFalse(); end
end
