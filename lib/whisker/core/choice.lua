-- src/core/choice.lua
-- Choice handling with conditions

local Choice = {}
Choice.__index = Choice

-- Dependencies for DI pattern (none for Choice - it's a leaf module)
Choice._dependencies = {}

-- Generate a unique choice ID
local function generate_choice_id()
    local template = "ch_xxxxxxxxxxxx"
    return string.gsub(template, "x", function()
        return string.format("%x", math.random(0, 0xf))
    end)
end

--- Create a new Choice instance via DI container
-- @param deps table Dependencies from container (optional for Choice)
-- @return function Factory function that creates Choice instances
function Choice.create(deps)
    -- deps is optional for Choice since it has no dependencies
    -- Return a factory function that creates choices
    return function(text_or_options, target)
        return Choice.new(text_or_options, target)
    end
end

-- WLS 1.0 Choice Types
Choice.TYPE_ONCE = "once"    -- + marker: disappears after selection
Choice.TYPE_STICKY = "sticky" -- * marker: always available

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
        id = options.id or generate_choice_id(),  -- NEW: Auto-generate ID if missing
        text = options.text or "",
        target_passage = options.target or options.target_passage or nil,
        condition = options.condition or nil,
        action = options.action or nil,
        metadata = options.metadata or {},
        -- WLS 1.0: Choice type (once-only vs sticky)
        choice_type = options.choice_type or options.type or Choice.TYPE_ONCE
    }

    setmetatable(instance, Choice)
    return instance
end

function Choice:set_text(text)
    self.text = text
end

function Choice:get_text()
    return self.text
end

function Choice:set_target(target_passage_id)
    self.target_passage = target_passage_id
end

function Choice:get_target()
    return self.target_passage
end

function Choice:set_condition(condition_code)
    self.condition = condition_code
end

function Choice:get_condition()
    return self.condition
end

function Choice:has_condition()
    return self.condition ~= nil and self.condition ~= ""
end

function Choice:set_action(action_code)
    self.action = action_code
end

function Choice:get_action()
    return self.action
end

function Choice:has_action()
    return self.action ~= nil and self.action ~= ""
end

-- WLS 1.0: Choice type methods

--- Get the choice type
---@return string "once" or "sticky"
function Choice:get_type()
    return self.choice_type or Choice.TYPE_ONCE
end

--- Set the choice type
---@param choice_type string "once" or "sticky"
function Choice:set_type(choice_type)
    self.choice_type = choice_type
end

--- Check if this is a once-only choice
---@return boolean
function Choice:is_once_only()
    return self:get_type() == Choice.TYPE_ONCE
end

--- Check if this is a sticky choice
---@return boolean
function Choice:is_sticky()
    return self:get_type() == Choice.TYPE_STICKY
end

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

function Choice:validate()
    if not self.text or self.text == "" then
        return false, "Choice text is required"
    end

    if not self.target_passage or self.target_passage == "" then
        return false, "Choice target passage is required"
    end

    return true
end

function Choice:serialize()
    return {
        id = self.id,  -- NEW: Include ID in serialization
        text = self.text,
        target_passage = self.target_passage,
        target = self.target_passage,  -- Alias for backwards compatibility
        condition = self.condition,
        action = self.action,
        metadata = self.metadata,
        choice_type = self.choice_type  -- WLS 1.0: Include choice type
    }
end

function Choice:deserialize(data)
    self.id = data.id or generate_choice_id()  -- NEW: Restore or generate ID
    self.text = data.text or ""
    self.target_passage = data.target_passage or data.target  -- Accept both field names
    self.condition = data.condition
    self.action = data.action
    self.metadata = data.metadata or {}
    self.choice_type = data.choice_type or data.type or Choice.TYPE_ONCE  -- WLS 1.0
end

-- Provide target as an alias for target_passage for backwards compatibility
Choice.__index = function(self, key)
    if key == "target" then
        return rawget(self, "target_passage")
    end
    return Choice[key]
end

-- Static method to restore metatable to a table
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

    return data
end

-- Static method to create from plain table (useful for deserialization)
function Choice.from_table(data)
    if not data then
        return nil
    end

    -- Create a new instance with the data
    return Choice.new({
        id = data.id,  -- NEW: Preserve ID if present
        text = data.text,
        target = data.target_passage or data.target,
        condition = data.condition,
        action = data.action,
        metadata = data.metadata,
        choice_type = data.choice_type or data.type  -- WLS 1.0
    })
end

return Choice
