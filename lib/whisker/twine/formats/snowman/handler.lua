--- Snowman story format handler
-- Implements Snowman 2.x template parsing and translation
--
-- lib/whisker/twine/formats/snowman/handler.lua

local SnowmanHandler = {}
SnowmanHandler._dependencies = {}
SnowmanHandler.__index = SnowmanHandler

local TemplateParser = require('whisker.twine.formats.snowman.template_parser')
local JSTranslator = require('whisker.twine.formats.snowman.js_translator')
local LinkParser = require('whisker.twine.formats.snowman.link_parser')
local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize handler
---@return table SnowmanHandler instance
function SnowmanHandler.new(deps)
  deps = deps or {}
  local self = setmetatable({}, SnowmanHandler)
  self.format_name = "snowman"
  self.supported_versions = { "2.0", "2.0.1", "2.0.2", "2.0.3" }
  return self
end

--- Detect if HTML is Snowman format
---@param html_data table Parsed HTML from HTMLParser
---@return boolean True if Snowman
function SnowmanHandler:detect(html_data)
  local format = html_data.metadata and html_data.metadata.format or ""
  local lower_format = format:lower()
  return lower_format == "snowman" or lower_format:match("^snowman") ~= nil
end

--------------------------------------------------------------------------------
-- Passage Parsing
--------------------------------------------------------------------------------

--- Parse passage content and translate to WhiskerScript AST
---@param passage table Passage data with content
---@return table AST nodes
function SnowmanHandler:parse_passage(passage)
  local content = passage.content
  if not content or content == "" then
    return {}
  end

  local ast_nodes = {}
  local pos = 1

  while pos <= #content do
    -- Try to parse template tag
    local template_node, new_pos = TemplateParser.parse_template_tag(content, pos)

    if template_node then
      -- Translate JavaScript to Lua/WhiskerScript
      local translated = self:_translate_template(template_node)
      if translated then
        table.insert(ast_nodes, translated)
      end
      pos = new_pos
    else
      -- Parse plain text/HTML until next template tag
      local text_node, next_pos = self:_parse_text(content, pos)
      if text_node then
        table.insert(ast_nodes, text_node)
        pos = next_pos
      else
        pos = pos + 1
      end
    end
  end

  return ast_nodes
end

--------------------------------------------------------------------------------
-- Template Translation
--------------------------------------------------------------------------------

--- Translate template node to WhiskerScript AST
---@param template_node table Template node from parser
---@return table|nil AST node
function SnowmanHandler:_translate_template(template_node)
  if template_node.type == "code_block" then
    -- <% code %>
    local lua_code, warnings = JSTranslator.translate_block(template_node.code)

    if lua_code then
      return {
        type = "script_block",
        code = lua_code,
        warnings = warnings
      }
    else
      return {
        type = "warning",
        message = "Unable to translate Snowman template code",
        original = template_node.code
      }
    end

  elseif template_node.type == "expression" then
    -- <%= expression %>
    local lua_expr, warnings = JSTranslator.translate_expression(template_node.code)

    if lua_expr then
      return {
        type = "print",
        expression = lua_expr,
        warnings = warnings
      }
    else
      return {
        type = "warning",
        message = "Unable to translate Snowman expression",
        original = template_node.code
      }
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Text Parsing
--------------------------------------------------------------------------------

--- Parse plain text until next template tag
---@param content string Full passage content
---@param pos number Current position
---@return table|nil, number Text node and next position
function SnowmanHandler:_parse_text(content, pos)
  -- Find next template tag
  local next_tag = content:find("<%", pos, true)

  if not next_tag then
    -- No more template tags
    local text = content:sub(pos)
    if text ~= "" then
      -- Check for data-passage links
      if text:find("data%-passage") then
        return self:_parse_text_with_links(text), #content + 1
      else
        -- Skip whitespace-only text
        if not text:match("^%s*$") then
          return ASTBuilder.create_text(text), #content + 1
        end
      end
    end
    return nil, #content + 1
  else
    local text = content:sub(pos, next_tag - 1)
    if text ~= "" then
      -- Check for data-passage links
      if text:find("data%-passage") then
        return self:_parse_text_with_links(text), next_tag
      else
        -- Skip whitespace-only text
        if not text:match("^%s*$") then
          return ASTBuilder.create_text(text), next_tag
        end
      end
    end
    return nil, next_tag
  end
end

--- Parse text that may contain data-passage links
---@param text string Text content
---@return table AST node
function SnowmanHandler:_parse_text_with_links(text)
  -- Check if contains links
  if LinkParser.has_data_passage_links(text) then
    local nodes = LinkParser.replace_links_with_choices(text)
    if #nodes == 1 then
      return nodes[1]
    else
      return {
        type = "fragment",
        children = nodes
      }
    end
  else
    return ASTBuilder.create_text(text)
  end
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

--- Get format name
---@return string Format name
function SnowmanHandler:get_format_name()
  return self.format_name
end

--- Get supported versions
---@return table Array of supported version strings
function SnowmanHandler:get_supported_versions()
  return self.supported_versions
end

--- Check if a specific version is supported
---@param version string Version to check
---@return boolean True if supported
function SnowmanHandler:is_version_supported(version)
  for _, v in ipairs(self.supported_versions) do
    if v == version or version:match("^" .. v:gsub("%.", "%%.")) then
      return true
    end
  end
  return false
end

return SnowmanHandler
