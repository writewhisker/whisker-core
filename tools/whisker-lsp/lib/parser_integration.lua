-- whisker-lsp/lib/parser_integration.lua
-- Integration with whisker-core parsers

local ParserIntegration = {}
ParserIntegration.__index = ParserIntegration

-- Try to load whisker parsers
local whisker_parser, lexer
local parser_available = false

local ok, parser = pcall(require, "whisker.parser.parser")
if ok then
  whisker_parser = parser
  parser_available = true
end

ok, lexer = pcall(require, "whisker.parser.lexer")
if not ok then
  lexer = nil
end

--- Create a new parser integration instance
--- @return table ParserIntegration instance
function ParserIntegration.new()
  local self = setmetatable({}, ParserIntegration)
  self.ast_cache = {}  -- uri -> {ast, version}
  return self
end

--- Parse a document
--- @param uri string Document URI
--- @param text string Document content
--- @param format string? File format (ink, wscript, twee)
--- @return table Parse result {success, ast, errors, warnings}
function ParserIntegration:parse(uri, text, format)
  format = format or self:detect_format(uri)

  local result = {
    success = false,
    ast = nil,
    errors = {},
    warnings = {},
    passages = {},
    variables = {}
  }

  if parser_available then
    -- Use actual parser
    local parse_result = self:parse_with_whisker(text, format)
    result.success = parse_result.success
    result.ast = parse_result.story
    result.errors = parse_result.errors or {}
    result.warnings = parse_result.warnings or {}

    if result.ast then
      result.passages = self:extract_passages(result.ast)
      result.variables = self:extract_variables(result.ast)
    end
  else
    -- Fallback: basic line-based parsing
    result = self:parse_basic(text, format)
    result.success = #result.errors == 0
  end

  -- Cache the result
  self.ast_cache[uri] = {
    ast = result.ast,
    errors = result.errors,
    warnings = result.warnings,
    passages = result.passages,
    variables = result.variables
  }

  return result
end

--- Parse using whisker parser
--- @param text string Document content
--- @param format string File format
--- @return table Parse result
function ParserIntegration:parse_with_whisker(text, format)
  if not parser_available then
    return { success = false, errors = {{ message = "Parser not available" }} }
  end

  -- Tokenize
  local tokens = {}
  if lexer then
    local lex = lexer.new()
    local lex_result = lex:tokenize(text)
    tokens = lex_result.tokens or {}
  end

  -- Parse
  local parser_instance = whisker_parser.new()
  return parser_instance:parse(tokens)
end

--- Basic line-based parsing (fallback)
--- @param text string Document content
--- @param format string File format
--- @return table Parse result
function ParserIntegration:parse_basic(text, format)
  local result = {
    success = true,
    ast = nil,
    errors = {},
    warnings = {},
    passages = {},
    variables = {}
  }

  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  local current_passage = nil

  for i, line in ipairs(lines) do
    -- Detect passage headers
    local passage_name = line:match("^===+%s*([%w_]+)%s*===+")
    if passage_name then
      current_passage = {
        name = passage_name,
        line = i - 1,  -- 0-based
        column = 0,
        tags = {},
        description = ""
      }
      result.passages[#result.passages + 1] = current_passage
    end

    -- Detect passage references (diverts)
    for target in line:gmatch("%->%s*([%w_]+)") do
      -- Track for validation later
    end

    -- Detect variable assignments (basic)
    local var_name = line:match("^%s*~%s*([%w_]+)%s*=")
    if var_name then
      result.variables[#result.variables + 1] = {
        name = var_name,
        line = i - 1,
        column = 0,
        type = "unknown"
      }
    end

    -- Detect choices
    local choice_text = line:match("^%s*[*+]%s*%[(.-)%]")
    if choice_text and current_passage then
      -- Track choice
    end
  end

  return result
end

--- Get cached AST for document
--- @param uri string Document URI
--- @return table|nil AST or nil if not cached
function ParserIntegration:get_ast(uri)
  local cached = self.ast_cache[uri]
  return cached and cached.ast
end

--- Invalidate cached AST
--- @param uri string Document URI
--- @return boolean Success
function ParserIntegration:invalidate(uri)
  self.ast_cache[uri] = nil
  return true
end

--- Get passages from cached parse
--- @param uri string Document URI
--- @return table Array of passages
function ParserIntegration:get_passages(uri)
  local cached = self.ast_cache[uri]
  return cached and cached.passages or {}
end

--- Get variables from cached parse
--- @param uri string Document URI
--- @return table Array of variables
function ParserIntegration:get_variables(uri)
  local cached = self.ast_cache[uri]
  return cached and cached.variables or {}
end

--- Get errors from cached parse
--- @param uri string Document URI
--- @return table Array of errors
function ParserIntegration:get_errors(uri)
  local cached = self.ast_cache[uri]
  return cached and cached.errors or {}
end

--- Get warnings from cached parse
--- @param uri string Document URI
--- @return table Array of warnings
function ParserIntegration:get_warnings(uri)
  local cached = self.ast_cache[uri]
  return cached and cached.warnings or {}
end

--- Extract passages from AST
--- @param ast table Parsed AST
--- @return table Array of passages
function ParserIntegration:extract_passages(ast)
  local passages = {}

  if not ast or not ast.passages then
    return passages
  end

  for name, passage in pairs(ast.passages) do
    passages[#passages + 1] = {
      name = name,
      line = passage.line or 0,
      column = passage.column or 0,
      tags = passage.tags or {},
      description = passage.description or ""
    }
  end

  return passages
end

--- Extract variables from AST
--- @param ast table Parsed AST
--- @return table Array of variables
function ParserIntegration:extract_variables(ast)
  local variables = {}

  if not ast or not ast.variables then
    return variables
  end

  for name, var in pairs(ast.variables) do
    variables[#variables + 1] = {
      name = name,
      line = var.line or 0,
      column = var.column or 0,
      type = var.type or "unknown",
      value = var.initial_value
    }
  end

  return variables
end

--- Find node at position
--- @param uri string Document URI
--- @param line number 0-based line number
--- @param col number 0-based column
--- @return table|nil Node information
function ParserIntegration:find_node_at_position(uri, line, col)
  local passages = self:get_passages(uri)
  local variables = self:get_variables(uri)

  -- Check passages
  for _, passage in ipairs(passages) do
    if passage.line == line then
      return {
        type = "passage",
        name = passage.name,
        passage = passage
      }
    end
  end

  -- Check variables
  for _, var in ipairs(variables) do
    if var.line == line then
      return {
        type = "variable",
        name = var.name,
        variable = var
      }
    end
  end

  return nil
end

--- Detect file format from URI
--- @param uri string Document URI
--- @return string Format identifier
function ParserIntegration:detect_format(uri)
  local ext = uri:match("%.([^%.]+)$")
  if ext then
    ext = ext:lower()
    if ext == "ink" then
      return "ink"
    elseif ext == "wscript" then
      return "wscript"
    elseif ext == "twee" then
      return "twee"
    end
  end
  return "whisker"
end

--- Check if parser is available
--- @return boolean
function ParserIntegration:is_parser_available()
  return parser_available
end

return ParserIntegration
