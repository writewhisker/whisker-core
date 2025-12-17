-- whisker/formats/ink/transformers/choice.lua
-- Choice transformer for Ink to Whisker conversion
-- Converts Ink choice points to whisker-core Choice objects

local ChoiceTransformer = {}
ChoiceTransformer.__index = ChoiceTransformer

-- Module metadata
ChoiceTransformer._whisker = {
  name = "ChoiceTransformer",
  version = "1.0.0",
  description = "Transforms Ink choices to whisker-core Choices",
  depends = {},
  capability = "formats.ink.transformers.choice"
}

-- Create a new ChoiceTransformer instance
function ChoiceTransformer.new()
  local instance = {}
  setmetatable(instance, ChoiceTransformer)
  return instance
end

-- Transform an Ink choice to a whisker-core Choice
-- @param choice_data table - The Ink choice data
-- @param parent_path string - The parent passage path
-- @param options table|nil - Conversion options
-- @return Choice - The converted choice
function ChoiceTransformer:transform(choice_data, parent_path, options)
  options = options or {}

  local Choice = require("whisker.core.choice")

  -- Extract choice properties
  local text = self:_extract_text(choice_data)
  local target = self:_extract_target(choice_data)
  local is_sticky = self:_is_sticky(choice_data)
  local is_fallback = self:_is_fallback(choice_data)

  -- Create the choice
  local choice = Choice.new({
    text = text,
    target = target,
    metadata = {}
  })

  -- Store Ink-specific metadata
  if is_sticky then
    choice.metadata.sticky = true
  end
  if is_fallback then
    choice.metadata.fallback = true
  end
  if options.preserve_ink_paths and parent_path then
    choice.metadata.ink_parent = parent_path
  end

  -- Store original choice index if available
  if choice_data.originalChoiceIndex then
    choice.metadata.ink_choice_index = choice_data.originalChoiceIndex
  end

  return choice
end

-- Extract choice text from choice data
-- @param choice_data table - The choice data
-- @return string - The extracted text
function ChoiceTransformer:_extract_text(choice_data)
  if type(choice_data) ~= "table" then
    return ""
  end

  -- Text is typically in the 'text' field
  if choice_data.text then
    return choice_data.text
  end

  -- Or it might be in a nested structure
  if choice_data[1] and type(choice_data[1]) == "string" then
    local text = choice_data[1]
    if text:sub(1, 1) == "^" then
      return text:sub(2)
    end
    return text
  end

  return ""
end

-- Extract target path from choice data
-- @param choice_data table - The choice data
-- @return string|nil - The target path
function ChoiceTransformer:_extract_target(choice_data)
  if type(choice_data) ~= "table" then
    return nil
  end

  -- Target is in pathStringOnChoice
  if choice_data.pathStringOnChoice then
    return choice_data.pathStringOnChoice
  end

  -- Or might be in targetPath
  if choice_data.targetPath then
    return choice_data.targetPath
  end

  return nil
end

-- Check if choice is sticky (repeatable)
-- @param choice_data table - The choice data
-- @return boolean
function ChoiceTransformer:_is_sticky(choice_data)
  if type(choice_data) ~= "table" then
    return false
  end

  -- Flags field contains sticky flag
  if choice_data.flags then
    -- Flag 0x01 indicates once-only (non-sticky)
    return (choice_data.flags % 2) == 0
  end

  -- Default to non-sticky (once-only)
  return false
end

-- Check if choice is a fallback choice
-- @param choice_data table - The choice data
-- @return boolean
function ChoiceTransformer:_is_fallback(choice_data)
  if type(choice_data) ~= "table" then
    return false
  end

  -- Flags field contains fallback flag
  if choice_data.flags then
    -- Flag 0x04 indicates fallback
    return (math.floor(choice_data.flags / 4) % 2) == 1
  end

  return false
end

-- Find choice points in a container
-- @param container table - The container to search
-- @return table - Array of choice data
function ChoiceTransformer:find_choices(container)
  local choices = {}

  if type(container) ~= "table" then
    return choices
  end

  self:_find_choices_recursive(container, choices)

  return choices
end

-- Recursively find choice points
function ChoiceTransformer:_find_choices_recursive(container, choices)
  if type(container) ~= "table" then
    return
  end

  for i, item in ipairs(container) do
    if type(item) == "table" then
      -- Check if this is a choice point
      if item["*"] then
        -- This is a choice point marker
        table.insert(choices, item)
      elseif item.c then
        -- This is a choice container
        table.insert(choices, item)
      else
        -- Recurse into nested containers
        self:_find_choices_recursive(item, choices)
      end
    end
  end
end

-- Transform all choices in a container
-- @param container table - The container
-- @param parent_path string - The parent passage path
-- @param options table|nil - Conversion options
-- @return table - Array of Choice objects
function ChoiceTransformer:transform_all(container, parent_path, options)
  local choice_data_list = self:find_choices(container)
  local choices = {}

  for _, choice_data in ipairs(choice_data_list) do
    local choice = self:transform(choice_data, parent_path, options)
    table.insert(choices, choice)
  end

  return choices
end

return ChoiceTransformer
