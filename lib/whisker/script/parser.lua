-- Whisker Script Parser
-- Converts token stream into AST
--
-- lib/whisker/script/parser.lua

local AST = require("whisker.script.ast")

--------------------------------------------------------------------------------
-- Operator Precedence
--------------------------------------------------------------------------------

local PRECEDENCE = {
  ["||"] = 1,
  ["&&"] = 2,
  ["=="] = 3, ["!="] = 3,
  ["<"] = 4, [">"] = 4, ["<="] = 4, [">="] = 4,
}

local UNARY_PRECEDENCE = 5

local BINARY_OPS = {
  ["OR"] = "||",
  ["AND"] = "&&",
  ["EQ"] = "==",
  ["NEQ"] = "!=",
  ["LT"] = "<",
  ["GT"] = ">",
  ["LTE"] = "<=",
  ["GTE"] = ">=",
}

local ASSIGN_OPS = {
  ["ASSIGN"] = "=",
  ["PLUS_ASSIGN"] = "+=",
  ["MINUS_ASSIGN"] = "-=",
}

--------------------------------------------------------------------------------
-- Parser Class
--------------------------------------------------------------------------------

local Parser = {}
Parser._dependencies = {}
Parser.__index = Parser

--- Create a new parser for the given tokens
---@param tokens table[] Array of tokens from lexer
---@param filename string|nil Optional filename for error messages
---@return Parser
function Parser.new(tokens, filename)
  local self = setmetatable({}, Parser)

  self.tokens = tokens
  self.filename = filename or "<input>"
  self.pos = 1

  -- Collected errors (for error recovery)
  self.errors = {}

  return self
end

--------------------------------------------------------------------------------
-- Token Navigation
--------------------------------------------------------------------------------

--- Get current token
---@return table|nil
function Parser:current()
  return self.tokens[self.pos]
end

--- Peek at token at offset
---@param offset number|nil Offset from current (default 0)
---@return table|nil
function Parser:peek(offset)
  offset = offset or 0
  return self.tokens[self.pos + offset]
end

--- Check if at end of tokens
---@return boolean
function Parser:is_at_end()
  local token = self:current()
  return not token or token.type == "EOF"
end

--- Advance to next token and return previous
---@return table|nil Previous token
function Parser:advance()
  if self:is_at_end() then
    return self:current()
  end
  local token = self:current()
  self.pos = self.pos + 1
  return token
end

--- Check if current token matches type
---@param type string Token type
---@return boolean
function Parser:check(type)
  local token = self:current()
  return token and token.type == type
end

--- Check if current token matches any of the types
---@param ... string Token types
---@return boolean
function Parser:check_any(...)
  local token = self:current()
  if not token then return false end
  for _, t in ipairs({...}) do
    if token.type == t then
      return true
    end
  end
  return false
end

--- Consume token if it matches type
---@param type string Expected token type
---@return table|nil Token if matched
function Parser:match(type)
  if self:check(type) then
    return self:advance()
  end
  return nil
end

--- Consume token if it matches any of the types
---@param ... string Token types
---@return table|nil Token if matched
function Parser:match_any(...)
  for _, t in ipairs({...}) do
    if self:check(t) then
      return self:advance()
    end
  end
  return nil
end

--- Expect a token of given type, error if not found
---@param type string Expected token type
---@param message string|nil Error message
---@return table Token
function Parser:expect(type, message)
  local token = self:current()
  if not token or token.type ~= type then
    local got = token and token.type or "EOF"
    local msg = message or ("expected " .. type .. " but got " .. got)
    self:error(msg)
    -- Return a dummy token to allow recovery
    return { type = type, value = nil, line = (token and token.line) or 0, column = (token and token.column) or 0, raw = "" }
  end
  return self:advance()
end

--- Skip newlines
function Parser:skip_newlines()
  while self:check("NEWLINE") do
    self:advance()
  end
end

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

--- Record an error
---@param message string Error message
---@param token table|nil Token at error (defaults to current)
function Parser:error(message, token)
  token = token or self:current()
  table.insert(self.errors, {
    message = message,
    line = token and token.line or 0,
    column = token and token.column or 0,
    token = token
  })
end

--- Synchronize after error (skip to next valid parse point)
function Parser:synchronize()
  -- Skip until we find a passage marker, choice marker, or EOF
  while not self:is_at_end() do
    if self:check("PASSAGE_MARKER") then
      return
    end
    if self:check("NEWLINE") then
      self:advance()
      -- After newline, check for structural elements
      if self:check_any("PASSAGE_MARKER", "PLUS", "LBRACE", "DOLLAR") then
        return
      end
    else
      self:advance()
    end
  end
end

--------------------------------------------------------------------------------
-- Main Parsing Entry Points
--------------------------------------------------------------------------------

--- Parse the entire token stream
---@return table Program AST node
function Parser:parse()
  local passages = {}

  self:skip_newlines()

  while not self:is_at_end() do
    local passage = self:parse_passage()
    if passage then
      table.insert(passages, passage)
    end
    self:skip_newlines()
  end

  return AST.Program(passages)
end

--- Parse with error recovery
---@return table Program AST node (with errors array)
function Parser:parse_with_recovery()
  local program = self:parse()
  program.errors = self.errors
  return program
end

--------------------------------------------------------------------------------
-- Passage Parsing
--------------------------------------------------------------------------------

--- Parse a passage
---@return table|nil Passage AST node
function Parser:parse_passage()
  -- Expect ::
  if not self:match("PASSAGE_MARKER") then
    self:error("expected passage marker ::")
    self:synchronize()
    return nil
  end

  -- Get passage name
  local name_token = self:expect("IDENTIFIER", "expected passage name after ::")
  local name = name_token.value or "unnamed"

  local metadata = {
    location = AST.Location(name_token.line, name_token.column, self.filename)
  }

  -- Expect newline after name
  self:match("NEWLINE")
  self:skip_newlines()

  -- Parse passage content
  local content = self:parse_content()

  return AST.Passage(name, content, metadata)
end

--- Parse passage content until next passage or EOF
---@return table[] Array of content nodes
function Parser:parse_content()
  local content = {}

  while not self:is_at_end() and not self:check("PASSAGE_MARKER") do
    local element = self:parse_content_element()
    if element then
      table.insert(content, element)
    end
    self:skip_newlines()
  end

  return content
end

--- Parse a single content element
---@return table|nil AST node
function Parser:parse_content_element()
  self:skip_newlines()

  if self:is_at_end() or self:check("PASSAGE_MARKER") then
    return nil
  end

  -- Choice
  if self:check("PLUS") then
    return self:parse_choice()
  end

  -- Conditional or conditional close
  if self:check("LBRACE") then
    -- Check if this is a closing { / }
    if self:peek(1) and self:peek(1).type == "SLASH" then
      return nil  -- Signal end of conditional content
    end
    return self:parse_conditional()
  end

  -- Assignment
  if self:check("DOLLAR") then
    return self:parse_assignment()
  end

  -- Embedded Lua
  if self:check("LUA_BLOCK") then
    return self:parse_lua_block()
  end

  -- Text content
  if self:check("TEXT") then
    return self:parse_text()
  end

  -- Identifier might be text
  if self:check("IDENTIFIER") then
    return self:parse_text()
  end

  -- Skip unknown tokens
  if not self:check("NEWLINE") then
    self:advance()
  end
  return nil
end

--------------------------------------------------------------------------------
-- Choice Parsing
--------------------------------------------------------------------------------

--- Parse a choice
---@return table|nil Choice AST node
function Parser:parse_choice()
  local start_token = self:expect("PLUS", "expected + for choice")

  local metadata = {
    location = AST.Location(start_token.line, start_token.column, self.filename)
  }

  -- Optional condition
  local condition = nil
  if self:check("LBRACE") then
    -- Make sure it's not { / }
    if self:peek(1) and self:peek(1).type ~= "SLASH" then
      self:advance()  -- consume {
      condition = self:parse_expression()
      self:expect("RBRACE", "expected } after choice condition")
    end
  end

  -- Choice text in brackets
  self:expect("LBRACKET", "expected [ for choice text")

  local text_parts = {}
  while not self:is_at_end() and not self:check("RBRACKET") and not self:check("NEWLINE") do
    local token = self:current()
    if token.type == "TEXT" then
      table.insert(text_parts, token.value)
      self:advance()
    elseif token.type == "DOLLAR" then
      self:advance()
      local var_token = self:expect("IDENTIFIER", "expected variable name")
      table.insert(text_parts, AST.Variable(var_token.value or ""))
    elseif token.type == "IDENTIFIER" then
      table.insert(text_parts, token.value)
      self:advance()
    else
      -- Include other tokens as text
      table.insert(text_parts, token.raw or token.value or "")
      self:advance()
    end
  end

  self:expect("RBRACKET", "expected ] after choice text")

  -- Arrow and target
  self:expect("ARROW", "expected -> after choice text")
  local target_token = self:expect("IDENTIFIER", "expected target passage name")
  local target = target_token.value or "unknown"

  -- Build choice text
  local text
  if #text_parts == 1 and type(text_parts[1]) == "string" then
    text = text_parts[1]
  elseif #text_parts > 0 then
    text = AST.Interpolation(text_parts)
  else
    text = ""
  end

  -- Consume trailing newline
  self:match("NEWLINE")

  return AST.Choice(text, target, condition, metadata)
end

--------------------------------------------------------------------------------
-- Conditional Parsing
--------------------------------------------------------------------------------

--- Parse a conditional block
---@return table|nil Conditional AST node
function Parser:parse_conditional()
  local start_token = self:expect("LBRACE", "expected { for conditional")

  local metadata = {
    location = AST.Location(start_token.line, start_token.column, self.filename)
  }

  -- Parse condition expression
  local condition = self:parse_expression()

  self:expect("RBRACE", "expected } after condition")
  self:match("NEWLINE")

  -- Parse content until { / }
  local then_content = {}

  while not self:is_at_end() do
    self:skip_newlines()

    -- Check for closing { / }
    if self:check("LBRACE") then
      if self:peek(1) and self:peek(1).type == "SLASH" then
        break
      end
    end

    -- Check for passage marker (unclosed conditional)
    if self:check("PASSAGE_MARKER") then
      self:error("unclosed conditional block (missing { / })")
      break
    end

    local element = self:parse_content_element()
    if element then
      table.insert(then_content, element)
    elseif self:check("LBRACE") and self:peek(1) and self:peek(1).type == "SLASH" then
      break
    end
  end

  -- Expect closing { / }
  if self:match("LBRACE") then
    self:expect("SLASH", "expected / in closing { / }")
    self:expect("RBRACE", "expected } in closing { / }")
  else
    self:error("expected { / } to close conditional")
  end

  self:match("NEWLINE")

  return AST.Conditional(condition, then_content, metadata)
end

--------------------------------------------------------------------------------
-- Assignment Parsing
--------------------------------------------------------------------------------

--- Parse a variable assignment
---@return table|nil Assignment AST node
function Parser:parse_assignment()
  local dollar_token = self:expect("DOLLAR", "expected $ for variable")

  local metadata = {
    location = AST.Location(dollar_token.line, dollar_token.column, self.filename)
  }

  local name_token = self:expect("IDENTIFIER", "expected variable name")
  local name = name_token.value or ""

  -- Get assignment operator
  local op_token = self:match_any("ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN")
  if not op_token then
    self:error("expected assignment operator (=, +=, -=)")
    self:synchronize()
    return nil
  end

  local operator = ASSIGN_OPS[op_token.type] or "="

  -- Parse value expression
  local value = self:parse_expression()

  self:match("NEWLINE")

  return AST.Assignment(name, operator, value, metadata)
end

--------------------------------------------------------------------------------
-- Lua Block Parsing
--------------------------------------------------------------------------------

--- Parse embedded Lua
---@return table|nil LuaBlock AST node
function Parser:parse_lua_block()
  local token = self:expect("LUA_BLOCK", "expected Lua block")

  local metadata = {
    location = AST.Location(token.line, token.column, self.filename)
  }

  self:match("NEWLINE")

  return AST.LuaBlock(token.value or "", metadata)
end

--------------------------------------------------------------------------------
-- Text Parsing
--------------------------------------------------------------------------------

--- Parse text content
---@return table|nil Text AST node
function Parser:parse_text()
  local parts = {}
  local start_token = self:current()

  while not self:is_at_end() do
    local token = self:current()

    -- Stop at structural elements
    if token.type == "NEWLINE" or token.type == "PASSAGE_MARKER" or
       token.type == "PLUS" or token.type == "LBRACE" or
       token.type == "LUA_BLOCK" then
      break
    end

    -- Variable interpolation
    if token.type == "DOLLAR" then
      self:advance()
      if self:check("IDENTIFIER") then
        local var_token = self:advance()
        table.insert(parts, AST.Variable(var_token.value or ""))
      else
        table.insert(parts, "$")
      end
    -- Text content
    elseif token.type == "TEXT" then
      table.insert(parts, token.value or "")
      self:advance()
    -- Identifier as text
    elseif token.type == "IDENTIFIER" then
      table.insert(parts, token.value or "")
      self:advance()
    -- Numbers as text
    elseif token.type == "NUMBER" then
      table.insert(parts, tostring(token.value))
      self:advance()
    -- Strings as text
    elseif token.type == "STRING" then
      table.insert(parts, token.value or "")
      self:advance()
    else
      -- Stop at unknown tokens
      break
    end
  end

  if #parts == 0 then
    return nil
  end

  local metadata = {
    location = AST.Location(
      start_token and start_token.line or 0,
      start_token and start_token.column or 0,
      self.filename
    )
  }

  -- Simplify if just one string part
  if #parts == 1 and type(parts[1]) == "string" then
    return AST.Text(parts[1], metadata)
  end

  -- Has interpolation
  return AST.Text(AST.Interpolation(parts), metadata)
end

--------------------------------------------------------------------------------
-- Expression Parsing (Precedence Climbing)
--------------------------------------------------------------------------------

--- Parse an expression
---@return table Expression AST node
function Parser:parse_expression()
  return self:parse_or_expression()
end

--- Parse OR expression (lowest precedence)
---@return table Expression AST node
function Parser:parse_or_expression()
  local left = self:parse_and_expression()

  while self:check("OR") do
    local op_token = self:advance()
    local right = self:parse_and_expression()
    left = AST.BinaryOp("||", left, right, {
      location = AST.Location(op_token.line, op_token.column, self.filename)
    })
  end

  return left
end

--- Parse AND expression
---@return table Expression AST node
function Parser:parse_and_expression()
  local left = self:parse_comparison_expression()

  while self:check("AND") do
    local op_token = self:advance()
    local right = self:parse_comparison_expression()
    left = AST.BinaryOp("&&", left, right, {
      location = AST.Location(op_token.line, op_token.column, self.filename)
    })
  end

  return left
end

--- Parse comparison expression
---@return table Expression AST node
function Parser:parse_comparison_expression()
  local left = self:parse_unary_expression()

  local op_token = self:match_any("EQ", "NEQ", "LT", "GT", "LTE", "GTE")
  if op_token then
    local operator = BINARY_OPS[op_token.type]
    local right = self:parse_unary_expression()
    return AST.BinaryOp(operator, left, right, {
      location = AST.Location(op_token.line, op_token.column, self.filename)
    })
  end

  return left
end

--- Parse unary expression
---@return table Expression AST node
function Parser:parse_unary_expression()
  if self:check("NOT") then
    local op_token = self:advance()
    local operand = self:parse_unary_expression()
    return AST.UnaryOp("!", operand, {
      location = AST.Location(op_token.line, op_token.column, self.filename)
    })
  end

  return self:parse_primary_expression()
end

--- Parse primary expression
---@return table Expression AST node
function Parser:parse_primary_expression()
  -- Variable
  if self:check("DOLLAR") then
    local dollar_token = self:advance()
    local name_token = self:expect("IDENTIFIER", "expected variable name after $")
    return AST.Variable(name_token.value or "", {
      location = AST.Location(dollar_token.line, dollar_token.column, self.filename)
    })
  end

  -- Number literal
  if self:check("NUMBER") then
    local token = self:advance()
    return AST.Literal(token.value, {
      location = AST.Location(token.line, token.column, self.filename)
    })
  end

  -- String literal
  if self:check("STRING") then
    local token = self:advance()
    return AST.Literal(token.value, {
      location = AST.Location(token.line, token.column, self.filename)
    })
  end

  -- Boolean true
  if self:check("TRUE") then
    local token = self:advance()
    return AST.Literal(true, {
      location = AST.Location(token.line, token.column, self.filename)
    })
  end

  -- Boolean false
  if self:check("FALSE") then
    local token = self:advance()
    return AST.Literal(false, {
      location = AST.Location(token.line, token.column, self.filename)
    })
  end

  -- Parenthesized expression
  if self:check("LPAREN") then
    self:advance()
    local expr = self:parse_expression()
    self:expect("RPAREN", "expected ) after expression")
    return expr
  end

  -- Error: unexpected token
  local token = self:current()
  self:error("expected expression", token)

  -- Return a placeholder
  return AST.Literal(nil, {
    location = AST.Location(
      token and token.line or 0,
      token and token.column or 0,
      self.filename
    )
  })
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return Parser
