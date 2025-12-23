-- whisker-lsp/lib/providers/diagnostics.lua
-- Diagnostics provider for error/warning reporting

local interfaces = require("lib.interfaces")

local DiagnosticsProvider = {}
DiagnosticsProvider.__index = DiagnosticsProvider

--- Create a new diagnostics provider
--- @param document_manager table DocumentManager instance
--- @param parser_integration table ParserIntegration instance
--- @return table DiagnosticsProvider instance
function DiagnosticsProvider.new(document_manager, parser_integration)
  local self = setmetatable({}, DiagnosticsProvider)
  self.document_manager = document_manager
  self.parser = parser_integration
  return self
end

--- Get diagnostics for a document
--- @param uri string Document URI
--- @return table Array of diagnostics
function DiagnosticsProvider:get_diagnostics(uri)
  local diagnostics = {}

  local text = self.document_manager:get_text(uri)
  if not text then
    return diagnostics
  end

  -- Parse the document
  local result = self.parser:parse(uri, text)

  -- Convert parser errors to diagnostics
  for _, err in ipairs(result.errors) do
    diagnostics[#diagnostics + 1] = self:create_diagnostic(
      err,
      interfaces.DiagnosticSeverity.Error
    )
  end

  -- Convert parser warnings to diagnostics
  for _, warn in ipairs(result.warnings) do
    diagnostics[#diagnostics + 1] = self:create_diagnostic(
      warn,
      interfaces.DiagnosticSeverity.Warning
    )
  end

  -- Check for undefined passage references
  local undefined = self:check_undefined_passages(uri, text, result.passages)
  for _, diag in ipairs(undefined) do
    diagnostics[#diagnostics + 1] = diag
  end

  -- Check for unreachable passages
  local unreachable = self:check_unreachable_passages(uri, text, result.passages)
  for _, diag in ipairs(unreachable) do
    diagnostics[#diagnostics + 1] = diag
  end

  -- Check for undefined variables
  local undefined_vars = self:check_undefined_variables(uri, text, result.variables)
  for _, diag in ipairs(undefined_vars) do
    diagnostics[#diagnostics + 1] = diag
  end

  return diagnostics
end

--- Create a diagnostic from error/warning
--- @param item table Error or warning item
--- @param severity number DiagnosticSeverity
--- @return table Diagnostic
function DiagnosticsProvider:create_diagnostic(item, severity)
  local line = item.line or 0
  local column = item.column or 0
  local end_column = item.end_column or (column + 1)

  return {
    range = {
      start = { line = line, character = column },
      ["end"] = { line = line, character = end_column }
    },
    severity = severity,
    source = "whisker-lsp",
    message = item.message or tostring(item)
  }
end

--- Check for undefined passage references
--- @param uri string Document URI
--- @param text string Document text
--- @param passages table Known passages
--- @return table Array of diagnostics
function DiagnosticsProvider:check_undefined_passages(uri, text, passages)
  local diagnostics = {}

  -- Build set of known passage names
  local known = {}
  for _, passage in ipairs(passages) do
    known[passage.name] = true
  end

  -- Add special passages
  known["END"] = true
  known["DONE"] = true
  known["START"] = true

  -- Find all passage references
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  for i, line in ipairs(lines) do
    -- Find divert references
    for target, col_start in line:gmatch("->%s*([%w_]+)()") do
      if not known[target] then
        local start_col = line:find("->%s*" .. target) or 0
        diagnostics[#diagnostics + 1] = {
          range = {
            start = { line = i - 1, character = start_col - 1 + 3 },  -- Skip "-> "
            ["end"] = { line = i - 1, character = start_col - 1 + 3 + #target }
          },
          severity = interfaces.DiagnosticSeverity.Error,
          source = "whisker-lsp",
          message = string.format("Undefined passage: '%s'", target),
          code = "undefined-passage"
        }
      end
    end

    -- Find choice targets
    for target in line:gmatch("%[.-%]%s*->%s*([%w_]+)") do
      if not known[target] then
        local start_col = line:find(target) or 0
        diagnostics[#diagnostics + 1] = {
          range = {
            start = { line = i - 1, character = start_col - 1 },
            ["end"] = { line = i - 1, character = start_col - 1 + #target }
          },
          severity = interfaces.DiagnosticSeverity.Error,
          source = "whisker-lsp",
          message = string.format("Undefined passage: '%s'", target),
          code = "undefined-passage"
        }
      end
    end
  end

  return diagnostics
end

--- Check for unreachable passages
--- @param uri string Document URI
--- @param text string Document text
--- @param passages table Known passages
--- @return table Array of diagnostics
function DiagnosticsProvider:check_unreachable_passages(uri, text, passages)
  local diagnostics = {}

  if #passages < 2 then
    return diagnostics
  end

  -- Build reachability graph
  local referenced = {}

  -- Find all references
  for target in text:gmatch("->%s*([%w_]+)") do
    referenced[target] = true
  end

  -- The first passage is always reachable (entry point)
  local first_passage = passages[1]
  if first_passage then
    referenced[first_passage.name] = true
  end

  -- START is always reachable
  referenced["START"] = true

  -- Check each passage
  for _, passage in ipairs(passages) do
    if not referenced[passage.name] and passage.name ~= "START" then
      diagnostics[#diagnostics + 1] = {
        range = {
          start = { line = passage.line, character = 0 },
          ["end"] = { line = passage.line, character = #passage.name + 6 }  -- "=== Name ==="
        },
        severity = interfaces.DiagnosticSeverity.Warning,
        source = "whisker-lsp",
        message = string.format("Passage '%s' is unreachable", passage.name),
        code = "unreachable-passage"
      }
    end
  end

  return diagnostics
end

--- Check for undefined variable references
--- @param uri string Document URI
--- @param text string Document text
--- @param variables table Known variables
--- @return table Array of diagnostics
function DiagnosticsProvider:check_undefined_variables(uri, text, variables)
  local diagnostics = {}

  -- Build set of known variable names
  local known = {}
  for _, var in ipairs(variables) do
    known[var.name] = true
  end

  -- Find all variable references in {}
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  for i, line in ipairs(lines) do
    -- Find variable references {varname}
    for var_name in line:gmatch("{([%w_]+)}") do
      if not known[var_name] then
        local start_col = line:find("{" .. var_name .. "}") or 0
        diagnostics[#diagnostics + 1] = {
          range = {
            start = { line = i - 1, character = start_col },
            ["end"] = { line = i - 1, character = start_col + #var_name }
          },
          severity = interfaces.DiagnosticSeverity.Warning,
          source = "whisker-lsp",
          message = string.format("Undefined variable: '%s'", var_name),
          code = "undefined-variable"
        }
      end
    end
  end

  return diagnostics
end

--- Check if format is supported
--- @param format string File format
--- @return boolean
function DiagnosticsProvider:supports_format(format)
  return format == "ink" or format == "wscript" or format == "twee" or format == "whisker"
end

return DiagnosticsProvider
