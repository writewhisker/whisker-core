--- Story Schema Definition
-- Defines the JSON schema for story import/export
-- @module whisker.format.schemas.story_schema
-- GAP-020: JSON Settings Section

local M = {}
M._dependencies = {"json_codec"}

--- Schema version for compatibility checking
M.SCHEMA_VERSION = "1.0.0"

--- JSON format version for compatibility checking (GAP-010)
M.FORMAT_VERSION = "1.0.0"

--- WLS specification version this implementation targets (GAP-011)
M.WLS_VERSION = "1.0.0"

--- Default values for optional fields
M.DEFAULTS = {
  format = "harlowe",
  ifid = nil,
  start = "Start",
  zoom = 1.0,
  tags = {},
}

--- Default settings values (GAP-020)
M.DEFAULT_SETTINGS = {
    tunnel_limit = 100,
    choice_fallback = "implicit_end",
    random_seed = nil,
    strict_mode = false,
    strict_hooks = false,
    debug = false,
    end_text = "The End",
    continue_text = "Continue",
    max_include_depth = 50,
}

--- Valid choice fallback behaviors (GAP-016)
M.VALID_FALLBACK_BEHAVIORS = {
    implicit_end = true,
    continue = true,
    error = true,
    none = true,
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

  -- GAP-020: Apply default settings
  result.settings = self:apply_default_settings(result.settings)

  return result
end

-- ============================================================================
-- WLS 1.0 GAP-020: Settings Validation and Management
-- ============================================================================

--- Validate settings object
---@param settings table
---@return boolean valid
---@return table errors
function M:validate_settings(settings)
    local errors = {}

    if settings == nil then
        return true, errors
    end

    if type(settings) ~= "table" then
        return false, {"settings must be an object"}
    end

    -- Validate tunnel_limit
    if settings.tunnel_limit ~= nil then
        if type(settings.tunnel_limit) ~= "number" then
            table.insert(errors, "settings.tunnel_limit must be a number")
        elseif settings.tunnel_limit < 1 then
            table.insert(errors, "settings.tunnel_limit must be at least 1")
        end
    end

    -- Validate choice_fallback
    if settings.choice_fallback ~= nil then
        if type(settings.choice_fallback) ~= "string" then
            table.insert(errors, "settings.choice_fallback must be a string")
        elseif not M.VALID_FALLBACK_BEHAVIORS[settings.choice_fallback] then
            local valid_list = {}
            for k, _ in pairs(M.VALID_FALLBACK_BEHAVIORS) do
                table.insert(valid_list, k)
            end
            table.sort(valid_list)
            table.insert(errors, "settings.choice_fallback must be one of: " .. table.concat(valid_list, ", "))
        end
    end

    -- Validate random_seed
    if settings.random_seed ~= nil then
        if type(settings.random_seed) ~= "number" and type(settings.random_seed) ~= "string" then
            table.insert(errors, "settings.random_seed must be a number or string")
        end
    end

    -- Validate boolean settings
    for _, key in ipairs({"strict_mode", "strict_hooks", "debug"}) do
        if settings[key] ~= nil and type(settings[key]) ~= "boolean" then
            table.insert(errors, "settings." .. key .. " must be a boolean")
        end
    end

    -- Validate string settings
    for _, key in ipairs({"end_text", "continue_text"}) do
        if settings[key] ~= nil and type(settings[key]) ~= "string" then
            table.insert(errors, "settings." .. key .. " must be a string")
        end
    end

    -- Validate max_include_depth
    if settings.max_include_depth ~= nil then
        if type(settings.max_include_depth) ~= "number" then
            table.insert(errors, "settings.max_include_depth must be a number")
        elseif settings.max_include_depth < 1 then
            table.insert(errors, "settings.max_include_depth must be at least 1")
        end
    end

    return #errors == 0, errors
end

--- Apply default settings
---@param settings table|nil
---@return table
function M:apply_default_settings(settings)
    local result = {}

    -- Start with defaults
    for k, v in pairs(M.DEFAULT_SETTINGS) do
        result[k] = v
    end

    -- Override with provided settings
    if settings then
        for k, v in pairs(settings) do
            result[k] = v
        end
    end

    return result
end

--- Serialize settings, omitting default values (for clean JSON)
---@param settings table
---@return table|nil
function M:serialize_settings(settings)
    if not settings then
        return nil
    end

    local result = {}
    local has_values = false

    for key, value in pairs(settings) do
        -- Only include if different from default
        if value ~= M.DEFAULT_SETTINGS[key] then
            result[key] = value
            has_values = true
        end
    end

    return has_values and result or nil
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
