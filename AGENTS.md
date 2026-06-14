# AGENTS.md

Guidance for working in this repository.

# Overview

Groundswell is a MATLAB application for viewing and analyzing
time-series (especially e-phys) data; `roving` is its companion
imaging/ROI app. Both follow a Model–View–Controller layout under the
`+groundswell` and `+roving` packages.  `tmt_116/` is a vendored
utility toolbox. `modpath.m` puts the app and toolbox on the MATLAB
path.

# Running the test suite

The tests live under `tests/` and use the `matlab.unittest`
framework. They drive the real `groundswell`/`roving` Controller and
View through their actual menu and button callbacks; only the
interactive dialogs are stubbed (see `tests/README.md` for how the
Controller's test mode works).

## Prerequisites

- **MATLAB** on the `PATH` (`matlab`).
- **A display.** The tests create figures, so they need an X
  display. Run them headlessly under `xvfb-run`, or with a real
  `DISPLAY` set.
- **Test data.** Most tests read fixtures from a `test-files/`
  directory near the repo. `tests/test_files_dir.m` locates it,
  checking `../test-files` first, then `../../test-files`. If it isn't
  found, the data-dependent tests skip themselves (reported as
  *filtered by assumption*) rather than fail.

## Headless (recommended)

From the repo root:

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" matlab -softwareopengl \
  -sd "$(pwd)" -batch "modpath(); assertSuccess(runtests('tests'))"
```

`assertSuccess` makes MATLAB exit non-zero if any test fails, which is
what you want for CI or a quick pass/fail.

The `-screen 0 1920x1080x24` and `-softwareopengl` flags matter: some
tests assert that a figure actually drew pixels by capturing it with
`getframe`.  Under a plain `xvfb-run -a` (low-color screen, no usable
OpenGL) those captures fail with
`MATLAB:print:ProblemGeneratingOutput` ("Failed to export"). A 24-bit
screen plus MATLAB's software OpenGL renderer makes them pass.

## With a display

If you already have a working `DISPLAY`:

```bash
matlab -sd "$(pwd)" -batch "modpath(); assertSuccess(runtests('tests'))"
```

## Interactively, inside MATLAB

From the `groundswell/` directory:

```matlab
modpath();                          % put the app + toolbox on the path
results = runtests('tests');        % whole suite
results = runtests('tests/TestAppOpen.m')   % a single test file
```

## Interpreting results

- **Passed / Failed** — as usual; `assertSuccess(results)` throws on
  any failure.
- **Incomplete / "filtered by assumption"** — the test was skipped,
  almost always because its `test-files/` fixture isn't present. Make
  `test-files/` reachable (see *Test data* above) to actually exercise
  those tests.

# Commit conventions

- Keep unrelated changes in separate commits (e.g. line-ending
  normalization separate from code changes).
- Do not mention Claude or other AI tooling in commit messages.
- Use the 50/72 rule for git messages.  The "body" should be empty
  only for very simple commits.

# MATLAB coding conventions

Indents should all be two spaces.  Top-level functions should be
indented.  Never use tabs.

Most identifiers should be lower snake case: all lowercase, with words
separated by underscores (e.g. `row_count`, `is_in_test_mode`).
Exceptions include class names, which are capitalized: a single word is
just capitalized (`Controller`); a multi-word name capitalizes the
first letter only, with underscores between the words
(`Video_file_imagej_jumbo_tif`).

Prefer standalone functions (in utility/, one function per file) over
static methods on a class.  If a helper doesn't need access to class
state, it usually doesn't belong on the class.  Only reach for a
static method when the helper is genuinely class-specific (e.g. an
alternate constructor, or a helper that operates on the class's own
representation in a way that wouldn't make sense elsewhere).

Boolean variables should start with some conjugation of "to be" or "to
do".  For instance: `is_done`, `did_explode`, `are_you_sure`.

Local variables in functions/methods should only be overwritten if
necessary for performance.  Prefer to create new variables holding
evolving versions of some value.

Prefer explicit variable names, even if they are long; and avoid
abbreviations.  Use a shorter English word that means the same thing
instead of an abbreviation.

For identifiers representing the number of something, prefer
`<singularNoun>_count` to `n_<PluralNoun>`.  E.g. prefer `row_count` to
`n_rows`, and `view_count` to `n_views`.  Applies to local variables,
properties, function/method names, and arguments alike.

Use spaces liberally in long expressions to add clarity.  E.g. add a
space after each comma in the argument list for functions.

This includes inserting a space before the final semicolon in a line
of code.

When checking for optional arguments, don't use nargin.  Use
exist(<variable name>, 'var').  This is less likely to break when
you add/remove arguments.

Treat the result of exist() as a logical only.  Don't compare it to
a specific numeric value (e.g. `exist(x, 'file') == 2`); the codes
overlap in subtle ways and shift between releases.  Just write
`if exist(x, 'var')` or `if ~exist(x, 'file')`.

The "end" keyword at the end of a function should be followed by the
comment "% function".  Same for end of a methods block and a
classdef block.

Individual lines should not be longer than 160 characters.

switch statements that check for multiple enumerated cases should
enumerate all the handled cases explicitly, and throw an error in
the "otherwise:" clause.  This makes it easier to find
inappropriately-handled cases when testing.

I sometimes use the term "charray" for "char array".  OK to use this
in comments, but just use "char" in variable names.

When converting a custom class to a char array, write it as
"char(thing)", not thing.char()

When calling `notify()` on an object, write it as
`obj.notify(<args>)`, not `notify(obj, <args>)`.

All functions and methods should have a comment after the line with
`function` in it that says what the function does in plain English.

If a line is too long, and it's of the form `w = f(x, y, z) ;`, break
it across lines like this:

```
w = f(x, ...
      y, ...
      z) ;
```

If that is still too long, do this:

```
w = ...
  f(x, ...
    y, ...
    z) ;
```

Validation should almost always happen in the model, never in the
controller.
