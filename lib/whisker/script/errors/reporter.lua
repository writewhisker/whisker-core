-- lib/whisker/script/errors/reporter.lua
-- Error reporting and formatting for Whisker Script compiler

local source_module = require("whisker.script.source")
local SourceFile = source_module.SourceFile
local SourceSpan = source_module.SourceSpan

local codes = require("whisker.script.errors.codes")

local M = {}

-- ============================================
-- ErrorReporter Class
-- ============================================

local ErrorReporter = {}
ErrorReporter.__index = ErrorReporter

--- Create a new error reporter
-- @param options table Optional configuration
-- @return ErrorReporter
function ErrorReporter.new(options)
  options = options or {}
  return setmetatable({
    _format = options.format or "text",
    _color = options.color ~= false, -- Enable colors by default
    _source_file = nil,
    _source = nil,
  }, ErrorReporter)
end

--- Set the source code for context
-- @param source string Source code
-- @param file_path string Optional file path
function ErrorReporter:set_source(source, file_path)
  self._source = source
  self._source_file = SourceFile.new(file_path or "<input>", source)
end

--- Set output format
-- @param format string "text", "json", or "annotated"
function ErrorReporter:set_format(format)
  assert(format == "text" or format == "json" or format == "annotated",
    "Invalid format: " .. tostring(format))
  self._format = format
end

--- Enable or disable colors
-- @param enabled boolean
function ErrorReporter:set_color(enabled)
  self._color = enabled
end

-- ============================================
-- Formatting Methods
-- ============================================

--- Get ANSI color code
-- @param name string Color name
-- @return string ANSI escape sequence
local function color(name, enabled)
  if not enabled then return "" end
  local colors = {
    reset = "\27[0m",
    bold = "\27[1m",
    red = "\27[31m",
    yellow = "\27[33m",
    blue = "\27[34m",
    cyan = "\27[36m",
    gray = "\27[90m",
  }
  return colors[name] or ""
end

--- Format severity with optional color
-- @param severity string Severity level
-- @param use_color boolean Whether to use colors
-- @return string Formatted severity
local function format_severity(severity, use_color)
  local c = function(name) return color(name, use_color) end

  if severity == codes.Severity.ERROR then
    return c("bold") .. c("red") .. "error" .. c("reset")
  elseif severity == codes.Severity.WARNING then
    return c("bold") .. c("yellow") .. "warning" .. c("reset")
  elseif severity == codes.Severity.HINT then
    return c("bold") .. c("cyan") .. "hint" .. c("reset")
  else
    return severity
  end
end

--- Format a single diagnostic in text format
-- @param diagnostic table Diagnostic object
-- @return string Formatted text
function ErrorReporter:_format_text(diagnostic)
  local lines = {}
  local c = function(name) return color(name, self._color) end

  -- Header: error[WSK0001]: Message
  local severity_str = format_severity(diagnostic.severity or codes.Severity.ERROR, self._color)
  local code_str = diagnostic.code and ("[" .. diagnostic.code .. "]") or ""
  local message = diagnostic.message or "Unknown error"

  table.insert(lines, string.format("%s%s%s: %s%s%s",
    severity_str, c("bold"), code_str, c("reset"), c("bold"), message))
  table.insert(lines, c("reset"))

  -- Source snippet
  if self._source_file and diagnostic.position then
    local pos = diagnostic.position
    local span = SourceSpan.new(pos, pos)

    -- If we have a lexeme/token length, extend the span
    if diagnostic.length then
      local end_pos = source_module.SourcePosition.new(
        pos.line,
        pos.column + diagnostic.length,
        pos.offset + diagnostic.length
      )
      span = SourceSpan.new(pos, end_pos)
    end

    local snippet = source_module.format_source_snippet(
      self._source_file,
      span,
      ""  -- No inline message in snippet
    )
    table.insert(lines, snippet)
  elseif diagnostic.position then
    -- No source file, just show position
    table.insert(lines, string.format("  --> %s:%d:%d",
      diagnostic.file_path or "<input>",
      diagnostic.position.line,
      diagnostic.position.column))
  end

  -- Suggestion
  if diagnostic.suggestion then
    table.insert(lines, "")
    table.insert(lines, string.format("   %s=%s help: %s%s",
      c("cyan"), c("reset"), diagnostic.suggestion, c("reset")))
  end

  return table.concat(lines, "\n")
end

--- Format a single diagnostic in JSON format
-- @param diagnostic table Diagnostic object
-- @return string JSON string
function ErrorReporter:_format_json(diagnostic)
  local obj = {
    code = diagnostic.code,
    message = diagnostic.message,
    severity = diagnostic.severity or codes.Severity.ERROR,
  }

  if diagnostic.position then
    obj.location = {
      line = diagnostic.position.line,
      column = diagnostic.position.column,
      file = diagnostic.file_path or "<input>",
    }
  end

  if diagnostic.suggestion then
    obj.suggestion = diagnostic.suggestion
  end

  -- Simple JSON encoding (no external dependency)
  local function escape_string(s)
    return s:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\t', '\\t')
            :gsub('\r', '\\r')
  end

  local parts = {}
  for k, v in pairs(obj) do
    local value_str
    if type(v) == "string" then
      value_str = '"' .. escape_string(v) .. '"'
    elseif type(v) == "number" then
      value_str = tostring(v)
    elseif type(v) == "table" then
      -- Nested object (simple case for location)
      local nested_parts = {}
      for nk, nv in pairs(v) do
        local nv_str = type(nv) == "string" and ('"' .. escape_string(nv) .. '"') or tostring(nv)
        table.insert(nested_parts, '"' .. nk .. '":' .. nv_str)
      end
      value_str = "{" .. table.concat(nested_parts, ",") .. "}"
    else
      value_str = tostring(v)
    end
    table.insert(parts, '"' .. k .. '":' .. value_str)
  end

  return "{" .. table.concat(parts, ",") .. "}"
end

--- Format a single diagnostic in annotated format
-- Shows source code with inline annotations
-- @param diagnostic table Diagnostic object
-- @return string Formatted text
function ErrorReporter:_format_annotated(diagnostic)
  if not self._source_file or not diagnostic.position then
    return self:_format_text(diagnostic)
  end

  local lines = {}
  local c = function(name) return color(name, self._color) end
  local pos = diagnostic.position

  -- Get context (2 lines before and after)
  local context = self._source_file:get_context(pos, 2)

  -- Gutter width
  local max_line = context[#context] and context[#context].line_number or pos.line
  local gutter_width = #tostring(max_line) + 1

  -- Header
  local severity_str = format_severity(diagnostic.severity or codes.Severity.ERROR, self._color)
  table.insert(lines, string.format("%s[%s]: %s",
    severity_str, diagnostic.code or "????", diagnostic.message or "Unknown error"))

  -- Location
  table.insert(lines, string.format("  --> %s:%d:%d",
    self._source_file.path, pos.line, pos.column))

  -- Empty line
  table.insert(lines, string.rep(" ", gutter_width) .. c("blue") .. " |" .. c("reset"))

  -- Context lines
  for _, ctx in ipairs(context) do
    local line_num = ctx.line_number
    local content = ctx.content

    -- Line with gutter
    local gutter = string.format("%" .. gutter_width .. "d", line_num)
    table.insert(lines, c("blue") .. gutter .. " |" .. c("reset") .. " " .. content)

    -- Underline for error line
    if line_num == pos.line then
      local underline_col = pos.column
      local underline_len = diagnostic.length or 1
      local spacing = string.rep(" ", underline_col - 1)
      local carets = c("red") .. string.rep("^", underline_len) .. c("reset")

      table.insert(lines, string.rep(" ", gutter_width) .. c("blue") .. " |" .. c("reset") .. " " .. spacing .. carets)
    end
  end

  -- Suggestion
  if diagnostic.suggestion then
    table.insert(lines, string.rep(" ", gutter_width) .. c("blue") .. " |" .. c("reset"))
    table.insert(lines, string.rep(" ", gutter_width) .. c("blue") .. " = " .. c("cyan") .. "help: " .. c("reset") .. diagnostic.suggestion)
  end

  return table.concat(lines, "\n")
end

--- Format a single diagnostic
-- @param diagnostic table Diagnostic object
-- @return string Formatted diagnostic
function ErrorReporter:format(diagnostic)
  if self._format == "json" then
    return self:_format_json(diagnostic)
  elseif self._format == "annotated" then
    return self:_format_annotated(diagnostic)
  else
    return self:_format_text(diagnostic)
  end
end

--- Report a single diagnostic
-- @param diagnostic table Diagnostic object
function ErrorReporter:report(diagnostic)
  io.stderr:write(self:format(diagnostic) .. "\n\n")
end

--- Report multiple diagnostics
-- @param diagnostics table Array of diagnostic objects
function ErrorReporter:report_all(diagnostics)
  for _, diag in ipairs(diagnostics) do
    self:report(diag)
  end

  -- Summary
  if #diagnostics > 0 then
    local errors = 0
    local warnings = 0
    for _, d in ipairs(diagnostics) do
      if d.severity == codes.Severity.ERROR then
        errors = errors + 1
      elseif d.severity == codes.Severity.WARNING then
        warnings = warnings + 1
      end
    end

    local c = function(name) return color(name, self._color) end
    local summary_parts = {}

    if errors > 0 then
      table.insert(summary_parts, c("bold") .. c("red") .. errors .. " error" .. (errors > 1 and "s" or "") .. c("reset"))
    end
    if warnings > 0 then
      table.insert(summary_parts, c("bold") .. c("yellow") .. warnings .. " warning" .. (warnings > 1 and "s" or "") .. c("reset"))
    end

    if #summary_parts > 0 then
      io.stderr:write(table.concat(summary_parts, ", ") .. " generated\n")
    end
  end
end

--- Format all diagnostics as a single string
-- @param diagnostics table Array of diagnostic objects
-- @return string All diagnostics formatted
function ErrorReporter:format_all(diagnostics)
  if self._format == "json" then
    -- Return JSON array
    local json_parts = {}
    for _, diag in ipairs(diagnostics) do
      table.insert(json_parts, self:_format_json(diag))
    end
    return "[" .. table.concat(json_parts, ",") .. "]"
  else
    local parts = {}
    for _, diag in ipairs(diagnostics) do
      table.insert(parts, self:format(diag))
    end
    return table.concat(parts, "\n\n")
  end
end

M.ErrorReporter = ErrorReporter

--- Factory function
-- @param options table Optional configuration
-- @return ErrorReporter
function M.new(options)
  return ErrorReporter.new(options)
end

--- Module metadata
M._whisker = {
  name = "script.errors.reporter",
  version = "1.0.0",
  description = "Error reporting and formatting for Whisker Script",
  depends = {
    "script.source",
    "script.errors.codes"
  },
  capability = "script.errors.reporter"
}

return M
