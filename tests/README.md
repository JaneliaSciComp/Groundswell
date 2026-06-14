# groundswell/tests — MATLAB test suite

A `matlab.unittest` suite for the Groundswell MATLAB app, back-ported from the
Python end-to-end tests under `pygroundswell/tests/`.  Like those, the tests
drive the **real** `groundswell.Controller`/`View` through the real menu and
button callbacks; only the interactive dialogs are stubbed.

## Running

A figure is created on the display, so a `DISPLAY` (or `xvfb-run`) must be
available.  From the `groundswell/` directory:

```matlab
modpath();                          % put the app + toolbox on the path
results = runtests('tests');        % whole suite
results = runtests('tests/Test_app_open.m')
```

or headless from a shell:

```bash
matlab -sd "$(pwd)" -batch "modpath(); assertSuccess(runtests('tests'))"
```

## How dialogs are stubbed

The groundswell `@Controller` runs its dialogs through wrapper methods
(`self.uigetfile(...)`, `self.inputdlg(...)`, `self.errordlg(...)`, …).  In
normal use they just call the real builtins, so interactive operation is
unchanged.  A test sets `c.is_in_test_mode = true` and then:

- queues the answers input dialogs should return in `c.dialog_responses` (a
  FIFO the wrappers pop — `{filename, dir}` for uigetfile/uiputfile, the cell
  inputdlg returns, the questdlg button string; `[]` is a sentinel meaning
  "accept the dialog's prefilled defaults", `{}` means Cancel);
- reads the text of any `errordlg`/`warndlg`/`msgbox` from `c.dialog_messages`;
- reads anything sent to `audioplayer` from `c.played_audio`.

`App_test_case` provides the shared fixtures and helpers (`openViaMenu`,
`fileResponse`, `trigger`, `fireButtonDown`, `selectChannels`, …).

The **roving** `@Controller` works the same way (`is_in_test_mode` +
`dialog_responses`/`dialog_messages`; its dialogs are uigetfile / uiputfile /
inputdlg / errordlg); `Roving_test_case` provides the matching fixtures.

## Files

- `App_test_case.m` — shared base fixture (path setup, figure cleanup, helpers).
- `Test_app_open.m` — open a `.tcs`, zoom/scroll, X-units + Set Range, channel
  selection, Y-range optimisation + Set Range, mutations.
- `Test_mutate_save.m` — data mutations (dx/x, change-fs, center), Save/Save-As,
  file lifecycle (close/revert/quit), and the Import paths (wav/text/abf/tcs).
- `Test_analysis.m` — the Analysis menu: power spectrum, spectrogram, coherency,
  coherency-at-frequency, coherogram, transfer function (run + draw, parameter
  rejection, mode menus), plus count-TTL-edges and play-as-audio.
- `Test_add_synced_data.m` — File ▸ Add synched data... and ...(FT): splice ROI
  signals from a second .tcs into the e-phys model, time-aligned via the
  camera-shutter TTL (the FT variant answers the frame-transfer confirmation).
- `Test_wrap_point.m` — break_at_wrap_points (wrapped-phase splitting).
- `FakeAudioPlayer.m` — a no-op stand-in for audioplayer used by the audio test.
- `Roving_test_case.m` — shared base fixture for the Roving (imaging/ROI) app.
- `Test_roving_app.m` — Roving: launch, open TIFF / ImageJ-jumbo / MJ2 video,
  mode buttons, every menu item, every button/edit.
- `Test_roving_overlay.m` — Roving File ▸ Overlay ▸ Load overlay...: synthesize a
  .ovl (via the app's Overlay_file_writer) and check its lines draw into the
  main axes.

## Relationship to the Python suite

These mirror the Python tests one class/method at a time.  A few Python tests
are intentionally not ported because they exercise the PyQt6 layer rather than
groundswell logic (e.g. dragging the Qt scrollbar, synthesising a mouse-drag
zoom); those are noted in the test files.

Note: the MATLAB `tests/` directory is skipped by `tools/mtree_export.m`, so
re-exporting the ASTs does not dump the test sources into `asts/`.
