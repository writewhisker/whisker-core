-- whisker/formats/ink/choice_adapter.lua
-- Adapter for converting Ink choices to whisker-core Choice format

local ChoiceAdapter = {}
ChoiceAdapter.__index = ChoiceAdapter

-- Module metadata
ChoiceAdapter._whisker = {
  name = "InkChoiceAdapter",
  version = "1.0.0",
  description = "Adapter for converting Ink choices to whisker-core format",
  depends = {},
  capability = "formats.ink.choice_adapter"
}

-- Create a new ChoiceAdapter instance
-- @return ChoiceAdapter
function ChoiceAdapter.new()
  local instance = {}
  setmetatable(instance, ChoiceAdapter)
  return instance
end

-- Convert a tinta choice to whisker-core Choice-compatible format
-- @param ink_choice table - tinta choice object
-- @param index number - 1-based index
-- @return table - whisker-core compatible choice
function ChoiceAdapter:adapt(ink_choice, index)
  if not ink_choice then
    return nil
  end

  local choice = {
    -- Core fields
    id = ink_choice.pathStringOnChoice or ("ink_choice_" .. index),
    index = index,
    text = ink_choice.text or "",
    target = ink_choice.pathStringOnChoice,

    -- Ink-specific metadata
    metadata = {
      ink_index = ink_choice.index or (index - 1),  -- tinta's 0-based index
      path = ink_choice.pathStringOnChoice,
      source_path = ink_choice.sourcePath,
      -- Ink choice types
      is_invisible_default = ink_choice.isInvisibleDefault or false,
      -- Tags if present
      tags = ink_choice.tags or {}
    }
  }

  return choice
end

-- Convert an array of tinta choices to whisker-core format
-- @param ink_choices table - Array of tinta choices
-- @return table - Array of whisker-core compatible choices
function ChoiceAdapter:adapt_all(ink_choices)
  local choices = {}

  if not ink_choices then
    return choices
  end

  for i, ink_choice in ipairs(ink_choices) do
    local adapted = self:adapt(ink_choice, i)
    if adapted then
      table.insert(choices, adapted)
    end
  end

  return choices
end

-- Convert a whisker-core Choice back to Ink format (for export)
-- @param choice table - whisker-core Choice
-- @return table - Ink choice data
function ChoiceAdapter:to_ink(choice)
  if not choice then
    return nil
  end

  return {
    text = choice.text,
    pathStringOnChoice = choice.target or choice.id,
    index = choice.metadata and choice.metadata.ink_index or (choice.index and choice.index - 1),
    isInvisibleDefault = choice.metadata and choice.metadata.is_invisible_default or false,
    tags = choice.metadata and choice.metadata.tags or {}
  }
end

-- Check if a choice represents a sticky choice (+ in Ink source)
-- Note: This is heuristic-based since compiled JSON doesn't preserve this directly
-- @param choice table - adapted choice
-- @return boolean
function ChoiceAdapter:is_sticky(choice)
  if not choice or not choice.metadata then
    return false
  end
  return choice.metadata.is_sticky == true
end

-- Check if a choice is a once-only choice (* in Ink source)
-- Note: This is the default in Ink
-- @param choice table - adapted choice
-- @return boolean
function ChoiceAdapter:is_once_only(choice)
  if not choice or not choice.metadata then
    return true  -- Default in Ink
  end
  return choice.metadata.is_sticky ~= true
end

-- Check if choice is an invisible default (fallback choice)
-- @param choice table - adapted choice
-- @return boolean
function ChoiceAdapter:is_fallback(choice)
  if not choice or not choice.metadata then
    return false
  end
  return choice.metadata.is_invisible_default == true
end

-- Get choice tags
-- @param choice table - adapted choice
-- @return table - Array of tags
function ChoiceAdapter:get_tags(choice)
  if not choice or not choice.metadata then
    return {}
  end
  return choice.metadata.tags or {}
end

return ChoiceAdapter
