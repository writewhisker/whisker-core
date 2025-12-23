--- Plugin Lifecycle State Machine
-- Manages plugin state transitions and validates lifecycle operations
-- @module whisker.plugin.plugin_lifecycle
-- @author Whisker Core Team
-- @license MIT

local PluginLifecycle = {}

--- Valid lifecycle states
-- @table STATES
PluginLifecycle.STATES = {
  "discovered",   -- Plugin found during directory scan, metadata extracted
  "loaded",       -- Plugin module loaded into memory, validated
  "initialized",  -- on_init hook executed, plugin received context
  "enabled",      -- on_enable hook executed, plugin actively participating
  "disabled",     -- on_disable hook executed, plugin temporarily inactive
  "destroyed",    -- on_destroy hook executed, plugin completely unloaded
  "error",        -- Plugin encountered error during lifecycle transition
}

--- Valid state transitions
-- Maps each state to an array of valid target states
-- @table TRANSITIONS
PluginLifecycle.TRANSITIONS = {
  discovered = {"loaded", "error"},
  loaded = {"initialized", "error"},
  initialized = {"enabled", "error"},
  enabled = {"disabled", "error"},
  disabled = {"enabled", "destroyed", "error"},
  error = {"destroyed"},
  destroyed = {},  -- Terminal state, no transitions allowed
}

--- Hook names associated with transitions
-- Maps transition (from:to) to the hook(s) to call
-- @table TRANSITION_HOOKS
PluginLifecycle.TRANSITION_HOOKS = {
  ["loaded:initialized"] = {"on_load", "on_init"},
  ["initialized:enabled"] = {"on_enable"},
  ["enabled:disabled"] = {"on_disable"},
  ["disabled:enabled"] = {"on_enable"},
  ["disabled:destroyed"] = {"on_destroy"},
  ["error:destroyed"] = {"on_destroy"},
}

--- Check if a state is valid
-- @param state string The state to check
-- @return boolean True if valid state
function PluginLifecycle.is_valid_state(state)
  for _, valid_state in ipairs(PluginLifecycle.STATES) do
    if state == valid_state then
      return true
    end
  end
  return false
end

--- Check if state transition is valid
-- @param from string Current state
-- @param to string Target state
-- @return boolean True if transition is valid
function PluginLifecycle.is_valid_transition(from, to)
  local allowed = PluginLifecycle.TRANSITIONS[from]
  if not allowed then
    return false
  end

  for _, state in ipairs(allowed) do
    if state == to then
      return true
    end
  end

  return false
end

--- Get allowed transitions from state
-- @param from string Current state
-- @return string[] Array of allowed next states
function PluginLifecycle.get_allowed_transitions(from)
  return PluginLifecycle.TRANSITIONS[from] or {}
end

--- Get hooks to execute for a transition
-- @param from string Current state
-- @param to string Target state
-- @return string[]|nil Array of hook names, or nil if no hooks
function PluginLifecycle.get_transition_hooks(from, to)
  local key = from .. ":" .. to
  return PluginLifecycle.TRANSITION_HOOKS[key]
end

--- Check if a state is terminal (no further transitions)
-- @param state string The state to check
-- @return boolean True if terminal state
function PluginLifecycle.is_terminal_state(state)
  local transitions = PluginLifecycle.TRANSITIONS[state]
  return transitions == nil or #transitions == 0
end

--- Check if a state indicates the plugin is active
-- @param state string The state to check
-- @return boolean True if plugin is active
function PluginLifecycle.is_active_state(state)
  return state == "enabled"
end

--- Check if a state indicates the plugin can be safely destroyed
-- @param state string The state to check
-- @return boolean True if plugin can be destroyed
function PluginLifecycle.can_destroy(state)
  if state == "destroyed" then
    return false  -- Already destroyed
  end
  if state == "error" or state == "disabled" then
    return true
  end
  return false
end

--- Get the path from current state to target state
-- Returns nil if no valid path exists
-- @param from string Current state
-- @param to string Target state
-- @return string[]|nil Array of states in the path, or nil
function PluginLifecycle.get_transition_path(from, to)
  if from == to then
    return {}
  end

  -- BFS to find shortest path
  local queue = {{state = from, path = {}}}
  local visited = {[from] = true}

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local allowed = PluginLifecycle.get_allowed_transitions(current.state)

    for _, next_state in ipairs(allowed) do
      if not visited[next_state] then
        local new_path = {}
        for _, s in ipairs(current.path) do
          table.insert(new_path, s)
        end
        table.insert(new_path, next_state)

        if next_state == to then
          return new_path
        end

        visited[next_state] = true
        table.insert(queue, {state = next_state, path = new_path})
      end
    end
  end

  return nil  -- No path found
end

--- Create a state machine instance for tracking a plugin
-- @param initial_state string|nil Initial state (defaults to "discovered")
-- @return table State machine instance
function PluginLifecycle.create_state_machine(initial_state)
  local machine = {
    _state = initial_state or "discovered",
    _history = {},
    _error = nil,
  }

  --- Get current state
  -- @return string Current state
  function machine:get_state()
    return self._state
  end

  --- Get error message (if in error state)
  -- @return string|nil Error message
  function machine:get_error()
    return self._error
  end

  --- Get state transition history
  -- @return table[] Array of {from, to, timestamp} entries
  function machine:get_history()
    return self._history
  end

  --- Transition to new state
  -- @param to string Target state
  -- @param error_msg string|nil Error message (if transitioning to error)
  -- @return boolean success
  -- @return string|nil error Error message if transition failed
  function machine:transition(to, error_msg)
    local from = self._state

    if not PluginLifecycle.is_valid_transition(from, to) then
      return false, string.format(
        "Invalid transition: %s -> %s",
        from,
        to
      )
    end

    -- Record history
    table.insert(self._history, {
      from = from,
      to = to,
      timestamp = os.time(),
    })

    self._state = to

    if to == "error" then
      self._error = error_msg
    else
      self._error = nil
    end

    return true
  end

  --- Check if can transition to state
  -- @param to string Target state
  -- @return boolean True if transition is valid
  function machine:can_transition(to)
    return PluginLifecycle.is_valid_transition(self._state, to)
  end

  --- Get allowed next states
  -- @return string[] Array of allowed states
  function machine:get_allowed_next()
    return PluginLifecycle.get_allowed_transitions(self._state)
  end

  return machine
end

return PluginLifecycle
