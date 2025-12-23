--- Harlowe story format handler
-- Implements Harlowe 3.x macro parsing and translation
--
-- lib/whisker/twine/formats/harlowe/handler.lua

local HarloweHandler = {}
HarloweHandler.__index = HarloweHandler

local MacroCore = require('whisker.twine.formats.harlowe.macro_core')
local MacroAdvanced = require('whisker.twine.formats.harlowe.macro_advanced')
local HookParser = require('whisker.twine.formats.harlowe.hook_parser')
local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize handler
---@return table HarloweHandler instance
function HarloweHandler.new()
  local self = setmetatable({}, HarloweHandler)
  self.format_name = "harlowe"
  self.supported_versions = { "3.0", "3.1", "3.2", "3.3" }

  -- Build combined translator table
  self.translators = {}

  -- Copy core translators
  for name, fn in pairs(MacroCore.translators) do
    self.translators[name] = fn
  end

  -- Register advanced translators
  MacroAdvanced.register_translators(self.translators)

  return self
end

--- Detect if HTML is Harlowe format
---@param html_data table Parsed HTML from HTMLParser
---@return boolean True if Harlowe
function HarloweHandler:detect(html_data)
  local format = html_data.metadata and html_data.metadata.format or ""
  return format:lower() == "harlowe" or format:lower():match("^harlowe")
end

--------------------------------------------------------------------------------
-- Passage Parsing
--------------------------------------------------------------------------------

--- Parse passage content and translate to WhiskerScript AST
---@param passage table Passage data with content
---@return table AST nodes or nil, error
function HarloweHandler:parse_passage(passage)
  local content = passage.content
  if not content or content == "" then
    return {}
  end

  local ast_nodes = {}
  local pos = 1

  -- First, extract named hooks
  local clean_content, hooks = HookParser.extract_hooks(content)

  -- Add named hook definitions as AST nodes
  for _, hook in ipairs(hooks) do
    local hook_node = ASTBuilder.create_named_hook(
      hook.name,
      self:parse_passage({ content = hook.content }),
      false
    )
    table.insert(ast_nodes, hook_node)
  end

  -- Parse the rest of the content
  content = clean_content
  pos = 1

  while pos <= #content do
    -- Try to parse macro
    local macro_node, new_pos = self:_try_parse_macro(content, pos)

    if macro_node then
      table.insert(ast_nodes, macro_node)
      pos = new_pos
    else
      -- Parse plain text until next macro or named hook
      local text_node, new_pos2 = self:_parse_text(content, pos)
      if text_node then
        table.insert(ast_nodes, text_node)
        pos = new_pos2
      else
        pos = pos + 1 -- Skip unparseable character
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
function HarloweHandler:_try_parse_macro(content, pos)
  -- Look for macro opening: (
  if content:sub(pos, pos) ~= "(" then
    return nil
  end

  -- Find closing ) for macro call
  local close_paren = self:_find_matching_paren(content, pos)
  if not close_paren then
    return nil -- Malformed macro
  end

  local macro_text = content:sub(pos + 1, close_paren - 1)

  -- Parse macro name and arguments
  local macro_name, args_text = macro_text:match("^([%w%-]+):%s*(.*)$")
  if not macro_name then
    -- Try macro without arguments: (else:)
    macro_name = macro_text:match("^([%w%-]+):?%s*$")
    if macro_name then
      args_text = ""
    else
      return nil -- Not a valid macro
    end
  end

  -- Parse arguments
  local args = self:_parse_arguments(args_text)

  -- Check for attached hook [...]
  local hook_content = nil
  local hook_end = close_paren

  if close_paren < #content and content:sub(close_paren + 1, close_paren + 1) == "[" then
    local hook_close = self:_find_matching_bracket(content, close_paren + 1)
    if hook_close then
      hook_content = content:sub(close_paren + 2, hook_close - 1)
      hook_end = hook_close
    end
  end

  -- Translate macro to AST using combined translators
  local translator = self.translators[macro_name:lower()]
  local ast_node

  if translator then
    ast_node = translator(args, hook_content)
  else
    ast_node = ASTBuilder.create_warning(
      "Unsupported Harlowe macro: " .. macro_name,
      { macro = macro_name, args = args, hook = hook_content }
    )
  end

  return ast_node, hook_end + 1
end

--- Find matching closing parenthesis
---@param content string Text to search
---@param start_pos number Position of opening (
---@return number|nil Position of closing )
function HarloweHandler:_find_matching_paren(content, start_pos)
  local depth = 0
  local in_string = false
  local string_char = nil

  for i = start_pos, #content do
    local char = content:sub(i, i)
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
      if char == "(" then
        depth = depth + 1
      elseif char == ")" then
        depth = depth - 1
        if depth == 0 then
          return i
        end
      end
    end
  end

  return nil
end

--- Find matching closing bracket
---@param content string Text to search
---@param start_pos number Position of opening [
---@return number|nil Position of closing ]
function HarloweHandler:_find_matching_bracket(content, start_pos)
  local depth = 0
  local in_string = false
  local string_char = nil

  for i = start_pos, #content do
    local char = content:sub(i, i)
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
      if char == "[" then
        depth = depth + 1
      elseif char == "]" then
        depth = depth - 1
        if depth == 0 then
          return i
        end
      end
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Argument Parsing
--------------------------------------------------------------------------------

--- Parse macro arguments (comma-separated)
---@param args_text string Argument text
---@return table Array of parsed argument values
function HarloweHandler:_parse_arguments(args_text)
  if not args_text or args_text == "" then
    return {}
  end

  local args = {}
  local current_arg = ""
  local depth = 0
  local in_string = false
  local string_char = nil

  for i = 1, #args_text do
    local char = args_text:sub(i, i)
    local prev_char = i > 1 and args_text:sub(i - 1, i - 1) or ""

    -- Handle strings
    if (char == '"' or char == "'") and prev_char ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
      current_arg = current_arg .. char
    elseif in_string then
      current_arg = current_arg .. char
    elseif char == "(" or char == "[" then
      depth = depth + 1
      current_arg = current_arg .. char
    elseif char == ")" or char == "]" then
      depth = depth - 1
      current_arg = current_arg .. char
    elseif char == "," and depth == 0 then
      -- Argument separator
      local trimmed = current_arg:match("^%s*(.-)%s*$")
      if trimmed and trimmed ~= "" then
        table.insert(args, self:_parse_value(trimmed))
      end
      current_arg = ""
    else
      current_arg = current_arg .. char
    end
  end

  -- Add final argument
  local trimmed = current_arg:match("^%s*(.-)%s*$")
  if trimmed and trimmed ~= "" then
    table.insert(args, self:_parse_value(trimmed))
  end

  return args
end

--- Parse single value (number, string, variable, boolean)
---@param text string Value text
---@return table { type, value }
function HarloweHandler:_parse_value(text)
  -- Trim whitespace
  text = text:match("^%s*(.-)%s*$")

  -- String literal
  if text:match('^".*"$') or text:match("^'.*'$") then
    return { type = "string", value = text:sub(2, -2) }
  end

  -- Number
  if text:match("^%-?%d+%.?%d*$") then
    return { type = "number", value = tonumber(text) }
  end

  -- Boolean
  if text == "true" then
    return { type = "boolean", value = true }
  elseif text == "false" then
    return { type = "boolean", value = false }
  end

  -- Variable (with $)
  if text:match("^%$[%w_]+$") then
    return { type = "variable", value = text:sub(2) } -- Remove $
  end

  -- Temporary variable (with _)
  if text:match("^_[%w_]+$") then
    return { type = "variable", value = text:sub(2) } -- Remove _
  end

  -- Expression (complex, store as-is)
  return { type = "expression", value = text }
end

--------------------------------------------------------------------------------
-- Text Parsing
--------------------------------------------------------------------------------

--- Parse plain text (until next macro)
---@param content string Passage content
---@param pos number Current position
---@return table|nil, number Text AST node and new position
function HarloweHandler:_parse_text(content, pos)
  -- Find next macro start or end of content
  local next_macro = content:find("%(", pos)
  local next_hook = content:find("|[%w_]+>", pos)

  local next_special = nil
  if next_macro and next_hook then
    next_special = math.min(next_macro, next_hook)
  elseif next_macro then
    next_special = next_macro
  elseif next_hook then
    next_special = next_hook
  end

  if not next_special then
    -- No more special content, take rest
    local text = content:sub(pos)
    if text ~= "" then
      return ASTBuilder.create_text(text), #content + 1
    else
      return nil
    end
  else
    -- Take text until next special
    local text = content:sub(pos, next_special - 1)
    if text ~= "" then
      return ASTBuilder.create_text(text), next_special
    else
      return nil
    end
  end
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

--- Get format name
---@return string Format name
function HarloweHandler:get_format_name()
  return self.format_name
end

--- Get supported versions
---@return table Array of supported version strings
function HarloweHandler:get_supported_versions()
  return self.supported_versions
end

--- Check if a specific version is supported
---@param version string Version to check
---@return boolean True if supported
function HarloweHandler:is_version_supported(version)
  for _, v in ipairs(self.supported_versions) do
    if v == version or version:match("^" .. v:gsub("%.", "%%.")) then
      return true
    end
  end
  return false
end

return HarloweHandler
