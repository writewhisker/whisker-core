-- whisker/interfaces/plugin.lua
-- IPlugin interface definition
-- Plugins must implement this interface

local IPlugin = {
  _name = "IPlugin",
  _description = "Plugin contract for extending whisker functionality",
  _required = {"name", "version", "init"},
  _optional = {"description", "dependencies", "destroy"},

  -- Plugin name (unique identifier)
  -- @type string
  name = "string",

  -- Plugin version (semantic versioning)
  -- @type string
  version = "string",

  -- Initialize the plugin
  -- @param container Container - DI container for registering services
  init = "function(self, container)",

  -- Clean up plugin resources (optional)
  destroy = "function(self)",

  -- Plugin dependencies (optional)
  -- @type table - Array of plugin names this plugin depends on
  dependencies = "table",
}

return IPlugin
