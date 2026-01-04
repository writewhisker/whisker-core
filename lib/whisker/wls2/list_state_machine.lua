--- LIST State Machine for WLS 2.0
--- Extends LIST with state machine operators
--- @module whisker.wls2.list_state_machine

local ListStateMachine = {
    _VERSION = "2.0.0"
}
ListStateMachine.__index = ListStateMachine
ListStateMachine._dependencies = {}

--- ListValue class - represents a LIST with state machine operations
local ListValue = {}
ListValue.__index = ListValue

--- Create a new ListValue
--- @param name string The list name
--- @param possibleValues table Array of possible values
--- @param activeValues table|nil Array of initially active values
--- @return ListValue The new list value
function ListValue.new(name, possibleValues, activeValues)
    if type(name) ~= "string" or name == "" then
        error("List name must be a non-empty string")
    end
    if type(possibleValues) ~= "table" then
        error("Possible values must be a table")
    end

    local self = setmetatable({}, ListValue)
    self._name = name
    self._possibleValues = {}
    self._activeValues = {}

    -- Build possible values set
    for _, v in ipairs(possibleValues) do
        self._possibleValues[v] = true
    end

    -- Set initial active values
    if activeValues then
        for _, v in ipairs(activeValues) do
            if self._possibleValues[v] then
                self._activeValues[v] = true
            end
        end
    end

    return self
end

--- Get the list name
--- @return string The list name
function ListValue:getName()
    return self._name
end

--- Get all possible values
--- @return table Array of possible values
function ListValue:getPossibleValues()
    local values = {}
    for v in pairs(self._possibleValues) do
        table.insert(values, v)
    end
    table.sort(values)
    return values
end

--- Get all active values
--- @return table Array of active values
function ListValue:getActiveValues()
    local values = {}
    for v in pairs(self._activeValues) do
        table.insert(values, v)
    end
    table.sort(values)
    return values
end

--- Add a state (+=)
--- @param value string|table Value or array of values to add
function ListValue:add(value)
    if type(value) == "table" then
        for _, v in ipairs(value) do
            self:add(v)
        end
        return
    end

    if not self._possibleValues[value] then
        error("Invalid value for list '" .. self._name .. "': " .. tostring(value))
    end
    self._activeValues[value] = true
end

--- Remove a state (-=)
--- @param value string|table Value or array of values to remove
function ListValue:remove(value)
    if type(value) == "table" then
        for _, v in ipairs(value) do
            self:remove(v)
        end
        return
    end

    self._activeValues[value] = nil
end

--- Toggle a state
--- @param value string Value to toggle
function ListValue:toggle(value)
    if self._activeValues[value] then
        self:remove(value)
    else
        self:add(value)
    end
end

--- Check if a state is active (?)
--- @param value string Value to check
--- @return boolean True if the value is active
function ListValue:contains(value)
    return self._activeValues[value] == true
end

--- Check if this list includes all values from another (superset, >=)
--- @param other ListValue|table Other list or array of values
--- @return boolean True if this list is a superset
function ListValue:includes(other)
    local otherValues
    if type(other) == "table" and other.getActiveValues then
        otherValues = other:getActiveValues()
    elseif type(other) == "table" then
        otherValues = other
    else
        error("Invalid argument to includes")
    end

    for _, v in ipairs(otherValues) do
        if not self._activeValues[v] then
            return false
        end
    end
    return true
end

--- Check if this list is a subset of another (<=)
--- @param other ListValue|table Other list or array of values
--- @return boolean True if this list is a subset
function ListValue:isSubsetOf(other)
    local otherSet = {}
    if type(other) == "table" and other.getActiveValues then
        for _, v in ipairs(other:getActiveValues()) do
            otherSet[v] = true
        end
    elseif type(other) == "table" then
        for _, v in ipairs(other) do
            otherSet[v] = true
        end
    else
        error("Invalid argument to isSubsetOf")
    end

    for v in pairs(self._activeValues) do
        if not otherSet[v] then
            return false
        end
    end
    return true
end

--- Check equality with another list (==)
--- @param other ListValue|table Other list or array of values
--- @return boolean True if lists have same active values
function ListValue:equals(other)
    return self:includes(other) and self:isSubsetOf(other)
end

--- Get the count of active values
--- @return number Count of active values
function ListValue:count()
    local n = 0
    for _ in pairs(self._activeValues) do
        n = n + 1
    end
    return n
end

--- Check if the list is empty
--- @return boolean True if no active values
function ListValue:isEmpty()
    return next(self._activeValues) == nil
end

--- Clear all active values
function ListValue:clear()
    self._activeValues = {}
end

--- Set to specific values (replace all active)
--- @param values table Array of values
function ListValue:set(values)
    self:clear()
    if values then
        self:add(values)
    end
end

--- Create a copy of this list
--- @return ListValue The copy
function ListValue:copy()
    local copy = ListValue.new(
        self._name,
        self:getPossibleValues(),
        self:getActiveValues()
    )
    return copy
end

--- Convert to string representation
--- @return string String representation
function ListValue:toString()
    local active = self:getActiveValues()
    if #active == 0 then
        return self._name .. "()"
    end
    return self._name .. "(" .. table.concat(active, ", ") .. ")"
end

ListValue.__tostring = ListValue.toString

--- Export ListValue class
ListStateMachine.ListValue = ListValue

--- ListRegistry - manages multiple LISTs
local ListRegistry = {}
ListRegistry.__index = ListRegistry

--- Create a new ListRegistry
--- @param deps table|nil Dependencies (optional, for DI pattern)
--- @return ListRegistry The new registry
function ListRegistry.new(deps)
    deps = deps or {}
    local self = setmetatable({}, ListRegistry)
    self._lists = {}
    return self
end

--- Define a new LIST
--- @param name string The list name
--- @param possibleValues table Array of possible values
--- @param initialValues table|nil Array of initially active values
--- @return ListValue The created list
function ListRegistry:define(name, possibleValues, initialValues)
    if self._lists[name] then
        error("LIST already defined: " .. name)
    end

    local list = ListValue.new(name, possibleValues, initialValues)
    self._lists[name] = list
    return list
end

--- Get a list by name
--- @param name string The list name
--- @return ListValue|nil The list or nil
function ListRegistry:get(name)
    return self._lists[name]
end

--- Check if a list exists
--- @param name string The list name
--- @return boolean True if list exists
function ListRegistry:has(name)
    return self._lists[name] ~= nil
end

--- Get all list names
--- @return table Array of list names
function ListRegistry:getNames()
    local names = {}
    for name in pairs(self._lists) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Clear all lists
function ListRegistry:clear()
    self._lists = {}
end

--- Export ListRegistry class
ListStateMachine.ListRegistry = ListRegistry

--- Create a new ListStateMachine manager (combines registry with utilities)
--- @param deps table Optional dependencies
--- @return table Manager with registry and utilities
function ListStateMachine.new(deps)
    local manager = {
        registry = ListRegistry.new(),
        _deps = deps or {}
    }

    -- Convenience methods that delegate to registry
    function manager:define(name, possibleValues, initialValues)
        return self.registry:define(name, possibleValues, initialValues)
    end

    function manager:get(name)
        return self.registry:get(name)
    end

    function manager:has(name)
        return self.registry:has(name)
    end

    function manager:getNames()
        return self.registry:getNames()
    end

    function manager:clear()
        self.registry:clear()
    end

    return manager
end

return ListStateMachine
