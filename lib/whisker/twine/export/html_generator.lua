--- HTML document generator
-- Assembles final Twine HTML document
--
-- lib/whisker/twine/export/html_generator.lua

local HTMLGenerator = {}

local StoryDataBuilder = require('whisker.twine.export.story_data_builder')

--------------------------------------------------------------------------------
-- HTML Generation
--------------------------------------------------------------------------------

--- Generate complete HTML document
---@param story_data table Story data structure
---@param format string Target format
---@param options table Export options
---@return string HTML content
function HTMLGenerator.generate(story_data, format, options)
  options = options or {}
  local parts = {}

  -- DOCTYPE and HTML opening
  table.insert(parts, '<!DOCTYPE html>')
  table.insert(parts, '<html>')
  table.insert(parts, '<head>')
  table.insert(parts, '  <meta charset="utf-8">')
  table.insert(parts, '  <title>' .. HTMLGenerator._escape_html(story_data.metadata.name) .. '</title>')
  table.insert(parts, '</head>')
  table.insert(parts, '<body>')

  -- tw-storydata element
  local attrs = StoryDataBuilder.build_attributes(story_data.metadata)
  table.insert(parts, '<tw-storydata ' .. attrs .. '>')

  -- CSS
  if story_data.css and story_data.css ~= "" then
    table.insert(parts, '')
    table.insert(parts, '  <style role="stylesheet" id="twine-user-stylesheet" type="text/twine-css">')
    table.insert(parts, story_data.css)
    table.insert(parts, '  </style>')
  end

  -- JavaScript
  if story_data.javascript and story_data.javascript ~= "" then
    table.insert(parts, '')
    table.insert(parts, '  <script role="script" id="twine-user-script" type="text/twine-javascript">')
    table.insert(parts, story_data.javascript)
    table.insert(parts, '  </script>')
  end

  -- Passages
  table.insert(parts, '')
  for _, passage in ipairs(story_data.passages) do
    table.insert(parts, HTMLGenerator._generate_passage_element(passage))
  end

  -- Format engine placeholder (Stage 9 will add actual engine)
  table.insert(parts, '')
  table.insert(parts, '  <!-- Story format engine would be embedded here -->')

  -- Close tw-storydata and HTML
  table.insert(parts, '</tw-storydata>')
  table.insert(parts, '</body>')
  table.insert(parts, '</html>')

  return table.concat(parts, '\n')
end

--------------------------------------------------------------------------------
-- Passage Element Generation
--------------------------------------------------------------------------------

--- Generate tw-passagedata element
---@param passage table Serialized passage
---@return string Passage element HTML
function HTMLGenerator._generate_passage_element(passage)
  local tags_str = table.concat(passage.tags, " ")
  local pos_str = string.format("%d,%d", passage.position.x, passage.position.y)
  local size_str = string.format("%d,%d", passage.size.width, passage.size.height)

  local attrs = string.format(
    'pid="%d" name="%s" tags="%s" position="%s" size="%s"',
    passage.pid,
    HTMLGenerator._escape_attr(passage.name),
    tags_str,
    pos_str,
    size_str
  )

  -- Escape passage content
  local content = HTMLGenerator._escape_passage_content(passage.content)

  return string.format('  <tw-passagedata %s>%s</tw-passagedata>', attrs, content)
end

--------------------------------------------------------------------------------
-- Escaping
--------------------------------------------------------------------------------

--- Escape HTML entities in text
---@param text string Text to escape
---@return string Escaped text
function HTMLGenerator._escape_html(text)
  if not text then return "" end

  return text:gsub("&", "&amp;")
             :gsub("<", "&lt;")
             :gsub(">", "&gt;")
end

--- Escape HTML attribute value
---@param text string Text to escape
---@return string Escaped text
function HTMLGenerator._escape_attr(text)
  if not text then return "" end

  return text:gsub("&", "&amp;")
             :gsub('"', "&quot;")
             :gsub("'", "&apos;")
end

--- Escape passage content (preserve some HTML)
---@param content string Passage content
---@return string Escaped content
function HTMLGenerator._escape_passage_content(content)
  if not content then return "" end

  -- Escape &, <, > but not quotes
  return content:gsub("&", "&amp;")
                :gsub("<", "&lt;")
                :gsub(">", "&gt;")
end

return HTMLGenerator
