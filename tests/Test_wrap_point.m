classdef Test_wrap_point < App_test_case
% Test_wrap_point  Back-port of the WrapPointTests in
% pygroundswell/tests/test_mutate_save_import.py.
%
% break_at_wrap_points (used to plot wrapped phase in Coherency) must split a
% column phase signal that crosses the wrap limits into pieces, each confined
% to the wrap range -- and a column input's diff must stay a column.

  methods (Test)
    function testBreakAtWrapPointsWithErrorBars(testCase)
      n = 40;
      x = (1:n)';
      y = linspace(-500.0, 500.0, n)';          % crosses +-180
      y_eb = [linspace(-510, 490, n)' linspace(-490, 510, n)'];   % n x 2
      [xs, ys, ~] = break_at_wrap_points(x, y, [-180.0 180.0], y_eb);
      testCase.verifyGreaterThan(numel(xs), 1, 'a wrapping signal should split');
      vals = [];
      for i = 1:numel(ys)
        vals = [vals; ys{i}(:)]; %#ok<AGROW>
      end
      testCase.verifyGreaterThanOrEqual(min(vals), -180.0 - 1e-6);
      testCase.verifyLessThanOrEqual(max(vals), 180.0 + 1e-6);
    end
  end
end
