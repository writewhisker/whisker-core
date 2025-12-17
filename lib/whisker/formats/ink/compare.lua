-- whisker/formats/ink/compare.lua
-- Story comparison utilities for round-trip verification

local Compare = {}
Compare.__index = Compare

-- Module metadata
Compare._whisker = {
  name = "StoryCompare",
  version = "1.0.0",
  description = "Comparison utilities for Ink round-trip verification",
  depends = {},
  capability = "formats.ink.compare"
}

-- Create a new Compare instance
function Compare.new()
  local instance = {
    differences = {}
  }
  setmetatable(instance, Compare)
  return instance
end

-- Compare two stories
-- @param original table - Original story
-- @param converted table - Converted story
-- @return boolean, table - Match status and differences
function Compare:compare(original, converted)
  self.differences = {}

  -- Compare passages
  self:_compare_passages(original.passages or {}, converted.passages or {})

  -- Compare variables
  self:_compare_variables(original.variables or {}, converted.variables or {})

  -- Compare metadata
  self:_compare_metadata(original, converted)

  return #self.differences == 0, self.differences
end

-- Compare passages between stories
function Compare:_compare_passages(orig, conv)
  -- Check for missing passages
  for id, _ in pairs(orig) do
    if not conv[id] then
      table.insert(self.differences, {
        type = "missing_passage",
        id = id,
        message = "Passage missing in converted story: " .. id
      })
    end
  end

  -- Check for extra passages
  for id, _ in pairs(conv) do
    if not orig[id] then
      table.insert(self.differences, {
        type = "extra_passage",
        id = id,
        message = "Extra passage in converted story: " .. id
      })
    end
  end

  -- Compare matching passages
  for id, orig_passage in pairs(orig) do
    local conv_passage = conv[id]
    if conv_passage then
      self:_compare_passage(id, orig_passage, conv_passage)
    end
  end
end

-- Compare a single passage
function Compare:_compare_passage(id, orig, conv)
  -- Compare content
  local orig_content = self:_normalize_content(orig.content or orig.text)
  local conv_content = self:_normalize_content(conv.content or conv.text)

  if orig_content ~= conv_content then
    table.insert(self.differences, {
      type = "content_mismatch",
      id = id,
      original = orig_content,
      converted = conv_content,
      message = "Content differs in passage: " .. id
    })
  end

  -- Compare choice count
  local orig_choices = orig.choices or {}
  local conv_choices = conv.choices or {}

  if #orig_choices ~= #conv_choices then
    table.insert(self.differences, {
      type = "choice_count_mismatch",
      id = id,
      original_count = #orig_choices,
      converted_count = #conv_choices,
      message = "Choice count differs in passage: " .. id
    })
  end
end

-- Compare variables
function Compare:_compare_variables(orig, conv)
  for name, orig_var in pairs(orig) do
    local conv_var = conv[name]

    if not conv_var then
      table.insert(self.differences, {
        type = "missing_variable",
        name = name,
        message = "Variable missing in converted story: " .. name
      })
    else
      -- Compare type
      if orig_var.type ~= conv_var.type then
        table.insert(self.differences, {
          type = "variable_type_mismatch",
          name = name,
          original_type = orig_var.type,
          converted_type = conv_var.type,
          message = "Variable type differs: " .. name
        })
      end

      -- Compare default value
      if not self:_values_equal(orig_var.default, conv_var.default) then
        table.insert(self.differences, {
          type = "variable_default_mismatch",
          name = name,
          original_default = orig_var.default,
          converted_default = conv_var.default,
          message = "Variable default differs: " .. name
        })
      end
    end
  end

  -- Check for extra variables
  for name, _ in pairs(conv) do
    if not orig[name] then
      table.insert(self.differences, {
        type = "extra_variable",
        name = name,
        message = "Extra variable in converted story: " .. name
      })
    end
  end
end

-- Compare metadata
function Compare:_compare_metadata(orig, conv)
  if orig.start ~= conv.start then
    table.insert(self.differences, {
      type = "start_mismatch",
      original = orig.start,
      converted = conv.start,
      message = "Start passage differs"
    })
  end
end

-- Normalize content for comparison
function Compare:_normalize_content(content)
  if content == nil then
    return ""
  end

  if type(content) == "table" then
    return table.concat(content, "\n")
  end

  -- Normalize whitespace
  return content:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

-- Check if two values are equal
function Compare:_values_equal(a, b)
  if type(a) ~= type(b) then
    return false
  end

  if type(a) == "table" then
    for k, v in pairs(a) do
      if not self:_values_equal(v, b[k]) then
        return false
      end
    end
    for k, v in pairs(b) do
      if not self:_values_equal(v, a[k]) then
        return false
      end
    end
    return true
  end

  return a == b
end

-- Get difference count
function Compare:get_difference_count()
  return #self.differences
end

-- Get differences by type
function Compare:get_differences_by_type(diff_type)
  local result = {}
  for _, diff in ipairs(self.differences) do
    if diff.type == diff_type then
      table.insert(result, diff)
    end
  end
  return result
end

-- Generate comparison report
function Compare:generate_report()
  local lines = {}

  table.insert(lines, "=== Story Comparison Report ===")
  table.insert(lines, "")

  if #self.differences == 0 then
    table.insert(lines, "Stories are equivalent.")
  else
    table.insert(lines, string.format("Found %d difference(s):", #self.differences))
    table.insert(lines, "")

    for i, diff in ipairs(self.differences) do
      table.insert(lines, string.format("%d. [%s] %s", i, diff.type, diff.message))
    end
  end

  return table.concat(lines, "\n")
end

return Compare
