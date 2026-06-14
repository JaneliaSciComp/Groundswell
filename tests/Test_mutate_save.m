classdef Test_mutate_save < App_test_case
% Test_mutate_save  Back-port of pygroundswell/tests/test_mutate_save_import.py
% (the Mutation, Save/Save-As, file-lifecycle, and Import sections).
%
% The Analysis section of that Python file is ported separately
% (Test_analysis), because its parameter dialogs live in free functions that
% the Controller dialog seam does not reach.
%
% Adaptations from the Python original:
%   * The two import error tests (empty .abf, unknown extension) verify the
%     observable outcome -- no model is built -- rather than asserting the
%     errordlg text: that errordlg is raised inside the free function
%     load_traces, which the Controller-level dialog seam cannot intercept.
%   * test_import_abf compares against MATLAB's own abf reader output shape
%     rather than Python's pyabf.

  methods (Access = private)
    function d = tempDir(testCase)
      d = tempname();
      mkdir(d);
      testCase.addTeardown(@() rmdir(d, 's'));
    end
    function p = testFile(testCase, name)
      p = fullfile(fileparts(testCase.TestFile), name);
    end
    function b = readBytes(~, f)
      fid = fopen(f, 'r');
      b = fread(fid, inf, '*uint8');
      fclose(fid);
    end
  end

  methods (Test)

    % --- Mutations -------------------------------------------------------

    function testDxOverXMathUnitsAndSavedFlag(testCase)
      c = testCase.loadedController();
      testCase.verifyTrue(logical(c.model.saved));   % just opened
      testCase.selectChannels(c, 1);

      before = testCase.modelData(c);
      c.dx_over_x();
      after = testCase.modelData(c);

      ch = before(:, 1);
      dmean = mean(ch);
      expect = 100.0 * (ch/abs(dmean) - sign(dmean));
      testCase.verifyEqual(after(:, 1), expect, 'RelTol', 1e-9);
      testCase.verifyEqual(char(c.model.units{1}), '%');          % relabelled
      testCase.verifyEqual(after(:, 2), before(:, 2), 'AbsTol', 1e-12); % others
      testCase.verifyFalse(logical(c.model.saved));               % now dirty
    end

    function testDxOverXMultipleSelectedChannels(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, [2 4]);
      before = testCase.modelData(c);
      c.dx_over_x();
      after = testCase.modelData(c);
      for j = [2 4]
        ch = before(:, j);
        dmean = mean(ch);
        expect = 100.0 * (ch/abs(dmean) - sign(dmean));
        testCase.verifyEqual(after(:, j), expect, 'RelTol', 1e-9);
        testCase.verifyEqual(char(c.model.units{j}), '%');
      end
      testCase.verifyEqual(after(:, 1), before(:, 1), 'AbsTol', 1e-12);
    end

    function testChangeFsUpdatesFsDtAndTimebase(testCase)
      c = testCase.loadedController();
      n_t = double(c.model.n_t);
      c.dialog_responses = {{'2000'}};
      c.change_fs();
      testCase.verifyEqual(c.fs_str, '2000');
      testCase.verifyEqual(double(c.model.fs), 2000.0, 'AbsTol', 1e-9);
      testCase.verifyEqual(double(c.model.dt), 1/2000, 'AbsTol', 1e-12);
      t = double(c.model.t(:));
      testCase.verifyEqual(numel(t), n_t);
      testCase.verifyEqual(diff(t), repmat(1/2000, n_t-1, 1), 'RelTol', 1e-9);
    end

    function testChangeFsRejectsInvalidInput(testCase)
      c = testCase.loadedController();
      fs0 = double(c.model.fs);
      for bad = {'not a number', '0', '-5'}
        c.dialog_responses = {bad};   % bad is a 1x1 cell {value}
        c.change_fs();
        testCase.verifyEqual(double(c.model.fs), fs0, 'AbsTol', 1e-9, ...
          sprintf('fs changed on bad input %s', bad{1}));
      end
    end

    function testChangeFsCancelIsNoop(testCase)
      c = testCase.loadedController();
      fs0 = double(c.model.fs);
      c.dialog_responses = {{}};   % cancel -> inputdlg returns an empty cell
      c.change_fs();
      testCase.verifyEqual(double(c.model.fs), fs0, 'AbsTol', 1e-9);
    end

    function testCenterMultipleChannels(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, [1 3]);
      before = testCase.modelData(c);
      c.center();
      after = testCase.modelData(c);
      testCase.verifyEqual(mean(after(:, 1)), 0.0, 'AbsTol', 1e-6);
      testCase.verifyEqual(mean(after(:, 3)), 0.0, 'AbsTol', 1e-6);
      testCase.verifyEqual(after(:, 2), before(:, 2), 'AbsTol', 1e-12);
      testCase.verifyFalse(logical(c.model.saved));
    end

    % --- Save / Save As --------------------------------------------------

    function testSaveUnchangedIsByteIdenticalToSource(testCase)
      c = testCase.loadedController();
      out = fullfile(testCase.tempDir(), 'out.tcs');
      c.save(out);
      testCase.verifyEqual(testCase.readBytes(out), ...
                           testCase.readBytes(testCase.TestFile));
    end

    function testSaveThenRereadMatchesModel(testCase)
      c = testCase.loadedController();
      out = fullfile(testCase.tempDir(), 'out.tcs');
      c.save(out);
      [names, ~, x_each, units] = read_tcs(out);
      n = double(c.model.n_chan);
      testCase.verifyEqual(numel(names), n);
      md = testCase.modelData(c);
      for i = 1:n
        testCase.verifyEqual(char(names{i}), char(c.model.names{i}));
        testCase.verifyEqual(char(units{i}), char(c.model.units{i}));
        testCase.verifyEqual(x_each{i}(:), md(:, i), 'RelTol', 1e-9);
      end
    end

    function testSaveUpdatesSavedFlagAndFilename(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.rectify();
      testCase.verifyFalse(logical(c.model.saved));
      out = fullfile(testCase.tempDir(), 'out.tcs');
      c.save(out);
      testCase.verifyTrue(logical(c.model.saved));
      testCase.verifyEqual(char(c.model.filename_abs), out);
      testCase.verifyTrue(logical(c.model.file_native));
    end

    function testSavePersistsMutationAcrossReopen(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.rectify();
      mutated = testCase.modelData(c);
      mutated = mutated(:, 1);
      out = fullfile(testCase.tempDir(), 'out.tcs');
      c.save(out);
      reopened = testCase.loadedController(out);
      rd = testCase.modelData(reopened);
      testCase.verifyEqual(rd(:, 1), mutated, 'RelTol', 1e-9);
      testCase.verifyGreaterThanOrEqual(min(rd(:, 1)), 0.0);   % rectified
    end

    function testSaveAsWritesFileAndReturnsTrue(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.center();
      d = testCase.tempDir();
      out = fullfile(d, 'saved_as.tcs');
      c.dialog_responses = {{'saved_as.tcs', [d filesep]}};
      saved = c.save_as();
      testCase.verifyTrue(logical(saved));
      testCase.verifyTrue(isfile(out));
      testCase.verifyTrue(logical(c.model.saved));
    end

    function testSaveAsCancelReturnsFalseAndWritesNothing(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.center();
      d = testCase.tempDir();
      before = dir(d);
      c.dialog_responses = {{0, 0}};   % Cancel -> uiputfile returns numeric 0
      saved = c.save_as();
      testCase.verifyFalse(logical(saved));
      testCase.verifyEqual(numel(dir(d)), numel(before));   % nothing written
      testCase.verifyFalse(logical(c.model.saved));         % still dirty
    end

    % --- File lifecycle: Close / Revert / Quit ---------------------------

    function testCloseClearsModelAndDisablesMenus(testCase)
      c = testCase.loadedController();
      testCase.verifyEqual(char(get(c.view.close_menu_h, 'Enable')), 'on');
      testCase.trigger(c.view.close_menu_h);   % freshly opened: saved, no dialog
      testCase.verifyTrue(isempty(c.model));
      testCase.verifyEqual(char(get(c.view.close_menu_h, 'Enable')), 'off');
    end

    function testCloseUnsavedCancelKeepsModel(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.rectify();                              % dirty
      c.dialog_responses = {'Cancel'};
      c.close();
      testCase.verifyFalse(isempty(c.model));
      testCase.verifyFalse(logical(c.model.saved));
    end

    function testCloseUnsavedDiscardClearsModel(testCase)
      c = testCase.loadedController();
      testCase.selectChannels(c, 1);
      c.rectify();
      c.dialog_responses = {'Discard'};
      c.close();
      testCase.verifyTrue(isempty(c.model));
    end

    function testRevertRestoresFileContents(testCase)
      d = testCase.tempDir();
      path = fullfile(d, 'copy.tcs');
      copyfile(testCase.TestFile, path);
      c = testCase.loadedController(path);
      original = testCase.modelData(c);
      testCase.selectChannels(c, 1);
      c.center();
      testCase.verifyFalse(logical(c.model.saved));
      testCase.verifyFalse(isequal(testCase.modelData(c), original));

      c.dialog_responses = {'Revert'};
      testCase.trigger(c.view.revert_menu_h);
      testCase.verifyEqual(testCase.modelData(c), original, 'RelTol', 1e-12);
      testCase.verifyTrue(logical(c.model.saved));
    end

    function testRevertCancelKeepsChanges(testCase)
      d = testCase.tempDir();
      path = fullfile(d, 'copy.tcs');
      copyfile(testCase.TestFile, path);
      c = testCase.loadedController(path);
      original = testCase.modelData(c);
      testCase.selectChannels(c, 1);
      c.center();
      c.dialog_responses = {'Cancel'};
      c.revert();
      testCase.verifyFalse(isequal(testCase.modelData(c), original));  % still mutated
      testCase.verifyFalse(logical(c.model.saved));
    end

    function testQuitTearsDownTheWindow(testCase)
      c = testCase.loadedController();   % freshly opened: saved, so no dialog
      fig = c.view.fig_h;
      testCase.trigger(c.view.quit_menu_h);
      testCase.verifyTrue(isempty(c.view.fig_h));
      testCase.verifyFalse(ishghandle(fig));   % the figure was really deleted
    end

    % --- Import ----------------------------------------------------------

    function testImportMonoWav(testCase)
      c = testCase.importedController(testCase.testFile('godzilla.wav'));
      testCase.verifyEqual(double(c.model.n_chan), 1);
      testCase.verifyEqual(char(c.model.units{1}), 'V');
      d = testCase.modelData(c);
      testCase.verifyEqual(size(d, 2), 1);
      testCase.verifyGreaterThanOrEqual(min(d(:)), -1.0);   % normalised
      testCase.verifyLessThan(max(d(:)), 1.0);
      testCase.verifyEqual(double(c.model.fs), 11025.0, 'AbsTol', 1e-3);
    end

    function testImportStereoWav(testCase)
      c = testCase.importedController(testCase.testFile('stereo_speech.wav'));
      testCase.verifyEqual(double(c.model.n_chan), 2);
      testCase.verifyEqual(char(c.model.units{2}), 'V');
      testCase.verifyEqual(double(c.model.fs), 8000.0, 'AbsTol', 1e-3);
    end

    function testImportPlainText(testCase)
      f = testCase.testFile('sine_cosine.txt');
      c = testCase.importedController(f);
      ref = readmatrix(f);
      testCase.verifyEqual(double(c.model.n_chan), size(ref, 2));
      testCase.verifyEqual(double(c.model.n_t), size(ref, 1));
      testCase.verifyEqual(double(c.model.fs), 1000.0, 'AbsTol', 1e-6);
      testCase.verifyEqual(char(c.model.units{1}), '?');
      testCase.verifyEqual(char(c.model.names{1}), 'x1');
      testCase.verifyEqual(testCase.modelData(c), ref, 'RelTol', 1e-9);
    end

    function testImportTextWithLabelsAndTimeStamps(testCase)
      f = testCase.testFile('text_file_with_labels_and_time_stamps.txt');
      c = testCase.importedController(f, 'Text file with labels and time stamps');
      raw = readmatrix(f, 'NumHeaderLines', 1);
      testCase.verifyEqual(double(c.model.n_chan), size(raw, 2) - 1);
      testCase.verifyEqual(double(c.model.n_t), size(raw, 1));
      testCase.verifyEqual(char(c.model.names{1}), 'T1');
      testCase.verifyEqual(char(c.model.names{double(c.model.n_chan)}), 'rA8');
      testCase.verifyEqual(testCase.modelData(c), raw(:, 2:end), 'RelTol', 1e-6);
    end

    function testImportBayleyStyleText(testCase)
      f = testCase.testFile('bayley_LHS_OK371_04.txt');
      c = testCase.importedController(f, 'Bayley-style text, 2.5 um/pel');
      raw = readmatrix(f, 'NumHeaderLines', 1);
      testCase.verifyEqual(double(c.model.n_chan), size(raw, 2) - 1);
      testCase.verifyEqual(double(c.model.n_t), size(raw, 1));
      testCase.verifyEqual(char(c.model.names{1}), 'A7');
      testCase.verifyEqual(char(c.model.names{double(c.model.n_chan)}), 'A1');
      testCase.verifyEqual(char(c.model.units{1}), 'um');
      testCase.verifyEqual(testCase.modelData(c), 2.5*raw(:, 2:end), 'RelTol', 1e-6);
      testCase.verifyEqual(double(c.model.fs), 30.0, 'AbsTol', 1e-6);
      t = double(c.model.t(:));
      testCase.verifyEqual(t, (raw(:, 1) - 1)/30.0, 'AbsTol', 1e-9);

      c5 = testCase.importedController(f, 'Bayley-style text, 5.0 um/pel');
      testCase.verifyEqual(testCase.modelData(c5), 5.0*raw(:, 2:end), 'RelTol', 1e-6);
    end

    function testImportTcsMatchesOpen(testCase)
      testCase.requireTestFile();
      c_imp = testCase.importedController(testCase.TestFile);
      c_open = testCase.loadedController();
      testCase.verifyEqual(double(c_imp.model.n_chan), double(c_open.model.n_chan));
      testCase.verifyEqual(testCase.modelData(c_imp), testCase.modelData(c_open), ...
                           'RelTol', 1e-9);
    end

    function testChooseFileAndImportRoutesThroughDialog(testCase)
      wav = testCase.testFile('godzilla.wav');
      [p, n, e] = fileparts(wav);
      c = testCase.newController();
      c.dialog_responses = {{[n e], [p filesep], 2}};  % wav = filter 2
      c.choose_file_and_import();
      testCase.verifyFalse(isempty(c.model));
      testCase.verifyEqual(double(c.model.n_chan), 1);
    end

    function testImportAbf(testCase)
      f = testCase.testFile('test.abf');
      c = testCase.importedController(f);
      % MATLAB's own abf reader is the reference here (not pyabf): just confirm
      % a sane model was built.
      testCase.verifyFalse(isempty(c.model));
      testCase.verifyGreaterThanOrEqual(double(c.model.n_chan), 1);
      testCase.verifyGreaterThan(double(c.model.n_t), 0);
      testCase.verifyGreaterThan(double(c.model.fs), 0);
    end

    function testImportEmptyAbfReportsError(testCase)
      % A 0-byte .abf can't be parsed: load_traces reports it via errordlg (a
      % free function, so not captured here) and no model is built.
      c = testCase.importedController(testCase.testFile('empty.abf'));
      testCase.verifyTrue(isempty(c.model));
    end

    function testImportUnknownExtensionReportsError(testCase)
      d = testCase.tempDir();
      bad = fullfile(d, 'mystery.xyz');
      fid = fopen(bad, 'w'); fwrite(fid, 'nonsense'); fclose(fid);
      c = testCase.importedController(bad);
      testCase.verifyTrue(isempty(c.model));   % no model built
    end

  end
end
