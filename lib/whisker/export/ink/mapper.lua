--- Ink Mapper
-- Maps whisker-core story structures to Ink JSON format
-- @module whisker.export.ink.mapper
-- @author Whisker Core Team
-- @license MIT

local InkMapper = {}

--- Map whisker-core story to Ink JSON structure
-- @param story table Whisker story
-- @return table Ink JSON structure
function InkMapper.map_story(story)
  local ink_json = {
    inkVersion = 20,
    root = {},
    listDefs = {},
  }

  -- Build passage map for reference
  local passage_map = {}
  for _, passage in ipairs(story.passages or {}) do
    passage_map[passage.name] = passage
  end

  -- Convert each passage to a knot
  for _, passage in ipairs(story.passages or {}) do
    local knot_name = InkMapper.sanitize_name(passage.name)
    ink_json[knot_name] = InkMapper.map_passage(passage)
  end

  -- Build root flow starting from start passage
  local start_passage = story.start_passage or story.start or "start"
  local start_name = InkMapper.sanitize_name(start_passage)

  ink_json.root = {
    { "->", start_name },
    "done",
    { "#f", 1 }  -- Flag for root container
  }

  return ink_json
end

--- Map a passage to an Ink knot
-- @param passage table Whisker passage
-- @return table Ink knot content
function InkMapper.map_passage(passage)
  local knot = {}

  -- Add passage text as string content
  if passage.text and #passage.text > 0 then
    -- Split by newlines and add as separate elements
    for line in passage.text:gmatch("[^\n]+") do
      table.insert(knot, { "^", line })
      table.insert(knot, "\n")
    end
    -- If text doesn't end with newline, the last \n is extra but okay
  end

  -- Add choices
  local choices = passage.choices or passage.links or {}
  if #choices > 0 then
    for i, choice in ipairs(choices) do
      local choice_content = InkMapper.map_choice(choice, i)
      table.insert(knot, choice_content)
    end
  else
    -- No choices = end of story
    table.insert(knot, "done")
  end

  -- Add container metadata
  table.insert(knot, { "#f", 1 })

  return knot
end

--- Map a choice to Ink choice structure
-- @param choice table Whisker choice
-- @param index number Choice index
-- @return table Ink choice structure
function InkMapper.map_choice(choice, index)
  local target = InkMapper.sanitize_name(choice.target or choice.passage or "start")

  return {
    -- Choice text
    { "*", {
      { "^", choice.text or ("Choice " .. index) },
    }},
    -- Divert to target
    { "->", target },
  }
end

--- Check story compatibility with Ink format
-- @param story table Whisker story
-- @return table Compatibility result {compatible, issues}
function InkMapper.check_compatibility(story)
  local issues = {}

  if not story then
    table.insert(issues, {
      issue = "No story provided",
      severity = "error",
    })
    return { compatible = false, issues = issues }
  end

  if not story.passages or #story.passages == 0 then
    table.insert(issues, {
      issue = "Story has no passages",
      severity = "error",
    })
    return { compatible = false, issues = issues }
  end

  for _, passage in ipairs(story.passages) do
    -- Check for unsupported features
    if passage.lua_code then
      table.insert(issues, {
        passage = passage.name,
        issue = "Lua code not supported in Ink export",
        severity = "error",
      })
    end

    if passage.macros then
      table.insert(issues, {
        passage = passage.name,
        issue = "Macros not supported in Ink export",
        severity = "warning",
      })
    end

    -- Check for whisker-specific tags
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        if tag:match("^whisker%-") then
          table.insert(issues, {
            passage = passage.name,
            issue = "Whisker-specific tag '" .. tag .. "' will be ignored",
            severity = "warning",
          })
        end
      end
    end
  end

  -- Count errors
  local error_count = 0
  for _, issue in ipairs(issues) do
    if issue.severity == "error" then
      error_count = error_count + 1
    end
  end

  return {
    compatible = error_count == 0,
    issues = issues,
  }
end

--- Sanitize a name for use as Ink knot/stitch name
-- @param name string Original name
-- @return string Sanitized name
function InkMapper.sanitize_name(name)
  if not name then return "unnamed" end

  -- Replace spaces and special characters with underscores
  local sanitized = name:gsub("[^%w_]", "_")

  -- Ensure doesn't start with number
  if sanitized:match("^%d") then
    sanitized = "_" .. sanitized
  end

  -- Lowercase
  sanitized = sanitized:lower()

  return sanitized
end

return InkMapper
