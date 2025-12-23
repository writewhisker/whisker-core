--- IPlugin Interface
-- Interface for whisker-core plugins
-- @module whisker.interfaces.plugin
-- @author Whisker Core Team
-- @license MIT

local IPlugin = {}

--- Get the plugin name
-- @return string The unique plugin identifier
function IPlugin:get_name()
  error("IPlugin:get_name must be implemented")
end

--- Get the plugin version
-- @return string The plugin version (semver format)
function IPlugin:get_version()
  error("IPlugin:get_version must be implemented")
end

--- Initialize the plugin
-- @param container table The DI container
-- @return boolean True if initialization succeeded
-- @return string|nil Error message if initialization failed
function IPlugin:init(container)
  error("IPlugin:init must be implemented")
end

--- Destroy/cleanup the plugin
function IPlugin:destroy()
  error("IPlugin:destroy must be implemented")
end

--- Get event hooks this plugin wants to handle
-- @return table Map of event names to handler functions
function IPlugin:get_hooks()
  error("IPlugin:get_hooks must be implemented")
end

--- Get services this plugin provides
-- @return table Map of service names to service factories
function IPlugin:get_services()
  error("IPlugin:get_services must be implemented")
end

--- Get plugin dependencies
-- @return table Array of required plugin names
function IPlugin:get_dependencies()
  error("IPlugin:get_dependencies must be implemented")
end

--- Check if plugin is enabled
-- @return boolean True if enabled
function IPlugin:is_enabled()
  error("IPlugin:is_enabled must be implemented")
end

--- Enable the plugin
function IPlugin:enable()
  error("IPlugin:enable must be implemented")
end

--- Disable the plugin
function IPlugin:disable()
  error("IPlugin:disable must be implemented")
end

return IPlugin
