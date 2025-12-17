-- whisker/core/passage.lua
-- Passage data structure with metadata
-- Represents a single passage/node in an interactive story

local Passage = {}
Passage.__index = Passage

-- Module metadata for container auto-registration
Passage._whisker = {
  name = "Passage",
  version = "2.0.0",
  description = "Passage data structure for story nodes",
  depends = {},
  capability = "core.passage"
}

-- Create a new Passage instance
-- @param id_or_options string|table - Passage ID or options table
-- @param name string - Optional name (when first arg is string)
-- @return Passage
function Passage.new(id_or_options, name)
  -- Support both old table-based and new parameter patterns
  local options = {}
  if type(id_or_options) == "table" then
    options = id_or_options
  else
    options.id = id_or_options
    options.name = name
  end

  local instance = {
    id = options.id or "",
    name = options.name or options.id or "",
    title = options.title or options.name or options.id or "",
    tags = options.tags or {},
    content = options.content or "",
    choices = options.choices or {},
    position = options.position or {x = 0, y = 0},
    size = options.size or {width = 100, height = 100},
    metadata = options.metadata or {},
    on_enter_script = options.on_enter_script or nil,
    on_exit_script = options.on_exit_script or nil
  }

  setmetatable(instance, Passage)
  return instance
end

-- Content management
function Passage:set_content(content)
  self.content = content
end

function Passage:get_content()
  return self.content
end

-- Choice management
function Passage:add_choice(choice)
  table.insert(self.choices, choice)
end

function Passage:get_choices()
  return self.choices
end

function Passage:remove_choice(index)
  table.remove(self.choices, index)
end

function Passage:clear_choices()
  self.choices = {}
end

-- Tag management
function Passage:add_tag(tag)
  table.insert(self.tags, tag)
end

function Passage:has_tag(tag)
  for _, t in ipairs(self.tags) do
    if t == tag then
      return true
    end
  end
  return false
end

function Passage:get_tags()
  return self.tags
end

function Passage:remove_tag(tag)
  for i, t in ipairs(self.tags) do
    if t == tag then
      table.remove(self.tags, i)
      return true
    end
  end
  return false
end

-- Position management (for visual editors)
function Passage:set_position(x, y)
  self.position.x = x
  self.position.y = y
end

function Passage:get_position()
  return self.position.x, self.position.y
end

-- Metadata management
function Passage:set_metadata(key, value)
  self.metadata[key] = value
end

function Passage:get_metadata(key, default)
  local value = self.metadata[key]
  if value ~= nil then
    return value
  end
  return default
end

function Passage:has_metadata(key)
  return self.metadata[key] ~= nil
end

function Passage:delete_metadata(key)
  if self.metadata[key] ~= nil then
    self.metadata[key] = nil
    return true
  end
  return false
end

function Passage:clear_metadata()
  self.metadata = {}
end

function Passage:get_all_metadata()
  -- Return a copy to prevent external modification
  local copy = {}
  for k, v in pairs(self.metadata) do
    copy[k] = v
  end
  return copy
end

-- Script hooks
function Passage:set_on_enter_script(script)
  self.on_enter_script = script
end

function Passage:get_on_enter_script()
  return self.on_enter_script
end

function Passage:set_on_exit_script(script)
  self.on_exit_script = script
end

function Passage:get_on_exit_script()
  return self.on_exit_script
end

-- Validation
function Passage:validate()
  if not self.id or self.id == "" then
    return false, "Passage ID is required"
  end

  -- Validate choices if they have validate method
  for i, choice in ipairs(self.choices) do
    if type(choice.validate) == "function" then
      local valid, err = choice:validate()
      if not valid then
        return false, "Choice " .. i .. ": " .. err
      end
    end
  end

  return true
end

-- Serialization - returns plain table representation
function Passage:serialize()
  -- Serialize choices if they have serialize method
  local serialized_choices = {}
  for _, choice in ipairs(self.choices) do
    if type(choice.serialize) == "function" then
      table.insert(serialized_choices, choice:serialize())
    else
      table.insert(serialized_choices, choice)
    end
  end

  return {
    id = self.id,
    name = self.name,
    title = self.title,
    tags = self.tags,
    content = self.content,
    choices = serialized_choices,
    position = self.position,
    size = self.size,
    metadata = self.metadata,
    on_enter_script = self.on_enter_script,
    on_exit_script = self.on_exit_script
  }
end

-- Deserialization - restores from plain table
-- Note: choice_restorer is optional function(choice_data) -> choice
function Passage:deserialize(data, choice_restorer)
  self.id = data.id
  self.name = data.name or data.id
  self.title = data.title or data.name or data.id
  self.tags = data.tags or {}
  self.content = data.content or ""
  self.position = data.position or {x = 0, y = 0}
  self.size = data.size or {width = 100, height = 100}
  self.metadata = data.metadata or {}
  self.on_enter_script = data.on_enter_script
  self.on_exit_script = data.on_exit_script

  -- Restore choices using provided restorer or keep as-is
  self.choices = {}
  if data.choices then
    for _, choice_data in ipairs(data.choices) do
      if choice_restorer and type(choice_data) == "table" then
        table.insert(self.choices, choice_restorer(choice_data))
      else
        table.insert(self.choices, choice_data)
      end
    end
  end
end

-- Static method to restore metatable to a plain table
-- Note: choice_restorer is optional function(choice_data) -> choice
function Passage.restore_metatable(data, choice_restorer)
  if not data or type(data) ~= "table" then
    return nil
  end

  -- If already has Passage metatable, return as-is
  if getmetatable(data) == Passage then
    return data
  end

  -- Set the Passage metatable
  setmetatable(data, Passage)

  -- Ensure title field exists
  data.title = data.title or data.name or data.id

  -- Restore choice metatables if restorer provided
  if data.choices and choice_restorer then
    for i, choice in ipairs(data.choices) do
      if type(choice) == "table" and not getmetatable(choice) then
        data.choices[i] = choice_restorer(choice)
      end
    end
  end

  return data
end

-- Static method to create from plain table
-- Note: choice_restorer is optional function(choice_data) -> choice
function Passage.from_table(data, choice_restorer)
  if not data then
    return nil
  end

  -- Create a new instance
  local instance = Passage.new({
    id = data.id,
    name = data.name,
    title = data.title,
    tags = data.tags,
    content = data.content,
    position = data.position,
    size = data.size,
    metadata = data.metadata,
    on_enter_script = data.on_enter_script,
    on_exit_script = data.on_exit_script
  })

  -- Restore choices with provided restorer or keep as-is
  if data.choices then
    for _, choice_data in ipairs(data.choices) do
      if choice_restorer and type(choice_data) == "table" then
        table.insert(instance.choices, choice_restorer(choice_data))
      else
        table.insert(instance.choices, choice_data)
      end
    end
  end

  return instance
end

return Passage
