--- TwineFormat
-- Twine HTML format handler implementing IFormat interface
-- Delegates to the existing whisker.twine parser implementation
-- @module whisker.formats.twine
-- @author Whisker Core Team
-- @license MIT

local IFormat = require("whisker.interfaces.format")
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")

local TwineFormat = {}
setmetatable(TwineFormat, { __index = IFormat })

TwineFormat.name = "twine"
TwineFormat.extensions = { ".html", ".htm" }
TwineFormat.version = "2.1.0"

--- Create a new Twine format handler
-- @param container Container The DI container (optional)
-- @return TwineFormat
function TwineFormat.new(container)
  local self = {
    _events = container and container:has("events") and container:resolve("events") or nil,
    _parser = nil,
    _exporter = nil,
  }

  local instance = setmetatable(self, { __index = TwineFormat })
  instance:_init_parser()

  return instance
end

--- Initialize the Twine parser and exporter
function TwineFormat:_init_parser()
  -- Load the existing twine parser
  local ok, parser = pcall(require, "whisker.twine.parser")
  if ok then
    self._parser = parser
  end

  -- Load exporter if available
  local ok_exp, exporter = pcall(require, "whisker.twine.export")
  if ok_exp then
    self._exporter = exporter
  end
end

--- Check if this format can import the given source
-- @param source string|table The source content to check
-- @return boolean can_import True if this format can handle the source
function TwineFormat:can_import(source)
  if type(source) ~= "string" then
    return false
  end

  if source == "" then
    return false
  end

  -- Look for Twine HTML markers
  return source:find("<tw%-storydata") ~= nil or
         source:find("<tw:storydata") ~= nil or
         source:find('id="storeArea"') ~= nil or  -- Twine 1.x
         source:find("Twine") ~= nil
end

--- Import source content into a Story structure
-- @param source string The source content to import
-- @return Story story The imported story
function TwineFormat:import(source)
  if not self:can_import(source) then
    error("Cannot import: not a valid Twine HTML format")
  end

  if not self._parser then
    error("Twine parser not available")
  end

  -- Use the existing parser
  local ok, result, err = pcall(function()
    return self._parser.parse(source)
  end)

  if not ok then
    error("Twine parse error: " .. tostring(result))
  end

  if not result then
    error("Twine parse error: " .. tostring(err or "unknown error"))
  end

  -- Convert parsed result to Story if needed
  local story
  if getmetatable(result) == Story or (result.passages and result.metadata) then
    -- Already a Story-like object, convert to proper Story
    story = self:_convert_to_story(result)
  else
    story = result
  end

  -- Emit event
  if self._events then
    self._events:emit("format:imported", {
      format = "twine",
      story = story,
      passage_count = story and #story:get_all_passages() or 0
    })
  end

  return story
end

--- Convert a parsed result to a proper Story object
-- @param parsed table The parsed result from the Twine parser
-- @return Story The converted story
function TwineFormat:_convert_to_story(parsed)
  local story = Story.create({
    title = parsed.metadata and parsed.metadata.name or parsed.name or "Untitled",
    author = parsed.metadata and parsed.metadata.creator,
    ifid = parsed.metadata and parsed.metadata.ifid,
    format = parsed.metadata and parsed.metadata.format,
    format_version = parsed.metadata and parsed.metadata.format_version,
  })

  story.start_passage = parsed.start_passage or
                        (parsed.metadata and parsed.metadata.startnode) or
                        nil

  -- Import passages
  if parsed.passages then
    if type(parsed.passages) == "table" then
      -- Handle both array and map formats
      for id_or_idx, passage_data in pairs(parsed.passages) do
        local passage = self:_convert_passage(passage_data, id_or_idx)
        if passage and passage.id and passage.id ~= "" then
          story:add_passage(passage)

          -- Set start passage if this is the start node
          if parsed.metadata and parsed.metadata.startnode then
            if tonumber(passage_data.pid) == parsed.metadata.startnode then
              story.start_passage = passage.id
            end
          end
        end
      end
    end
  end

  -- Fallback: use first passage as start
  if not story.start_passage then
    local all = story:get_all_passages()
    if #all > 0 then
      story.start_passage = all[1].id
    end
  end

  return story
end

--- Convert a parsed passage to a Passage object
-- @param data table The parsed passage data
-- @param default_id string|number Default ID if not present
-- @return Passage The converted passage
function TwineFormat:_convert_passage(data, default_id)
  local id = data.id or data.name or tostring(default_id)

  local passage = Passage.create({
    id = id,
    name = data.name or id,
    content = data.content or data.text or "",
    tags = data.tags or {},
    metadata = data.metadata or {},
    position = data.position,
  })

  -- Convert links to choices if present
  if data.links then
    for _, link in ipairs(data.links) do
      local choice = Choice.create({
        text = link.text or link.label or link.target,
        target = link.target or link.passage,
        condition = link.condition,
      })
      passage:add_choice(choice)
    end
  end

  -- Also check for choices field
  if data.choices then
    for _, choice_data in ipairs(data.choices) do
      local choice = Choice.create({
        id = choice_data.id,
        text = choice_data.text,
        target = choice_data.target or choice_data.target_passage,
        condition = choice_data.condition,
        action = choice_data.action,
      })
      passage:add_choice(choice)
    end
  end

  return passage
end

--- Check if this format can export the given story
-- @param story Story The story to check
-- @param options table|nil Export options
-- @return boolean can_export True if this format can export the story
function TwineFormat:can_export(story, options)
  if not story then
    return false
  end

  -- Need exporter available
  if not self._exporter then
    return false
  end

  -- Need at least some passages
  if not story.passages or type(story.passages) ~= "table" then
    return false
  end

  return true
end

--- Export a story to this format
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return string output The exported HTML content
function TwineFormat:export(story, options)
  options = options or {}

  if not self:can_export(story, options) then
    error("Cannot export: exporter not available or invalid story")
  end

  -- Use the existing exporter
  local ok, result = pcall(function()
    return self._exporter.export(story, options)
  end)

  if not ok then
    error("Twine export error: " .. tostring(result))
  end

  -- Emit event
  if self._events then
    self._events:emit("format:exported", {
      format = "twine",
      story = story,
      size = result and #result or 0
    })
  end

  return result
end

--- Get the format name
-- @return string The format name
function TwineFormat:get_name()
  return "twine"
end

--- Get supported file extensions
-- @return table Array of extensions
function TwineFormat:get_extensions()
  return { ".html", ".htm" }
end

--- Get the MIME type
-- @return string The MIME type
function TwineFormat:get_mime_type()
  return "text/html"
end

--- Get supported Twine story formats
-- @return table Array of format names (harlowe, sugarcube, etc.)
function TwineFormat:get_supported_formats()
  return { "harlowe", "sugarcube", "chapbook", "snowman" }
end

return TwineFormat
