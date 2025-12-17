-- lib/whisker/script/generator/emitter.lua
-- IR emission for Whisker Script code generator

local visitor_module = require("whisker.script.visitor")
local Visitor = visitor_module.Visitor

local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")

local M = {}

-- ============================================
-- Emitter Class
-- ============================================

local Emitter = setmetatable({}, { __index = Visitor })
Emitter.__index = Emitter

--- Create a new emitter
-- @return Emitter
function Emitter.new()
  local self = setmetatable(Visitor.new(), { __index = Emitter })
  self.story = nil
  self.current_passage = nil
  self.passage_order = {}
  return self
end

--- Emit IR from an annotated AST
-- @param ast table Annotated AST
-- @return Story Generated story
function Emitter:emit(ast)
  if not ast then
    return nil
  end

  -- Create story with metadata
  local story_opts = {
    title = self:_extract_metadata(ast, "title"),
    author = self:_extract_metadata(ast, "author"),
    version = self:_extract_metadata(ast, "version"),
    format = "whisker",
    format_version = "1.0.0"
  }

  self.story = Story.new(story_opts)
  self.passage_order = {}

  -- Visit the AST to generate passages
  self:visit(ast)

  -- Set start passage (first passage)
  if #self.passage_order > 0 then
    self.story:set_start_passage(self.passage_order[1])
  end

  return self.story
end

-- ============================================
-- Visitor Methods
-- ============================================

--- Visit Script node
function Emitter:visit_Script(node)
  -- Process passages
  for _, passage in ipairs(node.passages or {}) do
    self:visit(passage)
  end
end

--- Visit Passage node
function Emitter:visit_Passage(node)
  -- Create passage
  local passage = Passage.new({
    id = node.name,
    name = node.name,
    title = node.name,
    tags = self:_emit_tags(node.tags),
  })

  self.current_passage = passage
  table.insert(self.passage_order, node.name)

  -- Process body statements
  local content_parts = {}
  local choices = {}

  for _, stmt in ipairs(node.body or {}) do
    if stmt.type == "Choice" then
      local choice = self:_emit_choice(stmt)
      if choice then
        table.insert(choices, choice)
      end
    else
      local content = self:_emit_statement(stmt)
      if content then
        table.insert(content_parts, content)
      end
    end
  end

  -- Set passage content
  passage.content = self:_flatten_content(content_parts)
  passage.choices = choices

  -- Add to story
  self.story:add_passage(passage)

  self.current_passage = nil
end

--- Emit tags from tag nodes
-- @param tags table Array of tag nodes
-- @return table Array of tag strings
function Emitter:_emit_tags(tags)
  local result = {}
  for _, tag in ipairs(tags or {}) do
    if type(tag) == "table" and tag.name then
      table.insert(result, tag.name)
    elseif type(tag) == "string" then
      table.insert(result, tag)
    end
  end
  return result
end

--- Emit a choice node
-- @param node table Choice node
-- @return Choice
function Emitter:_emit_choice(node)
  local text = self:_emit_text_content(node.text)
  local target = nil
  local condition = nil

  -- Get target from divert
  if node.target and node.target.type == "Divert" then
    target = node.target.target
  end

  -- Get condition if present
  if node.condition then
    condition = self:_emit_expression_code(node.condition)
  end

  local choice = Choice.new({
    text = text,
    target = target,
    condition = condition
  })

  -- Handle choice body (nested statements)
  if node.body and #node.body > 0 then
    local action_parts = {}
    for _, stmt in ipairs(node.body) do
      local code = self:_emit_statement_action(stmt)
      if code then
        table.insert(action_parts, code)
      end
    end
    if #action_parts > 0 then
      choice.action = table.concat(action_parts, "\n")
    end
  end

  return choice
end

--- Emit a statement node
-- @param node table Statement node
-- @return string|table Content element
function Emitter:_emit_statement(node)
  local node_type = node.type

  if node_type == "Text" then
    return self:_emit_text(node)
  elseif node_type == "Divert" then
    return self:_emit_divert(node)
  elseif node_type == "Assignment" then
    -- Assignments become on_enter_script, not content
    return nil
  elseif node_type == "Conditional" then
    return self:_emit_conditional(node)
  elseif node_type == "TunnelCall" then
    return self:_emit_tunnel_call(node)
  elseif node_type == "TunnelReturn" then
    return self:_emit_tunnel_return(node)
  elseif node_type == "ThreadStart" then
    return self:_emit_thread_start(node)
  end

  return nil
end

--- Emit statement as action code (for choice bodies)
-- @param node table Statement node
-- @return string|nil Action code
function Emitter:_emit_statement_action(node)
  local node_type = node.type

  if node_type == "Assignment" then
    return self:_emit_assignment_code(node)
  elseif node_type == "Divert" then
    return nil -- Diverts are navigation, not actions
  end

  return nil
end

--- Emit text node
-- @param node table Text node
-- @return string|table Text content
function Emitter:_emit_text(node)
  return self:_emit_text_content(node)
end

--- Emit text content from Text node or similar
-- @param node table Text/choice text node
-- @return string Text content
function Emitter:_emit_text_content(node)
  if not node then
    return ""
  end

  -- If it's a string, return directly
  if type(node) == "string" then
    return node
  end

  -- If it's a table with segments
  local segments = node.segments or {}
  local parts = {}

  for _, seg in ipairs(segments) do
    if type(seg) == "string" then
      table.insert(parts, seg)
    elseif type(seg) == "table" then
      if seg.type == "InlineExpr" then
        table.insert(parts, self:_emit_inline_expr(seg))
      elseif seg.type == "InlineConditional" then
        table.insert(parts, self:_emit_inline_conditional(seg))
      elseif seg.type == "VariableRef" then
        table.insert(parts, self:_emit_variable_interpolation(seg))
      else
        -- Try to get string representation
        local text = self:_emit_text_content(seg)
        if text then
          table.insert(parts, text)
        end
      end
    end
  end

  return table.concat(parts, "")
end

--- Emit inline expression
-- @param node table InlineExpr node
-- @return string Interpolated expression
function Emitter:_emit_inline_expr(node)
  if node.expression then
    local expr = self:_emit_expression_code(node.expression)
    return "{" .. expr .. "}"
  end
  return ""
end

--- Emit inline conditional
-- @param node table InlineConditional node
-- @return string Interpolated conditional
function Emitter:_emit_inline_conditional(node)
  local cond = self:_emit_expression_code(node.condition)
  local then_val = self:_emit_text_content(node.then_value)
  local else_val = node.else_value and self:_emit_text_content(node.else_value) or ""

  if else_val ~= "" then
    return "{" .. cond .. ": " .. then_val .. " | " .. else_val .. "}"
  else
    return "{" .. cond .. ": " .. then_val .. "}"
  end
end

--- Emit variable interpolation
-- @param node table VariableRef node
-- @return string Variable reference string
function Emitter:_emit_variable_interpolation(node)
  return "{$" .. node.name .. "}"
end

--- Emit divert node
-- @param node table Divert node
-- @return table Divert content element
function Emitter:_emit_divert(node)
  return {
    type = "divert",
    target = node.target
  }
end

--- Emit conditional node
-- @param node table Conditional node
-- @return table Conditional content element
function Emitter:_emit_conditional(node)
  local branches = {}

  -- Main condition (then branch)
  if node.condition and node.then_body then
    table.insert(branches, {
      condition = self:_emit_expression_code(node.condition),
      content = self:_emit_statements_content(node.then_body)
    })
  end

  -- Elif clauses
  for _, elif in ipairs(node.elif_clauses or {}) do
    table.insert(branches, {
      condition = self:_emit_expression_code(elif.condition),
      content = self:_emit_statements_content(elif.body)
    })
  end

  -- Else branch
  local else_content = nil
  if node.else_body then
    else_content = self:_emit_statements_content(node.else_body)
  end

  return {
    type = "conditional",
    branches = branches,
    else_branch = else_content
  }
end

--- Emit statements as content array
-- @param stmts table Array of statements
-- @return string Concatenated content
function Emitter:_emit_statements_content(stmts)
  local parts = {}
  for _, stmt in ipairs(stmts or {}) do
    local content = self:_emit_statement(stmt)
    if content then
      if type(content) == "string" then
        table.insert(parts, content)
      elseif type(content) == "table" then
        -- For complex content, serialize as marker
        table.insert(parts, self:_serialize_content_element(content))
      end
    end
  end
  return self:_flatten_content(parts)
end

--- Emit tunnel call
-- @param node table TunnelCall node
-- @return table Tunnel call element
function Emitter:_emit_tunnel_call(node)
  return {
    type = "tunnel_call",
    target = node.target
  }
end

--- Emit tunnel return
-- @param node table TunnelReturn node
-- @return table Tunnel return element
function Emitter:_emit_tunnel_return(node)
  return {
    type = "tunnel_return"
  }
end

--- Emit thread start
-- @param node table ThreadStart node
-- @return table Thread start element
function Emitter:_emit_thread_start(node)
  return {
    type = "thread_start",
    target = node.target
  }
end

-- ============================================
-- Expression Code Generation
-- ============================================

--- Emit expression as Lua code string
-- @param node table Expression node
-- @return string Lua code
function Emitter:_emit_expression_code(node)
  if not node then
    return "nil"
  end

  local node_type = node.type

  if node_type == "Literal" then
    return self:_emit_literal_code(node)
  elseif node_type == "VariableRef" then
    return self:_emit_variable_code(node)
  elseif node_type == "BinaryExpr" then
    return self:_emit_binary_code(node)
  elseif node_type == "UnaryExpr" then
    return self:_emit_unary_code(node)
  elseif node_type == "FunctionCall" then
    return self:_emit_function_code(node)
  elseif node_type == "ListLiteral" then
    return self:_emit_list_code(node)
  end

  return "nil"
end

--- Emit literal as code
-- @param node table Literal node
-- @return string Lua literal
function Emitter:_emit_literal_code(node)
  local val = node.value
  local lit_type = node.literal_type

  if lit_type == "number" then
    return tostring(val)
  elseif lit_type == "string" then
    return string.format("%q", val)
  elseif lit_type == "boolean" then
    return val and "true" or "false"
  elseif lit_type == "null" or val == nil then
    return "nil"
  end

  return tostring(val)
end

--- Emit variable reference as code
-- @param node table VariableRef node
-- @return string Lua variable access
function Emitter:_emit_variable_code(node)
  local base = "_G.state[" .. string.format("%q", node.name) .. "]"

  if node.index then
    local idx = self:_emit_expression_code(node.index)
    return base .. "[" .. idx .. "]"
  end

  return base
end

--- Emit binary expression as code
-- @param node table BinaryExpr node
-- @return string Lua expression
function Emitter:_emit_binary_code(node)
  local left = self:_emit_expression_code(node.left)
  local right = self:_emit_expression_code(node.right)
  local op = node.operator

  -- Map operators to Lua
  local op_map = {
    ["=="] = "==",
    ["!="] = "~=",
    ["<"] = "<",
    [">"] = ">",
    ["<="] = "<=",
    [">="] = ">=",
    ["+"] = "+",
    ["-"] = "-",
    ["*"] = "*",
    ["/"] = "/",
    ["%"] = "%",
    ["and"] = "and",
    ["or"] = "or",
  }

  local lua_op = op_map[op] or op
  return "(" .. left .. " " .. lua_op .. " " .. right .. ")"
end

--- Emit unary expression as code
-- @param node table UnaryExpr node
-- @return string Lua expression
function Emitter:_emit_unary_code(node)
  local operand = self:_emit_expression_code(node.operand)
  local op = node.operator

  if op == "not" then
    return "(not " .. operand .. ")"
  elseif op == "-" then
    return "(-" .. operand .. ")"
  end

  return operand
end

--- Emit function call as code
-- @param node table FunctionCall node
-- @return string Lua function call
function Emitter:_emit_function_code(node)
  local args = {}
  for _, arg in ipairs(node.arguments or {}) do
    table.insert(args, self:_emit_expression_code(arg))
  end

  return "_G.funcs." .. node.name .. "(" .. table.concat(args, ", ") .. ")"
end

--- Emit list literal as code
-- @param node table ListLiteral node
-- @return string Lua table literal
function Emitter:_emit_list_code(node)
  local elements = {}
  for _, elem in ipairs(node.elements or {}) do
    table.insert(elements, self:_emit_expression_code(elem))
  end

  return "{" .. table.concat(elements, ", ") .. "}"
end

--- Emit assignment as action code
-- @param node table Assignment node
-- @return string Lua assignment
function Emitter:_emit_assignment_code(node)
  local var_name = node.variable.name
  local var_base = "_G.state[" .. string.format("%q", var_name) .. "]"
  local value = self:_emit_expression_code(node.value)
  local op = node.operator

  if op == "=" then
    return var_base .. " = " .. value
  elseif op == "+=" then
    return var_base .. " = " .. var_base .. " + " .. value
  elseif op == "-=" then
    return var_base .. " = " .. var_base .. " - " .. value
  elseif op == "*=" then
    return var_base .. " = " .. var_base .. " * " .. value
  elseif op == "/=" then
    return var_base .. " = " .. var_base .. " / " .. value
  elseif op == "[]=" then
    -- List append
    return "table.insert(" .. var_base .. ", " .. value .. ")"
  end

  return var_base .. " = " .. value
end

-- ============================================
-- Helper Methods
-- ============================================

--- Extract metadata from AST
-- @param ast table AST
-- @param key string Metadata key
-- @return string|nil Metadata value
function Emitter:_extract_metadata(ast, key)
  for _, meta in ipairs(ast.metadata or {}) do
    if meta.key == key then
      return meta.value
    end
  end
  return nil
end

--- Flatten content parts into string
-- @param parts table Array of content parts
-- @return string Flattened content
function Emitter:_flatten_content(parts)
  local result = {}
  for _, part in ipairs(parts) do
    if type(part) == "string" then
      table.insert(result, part)
    elseif type(part) == "table" then
      table.insert(result, self:_serialize_content_element(part))
    end
  end
  return table.concat(result, "\n")
end

--- Serialize a content element to string representation
-- @param elem table Content element
-- @return string Serialized form
function Emitter:_serialize_content_element(elem)
  if elem.type == "divert" then
    return "-> " .. elem.target
  elseif elem.type == "tunnel_call" then
    return "->-> " .. elem.target
  elseif elem.type == "tunnel_return" then
    return "->->"
  elseif elem.type == "thread_start" then
    return "<- " .. elem.target
  elseif elem.type == "conditional" then
    -- Serialize conditional as marker
    return "[conditional]"
  end
  return ""
end

M.Emitter = Emitter

--- Module metadata
M._whisker = {
  name = "script.generator.emitter",
  version = "0.1.0",
  description = "IR emission for Whisker Script",
  depends = {
    "script.visitor",
    "core.story",
    "core.passage",
    "core.choice"
  },
  capability = "script.generator.emitter"
}

return M
