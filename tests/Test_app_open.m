classdef Test_app_open < App_test_case
% Test_app_open  Back-port of pygroundswell/tests/test_app_open.py.
%
% Opens a .tcs through the real File > Open menu callback and exercises
% zoom/scroll, X-axis units + Set Range, channel selection, Y-axis range
% optimisation + Set Range, and the simple mutations.
%
% Two Python tests are intentionally not ported because they depend on the
% PyQt6 layer rather than groundswell logic:
%   * test_scrollbar_drag_after_zoom -- the MATLAB scrollbar callback is
%     commented out in @View/set_hg_callbacks.m; the live scrollbar is a
%     Python-port-only feature, so there is no MATLAB code path to drive.
%   * test_click_drag_zoom_within_axes -- draw_zoom_limits reads the axes
%     CurrentPoint, which is only set by real mouse events and cannot be
%     synthesised headlessly.  The zoom *result* is covered by
%     testZoomInAndScrollButtons.

  methods (Test)

    % --- FileOpenTests ---------------------------------------------------

    function testOpenValidFileLoadsModel(testCase)
      c = testCase.openViaMenu();   % asserts no error dialog internally
      testCase.verifyFalse(isempty(c.model));
      testCase.verifyEqual(double(c.model.n_chan), 22);
    end

    function testFileOpenMatchesCommandLine(testCase)
      % File > Open should behave the same as passing the file on the command
      % line (Controller(path)).  test.tcs is on a single time base, so the
      % constructor's open() pops no dialog.
      testCase.requireTestFile();
      direct = groundswell.Controller(testCase.TestFile);
      dialog = testCase.openViaMenu();   % asserts no error dialog internally
      testCase.verifyFalse(isempty(direct.model));
      testCase.verifyFalse(isempty(dialog.model));
      testCase.verifyEqual(double(direct.model.n_chan), ...
                           double(dialog.model.n_chan));
    end

    % --- ZoomScrollTests -------------------------------------------------

    function testZoomInAndScrollButtons(testCase)
      c = testCase.openViaMenu();
      v0 = testCase.tlView(c);
      t0 = v0(1); tf = v0(2);
      full = tf - t0;
      testCase.verifyGreaterThan(full, 0);

      assertView = @(lo, hi, msg) testCase.verifyEqual( ...
        testCase.tlView(c), [lo hi], 'AbsTol', 1e-6, msg);

      % zoom in twice: left edge fixed, width halves each click
      testCase.trigger(c.view.zoom_in_button_h);
      assertView(t0, t0 + full/2, 'after first zoom in');
      testCase.trigger(c.view.zoom_in_button_h);
      assertView(t0, t0 + full/4, 'after second zoom in');

      w = full/4;                          % current view width
      xl = get(c.view.axes_hs(1), 'xlim'); % seconds units -> x axis is time
      testCase.verifyEqual(double(xl(:)'), [t0, t0 + w], 'AbsTol', 1e-6);

      % scroll buttons (each acts on the current view), all clamped to [t0 tf]
      testCase.trigger(c.view.step_right_button_h);
      assertView(t0 + 0.05*w, t0 + w + 0.05*w, 'after step right');
      testCase.trigger(c.view.step_left_button_h);
      assertView(t0, t0 + w, 'after step left');
      testCase.trigger(c.view.page_right_button_h);
      assertView(t0 + w, t0 + 2*w, 'after page right');
      testCase.trigger(c.view.page_left_button_h);
      assertView(t0, t0 + w, 'after page left');
      testCase.trigger(c.view.to_end_button_h);
      assertView(tf - w, tf, 'after to end');
      testCase.trigger(c.view.to_start_button_h);
      assertView(t0, t0 + w, 'after to start');

      % zoom out: left edge fixed, width doubles, clamped to the record
      testCase.trigger(c.view.zoom_out_button_h);
      assertView(t0, t0 + 2*w, 'after zoom out');
      testCase.trigger(c.view.zoom_out_button_h);   % 4w would pass tf: clamp
      assertView(t0, tf, 'after second zoom out');

      % zoom way out: the full record in one click, from anywhere
      testCase.trigger(c.view.zoom_in_button_h);
      testCase.trigger(c.view.zoom_in_button_h);
      testCase.trigger(c.view.to_end_button_h);
      testCase.trigger(c.view.zoom_way_out_button_h);
      assertView(t0, tf, 'after zoom way out');
    end

    % --- XAxisUnitsTests -------------------------------------------------

    function testSetXUnitsToMilliseconds(testCase)
      c = testCase.openViaMenu();
      c.set_x_units('time_ms');
      testCase.verifyEqual(char(c.view.x_units), 'time_ms');

      lastAx = c.view.axes_hs(end);
      xlabel = get(lastAx, 'xlabel');
      testCase.verifyEqual(char(get(xlabel, 'string')), 'Time (ms)');

      xl = get(lastAx, 'xlim');
      tl = c.view.tl_view;
      testCase.verifyEqual(double(xl(2)), 1000.0*double(tl(2)), 'AbsTol', 1e-3);
    end

    function testAllXUnitConversions(testCase)
      units  = {'time_s', 'time_ms', 'time_min', 'time_hr'};
      scales = [1.0,       1000.0,    1/60.0,     1/3600.0];
      c = testCase.openViaMenu();
      lastAx = c.view.axes_hs(end);

      for k = 1:numel(units)
        unit = units{k};
        scale = scales(k);
        c.set_x_units(unit);
        testCase.verifyEqual(char(c.view.x_units), unit);

        % x-label reads the selected menu item's label
        menu = c.view.([unit '_menu_h']);
        testCase.verifyEqual(char(get(get(lastAx, 'xlabel'), 'string')), ...
                             char(get(menu, 'label')), ...
                             sprintf('xlabel for %s', unit));

        % x-limits are the time-view scaled into the chosen unit
        tl = double(c.view.tl_view(:)');
        xl = double(get(lastAx, 'xlim'));
        testCase.verifyEqual(xl(:)', scale*tl, 'AbsTol', 1e-4, ...
                             sprintf('xlim for %s', unit));

        % exactly the chosen item is checked
        for j = 1:numel(units)
          checked = char(get(c.view.([units{j} '_menu_h']), 'checked'));
          expected = 'off';
          if j == k, expected = 'on'; end
          testCase.verifyEqual(checked, expected, ...
            sprintf('%s checked after selecting %s', units{j}, unit));
        end
      end
    end

    function testEditTBoundsSetsTimeView(testCase)
      c = testCase.openViaMenu();
      % "Set Range..." through the injected inputdlg; enter [1, 4] (seconds).
      c.dialog_responses = {{'1.000000'; '4.000000'}};
      c.edit_t_bounds();
      tl = double(c.view.tl_view(:)');
      testCase.verifyEqual(tl, [1.0 4.0], 'AbsTol', 1e-6);
    end

    % --- SelectionTests --------------------------------------------------

    function testClickingChannelLabelSelectsIt(testCase)
      c = testCase.openViaMenu();
      testCase.verifyEqual(numel(c.view.i_selected), 0);
      set(c.view.fig_h, 'selectiontype', 'normal');
      label = get(c.view.axes_hs(3), 'ylabel');
      testCase.fireButtonDown(label);
      testCase.verifyEqual(testCase.selectedList(c), 3);
    end

    function testShiftClickExtendsSelection(testCase)
      c = testCase.openViaMenu();
      set(c.view.fig_h, 'selectiontype', 'normal');
      testCase.fireButtonDown(get(c.view.axes_hs(1), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), 1);
      set(c.view.fig_h, 'selectiontype', 'extend');
      testCase.fireButtonDown(get(c.view.axes_hs(3), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), [1 2 3]);
    end

    function testCtrlClickTogglesNoncontiguousSelection(testCase)
      c = testCase.openViaMenu();
      set(c.view.fig_h, 'selectiontype', 'normal');
      testCase.fireButtonDown(get(c.view.axes_hs(1), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), 1);
      set(c.view.fig_h, 'selectiontype', 'alt');     % ctrl/cmd-click toggles
      testCase.fireButtonDown(get(c.view.axes_hs(5), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), [1 5]);
      testCase.fireButtonDown(get(c.view.axes_hs(3), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), [1 3 5]);
      testCase.fireButtonDown(get(c.view.axes_hs(5), 'ylabel')); % remove 5
      testCase.verifyEqual(testCase.selectedList(c), [1 3]);
    end

    function testSelectAllNoneInvert(testCase)
      c = testCase.openViaMenu();
      n = double(c.model.n_chan);
      c.select_all();
      testCase.verifyEqual(numel(c.view.i_selected), n);
      c.select_none();
      testCase.verifyEqual(numel(c.view.i_selected), 0);
      c.invert_selection();           % from empty -> everything
      testCase.verifyEqual(numel(c.view.i_selected), n);
    end

    % --- YAxisTests ------------------------------------------------------

    function testOptimizeAllYRanges(testCase)
      c = testCase.openViaMenu();
      c.optimize_all_y_axis_ranges();
      d = double(c.model.data);
      for i = 1:double(c.model.n_chan)
        ch = d(:, i);
        ymid = (min(ch) + max(ch))/2;
        radius = (max(ch) - min(ch))/2;
        if radius == 0, radius = 1.0; end
        yl = double(get(c.view.axes_hs(i), 'ylim'));
        testCase.verifyEqual(yl(:)', [ymid - 1.1*radius, ymid + 1.1*radius], ...
                             'AbsTol', 1e-4, sprintf('channel %d', i));
      end
    end

    function testOptimizeSelectedYRanges(testCase)
      c = testCase.openViaMenu();
      set(c.view.fig_h, 'selectiontype', 'normal');
      testCase.fireButtonDown(get(c.view.axes_hs(1), 'ylabel'));
      set(c.view.axes_hs(1), 'YLim', [-99 99]);
      set(c.view.axes_hs(2), 'YLim', [-99 99]);
      c.optimize_selected_y_axis_ranges();

      d = double(c.model.data);
      ch = d(:, 1);
      ymid = (min(ch) + max(ch))/2;
      radius = (max(ch) - min(ch))/2;
      if radius == 0, radius = 1.0; end
      yl1 = double(get(c.view.axes_hs(1), 'ylim'));
      testCase.verifyEqual(yl1(:)', [ymid - 1.1*radius, ymid + 1.1*radius], ...
                           'AbsTol', 1e-4);
      yl2 = double(get(c.view.axes_hs(2), 'ylim'));   % unselected untouched
      testCase.verifyEqual(yl2(:)', [-99 99], 'AbsTol', 1e-4);
    end

    function testEditYBoundsSetsYlimOfSelected(testCase)
      c = testCase.openViaMenu();
      set(c.view.fig_h, 'selectiontype', 'normal');
      testCase.fireButtonDown(get(c.view.axes_hs(1), 'ylabel'));
      set(c.view.axes_hs(2), 'YLim', [-99 99]);   % unselected reference
      c.dialog_responses = {{'-5.000000'; '5.000000'}};
      c.edit_y_bounds();
      yl1 = double(get(c.view.axes_hs(1), 'ylim'));
      testCase.verifyEqual(yl1(:)', [-5 5], 'AbsTol', 1e-6);
      yl2 = double(get(c.view.axes_hs(2), 'ylim'));
      testCase.verifyEqual(yl2(1), -99, 'AbsTol', 1e-6);   % untouched
    end

    % --- MutationTests ---------------------------------------------------

    function testRectifySelectedChannel(testCase)
      c = testCase.openAndSelect(1);
      before = double(c.model.data);
      c.rectify();
      after = double(c.model.data);
      testCase.verifyEqual(after(:, 1), abs(before(:, 1)), 'AbsTol', 1e-9);
      testCase.verifyEqual(after(:, 2), before(:, 2), 'AbsTol', 1e-9);
    end

    function testCenterSelectedChannel(testCase)
      c = testCase.openAndSelect(2);
      before = double(c.model.data);
      c.center();
      after = double(c.model.data);
      testCase.verifyEqual(mean(after(:, 2)), 0.0, 'AbsTol', 1e-6);
      testCase.verifyEqual(after(:, 1), before(:, 1), 'AbsTol', 1e-9);
    end

  end

  methods (Access = private)
    function c = openAndSelect(testCase, channel)
      c = testCase.openViaMenu();
      set(c.view.fig_h, 'selectiontype', 'normal');
      testCase.fireButtonDown(get(c.view.axes_hs(channel), 'ylabel'));
      testCase.verifyEqual(testCase.selectedList(c), channel);
    end
  end
end
