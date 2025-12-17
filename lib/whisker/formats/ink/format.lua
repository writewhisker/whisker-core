-- whisker/formats/ink/format.lua
-- IInkFormat implementation - IFormat interface for Ink stories

local JsonLoader = require("whisker.formats.ink.json_loader")

local InkFormat = {}
InkFormat.__index = InkFormat

-- Module metadata for container auto-registration
InkFormat._whisker = {
  name = "InkFormat",
  version = "1.0.0",
  description = "Ink format handler implementing IFormat",
  depends = {},
  implements = "IFormat",
  capability = "formats.ink"
}

-- Format metadata (IFormat optional fields)
InkFormat.name = "ink"
InkFormat.version = "1.0.0"
InkFormat.extensions = {".json", ".ink.json"}

-- Create a new InkFormat instance
-- @param options table|nil - Optional configuration
-- @return InkFormat
function InkFormat.new(options)
  options = options or {}
  local instance = {
    _json_loader = JsonLoader.new(),
    _tinta = nil,  -- Lazy loaded
    _loaded_stories = {},  -- Cache for loaded stories
    _event_emitter = options.event_emitter
  }
  setmetatable(instance, InkFormat)
  return instance
end

-- Get tinta module (lazy load)
function InkFormat:_get_tinta()
  if not self._tinta then
    self._tinta = require("whisker.vendor.tinta")
  end
  return self._tinta
end

-- Check if this format can import the given source
-- @param source string|table - Source data to check (path, JSON string, or table)
-- @return boolean - True if format can handle this source
function InkFormat:can_import(source)
  if source == nil then
    return false
  end

  -- If it's a string, check if it's a file path or JSON content
  if type(source) == "string" then
    -- Check file extension
    if source:match("%.ink%.json$") or source:match("%.json$") then
      -- Could be a file path, check if file exists
      local file = io.open(source, "r")
      if file then
        file:close()
        return true
      end
    end

    -- Try to detect if it's JSON content
    local trimmed = source:gsub("^%s+", "")
    if trimmed:sub(1, 1) == "{" then
      return self._json_loader:is_ink_json(source)
    end

    return false
  end

  -- If it's a table, check for Ink structure
  if type(source) == "table" then
    return self._json_loader:is_ink_json(source)
  end

  return false
end

-- Import source data
-- @param source string|table - Source data to import (path, JSON string, or table)
-- @return table|nil, string|nil - Loaded story data or nil with error
function InkFormat:import(source)
  if source == nil then
    return nil, "Source cannot be nil"
  end

  local story_data
  local err

  if type(source) == "string" then
    -- Check if it's a file path
    local file = io.open(source, "r")
    if file then
      file:close()
      story_data, err = self._json_loader:load_file(source)
    else
      -- Assume it's JSON content
      story_data, err = self._json_loader:load_string(source)
    end
  elseif type(source) == "table" then
    -- Already parsed, just validate
    local valid
    valid, err = self._json_loader:validate(source)
    if valid then
      story_data = source
    end
  else
    return nil, "Invalid source type: " .. type(source)
  end

  if not story_data then
    return nil, err or "Failed to load Ink story"
  end

  -- Emit event if emitter available
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit("ink.story.loaded", {
      format = "ink",
      version = story_data.inkVersion
    })
  end

  return story_data
end

-- Load and validate from file path
-- @param path string - File path to ink.json
-- @return table|nil, string|nil - Loaded story data or nil with error
function InkFormat:load(path)
  return self:import(path)
end

-- Load from string content
-- @param content string - JSON string content
-- @return table|nil, string|nil - Loaded story data or nil with error
function InkFormat:load_string(content)
  return self:import(content)
end

-- Check if this format can export the given story
-- @param story Story|table - Story to check
-- @return boolean - True if format can export this story
function InkFormat:can_export(story)
  -- For now, we can export if the story has the necessary structure
  -- Full export support will be added in Stage 18
  if type(story) ~= "table" then
    return false
  end

  -- Check if it's already an Ink story (has inkVersion)
  if story.inkVersion and story.root then
    return true
  end

  -- Check if it's a whisker Story that could be converted
  -- This will be expanded when the exporter is implemented
  return false
end

-- Export story to this format
-- @param story Story|table - Story to export
-- @return string|nil, string|nil - Exported JSON or nil with error
function InkFormat:export(story)
  -- If already Ink format, encode to JSON
  if story.inkVersion and story.root then
    local json = require("whisker.utils.json")
    local ok, result = pcall(json.encode, story)
    if ok then
      return result
    else
      return nil, "Failed to encode JSON: " .. tostring(result)
    end
  end

  -- Full whisker-to-ink export will be implemented in Stage 18
  return nil, "Export from whisker format not yet implemented"
end

-- Validate story data
-- @param data table - Story data to validate
-- @return boolean, string|nil - True if valid, or false with error
function InkFormat:validate(data)
  return self._json_loader:validate(data)
end

-- Get metadata from story data
-- @param data table - Story data
-- @return table - Metadata table
function InkFormat:get_metadata(data)
  return self._json_loader:get_metadata(data)
end

-- Get Ink version from story data
-- @param data table - Story data
-- @return number|nil - Ink version
function InkFormat:get_version(data)
  return self._json_loader:get_version(data)
end

-- Set event emitter for notifications
-- @param emitter table - Event emitter with emit method
function InkFormat:set_event_emitter(emitter)
  self._event_emitter = emitter
end

return InkFormat
