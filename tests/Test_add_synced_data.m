classdef Test_add_synced_data < Groundswell_test_case
% Test_add_synced_data  Test the File > Add synched data... menu item.
%
% Scenario (non-frame-transfer): an electrophysiology .tcs holds, among its
% signals, a camera-shutter TTL ("camera_ex") with one pulse per acquired
% video frame.  ROI signals extracted from the video are in a second .tcs
% (one scalar per ROI per frame).  Selecting the shutter signal and invoking
% Add synched data... loads the ROI file and splices the ROI signals into the
% e-phys model, time-stamping each frame from the TTL pulses.
%
% Fixtures (in ../test-files):
%   NO_FRAME_TRANSFER_20exposures.tcs       e-phys: output_1, output _2, camera_ex
%   NO_FRAME_TRANSFER_20exposures_rois.tcs  20-frame ROI signal "a"
% The shutter has 21 pulses for 20 frames (the usual trailing vestigial pulse),
% i.e. n_pulses == n_frames + 1.  In normal mode rectify_exposure_times takes
% the clean path (drop the trailing pulse, no dialog).  The FT variant treats
% n+1 as the "really frame-transfer?" case and asks for confirmation via a
% questdlg; rectify_exposure_times is a @Controller method, so that questdlg
% goes through the test-mode seam too and we answer it 'Proceed' -- after which
% FT drops the *first* pulse and maps the frames to pulses 2..21.

  methods (Access = private)
    function p = syncFile(testCase, name)
      p = fullfile(fileparts(testCase.TestFile), name);
    end

    function checkAddSynced(testCase, ftMode)
      % Drive Add synched data... (ftMode=false) or Add synched data (FT)...
      % (ftMode=true) and verify the ROI signal is spliced in, aligned to the
      % camera-shutter TTL.  The two modes differ only in which menu is fired,
      % the extra 'Proceed' answer FT's confirmation questdlg needs, and which
      % pulses become the frame times (normal: the first n; FT: drop the first).
      ephys = testCase.syncFile('NO_FRAME_TRANSFER_20exposures.tcs');
      roi   = testCase.syncFile('NO_FRAME_TRANSFER_20exposures_rois.tcs');
      testCase.assumeTrue(isfile(ephys) && isfile(roi), ...
        'Add-synched-data test files not present');

      c = testCase.loadedController(ephys);     % single time base -> no dialog
      testCase.verifyEqual(double(c.model.n_chan), 3);

      % select the camera-shutter TTL (exactly one signal, as the menu requires)
      ic = find(strcmp(c.model.names, 'camera_ex'));
      testCase.assertNotEmpty(ic, 'no camera_ex channel in the e-phys file');
      testCase.selectChannels(c, ic);
      testCase.verifyEqual(testCase.selectedList(c), ic);

      % capture the pre-merge timeline and shutter signal for the alignment check
      t_before = double(c.model.t(:));
      shutter  = double(c.model.data(:, ic));

      % the ROI signal, read independently as the oracle
      [data_roi, ~, names_roi, units_roi] = groundswell.load_traces(roi, '');
      data_roi = double(data_roi(:));
      n_frame = numel(data_roi);

      % queue the dialog answers: uigetfile -> the ROI .tcs (filter 2); for FT,
      % also 'Proceed' past rectify_exposure_times' "really frame-transfer?" ask
      [d, n, e] = fileparts(roi);
      responses = {{[n e], [d filesep], 2}};
      if ftMode
        responses{end+1} = 'Proceed';
        menu = c.view.add_synced_data_ft_menu_item_h;
      else
        menu = c.view.add_synced_data_menu_item_h;
      end
      testCase.verifyEqual(char(get(menu, 'Enable')), 'on');
      c.dialog_responses = responses;
      testCase.trigger(menu);
      testCase.verifyEmpty(c.dialog_messages, 'Add synched data raised an error dialog');

      % --- a channel was added: the ROI signal "a" -----------------------
      testCase.verifyEqual(double(c.model.n_chan), 4);
      testCase.verifyEqual(char(c.model.names{4}), char(names_roi{1}));   % 'a'
      testCase.verifyEqual(char(c.model.units{4}), char(units_roi{1}));   % ''
      testCase.verifyFalse(logical(c.model.saved));   % a mutation -> unsaved
      % the original e-phys signals are preserved, in order
      testCase.verifyEqual(char(c.model.names{1}), 'output_1');
      testCase.verifyEqual(char(c.model.names{3}), 'camera_ex');

      % --- the merge is on a common timeline trimmed to the exposure span -
      t_after = double(c.model.t(:));
      mid = (min(shutter) + max(shutter)) / 2;
      t_pulse = double(groundswell.exposure_times(t_before, shutter > mid));
      t_pulse = t_pulse(:);
      if ftMode
        t_frame = t_pulse(2:n_frame+1);   % FT drops the first pulse
      else
        t_frame = t_pulse(1:n_frame);     % normal drops the trailing pulse
      end
      dt = (t_after(end) - t_after(1)) / (numel(t_after) - 1);
      testCase.verifyEqual(t_after(1),   t_frame(1),   'AbsTol', 1e-9);
      testCase.verifyEqual(t_after(end), t_frame(end), 'AbsTol', 1.5*dt);

      % --- the ROI signal sits at the right times with the right values ---
      % Between consecutive frame times the spliced ROI channel is the straight
      % line through the two ROI samples, so at each interval midpoint it must
      % equal the average of those samples.  (Sampling at midpoints avoids the
      % slope kinks at the frame times themselves.)
      t_grid_mid = (t_frame(1:end-1) + t_frame(2:end)) / 2;
      expected   = (data_roi(1:end-1) + data_roi(2:end)) / 2;
      got = interp1(t_after, double(c.model.data(:, 4)), t_grid_mid);
      tol = max(1e-9, 1e-6 * (max(data_roi) - min(data_roi)));
      testCase.verifyEqual(got, expected, 'AbsTol', tol, ...
        'spliced ROI signal is not aligned to the camera exposure pulses');

      % and its overall range matches the ROI source (values really embedded)
      roi_col = double(c.model.data(:, 4));
      testCase.verifyEqual(min(roi_col), min(data_roi), 'AbsTol', tol);
      testCase.verifyEqual(max(roi_col), max(data_roi), 'AbsTol', tol);
    end
  end

  methods (Test)
    function testAddSyncedDataSplicesRoiAlignedToTtl(testCase)
      testCase.checkAddSynced(false);   % File > Add synched data...
    end

    function testAddSyncedDataFtSplicesRoiAlignedToTtl(testCase)
      testCase.checkAddSynced(true);    % File > Add synched data (FT)...
    end
  end
end
