--- Ink Exporter
-- Exports Whisker stories to Ink JSON format
-- @module whisker.formats.ink.exporter
-- @author Whisker Core Team
-- @license MIT

local InkExporter = {}

--- Ink JSON version
InkExporter.INK_VERSION = 21

--- Check if a story can be exported to Ink format
-- @param story Story The story to check
-- @return boolean Can export
-- @return string|nil Reason if cannot export
function InkExporter.can_export(story)
  if not story then
    return false, "No story provided"
  end

  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end

  -- Check for features Ink doesn't support
  for _, passage in ipairs(story.passages) do
    if passage.metadata and passage.metadata.whisker_only then
      return false, "Story uses Whisker-only features"
    end

    -- Check for unsupported content types
    if passage.content_type and passage.content_type == "multimedia" then
      return false, "Ink does not support multimedia content"
    end
  end

  return true
end

--- Export Whisker story to Ink JSON
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return string|nil JSON string
-- @return string|nil Error message
function InkExporter.export(story, options)
  options = options or {}

  local can, reason = InkExporter.can_export(story)
  if not can then
    return nil, "Cannot export: " .. reason
  end

  -- Build Ink JSON structure
  local ink_structure = {
    inkVersion = InkExporter.INK_VERSION,
    root = {},
    listDefs = {},
  }

  -- Find start passage
  local start_id = story.start or "start"
  local start_passage = InkExporter._find_passage(story, start_id)

  if start_passage then
    ink_structure.root = InkExporter._passage_to_ink(start_passage)
  else
    -- Use first passage if start not found
    if #story.passages > 0 then
      ink_structure.root = InkExporter._passage_to_ink(story.passages[1])
    end
  end

  -- Add other passages as named content
  local named_content = {}
  for _, passage in ipairs(story.passages) do
    local id = passage.id
    if id ~= start_id and id ~= "root" then
      named_content[id] = InkExporter._passage_to_ink(passage)
    end
  end

  -- Add named content to root's last element
  if next(named_content) then
    table.insert(ink_structure.root, named_content)
  else
    table.insert(ink_structure.root, "TERM")
  end

  -- Export list definitions if present
  if story.metadata and story.metadata.listDefs then
    ink_structure.listDefs = story.metadata.listDefs
  end

  -- Encode to JSON
  local json = require("cjson")
  local ok, json_str = pcall(json.encode, ink_structure)

  if not ok then
    return nil, "Failed to encode JSON: " .. tostring(json_str)
  end

  return json_str
end

--- Find passage by ID
-- @param story Story The story
-- @param id string Passage ID
-- @return table|nil Passage or nil
-- @private
function InkExporter._find_passage(story, id)
  for _, passage in ipairs(story.passages) do
    if passage.id == id then
      return passage
    end
  end
  return nil
end

--- Convert passage to Ink content array
-- @param passage table Passage object
-- @return table Ink content array
-- @private
function InkExporter._passage_to_ink(passage)
  local content = {}

  -- Add text content
  if passage.content and #passage.content > 0 then
    -- Split into lines and add with proper Ink formatting
    local text = passage.content
    for line in text:gmatch("[^\n]+") do
      table.insert(content, "^" .. line)
      table.insert(content, "\n")
    end
  end

  -- Add tags
  if passage.tags then
    for _, tag in ipairs(passage.tags) do
      table.insert(content, { ["#"] = tag })
    end
  end

  -- Add choices
  if passage.choices and #passage.choices > 0 then
    for _, choice in ipairs(passage.choices) do
      local ink_choice = InkExporter._choice_to_ink(choice)
      table.insert(content, ink_choice)
    end
  else
    -- Add done command if no choices
    table.insert(content, "done")
  end

  return content
end

--- Convert choice to Ink format
-- @param choice table Choice object
-- @return table Ink choice structure
-- @private
function InkExporter._choice_to_ink(choice)
  local ink_choice = {}

  -- Choice point marker
  ink_choice["*"] = choice.target or "done"

  -- Choice flags
  local flags = 0

  -- Flag bit meanings in Ink:
  -- Bit 0: hasCondition
  -- Bit 1: hasStartContent
  -- Bit 2: hasChoiceOnlyContent
  -- Bit 3: onceOnly (default true)
  -- Bit 4: isInvisibleDefault

  if choice.once_only ~= false then
    flags = flags + 8 -- onceOnly flag
  end

  if choice.has_condition then
    flags = flags + 1
  end

  if choice.text and #choice.text > 0 then
    flags = flags + 4 -- hasChoiceOnlyContent
  end

  if flags > 0 then
    ink_choice["flg"] = flags
  end

  return ink_choice
end

--- Create minimal valid Ink JSON structure
-- @return table Empty Ink structure
function InkExporter.create_empty()
  return {
    inkVersion = InkExporter.INK_VERSION,
    root = {
      "done",
      "TERM",
    },
    listDefs = {},
  }
end

--- Validate Ink JSON structure
-- @param ink_json table Parsed Ink JSON
-- @return boolean Valid
-- @return string|nil Error message
function InkExporter.validate_structure(ink_json)
  if type(ink_json) ~= "table" then
    return false, "Ink JSON must be a table"
  end

  if not ink_json.inkVersion then
    return false, "Missing inkVersion"
  end

  if type(ink_json.inkVersion) ~= "number" then
    return false, "inkVersion must be a number"
  end

  if not ink_json.root then
    return false, "Missing root"
  end

  if type(ink_json.root) ~= "table" then
    return false, "root must be an array"
  end

  return true
end

return InkExporter
