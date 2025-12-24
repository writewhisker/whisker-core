--- JsonFormat
-- JSON format handler implementing IFormat interface
-- @module whisker.formats.json
-- @author Whisker Core Team
-- @license MIT

local IFormat = require("whisker.interfaces.format")

local JsonFormat = {}
setmetatable(JsonFormat, { __index = IFormat })

JsonFormat.name = "json"
JsonFormat.extensions = { ".json" }
JsonFormat.version = "2.1.0"

--- Create a new JSON format handler
-- @param container Container The DI container (optional)
-- @return JsonFormat
function JsonFormat.new(container)
  local self = {
    _events = container and container:has("events") and container:resolve("events") or nil,
    _json = nil,  -- Will be set in _init_json
    -- Factories from container (dependency injection)
    _story_factory = container and container:has("story_factory") and container:resolve("story_factory") or nil,
    _passage_factory = container and container:has("passage_factory") and container:resolve("passage_factory") or nil,
    _choice_factory = container and container:has("choice_factory") and container:resolve("choice_factory") or nil,
  }

  local instance = setmetatable(self, { __index = JsonFormat })
  instance:_init_json()
  instance:_init_factories()

  return instance
end

--- Initialize factories (lazy load if not injected)
function JsonFormat:_init_factories()
  if not self._story_factory then
    local StoryFactory = require("whisker.core.factories.story_factory")
    self._story_factory = StoryFactory.new()
  end
  if not self._passage_factory then
    local PassageFactory = require("whisker.core.factories.passage_factory")
    self._passage_factory = PassageFactory.new()
  end
  if not self._choice_factory then
    local ChoiceFactory = require("whisker.core.factories.choice_factory")
    self._choice_factory = ChoiceFactory.new()
  end
end

--- Initialize JSON library (try cjson, dkjson, or fallback)
function JsonFormat:_init_json()
  local ok, json = pcall(require, "cjson")
  if ok then
    self._json = json
    return
  end

  ok, json = pcall(require, "dkjson")
  if ok then
    self._json = json
    return
  end

  ok, json = pcall(require, "lunajson")
  if ok then
    self._json = json
    return
  end

  -- Fallback to minimal JSON implementation
  self._json = require("whisker.formats.json.minimal")
end

--- Check if this format can import the given source
-- @param source string|table The source content to check
-- @return boolean can_import True if this format can handle the source
function JsonFormat:can_import(source)
  if type(source) == "table" then
    -- Already parsed JSON
    return source.passages ~= nil or source.ifid ~= nil or source.metadata ~= nil
  end

  if type(source) ~= "string" then
    return false
  end

  -- Skip empty strings
  if source == "" then
    return false
  end

  -- Try to parse as JSON
  local ok, data = pcall(self._json.decode, source)
  if not ok then
    return false
  end

  -- Check for required story fields
  return type(data) == "table" and
         (data.passages ~= nil or data.ifid ~= nil or data.metadata ~= nil)
end

--- Import source content into a Story structure
-- @param source string|table The source content to import
-- @return Story story The imported story
function JsonFormat:import(source)
  if not self:can_import(source) then
    error("Cannot import: not a valid JSON story format")
  end

  local data
  if type(source) == "string" then
    local ok, result = pcall(self._json.decode, source)
    if not ok then
      error("JSON parse error: " .. tostring(result))
    end
    data = result
  else
    data = source
  end

  -- Create story using factory
  local story = self._story_factory:create({
    title = data.name or (data.metadata and data.metadata.name) or "Untitled",
    author = data.author or (data.metadata and data.metadata.author),
    version = data.version or (data.metadata and data.metadata.version),
    ifid = data.ifid or (data.metadata and data.metadata.ifid),
    format = data.format or (data.metadata and data.metadata.format),
    format_version = data.format_version or (data.metadata and data.metadata.format_version),
  })

  story.start_passage = data.start or data.start_passage

  -- Handle already structured metadata
  if data.metadata then
    for k, v in pairs(data.metadata) do
      story:set_metadata(k, v)
    end
  end

  -- Import passages
  if data.passages then
    if type(data.passages) == "table" then
      -- Handle both array and map formats
      local is_array = #data.passages > 0

      if is_array then
        -- Array format
        for _, passage_data in ipairs(data.passages) do
          local passage = self:_import_passage(passage_data)
          if passage and passage.id and passage.id ~= "" then
            story:add_passage(passage)
          end
        end
      else
        -- Map format (id -> passage)
        for id, passage_data in pairs(data.passages) do
          if type(passage_data) == "table" then
            passage_data.id = passage_data.id or id
            local passage = self:_import_passage(passage_data)
            if passage then
              story:add_passage(passage)
            end
          end
        end
      end
    end
  end

  -- Set start passage if not set
  if not story.start_passage then
    local passage_names = {}
    for id in pairs(story.passages) do
      table.insert(passage_names, id)
    end
    table.sort(passage_names)
    if #passage_names > 0 then
      story.start_passage = passage_names[1]
    end
  end

  -- Emit event
  if self._events then
    self._events:emit("format:imported", {
      format = "json",
      story = story,
      passage_count = #story:get_all_passages()
    })
  end

  return story
end

--- Import a single passage from data
-- @param data table Passage data
-- @return Passage The imported passage
function JsonFormat:_import_passage(data)
  local passage = self._passage_factory:create({
    id = data.id,
    name = data.name or data.id,
    content = data.content or data.text or "",
    tags = data.tags or {},
    metadata = data.metadata or {},
    position = data.position,
    size = data.size,
    on_enter_script = data.on_enter_script,
    on_exit_script = data.on_exit_script,
  })

  -- Import choices using factory
  if data.choices then
    for _, choice_data in ipairs(data.choices) do
      local choice = self._choice_factory:create({
        id = choice_data.id,
        text = choice_data.text,
        target = choice_data.target or choice_data.target_passage,
        condition = choice_data.condition,
        action = choice_data.action,
        metadata = choice_data.metadata,
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
function JsonFormat:can_export(story, options)
  if not story then
    return false
  end

  if type(story) ~= "table" then
    return false
  end

  -- Need at least metadata or passages
  if not story.passages and not story.metadata then
    return false
  end

  return true
end

--- Export a story to this format
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return string output The exported JSON content
function JsonFormat:export(story, options)
  options = options or {}

  if not self:can_export(story, options) then
    error("Cannot export: invalid story structure")
  end

  local data = {
    name = story.metadata and story.metadata.name,
    ifid = story.metadata and story.metadata.ifid,
    author = story.metadata and story.metadata.author,
    version = story.metadata and story.metadata.version,
    format = story.metadata and story.metadata.format,
    format_version = story.metadata and story.metadata.format_version,
    start = story.start_passage,
    metadata = story.metadata,
    passages = {},
  }

  -- Export passages
  local passages = story:get_all_passages()
  for _, passage in ipairs(passages) do
    local passage_data = {
      id = passage.id,
      name = passage.name,
      content = passage.content,
      tags = passage.tags,
      metadata = passage.metadata,
      position = passage.position,
      size = passage.size,
      on_enter_script = passage.on_enter_script,
      on_exit_script = passage.on_exit_script,
      choices = {},
    }

    -- Export choices
    local choices = passage:get_choices()
    if choices then
      for _, choice in ipairs(choices) do
        table.insert(passage_data.choices, {
          id = choice.id,
          text = choice.text,
          target = choice.target_passage or choice.target,
          condition = choice.condition,
          action = choice.action,
          metadata = choice.metadata,
        })
      end
    end

    table.insert(data.passages, passage_data)
  end

  -- Encode to JSON
  local ok, result
  if options.pretty then
    -- Try to encode with pretty printing if available
    if self._json.encode_pretty then
      ok, result = pcall(self._json.encode_pretty, data)
    else
      ok, result = pcall(self._json.encode, data)
    end
  else
    ok, result = pcall(self._json.encode, data)
  end

  if not ok then
    error("JSON encode error: " .. tostring(result))
  end

  -- Emit event
  if self._events then
    self._events:emit("format:exported", {
      format = "json",
      story = story,
      size = #result
    })
  end

  return result
end

--- Get the format name
-- @return string The format name
function JsonFormat:get_name()
  return "json"
end

--- Get supported file extensions
-- @return table Array of extensions
function JsonFormat:get_extensions()
  return { ".json", ".whisker" }
end

--- Get the MIME type
-- @return string The MIME type
function JsonFormat:get_mime_type()
  return "application/json"
end

return JsonFormat
