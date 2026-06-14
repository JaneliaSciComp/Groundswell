classdef Test_analysis < Groundswell_test_case
% Test_analysis  Back-port of the Analysis section of
% pygroundswell/tests/test_mutate_save_import.py: the Power Spectrum,
% Spectrogram, Coherency, Coherency-at-frequency, Coherogram, Transfer
% Function, Count TTL Edges and Play-as-Audio menu items.
%
% Each analysis is actuated through its real menu callback with the parameter
% inputdlg stubbed (accepting the prefilled defaults, or filling specific
% values).  "Drew something" is checked by rendering the created figure and
% measuring its non-white pixel fraction (the MATLAB analogue of the Python
% _nonwhite_fraction helper).
%
% Adaptations from the Python original:
%   * The mode-menu tests drive the analysis window's menu items found on the
%     created figure (findobj by label) and check the observable effect (the
%     plot's x/y scale, and the item's Checked state).  The Python versions
%     additionally read the window object's private mode_* properties by
%     monkey-patching the class constructor; a MATLAB classdef constructor
%     can't be patched per-instance, so those internal reads are omitted -- the
%     plot-scale/Checked assertions cover the same behaviour (the setters
%     re-syncing the plot).
%   * test_spectrogram_colorbar_shows_gradient is not ported: it asserts
%     Handel-specific colorbar pixel geometry (spine/tick/label placement) that
%     does not correspond to MATLAB's own colorbar rendering.

  methods (Access = private)
    function [c, figs] = runAnalysis(testCase, menuAttr, channels, dialogValues)
      if nargin < 4, dialogValues = {}; end
      c = testCase.loadedController();
      testCase.selectChannels(c, channels);
      testCase.verifyEqual(testCase.selectedList(c), sort(channels), ...
        sprintf('expected channels %s selected', mat2str(channels)));
      menu = c.view.(menuAttr);
      testCase.verifyEqual(char(get(menu, 'Enable')), 'on', ...
        sprintf('%s should be enabled with those channels selected', menuAttr));
      if isempty(dialogValues)
        c.dialog_responses = { [] };          % [] = accept the prefilled defaults
      else
        c.dialog_responses = { dialogValues }; % the param strings to "type"
      end
      before = findall(0, 'Type', 'figure');
      testCase.trigger(menu);
      figs = testCase.newFigures(before);
    end

    function assertDrew(testCase, label, c, figs, minFrac)
      if nargin < 5, minFrac = 0.02; end
      testCase.verifyEmpty(c.dialog_messages, ...
        sprintf('%s raised error dialog(s)', label));
      testCase.verifyNotEmpty(figs, sprintf('%s created no figure window', label));
      testCase.verifyGreaterThan(testCase.nonWhiteFraction(figs(end)), minFrac, ...
        sprintf('%s window appears blank', label));
    end
  end

  methods (Test)

    % -- single-signal analyses ------------------------------------------

    function testPowerSpectrumRunsAndDraws(testCase)
      [c, figs] = testCase.runAnalysis('power_spectrum_menu_h', 1);
      testCase.assertDrew('Power Spectrum', c, figs);
    end

    function testSpectrogramRunsAndDraws(testCase)
      % test.tcs is only 6 s at 10 Hz, so the default 0.6 s window is rejected;
      % fill a window that fits (window s, steps, NW, #tapers, max freq, FFT).
      [c, figs] = testCase.runAnalysis('spectrogram_menu_h', 1, ...
        {'1.5', '10', '4', '7', '5', '2'});
      testCase.assertDrew('Spectrogram', c, figs);
    end

    function testCoherencyRunsAndDraws(testCase)
      [c, figs] = testCase.runAnalysis('coherency_menu_h', [1 2]);
      testCase.assertDrew('Coherency', c, figs);
    end

    function testCoherencyAtOneFrequencyRunsAndDraws(testCase)
      % Sparse polar line-art -> far fewer pixels than the filled spectra.
      [c, figs] = testCase.runAnalysis('coherency_at_f_probe_menu_h', [1 2]);
      testCase.assertDrew('Coherency at One Frequency', c, figs, 0.008);
    end

    function testCoherogramRunsAndDraws(testCase)
      [c, figs] = testCase.runAnalysis('coherogram_menu_h', [1 2], ...
        {'1.5', '10', '4', '7', '5', '2', '0.05'});
      testCase.assertDrew('Coherogram', c, figs);
    end

    function testTransferFunctionRunsAndDraws(testCase)
      [c, figs] = testCase.runAnalysis('transfer_function_menu_h', [1 2]);
      testCase.assertDrew('Transfer Function', c, figs);
    end

    % -- preconditions ---------------------------------------------------

    function testAnalysisMenuEnablementTracksSelectionCount(testCase)
      c = testCase.loadedController();
      oneSignal = {'power_spectrum_menu_h', 'spectrogram_menu_h', ...
                   'play_as_audio_menu_h', 'count_ttl_edges_menu_h'};
      twoSignals = {'coherency_menu_h', 'coherogram_menu_h', ...
                    'transfer_function_menu_h'};
      assertEnabled = @(attrs, want, when) cellfun(@(a) testCase.verifyEqual( ...
        char(get(c.view.(a), 'Enable')), want, sprintf('%s with %s', a, when)), attrs);

      testCase.selectChannels(c, 1);
      assertEnabled(oneSignal, 'on', 'one channel');
      assertEnabled(twoSignals, 'off', 'one channel');
      assertEnabled({'coherency_at_f_probe_menu_h'}, 'off', 'one channel');

      c.select_none();
      testCase.selectChannels(c, [1 2]);
      assertEnabled(oneSignal, 'off', 'two channels');
      assertEnabled(twoSignals, 'on', 'two channels');
      assertEnabled({'coherency_at_f_probe_menu_h'}, 'on', 'two channels');

      c.select_none();
      testCase.selectChannels(c, [1 2 3]);
      assertEnabled([oneSignal twoSignals], 'off', 'three channels');
      assertEnabled({'coherency_at_f_probe_menu_h'}, 'on', 'three channels');
    end

    function testPowerSpectrumRejectsInvalidParameters(testCase)
      cases = {
        {'abc', '4', '7', '5', '2', '0.95'}, 'Number of windows must be an integer';
        {'0',   '4', '7', '5', '2', '0.95'}, 'Number of windows must be >= 1';
        {'1',   '4', '9', '5', '2', '0.95'}, 'Number of tapers must be <= 2*NW-1'};
      for i = 1:size(cases, 1)
        % runAnalysis builds a fresh Controller, so dialog_messages starts empty
        [c, figs] = testCase.runAnalysis('power_spectrum_menu_h', 1, cases{i, 1});
        testCase.verifyEqual(c.dialog_messages, cases(i, 2), ...
          sprintf('case %d errordlg', i));
        testCase.verifyEmpty(figs, ...
          sprintf('window opened despite %s', cases{i, 2}));
      end
    end

    % -- mode menus: the setters must re-sync the plot scale -------------

    function testPowerSpectrumLogScaleMenus(testCase)
      [c, figs] = testCase.runAnalysis('power_spectrum_menu_h', 1);
      fig = figs(end);
      testCase.verifyFalse(testCase.anyAxisScale(fig, 'X', 'log'));
      testCase.fireMenuItem(fig, 'X axis', 'Logarithmic');
      testCase.verifyTrue(testCase.anyAxisScale(fig, 'X', 'log'), ...
        'X-axis Logarithmic did not switch the plot to a log x-scale');
      testCase.fireMenuItem(fig, 'Y axis', 'Logarithmic');
      testCase.verifyTrue(testCase.anyAxisScale(fig, 'Y', 'log'), ...
        'Y-axis Logarithmic did not switch the plot to a log y-scale');
      testCase.fireMenuItem(fig, 'X axis', 'Linear');
      testCase.verifyFalse(testCase.anyAxisScale(fig, 'X', 'log'));
      % the selected item shows its radio check
      xlin = findobj(findobj(fig, 'Label', 'X axis'), 'Label', 'Linear');
      testCase.verifyEqual(char(get(xlin(1), 'Checked')), 'on');
    end

    function testCoherencyLogScaleMenus(testCase)
      [c, figs] = testCase.runAnalysis('coherency_menu_h', [1 2]);
      fig = figs(end);
      testCase.fireMenuItem(fig, 'X axis', 'Logarithmic');
      % the x scale applies to both the magnitude and the phase plot
      axs = findobj(fig, 'Type', 'axes');
      for k = 1:numel(axs)
        testCase.verifyEqual(lower(get(axs(k), 'XScale')), 'log');
      end
      testCase.fireMenuItem(fig, 'X axis', 'Linear');
      for k = 1:numel(axs)
        testCase.verifyEqual(lower(get(axs(k), 'XScale')), 'linear');
      end
    end

    function testSpectrogramYLogScaleMenu(testCase)
      [c, figs] = testCase.runAnalysis('spectrogram_menu_h', 1, ...
        {'1.5', '10', '4', '7', '5', '2'});
      fig = figs(end);
      testCase.verifyFalse(testCase.anyAxisScale(fig, 'Y', 'log'));
      testCase.fireMenuItem(fig, 'Y axis', 'Logarithmic');
      testCase.verifyTrue(testCase.anyAxisScale(fig, 'Y', 'log'), ...
        'Y-axis Logarithmic did not re-sync the spectrogram plot');
      testCase.fireMenuItem(fig, 'Y axis', 'Linear');
      testCase.verifyFalse(testCase.anyAxisScale(fig, 'Y', 'log'));
    end

    % -- message-box / audio (no analysis figure) ------------------------

    function testCountTtlEdgesReportsCounts(testCase)
      % Use a real camera-shutter TTL whose pulse count is known a priori:
      % NO_FRAME_TRANSFER_20exposures.tcs's "camera_ex" has 21 pulses (20 video
      % frames plus the usual trailing vestigial pulse), each a clean rise+fall,
      % so Count TTL Edges must report 21 rising and 21 falling.
      f = fullfile(fileparts(testCase.TestFile), 'NO_FRAME_TRANSFER_20exposures.tcs');
      testCase.assumeTrue(isfile(f), 'NO_FRAME_TRANSFER_20exposures.tcs not present');

      c = testCase.loadedController(f);
      ic = find(strcmp(c.model.names, 'camera_ex'));
      testCase.assertNotEmpty(ic, 'no camera_ex channel');
      testCase.selectChannels(c, ic);

      testCase.trigger(c.view.count_ttl_edges_menu_h);
      testCase.verifyNotEmpty(c.dialog_messages, 'no message box shown');
      msg = c.dialog_messages{end};
      testCase.verifySubstring(msg, 'Rising edges: 21');
      testCase.verifySubstring(msg, 'Falling edges: 21');
    end

    function testPlayAsAudioRuns(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      testCase.trigger(c.view.play_as_audio_menu_h);
      testCase.verifyNotEmpty(c.played_audio, 'audioplayer never invoked');
      % test.tcs is 10 Hz (< the 80 Hz floor) so it's resampled to 1 kHz, and
      % the samples are scaled into [-1, 1] before playback.  played_audio
      % entries are {signal, rate} pairs recorded by the audioplayer wrapper.
      rec = c.played_audio{end};
      testCase.verifyEqual(double(rec{2}), 1000.0);
      y = double(rec{1});
      testCase.verifyLessThanOrEqual(max(abs(y(:))), 1.0 + 1e-9);
    end

  end
end
