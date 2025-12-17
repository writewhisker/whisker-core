-- lib/whisker/script/errors/init.lua
-- Whisker Script error reporting module entry point

local M = {}

--- Report a single error
-- @param error table CompileError object
function M:report(error)
  -- Default: print to stderr
  io.stderr:write(self:format(error, "") .. "\n")
end

--- Report multiple errors
-- @param errors table Array of CompileError objects
function M:report_all(errors)
  for _, err in ipairs(errors) do
    self:report(err)
  end
end

--- Format error with source context
-- @param error table CompileError object
-- @param source string Source code for context
-- @return string Formatted error message
function M:format(error, source)
  error("whisker.script.errors:format() not implemented")
end

--- Set output format
-- @param format string "text", "json", or "annotated"
function M:set_format(format)
  error("whisker.script.errors:set_format() not implemented")
end

--- Create a new error reporter instance
-- @return table New reporter instance
function M.new()
  local instance = setmetatable({}, { __index = M })
  return instance
end

--- Module metadata
M._whisker = {
  name = "script.errors",
  version = "0.1.0",
  description = "Whisker Script error reporting",
  depends = {},
  capability = "script.errors"
}

return M
