--- Ink Format Handler
-- IFormat implementation for Ink JSON stories
-- @module whisker.formats.ink
-- @author Whisker Core Team
-- @license MIT

local InkFormat = {}
InkFormat.__index = InkFormat

--- Dependencies injected via container
InkFormat._dependencies = { "events", "logger" }

--- Create a new InkFormat instance
-- @param deps table Dependencies from container
-- @return InkFormat
function InkFormat.new(deps)
  local self = setmetatable({}, InkFormat)

  self.events = deps.events
  self.log = deps.logger

  return self
end

--- Get the format name
-- @return string
function InkFormat:get_name()
  return "ink"
end

--- Get supported file extensions
-- @return table
function InkFormat:get_extensions()
  return { ".ink.json", ".json" }
end

--- Get MIME type
-- @return string
function InkFormat:get_mime_type()
  return "application/json"
end

--- Check if source can be imported as Ink
-- @param source string The raw data to check
-- @return boolean
function InkFormat:can_import(source)
  if type(source) ~= "string" then
    return false
  end

  -- Try to detect Ink JSON format
  -- Ink JSON has specific markers: inkVersion, root
  local has_ink_version = source:match('"inkVersion"') ~= nil
  local has_root = source:match('"root"') ~= nil

  return has_ink_version and has_root
end

--- Import Ink JSON to Whisker story format
-- @param source string The Ink JSON string
-- @return Story The imported story
-- @return string|nil Error message if import failed
function InkFormat:import(source)
  if not self:can_import(source) then
    return nil, "Source is not valid Ink JSON"
  end

  local InkConverter = require("whisker.formats.ink.converter")
  local story, err = InkConverter.import(source, {
    events = self.events,
    log = self.log,
  })

  if story and self.events then
    self.events:emit("format:imported", {
      format = "ink",
      story = story,
    })
  end

  return story, err
end

--- Check if story can be exported to Ink
-- @param story Story The story to check
-- @param options table|nil Export options
-- @return boolean
function InkFormat:can_export(story, options)
  if not story then
    return false
  end

  local InkExporter = require("whisker.formats.ink.exporter")
  local can, _ = InkExporter.can_export(story)

  return can
end

--- Export Whisker story to Ink JSON
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return string The Ink JSON string
-- @return string|nil Error message if export failed
function InkFormat:export(story, options)
  if not self:can_export(story, options) then
    return nil, "Story cannot be exported to Ink format"
  end

  local InkExporter = require("whisker.formats.ink.exporter")
  local json, err = InkExporter.export(story, options)

  if json and self.events then
    self.events:emit("format:exported", {
      format = "ink",
      story = story,
    })
  end

  return json, err
end

return InkFormat
