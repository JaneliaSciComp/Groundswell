classdef Test_roving_overlay < Roving_test_case
% Test_roving_overlay  File > Overlay > Load overlay...
%
% Synthesise a .ovl overlay file (using the app's own Overlay_file_writer) whose
% line objects span the full 1..256 image extent, open the test TIFF in Roving,
% load the overlay, and check that the overlay lines are drawn into the main
% (image) axes.

  methods (Access = private)
    function p = writeOvl(testCase, n_frames, lines)
      % Write a .ovl with the same set of line objects on every frame, using
      % the application's own writer (so the on-disk format is authoritative).
      dtmp = tempname();
      mkdir(dtmp);
      testCase.addTeardown(@() rmdir(dtmp, 's'));
      p = fullfile(dtmp, 'synthetic.ovl');
      w = roving.Overlay_file_writer(p, n_frames);
      frame = lines(:);   % a frame overlay is a cell column of overlay objects
      for f = 1:n_frames
        w.append_frame_overlay(frame);
      end
      w.close();
    end
  end

  methods (Test)
    function testLoadOverlayDrawsLines(testCase)
      c = testCase.openTif();   % oct8B_8-24 bit.tif: 61 frames, 256x256
      % no overlay yet -> the show/hide overlay menu is disabled
      testCase.verifyEqual(char(get(c.view.show_overlay_menu_h, 'Enable')), 'off');

      % three line overlays, all coordinates in 1..256 inclusive: a diagonal
      % (uses every integer coord), the anti-diagonal, and the full-frame border
      d = (1:256)';
      lines = { roving.Line_overlay(d,           d,            2, [1 0 0]), ...
                roving.Line_overlay(d,           flipud(d),    2, [0 1 0]), ...
                roving.Line_overlay([1;256;256;1;1], [1;1;256;256;1], 2, [0 0 1]) };

      ovl = testCase.writeOvl(double(c.model.n_frames), lines);

      % File > Overlay > Load overlay... : uigetfile returns the .ovl
      [dd, n, e] = fileparts(ovl);
      c.dialog_responses = {{[n e], [dd filesep]}};
      testCase.trigger(c.view.load_overlay_menu_h);
      testCase.verifyEmpty(c.dialog_messages, 'loading the overlay raised an error dialog');

      % the overlay was drawn as line objects in the main (image) axes
      h = c.view.overlay_h;
      testCase.verifyEqual(numel(h), numel(lines), 'wrong number of overlay objects');
      for k = 1:numel(h)
        testCase.verifyTrue(ishghandle(h(k)) && strcmp(get(h(k), 'Type'), 'line'), ...
          'overlay object is not a drawn line');
        testCase.verifyTrue(isequal(get(h(k), 'Parent'), c.view.image_axes_h), ...
          'overlay line is not in the main image axes');
      end

      % loading an overlay enables the show/hide-overlay menu item
      testCase.verifyEqual(char(get(c.view.show_overlay_menu_h, 'Enable')), 'on');

      % the drawn coordinates are the ones we wrote -- all within 1..256, and
      % spanning the full extent (1 and 256 both present)
      allx = []; ally = [];
      for k = 1:numel(h)
        xd = get(h(k), 'XData'); yd = get(h(k), 'YData');
        allx = [allx; xd(:)]; ally = [ally; yd(:)]; %#ok<AGROW>
      end
      testCase.verifyGreaterThanOrEqual(min(allx), 1);
      testCase.verifyLessThanOrEqual(max(allx), 256);
      testCase.verifyGreaterThanOrEqual(min(ally), 1);
      testCase.verifyLessThanOrEqual(max(ally), 256);
      testCase.verifyEqual([min(allx) max(allx) min(ally) max(ally)], [1 256 1 256], ...
        'overlay does not span the full 1..256 extent');
    end
  end
end
