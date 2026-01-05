--- VCS Tools
-- Version control system tools for diffing and merging stories
-- @module whisker.vcs
-- @author Whisker Core Team
-- @license MIT

local vcs = {}
vcs._dependencies = {}

-- Import submodules
local ok_diff, diff = pcall(require, "whisker.vcs.diff")
if ok_diff then
  vcs.diff = diff.diff_stories
  vcs.format_diff = diff.format_diff
  vcs.get_summary = diff.get_summary
end

local ok_merge, merge = pcall(require, "whisker.vcs.merge")
if ok_merge then
  vcs.merge = merge.merge_stories
  vcs.resolve_conflicts = merge.resolve_conflicts
end

return vcs
