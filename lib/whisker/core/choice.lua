-- whisker/core/choice.lua
-- Choice data structure for navigation options
-- Represents a single choice/link in an interactive story

local Choice = {}
Choice.__index = Choice

-- Module metadata for container auto-registration
Choice._whisker = {
  name = "Choice",
  version = "2.0.0",
  description = "Choice data structure for navigation options",
  depends = {},
  capability = "core.choice"
}

-- Generate a unique choice ID
local function generate_choice_id()
  local template = "ch_xxxxxxxxxxxx"
  return string.gsub(template, "x", function()
    return string.format("%x", math.random(0, 0xf))
  end)
end

-- Create a new Choice instance
-- @param text_or_options string|table - Choice text or options table
-- @param target string - Optional target passage ID (when first arg is string)
-- @return Choice
function Choice.new(text_or_options, target)
  -- Support both old table-based and new parameter patterns
  local options = {}
  if type(text_or_options) == "table" then
    options = text_or_options
  else
    options.text = text_or_options
    options.target = target
  end

  local instance = {
    id = options.id or generate_choice_id(),
    text = options.text or "",
    target = options.target or options.target_passage or nil,
    target_passage = options.target or options.target_passage or nil, -- Alias for compatibility
    condition = options.condition or nil,
    action = options.action or nil,
    metadata = options.metadata or {}
  }

  setmetatable(instance, Choice)
  return instance
end

-- Text management
function Choice:set_text(text)
  self.text = text
end

function Choice:get_text()
  return self.text
end

-- Target management (uses string ID, not object reference)
function Choice:set_target(target_passage_id)
  self.target = target_passage_id
  self.target_passage = target_passage_id -- Keep alias in sync
end

function Choice:get_target()
  return self.target or self.target_passage
end

-- Condition management (condition is a string expression, not evaluated here)
function Choice:set_condition(condition_code)
  self.condition = condition_code
end

function Choice:get_condition()
  return self.condition
end

function Choice:has_condition()
  return self.condition ~= nil and self.condition ~= ""
end

function Choice:clear_condition()
  self.condition = nil
end

-- Action management (action is a string expression, not evaluated here)
function Choice:set_action(action_code)
  self.action = action_code
end

function Choice:get_action()
  return self.action
end

function Choice:has_action()
  return self.action ~= nil and self.action ~= ""
end

function Choice:clear_action()
  self.action = nil
end

-- Metadata management
function Choice:set_metadata(key, value)
  self.metadata[key] = value
end

function Choice:get_metadata(key, default)
  local value = self.metadata[key]
  if value ~= nil then
    return value
  end
  return default
end

function Choice:has_metadata(key)
  return self.metadata[key] ~= nil
end

function Choice:delete_metadata(key)
  if self.metadata[key] ~= nil then
    self.metadata[key] = nil
    return true
  end
  return false
end

function Choice:clear_metadata()
  self.metadata = {}
end

function Choice:get_all_metadata()
  -- Return a copy to prevent external modification
  local copy = {}
  for k, v in pairs(self.metadata) do
    copy[k] = v
  end
  return copy
end

-- Validation
function Choice:validate()
  if not self.text or self.text == "" then
    return false, "Choice text is required"
  end

  local target = self:get_target()
  if not target or target == "" then
    return false, "Choice target passage is required"
  end

  return true
end

-- Serialization - returns plain table representation
function Choice:serialize()
  return {
    id = self.id,
    text = self.text,
    target = self:get_target(),
    target_passage = self:get_target(), -- Include alias for compatibility
    condition = self.condition,
    action = self.action,
    metadata = self.metadata
  }
end

-- Deserialization - restores from plain table
function Choice:deserialize(data)
  self.id = data.id or generate_choice_id()
  self.text = data.text or ""
  self.target = data.target or data.target_passage
  self.target_passage = data.target or data.target_passage
  self.condition = data.condition
  self.action = data.action
  self.metadata = data.metadata or {}
end

-- Static method to restore metatable to a plain table
function Choice.restore_metatable(data)
  if not data or type(data) ~= "table" then
    return nil
  end

  -- If already has Choice metatable, return as-is
  if getmetatable(data) == Choice then
    return data
  end

  -- Set the Choice metatable
  setmetatable(data, Choice)

  -- Ensure target alias is set
  data.target = data.target or data.target_passage
  data.target_passage = data.target or data.target_passage

  return data
end

-- Static method to create from plain table
function Choice.from_table(data)
  if not data then
    return nil
  end

  -- Create a new instance with the data
  return Choice.new({
    id = data.id,
    text = data.text,
    target = data.target or data.target_passage,
    condition = data.condition,
    action = data.action,
    metadata = data.metadata
  })
end

return Choice
