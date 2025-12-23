#!/usr/bin/env lua
--- Modularity Validation Tool
-- Scans whisker-core lib files for modularity violations
-- @module tools.validate_modularity
-- @author Whisker Core Team

local lfs = require("lfs") or {}

-- Patterns that indicate modularity violations
local violations = {
  -- Direct require of whisker modules (except interfaces)
  {
    pattern = 'require%s*%(%s*["\']whisker%.(?!interfaces)',
    message = "DIRECT_REQUIRE: Direct require of whisker module",
    severity = "error"
  },
  -- Module-level tables that may be global state
  {
    pattern = "^local%s+[%w_]+%s*=%s*{}%s*$",
    message = "POSSIBLE_GLOBAL_STATE: Module-level table may be global state",
    severity = "warning"
  },
  -- Constructor without container parameter
  {
    pattern = "function%s+[%w_]+%.new%s*%(%)%s*$",
    message = "NO_DI_PARAM: Constructor may not accept container parameter",
    severity = "warning"
  },
  -- Hardcoded dependency creation
  {
    pattern = "=%s*require%s*%(.*%)%.new%s*%(",
    message = "HARDCODED_DEPENDENCY: Creating dependency directly",
    severity = "error"
  },
  -- Global variable assignment
  {
    pattern = "^[%w_]+%s*=%s*",
    message = "MODULE_GLOBAL: Possible global variable assignment",
    severity = "warning"
  },
}

-- Files/patterns to skip
local skip_patterns = {
  "init%.lua$",
  "spec%.lua$",
  "_test%.lua$",
  "^%.",  -- hidden files
}

-- Directories to skip
local skip_dirs = {
  "tests",
  "spec",
  "examples",
  ".git",
}

local function should_skip_file(path)
  for _, pattern in ipairs(skip_patterns) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

local function should_skip_dir(name)
  for _, dir in ipairs(skip_dirs) do
    if name == dir then
      return true
    end
  end
  return false
end

local function is_comment(line)
  return line:match("^%s*%-%-")
end

local function check_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return {}
  end

  local issues = {}
  local line_num = 0

  for line in file:lines() do
    line_num = line_num + 1

    -- Skip comments
    if not is_comment(line) then
      for _, violation in ipairs(violations) do
        if line:match(violation.pattern) then
          -- Skip class definition patterns
          if violation.message:match("GLOBAL_STATE") and
             (line:match("^local%s+[A-Z]") or line:match("__index")) then
            -- Skip - likely a class definition
          else
            table.insert(issues, {
              file = filepath,
              line = line_num,
              message = violation.message,
              severity = violation.severity,
              content = line:gsub("^%s+", ""):sub(1, 60)
            })
          end
        end
      end
    end
  end

  file:close()
  return issues
end

local function scan_directory(path, all_issues)
  all_issues = all_issues or {}

  -- Try to use lfs if available
  local scan_func = lfs and lfs.dir

  if not scan_func then
    -- Fallback to shell command
    local handle = io.popen('find "' .. path .. '" -name "*.lua" -type f 2>/dev/null')
    if handle then
      for filepath in handle:lines() do
        if not should_skip_file(filepath) then
          local issues = check_file(filepath)
          for _, issue in ipairs(issues) do
            table.insert(all_issues, issue)
          end
        end
      end
      handle:close()
    end
    return all_issues
  end

  -- Use lfs
  for entry in lfs.dir(path) do
    if entry ~= "." and entry ~= ".." then
      local full_path = path .. "/" .. entry
      local attr = lfs.attributes(full_path)

      if attr then
        if attr.mode == "directory" then
          if not should_skip_dir(entry) then
            scan_directory(full_path, all_issues)
          end
        elseif attr.mode == "file" and entry:match("%.lua$") then
          if not should_skip_file(entry) then
            local issues = check_file(full_path)
            for _, issue in ipairs(issues) do
              table.insert(all_issues, issue)
            end
          end
        end
      end
    end
  end

  return all_issues
end

local function print_issues(issues)
  local error_count = 0
  local warning_count = 0

  for _, issue in ipairs(issues) do
    local symbol = issue.severity == "error" and "X" or "!"
    print(string.format("%s %s:%d: %s",
      symbol, issue.file, issue.line, issue.message))

    if issue.content then
      print(string.format("    %s", issue.content))
    end

    if issue.severity == "error" then
      error_count = error_count + 1
    else
      warning_count = warning_count + 1
    end
  end

  return error_count, warning_count
end

-- Main execution
local function main()
  local lib_path = arg[1] or "lib/whisker"

  print("Modularity Validation")
  print("=====================")
  print(string.format("Scanning: %s", lib_path))
  print("")

  local issues = scan_directory(lib_path)

  if #issues == 0 then
    print("No modularity violations found!")
    print("")
    print("PASSED")
    os.exit(0)
  end

  local error_count, warning_count = print_issues(issues)

  print("")
  print(string.format("Summary: %d errors, %d warnings", error_count, warning_count))

  if error_count > 0 then
    print("")
    print("FAILED: Fix errors before proceeding")
    os.exit(1)
  else
    print("")
    print("PASSED with warnings")
    os.exit(0)
  end
end

main()
