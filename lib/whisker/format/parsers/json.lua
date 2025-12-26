--- JSON Story Parser
-- Parses JSON story files into internal story format
-- @module whisker.format.parsers.json

local M = {}
M._dependencies = {"json_codec", "story_schema"}

-- Lazy-loaded dependencies
local _json = nil
local _schema = nil

local function get_json()
  if not _json then
    _json = require("whisker.utils.json")
  end
  return _json
end

local function get_schema()
  if not _schema then
    local SchemaClass = require("whisker.format.schemas.story_schema")
    _schema = SchemaClass.new()
  end
  return _schema
end

--- Create a new JSON parser instance
-- @param deps table Dependencies
-- @return JsonParser instance
function M.new(deps)
  local self = setmetatable({}, {__index = M})
  self._json = deps and deps.json_codec or get_json()
  self._schema = deps and deps.story_schema or get_schema()
  return self
end

--- Parse JSON content into story structure
-- @param content string JSON content
-- @param options table Optional parsing options
-- @return table|nil Parsed story
-- @return string|nil Error message
function M.parse(content, options)
  options = options or {}
  local json = get_json()
  local schema = get_schema()

  -- Decode JSON
  local story, err = json.decode(content)
  if not story then
    return nil, "JSON parse error: " .. tostring(err)
  end

  -- Validate against schema (optional)
  if options.validate ~= false then
    local valid, errors = schema:validate(story)
    if not valid then
      return nil, "Validation errors: " .. table.concat(errors, "; ")
    end
  end

  -- Apply defaults
  story = schema:apply_defaults(story)

  -- Normalize to internal format
  local normalized = M.normalize_story(story)

  return normalized
end

--- Normalize a story object to internal format
-- @param story table Raw story object
-- @return table Normalized story
function M.normalize_story(story)
  local result = {
    name = story.name,
    format = story.format or "harlowe",
    ifid = story.ifid,
    start = story.start or "Start",
    zoom = story.zoom or 1.0,
    tags = story.tags or {},
    metadata = story.metadata or {},
    passages = {},
  }

  -- Normalize passages
  if story.passages then
    for _, passage in ipairs(story.passages) do
      local normalized_passage = {
        name = passage.name,
        content = passage.content or "",
        tags = passage.tags or {},
      }

      -- Optional position
      if passage.position then
        normalized_passage.position = {
          x = passage.position.x or 0,
          y = passage.position.y or 0,
        }
      end

      -- Optional size
      if passage.size then
        normalized_passage.size = {
          width = passage.size.width or 100,
          height = passage.size.height or 100,
        }
      end

      table.insert(result.passages, normalized_passage)
    end
  end

  return result
end

--- Parse JSON from file
-- @param path string File path
-- @param options table Optional parsing options
-- @return table|nil Parsed story
-- @return string|nil Error message
function M.parse_file(path, options)
  local file, err = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. tostring(err)
  end

  local content = file:read("*all")
  file:close()

  return M.parse(content, options)
end

--- Check if content is valid JSON
-- @param content string Content to check
-- @return boolean True if valid JSON
function M.is_json(content)
  local json = get_json()
  local result, _ = json.decode(content)
  return result ~= nil
end

--- Detect if content is a JSON story
-- @param content string Content to check
-- @return boolean True if appears to be a JSON story
function M.is_json_story(content)
  local json = get_json()
  local result, _ = json.decode(content)
  if not result or type(result) ~= "table" then
    return false
  end

  -- Check for story-like structure
  return result.passages ~= nil and result.name ~= nil
end

--- Export story to JSON
-- @param story table Story object
-- @param options table Export options
-- @return string JSON content
-- @return string|nil Error message
function M.to_json(story, options)
  options = options or {}
  local json = get_json()
  local schema = get_schema()

  -- Validate before export
  if options.validate ~= false then
    local valid, errors = schema:validate(story)
    if not valid then
      return nil, "Validation errors: " .. table.concat(errors, "; ")
    end
  end

  -- Add schema version to metadata
  local export_story = {}
  for k, v in pairs(story) do
    export_story[k] = v
  end

  export_story.metadata = export_story.metadata or {}
  export_story.metadata.schemaVersion = schema.SCHEMA_VERSION
  export_story.metadata.exported = os.date("%Y-%m-%dT%H:%M:%S")

  -- Encode
  if options.pretty then
    return json.encode(export_story, 1)
  else
    return json.encode(export_story)
  end
end

--- Convert parsed story to Twee format
-- @param story table Parsed story
-- @return string Twee format content
function M.to_twee(story)
  local result = {}

  -- Story metadata header (optional)
  if story.ifid or story.name then
    table.insert(result, ":: StoryData")
    local json = get_json()
    local metadata = {
      ifid = story.ifid,
      format = story.format,
      start = story.start,
    }
    table.insert(result, json.encode(metadata))
    table.insert(result, "")
  end

  -- Convert each passage
  for _, passage in ipairs(story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)
    table.insert(result, passage.content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Twee format to JSON story object
-- @param twee_content string Twee format content
-- @param format string Source format (harlowe, sugarcube, etc.)
-- @return table Story object suitable for JSON export
function M.from_twee(twee_content, format)
  format = format or "harlowe"

  -- Get the appropriate parser
  local parser
  local ok, p = pcall(require, "whisker.format.parsers." .. format)
  if ok then
    parser = p
  else
    -- Fall back to harlowe parser
    parser = require("whisker.format.parsers.harlowe")
  end

  -- Parse the Twee content
  local parsed = parser.parse(twee_content)

  -- Build JSON story object
  local story = {
    name = "Imported Story",
    format = format,
    start = "Start",
    passages = parsed.passages,
    metadata = {
      imported = os.date("%Y-%m-%dT%H:%M:%S"),
      sourceFormat = format,
    }
  }

  -- Try to find story name from StoryTitle passage
  for _, passage in ipairs(parsed.passages) do
    if passage.name == "StoryTitle" then
      story.name = passage.content:match("^%s*(.-)%s*$") or "Imported Story"
      break
    end
  end

  return story
end

return M
