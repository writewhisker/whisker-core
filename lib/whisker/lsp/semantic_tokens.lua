--- LSP Semantic Tokens Provider
-- Provides semantic tokens for enhanced syntax highlighting in WLS documents
-- @module whisker.lsp.semantic_tokens
-- @author Whisker Core Team
-- @license MIT

local SemanticTokens = {}
SemanticTokens.__index = SemanticTokens
SemanticTokens._dependencies = {}

-- Standard token types (must match client registration)
SemanticTokens.TOKEN_TYPES = {
  "namespace",      -- 0: passage names
  "type",           -- 1
  "class",          -- 2
  "enum",           -- 3
  "interface",      -- 4
  "struct",         -- 5
  "typeParameter",  -- 6
  "parameter",      -- 7
  "variable",       -- 8: variables
  "property",       -- 9: directives
  "enumMember",     -- 10
  "event",          -- 11
  "function",       -- 12: functions
  "method",         -- 13
  "macro",          -- 14
  "keyword",        -- 15: INCLUDE, NAMESPACE, etc.
  "modifier",       -- 16: choice modifiers
  "comment",        -- 17: comments
  "string",         -- 18: strings
  "number",         -- 19: numbers
  "regexp",         -- 20
  "operator"        -- 21: ->, +, *, etc.
}

-- Token type indices (0-based)
SemanticTokens.TYPE_NAMESPACE = 0
SemanticTokens.TYPE_VARIABLE = 8
SemanticTokens.TYPE_PROPERTY = 9
SemanticTokens.TYPE_FUNCTION = 12
SemanticTokens.TYPE_KEYWORD = 15
SemanticTokens.TYPE_MODIFIER = 16
SemanticTokens.TYPE_COMMENT = 17
SemanticTokens.TYPE_STRING = 18
SemanticTokens.TYPE_NUMBER = 19
SemanticTokens.TYPE_OPERATOR = 21

-- Token modifiers
SemanticTokens.TOKEN_MODIFIERS = {
  "declaration",    -- 0
  "definition",     -- 1
  "readonly",       -- 2
  "static",         -- 3
  "deprecated",     -- 4
  "abstract",       -- 5
  "async",          -- 6
  "modification",   -- 7
  "documentation",  -- 8
  "defaultLibrary"  -- 9
}

-- Modifier bit flags
SemanticTokens.MOD_DECLARATION = 1
SemanticTokens.MOD_DEFINITION = 2
SemanticTokens.MOD_READONLY = 4

--- Create a new semantic tokens provider
-- @param options table Options with documents manager
-- @return SemanticTokens Provider instance
function SemanticTokens.new(options)
  options = options or {}
  local self = setmetatable({}, SemanticTokens)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function SemanticTokens:set_parser(parser)
  self._parser = parser
end

--- Get full semantic tokens for a document
-- @param uri string Document URI
-- @return table Semantic tokens result with data array
function SemanticTokens:get_full(uri)
  local doc = self._documents:get(uri)
  if not doc then
    return { data = {} }
  end

  local tokens = self:_extract_tokens(doc.content or "")
  local data = self:_encode_tokens(tokens)

  return { data = data }
end

--- Get semantic tokens legend for capability registration
-- @return table Legend with tokenTypes and tokenModifiers
function SemanticTokens:get_legend()
  return {
    tokenTypes = self.TOKEN_TYPES,
    tokenModifiers = self.TOKEN_MODIFIERS
  }
end

--- Extract tokens from content
-- @param content string Document content
-- @return table Array of tokens
function SemanticTokens:_extract_tokens(content)
  local tokens = {}
  local line_num = 0

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    local line_tokens = self:_extract_line_tokens(line, line_num)
    for _, token in ipairs(line_tokens) do
      table.insert(tokens, token)
    end
    line_num = line_num + 1
  end

  return tokens
end

--- Extract tokens from a single line
-- @param line string Line content
-- @param line_num number Line number (0-based)
-- @return table Array of tokens
function SemanticTokens:_extract_line_tokens(line, line_num)
  local tokens = {}

  -- Passage definition: :: Name or :: Name [tags]
  local passage_start, _, passage_name = line:find("^%s*::%s*([%w_%.]+)")
  if passage_name then
    local name_start = line:find(passage_name, 1, true)
    if name_start then
      table.insert(tokens, {
        line = line_num,
        start = name_start - 1,
        length = #passage_name,
        type = SemanticTokens.TYPE_NAMESPACE,
        modifiers = SemanticTokens.MOD_DEFINITION
      })
    end
  end

  -- Keywords: INCLUDE, NAMESPACE, END NAMESPACE, FUNCTION, END, RETURN
  local keywords = { "INCLUDE", "NAMESPACE", "FUNCTION", "END", "RETURN", "VAR", "LIST", "ARRAY", "MAP" }
  for _, keyword in ipairs(keywords) do
    local pos = 1
    while true do
      local kw_start, kw_end = line:find("%f[%w_]" .. keyword .. "%f[^%w_]", pos)
      if not kw_start then break end
      table.insert(tokens, {
        line = line_num,
        start = kw_start - 1,
        length = #keyword,
        type = SemanticTokens.TYPE_KEYWORD,
        modifiers = 0
      })
      pos = kw_end + 1
    end
  end

  -- Variable interpolation: $varname
  local pos = 1
  while true do
    local var_start, var_end, var_name = line:find("%$([%w_]+)", pos)
    if not var_start then break end
    table.insert(tokens, {
      line = line_num,
      start = var_start - 1,
      length = #var_name + 1, -- Include $
      type = SemanticTokens.TYPE_VARIABLE,
      modifiers = 0
    })
    pos = var_end + 1
  end

  -- Expression interpolation: ${...}
  pos = 1
  while true do
    local expr_start, expr_end = line:find("%${[^}]+}", pos)
    if not expr_start then break end
    -- Token the whole expression as variable type
    table.insert(tokens, {
      line = line_num,
      start = expr_start - 1,
      length = expr_end - expr_start + 1,
      type = SemanticTokens.TYPE_VARIABLE,
      modifiers = 0
    })
    pos = expr_end + 1
  end

  -- Navigation: -> Target
  pos = 1
  while true do
    local arrow_start, _, target = line:find("(%->[%s]*[%w_%.]+)", pos)
    if not arrow_start then break end
    -- Arrow operator
    table.insert(tokens, {
      line = line_num,
      start = arrow_start - 1,
      length = 2,
      type = SemanticTokens.TYPE_OPERATOR,
      modifiers = 0
    })
    -- Target passage name
    local target_name = target:match("->%s*([%w_%.]+)")
    if target_name then
      local target_start = line:find(target_name, arrow_start + 2, true)
      if target_start then
        table.insert(tokens, {
          line = line_num,
          start = target_start - 1,
          length = #target_name,
          type = SemanticTokens.TYPE_NAMESPACE,
          modifiers = 0
        })
      end
    end
    pos = arrow_start + #target
  end

  -- Directives: @name:
  pos = 1
  while true do
    local dir_start, dir_end, directive = line:find("@([%w_]+):", pos)
    if not dir_start then break end
    table.insert(tokens, {
      line = line_num,
      start = dir_start - 1,
      length = #directive + 2, -- Include @ and :
      type = SemanticTokens.TYPE_PROPERTY,
      modifiers = SemanticTokens.MOD_DECLARATION
    })
    pos = dir_end + 1
  end

  -- Choice markers: + or *
  local choice_start = line:find("^%s*([+*])%s")
  if choice_start then
    local marker_pos = line:find("[+*]")
    if marker_pos then
      table.insert(tokens, {
        line = line_num,
        start = marker_pos - 1,
        length = 1,
        type = SemanticTokens.TYPE_OPERATOR,
        modifiers = 0
      })
    end
  end

  -- Choice modifiers: (once), (sticky)
  for modifier in line:gmatch("%(once%)") do
    local mod_start = line:find("%(once%)")
    if mod_start then
      table.insert(tokens, {
        line = line_num,
        start = mod_start - 1,
        length = 6,
        type = SemanticTokens.TYPE_MODIFIER,
        modifiers = 0
      })
    end
  end
  for modifier in line:gmatch("%(sticky%)") do
    local mod_start = line:find("%(sticky%)")
    if mod_start then
      table.insert(tokens, {
        line = line_num,
        start = mod_start - 1,
        length = 8,
        type = SemanticTokens.TYPE_MODIFIER,
        modifiers = 0
      })
    end
  end

  -- Comments: // or --
  local comment_start = line:find("//")
  if not comment_start then
    comment_start = line:find("%-%-")
  end
  if comment_start then
    table.insert(tokens, {
      line = line_num,
      start = comment_start - 1,
      length = #line - comment_start + 1,
      type = SemanticTokens.TYPE_COMMENT,
      modifiers = 0
    })
  end

  -- String literals: "..." or '...'
  pos = 1
  while true do
    local str_start, str_end = line:find('"[^"]*"', pos)
    if not str_start then
      str_start, str_end = line:find("'[^']*'", pos)
    end
    if not str_start then break end
    table.insert(tokens, {
      line = line_num,
      start = str_start - 1,
      length = str_end - str_start + 1,
      type = SemanticTokens.TYPE_STRING,
      modifiers = 0
    })
    pos = str_end + 1
  end

  -- Numbers
  pos = 1
  while true do
    local num_start, num_end = line:find("%f[%w_]%-?%d+%.?%d*%f[^%w_]", pos)
    if not num_start then break end
    table.insert(tokens, {
      line = line_num,
      start = num_start - 1,
      length = num_end - num_start + 1,
      type = SemanticTokens.TYPE_NUMBER,
      modifiers = 0
    })
    pos = num_end + 1
  end

  -- Sort by position to ensure correct encoding
  table.sort(tokens, function(a, b)
    if a.line ~= b.line then
      return a.line < b.line
    end
    return a.start < b.start
  end)

  -- Remove overlapping tokens (keep first)
  local filtered = {}
  local last_end = -1
  for _, token in ipairs(tokens) do
    if token.start >= last_end then
      table.insert(filtered, token)
      last_end = token.start + token.length
    end
  end

  return filtered
end

--- Encode tokens to LSP format (delta encoding)
-- @param tokens table Array of tokens
-- @return table Array of encoded integers
function SemanticTokens:_encode_tokens(tokens)
  local data = {}
  local prev_line = 0
  local prev_start = 0

  for _, token in ipairs(tokens) do
    local delta_line = token.line - prev_line
    local delta_start = delta_line == 0 and (token.start - prev_start) or token.start

    table.insert(data, delta_line)
    table.insert(data, delta_start)
    table.insert(data, token.length)
    table.insert(data, token.type)
    table.insert(data, token.modifiers)

    prev_line = token.line
    prev_start = token.start
  end

  return data
end

return SemanticTokens
