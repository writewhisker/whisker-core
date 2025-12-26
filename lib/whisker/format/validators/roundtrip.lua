-- Round-trip Validation Module
-- Validates conversion fidelity through round-trip testing

local M = {}
M._dependencies = {}

--- Create a new round-trip validator
-- @return table Validator instance
function M.new(deps)
  deps = deps or {}
  local self = setmetatable({}, {__index = M})
  return self
end

--- Normalize content for comparison (remove extra whitespace)
-- @param content string Content to normalize
-- @return string Normalized content
function M:normalize(content)
  if not content then return "" end
  return content:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Compare two stories for differences
-- @param story1 table First story
-- @param story2 table Second story
-- @return table Comparison result
function M:compare_stories(story1, story2)
  local result = {
    identical = true,
    passage_count_match = #story1.passages == #story2.passages,
    passage_count_1 = #story1.passages,
    passage_count_2 = #story2.passages,
    differences = {}
  }

  -- Build lookup for story1 passages
  local passages1 = {}
  for _, p in ipairs(story1.passages) do
    passages1[p.name] = p
  end

  -- Build lookup for story2 passages
  local passages2 = {}
  for _, p in ipairs(story2.passages) do
    passages2[p.name] = p
  end

  -- Check for passages in story2 not in story1
  for name, p2 in pairs(passages2) do
    local p1 = passages1[name]
    if not p1 then
      table.insert(result.differences, {
        type = "missing_passage",
        passage = name,
        in_story = 1,
        description = "Passage '" .. name .. "' exists in story2 but not in story1"
      })
      result.identical = false
    else
      -- Compare content
      local content_diff = self:compare_content(p1.content, p2.content, name)
      if content_diff then
        table.insert(result.differences, content_diff)
        result.identical = false
      end

      -- Compare tags
      local tag_diff = self:compare_tags(p1.tags or {}, p2.tags or {}, name)
      if tag_diff then
        table.insert(result.differences, tag_diff)
        result.identical = false
      end
    end
  end

  -- Check for passages in story1 not in story2
  for name, _ in pairs(passages1) do
    if not passages2[name] then
      table.insert(result.differences, {
        type = "missing_passage",
        passage = name,
        in_story = 2,
        description = "Passage '" .. name .. "' exists in story1 but not in story2"
      })
      result.identical = false
    end
  end

  if not result.passage_count_match then
    result.identical = false
  end

  return result
end

--- Compare content of two passages
-- @param content1 string First content
-- @param content2 string Second content
-- @param passage_name string Name of passage (for reporting)
-- @return table|nil Difference description or nil if identical
function M:compare_content(content1, content2, passage_name)
  local norm1 = self:normalize(content1)
  local norm2 = self:normalize(content2)

  if norm1 ~= norm2 then
    return {
      type = "content_mismatch",
      passage = passage_name,
      original = content1,
      roundtrip = content2,
      original_normalized = norm1,
      roundtrip_normalized = norm2,
      description = "Content differs in passage '" .. passage_name .. "'"
    }
  end
  return nil
end

--- Compare tags of two passages
-- @param tags1 table First tag list
-- @param tags2 table Second tag list
-- @param passage_name string Name of passage
-- @return table|nil Difference description or nil if identical
function M:compare_tags(tags1, tags2, passage_name)
  -- Sort for comparison
  local sorted1 = {}
  local sorted2 = {}
  for _, t in ipairs(tags1) do table.insert(sorted1, t) end
  for _, t in ipairs(tags2) do table.insert(sorted2, t) end
  table.sort(sorted1)
  table.sort(sorted2)

  local tags_match = #sorted1 == #sorted2
  if tags_match then
    for i, t in ipairs(sorted1) do
      if t ~= sorted2[i] then
        tags_match = false
        break
      end
    end
  end

  if not tags_match then
    return {
      type = "tags_mismatch",
      passage = passage_name,
      original_tags = tags1,
      roundtrip_tags = tags2,
      description = "Tags differ in passage '" .. passage_name .. "'"
    }
  end
  return nil
end

--- Extract links from content (multiple formats)
-- @param content string Content to extract links from
-- @return table Array of link objects {text, target}
function M:extract_links(content)
  local links = {}

  -- Harlowe/Chapbook [[Text->Target]]
  for text, target in content:gmatch("%[%[([^%]>]+)%->([^%]]+)%]%]") do
    table.insert(links, {text = text, target = target})
  end

  -- SugarCube [[Text|Target]]
  for text, target in content:gmatch("%[%[([^%]|]+)|([^%]]+)%]%]") do
    table.insert(links, {text = text, target = target})
  end

  -- Simple [[Target]] (avoid matching already-captured links)
  for target in content:gmatch("%[%[([^%]|>]+)%]%]") do
    -- Only add if not already captured
    local found = false
    for _, link in ipairs(links) do
      if link.target == target then
        found = true
        break
      end
    end
    if not found then
      table.insert(links, {text = target, target = target})
    end
  end

  -- Snowman [Text](Target)
  for text, target in content:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
    table.insert(links, {text = text, target = target})
  end

  return links
end

--- Compare links between two contents
-- @param links1 table First link list
-- @param links2 table Second link list
-- @return table Comparison result
function M:compare_links(links1, links2)
  local result = {
    preserved = true,
    count_match = #links1 == #links2,
    links1_count = #links1,
    links2_count = #links2,
    missing_from_2 = {},
    missing_from_1 = {}
  }

  -- Create lookup by target
  local targets1 = {}
  local targets2 = {}
  for _, l in ipairs(links1) do targets1[l.target] = l end
  for _, l in ipairs(links2) do targets2[l.target] = l end

  for target, _ in pairs(targets1) do
    if not targets2[target] then
      table.insert(result.missing_from_2, target)
      result.preserved = false
    end
  end

  for target, _ in pairs(targets2) do
    if not targets1[target] then
      table.insert(result.missing_from_1, target)
      result.preserved = false
    end
  end

  return result
end

--- Extract variables from content based on format
-- @param content string Content to extract from
-- @param format string Format name ("harlowe", "sugarcube", etc.)
-- @return table Map of variable names to values
function M:extract_variables(content, format)
  local vars = {}

  if format == "harlowe" then
    for var, val in content:gmatch("%(%s*set:%s*%$([%w_]+)%s+to%s+([^%)]+)%)") do
      vars[var] = val
    end
  elseif format == "sugarcube" then
    for var, val in content:gmatch("<<set%s+%$([%w_]+)%s+to%s+(.-)>>") do
      vars[var] = val
    end
  elseif format == "chapbook" then
    -- Chapbook vars section format: name: value
    for var, val in content:gmatch("([%w_]+):%s*([^\n]+)") do
      vars[var] = val
    end
  elseif format == "snowman" then
    for var, val in content:gmatch("s%.([%w_]+)%s*=%s*([^;]+)") do
      vars[var] = val
    end
  end

  return vars
end

--- Compare variables between two stories
-- @param vars1 table First variable map
-- @param vars2 table Second variable map
-- @return table Comparison result
function M:compare_variables(vars1, vars2)
  local result = {
    preserved = true,
    differences = {}
  }

  for name, val1 in pairs(vars1) do
    local val2 = vars2[name]
    if not val2 then
      table.insert(result.differences, {
        variable = name,
        type = "missing",
        original = val1
      })
      result.preserved = false
    elseif self:normalize(val1) ~= self:normalize(val2) then
      table.insert(result.differences, {
        variable = name,
        type = "value_changed",
        original = val1,
        roundtrip = val2
      })
      result.preserved = false
    end
  end

  for name, val2 in pairs(vars2) do
    if not vars1[name] then
      table.insert(result.differences, {
        variable = name,
        type = "added",
        value = val2
      })
      result.preserved = false
    end
  end

  return result
end

--- Perform semantic comparison between two stories
-- @param story1 table First story
-- @param format1 string Format of first story
-- @param story2 table Second story
-- @param format2 string Format of second story
-- @return table Semantic comparison result
function M:compare_semantics(story1, format1, story2, format2)
  local result = {
    links_preserved = true,
    variables_preserved = true,
    passage_structure_preserved = true,
    issues = {}
  }

  -- Compare passage structure
  if #story1.passages ~= #story2.passages then
    result.passage_structure_preserved = false
    table.insert(result.issues, {
      type = "passage_count_mismatch",
      story1_count = #story1.passages,
      story2_count = #story2.passages
    })
  end

  -- Compare links across all passages
  for i, p1 in ipairs(story1.passages) do
    local p2 = story2.passages[i]
    if p2 then
      local links1 = self:extract_links(p1.content)
      local links2 = self:extract_links(p2.content)
      local link_result = self:compare_links(links1, links2)
      if not link_result.preserved then
        result.links_preserved = false
        table.insert(result.issues, {
          type = "links_differ",
          passage = p1.name,
          details = link_result
        })
      end
    end
  end

  -- Compare variables across all passages
  for i, p1 in ipairs(story1.passages) do
    local p2 = story2.passages[i]
    if p2 then
      local vars1 = self:extract_variables(p1.content, format1)
      local vars2 = self:extract_variables(p2.content, format2)
      local var_result = self:compare_variables(vars1, vars2)
      if not var_result.preserved then
        result.variables_preserved = false
        table.insert(result.issues, {
          type = "variables_differ",
          passage = p1.name,
          details = var_result
        })
      end
    end
  end

  return result
end

--- Validate story structure
-- @param story table Story to validate
-- @return table Validation result
function M:validate_structure(story)
  local result = {
    valid = true,
    errors = {},
    warnings = {}
  }

  -- Check for story name
  if not story.name or story.name == "" then
    table.insert(result.warnings, {
      type = "missing_name",
      message = "Story has no name"
    })
  end

  -- Check for passages
  if not story.passages or #story.passages == 0 then
    table.insert(result.errors, {
      type = "no_passages",
      message = "Story has no passages"
    })
    result.valid = false
    return result
  end

  -- Check for duplicate passage names
  local names = {}
  for _, passage in ipairs(story.passages) do
    if names[passage.name] then
      table.insert(result.errors, {
        type = "duplicate_passage",
        passage = passage.name,
        message = "Duplicate passage name: " .. passage.name
      })
      result.valid = false
    end
    names[passage.name] = true
  end

  -- Check for empty passages
  for _, passage in ipairs(story.passages) do
    if not passage.content or passage.content == "" then
      table.insert(result.warnings, {
        type = "empty_passage",
        passage = passage.name,
        message = "Passage '" .. passage.name .. "' has no content"
      })
    end
  end

  -- Check for broken links
  for _, passage in ipairs(story.passages) do
    local links = self:extract_links(passage.content or "")
    for _, link in ipairs(links) do
      if not names[link.target] then
        table.insert(result.warnings, {
          type = "broken_link",
          passage = passage.name,
          target = link.target,
          message = "Link to non-existent passage '" .. link.target .. "' in '" .. passage.name .. "'"
        })
      end
    end
  end

  return result
end

--- Get summary of comparison result
-- @param comparison table Comparison result
-- @return string Human-readable summary
function M:get_summary(comparison)
  local lines = {}

  if comparison.identical then
    table.insert(lines, "Stories are identical")
  else
    table.insert(lines, "Stories differ:")
    table.insert(lines, string.format("  Passage counts: %d vs %d",
      comparison.passage_count_1, comparison.passage_count_2))

    for _, diff in ipairs(comparison.differences) do
      table.insert(lines, "  - " .. diff.description)
    end
  end

  return table.concat(lines, "\n")
end

return M
