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
-- @return any Parsed value
function M.parse_metadata_value(parser)
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
  elseif parser:check(TokenType.IDENTIFIER) then
    return parser:advance().literal
  elseif parser:check(TokenType.LBRACKET) then
    return M.parse_metadata_list(parser)
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

  -- Parse first item
  local item = M.parse_metadata_value(parser)
  if item ~= nil then
    table.insert(items, item)
  end

  -- Parse remaining items
  while parser:match(TokenType.COMMA) do
    item = M.parse_metadata_value(parser)
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

--- Parse passage body (indented statements)
-- @param parser Parser Parser instance
-- @return table Array of statement nodes
function M.parse_passage_body(parser)
  local body = {}

  parser:enter_context("in_passage")

  -- Check for INDENT to start body
  if not parser:check(TokenType.INDENT) then
    parser:leave_context("in_passage")
    return body
  end

  parser:advance()  -- Consume INDENT

  -- Parse statements until DEDENT or EOF
  while not parser:check_any(TokenType.DEDENT, TokenType.EOF, TokenType.PASSAGE_DECL) do
    -- Skip blank lines
    if parser:check(TokenType.NEWLINE) then
      parser:advance()
    elseif parser:check(TokenType.COMMENT) then
      parser:advance()
    else
      -- Parse statement (placeholder - full implementation in later stages)
      local stmt = M.parse_statement(parser)
      if stmt then
        table.insert(body, stmt)
      else
        -- Error recovery
        parser:synchronize_statement()
      end
    end
  end

  -- Consume DEDENT if present
  parser:match(TokenType.DEDENT)

  parser:leave_context("in_passage")

  return body
end

-- ============================================
-- Statement Parsing (Placeholder)
-- ============================================

--- Parse a single statement
-- @param parser Parser Parser instance
-- @return table Statement node or nil
function M.parse_statement(parser)
  -- For now, parse simple text or skip to next line
  -- Full implementation in Stages 13-18

  if parser:check(TokenType.DIVERT) then
    return M.parse_divert(parser)
  elseif parser:check(TokenType.PLUS) then
    -- Choice - will be implemented in Stage 14
    parser:synchronize_statement()
    return nil
  elseif parser:check(TokenType.ASSIGN) then
    -- Assignment - will be implemented in Stage 18
    parser:synchronize_statement()
    return nil
  elseif parser:check(TokenType.IDENTIFIER) then
    -- Could be text or function call
    return M.parse_text_line(parser)
  else
    -- Treat as text
    return M.parse_text_line(parser)
  end
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
