--- Story Schema Definition
-- Defines the JSON schema for story import/export
-- @module whisker.format.schemas.story_schema

local M = {}
M._dependencies = {"json_codec"}

--- Schema version for compatibility checking
M.SCHEMA_VERSION = "1.0.0"

--- Default values for optional fields
M.DEFAULTS = {
  format = "harlowe",
  ifid = nil,
  start = "Start",
  zoom = 1.0,
  tags = {},
}

--- Valid format types
M.VALID_FORMATS = {
  harlowe = true,
  sugarcube = true,
  chapbook = true,
  snowman = true,
}

--- Create a new story schema validator
-- @param deps table Dependencies
-- @return StorySchema instance
function M.new(deps)
  local self = setmetatable({}, {__index = M})
  self._json = deps and deps.json_codec
  return self
end

--- Validate a story object against the schema
-- @param story table The story object to validate
-- @return boolean True if valid
-- @return table|nil List of validation errors
function M:validate(story)
  local errors = {}

  -- Required: story must be a table
  if type(story) ~= "table" then
    return false, {"Story must be a table/object"}
  end

  -- Required: name field
  if not story.name or type(story.name) ~= "string" then
    table.insert(errors, "Missing or invalid 'name' field (string required)")
  end

  -- Required: passages array
  if not story.passages or type(story.passages) ~= "table" then
    table.insert(errors, "Missing or invalid 'passages' field (array required)")
  else
    -- Validate each passage
    for i, passage in ipairs(story.passages) do
      local passage_errors = self:validate_passage(passage, i)
      for _, err in ipairs(passage_errors) do
        table.insert(errors, err)
      end
    end
  end

  -- Optional: format field
  if story.format then
    if type(story.format) ~= "string" then
      table.insert(errors, "'format' must be a string")
    elseif not M.VALID_FORMATS[story.format:lower()] then
      table.insert(errors, "Invalid format: " .. story.format)
    end
  end

  -- Optional: ifid field
  if story.ifid and type(story.ifid) ~= "string" then
    table.insert(errors, "'ifid' must be a string")
  end

  -- Optional: start field
  if story.start and type(story.start) ~= "string" then
    table.insert(errors, "'start' must be a string")
  end

  -- Optional: zoom field
  if story.zoom and type(story.zoom) ~= "number" then
    table.insert(errors, "'zoom' must be a number")
  end

  -- Optional: metadata field
  if story.metadata and type(story.metadata) ~= "table" then
    table.insert(errors, "'metadata' must be an object")
  end

  -- Optional: tags field (story-level tags)
  if story.tags and type(story.tags) ~= "table" then
    table.insert(errors, "'tags' must be an array")
  end

  return #errors == 0, errors
end

--- Validate a passage object
-- @param passage table The passage to validate
-- @param index number The passage index (for error messages)
-- @return table List of validation errors
function M:validate_passage(passage, index)
  local errors = {}
  local prefix = "Passage " .. tostring(index) .. ": "

  if type(passage) ~= "table" then
    return {prefix .. "must be an object"}
  end

  -- Required: name
  if not passage.name or type(passage.name) ~= "string" then
    table.insert(errors, prefix .. "missing or invalid 'name' field")
  end

  -- Required: content
  if not passage.content then
    table.insert(errors, prefix .. "missing 'content' field")
  elseif type(passage.content) ~= "string" then
    table.insert(errors, prefix .. "'content' must be a string")
  end

  -- Optional: tags
  if passage.tags then
    if type(passage.tags) ~= "table" then
      table.insert(errors, prefix .. "'tags' must be an array")
    else
      for j, tag in ipairs(passage.tags) do
        if type(tag) ~= "string" then
          table.insert(errors, prefix .. "tag " .. j .. " must be a string")
        end
      end
    end
  end

  -- Optional: position
  if passage.position then
    if type(passage.position) ~= "table" then
      table.insert(errors, prefix .. "'position' must be an object")
    else
      if passage.position.x and type(passage.position.x) ~= "number" then
        table.insert(errors, prefix .. "'position.x' must be a number")
      end
      if passage.position.y and type(passage.position.y) ~= "number" then
        table.insert(errors, prefix .. "'position.y' must be a number")
      end
    end
  end

  -- Optional: size
  if passage.size then
    if type(passage.size) ~= "table" then
      table.insert(errors, prefix .. "'size' must be an object")
    else
      if passage.size.width and type(passage.size.width) ~= "number" then
        table.insert(errors, prefix .. "'size.width' must be a number")
      end
      if passage.size.height and type(passage.size.height) ~= "number" then
        table.insert(errors, prefix .. "'size.height' must be a number")
      end
    end
  end

  return errors
end

--- Create a minimal valid story object
-- @param name string Story name
-- @return table Valid story object
function M:create_empty_story(name)
  return {
    name = name or "Untitled Story",
    format = M.DEFAULTS.format,
    start = M.DEFAULTS.start,
    passages = {
      {
        name = "Start",
        content = "Your story begins here...",
        tags = {},
      }
    },
    metadata = {
      created = os.date("%Y-%m-%dT%H:%M:%S"),
      schemaVersion = M.SCHEMA_VERSION,
    }
  }
end

--- Apply defaults to a story object
-- @param story table Story object
-- @return table Story with defaults applied
function M:apply_defaults(story)
  local result = {}

  -- Copy all existing fields
  for k, v in pairs(story) do
    result[k] = v
  end

  -- Apply defaults for missing optional fields
  result.format = result.format or M.DEFAULTS.format
  result.start = result.start or M.DEFAULTS.start
  result.zoom = result.zoom or M.DEFAULTS.zoom

  -- Ensure passages have defaults
  if result.passages then
    for _, passage in ipairs(result.passages) do
      passage.tags = passage.tags or {}
    end
  end

  return result
end

--- Get JSON schema definition (for documentation/tooling)
-- @return table JSON Schema object
function M:get_json_schema()
  return {
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
    title = "Whisker Story Schema",
    version = M.SCHEMA_VERSION,
    type = "object",
    required = {"name", "passages"},
    properties = {
      name = {
        type = "string",
        description = "The story title",
      },
      format = {
        type = "string",
        enum = {"harlowe", "sugarcube", "chapbook", "snowman"},
        default = "harlowe",
        description = "Twine format for the story content",
      },
      ifid = {
        type = "string",
        description = "Interactive Fiction ID (UUID)",
      },
      start = {
        type = "string",
        default = "Start",
        description = "Name of the starting passage",
      },
      zoom = {
        type = "number",
        default = 1.0,
        description = "Editor zoom level",
      },
      tags = {
        type = "array",
        items = {type = "string"},
        description = "Story-level tags",
      },
      metadata = {
        type = "object",
        description = "Additional metadata",
      },
      passages = {
        type = "array",
        items = {
          type = "object",
          required = {"name", "content"},
          properties = {
            name = {
              type = "string",
              description = "Passage title",
            },
            content = {
              type = "string",
              description = "Passage content in the story format",
            },
            tags = {
              type = "array",
              items = {type = "string"},
              description = "Passage tags",
            },
            position = {
              type = "object",
              properties = {
                x = {type = "number"},
                y = {type = "number"},
              },
              description = "Editor position",
            },
            size = {
              type = "object",
              properties = {
                width = {type = "number"},
                height = {type = "number"},
              },
              description = "Editor size",
            },
          },
        },
      },
    },
  }
end

--- Export schema as JSON string
-- @param pretty boolean Whether to format with indentation
-- @return string JSON schema
function M:to_json(pretty)
  local json = require("whisker.utils.json")
  local schema = self:get_json_schema()
  if pretty then
    return json.encode(schema, 1)
  else
    return json.encode(schema)
  end
end

return M
