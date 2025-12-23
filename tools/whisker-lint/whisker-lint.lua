#!/usr/bin/env lua
-- whisker-lint: Static analysis for whisker-core interactive fiction
-- Detects errors, accessibility issues, and style violations

local script_dir = arg[0]:match("(.*/)") or "./"
package.path = script_dir .. "?.lua;" ..
               script_dir .. "lib/?.lua;" ..
               script_dir .. "lib/rules/?.lua;" ..
               script_dir .. "lib/reporters/?.lua;" ..
               package.path

local function print_help()
  print([[
whisker-lint - Static Analysis for Whisker Stories

Usage: whisker-lint [options] <file|directory>...

Options:
  -h, --help           Show this help message
  -v, --version        Show version information
  -c, --config FILE    Use custom config file (default: .whisker-lint.json)
  -f, --format FORMAT  Output format: text, json (default: text)
  --fix                Auto-fix fixable issues
  --quiet              Only show errors, not warnings
  --max-warnings N     Exit with error if warnings exceed N

Rules:
  unreachable-passage    Passage never visited from Start
  undefined-reference    Reference to non-existent passage
  unused-variable        Variable assigned but never read
  missing-start          No Start passage defined
  empty-passage          Passage with no content
  circular-only          Passage only reachable through itself

Exit Codes:
  0 - No issues found
  1 - Warnings found
  2 - Errors found

Examples:
  whisker-lint story.ink
  whisker-lint --format json src/
  whisker-lint -c custom.json story.ink
]])
end

local function print_version()
  print("whisker-lint 0.1.0")
  print("Static analysis for whisker-core stories")
end

-- Simple JSON encoder for config parsing
local function decode_json(str)
  -- Very simple JSON parser for config files
  local result = {}

  -- Parse object
  str = str:gsub("^%s*{", ""):gsub("}%s*$", "")

  for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
    value = value:gsub("^%s*", ""):gsub("%s*$", "")
    if value:match('^"') then
      result[key] = value:gsub('^"', ''):gsub('"$', '')
    elseif value == "true" then
      result[key] = true
    elseif value == "false" then
      result[key] = false
    elseif tonumber(value) then
      result[key] = tonumber(value)
    else
      result[key] = value
    end
  end

  -- Parse nested rules object
  local rules_match = str:match('"rules"%s*:%s*({[^}]+})')
  if rules_match then
    result.rules = {}
    for key, value in rules_match:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
      result.rules[key] = value
    end
  end

  return result
end

-- Config loader
local ConfigLoader = {}

function ConfigLoader.load(file_path)
  local default_config = {
    rules = {
      ["unreachable-passage"] = "warn",
      ["undefined-reference"] = "error",
      ["unused-variable"] = "warn",
      ["missing-start"] = "error",
      ["empty-passage"] = "warn",
      ["circular-only"] = "warn"
    },
    exclude = {}
  }

  if not file_path then
    file_path = ".whisker-lint.json"
  end

  local f = io.open(file_path, "r")
  if not f then
    return default_config
  end

  local content = f:read("*a")
  f:close()

  local ok, user_config = pcall(decode_json, content)
  if not ok then
    io.stderr:write("Warning: Could not parse config file\n")
    return default_config
  end

  -- Merge rules
  if user_config.rules then
    for k, v in pairs(user_config.rules) do
      default_config.rules[k] = v
    end
  end

  return default_config
end

-- Story Parser (simplified for linting)
local StoryParser = {}

function StoryParser.parse(content, format)
  local ast = {
    passages = {},
    variables = {},
    format = format
  }

  if format == "ink" then
    StoryParser.parse_ink(content, ast)
  elseif format == "twee" then
    StoryParser.parse_twee(content, ast)
  elseif format == "wscript" then
    StoryParser.parse_wscript(content, ast)
  end

  return ast
end

function StoryParser.parse_ink(content, ast)
  local current_passage = nil
  local line_num = 0

  for line in content:gmatch("([^\n]*)\n?") do
    line_num = line_num + 1

    -- Passage header: === Name ===
    local passage_name = line:match("^%s*===+%s*([%w_]+)%s*===+")
    if passage_name then
      current_passage = {
        name = passage_name,
        line = line_num,
        content = {},
        targets = {},
        variables_set = {},
        variables_read = {}
      }
      ast.passages[passage_name] = current_passage
    elseif current_passage then
      table.insert(current_passage.content, line)

      -- Check if this is a choice line
      local is_choice_line = line:match("^%s*[%*%+]")

      if is_choice_line then
        -- Find choice targets: * [text] -> Target or * text -> Target
        for target in line:gmatch("->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(current_passage.targets, {name = target, line = line_num, type = "choice"})
          end
        end
      else
        -- Find diverts: -> Target (only on non-choice lines)
        for target in line:gmatch("->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(current_passage.targets, {name = target, line = line_num})
          end
        end
      end

      -- Find variable assignments: ~ var = value
      for var in line:gmatch("~%s*([%w_]+)%s*=") do
        table.insert(current_passage.variables_set, {name = var, line = line_num})
        ast.variables[var] = ast.variables[var] or {assignments = {}, reads = {}}
        table.insert(ast.variables[var].assignments, {passage = current_passage.name, line = line_num})
      end

      -- Find variable reads: {var}
      for var in line:gmatch("{([%w_]+)}") do
        table.insert(current_passage.variables_read, {name = var, line = line_num})
        ast.variables[var] = ast.variables[var] or {assignments = {}, reads = {}}
        table.insert(ast.variables[var].reads, {passage = current_passage.name, line = line_num})
      end
    end
  end
end

function StoryParser.parse_twee(content, ast)
  local current_passage = nil
  local line_num = 0

  for line in content:gmatch("([^\n]*)\n?") do
    line_num = line_num + 1

    -- Passage header: :: Name [tags]
    local passage_name = line:match("^::%s*([^%[%{]+)")
    if passage_name then
      passage_name = passage_name:match("^%s*(.-)%s*$")
      current_passage = {
        name = passage_name,
        line = line_num,
        content = {},
        targets = {},
        variables_set = {},
        variables_read = {}
      }
      ast.passages[passage_name] = current_passage
    elseif current_passage then
      table.insert(current_passage.content, line)

      -- Find links: [[text|target]] or [[target]]
      for link in line:gmatch("%[%[([^%]]+)%]%]") do
        local target = link:match("|([^%]]+)$") or link:match("->([^%]]+)$") or link
        target = target:match("^%s*(.-)%s*$")
        table.insert(current_passage.targets, {name = target, line = line_num, type = "link"})
      end

      -- Find variable assignments: <<set $var = value>>
      for var in line:gmatch("<<set%s+%$([%w_]+)") do
        table.insert(current_passage.variables_set, {name = var, line = line_num})
        ast.variables[var] = ast.variables[var] or {assignments = {}, reads = {}}
        table.insert(ast.variables[var].assignments, {passage = current_passage.name, line = line_num})
      end

      -- Find variable reads: $var
      for var in line:gmatch("%$([%w_]+)") do
        if not line:match("<<set%s+%$" .. var) then
          table.insert(current_passage.variables_read, {name = var, line = line_num})
          ast.variables[var] = ast.variables[var] or {assignments = {}, reads = {}}
          table.insert(ast.variables[var].reads, {passage = current_passage.name, line = line_num})
        end
      end
    end
  end
end

function StoryParser.parse_wscript(content, ast)
  local current_passage = nil
  local brace_count = 0
  local line_num = 0

  for line in content:gmatch("([^\n]*)\n?") do
    line_num = line_num + 1

    -- Passage header: passage "Name" {
    local passage_name = line:match('^%s*passage%s+"([^"]+)"')
    if passage_name and brace_count == 0 then
      current_passage = {
        name = passage_name,
        line = line_num,
        content = {},
        targets = {},
        variables_set = {},
        variables_read = {}
      }
      ast.passages[passage_name] = current_passage
      brace_count = 1
    elseif current_passage then
      for _ in line:gmatch("{") do brace_count = brace_count + 1 end
      for _ in line:gmatch("}") do brace_count = brace_count - 1 end

      if brace_count == 0 then
        current_passage = nil
      else
        table.insert(current_passage.content, line)

        -- Find diverts: -> Target
        for target in line:gmatch("->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(current_passage.targets, {name = target, line = line_num})
          end
        end
      end
    end
  end
end

-- Rules
local Rules = {}

Rules["missing-start"] = {
  name = "missing-start",
  check = function(ast, context)
    local issues = {}
    local start_names = {"Start", "START", "start", "Beginning"}
    local has_start = false

    for _, name in ipairs(start_names) do
      if ast.passages[name] then
        has_start = true
        break
      end
    end

    if not has_start and next(ast.passages) then
      table.insert(issues, {
        file = context.file,
        line = 1,
        column = 0,
        message = "No 'Start' passage defined",
        rule = "missing-start"
      })
    end

    return issues
  end
}

Rules["unreachable-passage"] = {
  name = "unreachable-passage",
  check = function(ast, context)
    local issues = {}

    -- Find start passage
    local start_names = {"Start", "START", "start", "Beginning"}
    local start = nil
    for _, name in ipairs(start_names) do
      if ast.passages[name] then
        start = name
        break
      end
    end

    if not start then
      -- Use first passage as start
      for name, _ in pairs(ast.passages) do
        start = name
        break
      end
    end

    if not start then
      return issues
    end

    -- BFS to find reachable passages
    local reachable = {[start] = true}
    local queue = {start}

    while #queue > 0 do
      local current = table.remove(queue, 1)
      local passage = ast.passages[current]

      if passage then
        for _, target in ipairs(passage.targets) do
          if ast.passages[target.name] and not reachable[target.name] then
            reachable[target.name] = true
            table.insert(queue, target.name)
          end
        end
      end
    end

    -- Report unreachable passages
    for name, passage in pairs(ast.passages) do
      if not reachable[name] then
        table.insert(issues, {
          file = context.file,
          line = passage.line,
          column = 0,
          message = string.format("Passage '%s' is unreachable", name),
          rule = "unreachable-passage"
        })
      end
    end

    return issues
  end
}

Rules["undefined-reference"] = {
  name = "undefined-reference",
  check = function(ast, context)
    local issues = {}

    for name, passage in pairs(ast.passages) do
      for _, target in ipairs(passage.targets) do
        if not ast.passages[target.name] then
          table.insert(issues, {
            file = context.file,
            line = target.line,
            column = 0,
            message = string.format("Undefined passage '%s' referenced from '%s'", target.name, name),
            rule = "undefined-reference"
          })
        end
      end
    end

    return issues
  end
}

Rules["unused-variable"] = {
  name = "unused-variable",
  check = function(ast, context)
    local issues = {}

    for name, var in pairs(ast.variables) do
      if #var.assignments > 0 and #var.reads == 0 then
        local first_assignment = var.assignments[1]
        table.insert(issues, {
          file = context.file,
          line = first_assignment.line,
          column = 0,
          message = string.format("Variable '%s' is assigned but never read", name),
          rule = "unused-variable"
        })
      end
    end

    return issues
  end
}

Rules["empty-passage"] = {
  name = "empty-passage",
  check = function(ast, context)
    local issues = {}

    for name, passage in pairs(ast.passages) do
      local has_content = false
      for _, line in ipairs(passage.content) do
        if line:match("%S") and not line:match("^%s*//") and not line:match("^%s*#") then
          has_content = true
          break
        end
      end

      if not has_content and #passage.targets == 0 then
        table.insert(issues, {
          file = context.file,
          line = passage.line,
          column = 0,
          message = string.format("Passage '%s' has no content or choices", name),
          rule = "empty-passage"
        })
      end
    end

    return issues
  end
}

Rules["circular-only"] = {
  name = "circular-only",
  check = function(ast, context)
    local issues = {}

    -- Find passages only reachable through themselves
    for name, passage in pairs(ast.passages) do
      local references_from_others = false

      for other_name, other_passage in pairs(ast.passages) do
        if other_name ~= name then
          for _, target in ipairs(other_passage.targets) do
            if target.name == name then
              references_from_others = true
              break
            end
          end
        end
        if references_from_others then break end
      end

      -- Check if passage references itself
      local self_reference = false
      for _, target in ipairs(passage.targets) do
        if target.name == name then
          self_reference = true
          break
        end
      end

      if self_reference and not references_from_others then
        local start_names = {"Start", "START", "start", "Beginning"}
        local is_start = false
        for _, start_name in ipairs(start_names) do
          if name == start_name then
            is_start = true
            break
          end
        end

        if not is_start then
          table.insert(issues, {
            file = context.file,
            line = passage.line,
            column = 0,
            message = string.format("Passage '%s' is only reachable through self-reference", name),
            rule = "circular-only"
          })
        end
      end
    end

    return issues
  end
}

-- Reporters
local Reporters = {}

function Reporters.text(issues, options)
  for _, issue in ipairs(issues) do
    local severity_str = issue.severity == "error" and "error" or "warning"
    print(string.format("%s:%d:%d - %s - %s (%s)",
      issue.file,
      issue.line,
      issue.column,
      severity_str,
      issue.message,
      issue.rule
    ))
  end
end

function Reporters.json(issues, options)
  local parts = {}
  for _, issue in ipairs(issues) do
    table.insert(parts, string.format(
      '{"file":"%s","line":%d,"column":%d,"severity":"%s","message":"%s","rule":"%s"}',
      issue.file:gsub("\\", "\\\\"):gsub('"', '\\"'),
      issue.line,
      issue.column,
      issue.severity,
      issue.message:gsub("\\", "\\\\"):gsub('"', '\\"'),
      issue.rule
    ))
  end
  print("[" .. table.concat(parts, ",") .. "]")
end

-- Main Linter
local Linter = {}
Linter.__index = Linter

function Linter.new(config_file)
  local self = setmetatable({}, Linter)
  self.config = ConfigLoader.load(config_file)
  self.rules = Rules
  return self
end

function Linter:lint_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    io.stderr:write("Error: Cannot open file: " .. filepath .. "\n")
    return {}
  end

  local content = file:read("*a")
  file:close()

  -- Detect format from extension
  local ext = filepath:match("%.([^%.]+)$")
  local format = "ink"
  if ext == "twee" or ext == "tw" then
    format = "twee"
  elseif ext == "wscript" then
    format = "wscript"
  end

  local ast = StoryParser.parse(content, format)
  local context = {file = filepath}
  local all_issues = {}

  for rule_name, rule in pairs(self.rules) do
    local rule_severity = self.config.rules[rule_name]
    if rule_severity and rule_severity ~= "off" then
      local issues = rule.check(ast, context)
      for _, issue in ipairs(issues) do
        issue.severity = rule_severity
        table.insert(all_issues, issue)
      end
    end
  end

  -- Sort by line number
  table.sort(all_issues, function(a, b)
    if a.line ~= b.line then
      return a.line < b.line
    end
    return a.column < b.column
  end)

  return all_issues
end

function Linter:lint_directory(dirpath)
  local all_issues = {}

  -- Use ls to find files (cross-platform approach)
  local handle = io.popen('find "' .. dirpath .. '" -type f \\( -name "*.ink" -o -name "*.twee" -o -name "*.tw" -o -name "*.wscript" \\) 2>/dev/null')
  if handle then
    for filepath in handle:lines() do
      local issues = self:lint_file(filepath)
      for _, issue in ipairs(issues) do
        table.insert(all_issues, issue)
      end
    end
    handle:close()
  end

  return all_issues
end

function Linter:report(issues, format)
  local reporter = Reporters[format or "text"]
  if reporter then
    reporter(issues, {})
  else
    io.stderr:write("Error: Unknown format: " .. (format or "nil") .. "\n")
  end
end

-- Main entry point
local function main()
  local options = {
    config = nil,
    format = "text",
    fix = false,
    quiet = false,
    max_warnings = nil
  }

  local files = {}
  local i = 1

  while i <= #arg do
    local a = arg[i]
    if a == "-h" or a == "--help" then
      print_help()
      os.exit(0)
    elseif a == "-v" or a == "--version" then
      print_version()
      os.exit(0)
    elseif a == "-c" or a == "--config" then
      i = i + 1
      options.config = arg[i]
    elseif a == "-f" or a == "--format" then
      i = i + 1
      options.format = arg[i]
    elseif a == "--fix" then
      options.fix = true
    elseif a == "--quiet" then
      options.quiet = true
    elseif a == "--max-warnings" then
      i = i + 1
      options.max_warnings = tonumber(arg[i])
    elseif not a:match("^%-") then
      table.insert(files, a)
    end
    i = i + 1
  end

  if #files == 0 then
    io.stderr:write("Error: No input files specified\n")
    io.stderr:write("Use --help for usage information\n")
    os.exit(1)
  end

  local linter = Linter.new(options.config)
  local all_issues = {}

  for _, path in ipairs(files) do
    -- Check if directory
    local attr = io.open(path, "r")
    if attr then
      attr:close()
      -- It's a file
      local issues = linter:lint_file(path)
      for _, issue in ipairs(issues) do
        table.insert(all_issues, issue)
      end
    else
      -- Try as directory
      local issues = linter:lint_directory(path)
      for _, issue in ipairs(issues) do
        table.insert(all_issues, issue)
      end
    end
  end

  -- Filter by quiet mode
  if options.quiet then
    local filtered = {}
    for _, issue in ipairs(all_issues) do
      if issue.severity == "error" then
        table.insert(filtered, issue)
      end
    end
    all_issues = filtered
  end

  -- Report issues
  linter:report(all_issues, options.format)

  -- Calculate exit code
  local error_count = 0
  local warning_count = 0

  for _, issue in ipairs(all_issues) do
    if issue.severity == "error" then
      error_count = error_count + 1
    else
      warning_count = warning_count + 1
    end
  end

  if error_count > 0 then
    os.exit(2)
  elseif warning_count > 0 then
    if options.max_warnings and warning_count > options.max_warnings then
      os.exit(2)
    end
    os.exit(1)
  else
    os.exit(0)
  end
end

if arg[0]:match("whisker%-lint") then
  main()
end

return {
  Linter = Linter,
  Rules = Rules,
  Reporters = Reporters,
  ConfigLoader = ConfigLoader,
  StoryParser = StoryParser
}
