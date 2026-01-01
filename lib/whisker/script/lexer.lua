-- Whisker Script Lexer
-- Converts source text into a stream of tokens
--
-- lib/whisker/script/lexer.lua

--------------------------------------------------------------------------------
-- Token Class
--------------------------------------------------------------------------------

---@class Token
---@field type string Token type (e.g., "IDENTIFIER", "NUMBER", "PASSAGE_MARKER")
---@field value any Token value (string, number, boolean, or nil)
---@field line number Line number (1-indexed)
---@field column number Column number (1-indexed)
---@field length number Token length in characters
---@field raw string Original source text of token

local Token = {}
Token._dependencies = {}
Token.__index = Token

--- Create a new token
---@param type string Token type
---@param value any Token value
---@param line number Line number
---@param column number Column number
---@param raw string Original text
---@return Token
function Token.new(type, value, line, column, raw)
  local self = setmetatable({}, Token)
  self.type = type
  self.value = value
  self.line = line
  self.column = column
  self.length = #raw
  self.raw = raw
  return self
end

--- Convert token to string (for debugging)
function Token:__tostring()
  local val = self.value
  if val == nil then
    val = self.raw
  end
  return string.format(
    "Token(%s, %q) at %d:%d",
    self.type,
    tostring(val),
    self.line,
    self.column
  )
end

--------------------------------------------------------------------------------
-- Character Classification Helpers
--------------------------------------------------------------------------------

local function is_alpha(char)
  if not char then return false end
  return char:match("[A-Za-z_]") ~= nil
end

local function is_digit(char)
  if not char then return false end
  return char:match("[0-9]") ~= nil
end

local function is_alphanumeric(char)
  return is_alpha(char) or is_digit(char)
end

local function is_whitespace(char)
  if not char then return false end
  return char == " " or char == "\t" or char == "\r"
end

local function is_newline(char)
  return char == "\n"
end

--------------------------------------------------------------------------------
-- Lexer Class
--------------------------------------------------------------------------------

local Lexer = {}
Lexer.__index = Lexer

--- Create a new lexer for the given source
---@param source string Source code to tokenize
---@param filename string|nil Optional filename for error messages
---@return Lexer
function Lexer.new(source, filename)
  local self = setmetatable({}, Lexer)

  -- Source text (normalize line endings)
  self.source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
  self.filename = filename or "<input>"

  -- Position tracking
  self.pos = 1          -- Current position in source (1-indexed)
  self.line = 1         -- Current line number (1-indexed)
  self.column = 1       -- Current column number (1-indexed)

  -- Token start position (saved before scanning each token)
  self.start_pos = 1
  self.start_line = 1
  self.start_column = 1

  -- Tokens produced
  self.tokens = {}

  -- Error list
  self.errors = {}

  return self
end

--- Check if at end of source
---@return boolean
function Lexer:is_at_end()
  return self.pos > #self.source
end

--- Peek at current character without consuming
---@param offset number|nil Offset from current position (default 0)
---@return string|nil Character or nil if at end
function Lexer:peek(offset)
  offset = offset or 0
  local index = self.pos + offset
  if index > #self.source or index < 1 then
    return nil
  end
  return self.source:sub(index, index)
end

--- Consume and return current character
---@return string|nil Character or nil if at end
function Lexer:advance()
  if self:is_at_end() then
    return nil
  end

  local char = self.source:sub(self.pos, self.pos)
  self.pos = self.pos + 1

  -- Update position tracking
  if char == "\n" then
    self.line = self.line + 1
    self.column = 1
  else
    self.column = self.column + 1
  end

  return char
end

--- Check if current character matches expected, consume if so
---@param expected string Expected character
---@return boolean
function Lexer:match(expected)
  if self:is_at_end() then
    return false
  end
  if self:peek() ~= expected then
    return false
  end
  self:advance()
  return true
end

--- Check if current sequence matches expected string
---@param expected string Expected string
---@return boolean
function Lexer:match_string(expected)
  local len = #expected
  if self.pos + len - 1 > #self.source then
    return false
  end
  if self.source:sub(self.pos, self.pos + len - 1) ~= expected then
    return false
  end
  -- Consume all characters
  for _ = 1, len do
    self:advance()
  end
  return true
end

--- Check if upcoming sequence matches expected string (without consuming)
---@param expected string Expected string
---@return boolean
function Lexer:check_string(expected)
  local len = #expected
  if self.pos + len - 1 > #self.source then
    return false
  end
  return self.source:sub(self.pos, self.pos + len - 1) == expected
end

--- Consume characters while predicate is true
---@param predicate function(char: string): boolean
---@return string Consumed text
function Lexer:consume_while(predicate)
  local start = self.pos
  while not self:is_at_end() and predicate(self:peek()) do
    self:advance()
  end
  return self.source:sub(start, self.pos - 1)
end

--- Save current position as token start
function Lexer:mark_start()
  self.start_pos = self.pos
  self.start_line = self.line
  self.start_column = self.column
end

--- Get text from start position to current position
---@return string
function Lexer:get_text_from_start()
  return self.source:sub(self.start_pos, self.pos - 1)
end

--------------------------------------------------------------------------------
-- Token Emission
--------------------------------------------------------------------------------

--- Create and add a token to the token stream
---@param type string Token type
---@param value any Token value (optional)
function Lexer:emit_token(type, value)
  local raw = self:get_text_from_start()
  local token = Token.new(type, value, self.start_line, self.start_column, raw)
  table.insert(self.tokens, token)
end

--- Add an error token
---@param message string Error message
function Lexer:emit_error(message)
  local token = Token.new("ERROR", message, self.start_line, self.start_column, "")
  table.insert(self.tokens, token)
  table.insert(self.errors, {
    message = message,
    line = self.start_line,
    column = self.start_column
  })
end

--------------------------------------------------------------------------------
-- Token Recognition (Stages 04-05 will fill these in)
--------------------------------------------------------------------------------

--- Skip whitespace (not newlines)
function Lexer:skip_whitespace()
  self:consume_while(is_whitespace)
end

--- Scan a line comment (// ...)
---@return boolean true if comment was scanned
function Lexer:scan_line_comment()
  if not self:check_string("//") then
    return false
  end
  self:mark_start()
  self:match_string("//")
  -- Consume until newline (but don't consume the newline)
  self:consume_while(function(c) return c ~= "\n" end)
  -- Don't emit comment tokens (they're ignored)
  return true
end

--- Scan a block comment (/* ... */)
---@return boolean true if comment was scanned
function Lexer:scan_block_comment()
  if not self:check_string("/*") then
    return false
  end
  self:mark_start()
  self:match_string("/*")

  -- Find closing */
  while not self:is_at_end() do
    if self:check_string("*/") then
      self:match_string("*/")
      return true
    end
    self:advance()
  end

  -- Unclosed block comment
  self:emit_error("unterminated block comment")
  return true
end

--- Scan an identifier
---@return string|nil identifier or nil
function Lexer:scan_identifier()
  if not is_alpha(self:peek()) then
    return nil
  end
  self:mark_start()
  local ident = self:consume_while(is_alphanumeric)
  return ident
end

--- Scan a number literal
---@return number|nil
function Lexer:scan_number()
  if not is_digit(self:peek()) then
    return nil
  end
  self:mark_start()

  -- Integer part
  local num_str = self:consume_while(is_digit)

  -- Decimal part
  if self:peek() == "." and is_digit(self:peek(1)) then
    self:advance() -- consume '.'
    num_str = num_str .. "." .. self:consume_while(is_digit)
  end

  return tonumber(num_str)
end

--- Scan a string literal
---@return string|nil parsed string or nil, boolean success
function Lexer:scan_string()
  if self:peek() ~= '"' then
    return nil, false
  end
  self:mark_start()
  self:advance() -- consume opening quote

  local chars = {}
  while not self:is_at_end() do
    local char = self:peek()

    if char == '"' then
      self:advance() -- consume closing quote
      return table.concat(chars), true
    elseif char == "\n" then
      self:emit_error("unterminated string (newline in string)")
      return nil, false
    elseif char == "\\" then
      -- Escape sequence
      self:advance() -- consume backslash
      local escape_char = self:advance()
      if escape_char == "n" then
        table.insert(chars, "\n")
      elseif escape_char == "t" then
        table.insert(chars, "\t")
      elseif escape_char == "r" then
        table.insert(chars, "\r")
      elseif escape_char == "\\" then
        table.insert(chars, "\\")
      elseif escape_char == '"' then
        table.insert(chars, '"')
      elseif escape_char == "{" then
        table.insert(chars, "{")
      elseif escape_char == "}" then
        table.insert(chars, "}")
      elseif escape_char == "$" then
        table.insert(chars, "$")
      else
        -- Unknown escape, include as-is
        table.insert(chars, "\\" .. (escape_char or ""))
      end
    else
      table.insert(chars, char)
      self:advance()
    end
  end

  self:emit_error("unterminated string")
  return nil, false
end

--- Scan embedded Lua code {{ ... }}
---@return string|nil lua code or nil
function Lexer:scan_lua_block()
  if not self:check_string("{{") then
    return nil
  end
  self:mark_start()
  self:match_string("{{")

  local start_pos = self.pos
  local depth = 1

  while not self:is_at_end() and depth > 0 do
    if self:check_string("{{") then
      self:match_string("{{")
      depth = depth + 1
    elseif self:check_string("}}") then
      depth = depth - 1
      if depth == 0 then
        local code = self.source:sub(start_pos, self.pos - 1)
        self:match_string("}}")
        return code
      end
      self:match_string("}}")
    else
      self:advance()
    end
  end

  self:emit_error("unterminated Lua block (expected }})")
  return nil
end

--------------------------------------------------------------------------------
-- Main Tokenization
--------------------------------------------------------------------------------

--- Tokenize the entire source
---@return Token[] Tokens (including ERROR tokens if any)
function Lexer:tokenize()
  while not self:is_at_end() do
    self:scan_token()
  end

  -- Add EOF token
  self:mark_start()
  self:emit_token("EOF", nil)

  return self.tokens
end

--- Scan a single token
function Lexer:scan_token()
  -- Skip whitespace (but not newlines)
  self:skip_whitespace()

  if self:is_at_end() then
    return
  end

  -- Skip comments
  if self:scan_line_comment() then
    return
  end
  if self:scan_block_comment() then
    return
  end

  -- Skip whitespace again (in case comment consumed spaces)
  self:skip_whitespace()

  if self:is_at_end() then
    return
  end

  self:mark_start()
  local char = self:peek()

  -- Newline
  if char == "\n" then
    self:advance()
    self:emit_token("NEWLINE", nil)
    return
  end

  -- Multi-character tokens (check longest first)
  if self:check_string("::") then
    self:match_string("::")
    self:emit_token("PASSAGE_MARKER", nil)
    return
  end

  if self:check_string("->") then
    self:match_string("->")
    self:emit_token("ARROW", nil)
    return
  end

  if self:check_string("{{") then
    local code = self:scan_lua_block()
    if code then
      self:emit_token("LUA_BLOCK", code)
    end
    return
  end

  if self:check_string("==") then
    self:match_string("==")
    self:emit_token("EQ", nil)
    return
  end

  -- WLS 1.0: Use ~= for not-equal (Lua-style)
  if self:check_string("~=") then
    self:match_string("~=")
    self:emit_token("NEQ", nil)
    return
  end

  -- WLS 1.0: Reject C-style != with helpful error
  if self:check_string("!=") then
    self:match_string("!=")
    self:emit_error("Use '~=' instead of '!=' for not-equal (WLS 1.0 uses Lua-style operators)")
    return
  end

  if self:check_string("<=") then
    self:match_string("<=")
    self:emit_token("LTE", nil)
    return
  end

  if self:check_string(">=") then
    self:match_string(">=")
    self:emit_token("GTE", nil)
    return
  end

  -- WLS 1.0: Reject C-style && with helpful error (use 'and' instead)
  if self:check_string("&&") then
    self:match_string("&&")
    self:emit_error("Use 'and' instead of '&&' (WLS 1.0 uses Lua-style operators)")
    return
  end

  -- WLS 1.0: Reject C-style || with helpful error (use 'or' instead)
  if self:check_string("||") then
    self:match_string("||")
    self:emit_error("Use 'or' instead of '||' (WLS 1.0 uses Lua-style operators)")
    return
  end

  if self:check_string("+=") then
    self:match_string("+=")
    self:emit_token("PLUS_ASSIGN", nil)
    return
  end

  if self:check_string("-=") then
    self:match_string("-=")
    self:emit_token("MINUS_ASSIGN", nil)
    return
  end

  -- Single character tokens
  if char == "+" then
    self:advance()
    self:emit_token("PLUS", nil)
    return
  end

  if char == "-" then
    self:advance()
    self:emit_token("MINUS", nil)
    return
  end

  if char == "{" then
    self:advance()
    self:emit_token("LBRACE", nil)
    return
  end

  if char == "}" then
    self:advance()
    self:emit_token("RBRACE", nil)
    return
  end

  if char == "[" then
    self:advance()
    self:emit_token("LBRACKET", nil)
    -- Now consume text content until ]
    self:skip_whitespace()
    if not self:is_at_end() and self:peek() ~= "]" then
      self:mark_start()
      local text_chars = {}
      while not self:is_at_end() and self:peek() ~= "]" do
        table.insert(text_chars, self:peek())
        self:advance()
      end
      local text = table.concat(text_chars)
      -- Trim trailing whitespace
      text = text:gsub("%s+$", "")
      if #text > 0 then
        self:emit_token("TEXT", text)
      end
    end
    -- Now emit the close bracket
    if self:peek() == "]" then
      self:mark_start()
      self:advance()
      self:emit_token("RBRACKET", nil)
    end
    return
  end

  if char == "]" then
    self:advance()
    self:emit_token("RBRACKET", nil)
    return
  end

  if char == "(" then
    self:advance()
    self:emit_token("LPAREN", nil)
    return
  end

  if char == ")" then
    self:advance()
    self:emit_token("RPAREN", nil)
    return
  end

  if char == "/" then
    self:advance()
    self:emit_token("SLASH", nil)
    return
  end

  if char == "$" then
    self:advance()
    self:emit_token("DOLLAR", nil)
    return
  end

  if char == "=" then
    self:advance()
    self:emit_token("ASSIGN", nil)
    return
  end

  if char == "<" then
    self:advance()
    self:emit_token("LT", nil)
    return
  end

  if char == ">" then
    self:advance()
    self:emit_token("GT", nil)
    return
  end

  -- WLS 1.0: Reject C-style ! with helpful error (use 'not' instead)
  if char == "!" then
    self:advance()
    self:emit_error("Use 'not' instead of '!' (WLS 1.0 uses Lua-style operators)")
    return
  end

  -- String literal
  if char == '"' then
    local str, ok = self:scan_string()
    if ok then
      self:emit_token("STRING", str)
    end
    return
  end

  -- Number literal
  if is_digit(char) then
    local num = self:scan_number()
    self:emit_token("NUMBER", num)
    return
  end

  -- Identifier or keyword
  if is_alpha(char) then
    local ident = self:scan_identifier()
    -- Check for keywords
    if ident == "true" then
      self:emit_token("TRUE", true)
    elseif ident == "false" then
      self:emit_token("FALSE", false)
    -- WLS 1.0: Lua-style logical operators as keywords
    elseif ident == "and" then
      self:emit_token("AND", nil)
    elseif ident == "or" then
      self:emit_token("OR", nil)
    elseif ident == "not" then
      self:emit_token("NOT", nil)
    else
      self:emit_token("IDENTIFIER", ident)
    end
    return
  end

  -- Text content (anything else)
  -- Consume until we hit a special character
  local text_chars = {}
  while not self:is_at_end() do
    local c = self:peek()

    -- Check for escape sequences in text
    if c == "\\" then
      self:advance()
      local escape = self:advance()
      if escape == "{" or escape == "}" or escape == "$" or escape == "\\" then
        table.insert(text_chars, escape)
      elseif escape == "n" then
        table.insert(text_chars, "\n")
      elseif escape == "t" then
        table.insert(text_chars, "\t")
      else
        table.insert(text_chars, "\\" .. (escape or ""))
      end
    -- Stop at special markers
    elseif c == "\n" or c == ":" or c == "+" or c == "{" or c == "$"
        or c == "[" or c == "]" or c == "/" then
      -- Check for :: specifically (single : is okay in text)
      if c == ":" and self:peek(1) == ":" then
        break
      elseif c == ":" then
        table.insert(text_chars, c)
        self:advance()
      elseif c == "/" and (self:peek(1) == "/" or self:peek(1) == "*") then
        break
      elseif c == "/" then
        table.insert(text_chars, c)
        self:advance()
      else
        break
      end
    else
      table.insert(text_chars, c)
      self:advance()
    end
  end

  if #text_chars > 0 then
    local text = table.concat(text_chars)
    -- Trim trailing whitespace from text
    text = text:gsub("%s+$", "")
    if #text > 0 then
      self:emit_token("TEXT", text)
    end
  end
end

--------------------------------------------------------------------------------
-- Module Exports
--------------------------------------------------------------------------------

return {
  Token = Token,
  Lexer = Lexer,

  -- Character classification (for external use if needed)
  is_alpha = is_alpha,
  is_digit = is_digit,
  is_alphanumeric = is_alphanumeric,
  is_whitespace = is_whitespace,
  is_newline = is_newline,
}
