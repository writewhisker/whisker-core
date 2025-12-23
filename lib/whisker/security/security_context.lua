--- Security Context
-- Thread-local storage for current plugin execution context
-- @module whisker.security.security_context
-- @author Whisker Core Team
-- @license MIT

local SecurityContext = {}

--- Current context stack (for nested plugin calls)
local _context_stack = {}

--- Context entry metadata
-- @table ContextEntry
-- @field plugin_id string Plugin identifier
-- @field capabilities table Set of granted capabilities
-- @field permissions table Set of granted permissions
-- @field start_time number Execution start time
-- @field parent_id string|nil Parent plugin ID (for nested calls)

--- Enter a security context
-- @param plugin_id string Plugin identifier
-- @param capabilities table Array of capability IDs
-- @param permissions table|nil Set of granted permissions
-- @return boolean success
function SecurityContext.enter(plugin_id, capabilities, permissions)
  assert(type(plugin_id) == "string", "Plugin ID must be string")
  assert(type(capabilities) == "table", "Capabilities must be table")

  -- Convert capabilities to set for O(1) lookup
  local cap_set = {}
  for _, cap in ipairs(capabilities) do
    cap_set[cap] = true
  end

  -- Get parent ID if we're nested
  local parent_id = nil
  if #_context_stack > 0 then
    parent_id = _context_stack[#_context_stack].plugin_id
  end

  -- Push context onto stack
  local entry = {
    plugin_id = plugin_id,
    capabilities = cap_set,
    permissions = permissions or {},
    start_time = os.clock(),
    parent_id = parent_id,
  }

  table.insert(_context_stack, entry)

  return true
end

--- Exit the current security context
-- @return boolean success
-- @return string|nil error Error if no context to exit
function SecurityContext.exit()
  if #_context_stack == 0 then
    return false, "No security context to exit"
  end

  table.remove(_context_stack)
  return true
end

--- Get current context (top of stack)
-- @return table|nil Current context entry or nil if none
function SecurityContext.current()
  if #_context_stack == 0 then
    return nil
  end
  return _context_stack[#_context_stack]
end

--- Get current plugin ID
-- @return string|nil Plugin ID or nil if no context
function SecurityContext.get_plugin_id()
  local ctx = SecurityContext.current()
  if ctx then
    return ctx.plugin_id
  end
  return nil
end

--- Check if capability is available in current context
-- @param capability_id string Capability ID
-- @return boolean True if capability is available
function SecurityContext.has_capability(capability_id)
  local ctx = SecurityContext.current()
  if not ctx then
    -- No context means core code, which has all capabilities
    return true
  end
  return ctx.capabilities[capability_id] == true
end

--- Get all capabilities in current context
-- @return table Set of capability IDs
function SecurityContext.get_capabilities()
  local ctx = SecurityContext.current()
  if not ctx then
    return {} -- Core code has implicit capabilities
  end
  return ctx.capabilities
end

--- Check if permission is granted in current context
-- @param permission_key string Permission key
-- @return boolean True if permission is granted
function SecurityContext.has_permission(permission_key)
  local ctx = SecurityContext.current()
  if not ctx then
    return true -- Core code has all permissions
  end
  return ctx.permissions[permission_key] == true
end

--- Get execution time of current context
-- @return number|nil Time in seconds or nil if no context
function SecurityContext.get_execution_time()
  local ctx = SecurityContext.current()
  if not ctx then
    return nil
  end
  return os.clock() - ctx.start_time
end

--- Get context stack depth
-- @return number Stack depth
function SecurityContext.depth()
  return #_context_stack
end

--- Check if currently in a plugin context
-- @return boolean True if in a plugin context
function SecurityContext.in_plugin_context()
  return #_context_stack > 0
end

--- Check if currently in nested plugin context
-- @return boolean True if nested (depth > 1)
function SecurityContext.is_nested()
  return #_context_stack > 1
end

--- Get parent plugin ID (for nested contexts)
-- @return string|nil Parent plugin ID or nil
function SecurityContext.get_parent_id()
  local ctx = SecurityContext.current()
  if ctx then
    return ctx.parent_id
  end
  return nil
end

--- Execute function within a security context
-- @param plugin_id string Plugin identifier
-- @param capabilities table Array of capability IDs
-- @param fn function Function to execute
-- @param ... any Arguments to pass to function
-- @return boolean success
-- @return any result Function result or error
function SecurityContext.with_context(plugin_id, capabilities, fn, ...)
  SecurityContext.enter(plugin_id, capabilities)

  local results = {pcall(fn, ...)}
  local success = results[1]

  SecurityContext.exit()

  if success then
    return true, select(2, table.unpack(results))
  else
    return false, results[2]
  end
end

--- Clear all contexts (for cleanup/testing)
function SecurityContext.clear()
  _context_stack = {}
end

--- Get full context stack (for debugging)
-- @return table Array of context entries
function SecurityContext.get_stack()
  local stack = {}
  for i, entry in ipairs(_context_stack) do
    stack[i] = {
      plugin_id = entry.plugin_id,
      capabilities = entry.capabilities,
      depth = i,
    }
  end
  return stack
end

--- Validate context integrity
-- Checks that all contexts were properly exited
-- @return boolean success
-- @return string|nil error Error if stack is not empty
function SecurityContext.validate()
  if #_context_stack > 0 then
    local ids = {}
    for _, entry in ipairs(_context_stack) do
      table.insert(ids, entry.plugin_id)
    end
    return false, string.format(
      "Security context leak: %d unexited contexts (%s)",
      #_context_stack,
      table.concat(ids, ", ")
    )
  end
  return true
end

return SecurityContext
