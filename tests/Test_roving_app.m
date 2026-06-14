classdef Test_roving_app < Roving_test_case
% Test_roving_app  Back-port of pygroundswell/tests/test_roving_app.py: the
% Roving imaging/ROI viewer launches non-blank, opens TIFF / ImageJ-jumbo /
% MJ2 videos through the real File > Open video menu, and every menu item and
% button can be actuated through its real callback.
%
% Not ported (the same headless limit as the groundswell zoom-drag): the
% mouse-drag ROI-drawing and zoom-rectangle gesture tests (RovingZoomTests,
% RovingRoiGestureTests) drive the real Qt mouse handlers via synthesised
% events / axes CurrentPoint, which cannot be reproduced headlessly in MATLAB;
% and the Handel-pixel-rendering display tests (RovingDisplayTests) assert the
% Python port's colormap/colorbar pixel mapping rather than groundswell logic.
% Programmatic ROI creation (add_roi) and selection are still exercised below.

  properties (Constant)
    MODE_BUTTONS = {
      'elliptic_roi',  'elliptic_roi_button_h';
      'rect_roi',      'rect_roi_button_h';
      'polygonal_roi', 'polygonal_roi_button_h';
      'select',        'select_button_h';
      'zoom',          'zoom_button_h';
      'move_all',      'move_all_button_h'};
  end

  methods (Access = private)
    function assertOnlyMode(testCase, c, activeAttr)
      for k = 1:size(testCase.MODE_BUTTONS, 1)
        attr = testCase.MODE_BUTTONS{k, 2};
        want = double(strcmp(attr, activeAttr));
        testCase.verifyEqual(double(get(c.view.(attr), 'Value')), want, ...
          sprintf('%s Value should be %d', attr, want));
      end
    end
  end

  methods (Test)

    % --- launch ----------------------------------------------------------

    function testLaunchWindowPopulatedAndNotBlank(testCase)
      c = testCase.newController();
      fig = c.view.figure_h;
      testCase.verifyEqual(char(get(fig, 'Name')), 'Roving');
      testCase.verifyGreaterThanOrEqual(numel(findall(fig, 'Type', 'uimenu')), 5);
      testCase.verifyGreaterThanOrEqual(numel(findall(fig, 'Type', 'uicontrol')), 15);
      testCase.verifyGreaterThanOrEqual(numel(findall(fig, 'Type', 'axes')), 2);
      testCase.verifyGreaterThan(testCase.nonWhiteFraction(fig), 0.02, ...
        'the Roving window renders blank');
    end

    % --- open a TIFF -----------------------------------------------------

    function testOpenTifViaMenuDisplaysFrames(testCase)
      c = testCase.openTif();
      m = c.model;
      testCase.verifyEqual(double(m.n_frames), 61);
      testCase.verifyEqual(double(m.n_rows), 256);
      testCase.verifyEqual(double(m.n_cols), 256);

      cdata = double(get(c.view.image_h, 'cdata'));
      testCase.verifyEqual(size(cdata), [256 256]);
      testCase.verifyGreaterThan(max(cdata(:)), min(cdata(:)));
      testCase.verifyEqual(strtrim(char(get(c.view.frame_index_edit_h, 'string'))), '1');
    end

    % --- mode buttons (radio-style exclusivity) --------------------------

    function testClickingEachButtonIsMutuallyExclusive(testCase)
      c = testCase.openTif();
      testCase.addSquareRoi(c);   % select/move_all enable once an ROI exists
      for k = 1:size(testCase.MODE_BUTTONS, 1)
        mode = testCase.MODE_BUTTONS{k, 1};
        attr = testCase.MODE_BUTTONS{k, 2};
        testCase.verifyEqual(char(get(c.view.(attr), 'Enable')), 'on', ...
          sprintf('%s should be enabled', attr));
        testCase.trigger(c.view.(attr));
        testCase.verifyEqual(char(c.view.mode), mode);
        testCase.assertOnlyMode(c, attr);
      end
    end

    function testReclickingActiveButtonKeepsItSelected(testCase)
      c = testCase.openTif();
      testCase.addSquareRoi(c);
      testCase.trigger(c.view.zoom_button_h);
      testCase.assertOnlyMode(c, 'zoom_button_h');
      testCase.trigger(c.view.zoom_button_h);     % re-click stays selected
      testCase.verifyEqual(char(c.view.mode), 'zoom');
      testCase.assertOnlyMode(c, 'zoom_button_h');
    end

    % --- open ImageJ "jumbo" TIFF and MJ2 --------------------------------

    function testOpenJumboTifViaMenu(testCase)
      testCase.assumeNotEmpty(testCase.JumboFile, 'jumbo .tif not present');
      c = testCase.newController();
      c.dialog_responses = { testCase.fileResponse(testCase.JumboFile) };
      testCase.trigger(c.view.open_video_menu_h);
      testCase.verifyEmpty(c.dialog_messages);
      m = c.model;
      testCase.verifyEqual(double(m.n_frames), 9000);
      testCase.verifyEqual(double(m.n_rows), 512);
      testCase.verifyEqual(double(m.n_cols), 512);

      raw1 = m.get_frame(1);
      testCase.verifyEqual(size(raw1), [512 512]);
      testCase.verifyEqual(class(raw1), 'uint16');
      % the min/max ImageJ recorded in the file's comment
      testCase.verifyEqual(double(min(raw1(:))), 117);
      testCase.verifyEqual(double(max(raw1(:))), 14822);

      % seek to the last frame (read from the far end of the 4.7 GB file)
      testCase.setEdit(c.view.frame_index_edit_h, '9000');
      testCase.verifyEqual(double(c.view.frame_index), 9000);
      raw9000 = m.get_frame(9000);
      testCase.verifyTrue(any(raw9000(:) ~= raw1(:)), 'frame 9000 equals frame 1');
    end

    function testOpenMj2ViaMenu(testCase)
      testCase.assumeNotEmpty(testCase.Mj2File, '.mj2 not present');
      c = testCase.newController();
      c.dialog_responses = { testCase.fileResponse(testCase.Mj2File) };
      testCase.trigger(c.view.open_video_menu_h);
      testCase.verifyEmpty(c.dialog_messages);
      m = c.model;
      testCase.verifyEqual(double(m.n_frames), 324);
      testCase.verifyEqual(double(m.n_rows), 1024);
      testCase.verifyEqual(double(m.n_cols), 768);
      testCase.verifyEqual(double(m.fs), 19141.0/660.0, 'AbsTol', 1e-6);

      raw1 = m.get_frame(1);
      testCase.verifyEqual(size(raw1), [768 1024]);
      testCase.verifyEqual(class(raw1), 'uint8');

      testCase.setEdit(c.view.frame_index_edit_h, '324');
      testCase.verifyEqual(double(c.view.frame_index), 324);
      raw324 = m.get_frame(324);
      testCase.verifyTrue(any(raw324(:) ~= raw1(:)), 'frame 324 equals frame 1');
      % real random access: re-reading frame 1 reproduces it exactly
      testCase.verifyEqual(m.get_frame(1), raw1);
    end

    % --- every menu item -------------------------------------------------

    function testEveryMenuItem(testCase)
      testCase.requireTif();
      testCase.assumeNotEmpty(testCase.RpbFile, '.rpb not present');
      c = testCase.newController();
      c.dialog_responses = { testCase.fileResponse(testCase.TifFile) };
      testCase.trigger(c.view.open_video_menu_h);
      testCase.addSquareRoi(c);
      c.view.select_roi(1);

      td = tempname(); mkdir(td);
      testCase.addTeardown(@() rmdir(td, 's'));
      out = @(name) fullfile(td, name);

      % (menu attr, queued dialog responses): {} for a menu that shows no
      % dialog, a one-element queue for a file dialog ({filename,dir}), and
      % {[]} for an inputdlg whose prefilled defaults we accept.
      cancel = testCase.fileResponse('');   % {0,0} -> uigetfile "Cancel"
      script = {
        'open_video_menu_h',            { testCase.fileResponse(testCase.TifFile) };
        'open_rois_menu_h',             { testCase.fileResponse(testCase.RpbFile) };
        'save_rois_to_file_menu_h',     { testCase.fileResponse(out('rois.rpb')) };
        'export_to_tcs_menu_h',         { testCase.fileResponse(out('signals.tcs')) };
        'export_to_mask_menu_h',        { testCase.fileResponse(out('mask.tif')) };
        'load_overlay_menu_h',          { cancel };             % no .ovl fixture
        'copy_menu_h',                  {};
        'paste_menu_h',                 {};
        'cut_menu_h',                   {};
        'pixel_data_type_min_max_menu_h', {};
        'min_max_menu_h',               {};
        'five_95_menu_h',               {};
        'abs_max_menu_h',               {};
        'ninety_symmetric_menu_h',      {};
        'colorbar_edit_bounds_menu_h',  { [] };                 % inputdlg defaults
        'bone_menu_h',                  {};
        'hot_menu_h',                   {};
        'parula_menu_h',                {};
        'jet_menu_h',                   {};
        'red_green_menu_h',             {};
        'red_blue_menu_h',              {};
        'gray_menu_h',                  {};
        'brighten_menu_h',              {};
        'darken_menu_h',                {};
        'revert_menu_h',                {};
        'rename_roi_menu_h',            { [] };                 % inputdlg defaults
        'hide_rois_menu_h',             {};
        'hide_rois_menu_h',             {};                     % ...and back on
        'delete_roi_menu_h',            {};
        'delete_all_rois_menu_h',       {};
        'quit_menu_h',                  {}};                    % last: tears down

      % The Overlay menu stays disabled until an .ovl file is loaded (no test
      % fixture); assert it is disabled rather than silently no-op'ing.
      testCase.verifyEqual(char(get(c.view.show_overlay_menu_h, 'Enable')), 'off');

      needSel = {'copy_menu_h', 'cut_menu_h', 'rename_roi_menu_h', 'delete_roi_menu_h'};
      for i = 1:size(script, 1)
        attr = script{i, 1};
        if any(strcmp(attr, needSel)) && testCase.noRoiSelected(c)
          c.view.select_roi(1);
        end
        testCase.triggerMenu(c, attr, script{i, 2});
      end

      % completeness: every *_menu_h with a callback must be in the script
      scripted = unique(script(:, 1));
      missing = setdiff(testCase.actionableMenus(c), [scripted; {'show_overlay_menu_h'}]);
      testCase.verifyEmpty(missing, ...
        sprintf('menu items missing from the script: %s', strjoin(missing, ', ')));

      % the save/export menus really wrote files
      for name = {'rois.rpb', 'signals.tcs', 'mask.tif'}
        info = dir(out(name{1}));
        testCase.verifyNotEmpty(info, sprintf('%s not written', name{1}));
        testCase.verifyGreaterThan(info.bytes, 0, sprintf('%s is empty', name{1}));
      end
    end

    % --- every button and edit ------------------------------------------

    function testEveryButtonAndEdit(testCase)
      c = testCase.openTif();
      fig = c.view.figure_h;
      controls = findall(fig, 'Type', 'uicontrol');
      testCase.verifyGreaterThanOrEqual(numel(controls), 15);

      % speed playback up so the play buttons' paced loops finish quickly
      testCase.setEdit(c.view.FPS_edit_h, '500');
      testCase.setEdit(c.view.frame_index_edit_h, '30');
      testCase.verifyEqual(double(c.view.frame_index), 30);

      clicked = {};
      for k = 1:numel(controls)
        ctl = controls(k);
        style = lower(char(get(ctl, 'Style')));
        if ~ismember(style, {'pushbutton', 'togglebutton'}), continue; end
        if isempty(get(ctl, 'Callback')), continue; end
        c.dialog_messages = {};
        testCase.trigger(ctl);
        testCase.verifyEmpty(c.dialog_messages, ...
          sprintf('%s raised error dialog(s)', char(get(ctl, 'Tag'))));
        clicked{end+1} = char(get(ctl, 'Tag')); %#ok<AGROW>
      end
      for want = {'to_start_button_h', 'play_backward_button_h', ...
                  'frame_backward_button_h', 'stop_button_h', ...
                  'frame_forward_button_h', 'play_forward_button_h', ...
                  'to_end_button_h', 'elliptic_roi_button_h', ...
                  'rect_roi_button_h', 'polygonal_roi_button_h', ...
                  'select_button_h', 'zoom_button_h', 'move_all_button_h'}
        testCase.verifyTrue(ismember(want{1}, clicked), ...
          sprintf('%s was not clicked', want{1}));
      end
    end

  end

  methods (Access = private)
    function tf = noRoiSelected(~, c)
      sel = c.view.selected_roi_index;
      tf = isempty(sel) || any(isnan(double(sel(:))));
    end

    function names = actionableMenus(~, c)
      % All *_menu_h View properties that carry a callback.
      p = properties(c.view);
      p = p(endsWith(p, '_menu_h'));
      names = {};
      for i = 1:numel(p)
        h = c.view.(p{i});
        if ~isempty(h) && ishghandle(h) && ~isempty(get(h, 'Callback'))
          names{end+1} = p{i}; %#ok<AGROW>
        end
      end
      names = names(:);
    end

    function triggerMenu(testCase, c, attr, responses)
      menu = c.view.(attr);
      testCase.verifyEqual(char(get(menu, 'Enable')), 'on', ...
        sprintf('%s is disabled; trigger would be a no-op', attr));
      c.dialog_responses = responses;
      c.dialog_messages = {};
      testCase.trigger(menu);
      testCase.verifyEmpty(c.dialog_messages, ...
        sprintf('%s raised error dialog(s): %s', attr, strjoin(c.dialog_messages, '; ')));
    end
  end
end
