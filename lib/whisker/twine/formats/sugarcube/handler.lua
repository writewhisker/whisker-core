--- SugarCube story format handler
-- Implements SugarCube 2.x macro parsing and translation
--
-- lib/whisker/twine/formats/sugarcube/handler.lua

local SugarCubeHandler = {}
SugarCubeHandler.__index = SugarCubeHandler

local MacroCore = require('whisker.twine.formats.sugarcube.macro_core')
local MacroAdvanced = require('whisker.twine.formats.sugarcube.macro_advanced')
local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize handler
---@return table SugarCubeHandler instance
function SugarCubeHandler.new()
  local self = setmetatable({}, SugarCubeHandler)
  self.format_name = "sugarcube"
  self.supported_versions = { "2.30", "2.31", "2.32", "2.33", "2.34", "2.35", "2.36", "2.37" }

  -- Build translator table from core
  self.translators = {}
  for name, fn in pairs(MacroCore.translators) do
    self.translators[name] = fn
  end

  -- Register advanced translators
  MacroAdvanced.register_translators(self.translators)

  return self
end

--- Detect if HTML is SugarCube format
---@param html_data table Parsed HTML from HTMLParser
---@return boolean True if SugarCube
function SugarCubeHandler:detect(html_data)
  local format = html_data.metadata and html_data.metadata.format or ""
  local lower_format = format:lower()
  return lower_format == "sugarcube" or lower_format:match("^sugarcube") ~= nil
end

--------------------------------------------------------------------------------
-- Passage Parsing
--------------------------------------------------------------------------------

--- Parse passage content and translate to WhiskerScript AST
---@param passage table Passage data with content
---@return table AST nodes
function SugarCubeHandler:parse_passage(passage)
  local content = passage.content
  if not content or content == "" then
    return {}
  end

  local ast_nodes = {}
  local pos = 1

  while pos <= #content do
    -- Try to parse macro
    local macro_node, new_pos = self:_try_parse_macro(content, pos)

    if macro_node then
      table.insert(ast_nodes, macro_node)
      pos = new_pos
    else
      -- Try to parse wiki-style link [[link]]
      local link_node, link_pos = self:_try_parse_link(content, pos)
      if link_node then
        table.insert(ast_nodes, link_node)
        pos = link_pos
      else
        -- Parse plain text until next macro or link
        local text_node, text_pos = self:_parse_text(content, pos)
        if text_node then
          table.insert(ast_nodes, text_node)
          pos = text_pos
        else
          pos = pos + 1
        end
      end
    end
  end

  return ast_nodes
end

--------------------------------------------------------------------------------
-- Macro Parsing
--------------------------------------------------------------------------------

--- Try to parse macro at position
---@param content string Passage content
---@param pos number Current position
---@return table|nil, number AST node and new position, or nil
function SugarCubeHandler:_try_parse_macro(content, pos)
  -- Look for macro opening: <<
  if content:sub(pos, pos + 1) ~= "<<" then
    return nil
  end

  -- Find closing >>
  local close_pos = self:_find_macro_close(content, pos + 2)
  if not close_pos then
    return nil -- Malformed macro
  end

  local macro_text = content:sub(pos + 2, close_pos - 1)

  -- Check if closing tag: <</macroName>>
  if macro_text:sub(1, 1) == "/" then
    -- This is a closing tag, handled by container macro parser
    return nil
  end

  -- Parse macro name and arguments
  -- Handle special single-character macros: <<- expr>> and <<= expr>>
  local macro_name, args_text
  if macro_text:sub(1, 1) == "-" or macro_text:sub(1, 1) == "=" then
    macro_name = macro_text:sub(1, 1)
    args_text = macro_text:sub(2):match("^%s*(.*)$") or ""
  else
    macro_name, args_text = macro_text:match("^([%w%-_]+)%s*(.*)$")
    if not macro_name then
      return nil
    end
    macro_name = macro_name:lower()
  end

  -- Check if this is a container macro (needs closing tag)
  local is_container = self:_is_container_macro(macro_name)

  local macro_body = nil
  local end_pos = close_pos + 2 -- Position after >> (close_pos is first >, so +2 to skip both)

  if is_container then
    -- Find matching closing tag
    local closing_tag = "<</" .. macro_name .. ">>"
    local body_start = close_pos + 2
    local body_end, tag_end = self:_find_closing_tag(content, body_start, macro_name)

    if body_end then
      macro_body = content:sub(body_start, body_end - 1)
      end_pos = tag_end
    else
      -- Missing closing tag - error
      return ASTBuilder.create_error("Missing closing tag for <<" .. macro_name .. ">>"), close_pos + 2
    end
  end

  -- Parse arguments
  local args = self:_parse_arguments(args_text)

  -- Translate macro to AST
  local translator = self.translators[macro_name]
  local ast_node

  if translator then
    ast_node = translator(args, macro_body, self)
  else
    ast_node = ASTBuilder.create_warning(
      "Unsupported SugarCube macro: " .. macro_name,
      { macro = macro_name, args = args, body = macro_body }
    )
  end

  return ast_node, end_pos
end

--- Find macro close (>>)
---@param content string Content to search
---@param start_pos number Position to start from
---@return number|nil Position of first >
function SugarCubeHandler:_find_macro_close(content, start_pos)
  local in_string = false
  local string_char = nil

  for i = start_pos, #content do
    local char = content:sub(i, i)
    local prev = i > 1 and content:sub(i - 1, i - 1) or ""

    -- Handle string literals
    if (char == '"' or char == "'") and prev ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
    elseif not in_string then
      if content:sub(i, i + 1) == ">>" then
        return i
      end
    end
  end

  return nil
end

--- Find closing tag for container macro
---@param content string Content to search
---@param start_pos number Position to start from
---@param macro_name string Name of macro to close
---@return number|nil, number|nil Body end position and tag end position
function SugarCubeHandler:_find_closing_tag(content, start_pos, macro_name)
  local depth = 1
  local pos = start_pos
  local opening = "<<" .. macro_name
  local closing = "<</" .. macro_name .. ">>"

  while pos <= #content do
    -- Check for nested opening
    if content:sub(pos, pos + #opening - 1):lower() == opening:lower() then
      -- Make sure it's a full macro opening (followed by space or >>)
      local next_char = content:sub(pos + #opening, pos + #opening)
      if next_char == " " or next_char == ">" or next_char == "\n" or next_char == "\t" then
        depth = depth + 1
      end
    end

    -- Check for closing
    if content:sub(pos, pos + #closing - 1):lower() == closing:lower() then
      depth = depth - 1
      if depth == 0 then
        return pos, pos + #closing
      end
    end

    pos = pos + 1
  end

  return nil, nil
end

--- Check if macro requires closing tag
---@param macro_name string Macro name
---@return boolean True if container macro
function SugarCubeHandler:_is_container_macro(macro_name)
  local container_macros = {
    ["if"] = true,
    ["for"] = true,
    ["link"] = true,
    ["button"] = true,
    ["linkappend"] = true,
    ["linkprepend"] = true,
    ["linkreplace"] = true,
    ["nobr"] = true,
    ["silently"] = true,
    ["repeat"] = true,
    ["switch"] = true,
    ["capture"] = true,
    ["widget"] = true,
    ["script"] = true,
    ["timed"] = true,
    ["type"] = true
  }

  return container_macros[macro_name] or false
end

--------------------------------------------------------------------------------
-- Argument Parsing
--------------------------------------------------------------------------------

--- Parse macro arguments
---@param args_text string Argument text
---@return table Array of parsed arguments
function SugarCubeHandler:_parse_arguments(args_text)
  if not args_text or args_text == "" then
    return {}
  end

  args_text = args_text:match("^%s*(.-)%s*$") -- Trim

  if args_text == "" then
    return {}
  end

  -- Check for quoted strings as first argument (common for link/button)
  local first_arg = args_text:match('^"([^"]*)"') or args_text:match("^'([^']*)'")

  if first_arg then
    -- Extract rest of arguments
    local quote_char = args_text:sub(1, 1)
    local quote_end = args_text:find(quote_char, 2)
    local rest = ""
    if quote_end then
      rest = args_text:sub(quote_end + 1):match("^%s*(.-)%s*$")
    end

    local args = {{ type = "string", value = first_arg }}

    if rest and rest ~= "" then
      -- Second argument (often passage name)
      local second_arg = rest:match('^"([^"]*)"') or rest:match("^'([^']*)'")
      if second_arg then
        table.insert(args, { type = "string", value = second_arg })
      else
        table.insert(args, { type = "expression", value = rest })
      end
    end

    return args
  else
    -- Return entire args as expression
    return {{ type = "expression", value = args_text }}
  end
end

--------------------------------------------------------------------------------
-- Link Parsing
--------------------------------------------------------------------------------

--- Try to parse wiki-style link at position
---@param content string Passage content
---@param pos number Current position
---@return table|nil, number AST node and new position, or nil
function SugarCubeHandler:_try_parse_link(content, pos)
  if content:sub(pos, pos + 1) ~= "[[" then
    return nil
  end

  -- Find closing ]]
  local close_pos = content:find("%]%]", pos + 2)
  if not close_pos then
    return nil
  end

  local link_content = content:sub(pos + 2, close_pos - 1)

  -- Parse link formats:
  -- [[Text->Destination]]
  -- [[Destination<-Text]]
  -- [[Destination]]
  local text, destination

  local arrow_text, arrow_dest = link_content:match("^(.+)%->(.+)$")
  if arrow_text and arrow_dest then
    text = arrow_text:match("^%s*(.-)%s*$")
    destination = arrow_dest:match("^%s*(.-)%s*$")
  else
    local back_dest, back_text = link_content:match("^(.+)%<%-(.+)$")
    if back_dest and back_text then
      text = back_text:match("^%s*(.-)%s*$")
      destination = back_dest:match("^%s*(.-)%s*$")
    else
      -- Simple link: [[Destination]]
      text = link_content:match("^%s*(.-)%s*$")
      destination = text
    end
  end

  return ASTBuilder.create_choice(text, {}, destination), close_pos + 2
end

--------------------------------------------------------------------------------
-- Text Parsing
--------------------------------------------------------------------------------

--- Parse plain text until next macro or link
---@param content string Passage content
---@param pos number Current position
---@return table|nil, number Text AST node and new position
function SugarCubeHandler:_parse_text(content, pos)
  local next_macro = content:find("<<", pos, true)
  local next_link = content:find("%[%[", pos)

  local next_special = nil
  if next_macro and next_link then
    next_special = math.min(next_macro, next_link)
  elseif next_macro then
    next_special = next_macro
  elseif next_link then
    next_special = next_link
  end

  if not next_special then
    local text = content:sub(pos)
    if text ~= "" then
      return ASTBuilder.create_text(text), #content + 1
    else
      return nil
    end
  else
    local text = content:sub(pos, next_special - 1)
    if text ~= "" then
      return ASTBuilder.create_text(text), next_special
    else
      return nil
    end
  end
end

--------------------------------------------------------------------------------
-- Body Content Parsing (for container macros)
--------------------------------------------------------------------------------

--- Parse body content recursively
---@param body string Body content
---@return table AST nodes
function SugarCubeHandler:_parse_body_content(body)
  if not body or body == "" then
    return {}
  end

  return self:parse_passage({ content = body })
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

--- Get format name
---@return string Format name
function SugarCubeHandler:get_format_name()
  return self.format_name
end

--- Get supported versions
---@return table Array of supported version strings
function SugarCubeHandler:get_supported_versions()
  return self.supported_versions
end

--- Check if a specific version is supported
---@param version string Version to check
---@return boolean True if supported
function SugarCubeHandler:is_version_supported(version)
  for _, v in ipairs(self.supported_versions) do
    if v == version or version:match("^" .. v:gsub("%.", "%%.")) then
      return true
    end
  end
  return false
end

return SugarCubeHandler
