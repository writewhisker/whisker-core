--- AST Builder for Twine format conversion
-- Provides helper functions to create WhiskerScript AST nodes
-- Used by Harlowe, SugarCube, and other format translators
--
-- lib/whisker/twine/ast_builder.lua

local ASTBuilder = {}

--------------------------------------------------------------------------------
-- Literal Constructors
--------------------------------------------------------------------------------

--- Create a literal node
---@param literal_type string Type of literal: "number", "string", "boolean", "nil"
---@param value any The literal value
---@return table AST node
function ASTBuilder.create_literal(literal_type, value)
  return {
    type = "literal",
    literal_type = literal_type,
    value = value
  }
end

--- Create a text node
---@param content string Text content
---@return table AST node
function ASTBuilder.create_text(content)
  return {
    type = "text",
    content = content
  }
end

--------------------------------------------------------------------------------
-- Variable Constructors
--------------------------------------------------------------------------------

--- Create a variable reference node
---@param name string Variable name (without $)
---@return table AST node
function ASTBuilder.create_variable_ref(name)
  return {
    type = "variable",
    name = name
  }
end

--- Create a property access node (for datamap access)
---@param target table Target expression (variable or nested access)
---@param property string Property name
---@return table AST node
function ASTBuilder.create_property_access(target, property)
  return {
    type = "property_access",
    target = target,
    property = property
  }
end

--- Create an array access node
---@param target table Target expression (the array)
---@param index table Index expression
---@return table AST node
function ASTBuilder.create_array_access(target, index)
  return {
    type = "array_access",
    target = target,
    index = index
  }
end

--- Create a length-of node
---@param target table Target expression (array or string)
---@return table AST node
function ASTBuilder.create_length_of(target)
  return {
    type = "length_of",
    target = target
  }
end

--------------------------------------------------------------------------------
-- Assignment Constructors
--------------------------------------------------------------------------------

--- Create an assignment node
---@param variable string Variable name (without $)
---@param value table Value expression
---@param operator string|nil Assignment operator (default "=")
---@return table AST node
function ASTBuilder.create_assignment(variable, value, operator)
  return {
    type = "assignment",
    variable = variable,
    operator = operator or "=",
    value = value
  }
end

--------------------------------------------------------------------------------
-- Control Flow Constructors
--------------------------------------------------------------------------------

--- Create a conditional node
---@param condition table Condition expression
---@param body table[] Body statements
---@return table AST node
function ASTBuilder.create_conditional(condition, body)
  return {
    type = "conditional",
    condition = condition,
    body = body or {}
  }
end

--- Create an elsif clause node
---@param condition table Condition expression
---@param body table[] Body statements
---@return table AST node
function ASTBuilder.create_elsif(condition, body)
  return {
    type = "elsif",
    condition = condition,
    body = body or {}
  }
end

--- Create an else clause node
---@param body table[] Body statements
---@return table AST node
function ASTBuilder.create_else(body)
  return {
    type = "else",
    body = body or {}
  }
end

--- Create a for-loop node
---@param variable string Loop variable name
---@param collection table Collection expression to iterate over
---@param body table[] Loop body statements
---@return table AST node
function ASTBuilder.create_for_loop(variable, collection, body)
  return {
    type = "for_loop",
    variable = variable,
    collection = collection,
    body = body or {}
  }
end

--- Create an event listener node (for Harlowe's (event:) macro)
---@param condition table Condition that triggers the event
---@param body table[] Body to execute when triggered
---@return table AST node
function ASTBuilder.create_event_listener(condition, body)
  return {
    type = "event_listener",
    condition = condition,
    body = body or {},
    -- Note: true live updates not supported in text mode
    warning = "Event listeners check on turn changes in text mode"
  }
end

--------------------------------------------------------------------------------
-- Navigation Constructors
--------------------------------------------------------------------------------

--- Create a choice node
---@param text string Choice display text
---@param body table[] Body executed when choice is selected
---@param destination string|nil Target passage (optional)
---@return table AST node
function ASTBuilder.create_choice(text, body, destination)
  return {
    type = "choice",
    text = text,
    body = body or {},
    destination = destination
  }
end

--- Create a goto node
---@param destination string Target passage name
---@return table AST node
function ASTBuilder.create_goto(destination)
  return {
    type = "goto",
    destination = destination
  }
end

--------------------------------------------------------------------------------
-- Expression Constructors
--------------------------------------------------------------------------------

--- Create a binary operation node
---@param operator string Operator ("+", "-", "*", "/", "==", "!=", "<", ">", "<=", ">=")
---@param left table Left operand expression
---@param right table Right operand expression
---@return table AST node
function ASTBuilder.create_binary_op(operator, left, right)
  return {
    type = "binary_op",
    operator = operator,
    left = left,
    right = right
  }
end

--- Create a logical operation node
---@param operator string Operator ("and", "or")
---@param left table Left operand expression
---@param right table Right operand expression
---@return table AST node
function ASTBuilder.create_logical_op(operator, left, right)
  return {
    type = "logical_op",
    operator = operator,
    left = left,
    right = right
  }
end

--- Create a unary operation node
---@param operator string Operator ("not", "-")
---@param operand table Operand expression
---@return table AST node
function ASTBuilder.create_unary_op(operator, operand)
  return {
    type = "unary_op",
    operator = operator,
    operand = operand
  }
end

--- Create a raw expression node (for unparseable expressions)
---@param expr string Raw expression string
---@return table AST node
function ASTBuilder.create_raw_expression(expr)
  return {
    type = "raw_expression",
    expression = expr
  }
end

--------------------------------------------------------------------------------
-- Data Structure Constructors
--------------------------------------------------------------------------------

--- Create an array literal node
---@param items table[] Array of item expressions
---@return table AST node
function ASTBuilder.create_array_literal(items)
  return {
    type = "array_literal",
    items = items or {}
  }
end

--- Create a table/datamap literal node
---@param pairs table[] Array of {key, value} pairs
---@return table AST node
function ASTBuilder.create_table_literal(pairs)
  return {
    type = "table_literal",
    pairs = pairs or {}
  }
end

--- Create a random choice expression node
---@param collection table Collection to choose from
---@return table AST node
function ASTBuilder.create_random_choice(collection)
  return {
    type = "random_choice",
    collection = collection
  }
end

--------------------------------------------------------------------------------
-- Named Hook Constructors
--------------------------------------------------------------------------------

--- Create a hook update node (replace, append, prepend)
---@param operation string Operation type: "replace", "append", "prepend"
---@param hook_name string Name of the hook to update
---@param content table[] New content for the hook
---@return table AST node
function ASTBuilder.create_hook_update(operation, hook_name, content)
  return {
    type = "hook_update",
    operation = operation,
    hook_name = hook_name,
    content = content or {}
  }
end

--- Create a named hook definition node
---@param name string Hook name
---@param content table[] Hook content
---@param hidden boolean|nil Whether hook starts hidden
---@return table AST node
function ASTBuilder.create_named_hook(name, content, hidden)
  return {
    type = "named_hook",
    name = name,
    content = content or {},
    hidden = hidden or false
  }
end

--------------------------------------------------------------------------------
-- Live/Timed Update Constructors
--------------------------------------------------------------------------------

--- Create a live update node
---@param interval number Interval in seconds
---@param body table[] Body to execute/display
---@return table AST node
function ASTBuilder.create_live_update(interval, body)
  return {
    type = "live_update",
    interval = interval,
    body = body or {},
    warning = "Live updates execute once in text mode; true live updates require GUI runtime"
  }
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Create an error node
---@param message string Error message
---@return table AST node
function ASTBuilder.create_error(message)
  return {
    type = "error",
    message = message
  }
end

--- Create a warning node
---@param message string Warning message
---@param original table|nil Original content that caused the warning
---@return table AST node
function ASTBuilder.create_warning(message, original)
  return {
    type = "warning",
    message = message,
    original = original
  }
end

return ASTBuilder
