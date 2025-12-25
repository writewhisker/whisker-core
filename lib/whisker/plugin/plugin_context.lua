--- Plugin Context
-- Provides capability-controlled access to framework features for plugins
-- @module whisker.plugin.plugin_context
-- @author Whisker Core Team
-- @license MIT

local PluginContext = {}
PluginContext._dependencies = {}
PluginContext.__index = PluginContext

--- Known capability types
-- @table CAPABILITIES
PluginContext.CAPABILITIES = {
  -- State access
  "state:read",
  "state:write",
  "state:watch",
  -- Persistence
  "persistence:read",
  "persistence:write",
  -- UI
  "ui:inject",
  "ui:style",
  "ui:theme",
  -- System (restricted)
  "system:http",
  "system:file",
}

--- Create a new plugin context
-- @param plugin_name string Plugin name
-- @param plugin_version string Plugin version
-- @param capabilities string[]|nil Capabilities granted to plugin
-- @param state_manager table|nil State manager for state/storage access
-- @param hook_manager table|nil Hook manager for dynamic hook registration
-- @param plugin_registry table|nil Plugin registry for inter-plugin communication
-- @return PluginContext New context instance
function PluginContext.new(plugin_name, plugin_version, capabilities, state_manager, hook_manager, plugin_registry)
  local self = setmetatable({}, PluginContext)

  self.name = plugin_name
  self.version = plugin_version
  self._capabilities = capabilities or {}
  self._state_manager = state_manager
  self._hook_manager = hook_manager
  self._plugin_registry = plugin_registry
  self._registered_hooks = {}

  -- Create capability-controlled interfaces
  self.state = self:_create_state_interface()
  self.storage = self:_create_storage_interface()
  self.ui = self:_create_ui_interface()
  self.log = self:_create_log_interface()
  self.plugins = self:_create_plugins_interface()
  self.hooks = self:_create_hooks_interface()

  return self
end

--- Check if plugin has a specific capability
-- @param capability string The capability to check
-- @return boolean True if plugin has the capability
function PluginContext:has_capability(capability)
  for _, cap in ipairs(self._capabilities) do
    if cap == capability then
      return true
    end
  end
  return false
end

--- Get all granted capabilities
-- @return string[] Array of capabilities
function PluginContext:get_capabilities()
  local caps = {}
  for i, cap in ipairs(self._capabilities) do
    caps[i] = cap
  end
  return caps
end

--- Check capability and raise error if missing
-- @param capability string The capability required
local function require_capability(self, capability)
  if not self:has_capability(capability) then
    error(string.format(
      "Plugin '%s' lacks capability '%s'",
      self.name,
      capability
    ))
  end
end

--- Create state access interface (story variables)
-- @return table State interface
function PluginContext:_create_state_interface()
  local self_ref = self

  return {
    --- Get a story variable
    -- @param key string Variable name
    -- @return any Variable value
    get = function(key)
      require_capability(self_ref, "state:read")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      return self_ref._state_manager:get(key)
    end,

    --- Set a story variable
    -- @param key string Variable name
    -- @param value any Variable value
    set = function(key, value)
      require_capability(self_ref, "state:write")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      self_ref._state_manager:set(key, value)
    end,

    --- Check if a story variable exists
    -- @param key string Variable name
    -- @return boolean True if exists
    has = function(key)
      require_capability(self_ref, "state:read")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      return self_ref._state_manager:has(key)
    end,

    --- Delete a story variable
    -- @param key string Variable name
    delete = function(key)
      require_capability(self_ref, "state:write")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      if self_ref._state_manager.delete then
        self_ref._state_manager:delete(key)
      else
        self_ref._state_manager:set(key, nil)
      end
    end,

    --- Get all story variables
    -- @return table All variables
    get_all = function()
      require_capability(self_ref, "state:read")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      if self_ref._state_manager.get_all_variables then
        return self_ref._state_manager:get_all_variables()
      end
      return {}
    end,
  }
end

--- Create plugin-specific storage interface (namespaced)
-- @return table Storage interface
function PluginContext:_create_storage_interface()
  local self_ref = self

  -- Storage keys are prefixed with plugin name
  local function make_key(key)
    return "__plugin_" .. self_ref.name .. "_" .. key
  end

  return {
    --- Get a plugin storage value
    -- @param key string Storage key
    -- @return any Stored value
    get = function(key)
      require_capability(self_ref, "persistence:read")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      return self_ref._state_manager:get(make_key(key))
    end,

    --- Set a plugin storage value
    -- @param key string Storage key
    -- @param value any Value to store
    set = function(key, value)
      require_capability(self_ref, "persistence:write")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      self_ref._state_manager:set(make_key(key), value)
    end,

    --- Check if a plugin storage key exists
    -- @param key string Storage key
    -- @return boolean True if exists
    has = function(key)
      require_capability(self_ref, "persistence:read")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      return self_ref._state_manager:has(make_key(key))
    end,

    --- Delete a plugin storage key
    -- @param key string Storage key
    delete = function(key)
      require_capability(self_ref, "persistence:write")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      if self_ref._state_manager.delete then
        self_ref._state_manager:delete(make_key(key))
      else
        self_ref._state_manager:set(make_key(key), nil)
      end
    end,

    --- Clear all plugin storage
    clear = function()
      require_capability(self_ref, "persistence:write")
      if not self_ref._state_manager then
        error("State manager not available")
      end
      -- Clear all keys with plugin prefix
      local prefix = "__plugin_" .. self_ref.name .. "_"
      if self_ref._state_manager.delete_prefix then
        self_ref._state_manager:delete_prefix(prefix)
      elseif self_ref._state_manager.get_all_variables then
        -- Fallback: iterate and delete matching keys
        local all_vars = self_ref._state_manager:get_all_variables()
        for key in pairs(all_vars) do
          if key:sub(1, #prefix) == prefix then
            if self_ref._state_manager.delete then
              self_ref._state_manager:delete(key)
            else
              self_ref._state_manager:set(key, nil)
            end
          end
        end
      end
    end,
  }
end

--- Create UI injection interface
-- @return table UI interface
function PluginContext:_create_ui_interface()
  local self_ref = self

  return {
    --- Add a UI component
    -- @param component_def table Component definition
    -- @return string Component ID
    add_component = function(component_def)
      require_capability(self_ref, "ui:inject")
      -- UI implementation deferred to later phase
      error("UI injection not yet implemented")
    end,

    --- Remove a UI component
    -- @param component_id string Component ID
    -- @return boolean Success
    remove_component = function(component_id)
      require_capability(self_ref, "ui:inject")
      error("UI injection not yet implemented")
    end,

    --- Update a UI component
    -- @param component_id string Component ID
    -- @param updates table Partial component definition
    -- @return boolean Success
    update_component = function(component_id, updates)
      require_capability(self_ref, "ui:inject")
      error("UI injection not yet implemented")
    end,
  }
end

--- Create logging interface (always available)
-- @return table Log interface
function PluginContext:_create_log_interface()
  local self_ref = self

  local function format_message(level, message, ...)
    local args = {...}
    local formatted = #args > 0 and string.format(message, ...) or message
    return string.format("[%s][%s] %s", level, self_ref.name, formatted)
  end

  return {
    --- Log debug message
    -- @param message string Log message
    -- @param ... any Format arguments
    debug = function(message, ...)
      print(format_message("DEBUG", message, ...))
    end,

    --- Log info message
    -- @param message string Log message
    -- @param ... any Format arguments
    info = function(message, ...)
      print(format_message("INFO", message, ...))
    end,

    --- Log warning message
    -- @param message string Log message
    -- @param ... any Format arguments
    warn = function(message, ...)
      print(format_message("WARN", message, ...))
    end,

    --- Log error message
    -- @param message string Log message
    -- @param ... any Format arguments
    error = function(message, ...)
      print(format_message("ERROR", message, ...))
    end,
  }
end

--- Create inter-plugin communication interface (always available)
-- @return table Plugins interface
function PluginContext:_create_plugins_interface()
  local self_ref = self

  return {
    --- Get another plugin's public API
    -- @param plugin_name string Plugin name
    -- @return table|nil Plugin API or nil if not found/enabled
    get = function(plugin_name)
      if not self_ref._plugin_registry then
        return nil
      end

      local plugin = self_ref._plugin_registry:get_plugin(plugin_name)
      if not plugin then
        return nil
      end

      -- Only return API if plugin is enabled
      if plugin.state ~= "enabled" then
        return nil
      end

      -- Return plugin's public API
      return plugin.definition and plugin.definition.api or nil
    end,

    --- Check if a plugin exists and is enabled
    -- @param plugin_name string Plugin name
    -- @return boolean True if plugin is available
    has = function(plugin_name)
      if not self_ref._plugin_registry then
        return false
      end

      local plugin = self_ref._plugin_registry:get_plugin(plugin_name)
      return plugin ~= nil and plugin.state == "enabled"
    end,

    --- List all enabled plugins
    -- @return string[] Array of enabled plugin names
    list = function()
      if not self_ref._plugin_registry then
        return {}
      end

      local enabled = self_ref._plugin_registry:get_plugins_by_state("enabled")
      local names = {}
      for _, plugin in ipairs(enabled) do
        table.insert(names, plugin.name)
      end
      return names
    end,
  }
end

--- Create hook registration interface (always available)
-- @return table Hooks interface
function PluginContext:_create_hooks_interface()
  local self_ref = self

  return {
    --- Register a hook handler
    -- @param event string Hook event name
    -- @param callback function Handler function
    -- @param priority number|nil Priority (0-100, default 50)
    -- @return string|nil Hook ID or nil if failed
    register = function(event, callback, priority)
      if not self_ref._hook_manager then
        error("Hook manager not available")
      end

      local hook_id = self_ref._hook_manager:register_hook(event, callback, priority)

      -- Track registered hooks for cleanup
      table.insert(self_ref._registered_hooks, hook_id)

      return hook_id
    end,

    --- Unregister a hook handler
    -- @param hook_id string Hook ID from register
    -- @return boolean Success
    unregister = function(hook_id)
      if not self_ref._hook_manager then
        error("Hook manager not available")
      end

      local success = self_ref._hook_manager:unregister_hook(hook_id)

      -- Remove from tracked hooks
      if success then
        for i, id in ipairs(self_ref._registered_hooks) do
          if id == hook_id then
            table.remove(self_ref._registered_hooks, i)
            break
          end
        end
      end

      return success
    end,
  }
end

--- Cleanup all resources (called during plugin destroy)
function PluginContext:cleanup()
  -- Unregister all hooks
  if self._hook_manager then
    for _, hook_id in ipairs(self._registered_hooks) do
      pcall(function()
        self._hook_manager:unregister_hook(hook_id)
      end)
    end
  end
  self._registered_hooks = {}
end

--- Validate a capability string
-- @param capability string Capability to validate
-- @return boolean True if valid capability
function PluginContext.is_valid_capability(capability)
  for _, valid_cap in ipairs(PluginContext.CAPABILITIES) do
    if capability == valid_cap then
      return true
    end
  end
  return false
end

--- Validate an array of capabilities
-- @param capabilities string[] Capabilities to validate
-- @return boolean success
-- @return string|nil error Error message if validation failed
function PluginContext.validate_capabilities(capabilities)
  if not capabilities then
    return true
  end

  if type(capabilities) ~= "table" then
    return false, "Capabilities must be a table"
  end

  for i, cap in ipairs(capabilities) do
    if type(cap) ~= "string" then
      return false, string.format("Capability at index %d must be a string", i)
    end
    if not PluginContext.is_valid_capability(cap) then
      return false, string.format("Unknown capability: %s", cap)
    end
  end

  return true
end

return PluginContext
