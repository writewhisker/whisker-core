-- lib/whisker/script/format.lua
-- IFormat implementation for Whisker Script

local M = {}

-- ============================================
-- WhiskerScriptFormat Class
-- ============================================

local WhiskerScriptFormat = {}
WhiskerScriptFormat.__index = WhiskerScriptFormat

-- Module metadata for container auto-registration
WhiskerScriptFormat._whisker = {
  name = "WhiskerScriptFormat",
  version = "1.0.0",
  description = "Whisker Script format handler implementing IFormat",
  depends = {},
  implements = "IFormat",
  capability = "format.whisker"
}

-- Format metadata (IFormat optional fields)
WhiskerScriptFormat.name = "whisker"
WhiskerScriptFormat.version = "1.0.0"
WhiskerScriptFormat.extensions = { ".wsk" }

--- Create a new WhiskerScriptFormat instance
-- @param options table|nil Optional configuration
-- @return WhiskerScriptFormat
function WhiskerScriptFormat.new(options)
  options = options or {}
  local instance = {
    _event_emitter = options.event_emitter,
    _compiler = nil, -- Lazy loaded
  }
  setmetatable(instance, WhiskerScriptFormat)
  return instance
end

--- Get or create compiler instance
-- @return Compiler
function WhiskerScriptFormat:_get_compiler()
  if not self._compiler then
    local script_module = require("whisker.script")
    self._compiler = script_module.Compiler.new()
  end
  return self._compiler
end

--- Check if this format can import the given source
-- Detects Whisker Script syntax by looking for characteristic patterns
-- @param source string|table Source data to check
-- @return boolean True if format can handle this source
function WhiskerScriptFormat:can_import(source)
  if source == nil then
    return false
  end

  -- Only handle string sources
  if type(source) ~= "string" then
    return false
  end

  -- If it's a file path ending in .wsk, check file exists
  if source:match("%.wsk$") then
    local file = io.open(source, "r")
    if file then
      file:close()
      return true
    end
  end

  -- Check for characteristic Whisker Script syntax patterns
  -- Passage declaration: ::
  if source:match("^%s*::") or source:match("\n%s*::") then
    return true
  end

  -- Metadata declaration: @@
  if source:match("^%s*@@") or source:match("\n%s*@@") then
    return true
  end

  -- Choice markers at line start: +
  if source:match("^%s*%+%s*%[") or source:match("\n%s*%+%s*%[") then
    return true
  end

  -- Variable assignment: ~
  if source:match("^%s*~") or source:match("\n%s*~") then
    return true
  end

  return false
end

--- Import Whisker Script source into a Story object
-- @param source string Source data to import (path or content)
-- @return Story Parsed story object
function WhiskerScriptFormat:import(source)
  if source == nil then
    error("Source cannot be nil")
  end

  local content = source

  -- If source is a file path, read the file
  if type(source) == "string" and source:match("%.wsk$") then
    local file = io.open(source, "r")
    if file then
      content = file:read("*a")
      file:close()
    end
  end

  -- Compile the source
  local compiler = self:_get_compiler()
  local result = compiler:compile(content)

  -- Emit event if emitter available
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit("whisker.script.imported", {
      format = "whisker",
      diagnostics_count = result.diagnostics and #result.diagnostics or 0
    })
  end

  -- Check for errors
  if result.diagnostics then
    local errors = {}
    for _, diag in ipairs(result.diagnostics) do
      if diag.severity == "error" then
        table.insert(errors, diag)
      end
    end
    if #errors > 0 then
      error(self:_format_errors(errors))
    end
  end

  return result.story
end

--- Format error diagnostics into a readable message
-- @param errors table Array of error diagnostics
-- @return string Formatted error message
function WhiskerScriptFormat:_format_errors(errors)
  local lines = { "Whisker Script compilation failed:" }
  for _, err in ipairs(errors) do
    local pos_str = ""
    if err.position then
      pos_str = string.format(" at line %d, column %d",
        err.position.line or 0,
        err.position.column or 0)
    end
    table.insert(lines, string.format("  [%s]%s: %s",
      err.code or "ERROR",
      pos_str,
      err.message or "Unknown error"))
    if err.suggestion then
      table.insert(lines, string.format("    hint: %s", err.suggestion))
    end
  end
  return table.concat(lines, "\n")
end

--- Check if this format can export the given story
-- @param story Story Story to check
-- @return boolean True if format can export this story
function WhiskerScriptFormat:can_export(story)
  if type(story) ~= "table" then
    return false
  end

  -- Check for basic Story structure
  -- Must have passages (as array or table)
  if story.passages then
    return true
  end

  -- Check for get_passages method
  if type(story.get_passages) == "function" then
    return true
  end

  -- Check for get_all_passages method
  if type(story.get_all_passages) == "function" then
    return true
  end

  return false
end

--- Export Story to Whisker Script source
-- @param story Story Story to export
-- @return string Whisker Script source code
function WhiskerScriptFormat:export(story)
  local writer_module = require("whisker.script.writer")
  local writer = writer_module.Writer.new()
  local source = writer:write(story)

  -- Emit event if emitter available
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit("whisker.script.exported", {
      format = "whisker",
      length = #source
    })
  end

  return source
end

--- Set event emitter for notifications
-- @param emitter table Event emitter with emit method
function WhiskerScriptFormat:set_event_emitter(emitter)
  self._event_emitter = emitter
end

M.WhiskerScriptFormat = WhiskerScriptFormat

--- Module metadata
M._whisker = {
  name = "script.format",
  version = "1.0.0",
  description = "IFormat implementation for Whisker Script",
  depends = { "script" },
  capability = "script.format"
}

return M
