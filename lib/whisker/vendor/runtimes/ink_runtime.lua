--- Ink Runtime Abstraction
-- Wraps the tinta library for Ink story execution
-- Implements IInkRuntime interface for dependency injection
-- @module whisker.vendor.runtimes.ink_runtime
-- @author Whisker Core Team
-- @license MIT

local InkRuntime = {}
InkRuntime.__index = InkRuntime

--- Dependencies injected via container
InkRuntime._dependencies = { "json_codec", "logger" }

--- Supported Ink JSON version
local SUPPORTED_INK_VERSION = 21

--- Create a new InkRuntime instance
-- @param deps table|nil Dependencies from container
-- @return InkRuntime
function InkRuntime.new(deps)
  local self = setmetatable({}, InkRuntime)

  deps = deps or {}
  self.json_codec = deps.json_codec
  self.log = deps.logger

  -- Lazy load tinta
  self._tinta = nil
  self._loaded = false

  return self
end

--- Create an InkRuntime via container pattern
-- @param container table DI container
-- @return InkRuntime
function InkRuntime.create(container)
  local deps = {}
  if container and container.has then
    if container:has("json_codec") then
      deps.json_codec = container:resolve("json_codec")
    end
    if container:has("logger") then
      deps.logger = container:resolve("logger")
    end
  end
  return InkRuntime.new(deps)
end

--- Lazy load the tinta library
-- @private
-- @return table The tinta module
function InkRuntime:_load_tinta()
  if not self._loaded then
    self._tinta = require("whisker.vendor.tinta")
    self._loaded = true
  end
  return self._tinta
end

--- Create a new Ink story from parsed JSON data
-- @param ink_data table|string The parsed Ink JSON structure or JSON string
-- @return StoryWrapper The wrapped story object
-- @return string|nil Error message if creation failed
function InkRuntime:create_story(ink_data)
  local tinta = self:_load_tinta()

  -- If it's a string, decode it first
  if type(ink_data) == "string" then
    if self.json_codec then
      local decoded, err = self.json_codec:decode(ink_data)
      if err then
        return nil, "Failed to parse Ink JSON: " .. err
      end
      ink_data = decoded
    else
      -- Fallback to direct require if no codec injected
      local json = require("cjson")
      local ok, decoded = pcall(json.decode, ink_data)
      if not ok then
        return nil, "Failed to parse Ink JSON: " .. tostring(decoded)
      end
      ink_data = decoded
    end
  end

  -- Validate ink data
  if type(ink_data) ~= "table" then
    return nil, "Ink data must be a table or JSON string"
  end

  if not ink_data.inkVersion then
    return nil, "Missing inkVersion in Ink data"
  end

  -- Create the tinta story
  local ok, story = pcall(tinta.create_story, ink_data)
  if not ok then
    return nil, "Failed to create Ink story: " .. tostring(story)
  end

  -- Wrap the story in our abstraction layer
  local wrapper = self:_wrap_story(story, ink_data)
  return wrapper
end

--- Wrap a tinta story in our abstraction layer
-- @private
-- @param story table The raw tinta story
-- @param ink_data table The original Ink data
-- @return StoryWrapper
function InkRuntime:_wrap_story(story, ink_data)
  local StoryWrapper = require("whisker.vendor.runtimes.story_wrapper")
  return StoryWrapper.new(story, ink_data, self.json_codec)
end

--- Get the runtime name
-- @return string Runtime name
function InkRuntime:get_runtime_name()
  return "tinta"
end

--- Get supported Ink version
-- @return number The supported Ink JSON version
function InkRuntime:get_ink_version()
  return SUPPORTED_INK_VERSION
end

--- Check if this runtime supports a feature
-- @param feature string Feature name
-- @return boolean True if the feature is supported
function InkRuntime:supports(feature)
  local supported_features = {
    flows = true,
    threads = true,
    external_functions = true,
    tunnels = true,
    lists = true,
    variable_observers = true,
  }
  return supported_features[feature] == true
end

--- Check if tinta is available
-- @return boolean True if tinta can be loaded
function InkRuntime:is_available()
  local ok = pcall(function()
    self:_load_tinta()
  end)
  return ok and self._loaded
end

return InkRuntime
