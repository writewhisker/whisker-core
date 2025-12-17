-- whisker/formats/ink/converter.lua
-- Ink to Whisker converter
-- Transforms InkStory to whisker-core Story structure

local InkConverter = {}
InkConverter.__index = InkConverter

-- Module metadata for container auto-registration
InkConverter._whisker = {
  name = "InkConverter",
  version = "1.0.0",
  description = "Converts Ink stories to whisker-core format",
  depends = {},
  capability = "formats.ink.converter"
}

-- Create a new InkConverter instance
-- @param options table|nil - Optional configuration
-- @return InkConverter
function InkConverter.new(options)
  options = options or {}
  local instance = {
    _transformers = {},
    _options = {
      preserve_ink_paths = options.preserve_ink_paths ~= false,
      generate_ids_from_paths = options.generate_ids_from_paths ~= false
    }
  }
  setmetatable(instance, InkConverter)

  -- Load default transformers
  instance:_load_default_transformers()

  return instance
end

-- Load the default transformer set
function InkConverter:_load_default_transformers()
  local transformers = require("whisker.formats.ink.transformers")
  self._transformers = {
    knot = transformers.knot()
  }
end

-- Register a transformer
-- @param name string - Transformer name
-- @param transformer table - Transformer with transform method
function InkConverter:register_transformer(name, transformer)
  self._transformers[name] = transformer
end

-- Get a registered transformer
-- @param name string - Transformer name
-- @return table|nil
function InkConverter:get_transformer(name)
  return self._transformers[name]
end

-- Convert an InkStory to a whisker-core Story
-- @param ink_story InkStory - The Ink story to convert
-- @return Story - The converted whisker-core Story
function InkConverter:convert(ink_story)
  if not ink_story then
    error("InkStory is required for conversion")
  end

  local Story = require("whisker.core.story")

  -- Extract metadata
  local metadata = ink_story:get_metadata()

  -- Create new whisker Story
  local story = Story.new({
    title = metadata.title or "Untitled",
    author = metadata.author or "",
    version = metadata.version or "1.0.0",
    format = "ink",
    format_version = tostring(ink_story:get_ink_version() or "")
  })

  -- Store original Ink format info
  story:set_setting("ink_version", ink_story:get_ink_version())
  story:set_setting("converted_from", "ink")

  -- Add story-level tags
  if metadata.tags then
    for _, tag in ipairs(metadata.tags) do
      story:add_tag(tag)
    end
  end

  -- Convert knots to passages
  self:_convert_knots(ink_story, story)

  -- Convert global variables
  self:_convert_variables(ink_story, story)

  -- Set start passage (usually the first knot or "START")
  self:_set_start_passage(ink_story, story)

  return story
end

-- Convert knots to passages
function InkConverter:_convert_knots(ink_story, story)
  local knot_transformer = self._transformers.knot
  if not knot_transformer then
    error("No knot transformer registered")
  end

  local knots = ink_story:get_knots()
  for _, knot_path in ipairs(knots) do
    local passage = knot_transformer:transform(ink_story, knot_path, self._options)
    if passage then
      story:add_passage(passage)
    end
  end
end

-- Convert global variables
function InkConverter:_convert_variables(ink_story, story)
  local variables = ink_story:get_global_variables()
  for name, var_info in pairs(variables) do
    -- Use typed variable format
    story:set_typed_variable(name, var_info.type or "unknown", var_info.value)
  end
end

-- Set the start passage
function InkConverter:_set_start_passage(ink_story, story)
  local passages = story:get_all_passages()

  if #passages == 0 then
    return
  end

  -- Look for common start passage patterns
  local start_candidates = {"START", "start", "Begin", "begin", "Intro", "intro"}

  for _, candidate in ipairs(start_candidates) do
    if story:get_passage(candidate) then
      story:set_start_passage(candidate)
      return
    end
  end

  -- Otherwise use the first passage alphabetically
  local sorted_ids = {}
  for _, passage in ipairs(passages) do
    table.insert(sorted_ids, passage.id)
  end
  table.sort(sorted_ids)

  if #sorted_ids > 0 then
    story:set_start_passage(sorted_ids[1])
  end
end

-- Convert an InkStory from file
-- @param path string - Path to the ink.json file
-- @return Story
function InkConverter:convert_from_file(path)
  local InkStory = require("whisker.formats.ink.story")
  local ink_story = InkStory.from_file(path)
  return self:convert(ink_story)
end

-- Convert an InkStory from JSON string
-- @param json_string string - The ink.json content
-- @return Story
function InkConverter:convert_from_string(json_string)
  local InkStory = require("whisker.formats.ink.story")
  local ink_story = InkStory.from_string(json_string)
  return self:convert(ink_story)
end

-- Static convenience method
-- @param ink_story InkStory - Story to convert
-- @param options table|nil - Optional configuration
-- @return Story
function InkConverter.to_whisker(ink_story, options)
  local converter = InkConverter.new(options)
  return converter:convert(ink_story)
end

return InkConverter
