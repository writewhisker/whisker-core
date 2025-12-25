--- Chapbook story format handler
-- Implements Chapbook 1.x parsing and translation
--
-- lib/whisker/twine/formats/chapbook/handler.lua

local ChapbookHandler = {}
ChapbookHandler._dependencies = {}
ChapbookHandler.__index = ChapbookHandler

local ModifierParser = require('whisker.twine.formats.chapbook.modifier_parser')
local InsertParser = require('whisker.twine.formats.chapbook.insert_parser')
local VariableParser = require('whisker.twine.formats.chapbook.variable_parser')
local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize handler
---@return table ChapbookHandler instance
function ChapbookHandler.new(deps)
  deps = deps or {}
  local self = setmetatable({}, ChapbookHandler)
  self.format_name = "chapbook"
  self.supported_versions = { "1.0", "1.1", "1.2", "1.2.1", "1.2.2", "1.2.3" }
  return self
end

--- Detect if HTML is Chapbook format
---@param html_data table Parsed HTML from HTMLParser
---@return boolean True if Chapbook
function ChapbookHandler:detect(html_data)
  local format = html_data.metadata and html_data.metadata.format or ""
  local lower_format = format:lower()
  return lower_format == "chapbook" or lower_format:match("^chapbook") ~= nil
end

--------------------------------------------------------------------------------
-- Passage Parsing
--------------------------------------------------------------------------------

--- Parse passage content and translate to WhiskerScript AST
---@param passage table Passage data with content
---@return table AST nodes
function ChapbookHandler:parse_passage(passage)
  local content = passage.content
  if not content or content == "" then
    return {}
  end

  local ast_nodes = {}
  local lines = {}

  -- Split into lines
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Skip empty lines
    if trimmed == "" then
      i = i + 1

    -- Check for variable assignment (name: value)
    elseif VariableParser.is_assignment(trimmed) then
      local var_node = VariableParser.parse_assignment(trimmed)
      table.insert(ast_nodes, var_node)
      i = i + 1

    -- Check for wiki-style link [[...]] (must check before single-bracket modifier)
    elseif trimmed:find("%[%[") then
      local link_nodes = self:_parse_line_with_links(trimmed)
      for _, node in ipairs(link_nodes) do
        table.insert(ast_nodes, node)
      end
      i = i + 1

    -- Check for modifier ([modifier args]) - single bracket only, not double
    elseif trimmed:match("^%[%a.-%]$") and not trimmed:match("^%[%[") then
      local modifier_node, consumed_lines = ModifierParser.parse_modifier(lines, i)
      table.insert(ast_nodes, modifier_node)
      i = i + consumed_lines

    -- Regular text (may contain inserts)
    else
      local text_node = self:_parse_text_line(line)
      table.insert(ast_nodes, text_node)
      i = i + 1
    end
  end

  return ast_nodes
end

--------------------------------------------------------------------------------
-- Text Line Parsing
--------------------------------------------------------------------------------

--- Parse text line (handle inserts and markdown)
---@param line string Line of text
---@return table AST node
function ChapbookHandler:_parse_text_line(line)
  -- Check for inserts: {varName}
  if line:find("{") then
    return InsertParser.parse_line_with_inserts(line)
  else
    -- Plain text (preserve markdown)
    return ASTBuilder.create_text(line)
  end
end

--------------------------------------------------------------------------------
-- Link Parsing
--------------------------------------------------------------------------------

--- Parse line that contains wiki-style links
---@param line string Line with [[links]]
---@return table Array of AST nodes
function ChapbookHandler:_parse_line_with_links(line)
  local nodes = {}
  local pos = 1

  while pos <= #line do
    local link_start = line:find("%[%[", pos)

    if not link_start then
      -- No more links
      local remaining = line:sub(pos)
      if remaining ~= "" then
        if remaining:find("{") then
          table.insert(nodes, InsertParser.parse_line_with_inserts(remaining))
        else
          table.insert(nodes, ASTBuilder.create_text(remaining))
        end
      end
      break
    end

    -- Text before link
    if link_start > pos then
      local before = line:sub(pos, link_start - 1)
      if before:find("{") then
        table.insert(nodes, InsertParser.parse_line_with_inserts(before))
      else
        table.insert(nodes, ASTBuilder.create_text(before))
      end
    end

    -- Find closing ]]
    local link_end = line:find("%]%]", link_start + 2)
    if not link_end then
      -- Malformed link
      table.insert(nodes, ASTBuilder.create_text(line:sub(link_start)))
      break
    end

    -- Parse link content
    local link_content = line:sub(link_start + 2, link_end - 1)
    local link_node = self:_parse_link(link_content)
    table.insert(nodes, link_node)

    pos = link_end + 2
  end

  return nodes
end

--- Parse link content: [[Text->Destination]] or [[Destination<-Text]] or [[Destination]]
---@param link_content string Content between [[ and ]]
---@return table AST node
function ChapbookHandler:_parse_link(link_content)
  local text, destination

  -- Text->Destination format
  local arrow_text, arrow_dest = link_content:match("^(.+)%->(.+)$")
  if arrow_text and arrow_dest then
    text = arrow_text:match("^%s*(.-)%s*$")
    destination = arrow_dest:match("^%s*(.-)%s*$")
  else
    -- Destination<-Text format
    local back_dest, back_text = link_content:match("^(.+)%<%-(.+)$")
    if back_dest and back_text then
      text = back_text:match("^%s*(.-)%s*$")
      destination = back_dest:match("^%s*(.-)%s*$")
    else
      -- Simple [[Destination]]
      text = link_content:match("^%s*(.-)%s*$")
      destination = text
    end
  end

  return ASTBuilder.create_choice(text, {}, destination)
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

--- Get format name
---@return string Format name
function ChapbookHandler:get_format_name()
  return self.format_name
end

--- Get supported versions
---@return table Array of supported version strings
function ChapbookHandler:get_supported_versions()
  return self.supported_versions
end

--- Check if a specific version is supported
---@param version string Version to check
---@return boolean True if supported
function ChapbookHandler:is_version_supported(version)
  for _, v in ipairs(self.supported_versions) do
    if v == version or version:match("^" .. v:gsub("%.", "%%.")) then
      return true
    end
  end
  return false
end

return ChapbookHandler
