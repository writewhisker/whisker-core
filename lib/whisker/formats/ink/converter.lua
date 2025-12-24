--- Ink to Whisker Story Converter
-- Converts Ink JSON to Whisker's internal story format
-- @module whisker.formats.ink.converter
-- @author Whisker Core Team
-- @license MIT

local InkConverter = {}

--- Dependencies injected via container
InkConverter._dependencies = { "json_codec" }

--- Get or lazy-load JSON codec
-- @param deps table|nil Dependencies that may include json_codec
-- @return IJsonCodec
local function get_json_codec(deps)
  if deps and deps.json_codec then
    return deps.json_codec
  end
  -- Lazy-load default codec
  local JsonCodec = require("whisker.vendor.codecs.json_codec")
  return JsonCodec.new()
end

--- Import Ink JSON to Whisker story format
-- @param json_text string The Ink JSON string
-- @param deps table|nil Dependencies (json_codec, events, log)
-- @return Story|nil The imported story
-- @return string|nil Error message
function InkConverter.import(json_text, deps)
  deps = deps or {}
  local json_codec = get_json_codec(deps)

  -- Parse JSON
  local ink_data, err = json_codec:decode(json_text)
  if err then
    return nil, "Failed to parse Ink JSON: " .. err
  end

  -- Validate Ink structure
  if not ink_data.inkVersion then
    return nil, "Missing inkVersion in Ink JSON"
  end

  if not ink_data.root then
    return nil, "Missing root in Ink JSON"
  end

  -- Create story structure
  local story = {
    id = "ink_story_" .. os.time(),
    format = "ink",
    metadata = {
      inkVersion = ink_data.inkVersion,
      original_format = "ink",
      imported_at = os.time(),
    },
    passages = {},
    variables = {},
    start = "root",
    _raw_ink = ink_data, -- Keep raw data for engine
  }

  -- Extract top-level knots as passages
  local passages = InkConverter._extract_passages(ink_data)
  story.passages = passages

  -- Extract global variables
  if ink_data.root then
    local vars = InkConverter._extract_variables(ink_data)
    story.variables = vars
  end

  -- Extract list definitions
  if ink_data.listDefs then
    story.metadata.listDefs = ink_data.listDefs
  end

  return story, nil
end

--- Extract passages (knots) from Ink data
-- @param ink_data table Parsed Ink JSON
-- @return table Array of passage objects
function InkConverter._extract_passages(ink_data)
  local passages = {}

  -- Root is always the first passage
  table.insert(passages, {
    id = "root",
    title = "Start",
    content = "",
    choices = {},
    metadata = {
      is_root = true,
    },
  })

  -- Extract named knots from root structure
  -- In Ink JSON, knots are stored as named content
  if type(ink_data.root) == "table" then
    local named_content = InkConverter._find_named_content(ink_data.root)

    for name, content in pairs(named_content) do
      if name ~= "global decl" and not name:match("^#") then
        local passage = {
          id = name,
          title = name,
          content = InkConverter._extract_text_content(content),
          choices = InkConverter._extract_choices(content),
          metadata = {
            type = "knot",
          },
        }
        table.insert(passages, passage)
      end
    end
  end

  return passages
end

--- Find named content in Ink container
-- @param container table Ink container array
-- @return table Named content map
function InkConverter._find_named_content(container)
  local named = {}

  if type(container) ~= "table" then
    return named
  end

  -- Named content is typically in the last element
  local last = container[#container]
  if type(last) == "table" and not last[1] then
    -- This is an object, not an array - contains named content
    for key, value in pairs(last) do
      if not key:match("^#") then -- Skip metadata keys
        named[key] = value
      end
    end
  end

  return named
end

--- Extract text content from Ink container
-- @param container table Ink container
-- @return string Text content
function InkConverter._extract_text_content(container)
  local text_parts = {}

  if type(container) ~= "table" then
    return ""
  end

  for _, item in ipairs(container) do
    if type(item) == "string" then
      if item:sub(1, 1) == "^" then
        table.insert(text_parts, item:sub(2))
      elseif item == "\n" then
        table.insert(text_parts, "\n")
      end
    end
  end

  return table.concat(text_parts)
end

--- Extract choices from Ink container
-- @param container table Ink container
-- @return table Array of choice objects
function InkConverter._extract_choices(container)
  local choices = {}

  if type(container) ~= "table" then
    return choices
  end

  for _, item in ipairs(container) do
    if type(item) == "table" then
      -- Look for choice point markers
      if item["*"] then
        local choice = {
          text = "", -- Will be filled from choice content
          target = item["*"]:gsub("%..*$", ""), -- Remove stitch part for simple target
          conditions = {},
          metadata = {
            path = item["*"],
            flags = item["flg"],
          },
        }
        table.insert(choices, choice)
      end
    end
  end

  return choices
end

--- Extract variables from Ink data
-- @param ink_data table Parsed Ink JSON
-- @return table Variables map
function InkConverter._extract_variables(ink_data)
  local variables = {}

  -- Variables are initialized in "global decl" section
  if type(ink_data.root) == "table" then
    local named = InkConverter._find_named_content(ink_data.root)
    if named["global decl"] then
      variables = InkConverter._parse_global_decl(named["global decl"])
    end
  end

  return variables
end

--- Parse global declarations
-- @param decl table Global declaration container
-- @return table Variables
function InkConverter._parse_global_decl(decl)
  local vars = {}

  if type(decl) ~= "table" then
    return vars
  end

  for _, item in ipairs(decl) do
    if type(item) == "table" then
      -- Variable assignment
      if item["VAR="] then
        local name = item["VAR="]
        vars[name] = {
          name = name,
          initial_value = nil, -- Would need to evaluate
          type = "global",
        }
      end
    end
  end

  return vars
end

return InkConverter
