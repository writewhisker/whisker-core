--- Ink Choice Mapper
-- Maps Ink choices to Whisker choice format
-- @module whisker.formats.ink.choice_mapper
-- @author Whisker Core Team
-- @license MIT

local ChoiceMapper = {}

--- Convert Ink choices to Whisker format
-- @param ink_choices table Array of raw Ink choice objects
-- @return table Array of Whisker choice objects
function ChoiceMapper.to_whisker(ink_choices)
  local whisker_choices = {}

  for i, ink_choice in ipairs(ink_choices) do
    local whisker_choice = {
      -- Standard Whisker choice fields
      id = "choice_" .. i,
      index = i,
      text = ink_choice.text or "",
      target = nil, -- Ink handles navigation internally

      -- Extended fields from Ink
      tags = ink_choice.tags or {},
      is_invisible = ink_choice.isInvisibleDefault or false,

      -- Metadata for debugging/introspection
      metadata = {
        source = "ink",
        source_path = ink_choice.sourcePath,
        target_path = ink_choice.targetPath,
        thread_index = ink_choice.originalThreadIndex,
      },

      -- Keep original for engine use
      _original = ink_choice,
    }

    table.insert(whisker_choices, whisker_choice)
  end

  return whisker_choices
end

--- Convert Whisker choice selection to Ink format
-- @param whisker_choice table The selected Whisker choice
-- @param ink_choices table The original Ink choices
-- @return number Ink choice index (1-based)
-- @return string|nil Error message
function ChoiceMapper.to_ink_selection(whisker_choice, ink_choices)
  -- If choice has original Ink data, use it directly
  if whisker_choice._original then
    return whisker_choice.index
  end

  -- Match by index
  if whisker_choice.index and whisker_choice.index >= 1 and whisker_choice.index <= #ink_choices then
    return whisker_choice.index
  end

  -- Match by text
  for i, ink_choice in ipairs(ink_choices) do
    if ink_choice.text == whisker_choice.text then
      return i
    end
  end

  return nil, "Could not map choice to Ink format"
end

--- Check if an Ink choice should be visible
-- @param ink_choice table The Ink choice
-- @return boolean
function ChoiceMapper.is_visible(ink_choice)
  return not (ink_choice.isInvisibleDefault or false)
end

--- Filter visible choices only
-- @param ink_choices table Array of Ink choices
-- @return table Visible choices only
function ChoiceMapper.filter_visible(ink_choices)
  local visible = {}

  for _, choice in ipairs(ink_choices) do
    if ChoiceMapper.is_visible(choice) then
      table.insert(visible, choice)
    end
  end

  return visible
end

--- Get choice by index
-- @param choices table Array of choices
-- @param index number 1-based index
-- @return table|nil Choice or nil
function ChoiceMapper.get_by_index(choices, index)
  if index < 1 or index > #choices then
    return nil
  end
  return choices[index]
end

--- Get choice by text (first match)
-- @param choices table Array of choices
-- @param text string Choice text to find
-- @return table|nil Choice or nil
-- @return number|nil Index or nil
function ChoiceMapper.find_by_text(choices, text)
  for i, choice in ipairs(choices) do
    if choice.text == text then
      return choice, i
    end
  end
  return nil, nil
end

--- Extract tags from choice
-- @param choice table Choice object
-- @return table Array of tags
function ChoiceMapper.get_tags(choice)
  return choice.tags or {}
end

--- Check if choice has specific tag
-- @param choice table Choice object
-- @param tag string Tag to check
-- @return boolean
function ChoiceMapper.has_tag(choice, tag)
  local tags = ChoiceMapper.get_tags(choice)
  for _, t in ipairs(tags) do
    if t == tag then
      return true
    end
  end
  return false
end

--- Create choice summary for debugging
-- @param choices table Array of choices
-- @return string Summary text
function ChoiceMapper.summarize(choices)
  local lines = {}

  for i, choice in ipairs(choices) do
    local line = string.format("%d. %s", i, choice.text or "(no text)")
    if choice.tags and #choice.tags > 0 then
      line = line .. " [" .. table.concat(choice.tags, ", ") .. "]"
    end
    table.insert(lines, line)
  end

  return table.concat(lines, "\n")
end

return ChoiceMapper
