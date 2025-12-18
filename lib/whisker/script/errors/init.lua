-- lib/whisker/script/errors/init.lua
-- Whisker Script error reporting module entry point

local codes = require("whisker.script.errors.codes")
local reporter = require("whisker.script.errors.reporter")

local M = {}

-- Re-export error codes
M.Severity = codes.Severity
M.Lexer = codes.Lexer
M.Parser = codes.Parser
M.Semantic = codes.Semantic
M.Generator = codes.Generator
M.Messages = codes.Messages
M.format_message = codes.format_message
M.get_suggestion = codes.get_suggestion
M.get_severity = codes.get_severity

-- Re-export reporter
M.ErrorReporter = reporter.ErrorReporter

--- Create a new error reporter instance
-- @param options table Optional configuration
-- @return ErrorReporter New reporter instance
function M.new(options)
  return reporter.new(options)
end

--- Module metadata
M._whisker = {
  name = "script.errors",
  version = "1.0.0",
  description = "Whisker Script error reporting",
  depends = {
    "script.errors.codes",
    "script.errors.reporter"
  },
  capability = "script.errors"
}

return M
