-- whisker/formats/ink/generators/choice.lua
-- Generates Ink choice points from whisker choices

local ChoiceGenerator = {}
ChoiceGenerator.__index = ChoiceGenerator

-- Module metadata
ChoiceGenerator._whisker = {
  name = "ChoiceGenerator",
  version = "1.0.0",
  description = "Generates Ink choice points from whisker choices",
  depends = {},
  capability = "formats.ink.generators.choice"
}

-- Choice flags in Ink
ChoiceGenerator.FLAGS = {
  HAS_CONDITION = 1,
  HAS_START_CONTENT = 2,
  HAS_CHOICE_ONLY_CONTENT = 4,
  INVISIBLE_DEFAULT = 8,
  ONCE_ONLY = 16
}

-- Create a new ChoiceGenerator instance
function ChoiceGenerator.new()
  local instance = {}
  setmetatable(instance, ChoiceGenerator)
  return instance
end

-- Generate an Ink choice point from a whisker choice
-- @param choice table - The whisker choice
-- @param options table|nil - Generation options
-- @return table - Ink choice point structure
function ChoiceGenerator:generate(choice, options)
  options = options or {}

  local choice_point = {}

  -- Add choice text
  if choice.text then
    table.insert(choice_point, "ev")
    table.insert(choice_point, { ["^"] = choice.text })
    table.insert(choice_point, "/ev")
  end

  -- Build flags
  local flags = self:_calculate_flags(choice)

  -- Create choice point object
  local cp = {
    ["*"] = self:_get_path_string(choice),
    flg = flags
  }

  table.insert(choice_point, cp)

  return choice_point
end

-- Generate multiple choices as a choice block
-- @param choices table - Array of whisker choices
-- @param options table|nil - Generation options
-- @return table - Ink choice block
function ChoiceGenerator:generate_block(choices, options)
  options = options or {}
  local block = {}

  for i, choice in ipairs(choices) do
    local choice_content = self:generate(choice, options)
    for _, item in ipairs(choice_content) do
      table.insert(block, item)
    end
  end

  return block
end

-- Calculate flags for a choice
-- @param choice table - The whisker choice
-- @return number - Combined flags
function ChoiceGenerator:_calculate_flags(choice)
  local flags = 0

  -- Once-only is default in Ink (flag set means NOT once-only, i.e., sticky)
  if not choice.sticky then
    flags = flags + self.FLAGS.ONCE_ONLY
  end

  -- Has start content (text shown in both choice and output)
  if choice.text then
    flags = flags + self.FLAGS.HAS_START_CONTENT
  end

  -- Has choice-only content (text only shown in choice)
  if choice.choice_text then
    flags = flags + self.FLAGS.HAS_CHOICE_ONLY_CONTENT
  end

  -- Has condition
  if choice.condition then
    flags = flags + self.FLAGS.HAS_CONDITION
  end

  -- Invisible default (fallback choice)
  if choice.fallback then
    flags = flags + self.FLAGS.INVISIBLE_DEFAULT
  end

  return flags
end

-- Get path string for choice target
-- @param choice table - The whisker choice
-- @return string - Path to choice content
function ChoiceGenerator:_get_path_string(choice)
  if choice.target then
    return choice.target
  end
  return "0.c-" .. (choice.index or 0)
end

-- Check if choice is sticky
-- @param choice table - The whisker choice
-- @return boolean
function ChoiceGenerator:is_sticky(choice)
  return choice.sticky == true
end

-- Check if choice is fallback
-- @param choice table - The whisker choice
-- @return boolean
function ChoiceGenerator:is_fallback(choice)
  return choice.fallback == true
end

-- Generate condition for choice
-- @param choice table - The whisker choice
-- @return table|nil - Condition content or nil
function ChoiceGenerator:generate_condition(choice)
  if not choice.condition then
    return nil
  end

  local cond = {}
  table.insert(cond, "ev")

  -- Simple condition (variable reference)
  if type(choice.condition) == "string" then
    table.insert(cond, { ["VAR?"] = choice.condition })
  elseif type(choice.condition) == "table" then
    -- Complex condition
    local logic_gen = require("whisker.formats.ink.generators.logic")
    if logic_gen.new then
      logic_gen = logic_gen.new()
    end
    local expr = logic_gen:generate_expression(choice.condition)
    for _, item in ipairs(expr) do
      table.insert(cond, item)
    end
  end

  table.insert(cond, "/ev")
  return cond
end

-- Generate choice content (what happens after selection)
-- @param choice table - The whisker choice
-- @param passage table|nil - Target passage if embedded
-- @return table - Content container
function ChoiceGenerator:generate_content(choice, passage)
  local content = {}

  -- Add any choice-specific content
  if choice.content then
    if type(choice.content) == "string" then
      table.insert(content, "^" .. choice.content)
      table.insert(content, "\n")
    end
  end

  return content
end

return ChoiceGenerator
