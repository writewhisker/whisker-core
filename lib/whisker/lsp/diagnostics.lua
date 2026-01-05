--- LSP Diagnostics Provider
-- Provides validation and error reporting for WLS documents
-- @module whisker.lsp.diagnostics
-- @author Whisker Core Team
-- @license MIT

local Diagnostics = {}
Diagnostics.__index = Diagnostics
Diagnostics._dependencies = {}

--- Diagnostic severity levels
local DiagnosticSeverity = {
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  HINT = 4,
}

--- Create a new diagnostics provider
-- @param options table Options with documents manager
-- @return Diagnostics Provider instance
function Diagnostics.new(options)
  options = options or {}
  local self = setmetatable({}, Diagnostics)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Diagnostics:set_parser(parser)
  self._parser = parser
end

--- Validate document and return diagnostics
-- @param uri string Document URI
-- @return table Array of diagnostics
function Diagnostics:validate(uri)
  local diagnostics = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return diagnostics end

  -- Collect passage names for link validation
  local passage_names = {}
  for i, line in ipairs(lines) do
    local header = line:match("^::%s*(.+)$")
    if header then
      local name = header:match("^([^%[%]]+)")
      if name then
        passage_names[name:match("^%s*(.-)%s*$")] = i
      end
    end
  end

  -- Validate each line
  for i, line in ipairs(lines) do
    -- Check for broken links (-> target)
    self:_check_broken_links(line, i, passage_names, diagnostics)

    -- Check for unclosed braces
    self:_check_brace_balance(line, i, diagnostics)

    -- Check for duplicate passage declarations
    self:_check_duplicate_passages(line, i, lines, diagnostics)

    -- Check for undefined variables
    self:_check_undefined_variables(line, i, lines, diagnostics)
  end

  return diagnostics
end

--- Check for broken links in a line
-- @param line string Line content
-- @param line_num number Line number (1-based)
-- @param passage_names table Set of valid passage names
-- @param diagnostics table Diagnostics array to append to
function Diagnostics:_check_broken_links(line, line_num, passage_names, diagnostics)
  -- Special targets that are always valid
  local special_targets = { END = true, BACK = true, RESTART = true }

  -- Check -> links
  for target in line:gmatch("->%s*([%w_]+)") do
    if not passage_names[target] and not special_targets[target] then
      local start_pos = line:find("->%s*" .. target, 1) or 0
      local name_pos = line:find(target, start_pos, true) or start_pos
      table.insert(diagnostics, {
        range = {
          start = { line = line_num - 1, character = name_pos - 1 },
          ["end"] = { line = line_num - 1, character = name_pos - 1 + #target },
        },
        severity = DiagnosticSeverity.ERROR,
        source = "whisker-lsp",
        message = "Broken link: passage '" .. target .. "' not found",
      })
    end
  end

  -- Check [[link]] style links
  for link_content in line:gmatch("%[%[(.-)%]%]") do
    -- Extract target from various link formats
    local target = link_content:match("->%s*(.+)$") or
                   link_content:match("<%-(.+)$") or
                   link_content

    target = target:match("^%s*(.-)%s*$")

    if not passage_names[target] and not special_targets[target] and target ~= "" then
      local link_start = line:find("%[%[" .. link_content:gsub("([^%w])", "%%%1"), 1) or 0
      table.insert(diagnostics, {
        range = {
          start = { line = line_num - 1, character = link_start },
          ["end"] = { line = line_num - 1, character = link_start + #link_content + 4 },
        },
        severity = DiagnosticSeverity.ERROR,
        source = "whisker-lsp",
        message = "Broken link: passage '" .. target .. "' not found",
      })
    end
  end
end

--- Check for unbalanced braces
-- @param line string Line content
-- @param line_num number Line number (1-based)
-- @param diagnostics table Diagnostics array to append to
function Diagnostics:_check_brace_balance(line, line_num, diagnostics)
  local open = 0
  local close = 0
  local positions = {}

  for i = 1, #line do
    local c = line:sub(i, i)
    if c == "{" then
      open = open + 1
      table.insert(positions, { char = "{", pos = i })
    elseif c == "}" then
      close = close + 1
      if #positions > 0 and positions[#positions].char == "{" then
        table.remove(positions)
      else
        table.insert(positions, { char = "}", pos = i })
      end
    end
  end

  for _, p in ipairs(positions) do
    local msg = p.char == "{" and "Unclosed brace" or "Unexpected closing brace"
    table.insert(diagnostics, {
      range = {
        start = { line = line_num - 1, character = p.pos - 1 },
        ["end"] = { line = line_num - 1, character = p.pos },
      },
      severity = DiagnosticSeverity.ERROR,
      source = "whisker-lsp",
      message = msg,
    })
  end
end

--- Check for duplicate passage declarations
-- @param line string Line content
-- @param line_num number Line number (1-based)
-- @param all_lines table All lines
-- @param diagnostics table Diagnostics array to append to
function Diagnostics:_check_duplicate_passages(line, line_num, all_lines, diagnostics)
  local header = line:match("^::%s*(.+)$")
  if not header then return end

  local name = header:match("^([^%[%]]+)")
  if not name then return end
  name = name:match("^%s*(.-)%s*$")

  -- Check if this passage name appears earlier
  for i = 1, line_num - 1 do
    local other_header = all_lines[i]:match("^::%s*(.+)$")
    if other_header then
      local other_name = other_header:match("^([^%[%]]+)")
      if other_name then
        other_name = other_name:match("^%s*(.-)%s*$")
        if other_name == name then
          local name_start = line:find(name, 1, true) - 1
          table.insert(diagnostics, {
            range = {
              start = { line = line_num - 1, character = name_start },
              ["end"] = { line = line_num - 1, character = name_start + #name },
            },
            severity = DiagnosticSeverity.ERROR,
            source = "whisker-lsp",
            message = "Duplicate passage '" .. name .. "' (first defined on line " .. i .. ")",
          })
          break
        end
      end
    end
  end
end

--- Check for undefined variable references
-- @param line string Line content
-- @param line_num number Line number (1-based)
-- @param all_lines table All lines
-- @param diagnostics table Diagnostics array to append to
function Diagnostics:_check_undefined_variables(line, line_num, all_lines, diagnostics)
  -- Collect all defined variables (VAR declarations before this line)
  local defined_vars = {}
  for i = 1, line_num - 1 do
    local var_name = all_lines[i]:match("^%s*VAR%s+([%w_]+)")
    if var_name then
      defined_vars[var_name] = true
    end
  end

  -- Also check current line for VAR declaration
  local current_var = line:match("^%s*VAR%s+([%w_]+)")
  if current_var then
    defined_vars[current_var] = true
  end

  -- Skip if this is a VAR declaration line
  if line:match("^%s*VAR%s+") then
    return
  end

  -- Find variable references
  local pos = 1
  while true do
    local start_pos, end_pos, var_name = line:find("%$([%w_]+)", pos)
    if not start_pos then break end

    -- Only warn (not error) for undefined variables, as they might be set at runtime
    if not defined_vars[var_name] then
      table.insert(diagnostics, {
        range = {
          start = { line = line_num - 1, character = start_pos - 1 },
          ["end"] = { line = line_num - 1, character = end_pos },
        },
        severity = DiagnosticSeverity.WARNING,
        source = "whisker-lsp",
        message = "Variable '$" .. var_name .. "' may not be defined",
      })
    end

    pos = end_pos + 1
  end
end

return Diagnostics
