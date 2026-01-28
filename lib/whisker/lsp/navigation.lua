--- LSP Navigation Provider
-- Provides go-to-definition and find-references for WLS documents
-- @module whisker.lsp.navigation
-- @author Whisker Core Team
-- @license MIT

local Navigation = {}
Navigation.__index = Navigation
Navigation._dependencies = {}

--- Create a new navigation provider
-- @param options table Options with documents manager
-- @return Navigation Provider instance
function Navigation.new(options)
  options = options or {}
  local self = setmetatable({}, Navigation)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Navigation:set_parser(parser)
  self._parser = parser
end

--- Get definition location for symbol at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return table|nil Location or array of locations
function Navigation:get_definition(uri, line, character)
  local word, start_char, end_char = self._documents:get_word_at(uri, line, character)
  if not word then return nil end

  local text_before = self._documents:get_text_before(uri, line, character)

  -- Variable definition ($varname)
  if word:sub(1, 1) == "$" then
    return self:_find_variable_definition(uri, word:sub(2))
  end

  -- Passage reference (after -> or in choice)
  if text_before then
    if text_before:match("->%s*$") or
       text_before:match("%]%s*->%s*$") or
       text_before:match("%[%[%s*$") then
      return self:_find_passage_definition(uri, word)
    end
  end

  -- Function definition (after FUNCTION keyword or as function call)
  local line_text = self._documents:get_line(uri, line) or ""
  if line_text:match("FUNCTION%s+" .. word) or line_text:match(word .. "%s*%(") then
    return self:_find_function_definition(uri, word)
  end

  -- Check if this might be a passage name in general context
  local passage_def = self:_find_passage_definition(uri, word)
  if passage_def then
    return passage_def
  end

  return nil
end

--- Get all references to symbol at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return table Array of locations
function Navigation:get_references(uri, line, character)
  local word, _, _ = self._documents:get_word_at(uri, line, character)
  if not word then return {} end

  local text_before = self._documents:get_text_before(uri, line, character)

  -- Variable references
  if word:sub(1, 1) == "$" then
    return self:find_variable_references(uri, word:sub(2))
  end

  -- Check if on passage header or reference
  local line_text = self._documents:get_line(uri, line)
  if line_text and line_text:match("^::") then
    local passage_name = line_text:match("^::%s*([^%[%]]+)")
    if passage_name then
      passage_name = passage_name:match("^%s*(.-)%s*$")
      return self:find_passage_references(uri, passage_name)
    end
  end

  -- Check for function context
  if line_text then
    if line_text:match("^%s*FUNCTION%s+" .. word) or line_text:match(word .. "%s*%(") then
      return self:find_function_references(uri, word)
    end
  end

  -- Default: try passage references
  return self:find_passage_references(uri, word)
end

--- Determine symbol type at position
-- @param doc table Document
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @param word string Word at position
-- @return string|nil Symbol type
function Navigation:determine_symbol_type(doc, line, character, word)
  local line_text = self._documents:get_line(doc.uri or "", line)
  if not line_text then return nil end

  -- Passage definition or reference
  if line_text:match("^%s*::%s*" .. word) then
    return "passage"
  elseif line_text:match("%->%s*" .. word) then
    return "passage"
  elseif line_text:match("visited%s*%(%s*[\"']" .. word) then
    return "passage"
  end

  -- Function definition or call
  if line_text:match("^%s*FUNCTION%s+" .. word) then
    return "function"
  elseif line_text:match(word .. "%s*%(") then
    return "function"
  end

  -- Variable
  if line_text:match("%$" .. word) or line_text:match("^%s*VAR%s+" .. word) then
    return "variable"
  end

  -- Hook
  if line_text:match("|" .. word .. ">") then
    return "hook"
  end

  -- Default: try passage
  return "passage"
end

--- Find variable definition location
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table|nil Location
function Navigation:_find_variable_definition(uri, var_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    local name = line:match("^%s*VAR%s+([%w_]+)%s*=")
    if name == var_name then
      local start_col = line:find(var_name, 1, true) - 1
      return {
        uri = uri,
        range = {
          start = { line = i - 1, character = start_col },
          ["end"] = { line = i - 1, character = start_col + #var_name },
        },
      }
    end
  end

  return nil
end

--- Find passage definition location
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return table|nil Location
function Navigation:_find_passage_definition(uri, passage_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    local header = line:match("^::%s*(.+)$")
    if header then
      local name = header:match("^([^%[%]]+)")
      if name then
        name = name:match("^%s*(.-)%s*$")
        if name == passage_name then
          local start_col = line:find(passage_name, 1, true) - 1
          return {
            uri = uri,
            range = {
              start = { line = i - 1, character = start_col },
              ["end"] = { line = i - 1, character = start_col + #passage_name },
            },
          }
        end
      end
    end
  end

  return nil
end

--- Find variable definition location
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table|nil Location
function Navigation:_find_variable_definition(uri, var_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    local name = line:match("^%s*VAR%s+([%w_]+)%s*=")
    if name == var_name then
      local start_col = line:find(var_name, 1, true) - 1
      return {
        uri = uri,
        range = {
          start = { line = i - 1, character = start_col },
          ["end"] = { line = i - 1, character = start_col + #var_name },
        },
      }
    end
  end

  return nil
end

--- Find function definition location
-- @param uri string Document URI
-- @param func_name string Function name
-- @return table|nil Location
function Navigation:_find_function_definition(uri, func_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    if line:match("^%s*FUNCTION%s+" .. func_name) then
      local start_col = line:find(func_name, 1, true) - 1
      return {
        uri = uri,
        range = {
          start = { line = i - 1, character = start_col },
          ["end"] = { line = i - 1, character = start_col + #func_name },
        },
      }
    end
  end

  return nil
end

--- Find all variable references (public method for rename support)
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table Array of locations
function Navigation:find_variable_references(uri, var_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  local escaped_name = var_name:gsub("([^%w_])", "%%%1")

  for i, line in ipairs(lines) do
    -- VAR declaration
    if line:match("^%s*VAR%s+" .. escaped_name .. "%s*=") then
      local name_start = line:find(var_name, 1, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #var_name },
          },
        })
      end
    end

    -- $var interpolation
    local start_pos = 1
    while true do
      local match_start = line:find("%$" .. escaped_name .. "%f[^%w_]", start_pos)
      if not match_start then break end

      table.insert(locations, {
        uri = uri,
        range = {
          start = { line = i - 1, character = match_start }, -- After $
          ["end"] = { line = i - 1, character = match_start + #var_name },
        },
      })

      start_pos = match_start + 1
    end

    -- ${...var...} expression interpolation
    for expr in line:gmatch("%${([^}]+)}") do
      if expr:match(escaped_name) then
        local expr_start = line:find("%${" .. expr:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"), 1)
        if expr_start then
          local var_pos = expr:find(var_name)
          if var_pos then
            table.insert(locations, {
              uri = uri,
              range = {
                start = { line = i - 1, character = expr_start + 1 + var_pos - 1 },
                ["end"] = { line = i - 1, character = expr_start + 1 + var_pos - 1 + #var_name },
              },
            })
          end
        end
      end
    end
  end

  return locations
end

--- Find all passage references (public method for rename support)
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return table Array of locations
function Navigation:find_passage_references(uri, passage_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  -- Escape special pattern characters
  local escaped_name = passage_name:gsub("([^%w_])", "%%%1")

  for i, line in ipairs(lines) do
    -- Passage header definition
    if line:match("^::%s*" .. escaped_name .. "%s*$") or
       line:match("^::%s*" .. escaped_name .. "%[") or
       line:match("^::%s*" .. escaped_name .. "%s+") then
      local name_start = line:find(passage_name, 1, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #passage_name },
          },
        })
      end
    end

    -- Navigation: -> references
    local start_pos = 1
    while true do
      local arrow_pattern = "->%s*" .. escaped_name .. "%f[^%w_]"
      local match_start = line:find(arrow_pattern, start_pos)
      if not match_start then break end

      local name_start = line:find(passage_name, match_start, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #passage_name },
          },
        })
      end

      start_pos = (match_start or 0) + 2
      if start_pos > #line then break end
    end

    -- [[ ]] references
    local bracket_pattern = "%[%[.-" .. escaped_name
    local match_start = line:find(bracket_pattern)
    if match_start then
      local name_start = line:find(passage_name, match_start, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #passage_name },
          },
        })
      end
    end

    -- visited() calls
    start_pos = 1
    while true do
      local visit_start = line:find("visited%s*%(%s*[\"']" .. escaped_name .. "[\"']", start_pos)
      if not visit_start then break end

      local name_start = line:find(passage_name, visit_start, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #passage_name },
          },
        })
      end

      start_pos = (visit_start or 0) + 7
      if start_pos > #line then break end
    end
  end

  return locations
end

--- Find all function references (public method for rename support)
-- @param uri string Document URI
-- @param func_name string Function name
-- @return table Array of locations
function Navigation:find_function_references(uri, func_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  local escaped_name = func_name:gsub("([^%w_])", "%%%1")

  for i, line in ipairs(lines) do
    -- Function definition
    if line:match("^%s*FUNCTION%s+" .. escaped_name) then
      local name_start = line:find(func_name, 1, true)
      if name_start then
        table.insert(locations, {
          uri = uri,
          range = {
            start = { line = i - 1, character = name_start - 1 },
            ["end"] = { line = i - 1, character = name_start - 1 + #func_name },
          },
        })
      end
    end

    -- Function calls: name(...)
    local start_pos = 1
    while true do
      local call_start = line:find(escaped_name .. "%s*%(", start_pos)
      if not call_start then break end

      table.insert(locations, {
        uri = uri,
        range = {
          start = { line = i - 1, character = call_start - 1 },
          ["end"] = { line = i - 1, character = call_start - 1 + #func_name },
        },
      })

      start_pos = call_start + #func_name
    end
  end

  return locations
end

--- Find all hook references
-- @param uri string Document URI
-- @param hook_name string Hook name
-- @return table Array of locations
function Navigation:find_hook_references(uri, hook_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  local escaped_name = hook_name:gsub("([^%w_])", "%%%1")

  for i, line in ipairs(lines) do
    local start_pos = 1
    while true do
      local hook_start = line:find("|" .. escaped_name .. ">", start_pos)
      if not hook_start then break end

      table.insert(locations, {
        uri = uri,
        range = {
          start = { line = i - 1, character = hook_start }, -- After |
          ["end"] = { line = i - 1, character = hook_start + #hook_name },
        },
      })

      start_pos = hook_start + #hook_name + 2
    end
  end

  return locations
end

--- Helper to make a range (for internal use)
-- @param line number Line number (0-based)
-- @param char number Character position (0-based)
-- @param length number Length of the range
-- @return table LSP range
function Navigation:make_range(line, char, length)
  return {
    start = { line = line, character = char },
    ["end"] = { line = line, character = char + length }
  }
end

return Navigation
