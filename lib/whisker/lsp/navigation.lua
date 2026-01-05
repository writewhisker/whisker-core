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
    return self:_find_variable_references(uri, word:sub(2))
  end

  -- Check if on passage header or reference
  local line_text = self._documents:get_line(uri, line)
  if line_text and line_text:match("^::") then
    local passage_name = line_text:match("^::%s*([^%[%]]+)")
    if passage_name then
      passage_name = passage_name:match("^%s*(.-)%s*$")
      return self:_find_passage_references(uri, passage_name)
    end
  end

  -- Passage references
  return self:_find_passage_references(uri, word)
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

--- Find all variable references
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table Array of locations
function Navigation:_find_variable_references(uri, var_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  local pattern = "%$" .. var_name .. "%f[^%w_]"

  for i, line in ipairs(lines) do
    local start_pos = 1
    while true do
      local match_start = line:find(pattern, start_pos)
      if not match_start then break end

      table.insert(locations, {
        uri = uri,
        range = {
          start = { line = i - 1, character = match_start - 1 },
          ["end"] = { line = i - 1, character = match_start + #var_name },
        },
      })

      start_pos = match_start + 1
    end
  end

  return locations
end

--- Find all passage references
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return table Array of locations
function Navigation:_find_passage_references(uri, passage_name)
  local locations = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return locations end

  -- Escape special pattern characters
  local escaped_name = passage_name:gsub("([^%w_])", "%%%1")

  for i, line in ipairs(lines) do
    -- Check for -> references
    local arrow_pattern = "->%s*" .. escaped_name .. "%f[^%w_]"
    local match_start = line:find(arrow_pattern)
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

    -- Check for [[ ]] references
    local bracket_pattern = "%[%[.-" .. escaped_name
    match_start = line:find(bracket_pattern)
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

    -- Check for passage header definition (include it too)
    if line:match("^::%s*" .. escaped_name .. "%s*") or
       line:match("^::%s*" .. escaped_name .. "%[") then
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
  end

  return locations
end

return Navigation
