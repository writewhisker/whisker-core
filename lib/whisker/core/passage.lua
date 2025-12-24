-- src/core/passage.lua
-- Passage representation with metadata

local Passage = {}
Passage.__index = Passage

-- Dependencies for DI pattern
Passage._dependencies = {"choice_factory"}

-- Cached choice factory for backward compatibility (lazy loaded)
local _choice_factory_cache = nil

--- Get the choice factory (supports both DI and backward compatibility)
-- @param deps table|nil Dependencies from container
-- @return table The choice factory
local function get_choice_factory(deps)
  if deps and deps.choice_factory then
    return deps.choice_factory
  end
  -- Fallback: lazy load the default factory for backward compatibility
  if not _choice_factory_cache then
    local ChoiceFactory = require("whisker.core.factories.choice_factory")
    _choice_factory_cache = ChoiceFactory.new()
  end
  return _choice_factory_cache
end

--- Create a new Passage instance via DI container
-- @param deps table Dependencies from container (choice_factory)
-- @return function Factory function that creates Passage instances
function Passage.create(deps)
  local choice_factory = get_choice_factory(deps)
  -- Return a factory function that creates passages
  return function(id_or_options, name)
    return Passage.new(id_or_options, name, choice_factory)
  end
end

function Passage.new(id_or_options, name, choice_factory)
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
        tags = options.tags or {},
        content = options.content or "",
        choices = options.choices or {},
        position = options.position or {x = 0, y = 0},
        size = options.size or {width = 100, height = 100},
        metadata = options.metadata or {},
        on_enter_script = options.on_enter_script or nil,
        on_exit_script = options.on_exit_script or nil,
        -- Store choice factory for DI (optional, for metatable restoration)
        _choice_factory = choice_factory
    }

    setmetatable(instance, Passage)
    return instance
end

function Passage:set_content(content)
    self.content = content
end

function Passage:get_content()
    return self.content
end

function Passage:add_choice(choice)
    table.insert(self.choices, choice)
end

function Passage:get_choices()
    return self.choices
end

function Passage:get_choice(index)
    return self.choices[index]
end

function Passage:remove_choice(index)
    table.remove(self.choices, index)
end

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

function Passage:remove_tag(tag)
    for i, t in ipairs(self.tags) do
        if t == tag then
            table.remove(self.tags, i)
            return true
        end
    end
    return false
end

function Passage:get_tags()
    return self.tags
end

function Passage:set_position(x, y)
    self.position.x = x
    self.position.y = y
end

function Passage:get_position()
    return self.position.x, self.position.y
end

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

function Passage:set_on_enter_script(script)
    self.on_enter_script = script
end

function Passage:set_on_exit_script(script)
    self.on_exit_script = script
end

function Passage:validate()
    if not self.id or self.id == "" then
        return false, "Passage ID is required"
    end

    if not self.name or self.name == "" then
        return false, "Passage name is required"
    end

    -- Validate choices
    for i, choice in ipairs(self.choices) do
        local valid, err = choice:validate()
        if not valid then
            return false, "Choice " .. i .. ": " .. err
        end
    end

    return true
end

function Passage:serialize()
    return {
        id = self.id,
        name = self.name,
        tags = self.tags,
        content = self.content,
        choices = self.choices,
        position = self.position,
        size = self.size,
        metadata = self.metadata,
        on_enter_script = self.on_enter_script,
        on_exit_script = self.on_exit_script
    }
end

function Passage:deserialize(data)
    self.id = data.id
    self.name = data.name
    self.tags = data.tags or {}
    self.content = data.content or ""
    self.choices = data.choices or {}
    self.position = data.position or {x = 0, y = 0}
    self.size = data.size or {width = 100, height = 100}
    self.metadata = data.metadata or {}
    self.on_enter_script = data.on_enter_script
    self.on_exit_script = data.on_exit_script

    -- Restore metatables for choice objects if needed
    if self.choices then
        -- Use injected choice factory if available, otherwise fallback
        local choice_factory = self._choice_factory or get_choice_factory()
        for i, choice in ipairs(self.choices) do
            if type(choice) == "table" and not getmetatable(choice) then
                self.choices[i] = choice_factory:restore_metatable(choice)
            end
        end
    end
end

--- Static method to restore metatable to a table
-- @param data table Plain table with passage data
-- @param choice_factory table|nil Optional choice factory for DI
-- @return Passage The table with Passage metatable restored
function Passage.restore_metatable(data, choice_factory)
    if not data or type(data) ~= "table" then
        return nil
    end

    -- If already has Passage metatable, return as-is
    if getmetatable(data) == Passage then
        return data
    end

    -- Set the Passage metatable
    setmetatable(data, Passage)

    -- Restore metatables for nested objects (choices)
    if data.choices then
        -- Use provided factory or fallback to default
        local factory = choice_factory or data._choice_factory or get_choice_factory()
        for i, choice in ipairs(data.choices) do
            if type(choice) == "table" and not getmetatable(choice) then
                data.choices[i] = factory:restore_metatable(choice)
            end
        end
    end

    return data
end

--- Static method to create from plain table (useful for deserialization)
-- @param data table Serialized passage data
-- @param choice_factory table|nil Optional choice factory for DI
-- @return Passage The restored passage instance
function Passage.from_table(data, choice_factory)
    if not data then
        return nil
    end

    -- Get choice factory (use provided or fallback)
    local factory = choice_factory or get_choice_factory()

    -- Create a new instance
    local instance = Passage.new({
        id = data.id,
        name = data.name,
        tags = data.tags,
        content = data.content,
        position = data.position,
        size = data.size,
        metadata = data.metadata,
        on_enter_script = data.on_enter_script,
        on_exit_script = data.on_exit_script
    }, nil, factory)

    -- Restore choices with proper metatables
    if data.choices then
        for _, choice_data in ipairs(data.choices) do
            if type(choice_data) == "table" then
                local choice = factory:from_table(choice_data)
                table.insert(instance.choices, choice)
            end
        end
    end

    return instance
end

return Passage
