--- Snowman ERB-style template parser
-- Parses <% code %> and <%= expression %>
--
-- lib/whisker/twine/formats/snowman/template_parser.lua

local TemplateParser = {}

--------------------------------------------------------------------------------
-- Template Tag Parsing
--------------------------------------------------------------------------------

--- Parse template tag at position
---@param content string Passage content
---@param pos number Current position
---@return table|nil, number Template node and new position, or nil
function TemplateParser.parse_template_tag(content, pos)
  -- Look for opening <%
  if content:sub(pos, pos + 1) ~= "<%" then
    return nil
  end

  -- Check if expression (<%=) or code block (<%)
  local is_expression = content:sub(pos + 2, pos + 2) == "="

  local start_pos = is_expression and pos + 3 or pos + 2

  -- Find closing %>
  local close_pos = TemplateParser._find_closing_tag(content, start_pos)

  if not close_pos then
    -- Malformed template tag
    return nil
  end

  local code = content:sub(start_pos, close_pos - 1)

  -- Trim whitespace
  code = code:match("^%s*(.-)%s*$")

  local node = {
    type = is_expression and "expression" or "code_block",
    code = code
  }

  return node, close_pos + 2 -- Position after %>
end

--- Find closing %> tag
---@param content string Content to search
---@param start_pos number Position to start search
---@return number|nil Position of closing tag
function TemplateParser._find_closing_tag(content, start_pos)
  local in_string = false
  local string_char = nil

  for i = start_pos, #content - 1 do
    local char = content:sub(i, i)
    local next_char = content:sub(i + 1, i + 1)
    local prev_char = i > 1 and content:sub(i - 1, i - 1) or ""

    -- Handle string literals
    if (char == '"' or char == "'") and prev_char ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
    elseif not in_string then
      if char == "%" and next_char == ">" then
        return i
      end
    end
  end

  return nil
end

return TemplateParser
