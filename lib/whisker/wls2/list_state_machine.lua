--- LIST State Machine for WLS 2.0
--- Extends LIST with state machine operators
--- Provides event callbacks, history tracking, thread safety, and serialization
--- @module whisker.wls2.list_state_machine

local ListStateMachine = {
    _VERSION = "2.0.0"
}
ListStateMachine.__index = ListStateMachine
ListStateMachine._dependencies = {}

--- ListValue class - represents a LIST with state machine operations
local ListValue = {}
ListValue.__index = ListValue

--- Configuration defaults
local DEFAULT_CONFIG = {
    trackHistory = false,
    maxHistoryLength = 100,
    allowUndefinedStates = false,
    onTransition = nil
}

--- Create a new ListValue
--- @param name string The list name
--- @param possibleValues table Array of possible values
--- @param activeValues table|nil Array of initially active values
--- @param config table|nil Configuration options
--- @return ListValue The new list value
function ListValue.new(name, possibleValues, activeValues, config)
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
    self._stateCallbacks = {}
    self._history = {}
    self._locked = false

    -- Merge config with defaults
    self._config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        self._config[k] = v
    end
    if config then
        for k, v in pairs(config) do
            self._config[k] = v
        end
    end

    -- Build possible values set
    for _, v in ipairs(possibleValues) do
        self._possibleValues[v] = true
    end

    -- Set initial active values
    if activeValues then
        for _, v in ipairs(activeValues) do
            if self._possibleValues[v] then
                self._activeValues[v] = true
                -- Record initial state entries if tracking history
                if self._config.trackHistory then
                    self:_recordTransition(v, "enter", {})
                end
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

--- Ensure the list is not locked
--- @private
function ListValue:_ensureUnlocked()
    if self._locked then
        error("ListStateMachine '" .. self._name .. "' is locked")
    end
end

--- Record a state transition in history
--- @private
--- @param state string The state
--- @param action string "enter" or "exit"
--- @param previousStates table Previous active states
function ListValue:_recordTransition(state, action, previousStates)
    if not self._config.trackHistory then
        return
    end

    table.insert(self._history, {
        state = state,
        action = action,
        timestamp = os.time(),
        previousStates = previousStates
    })

    -- Trim history if needed
    local maxLen = self._config.maxHistoryLength
    if maxLen and maxLen > 0 then
        while #self._history > maxLen do
            table.remove(self._history, 1)
        end
    end
end

--- Trigger callbacks for a state transition
--- @private
--- @param state string The state
--- @param action string "enter" or "exit"
function ListValue:_triggerCallback(state, action)
    -- Call global transition callback
    if self._config.onTransition then
        self._config.onTransition(state, action, self)
    end

    -- Call state-specific callback
    local callbacks = self._stateCallbacks[state]
    if callbacks then
        if action == "enter" and callbacks.onEnter then
            callbacks.onEnter(state, action, self)
        elseif action == "exit" and callbacks.onExit then
            callbacks.onExit(state, action, self)
        end
    end
end

--- Add a state (+=) - internal, no callbacks
--- @param value string|table Value or array of values to add
function ListValue:_addRaw(value)
    if type(value) == "table" then
        for _, v in ipairs(value) do
            self:_addRaw(v)
        end
        return
    end

    if not self._possibleValues[value] then
        error("Invalid value for list '" .. self._name .. "': " .. tostring(value))
    end
    self._activeValues[value] = true
end

--- Add a state (+=)
--- @param value string|table Value or array of values to add
function ListValue:add(value)
    self:_ensureUnlocked()
    self:_addRaw(value)
end

--- Remove a state (-=) - internal, no callbacks
--- @param value string|table Value or array of values to remove
function ListValue:_removeRaw(value)
    if type(value) == "table" then
        for _, v in ipairs(value) do
            self:_removeRaw(v)
        end
        return
    end

    self._activeValues[value] = nil
end

--- Remove a state (-=)
--- @param value string|table Value or array of values to remove
function ListValue:remove(value)
    self:_ensureUnlocked()
    self:_removeRaw(value)
end

--- Toggle a state
--- @param value string Value to toggle
--- @return boolean New active status
function ListValue:toggle(value)
    self:_ensureUnlocked()
    if self._activeValues[value] then
        self:exit(value)
        return false
    else
        self:enter(value)
        return true
    end
end

--- Enter a state (make it active) with callbacks
--- @param state string State to enter
function ListValue:enter(state)
    self:_ensureUnlocked()
    if not self._activeValues[state] then
        local previousStates = self:getActiveValues()
        self:_addRaw(state)
        self:_recordTransition(state, "enter", previousStates)
        self:_triggerCallback(state, "enter")
    end
end

--- Exit a state (make it inactive) with callbacks
--- @param state string State to exit
function ListValue:exit(state)
    self:_ensureUnlocked()
    if self._activeValues[state] then
        local previousStates = self:getActiveValues()
        self:_removeRaw(state)
        self:_recordTransition(state, "exit", previousStates)
        self:_triggerCallback(state, "exit")
    end
end

--- Transition to exactly one state (exit all others, enter this one)
--- @param state string State to transition to
function ListValue:transitionTo(state)
    self:_ensureUnlocked()
    local previousStates = self:getActiveValues()

    -- Exit all current states except target
    for _, currentState in ipairs(previousStates) do
        if currentState ~= state then
            self:_removeRaw(currentState)
            self:_recordTransition(currentState, "exit", previousStates)
            self:_triggerCallback(currentState, "exit")
        end
    end

    -- Enter the new state if not already active
    local wasActive = false
    for _, v in ipairs(previousStates) do
        if v == state then
            wasActive = true
            break
        end
    end

    if not wasActive then
        self:_addRaw(state)
        self:_recordTransition(state, "enter", previousStates)
        self:_triggerCallback(state, "enter")
    end
end

--- Reset all states (clear all)
function ListValue:reset()
    self:_ensureUnlocked()
    local previousStates = self:getActiveValues()

    for _, state in ipairs(previousStates) do
        self:_removeRaw(state)
        self:_recordTransition(state, "exit", previousStates)
        self:_triggerCallback(state, "exit")
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

--- Check if any of the given states is active
--- @param ... string States to check
--- @return boolean True if any state is active
function ListValue:isAnyActive(...)
    local states = {...}
    for _, state in ipairs(states) do
        if self._activeValues[state] then
            return true
        end
    end
    return false
end

--- Check if all of the given states are active
--- @param ... string States to check
--- @return boolean True if all states are active
function ListValue:areAllActive(...)
    local states = {...}
    for _, state in ipairs(states) do
        if not self._activeValues[state] then
            return false
        end
    end
    return true
end

-- ============ Callbacks ============

--- Register callbacks for a specific state
--- @param state string State to register callbacks for
--- @param callbacks table Table with onEnter and/or onExit functions
function ListValue:onState(state, callbacks)
    self._stateCallbacks[state] = callbacks
end

--- Remove callbacks for a state
--- @param state string State to remove callbacks for
function ListValue:offState(state)
    self._stateCallbacks[state] = nil
end

--- Clear all state callbacks
function ListValue:clearCallbacks()
    self._stateCallbacks = {}
end

-- ============ History ============

--- Get transition history
--- @return table Array of transition events
function ListValue:getHistory()
    local result = {}
    for i, v in ipairs(self._history) do
        result[i] = v
    end
    return result
end

--- Clear transition history
function ListValue:clearHistory()
    self._history = {}
end

--- Get the last N transitions
--- @param count number Number of transitions to get
--- @return table Array of transition events
function ListValue:getRecentTransitions(count)
    local result = {}
    local start = math.max(1, #self._history - count + 1)
    for i = start, #self._history do
        table.insert(result, self._history[i])
    end
    return result
end

--- Find when a state was last entered
--- @param state string State to find
--- @return table|nil Transition event or nil
function ListValue:getLastEntry(state)
    for i = #self._history, 1, -1 do
        local event = self._history[i]
        if event.state == state and event.action == "enter" then
            return event
        end
    end
    return nil
end

--- Find when a state was last exited
--- @param state string State to find
--- @return table|nil Transition event or nil
function ListValue:getLastExit(state)
    for i = #self._history, 1, -1 do
        local event = self._history[i]
        if event.state == state and event.action == "exit" then
            return event
        end
    end
    return nil
end

-- ============ Thread Safety ============

--- Lock the state machine to prevent modifications
function ListValue:lock()
    self._locked = true
end

--- Unlock the state machine
function ListValue:unlock()
    self._locked = false
end

--- Check if the machine is locked
--- @return boolean True if locked
function ListValue:isLocked()
    return self._locked
end

--- Execute a function with the machine locked
--- @param fn function Function to execute
--- @return any Result of the function
function ListValue:withLock(fn)
    self:lock()
    local ok, result = pcall(fn, self)
    self:unlock()
    if not ok then
        error(result)
    end
    return result
end

-- ============ Serialization ============

--- Get current state for serialization
--- @return table Serialized state
function ListValue:getState()
    return {
        name = self._name,
        validStates = self:getPossibleValues(),
        activeStates = self:getActiveValues(),
        history = self._config.trackHistory and self:getHistory() or nil
    }
end

--- Restore from serialized state
--- @param state table Serialized state
function ListValue:restoreState(state)
    self:_ensureUnlocked()

    -- Rebuild possible values
    self._possibleValues = {}
    for _, v in ipairs(state.validStates) do
        self._possibleValues[v] = true
    end

    -- Rebuild active values
    self._activeValues = {}
    for _, v in ipairs(state.activeStates) do
        self._activeValues[v] = true
    end

    -- Restore history if provided
    if state.history then
        self._history = {}
        for _, event in ipairs(state.history) do
            table.insert(self._history, event)
        end
    end
end

--- Create a new ListValue from serialized state
--- @param state table Serialized state
--- @param config table|nil Configuration options
--- @return ListValue The new list value
function ListValue.fromState(state, config)
    local list = ListValue.new(
        state.name,
        state.validStates,
        state.activeStates,
        config
    )
    if state.history then
        list._history = {}
        for _, event in ipairs(state.history) do
            table.insert(list._history, event)
        end
    end
    return list
end

--- Create a copy of this list
--- @param includeHistory boolean|nil Whether to include history (default true)
--- @return ListValue The copy
function ListValue:copy(includeHistory)
    if includeHistory == nil then
        includeHistory = true
    end

    local copy = ListValue.new(
        self._name,
        self:getPossibleValues(),
        self:getActiveValues(),
        self._config
    )

    if includeHistory then
        for _, event in ipairs(self._history) do
            table.insert(copy._history, event)
        end
    end

    -- Clone callbacks
    for state, callbacks in pairs(self._stateCallbacks) do
        copy._stateCallbacks[state] = callbacks
    end

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
--- @param config table|nil Configuration options
--- @return ListValue The created list
function ListRegistry:define(name, possibleValues, initialValues, config)
    if self._lists[name] then
        error("LIST already defined: " .. name)
    end

    local list = ListValue.new(name, possibleValues, initialValues, config)
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

--- Get all lists
--- @return table Array of lists
function ListRegistry:getAll()
    local lists = {}
    for _, list in pairs(self._lists) do
        table.insert(lists, list)
    end
    return lists
end

--- Remove a list
--- @param name string The list name
--- @return boolean True if removed
function ListRegistry:remove(name)
    if self._lists[name] then
        self._lists[name] = nil
        return true
    end
    return false
end

--- Get serialized state of all lists
--- @return table Map of list states
function ListRegistry:getState()
    local result = {}
    for name, list in pairs(self._lists) do
        result[name] = list:getState()
    end
    return result
end

--- Restore all lists from serialized state
--- @param state table Map of list states
function ListRegistry:restoreState(state)
    for name, listState in pairs(state) do
        local existing = self._lists[name]
        if existing then
            existing:restoreState(listState)
        else
            self._lists[name] = ListValue.fromState(listState)
        end
    end
end

--- Clone this registry
--- @param includeHistory boolean|nil Whether to include history (default true)
--- @return ListRegistry The clone
function ListRegistry:clone(includeHistory)
    local cloned = ListRegistry.new()
    for name, list in pairs(self._lists) do
        cloned._lists[name] = list:copy(includeHistory)
    end
    return cloned
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
    function manager:define(name, possibleValues, initialValues, config)
        return self.registry:define(name, possibleValues, initialValues, config)
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

    function manager:getAll()
        return self.registry:getAll()
    end

    function manager:remove(name)
        return self.registry:remove(name)
    end

    function manager:clear()
        self.registry:clear()
    end

    function manager:getState()
        return self.registry:getState()
    end

    function manager:restoreState(state)
        self.registry:restoreState(state)
    end

    function manager:clone(includeHistory)
        local cloned = {
            registry = self.registry:clone(includeHistory),
            _deps = self._deps
        }
        setmetatable(cloned, getmetatable(self))
        return cloned
    end

    return manager
end

-- ============ Convenience Functions ============

--- Create a simple state machine for exclusive states
--- @param name string Machine name
--- @param states table Array of state names
--- @param initialState string|nil Initial state (defaults to first)
--- @param config table|nil Configuration options
--- @return ListValue The state machine
function ListStateMachine.createExclusive(name, states, initialState, config)
    local initial = {}
    if initialState then
        initial = {initialState}
    elseif #states > 0 then
        initial = {states[1]}
    end
    return ListValue.new(name, states, initial, config)
end

--- Create a flag-based state machine where multiple states can be active
--- @param name string Machine name
--- @param flags table Array of flag names
--- @param initialFlags table|nil Array of initially active flags
--- @param config table|nil Configuration options
--- @return ListValue The state machine
function ListStateMachine.createFlags(name, flags, initialFlags, config)
    return ListValue.new(name, flags, initialFlags or {}, config)
end

return ListStateMachine
