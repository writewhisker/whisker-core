#!/usr/bin/env lua
-- Script to count lines in Lua files

local function count_lines(filepath)
  local count = 0
  local file = io.open(filepath, "r")
  if not file then return 0 end

  for _ in file:lines() do
    count = count + 1
  end
  file:close()
  return count
end

local function scan_directory(dir, exclude_vendor)
  local files = {}
  local handle = io.popen("find " .. dir .. ' -name "*.lua" 2>/dev/null')
  if not handle then return files end

  for line in handle:lines() do
    if not exclude_vendor or not line:match("/vendor/") then
      table.insert(files, line)
    end
  end
  handle:close()
  return files
end

-- Main execution
local lib_dir = arg[1] or "/Users/jims/code/github.com/writewhisker/impl/whisker-core/lib/whisker"
local files = scan_directory(lib_dir, true)

local total_lines = 0
for _, filepath in ipairs(files) do
  local lines = count_lines(filepath)
  total_lines = total_lines + lines
end

print(string.format("Files: %d", #files))
print(string.format("Lines: %d", total_lines))
