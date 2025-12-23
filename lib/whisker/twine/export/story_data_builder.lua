--- Story data structure builder
-- Creates tw-storydata structure from metadata and passages
--
-- lib/whisker/twine/export/story_data_builder.lua

local StoryDataBuilder = {}

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

--- Build complete story data structure
---@param metadata table Story metadata
---@param passages table Serialized passages
---@param css string Story CSS
---@param js string Story JavaScript
---@return table Story data structure
function StoryDataBuilder.build(metadata, passages, css, js)
  return {
    metadata = metadata,
    passages = passages,
    css = css or "",
    javascript = js or ""
  }
end

--------------------------------------------------------------------------------
-- Attribute Building
--------------------------------------------------------------------------------

--- Build tw-storydata attributes string
---@param metadata table Story metadata
---@return string Attribute string
function StoryDataBuilder.build_attributes(metadata)
  local attrs = {}

  table.insert(attrs, string.format('name="%s"', StoryDataBuilder._escape_attr(metadata.name)))
  table.insert(attrs, string.format('startnode="%d"', metadata.startnode))
  table.insert(attrs, string.format('creator="%s"', metadata.creator))
  table.insert(attrs, string.format('creator-version="%s"', metadata.creator_version))
  table.insert(attrs, string.format('ifid="%s"', metadata.ifid))
  table.insert(attrs, string.format('zoom="%s"', tostring(metadata.zoom)))
  table.insert(attrs, string.format('format="%s"', metadata.format))
  table.insert(attrs, string.format('format-version="%s"', metadata.format_version))
  table.insert(attrs, string.format('options="%s"', StoryDataBuilder._escape_attr(metadata.options)))

  if metadata.hidden then
    table.insert(attrs, "hidden")
  end

  return table.concat(attrs, " ")
end

--------------------------------------------------------------------------------
-- Escaping
--------------------------------------------------------------------------------

--- Escape HTML attribute value
---@param value string Value to escape
---@return string Escaped value
function StoryDataBuilder._escape_attr(value)
  if not value then return "" end

  -- Escape & first, then other characters
  return value:gsub("&", "&amp;")
              :gsub('"', "&quot;")
              :gsub("'", "&apos;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
end

return StoryDataBuilder
