--- Plugin System
-- Plugin infrastructure for whisker-core extensibility
-- @module whisker.plugin
-- @author Whisker Core Team
-- @license MIT

local plugin = {}

-- Export submodules
plugin.PluginLifecycle = require("whisker.plugin.plugin_lifecycle")
plugin.PluginContext = require("whisker.plugin.plugin_context")
plugin.PluginRegistry = require("whisker.plugin.plugin_registry")
plugin.DependencyResolver = require("whisker.plugin.dependency_resolver")
plugin.HookManager = require("whisker.plugin.hook_manager")
plugin.HookTypes = require("whisker.plugin.hook_types")
plugin.StoryHooks = require("whisker.plugin.story_hooks")
plugin.PluginSandbox = require("whisker.plugin.plugin_sandbox")
plugin.BuiltinLoader = require("whisker.plugin.builtin_loader")

--- Get the singleton plugin registry instance
-- @return PluginRegistry The shared registry instance
function plugin.get_registry()
  return plugin.PluginRegistry.get_instance()
end

--- Initialize the plugin system with configuration
-- @param config table|nil Configuration options
-- @return PluginRegistry The initialized registry
function plugin.initialize(config)
  return plugin.PluginRegistry.initialize(config)
end

--- Shutdown the plugin system
function plugin.shutdown()
  local registry = plugin.PluginRegistry.get_instance()
  registry:destroy_all_plugins()
  plugin.PluginRegistry.reset_instance()
end

return plugin
