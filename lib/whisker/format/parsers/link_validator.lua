--- Link Validator
-- Validate link targets in stories
-- @module whisker.format.parsers.link_validator
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

--- Extract links from Harlowe content
-- @param content string Passage content
-- @return table Array of link objects
function M.extract_harlowe_links(content)
  local links = {}

  -- [[Text->Target]]
  for pos, text, target in content:gmatch("()%[%[(.-)%->(.-)%]%]") do
    table.insert(links, {
      position = pos,
      text = text:match("^%s*(.-)%s*$"),
      target = target:match("^%s*(.-)%s*$"),
      type = "arrow"
    })
  end

  -- [[Target]] (simple) - but not those with ->
  for pos, target in content:gmatch("()%[%[([^%]%-]+)%]%]") do
    -- Skip if it contains -> (already matched above)
    if not target:match("->") then
      table.insert(links, {
        position = pos,
        text = target:match("^%s*(.-)%s*$"),
        target = target:match("^%s*(.-)%s*$"),
        type = "simple"
      })
    end
  end

  -- (goto: "Target") and (display: "Target")
  for pos, macro, target in content:gmatch("()%((%w+):%s*\"([^\"]+)\"%s*%)") do
    if macro == "goto" or macro == "display" or macro == "link-goto" then
      table.insert(links, {
        position = pos,
        text = nil,
        target = target,
        type = "macro"
      })
    end
  end

  return links
end

--- Extract links from SugarCube content
-- @param content string Passage content
-- @return table Array of link objects
function M.extract_sugarcube_links(content)
  local links = {}

  -- [[Text|Target]]
  for pos, text, target in content:gmatch("()%[%[(.-)%|(.-)%]%]") do
    table.insert(links, {
      position = pos,
      text = text:match("^%s*(.-)%s*$"),
      target = target:match("^%s*(.-)%s*$"),
      type = "pipe"
    })
  end

  -- [[Target]] (simple) - but not those with |
  for pos, target in content:gmatch("()%[%[([^%]|]+)%]%]") do
    -- Skip if it contains | (already matched above)
    if not target:match("|") then
      table.insert(links, {
        position = pos,
        text = target:match("^%s*(.-)%s*$"),
        target = target:match("^%s*(.-)%s*$"),
        type = "simple"
      })
    end
  end

  -- <<goto "Target">>
  for pos, target in content:gmatch("()<<goto%s+\"([^\"]+)\"%s*>>") do
    table.insert(links, {
      position = pos,
      text = nil,
      target = target,
      type = "macro"
    })
  end

  -- <<goto 'Target'>>
  for pos, target in content:gmatch("()<<goto%s+'([^']+)'%s*>>") do
    table.insert(links, {
      position = pos,
      text = nil,
      target = target,
      type = "macro"
    })
  end

  return links
end

--- Extract links from Chapbook content
-- @param content string Passage content
-- @return table Array of link objects
function M.extract_chapbook_links(content)
  local links = {}

  -- [[Text->Target]]
  for pos, text, target in content:gmatch("()%[%[(.-)%->(.-)%]%]") do
    table.insert(links, {
      position = pos,
      text = text:match("^%s*(.-)%s*$"),
      target = target:match("^%s*(.-)%s*$"),
      type = "arrow"
    })
  end

  -- [[Target]] (simple)
  for pos, target in content:gmatch("()%[%[([^%]%-]+)%]%]") do
    if not target:match("->") then
      table.insert(links, {
        position = pos,
        text = target:match("^%s*(.-)%s*$"),
        target = target:match("^%s*(.-)%s*$"),
        type = "simple"
      })
    end
  end

  -- {link to: 'Target'}
  for pos, target in content:gmatch("(){link to:%s*'([^']+)'") do
    table.insert(links, {
      position = pos,
      text = nil,
      target = target,
      type = "insert"
    })
  end

  -- {link to: "Target"}
  for pos, target in content:gmatch("(){link to:%s*\"([^\"]+)\"") do
    table.insert(links, {
      position = pos,
      text = nil,
      target = target,
      type = "insert"
    })
  end

  return links
end

--- Extract links from Snowman content
-- @param content string Passage content
-- @return table Array of link objects
function M.extract_snowman_links(content)
  local links = {}

  -- [Text](Target) - markdown style (including external URLs for categorization)
  for pos, text, target in content:gmatch("()%[([^%]]+)%]%(([^%)]+)%)") do
    table.insert(links, {
      position = pos,
      text = text:match("^%s*(.-)%s*$"),
      target = target:match("^%s*(.-)%s*$"),
      type = "markdown"
    })
  end

  -- [[Target]] (also supported)
  for pos, target in content:gmatch("()%[%[([^%]]+)%]%]") do
    table.insert(links, {
      position = pos,
      text = target:match("^%s*(.-)%s*$"),
      target = target:match("^%s*(.-)%s*$"),
      type = "simple"
    })
  end

  return links
end

--- Validate links against passage names
-- @param links table Array of link objects
-- @param passage_names table Set of valid passage names
-- @param passage_name string Current passage name (for context)
-- @return table Validation results
function M.validate_links(links, passage_names, passage_name)
  local results = {
    valid = {},
    broken = {},
    external = {}
  }

  for _, link in ipairs(links) do
    local target = link.target

    -- Skip external URLs
    if target:match("^https?://") or target:match("^mailto:") then
      link.category = "external"
      table.insert(results.external, link)
    elseif passage_names[target] then
      link.category = "valid"
      table.insert(results.valid, link)
    else
      -- Try case-insensitive match
      local found = false
      for name, _ in pairs(passage_names) do
        if name:lower() == target:lower() then
          link.category = "valid"
          link.suggestion = name
          table.insert(results.valid, link)
          found = true
          break
        end
      end

      if not found then
        link.category = "broken"
        link.from_passage = passage_name
        table.insert(results.broken, link)
      end
    end
  end

  return results
end

--- Validate all links in a story
-- @param story table Parsed story
-- @param format string Format name
-- @return table Validation results
function M.validate_story(story, format)
  local extractor = M["extract_" .. format .. "_links"]
  if not extractor then
    extractor = M.extract_harlowe_links
  end

  -- Build passage name set
  local passage_names = {}
  for _, passage in ipairs(story.passages) do
    passage_names[passage.name] = true
  end

  local all_results = {
    total_links = 0,
    valid_count = 0,
    broken_count = 0,
    external_count = 0,
    broken_links = {},
    by_passage = {}
  }

  for _, passage in ipairs(story.passages) do
    local links = extractor(passage.content)
    local results = M.validate_links(links, passage_names, passage.name)

    all_results.total_links = all_results.total_links + #links
    all_results.valid_count = all_results.valid_count + #results.valid
    all_results.broken_count = all_results.broken_count + #results.broken
    all_results.external_count = all_results.external_count + #results.external

    for _, broken in ipairs(results.broken) do
      table.insert(all_results.broken_links, broken)
    end

    all_results.by_passage[passage.name] = results
  end

  return all_results
end

return M
