#!/usr/bin/env lua
--- Modularity Validation Tool
-- Scans whisker-core lib files for modularity violations
-- Enforces DI patterns and prevents direct module coupling
-- @module tools.validate_modularity
-- @author Whisker Core Team

local lfs = pcall(require, "lfs") and require("lfs") or nil

-- Configuration
local CONFIG = {
  -- Exit codes
  EXIT_SUCCESS = 0,
  EXIT_VIOLATIONS = 1,
  EXIT_ERROR = 2,

  -- Output formats
  FORMAT_TEXT = "text",
  FORMAT_JSON = "json",
  FORMAT_CI = "ci",
}

-- Severity levels
local SEVERITY = {
  ERROR = "error",
  WARNING = "warning",
  INFO = "info",
}

-- Violation rules with patterns and exceptions
local RULES = {
  -- Rule 1: Direct require of whisker modules (except allowed patterns)
  {
    id = "DIRECT_REQUIRE",
    name = "Direct Require Violation",
    description = "Modules should not directly require other whisker modules (use DI)",
    severity = SEVERITY.ERROR,
    pattern = 'require%s*%(%s*["\']whisker%.([^"\']+)["\']%s*%)',
    -- Modules allowed to be required directly
    allowed_requires = {
      "interfaces",           -- Interface definitions are always allowed
      "interfaces%..*",       -- Any interface submodule
      "vendor%..*",           -- Vendor abstractions (not raw vendors)
      "kernel%.container",    -- Container is allowed in bootstrap
      "kernel%.event_bus",    -- Event bus is allowed in bootstrap
      "kernel%.events",       -- Events is allowed
      "kernel%.bootstrap",    -- Bootstrap is allowed in init
      "core%.choice",         -- Core types needed by factories
      "core%.passage",        -- Core types needed by factories
      "core%.story",          -- Core types needed by factories
      "core%.game_state",     -- Core types needed by factories
      "core%.lua_interpreter", -- Core types needed by factories
      "core%.control_flow",   -- Control flow needed by factories
      "core%.engine",         -- Engine is core infrastructure
      "core%.factories%..*",  -- Factories can be required
      -- Intra-module requires are allowed (same module can require its own files)
      "security%..*",         -- Security module intra-module
      "profiling%..*",        -- Profiling module intra-module
      "benchmarks%..*",       -- Benchmarks module intra-module
      "analytics%..*",        -- Analytics module intra-module
      "platform%..*",         -- Platform module intra-module
      "plugin%..*",           -- Plugin module intra-module
      "media%..*",            -- Media module intra-module
      "formats%..*",          -- Formats module intra-module
      "script%..*",           -- Script module intra-module
      "runtime%..*",          -- Runtime module intra-module
      "i18n%..*",             -- i18n module intra-module
      "twine%..*",            -- Twine module intra-module
      "export%..*",           -- Export module intra-module
      "cli%..*",              -- CLI module intra-module
      "tools%..*",            -- Tools module intra-module
      "format%..*",           -- Format module intra-module
      "utils%..*",            -- Utils module intra-module (shared utilities)
    },
    -- Files where direct requires are allowed
    allowed_files = {
      "init%.lua$",           -- Init files wire things together
      "kernel/init%.lua$",    -- Kernel init wires core services
      "kernel/bootstrap%.lua$", -- Bootstrap creates the container
    },
  },

  -- Rule 2: Missing _dependencies declaration
  {
    id = "MISSING_DEPENDENCIES",
    name = "Missing Dependencies Declaration",
    description = "Modules should declare their dependencies via _dependencies",
    severity = SEVERITY.WARNING,
    check = function(content, filepath)
      -- Only check modules that have a new() constructor
      if content:match("function%s+[%w_]+%.new%s*%(") then
        -- Should have _dependencies declaration
        if not content:match("_dependencies%s*=") then
          return true, "Module has new() but no _dependencies declaration"
        end
      end
      return false
    end,
    allowed_files = {
      "init%.lua$",
      "interfaces/.*%.lua$",
    },
  },

  -- Rule 3: Constructor without deps parameter
  {
    id = "NO_DEPS_PARAM",
    name = "Constructor Without Dependencies",
    description = "Constructors should accept a deps/container parameter",
    severity = SEVERITY.WARNING,
    pattern = "function%s+[%w_]+%.new%s*%(%s*%)%s*$",
    allowed_files = {
      "interfaces/.*%.lua$",
    },
  },

  -- Rule 4: Hardcoded dependency creation
  {
    id = "HARDCODED_DEP",
    name = "Hardcoded Dependency Creation",
    description = "Dependencies should be injected, not created directly",
    severity = SEVERITY.ERROR,
    pattern = "=%s*require%s*%([^)]+%)%.new%s*%(",
    allowed_files = {
      "kernel/bootstrap%.lua$",
      "kernel/init%.lua$",
    },
  },

  -- Rule 5: Direct vendor require (should use abstractions)
  {
    id = "DIRECT_VENDOR",
    name = "Direct Vendor Require",
    description = "Should use vendor abstractions instead of direct requires",
    severity = SEVERITY.ERROR,
    patterns = {
      'require%s*%(%s*["\']cjson["\']%s*%)',
      'require%s*%(%s*["\']dkjson["\']%s*%)',
      'require%s*%(%s*["\']whisker%.vendor%.tinta["\']%s*%)',
    },
    allowed_files = {
      "vendor/codecs/.*%.lua$",
      "vendor/runtimes/.*%.lua$",
    },
  },

  -- Rule 6: Global variable assignment
  {
    id = "GLOBAL_ASSIGN",
    name = "Global Variable Assignment",
    description = "Modules should not assign global variables",
    severity = SEVERITY.WARNING,
    -- Need file content to check for forward declarations
    check = function(content, filepath)
      local violations = {}
      local forward_declared = {}

      -- First pass: find forward declarations (local funcName)
      for line in content:gmatch("[^\n]+") do
        local name = line:match("^local%s+([%w_]+)%s*$")
        if name then
          forward_declared[name] = true
        end
      end

      -- Second pass: find global assignments
      local line_num = 0
      for line in content:gmatch("[^\n]+") do
        line_num = line_num + 1
        if line:match("^[%w_]+%s*=") and not line:match("^local%s") then
          -- Skip return statements and common patterns
          if not line:match("^return%s") and not line:match("^%-%-") and not line:match("^M%s*=") then
            -- Check if this is a forward declaration assignment
            local name = line:match("^([%w_]+)%s*=")
            if name and not forward_declared[name] then
              table.insert(violations, {line = line_num, detail = "Possible global variable assignment"})
            end
          end
        end
      end

      return #violations > 0, violations
    end,
    allowed_files = {
      "init%.lua$",
    },
  },

  -- Rule 7: Module should return a table
  {
    id = "NO_RETURN",
    name = "Missing Module Return",
    description = "Modules should return a table",
    severity = SEVERITY.WARNING,
    check = function(content, filepath)
      -- Check if file ends with return statement
      if not content:match("return%s+[%w_]+%s*$") and
         not content:match("return%s+{") then
        return true, "Module may not return a value"
      end
      return false
    end,
    allowed_files = {
      "spec%.lua$",
      "_test%.lua$",
    },
  },
}

-- Files/patterns to always skip
local SKIP_PATTERNS = {
  "spec%.lua$",
  "_spec%.lua$",
  "_test%.lua$",
  "test_.*%.lua$",
  "^%.",
}

-- Directories to skip
local SKIP_DIRS = {
  "tests",
  "spec",
  "examples",
  ".git",
  "node_modules",
  "build",
  "dist",
  "tinta",  -- Third-party Ink runtime library
}

-- Helper functions
local function should_skip_file(path)
  -- Check file patterns
  for _, pattern in ipairs(SKIP_PATTERNS) do
    if path:match(pattern) then
      return true
    end
  end
  -- Check if path contains a skip directory
  for _, dir in ipairs(SKIP_DIRS) do
    if path:match("/" .. dir .. "/") or path:match("^" .. dir .. "/") then
      return true
    end
  end
  return false
end

local function should_skip_dir(name)
  for _, dir in ipairs(SKIP_DIRS) do
    if name == dir then
      return true
    end
  end
  return false
end

local function is_comment(line)
  return line:match("^%s*%-%-")
end

local function is_file_allowed(filepath, allowed_files)
  if not allowed_files then return false end
  for _, pattern in ipairs(allowed_files) do
    if filepath:match(pattern) then
      return true
    end
  end
  return false
end

local function is_require_allowed(module_path, allowed_requires)
  if not allowed_requires then return false end
  for _, pattern in ipairs(allowed_requires) do
    if module_path:match("^" .. pattern .. "$") then
      return true
    end
  end
  return false
end

local function check_rule(rule, content, filepath, line_num, line)
  local issues = {}

  -- Skip if file is in allowed list
  if is_file_allowed(filepath, rule.allowed_files) then
    return issues
  end

  -- Pattern-based check
  if rule.pattern then
    local match = line:match(rule.pattern)
    if match then
      -- Check if the matched require is allowed
      if rule.id == "DIRECT_REQUIRE" then
        if not is_require_allowed(match, rule.allowed_requires) then
          table.insert(issues, {
            rule_id = rule.id,
            severity = rule.severity,
            message = rule.description,
            detail = "requires: whisker." .. match,
          })
        end
      else
        table.insert(issues, {
          rule_id = rule.id,
          severity = rule.severity,
          message = rule.description,
        })
      end
    end
  end

  -- Multiple patterns check
  if rule.patterns then
    for _, pattern in ipairs(rule.patterns) do
      if line:match(pattern) then
        table.insert(issues, {
          rule_id = rule.id,
          severity = rule.severity,
          message = rule.description,
          detail = "matched: " .. pattern,
        })
        break
      end
    end
  end

  -- Line-level custom check function
  if rule.line_check then
    local is_violation, detail = rule.line_check(line, filepath, line_num)
    if is_violation then
      table.insert(issues, {
        rule_id = rule.id,
        severity = rule.severity,
        message = rule.description,
        detail = detail,
      })
    end
  end

  return issues
end

local function check_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local issues = {}
  local lines = {}

  -- Split content into lines
  for line in content:gmatch("[^\n]*") do
    table.insert(lines, line)
  end

  -- Check each line against each rule
  for line_num, line in ipairs(lines) do
    if not is_comment(line) then
      for _, rule in ipairs(RULES) do
        -- Skip file-level checks for line-by-line processing
        if rule.pattern or rule.patterns or rule.line_check then
          local rule_issues = check_rule(rule, content, filepath, line_num, line)
          for _, issue in ipairs(rule_issues) do
            issue.file = filepath
            issue.line = line_num
            issue.content = line:gsub("^%s+", ""):sub(1, 80)
            table.insert(issues, issue)
          end
        end
      end
    end
  end

  -- Run file-level checks
  for _, rule in ipairs(RULES) do
    if rule.check and not rule.pattern and not rule.patterns then
      if not is_file_allowed(filepath, rule.allowed_files) then
        local is_violation, detail = rule.check(content, filepath)
        if is_violation then
          table.insert(issues, {
            file = filepath,
            line = 1,
            rule_id = rule.id,
            severity = rule.severity,
            message = rule.description,
            detail = detail,
            content = "",
          })
        end
      end
    end
  end

  return issues
end

local function scan_directory(path, all_issues)
  all_issues = all_issues or {}

  if lfs then
    -- Use lfs if available
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
            if not should_skip_file(entry) and not should_skip_file(full_path) then
              local issues = check_file(full_path)
              for _, issue in ipairs(issues) do
                table.insert(all_issues, issue)
              end
            end
          end
        end
      end
    end
  else
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
  end

  return all_issues
end

-- Output formatters
local function format_text(issues)
  local error_count = 0
  local warning_count = 0
  local info_count = 0

  for _, issue in ipairs(issues) do
    local symbol = issue.severity == SEVERITY.ERROR and "X"
                   or issue.severity == SEVERITY.WARNING and "!"
                   or "i"

    print(string.format("%s [%s] %s:%d", symbol, issue.rule_id, issue.file, issue.line))
    print(string.format("  %s", issue.message))

    if issue.detail then
      print(string.format("  Detail: %s", issue.detail))
    end

    if issue.content and #issue.content > 0 then
      print(string.format("  Code: %s", issue.content))
    end

    print("")

    if issue.severity == SEVERITY.ERROR then
      error_count = error_count + 1
    elseif issue.severity == SEVERITY.WARNING then
      warning_count = warning_count + 1
    else
      info_count = info_count + 1
    end
  end

  return error_count, warning_count, info_count
end

local function format_json(issues)
  local parts = {}

  table.insert(parts, "{")
  table.insert(parts, '  "issues": [')

  for i, issue in ipairs(issues) do
    local comma = i < #issues and "," or ""
    table.insert(parts, string.format(
      '    {"file": "%s", "line": %d, "rule": "%s", "severity": "%s", "message": "%s"}%s',
      issue.file:gsub("\\", "\\\\"):gsub('"', '\\"'),
      issue.line,
      issue.rule_id,
      issue.severity,
      issue.message:gsub("\\", "\\\\"):gsub('"', '\\"'),
      comma
    ))
  end

  table.insert(parts, "  ],")

  local error_count, warning_count = 0, 0
  for _, issue in ipairs(issues) do
    if issue.severity == SEVERITY.ERROR then
      error_count = error_count + 1
    elseif issue.severity == SEVERITY.WARNING then
      warning_count = warning_count + 1
    end
  end

  table.insert(parts, string.format('  "summary": {"errors": %d, "warnings": %d, "total": %d}',
    error_count, warning_count, #issues))
  table.insert(parts, "}")

  print(table.concat(parts, "\n"))

  return error_count, warning_count, 0
end

local function format_ci(issues)
  -- GitHub Actions annotation format
  for _, issue in ipairs(issues) do
    local level = issue.severity == SEVERITY.ERROR and "error" or "warning"
    print(string.format("::%s file=%s,line=%d::[%s] %s",
      level, issue.file, issue.line, issue.rule_id, issue.message))
  end

  local error_count, warning_count = 0, 0
  for _, issue in ipairs(issues) do
    if issue.severity == SEVERITY.ERROR then
      error_count = error_count + 1
    elseif issue.severity == SEVERITY.WARNING then
      warning_count = warning_count + 1
    end
  end

  return error_count, warning_count, 0
end

-- Print usage information
local function print_usage()
  print("Usage: lua validate_modularity.lua [options] [path]")
  print("")
  print("Options:")
  print("  --format=FORMAT   Output format: text (default), json, ci")
  print("  --errors-only     Only report errors, not warnings")
  print("  --list-rules      List all validation rules")
  print("  --help            Show this help message")
  print("")
  print("Path:")
  print("  Directory to scan (default: lib/whisker)")
  print("")
  print("Exit codes:")
  print("  0  No errors found")
  print("  1  Errors found")
  print("  2  Tool error")
end

local function print_rules()
  print("Modularity Validation Rules")
  print("===========================")
  print("")

  for _, rule in ipairs(RULES) do
    print(string.format("[%s] %s", rule.id, rule.name))
    print(string.format("  Severity: %s", rule.severity))
    print(string.format("  %s", rule.description))
    print("")
  end
end

-- Parse command line arguments
local function parse_args()
  local options = {
    format = CONFIG.FORMAT_TEXT,
    errors_only = false,
    path = "lib/whisker",
  }

  for i, arg_val in ipairs(arg) do
    if arg_val == "--help" or arg_val == "-h" then
      print_usage()
      os.exit(CONFIG.EXIT_SUCCESS)
    elseif arg_val == "--list-rules" then
      print_rules()
      os.exit(CONFIG.EXIT_SUCCESS)
    elseif arg_val == "--errors-only" then
      options.errors_only = true
    elseif arg_val:match("^--format=") then
      options.format = arg_val:match("^--format=(.+)$")
    elseif not arg_val:match("^%-") then
      options.path = arg_val
    end
  end

  return options
end

-- Main execution
local function main()
  local options = parse_args()

  if options.format == CONFIG.FORMAT_TEXT then
    print("Modularity Validation")
    print("=====================")
    print(string.format("Scanning: %s", options.path))
    print(string.format("Format: %s", options.format))
    print("")
  end

  local issues = scan_directory(options.path)

  -- Filter to errors only if requested
  if options.errors_only then
    local filtered = {}
    for _, issue in ipairs(issues) do
      if issue.severity == SEVERITY.ERROR then
        table.insert(filtered, issue)
      end
    end
    issues = filtered
  end

  if #issues == 0 then
    if options.format == CONFIG.FORMAT_TEXT then
      print("No modularity violations found!")
      print("")
      print("PASSED")
    elseif options.format == CONFIG.FORMAT_JSON then
      print('{"issues": [], "summary": {"errors": 0, "warnings": 0, "total": 0}}')
    end
    os.exit(CONFIG.EXIT_SUCCESS)
  end

  local error_count, warning_count

  if options.format == CONFIG.FORMAT_JSON then
    error_count, warning_count = format_json(issues)
  elseif options.format == CONFIG.FORMAT_CI then
    error_count, warning_count = format_ci(issues)
  else
    error_count, warning_count = format_text(issues)
  end

  if options.format == CONFIG.FORMAT_TEXT then
    print(string.format("Summary: %d errors, %d warnings", error_count, warning_count))
    print("")

    if error_count > 0 then
      print("FAILED: Fix errors before proceeding")
    else
      print("PASSED with warnings")
    end
  end

  if error_count > 0 then
    os.exit(CONFIG.EXIT_VIOLATIONS)
  else
    os.exit(CONFIG.EXIT_SUCCESS)
  end
end

-- Export for testing
local M = {
  RULES = RULES,
  SEVERITY = SEVERITY,
  CONFIG = CONFIG,
  check_file = check_file,
  scan_directory = scan_directory,
  is_file_allowed = is_file_allowed,
  is_require_allowed = is_require_allowed,
}

-- Run if executed directly
if arg and arg[0] and arg[0]:match("validate_modularity%.lua$") then
  main()
end

return M
