--- Hook Manager
-- Central registry for hook handlers with priority-based execution
-- @module whisker.plugin.hook_manager
-- @author Whisker Core Team
-- @license MIT

local HookTypes = require("whisker.plugin.hook_types")

local HookManager = {}
HookManager._dependencies = {}
HookManager.__index = HookManager

--- Default hook priority
HookManager.DEFAULT_PRIORITY = 50

--- Priority range
HookManager.MIN_PRIORITY = 0
HookManager.MAX_PRIORITY = 100

--- Create a new hook manager
-- @return HookManager New instance
function HookManager.new(deps)
  deps = deps or {}
  local self = setmetatable({}, HookManager)

  self._hooks = {}         -- event -> [{id, callback, priority, plugin_name}]
  self._next_id = 1        -- Auto-increment hook ID
  self._id_to_event = {}   -- hook_id -> event name (for unregistration)
  self._paused = {}        -- event -> boolean (pause specific events)
  self._global_pause = false

  return self
end

--- Generate unique hook ID
-- @return string Hook ID
function HookManager:_generate_id()
  local id = "hook_" .. self._next_id
  self._next_id = self._next_id + 1
  return id
end

--- Register a hook handler
-- @param event string Hook event name
-- @param callback function Handler function
-- @param priority number|nil Priority (0-100, default 50, lower runs first)
-- @param plugin_name string|nil Plugin name for debugging
-- @return string hook_id Hook identifier for unregistration
function HookManager:register_hook(event, callback, priority, plugin_name)
  assert(type(event) == "string", "Event must be string")
  assert(type(callback) == "function", "Callback must be function")

  priority = priority or HookManager.DEFAULT_PRIORITY
  assert(type(priority) == "number", "Priority must be number")
  priority = math.max(HookManager.MIN_PRIORITY, math.min(HookManager.MAX_PRIORITY, priority))

  -- Initialize event bucket if needed
  if not self._hooks[event] then
    self._hooks[event] = {}
  end

  -- Generate hook ID
  local hook_id = self:_generate_id()

  -- Create hook entry
  local entry = {
    id = hook_id,
    callback = callback,
    priority = priority,
    plugin_name = plugin_name,
    registered_at = os.time(),
  }

  -- Insert maintaining priority order (lower priority runs first)
  local hooks = self._hooks[event]
  local inserted = false
  for i, existing in ipairs(hooks) do
    if priority < existing.priority then
      table.insert(hooks, i, entry)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(hooks, entry)
  end

  -- Track for unregistration
  self._id_to_event[hook_id] = event

  return hook_id
end

--- Unregister a hook handler
-- @param hook_id string Hook ID from register_hook
-- @return boolean success
function HookManager:unregister_hook(hook_id)
  local event = self._id_to_event[hook_id]
  if not event then
    return false
  end

  local hooks = self._hooks[event]
  if not hooks then
    return false
  end

  for i, entry in ipairs(hooks) do
    if entry.id == hook_id then
      table.remove(hooks, i)
      self._id_to_event[hook_id] = nil
      return true
    end
  end

  return false
end

--- Trigger an observer hook (side effects only)
-- @param event string Hook event name
-- @param ... any Arguments to pass to handlers
-- @return table results Array of {success, result_or_error} for each handler
function HookManager:trigger(event, ...)
  if self._global_pause or self._paused[event] then
    return {}
  end

  local hooks = self._hooks[event]
  if not hooks or #hooks == 0 then
    return {}
  end

  local results = {}

  for _, entry in ipairs(hooks) do
    local success, result = pcall(entry.callback, ...)
    table.insert(results, {
      success = success,
      result = result,
      hook_id = entry.id,
      plugin_name = entry.plugin_name,
    })
  end

  return results
end

--- Trigger a transform hook (returns modified value)
-- @param event string Hook event name
-- @param initial_value any Initial value to transform
-- @param ... any Additional arguments (passed to each handler)
-- @return any transformed_value Final transformed value
-- @return table results Array of {success, result_or_error} for each handler
function HookManager:transform(event, initial_value, ...)
  if self._global_pause or self._paused[event] then
    return initial_value, {}
  end

  local hooks = self._hooks[event]
  if not hooks or #hooks == 0 then
    return initial_value, {}
  end

  local value = initial_value
  local results = {}

  for _, entry in ipairs(hooks) do
    local success, result = pcall(entry.callback, value, ...)

    table.insert(results, {
      success = success,
      result = result,
      hook_id = entry.id,
      plugin_name = entry.plugin_name,
    })

    if success and result ~= nil then
      value = result  -- Use transformed value
    end
  end

  return value, results
end

--- Smart trigger based on hook type
-- Automatically calls trigger() for observer hooks and transform() for transform hooks
-- @param event string Hook event name
-- @param ... any Arguments (first arg is value for transform hooks)
-- @return any|nil value Transformed value for transform hooks, nil for observer
-- @return table results Handler results
function HookManager:emit(event, ...)
  local mode = HookTypes.get_mode(event)

  if mode == HookTypes.MODE.TRANSFORM then
    return self:transform(event, ...)
  else
    -- Observer mode (including unknown events treated as observer)
    return nil, self:trigger(event, ...)
  end
end

--- Get registered hooks for an event
-- @param event string Hook event name
-- @return table[] Array of hook entries
function HookManager:get_hooks(event)
  return self._hooks[event] or {}
end

--- Get number of registered hooks for an event
-- @param event string Hook event name
-- @return number Hook count
function HookManager:get_hook_count(event)
  local hooks = self._hooks[event]
  return hooks and #hooks or 0
end

--- Get all events with registered hooks
-- @return string[] Array of event names
function HookManager:get_registered_events()
  local events = {}
  for event, hooks in pairs(self._hooks) do
    if #hooks > 0 then
      table.insert(events, event)
    end
  end
  table.sort(events)
  return events
end

--- Get total number of registered hooks
-- @return number Total hook count
function HookManager:get_total_hook_count()
  local total = 0
  for _, hooks in pairs(self._hooks) do
    total = total + #hooks
  end
  return total
end

--- Clear all hooks for an event
-- @param event string Hook event name
-- @return number Number of hooks removed
function HookManager:clear_event(event)
  local hooks = self._hooks[event]
  if not hooks then
    return 0
  end

  local count = #hooks

  -- Remove ID mappings
  for _, entry in ipairs(hooks) do
    self._id_to_event[entry.id] = nil
  end

  self._hooks[event] = nil

  return count
end

--- Clear all registered hooks
-- @return number Number of hooks removed
function HookManager:clear_all()
  local total = self:get_total_hook_count()
  self._hooks = {}
  self._id_to_event = {}
  return total
end

--- Clear all hooks for a specific plugin
-- @param plugin_name string Plugin name
-- @return number Number of hooks removed
function HookManager:clear_plugin_hooks(plugin_name)
  local removed = 0

  for event, hooks in pairs(self._hooks) do
    local i = 1
    while i <= #hooks do
      if hooks[i].plugin_name == plugin_name then
        self._id_to_event[hooks[i].id] = nil
        table.remove(hooks, i)
        removed = removed + 1
      else
        i = i + 1
      end
    end
  end

  return removed
end

--- Pause hook execution for an event
-- @param event string Hook event name
function HookManager:pause_event(event)
  self._paused[event] = true
end

--- Resume hook execution for an event
-- @param event string Hook event name
function HookManager:resume_event(event)
  self._paused[event] = nil
end

--- Check if event is paused
-- @param event string Hook event name
-- @return boolean True if paused
function HookManager:is_event_paused(event)
  return self._paused[event] == true
end

--- Pause all hook execution globally
function HookManager:pause_all()
  self._global_pause = true
end

--- Resume all hook execution globally
function HookManager:resume_all()
  self._global_pause = false
end

--- Check if hooks are globally paused
-- @return boolean True if globally paused
function HookManager:is_globally_paused()
  return self._global_pause
end

--- Get hooks for a specific plugin
-- @param plugin_name string Plugin name
-- @return table[] Array of {event, hook_entry}
function HookManager:get_plugin_hooks(plugin_name)
  local plugin_hooks = {}

  for event, hooks in pairs(self._hooks) do
    for _, entry in ipairs(hooks) do
      if entry.plugin_name == plugin_name then
        table.insert(plugin_hooks, {
          event = event,
          hook = entry,
        })
      end
    end
  end

  return plugin_hooks
end

--- Register static hooks from plugin definition
-- @param plugin_name string Plugin name
-- @param hooks table Map of event -> handler function
-- @param priority number|nil Base priority for hooks
-- @return string[] hook_ids Array of registered hook IDs
function HookManager:register_plugin_hooks(plugin_name, hooks, priority)
  local hook_ids = {}

  if not hooks then
    return hook_ids
  end

  for event, callback in pairs(hooks) do
    if type(callback) == "function" then
      local id = self:register_hook(event, callback, priority, plugin_name)
      table.insert(hook_ids, id)
    end
  end

  return hook_ids
end

--- Create a scoped context for temporary hooks
-- Hooks registered in the scope are automatically unregistered when scope closes
-- @return table Scope object with register() and close() methods
function HookManager:create_scope()
  local manager = self
  local scope_hooks = {}

  local scope = {}

  --- Register a hook in this scope
  -- @param event string Hook event name
  -- @param callback function Handler function
  -- @param priority number|nil Priority
  -- @return string hook_id
  function scope:register(event, callback, priority)
    local id = manager:register_hook(event, callback, priority, "scope")
    table.insert(scope_hooks, id)
    return id
  end

  --- Close scope and unregister all hooks
  -- @return number Number of hooks unregistered
  function scope:close()
    local count = 0
    for _, id in ipairs(scope_hooks) do
      if manager:unregister_hook(id) then
        count = count + 1
      end
    end
    scope_hooks = {}
    return count
  end

  --- Get hooks registered in this scope
  -- @return string[] Array of hook IDs
  function scope:get_hooks()
    local ids = {}
    for _, id in ipairs(scope_hooks) do
      table.insert(ids, id)
    end
    return ids
  end

  return scope
end

return HookManager
