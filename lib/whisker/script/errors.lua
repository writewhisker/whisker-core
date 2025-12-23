-- Whisker Script Error Formatting
-- Provides user-friendly error messages
--
-- lib/whisker/script/errors.lua

local Errors = {}

--------------------------------------------------------------------------------
-- ANSI Color Codes (for terminal output)
--------------------------------------------------------------------------------

local COLORS = {
  reset = "\27[0m",
  red = "\27[31m",
  yellow = "\27[33m",
  blue = "\27[34m",
  cyan = "\27[36m",
  bold = "\27[1m",
  dim = "\27[2m",
}

--- Check if colors should be used
---@return boolean
local function use_colors()
  -- Check TERM and NO_COLOR environment variables
  local term = os.getenv("TERM")
  local no_color = os.getenv("NO_COLOR")

  if no_color then
    return false
  end

  if term and (term:match("color") or term:match("xterm") or term:match("screen")) then
    return true
  end

  return false
end

--- Apply color if enabled
---@param text string Text to color
---@param color string Color name
---@return string
local function colorize(text, color)
  if use_colors() and COLORS[color] then
    return COLORS[color] .. text .. COLORS.reset
  end
  return text
end

--------------------------------------------------------------------------------
-- Source Context
--------------------------------------------------------------------------------

--- Get a line from source text
---@param source string Source text
---@param line_num number Line number (1-indexed)
---@return string|nil Line content
local function get_line(source, line_num)
  local current_line = 1
  local start_pos = 1

  for i = 1, #source do
    if current_line == line_num then
      -- Find end of this line
      local end_pos = source:find("\n", start_pos) or #source + 1
      return source:sub(start_pos, end_pos - 1)
    end

    if source:sub(i, i) == "\n" then
      current_line = current_line + 1
      start_pos = i + 1
    end
  end

  if current_line == line_num then
    return source:sub(start_pos)
  end

  return nil
end

--- Get lines around a position for context
---@param source string Source text
---@param line_num number Target line number
---@param context_lines number|nil Number of context lines (default 1)
---@return table Array of {line_num, content}
local function get_context_lines(source, line_num, context_lines)
  context_lines = context_lines or 1
  local lines = {}

  for i = math.max(1, line_num - context_lines), line_num + context_lines do
    local line = get_line(source, i)
    if line then
      table.insert(lines, { num = i, content = line })
    end
  end

  return lines
end

--------------------------------------------------------------------------------
-- Error Formatting
--------------------------------------------------------------------------------

--- Format an error message
---@param error table Error info {message, line, column}
---@param source string|nil Source text
---@param filename string|nil Filename
---@return string Formatted error message
function Errors.format_error(error, source, filename)
  local lines = {}
  filename = filename or "<input>"

  -- Error header
  local location = string.format("%s:%d:%d", filename, error.line or 0, error.column or 0)
  local header = colorize("error", "red") .. ": " ..
                 colorize(location, "bold") .. ": " ..
                 error.message

  table.insert(lines, header)

  -- Source context
  if source and error.line and error.line > 0 then
    local context = get_context_lines(source, error.line, 0)

    table.insert(lines, colorize("  |", "blue"))

    for _, ctx in ipairs(context) do
      local line_num = string.format("%3d", ctx.num)
      local prefix = colorize(line_num .. " |", "blue")

      if ctx.num == error.line then
        table.insert(lines, prefix .. " " .. ctx.content)

        -- Underline the error position
        if error.column and error.column > 0 then
          local pointer = string.rep(" ", error.column - 1) .. colorize("^", "red")
          table.insert(lines, colorize("    |", "blue") .. " " .. pointer)
        end
      else
        table.insert(lines, prefix .. " " .. colorize(ctx.content, "dim"))
      end
    end

    table.insert(lines, colorize("  |", "blue"))
  end

  -- Suggestion (if available)
  if error.suggestion then
    table.insert(lines, colorize("help", "cyan") .. ": " .. error.suggestion)
  end

  return table.concat(lines, "\n")
end

--- Format a warning message
---@param warning table Warning info {message, line, column}
---@param source string|nil Source text
---@param filename string|nil Filename
---@return string Formatted warning message
function Errors.format_warning(warning, source, filename)
  local lines = {}
  filename = filename or "<input>"

  local location = string.format("%s:%d:%d", filename, warning.line or 0, warning.column or 0)
  local header = colorize("warning", "yellow") .. ": " ..
                 colorize(location, "bold") .. ": " ..
                 warning.message

  table.insert(lines, header)

  return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Error Suggestions
--------------------------------------------------------------------------------

local ERROR_SUGGESTIONS = {
  ["expected passage name"] = "passage names must start with a letter or underscore",
  ["expected identifier"] = "use a valid name (letters, numbers, underscores)",
  ["expected ]"] = "check that your choice text has a closing bracket ]",
  ["expected ->"] = "choices need an arrow -> followed by target passage name",
  ["expected }"] = "check that your condition has a closing brace }",
  ["expected { / }"] = "conditional blocks need to be closed with { / }",
  ["unterminated string"] = "add a closing quote \" to your string",
  ["unterminated block comment"] = "add */ to close your block comment",
  ["expected expression"] = "conditions need an expression like $variable or $x > 5",
  ["expected value"] = "assignments need a value: $gold = 100",
}

--- Add suggestions to errors
---@param errors table[] Array of error objects
---@return table[] Errors with suggestions added
function Errors.add_suggestions(errors)
  for _, err in ipairs(errors) do
    local msg = err.message:lower()
    for pattern, suggestion in pairs(ERROR_SUGGESTIONS) do
      if msg:find(pattern:lower(), 1, true) then
        err.suggestion = suggestion
        break
      end
    end
  end
  return errors
end

--------------------------------------------------------------------------------
-- Error Recovery
--------------------------------------------------------------------------------

--- Determine the best recovery point after an error
---@param tokens table[] Token array
---@param pos number Current position
---@return number New position
function Errors.find_recovery_point(tokens, pos)
  -- Skip until we find a safe point to resume parsing
  while pos <= #tokens do
    local token = tokens[pos]

    -- Stop at structural boundaries
    if token.type == "PASSAGE_MARKER" then
      return pos
    end

    -- Stop at newline followed by structural element
    if token.type == "NEWLINE" then
      local next_token = tokens[pos + 1]
      if next_token then
        if next_token.type == "PASSAGE_MARKER" or
           next_token.type == "PLUS" or
           next_token.type == "LBRACE" or
           next_token.type == "DOLLAR" then
          return pos + 1
        end
      end
    end

    pos = pos + 1
  end

  return pos
end

--------------------------------------------------------------------------------
-- Error Categories
--------------------------------------------------------------------------------

Errors.CATEGORIES = {
  SYNTAX = "syntax",
  SEMANTIC = "semantic",
  WARNING = "warning",
}

--- Categorize an error
---@param message string Error message
---@return string Category
function Errors.categorize(message)
  local msg = message:lower()

  if msg:find("expected") or msg:find("unexpected") or
     msg:find("unterminated") or msg:find("invalid") then
    return Errors.CATEGORIES.SYNTAX
  end

  if msg:find("undefined") or msg:find("unknown passage") or
     msg:find("unreachable") then
    return Errors.CATEGORIES.SEMANTIC
  end

  return Errors.CATEGORIES.SYNTAX
end

--------------------------------------------------------------------------------
-- Summary Formatting
--------------------------------------------------------------------------------

--- Format a summary of all errors
---@param errors table[] Array of error objects
---@return string Summary text
function Errors.format_summary(errors)
  if #errors == 0 then
    return colorize("No errors found.", "cyan")
  end

  local syntax_count = 0
  local semantic_count = 0

  for _, err in ipairs(errors) do
    local cat = Errors.categorize(err.message)
    if cat == Errors.CATEGORIES.SYNTAX then
      syntax_count = syntax_count + 1
    else
      semantic_count = semantic_count + 1
    end
  end

  local parts = {}

  if #errors == 1 then
    table.insert(parts, colorize("1 error", "red"))
  else
    table.insert(parts, colorize(#errors .. " errors", "red"))
  end

  if syntax_count > 0 and semantic_count > 0 then
    table.insert(parts, string.format("(%d syntax, %d semantic)", syntax_count, semantic_count))
  end

  return table.concat(parts, " ")
end

--------------------------------------------------------------------------------
-- Validation Errors
--------------------------------------------------------------------------------

--- Validate a program AST and collect semantic errors
---@param ast table Program AST
---@return table[] Array of error objects
function Errors.validate(ast)
  local errors = {}

  if ast.type ~= "program" then
    return errors
  end

  -- Collect all passage names
  local passage_names = {}
  for _, passage in ipairs(ast.passages or {}) do
    passage_names[passage.name] = true
  end

  -- Check all choice targets
  local function check_node(node)
    if not node then return end

    if node.type == "choice" then
      if node.target and not passage_names[node.target] then
        table.insert(errors, {
          message = "unknown passage: " .. node.target,
          line = node.metadata and node.metadata.location and node.metadata.location.line or 0,
          column = node.metadata and node.metadata.location and node.metadata.location.column or 0,
          suggestion = "check that the passage '" .. node.target .. "' is defined"
        })
      end
    elseif node.type == "passage" then
      for _, elem in ipairs(node.content or {}) do
        check_node(elem)
      end
    elseif node.type == "conditional" then
      for _, elem in ipairs(node.then_content or {}) do
        check_node(elem)
      end
    end
  end

  for _, passage in ipairs(ast.passages or {}) do
    check_node(passage)
  end

  return errors
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return Errors
