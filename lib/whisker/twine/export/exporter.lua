--- Twine HTML exporter
-- Converts whisker-core stories to Twine HTML format
--
-- lib/whisker/twine/export/exporter.lua

local TwineExporter = {}

local StoryDataBuilder = require('whisker.twine.export.story_data_builder')
local PassageSerializer = require('whisker.twine.export.passage_serializer')
local HTMLGenerator = require('whisker.twine.export.html_generator')
local IFIDGenerator = require('whisker.twine.util.ifid_generator')

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

--- Export whisker story to Twine HTML
---@param story table Whisker story object
---@param format string Target format ("harlowe", "sugarcube", "chapbook", "snowman")
---@param options table Export options
---@return string|nil, string HTML content or nil with error
function TwineExporter.export(story, format, options)
  options = options or {}

  -- Validate format
  local supported_formats = { "harlowe", "sugarcube", "chapbook", "snowman" }
  if not TwineExporter._contains(supported_formats, format:lower()) then
    return nil, "Unsupported export format: " .. format
  end

  -- Validate story
  if not story or not story.passages or #story.passages == 0 then
    return nil, "Story must have at least one passage"
  end

  -- Get or create metadata
  local story_metadata = story.metadata or {}

  -- Generate IFID if not present
  local ifid = story_metadata.ifid or IFIDGenerator.generate()

  -- Build story metadata
  local export_metadata = {
    name = story_metadata.name or "Untitled Story",
    startnode = TwineExporter._find_start_passage_pid(story.passages),
    creator = "whisker-core",
    creator_version = "1.0.0",
    ifid = ifid,
    zoom = 1.0,
    format = TwineExporter._normalize_format_name(format),
    format_version = TwineExporter._get_format_version(format),
    options = options.format_options or "",
    hidden = true
  }

  -- Serialize passages
  local serialized_passages = {}
  for i, passage in ipairs(story.passages) do
    local serialized = PassageSerializer.serialize(passage, format, i)
    table.insert(serialized_passages, serialized)
  end

  -- Build story data structure
  local story_data = StoryDataBuilder.build(
    export_metadata,
    serialized_passages,
    story.css or "",
    story.javascript or ""
  )

  -- Generate final HTML
  local html = HTMLGenerator.generate(story_data, format, options)

  return html
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Find PID of start passage
---@param passages table Array of passages
---@return number PID
function TwineExporter._find_start_passage_pid(passages)
  -- Look for passage named "Start" or first passage
  for i, passage in ipairs(passages) do
    if passage.name and passage.name:lower() == "start" then
      return i
    end
  end

  return 1  -- Default to first passage
end

--- Normalize format name for Twine
---@param format string Format name
---@return string Normalized format name
function TwineExporter._normalize_format_name(format)
  local names = {
    harlowe = "Harlowe",
    sugarcube = "SugarCube",
    chapbook = "Chapbook",
    snowman = "Snowman"
  }

  return names[format:lower()] or "Harlowe"
end

--- Get format version string
---@param format string Format name
---@return string Version string
function TwineExporter._get_format_version(format)
  local versions = {
    harlowe = "3.3.8",
    sugarcube = "2.36.1",
    chapbook = "1.2.3",
    snowman = "2.0.3"
  }

  return versions[format:lower()] or "1.0.0"
end

--- Check if table contains value
---@param tbl table Table to search
---@param value any Value to find
---@return boolean True if found
function TwineExporter._contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

--- Get list of supported formats
---@return table Array of format names
function TwineExporter.get_supported_formats()
  return { "harlowe", "sugarcube", "chapbook", "snowman" }
end

--- Check if a format is supported
---@param format string Format name
---@return boolean True if supported
function TwineExporter.is_format_supported(format)
  return TwineExporter._contains(TwineExporter.get_supported_formats(), format:lower())
end

return TwineExporter
