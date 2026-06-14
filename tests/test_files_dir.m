function d = test_files_dir()
% test_files_dir  Absolute path to the shared test-files directory, or '' if
% it can't be found.  The directory lives near the repo; check
% repo/../test-files first, then repo/../../test-files, before giving up.
% Resolved from this file's own location, so it's independent of the caller's
% current directory.

here = fileparts(mfilename('fullpath'));   % groundswell/tests
repo = fileparts(here);                    % groundswell/
candidates = { fullfile(repo, '..', 'test-files'), ...
               fullfile(repo, '..', '..', 'test-files') };

d = '';
for i = 1:numel(candidates)
  if exist(candidates{i}, 'dir')
    d = char(java.io.File(candidates{i}).getCanonicalPath());
    return;
  end
end

end
