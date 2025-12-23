#!/usr/bin/env lua
-- whisker-fmt: Code formatter for whisker-core interactive fiction
-- Enforces consistent style across story files

local script_dir = arg[0]:match("(.*/)") or "./"
package.path = script_dir .. "?.lua;" ..
               script_dir .. "lib/?.lua;" ..
               script_dir .. "lib/formatters/?.lua;" ..
               package.path

local function print_help()
  print([[
whisker-fmt - Code Formatter for Whisker Stories

Usage: whisker-fmt [options] <file|directory>...

Options:
  -h, --help           Show this help message
  -v, --version        Show version information
  -c, --config FILE    Use custom config file (default: .whisker-fmt.json)
  --check              Check formatting without modifying files
  --diff               Show diff of changes (implies --check)
  --stdin              Read from stdin, write to stdout
  --write              Write formatted output back to files (default)

Configuration (.whisker-fmt.json):
  indent_style         "space" or "tab" (default: "space")
  indent_size          Number of spaces (default: 2)
  max_line_length      Maximum line length (default: 100)
  normalize_whitespace Trim trailing whitespace (default: true)
  blank_lines_between  Blank lines between passages (default: 1)
  align_choices        Align choice text (default: true)

Examples:
  whisker-fmt story.ink
  whisker-fmt --check src/
  whisker-fmt --diff story.ink
  cat story.ink | whisker-fmt --stdin

Exit Codes:
  0 - Formatting complete (or files already formatted with --check)
  1 - Files would be modified (with --check)
  2 - Error occurred
]])
end

local function print_version()
  print("whisker-fmt 0.1.0")
  print("Code formatter for whisker-core stories")
end

-- Simple JSON decoder
local function decode_json(str)
  local result = {}
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

  return result
end

-- Config loader
local ConfigLoader = {}

function ConfigLoader.load(file_path)
  local default_config = {
    indent_style = "space",
    indent_size = 2,
    max_line_length = 100,
    normalize_whitespace = true,
    blank_lines_between = 1,
    align_choices = true,
    sort_passages = false
  }

  if not file_path then
    file_path = ".whisker-fmt.json"
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

  for k, v in pairs(user_config) do
    default_config[k] = v
  end

  return default_config
end

-- Ink Formatter
local InkFormatter = {}

function InkFormatter.format(content, config)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local formatted = {}
  local in_passage = false
  local last_was_blank = false
  local last_was_passage_header = false

  local indent_char = config.indent_style == "tab" and "\t" or string.rep(" ", config.indent_size)

  for i, line in ipairs(lines) do
    local original_line = line

    -- Normalize whitespace
    if config.normalize_whitespace then
      line = line:gsub("%s+$", "")
    end

    -- Handle passage headers: === Name ===
    local passage_name = line:match("^%s*===+%s*([%w_]+)%s*===+%s*$")
    if passage_name then
      -- Add blank lines before passage (except first)
      if #formatted > 0 and not last_was_blank then
        for _ = 1, config.blank_lines_between do
          table.insert(formatted, "")
        end
      end

      -- Format header consistently
      table.insert(formatted, "=== " .. passage_name .. " ===")
      in_passage = true
      last_was_blank = false
      last_was_passage_header = true
    -- Handle choices: * [text] -> target or + [text] -> target
    elseif line:match("^%s*[%*%+]") then
      local indent, marker, rest = line:match("^(%s*)([%*%+])%s*(.*)$")

      -- Normalize indent level
      local indent_level = 0
      if indent then
        indent_level = math.floor(#indent / config.indent_size)
      end
      local new_indent = string.rep(indent_char, indent_level)

      -- Parse choice parts
      local bracket_text = rest:match("^%[([^%]]+)%]")
      local after_bracket = rest:match("^%[[^%]]+%]%s*(.*)$") or ""
      local target = after_bracket:match("->%s*([%w_]+)")
      local inline_text = rest:match("^([^%[%->]+)")

      if bracket_text then
        if target then
          table.insert(formatted, new_indent .. marker .. " [" .. bracket_text:gsub("^%s*", ""):gsub("%s*$", "") .. "] -> " .. target)
        else
          table.insert(formatted, new_indent .. marker .. " [" .. bracket_text:gsub("^%s*", ""):gsub("%s*$", "") .. "]")
        end
      elseif inline_text then
        inline_text = inline_text:gsub("^%s*", ""):gsub("%s*$", "")
        table.insert(formatted, new_indent .. marker .. " " .. inline_text)
      else
        table.insert(formatted, new_indent .. marker .. " " .. rest)
      end

      last_was_blank = false
      last_was_passage_header = false
    -- Handle diverts: -> target
    elseif line:match("^%s*->") then
      local indent, target = line:match("^(%s*)%->%s*([%w_]+)")
      if target then
        local indent_level = 0
        if indent then
          indent_level = math.floor(#indent / config.indent_size)
        end
        local new_indent = string.rep(indent_char, indent_level)
        table.insert(formatted, new_indent .. "-> " .. target)
      else
        table.insert(formatted, line)
      end
      last_was_blank = false
      last_was_passage_header = false
    -- Handle variable assignments: ~ var = value
    elseif line:match("^%s*~") then
      local var, op, value = line:match("^%s*~%s*([%w_]+)%s*([%+%-]?=)%s*(.+)$")
      if var then
        table.insert(formatted, "~ " .. var .. " " .. op .. " " .. value:gsub("%s*$", ""))
      else
        table.insert(formatted, line)
      end
      last_was_blank = false
      last_was_passage_header = false
    -- Handle comments: // comment
    elseif line:match("^%s*//") then
      local comment = line:match("^%s*//%s*(.*)$")
      if comment then
        table.insert(formatted, "// " .. comment:gsub("%s*$", ""))
      else
        table.insert(formatted, line)
      end
      last_was_blank = false
      last_was_passage_header = false
    -- Handle blank lines
    elseif line:match("^%s*$") then
      -- Only add one blank line, unless after passage header
      if not last_was_blank and not last_was_passage_header then
        table.insert(formatted, "")
      end
      last_was_blank = true
      last_was_passage_header = false
    -- Regular content
    else
      table.insert(formatted, line)
      last_was_blank = false
      last_was_passage_header = false
    end
  end

  -- Remove trailing blank lines
  while #formatted > 0 and formatted[#formatted]:match("^%s*$") do
    table.remove(formatted)
  end

  -- Ensure final newline
  return table.concat(formatted, "\n") .. "\n"
end

-- Twee Formatter
local TweeFormatter = {}

function TweeFormatter.format(content, config)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local formatted = {}
  local last_was_blank = false
  local last_was_passage_header = false

  for i, line in ipairs(lines) do
    -- Normalize whitespace
    if config.normalize_whitespace then
      line = line:gsub("%s+$", "")
    end

    -- Handle passage headers: :: Name [tags]
    local passage_part = line:match("^::%s*(.+)$")
    if passage_part then
      -- Add blank lines before passage (except first)
      if #formatted > 0 and not last_was_blank then
        for _ = 1, config.blank_lines_between do
          table.insert(formatted, "")
        end
      end

      -- Check for tags in square brackets
      local name_part, tags = passage_part:match("^(.-)%s*(%[.+%])%s*$")
      if not name_part then
        name_part = passage_part
        tags = nil
      end
      name_part = name_part:gsub("^%s*", ""):gsub("%s*$", "")

      if tags then
        table.insert(formatted, ":: " .. name_part .. " " .. tags)
      else
        table.insert(formatted, ":: " .. name_part)
      end

      last_was_blank = false
      last_was_passage_header = true
    -- Handle links: [[text|target]] or [[target]]
    elseif line:match("%[%[") then
      local formatted_line = line
      -- Normalize link spacing - capture and trim each part
      formatted_line = formatted_line:gsub("%[%[%s*(.-)%s*|%s*(.-)%s*%]%]", function(text, target)
        return "[[" .. text:gsub("^%s*", ""):gsub("%s*$", "") .. "|" .. target:gsub("^%s*", ""):gsub("%s*$", "") .. "]]"
      end)
      -- For links without pipe
      formatted_line = formatted_line:gsub("%[%[%s*([^%]|]-)%s*%]%]", function(target)
        return "[[" .. target:gsub("^%s*", ""):gsub("%s*$", "") .. "]]"
      end)
      table.insert(formatted, formatted_line)
      last_was_blank = false
      last_was_passage_header = false
    -- Handle blank lines
    elseif line:match("^%s*$") then
      if not last_was_blank and not last_was_passage_header then
        table.insert(formatted, "")
      end
      last_was_blank = true
      last_was_passage_header = false
    else
      table.insert(formatted, line)
      last_was_blank = false
      last_was_passage_header = false
    end
  end

  -- Remove trailing blank lines
  while #formatted > 0 and formatted[#formatted]:match("^%s*$") do
    table.remove(formatted)
  end

  return table.concat(formatted, "\n") .. "\n"
end

-- WhiskerScript Formatter
local WScriptFormatter = {}

function WScriptFormatter.format(content, config)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local formatted = {}
  local indent_level = 0
  local indent_char = config.indent_style == "tab" and "\t" or string.rep(" ", config.indent_size)
  local last_was_blank = false

  for i, line in ipairs(lines) do
    -- Normalize whitespace
    if config.normalize_whitespace then
      line = line:gsub("%s+$", "")
    end

    local trimmed = line:gsub("^%s*", "")

    -- Decrease indent for closing braces
    if trimmed:match("^}") then
      indent_level = math.max(0, indent_level - 1)
    end

    -- Handle passage declarations: passage "Name" {
    local passage_name = trimmed:match('^passage%s+"([^"]+)"')
    if passage_name then
      if #formatted > 0 and not last_was_blank then
        for _ = 1, config.blank_lines_between do
          table.insert(formatted, "")
        end
      end
      table.insert(formatted, 'passage "' .. passage_name .. '" {')
      indent_level = 1
      last_was_blank = false
    -- Handle blank lines
    elseif trimmed == "" then
      if not last_was_blank then
        table.insert(formatted, "")
      end
      last_was_blank = true
    -- Handle closing brace
    elseif trimmed == "}" then
      table.insert(formatted, string.rep(indent_char, indent_level) .. "}")
      last_was_blank = false
    -- Regular content
    else
      local current_indent = string.rep(indent_char, indent_level)
      table.insert(formatted, current_indent .. trimmed)
      last_was_blank = false

      -- Increase indent after opening brace
      if trimmed:match("{%s*$") then
        indent_level = indent_level + 1
      end
    end
  end

  -- Remove trailing blank lines
  while #formatted > 0 and formatted[#formatted]:match("^%s*$") do
    table.remove(formatted)
  end

  return table.concat(formatted, "\n") .. "\n"
end

-- Main Formatter
local Formatter = {}
Formatter.__index = Formatter

function Formatter.new(config_file)
  local self = setmetatable({}, Formatter)
  self.config = ConfigLoader.load(config_file)
  self.formatters = {
    ink = InkFormatter,
    twee = TweeFormatter,
    tw = TweeFormatter,
    wscript = WScriptFormatter
  }
  return self
end

function Formatter:format_content(content, format)
  local formatter = self.formatters[format]
  if not formatter then
    return nil, "Unsupported format: " .. format
  end
  return formatter.format(content, self.config)
end

function Formatter:format_file(filepath, options)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Cannot open file: " .. filepath
  end

  local content = file:read("*a")
  file:close()

  local ext = filepath:match("%.([^%.]+)$")
  local formatted, err = self:format_content(content, ext)

  if not formatted then
    return nil, err
  end

  if options.check or options.diff then
    local changed = formatted ~= content
    if options.diff and changed then
      -- Simple diff output
      io.stderr:write("--- " .. filepath .. " (original)\n")
      io.stderr:write("+++ " .. filepath .. " (formatted)\n")
      -- Just indicate changed
      io.stderr:write("File would be modified\n")
    end
    return changed, nil
  else
    -- Write back
    local out = io.open(filepath, "w")
    if not out then
      return nil, "Cannot write to file: " .. filepath
    end
    out:write(formatted)
    out:close()
    return true, nil
  end
end

function Formatter:format_stdin(format)
  local content = io.read("*a")
  local formatted, err = self:format_content(content, format or "ink")
  if formatted then
    io.write(formatted)
    return true
  else
    io.stderr:write("Error: " .. err .. "\n")
    return false
  end
end

-- Main entry point
local function main()
  local options = {
    config = nil,
    check = false,
    diff = false,
    stdin = false,
    stdin_format = "ink"
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
    elseif a == "--check" then
      options.check = true
    elseif a == "--diff" then
      options.diff = true
      options.check = true
    elseif a == "--stdin" then
      options.stdin = true
    elseif a == "--stdin-format" then
      i = i + 1
      options.stdin_format = arg[i]
    elseif a == "--write" then
      options.check = false
      options.diff = false
    elseif not a:match("^%-") then
      table.insert(files, a)
    end
    i = i + 1
  end

  local formatter = Formatter.new(options.config)

  if options.stdin then
    local ok = formatter:format_stdin(options.stdin_format)
    os.exit(ok and 0 or 2)
  end

  if #files == 0 then
    io.stderr:write("Error: No input files specified\n")
    io.stderr:write("Use --help for usage information\n")
    os.exit(2)
  end

  local any_changed = false
  local any_error = false

  for _, path in ipairs(files) do
    -- Check if it's a file
    local file = io.open(path, "r")
    if file then
      file:close()
      local result, err = formatter:format_file(path, options)
      if err then
        io.stderr:write("Error: " .. err .. "\n")
        any_error = true
      elseif result then
        any_changed = true
        if not options.check then
          print("Formatted: " .. path)
        else
          print("Would reformat: " .. path)
        end
      else
        if not options.check then
          print("Unchanged: " .. path)
        end
      end
    else
      -- Try as directory
      local handle = io.popen('find "' .. path .. '" -type f \\( -name "*.ink" -o -name "*.twee" -o -name "*.tw" -o -name "*.wscript" \\) 2>/dev/null')
      if handle then
        for filepath in handle:lines() do
          local result, err = formatter:format_file(filepath, options)
          if err then
            io.stderr:write("Error: " .. err .. "\n")
            any_error = true
          elseif result then
            any_changed = true
            if not options.check then
              print("Formatted: " .. filepath)
            else
              print("Would reformat: " .. filepath)
            end
          end
        end
        handle:close()
      end
    end
  end

  if any_error then
    os.exit(2)
  elseif options.check and any_changed then
    os.exit(1)
  else
    os.exit(0)
  end
end

if arg[0]:match("whisker%-fmt") then
  main()
end

return {
  Formatter = Formatter,
  ConfigLoader = ConfigLoader,
  InkFormatter = InkFormatter,
  TweeFormatter = TweeFormatter,
  WScriptFormatter = WScriptFormatter
}
