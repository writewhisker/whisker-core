--- Chapbook variable assignment parser
-- Parses: variableName: value
--
-- lib/whisker/twine/formats/chapbook/variable_parser.lua

local VariableParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local ExprParser = require('whisker.twine.formats.chapbook.expression_parser')

--------------------------------------------------------------------------------
-- Assignment Parsing
--------------------------------------------------------------------------------

--- Parse variable assignment line
---@param line string Line containing assignment (e.g., "health: 100")
---@return table AST node
function VariableParser.parse_assignment(line)
  -- Match pattern: varName: value
  local var_name, value_str = line:match("^([%w_]+):%s*(.+)$")

  if not var_name then
    return ASTBuilder.create_error("Invalid variable assignment: " .. line)
  end

  -- Parse value
  local value_ast = ExprParser.parse(value_str)

  return ASTBuilder.create_assignment(var_name, value_ast)
end

--- Check if a line is a variable assignment
---@param line string Line to check
---@return boolean True if line is an assignment
function VariableParser.is_assignment(line)
  -- Assignment format: varName: value
  -- Must not be a modifier [...]
  if line:match("^%[") then
    return false
  end

  -- Must have varName: pattern at start
  return line:match("^[%w_]+:%s*.+") ~= nil
end

--- Parse multiple assignment lines (Chapbook vars block style)
---@param lines table Array of lines
---@param start_index number Starting line index
---@return table, number Array of AST nodes and number of lines consumed
function VariableParser.parse_assignment_block(lines, start_index)
  local assignments = {}
  local consumed = 0

  for i = start_index, #lines do
    local line = lines[i]

    if VariableParser.is_assignment(line) then
      local ast = VariableParser.parse_assignment(line)
      table.insert(assignments, ast)
      consumed = consumed + 1
    else
      break
    end
  end

  return assignments, consumed
end

return VariableParser
