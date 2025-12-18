-- lib/whisker/script/parser/grammar.lua
-- Grammar rules for Whisker Script parser

local tokens_module = require("whisker.script.lexer.tokens")
local ast_module = require("whisker.script.parser.ast")
local codes_module = require("whisker.script.errors.codes")

local TokenType = tokens_module.TokenType
local Node = ast_module.Node
local ErrorCodes = codes_module.Parser

local M = {}

-- ============================================
-- Script-Level Parsing
-- ============================================

--- Parse entire script
-- @param parser Parser Parser instance
-- @return table ScriptNode
function M.parse_script(parser)
  local metadata = {}
  local includes = {}
  local passages = {}
  local start_pos = parser:peek().pos

  -- Skip leading whitespace/comments
  parser:skip_whitespace()

  while not parser:is_at_end() do
    if parser:check(TokenType.METADATA) then
      local meta = M.parse_metadata(parser)
      if meta then table.insert(metadata, meta) end
    elseif parser:check(TokenType.INCLUDE) then
      local inc = M.parse_include(parser)
      if inc then table.insert(includes, inc) end
    elseif parser:check(TokenType.PASSAGE_DECL) then
      local passage = M.parse_passage_decl(parser)
      if passage then table.insert(passages, passage) end
    elseif parser:check_any(TokenType.NEWLINE, TokenType.COMMENT) then
      parser:advance()  -- Skip blank lines and comments
    elseif parser:check(TokenType.EOF) then
      break
    else
      parser:error_at_current("Expected passage declaration (::)", ErrorCodes.EXPECTED_PASSAGE_DECL)
      parser:synchronize()
    end
  end

  return Node.script(metadata, includes, passages, start_pos)
end

-- ============================================
-- Metadata Parsing
-- ============================================

--- Parse metadata declaration
-- @param parser Parser Parser instance
-- @return table MetadataNode or nil on error
function M.parse_metadata(parser)
  local start_pos = parser:peek().pos

  -- Consume @@
  parser:expect(TokenType.METADATA, "Expected @@")

  -- Skip whitespace after @@
  parser:skip(TokenType.NEWLINE)

  -- Get key (identifier)
  local key_token = parser:expect(TokenType.IDENTIFIER, "Expected metadata key")
  if not key_token then
    parser:synchronize()
    return nil
  end

  -- Expect colon
  if not parser:expect(TokenType.COLON, "Expected ':' after metadata key") then
    parser:synchronize()
    return nil
  end

  -- Parse value (simple for now - string, number, or identifier)
  local value = M.parse_metadata_value(parser)
  if value == nil and parser:has_errors() then
    parser:synchronize()
    return nil
  end

  -- Consume trailing newline
  parser:match(TokenType.NEWLINE)

  return Node.metadata(key_token.literal, value, start_pos)
end

--- Parse metadata value
-- @param parser Parser Parser instance
-- @param in_list boolean Whether parsing inside a list (restrict tokens)
-- @return any Parsed value
function M.parse_metadata_value(parser, in_list)
  if parser:check(TokenType.STRING) then
    return parser:advance().literal
  elseif parser:check(TokenType.NUMBER) then
    return parser:advance().literal
  elseif parser:check(TokenType.TRUE) then
    parser:advance()
    return true
  elseif parser:check(TokenType.FALSE) then
    parser:advance()
    return false
  elseif parser:check(TokenType.LBRACKET) then
    return M.parse_metadata_list(parser)
  elseif parser:check(TokenType.IDENTIFIER) then
    if in_list then
      -- In a list, just return a single identifier
      return parser:advance().literal
    else
      -- Collect all tokens until end of line as the value
      local parts = {}
      while not parser:check_any(TokenType.NEWLINE, TokenType.EOF) do
        local token = parser:advance()
        if token.lexeme and #token.lexeme > 0 then
          table.insert(parts, token.lexeme)
        end
      end
      return table.concat(parts, " ")
    end
  else
    parser:error_at_current("Expected metadata value", ErrorCodes.EXPECTED_EXPRESSION)
    return nil
  end
end

--- Parse metadata list value [item1, item2, ...]
-- @param parser Parser Parser instance
-- @return table Array of values
function M.parse_metadata_list(parser)
  parser:expect(TokenType.LBRACKET, "Expected '['")

  local items = {}

  -- Handle empty list
  if parser:check(TokenType.RBRACKET) then
    parser:advance()
    return items
  end

  -- Parse first item (in_list = true)
  local item = M.parse_metadata_value(parser, true)
  if item ~= nil then
    table.insert(items, item)
  end

  -- Parse remaining items (in_list = true)
  while parser:match(TokenType.COMMA) do
    item = M.parse_metadata_value(parser, true)
    if item ~= nil then
      table.insert(items, item)
    end
  end

  parser:expect(TokenType.RBRACKET, "Expected ']'")

  return items
end

-- ============================================
-- Include/Import Parsing
-- ============================================

--- Parse include directive
-- @param parser Parser Parser instance
-- @return table IncludeNode or nil on error
function M.parse_include(parser)
  local start_pos = parser:peek().pos

  -- Consume >>
  parser:expect(TokenType.INCLUDE, "Expected '>>'")

  -- Parse path (string)
  local path_token = parser:expect(TokenType.STRING, "Expected file path")
  if not path_token then
    parser:synchronize()
    return nil
  end

  local alias = nil

  -- Check for optional 'as' alias
  if parser:check(TokenType.AS) then
    parser:advance()
    local alias_token = parser:expect(TokenType.IDENTIFIER, "Expected alias name")
    if alias_token then
      alias = alias_token.literal
    end
  end

  -- Consume trailing newline
  parser:match(TokenType.NEWLINE)

  return Node.include(path_token.literal, alias, start_pos)
end

-- ============================================
-- Passage Declaration Parsing
-- ============================================

--- Parse passage declaration (header only, body parsed separately)
-- @param parser Parser Parser instance
-- @return table PassageNode or nil on error
function M.parse_passage_decl(parser)
  local start_pos = parser:peek().pos

  -- Consume ::
  parser:expect(TokenType.PASSAGE_DECL, "Expected '::'")

  -- Get passage name
  local name_token = parser:expect(TokenType.IDENTIFIER, "Expected passage name")
  if not name_token then
    parser:synchronize()
    return nil
  end

  -- Parse optional tags
  local tags = {}
  if parser:check(TokenType.LBRACKET) then
    tags = M.parse_tag_list(parser)
  end

  -- Consume trailing newline
  parser:match(TokenType.NEWLINE)

  -- Parse passage body (indented content)
  local body = M.parse_passage_body(parser)

  return Node.passage(name_token.literal, tags, body, start_pos)
end

--- Parse tag list [tag1, tag2, ...]
-- @param parser Parser Parser instance
-- @return table Array of TagNode
function M.parse_tag_list(parser)
  parser:expect(TokenType.LBRACKET, "Expected '['")

  local tags = {}

  -- Handle empty tags
  if parser:check(TokenType.RBRACKET) then
    parser:advance()
    return tags
  end

  -- Parse first tag
  local tag = M.parse_tag(parser)
  if tag then table.insert(tags, tag) end

  -- Parse remaining tags
  while parser:match(TokenType.COMMA) do
    tag = M.parse_tag(parser)
    if tag then table.insert(tags, tag) end
  end

  parser:expect(TokenType.RBRACKET, "Expected ']'")

  return tags
end

--- Parse single tag
-- @param parser Parser Parser instance
-- @return table TagNode or nil
function M.parse_tag(parser)
  local start_pos = parser:peek().pos

  local name_token = parser:expect(TokenType.IDENTIFIER, "Expected tag name")
  if not name_token then
    return nil
  end

  local value = nil

  -- Check for tag value
  if parser:match(TokenType.COLON) then
    if parser:check(TokenType.STRING) then
      value = parser:advance().literal
    elseif parser:check(TokenType.NUMBER) then
      value = parser:advance().literal
    elseif parser:check(TokenType.IDENTIFIER) then
      value = parser:advance().literal
    end
  end

  return Node.tag(name_token.literal, value, start_pos)
end

--- Parse passage body (statements until next passage or EOF)
-- @param parser Parser Parser instance
-- @return table Array of statement nodes
function M.parse_passage_body(parser)
  local body = {}

  parser:enter_context("in_passage")

  -- Consume INDENT if present (for indented style)
  local has_indent = parser:match(TokenType.INDENT)

  -- Parse statements until DEDENT, next passage declaration, or EOF
  while not parser:check_any(TokenType.EOF, TokenType.PASSAGE_DECL) do
    -- Check for DEDENT if we had an INDENT
    if has_indent and parser:check(TokenType.DEDENT) then
      parser:advance()
      break
    end

    -- Skip blank lines
    if parser:check(TokenType.NEWLINE) then
      parser:advance()
    elseif parser:check(TokenType.COMMENT) then
      parser:advance()
    else
      -- Parse statement
      local stmt = M.parse_statement(parser)
      if stmt then
        table.insert(body, stmt)
      else
        -- Error recovery - advance at least one token to avoid infinite loop
        if not parser:check_any(TokenType.NEWLINE, TokenType.EOF, TokenType.PASSAGE_DECL) then
          parser:advance()
        end
        parser:synchronize_statement()
      end
    end
  end

  parser:leave_context("in_passage")

  return body
end

-- ============================================
-- Statement Parsing
-- ============================================

--- Parse a single statement
-- @param parser Parser Parser instance
-- @return table Statement node or nil
function M.parse_statement(parser)
  local token = parser:peek()

  if parser:check(TokenType.DIVERT) then
    return M.parse_divert(parser)
  elseif parser:check(TokenType.TUNNEL) then
    return M.parse_tunnel(parser)
  elseif parser:check(TokenType.THREAD) then
    return M.parse_thread(parser)
  elseif parser:check(TokenType.PLUS) then
    return M.parse_choice(parser)
  elseif parser:check(TokenType.ASSIGN) then
    return M.parse_assignment(parser)
  elseif parser:check(TokenType.IF) then
    return M.parse_conditional(parser)
  elseif parser:check_any(TokenType.IDENTIFIER, TokenType.STRING, TokenType.NUMBER) then
    return M.parse_text_line(parser)
  elseif parser:check(TokenType.LBRACE) then
    return M.parse_text_line(parser)
  elseif parser:check(TokenType.VARIABLE) then
    -- Could be assignment without ~ or text
    return M.parse_text_line(parser)
  else
    -- Treat remaining as text or skip
    if not parser:check_any(TokenType.NEWLINE, TokenType.DEDENT, TokenType.EOF) then
      return M.parse_text_line(parser)
    end
    return nil
  end
end

--- Parse tunnel call ->->
-- @param parser Parser Parser instance
-- @return table TunnelCallNode or nil
function M.parse_tunnel(parser)
  local start_pos = parser:peek().pos
  parser:expect(TokenType.TUNNEL, "Expected '->->'")

  local target_token = parser:expect(TokenType.IDENTIFIER, "Expected passage name")
  if not target_token then
    parser:synchronize_statement()
    return nil
  end

  parser:match(TokenType.NEWLINE)
  return Node.tunnel_call(target_token.literal, {}, start_pos)
end

--- Parse thread start <-
-- @param parser Parser Parser instance
-- @return table ThreadStartNode or nil
function M.parse_thread(parser)
  local start_pos = parser:peek().pos
  parser:expect(TokenType.THREAD, "Expected '<-'")

  local target_token = parser:expect(TokenType.IDENTIFIER, "Expected passage name")
  if not target_token then
    parser:synchronize_statement()
    return nil
  end

  parser:match(TokenType.NEWLINE)
  return Node.thread_start(target_token.literal, start_pos)
end

--- Parse choice statement
-- Syntax: + [choice text] -> target
-- @param parser Parser Parser instance
-- @return table ChoiceNode or nil
function M.parse_choice(parser)
  local start_pos = parser:peek().pos
  parser:advance()  -- Consume +

  local condition = nil
  local text = nil
  local target = nil

  -- Check for optional condition { expr }
  if parser:check(TokenType.LBRACE) then
    parser:advance()  -- Consume {
    condition = M.parse_expression(parser)
    parser:expect(TokenType.RBRACE, "Expected '}' after condition")
  end

  -- Parse choice text in brackets [text]
  if parser:check(TokenType.LBRACKET) then
    parser:advance()  -- Consume [
    local text_parts = {}
    while not parser:check_any(TokenType.RBRACKET, TokenType.NEWLINE, TokenType.EOF) do
      local token = parser:advance()
      if token.lexeme and #token.lexeme > 0 then
        table.insert(text_parts, token.lexeme)
      end
    end
    parser:match(TokenType.RBRACKET)  -- Consume ]
    text = Node.text({ table.concat(text_parts, " ") }, start_pos)
  else
    -- No brackets - just parse as text until divert or newline
    local text_parts = {}
    while not parser:check_any(TokenType.DIVERT, TokenType.NEWLINE, TokenType.EOF) do
      local token = parser:advance()
      if token.lexeme and #token.lexeme > 0 then
        table.insert(text_parts, token.lexeme)
      end
    end
    if #text_parts > 0 then
      text = Node.text({ table.concat(text_parts, " ") }, start_pos)
    end
  end

  -- Check for optional divert -> target
  if parser:check(TokenType.DIVERT) then
    parser:advance()  -- Consume ->
    local target_token = parser:expect(TokenType.IDENTIFIER, "Expected passage name after '->'")
    if target_token then
      target = Node.divert(target_token.literal, {}, target_token.pos)
    end
  end

  parser:match(TokenType.NEWLINE)

  return Node.choice(text, condition, target, {}, false, start_pos)
end

--- Parse assignment statement (placeholder for Stage 18)
-- @param parser Parser Parser instance
-- @return table AssignmentNode or nil
function M.parse_assignment(parser)
  local start_pos = parser:peek().pos
  parser:advance()  -- Consume ~

  -- Expect variable
  local var_token = parser:expect(TokenType.VARIABLE, "Expected variable")
  if not var_token then
    parser:synchronize_statement()
    return nil
  end

  local variable = Node.variable_ref(var_token.literal, nil, var_token.pos)

  -- Expect operator
  local op = "="
  if parser:match(TokenType.EQ) then op = "="
  elseif parser:match(TokenType.PLUS_EQ) then op = "+="
  elseif parser:match(TokenType.MINUS_EQ) then op = "-="
  elseif parser:match(TokenType.STAR_EQ) then op = "*="
  elseif parser:match(TokenType.SLASH_EQ) then op = "/="
  else
    parser:error_at_current("Expected assignment operator")
    parser:synchronize_statement()
    return nil
  end

  -- Parse value expression (simplified)
  local value = M.parse_expression(parser)
  if not value then
    parser:synchronize_statement()
    return nil
  end

  parser:match(TokenType.NEWLINE)
  return Node.assignment(variable, op, value, start_pos)
end

--- Parse conditional statement (placeholder for Stage 17)
-- @param parser Parser Parser instance
-- @return table ConditionalNode or nil
function M.parse_conditional(parser)
  local start_pos = parser:peek().pos
  parser:advance()  -- Consume 'if'

  -- Parse condition
  local condition = M.parse_expression(parser)
  if not condition then
    parser:synchronize_statement()
    return nil
  end

  parser:match(TokenType.NEWLINE)

  -- Parse then body
  local then_body = {}
  if parser:check(TokenType.INDENT) then
    parser:advance()
    while not parser:check_any(TokenType.DEDENT, TokenType.EOF) do
      if parser:check_any(TokenType.NEWLINE, TokenType.COMMENT) then
        parser:advance()
      else
        local stmt = M.parse_statement(parser)
        if stmt then table.insert(then_body, stmt) end
      end
    end
    parser:match(TokenType.DEDENT)
  end

  return Node.conditional(condition, then_body, {}, nil, start_pos)
end

--- Parse expression (simplified for now)
-- @param parser Parser Parser instance
-- @return table Expression node or nil
function M.parse_expression(parser)
  return M.parse_comparison(parser)
end

--- Parse comparison expression
function M.parse_comparison(parser)
  local left = M.parse_term(parser)
  if not left then return nil end

  while parser:check_any(TokenType.EQ_EQ, TokenType.BANG_EQ, TokenType.LT, TokenType.GT, TokenType.LT_EQ, TokenType.GT_EQ) do
    local op = parser:advance().lexeme
    local right = M.parse_term(parser)
    if not right then return nil end
    left = Node.binary_expr(op, left, right, left.pos)
  end

  return left
end

--- Parse term (add/subtract)
function M.parse_term(parser)
  local left = M.parse_factor(parser)
  if not left then return nil end

  while parser:check_any(TokenType.PLUS, TokenType.MINUS) do
    local op = parser:advance().lexeme
    local right = M.parse_factor(parser)
    if not right then return nil end
    left = Node.binary_expr(op, left, right, left.pos)
  end

  return left
end

--- Parse factor (multiply/divide)
function M.parse_factor(parser)
  local left = M.parse_unary(parser)
  if not left then return nil end

  while parser:check_any(TokenType.STAR, TokenType.SLASH, TokenType.PERCENT) do
    local op = parser:advance().lexeme
    local right = M.parse_unary(parser)
    if not right then return nil end
    left = Node.binary_expr(op, left, right, left.pos)
  end

  return left
end

--- Parse unary expression
function M.parse_unary(parser)
  if parser:check_any(TokenType.MINUS, TokenType.NOT) then
    local op = parser:advance().lexeme
    local operand = M.parse_unary(parser)
    if not operand then return nil end
    return Node.unary_expr(op, operand, parser:previous().pos)
  end

  return M.parse_primary(parser)
end

--- Parse primary expression
function M.parse_primary(parser)
  local start_pos = parser:peek().pos

  if parser:check(TokenType.NUMBER) then
    local token = parser:advance()
    return Node.literal(token.literal, "number", start_pos)
  elseif parser:check(TokenType.STRING) then
    local token = parser:advance()
    return Node.literal(token.literal, "string", start_pos)
  elseif parser:check(TokenType.TRUE) then
    parser:advance()
    return Node.literal(true, "boolean", start_pos)
  elseif parser:check(TokenType.FALSE) then
    parser:advance()
    return Node.literal(false, "boolean", start_pos)
  elseif parser:check(TokenType.NULL) then
    parser:advance()
    return Node.literal(nil, "null", start_pos)
  elseif parser:check(TokenType.VARIABLE) then
    local token = parser:advance()
    return Node.variable_ref(token.literal, nil, start_pos)
  elseif parser:check(TokenType.IDENTIFIER) then
    local token = parser:advance()
    -- Check for function call
    if parser:check(TokenType.LPAREN) then
      return M.parse_function_call(parser, token.literal, start_pos)
    end
    return Node.literal(token.literal, "string", start_pos)
  elseif parser:check(TokenType.LPAREN) then
    parser:advance()
    local expr = M.parse_expression(parser)
    parser:expect(TokenType.RPAREN, "Expected ')'")
    return expr
  else
    return nil
  end
end

--- Parse function call
function M.parse_function_call(parser, name, start_pos)
  parser:expect(TokenType.LPAREN, "Expected '('")

  local args = {}
  if not parser:check(TokenType.RPAREN) then
    local arg = M.parse_expression(parser)
    if arg then table.insert(args, arg) end

    while parser:match(TokenType.COMMA) do
      arg = M.parse_expression(parser)
      if arg then table.insert(args, arg) end
    end
  end

  parser:expect(TokenType.RPAREN, "Expected ')'")
  return Node.function_call(name, args, start_pos)
end

--- Parse simple text line
-- @param parser Parser Parser instance
-- @return table TextNode or nil
function M.parse_text_line(parser)
  local start_pos = parser:peek().pos
  local segments = {}

  -- Collect tokens until newline or significant token
  while not parser:check_any(TokenType.NEWLINE, TokenType.DEDENT, TokenType.EOF) do
    local token = parser:peek()

    -- Handle inline expressions {expr}
    if parser:check(TokenType.LBRACE) then
      -- Will be implemented in Stage 15
      parser:advance()
      while not parser:check_any(TokenType.RBRACE, TokenType.NEWLINE, TokenType.EOF) do
        parser:advance()
      end
      parser:match(TokenType.RBRACE)
    else
      -- Add token text to segments
      if token.lexeme and #token.lexeme > 0 then
        table.insert(segments, token.lexeme)
      end
      parser:advance()
    end
  end

  -- Consume newline
  parser:match(TokenType.NEWLINE)

  if #segments > 0 then
    return Node.text({ table.concat(segments, " ") }, start_pos)
  end

  return nil
end

--- Parse divert statement
-- @param parser Parser Parser instance
-- @return table DivertNode or nil
function M.parse_divert(parser)
  local start_pos = parser:peek().pos

  parser:expect(TokenType.DIVERT, "Expected '->'")

  local target_token = parser:expect(TokenType.IDENTIFIER, "Expected passage name")
  if not target_token then
    parser:synchronize_statement()
    return nil
  end

  parser:match(TokenType.NEWLINE)

  return Node.divert(target_token.literal, {}, start_pos)
end

--- Module metadata
M._whisker = {
  name = "script.parser.grammar",
  version = "0.1.0",
  description = "Grammar rules for Whisker Script parser",
  depends = { "script.lexer.tokens", "script.parser.ast", "script.errors.codes" },
  capability = "script.parser.grammar"
}

return M
