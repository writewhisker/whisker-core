--- LSP Hover Provider
-- Provides hover information for WLS documents
-- @module whisker.lsp.hover
-- @author Whisker Core Team
-- @license MIT

local Hover = {}
Hover.__index = Hover
Hover._dependencies = {}

--- Create a new hover provider
-- @param options table Options with documents manager
-- @return Hover Provider instance
function Hover.new(options)
  options = options or {}
  local self = setmetatable({}, Hover)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Hover:set_parser(parser)
  self._parser = parser
end

--- Get hover information at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return table|nil Hover result
function Hover:get_hover(uri, line, character)
  local word, start_char, end_char = self._documents:get_word_at(uri, line, character)
  if not word then return nil end

  local text_before = self._documents:get_text_before(uri, line, character)

  -- Check for variable hover ($varname)
  if word:sub(1, 1) == "$" then
    return self:_get_variable_hover(uri, word:sub(2))
  end

  -- Check for passage reference (after -> or in [[ ]])
  -- Pattern allows word characters at end since cursor may be in the middle of the word
  if text_before and (text_before:match("->%s*[%w_]*$") or text_before:match("%[%[%s*[%w_]*$")) then
    return self:_get_passage_hover(uri, word, line, start_char, end_char)
  end

  -- Check if word is a passage name in a choice
  if text_before and text_before:match("%]%s*->%s*[%w_]*$") then
    return self:_get_passage_hover(uri, word, line, start_char, end_char)
  end

  -- Check if on a passage header
  local line_text = self._documents:get_line(uri, line)
  if line_text and line_text:match("^::%s*" .. word) then
    return self:_get_passage_header_hover(uri, word, line)
  end

  return nil
end

--- Get hover for a variable
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table|nil Hover result
function Hover:_get_variable_hover(uri, var_name)
  local var_info = self:_find_variable(uri, var_name)

  if not var_info then
    return {
      contents = {
        kind = "markdown",
        value = "**Variable:** `$" .. var_name .. "`\n\n*Not declared*",
      },
    }
  end

  local markdown = "**Variable:** `$" .. var_name .. "`\n\n"
  if var_info.var_type then
    markdown = markdown .. "**Type:** " .. var_info.var_type .. "\n\n"
  end
  if var_info.value ~= nil then
    markdown = markdown .. "**Initial value:** `" .. tostring(var_info.value) .. "`\n\n"
  end
  if var_info.line then
    markdown = markdown .. "*Declared on line " .. (var_info.line + 1) .. "*"
  end

  return {
    contents = {
      kind = "markdown",
      value = markdown,
    },
  }
end

--- Get hover for a passage reference
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @param line number Current line
-- @param start_char number Start character
-- @param end_char number End character
-- @return table|nil Hover result
function Hover:_get_passage_hover(uri, passage_name, line, start_char, end_char)
  local passage_info = self:_find_passage(uri, passage_name)

  if not passage_info then
    return {
      contents = {
        kind = "markdown",
        value = "**Passage:** `" .. passage_name .. "`\n\n*Not found in document*",
      },
      range = {
        start = { line = line, character = start_char },
        ["end"] = { line = line, character = end_char },
      },
    }
  end

  local markdown = "**Passage:** `" .. passage_name .. "`\n\n"

  if passage_info.tags and #passage_info.tags > 0 then
    markdown = markdown .. "**Tags:** " .. table.concat(passage_info.tags, ", ") .. "\n\n"
  end

  if passage_info.preview then
    markdown = markdown .. "**Preview:**\n```\n" .. passage_info.preview .. "\n```\n\n"
  end

  if passage_info.choice_count and passage_info.choice_count > 0 then
    markdown = markdown .. "**Choices:** " .. passage_info.choice_count .. "\n\n"
  end

  if passage_info.reference_count then
    markdown = markdown .. "**References:** " .. passage_info.reference_count .. "\n\n"
  end

  markdown = markdown .. "*Defined on line " .. (passage_info.line + 1) .. "*"

  return {
    contents = {
      kind = "markdown",
      value = markdown,
    },
    range = {
      start = { line = line, character = start_char },
      ["end"] = { line = line, character = end_char },
    },
  }
end

--- Get hover for a passage header
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @param line number Line number
-- @return table|nil Hover result
function Hover:_get_passage_header_hover(uri, passage_name, line)
  local passage_info = self:_find_passage(uri, passage_name)
  if not passage_info then return nil end

  local markdown = "**Passage:** `" .. passage_name .. "`\n\n"

  if passage_info.tags and #passage_info.tags > 0 then
    markdown = markdown .. "**Tags:** " .. table.concat(passage_info.tags, ", ") .. "\n\n"
  end

  -- Count references to this passage
  local ref_count = self:_count_passage_references(uri, passage_name)
  markdown = markdown .. "**References:** " .. ref_count .. "\n\n"

  -- Count choices
  if passage_info.choice_count then
    markdown = markdown .. "**Choices:** " .. passage_info.choice_count
  end

  return {
    contents = {
      kind = "markdown",
      value = markdown,
    },
  }
end

--- Find variable info in document
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table|nil Variable info
function Hover:_find_variable(uri, var_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    local name, value = line:match("^%s*VAR%s+([%w_]+)%s*=%s*(.+)$")
    if name == var_name then
      local var_type = "string"
      value = value:match("^%s*(.-)%s*$")
      if value == "true" or value == "false" then
        var_type = "boolean"
      elseif tonumber(value) then
        var_type = "number"
      end
      return {
        name = name,
        value = value,
        var_type = var_type,
        line = i - 1,
      }
    end
  end

  return nil
end

--- Find passage info in document
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return table|nil Passage info
function Hover:_find_passage(uri, passage_name)
  local lines = self._documents:get_lines(uri)
  if not lines then return nil end

  for i, line in ipairs(lines) do
    local header = line:match("^::%s*(.+)$")
    if header then
      local name = header:match("^([^%[%]]+)")
      if name then
        name = name:match("^%s*(.-)%s*$")
        if name == passage_name then
          -- Extract tags
          local tags = {}
          local tags_str = header:match("%[(.+)%]")
          if tags_str then
            for tag in tags_str:gmatch("[^,%s]+") do
              table.insert(tags, tag)
            end
          end

          -- Get preview (next few lines)
          local preview_lines = {}
          local choice_count = 0
          for j = i + 1, math.min(i + 5, #lines) do
            local next_line = lines[j]
            if next_line:match("^::") then break end
            if next_line:match("^%s*[+*]") then
              choice_count = choice_count + 1
            elseif next_line:match("%S") then
              table.insert(preview_lines, next_line:sub(1, 60))
            end
            if #preview_lines >= 3 then break end
          end

          return {
            name = name,
            line = i - 1,
            tags = tags,
            preview = table.concat(preview_lines, "\n"),
            choice_count = choice_count,
            reference_count = self:_count_passage_references(uri, passage_name),
          }
        end
      end
    end
  end

  return nil
end

--- Count references to a passage
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return number Reference count
function Hover:_count_passage_references(uri, passage_name)
  local count = 0
  local content = self._documents:get_content(uri)
  if not content then return 0 end

  -- Count -> references
  for _ in content:gmatch("->%s*" .. passage_name:gsub("([^%w])", "%%%1") .. "%f[^%w_]") do
    count = count + 1
  end

  -- Count [[ ]] references
  for _ in content:gmatch("%[%[.-" .. passage_name:gsub("([^%w])", "%%%1") .. ".-]]") do
    count = count + 1
  end

  return count
end

return Hover
