--- ServiceLoader
-- Registers all core services with the DI container using lazy loading
-- Supports plugin services and dynamic service discovery
-- @module whisker.services
-- @author Whisker Core Team
-- @license MIT

local ServicePriority = require("whisker.interfaces.service").ServicePriority
local ServiceStatus = require("whisker.interfaces.service").ServiceStatus

local ServiceLoader = {}

-- Plugin service registry for external services
ServiceLoader._plugin_services = {}

-- Service status tracking
ServiceLoader._service_status = {}

--- Service manifest defining all available services
-- Each entry contains the module path, options, and metadata for discovery
-- @table SERVICE_MANIFEST
ServiceLoader.SERVICE_MANIFEST = {
  state = {
    module_path = "whisker.services.state",
    options = {
      singleton = true,
      implements = "IState",
      depends = {"events"}
    },
    metadata = {
      priority = ServicePriority.HIGH,
      description = "Core state management service",
      category = "foundation"
    }
  },
  history = {
    module_path = "whisker.services.history",
    options = {
      singleton = true,
      depends = {"events", "state"}
    },
    metadata = {
      priority = ServicePriority.NORMAL,
      description = "Navigation history tracking",
      category = "navigation"
    }
  },
  variables = {
    module_path = "whisker.services.variables",
    options = {
      singleton = true,
      depends = {"state", "events"}
    },
    metadata = {
      priority = ServicePriority.NORMAL,
      description = "Variable management with state integration",
      category = "scripting"
    }
  },
  persistence = {
    module_path = "whisker.services.persistence",
    options = {
      singleton = true,
      depends = {"state", "events"}
    },
    metadata = {
      priority = ServicePriority.NORMAL,
      description = "Save/load game state persistence",
      category = "storage"
    }
  }
}

--- Register all core services with lazy loading
-- Services are not loaded until first resolved
-- @param container Container The DI container
function ServiceLoader.register_all(container)
  for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
    ServiceLoader.register_service(container, name, config)
  end
end

--- Register a single service from the manifest
-- @param container Container The DI container
-- @param name string The service name
-- @param config table The service configuration from manifest
function ServiceLoader.register_service(container, name, config)
  local options = {}
  for k, v in pairs(config.options or {}) do
    options[k] = v
  end

  -- Add metadata to options for discovery
  options.metadata = config.metadata

  -- Use lazy registration
  container:register_lazy(name, config.module_path, options)
end

--- Register only state service (lazy)
-- @param container Container The DI container
function ServiceLoader.register_state(container)
  local config = ServiceLoader.SERVICE_MANIFEST.state
  ServiceLoader.register_service(container, "state", config)
end

--- Register only history service (lazy)
-- @param container Container The DI container
function ServiceLoader.register_history(container)
  local config = ServiceLoader.SERVICE_MANIFEST.history
  ServiceLoader.register_service(container, "history", config)
end

--- Register only variable service (lazy)
-- @param container Container The DI container
function ServiceLoader.register_variables(container)
  local config = ServiceLoader.SERVICE_MANIFEST.variables
  ServiceLoader.register_service(container, "variables", config)
end

--- Register only persistence service (lazy)
-- @param container Container The DI container
function ServiceLoader.register_persistence(container)
  local config = ServiceLoader.SERVICE_MANIFEST.persistence
  ServiceLoader.register_service(container, "persistence", config)
end

--- Get service metadata by name
-- @param name string The service name
-- @return table|nil The service metadata
function ServiceLoader.get_metadata(name)
  local config = ServiceLoader.SERVICE_MANIFEST[name]
  return config and config.metadata
end

--- Get all service names
-- @return table Array of service names
function ServiceLoader.get_names()
  local names = {}
  for name in pairs(ServiceLoader.SERVICE_MANIFEST) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Get services by category
-- @param category string The category to filter by
-- @return table Array of service names in the category
function ServiceLoader.get_by_category(category)
  local names = {}
  for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
    if config.metadata and config.metadata.category == category then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

--- Get services by priority
-- @param priority number The priority level
-- @return table Array of service names with that priority
function ServiceLoader.get_by_priority(priority)
  local names = {}
  for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
    if config.metadata and config.metadata.priority == priority then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

--- Check if a service is in the manifest
-- @param name string The service name
-- @return boolean True if the service is defined in the manifest
function ServiceLoader.has_service(name)
  return ServiceLoader.SERVICE_MANIFEST[name] ~= nil
end

--- Get the module path for a service
-- @param name string The service name
-- @return string|nil The module path, or nil if not found
function ServiceLoader.get_module_path(name)
  local config = ServiceLoader.SERVICE_MANIFEST[name] or ServiceLoader._plugin_services[name]
  return config and config.module_path
end

--- Register a plugin-provided service
-- Allows external plugins to add services to the registry
-- @param name string The unique service name
-- @param config table Service configuration
-- @param config.module_path string The module path for lazy loading
-- @param config.factory function|nil Optional factory function (alternative to module_path)
-- @param config.options table|nil Registration options
-- @param config.metadata table|nil Service metadata for discovery
-- @return boolean success True if registered
function ServiceLoader.register_plugin(name, config)
  -- Validate required fields
  if not name or type(name) ~= "string" then
    error("Plugin service name must be a non-empty string")
  end

  if not config then
    error("Plugin service config is required")
  end

  if not config.module_path and not config.factory then
    error("Plugin service must have module_path or factory")
  end

  -- Check for conflicts with core services
  if ServiceLoader.SERVICE_MANIFEST[name] then
    error("Cannot override core service: " .. name)
  end

  -- Register the plugin service
  ServiceLoader._plugin_services[name] = {
    module_path = config.module_path,
    factory = config.factory,
    options = config.options or {},
    metadata = config.metadata or {
      priority = ServicePriority.LAZY,
      category = "plugin",
      description = config.description or "Plugin-provided service"
    }
  }

  ServiceLoader._service_status[name] = ServiceStatus.REGISTERED

  return true
end

--- Unregister a plugin-provided service
-- @param name string The service name
-- @return boolean success True if unregistered
function ServiceLoader.unregister_plugin(name)
  if ServiceLoader.SERVICE_MANIFEST[name] then
    error("Cannot unregister core service: " .. name)
  end

  if ServiceLoader._plugin_services[name] then
    ServiceLoader._plugin_services[name] = nil
    ServiceLoader._service_status[name] = ServiceStatus.UNREGISTERED
    return true
  end

  return false
end

--- Register a plugin service with a container
-- @param container Container The DI container
-- @param name string The plugin service name
-- @return boolean success True if registered with container
function ServiceLoader.register_plugin_service(container, name)
  local config = ServiceLoader._plugin_services[name]
  if not config then
    return false
  end

  if config.factory then
    -- Use factory function directly
    container:register(name, config.factory, config.options)
  else
    -- Use lazy module loading
    local options = {}
    for k, v in pairs(config.options or {}) do
      options[k] = v
    end
    options.metadata = config.metadata
    container:register_lazy(name, config.module_path, options)
  end

  return true
end

--- Register all plugin services with a container
-- @param container Container The DI container
-- @return number count Number of services registered
function ServiceLoader.register_all_plugins(container)
  local count = 0
  for name in pairs(ServiceLoader._plugin_services) do
    if ServiceLoader.register_plugin_service(container, name) then
      count = count + 1
    end
  end
  return count
end

--- Get all registered plugin service names
-- @return table Array of plugin service names
function ServiceLoader.get_plugin_names()
  local names = {}
  for name in pairs(ServiceLoader._plugin_services) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Check if a service is a plugin service
-- @param name string The service name
-- @return boolean True if it's a plugin service
function ServiceLoader.is_plugin(name)
  return ServiceLoader._plugin_services[name] ~= nil
end

--- Discover services from a directory path pattern
-- Scans for service modules and registers them as plugins
-- @param path_pattern string The Lua module path pattern (e.g., "mygame.services")
-- @param options table|nil Discovery options
-- @param options.category string Default category for discovered services
-- @param options.priority number Default priority for discovered services
-- @param options.filter function Optional filter function(name, module) returning boolean
-- @return table Array of discovered service names
function ServiceLoader.discover(path_pattern, options)
  options = options or {}
  local discovered = {}

  -- Convert module path pattern to filesystem path
  local base_path = path_pattern:gsub("%.", "/")

  -- Try to find service modules that follow the convention
  -- Services should export: name, _dependencies, new/create
  local search_paths = {
    base_path .. "/init.lua",  -- Direct module
  }

  -- Attempt to discover modules from package.path
  for path in package.path:gmatch("[^;]+") do
    local module_pattern = path:gsub("%?", base_path)
    -- Check if module exists and try to load it
    local file = io.open(module_pattern, "r")
    if file then
      file:close()

      -- Try to require the module
      local success, mod = pcall(require, path_pattern)
      if success and type(mod) == "table" then
        -- Check if it looks like a service module
        if mod.new or mod.create or mod._dependencies then
          local name = mod.name or path_pattern:match("([^%.]+)$") or "unknown"

          -- Apply filter if provided
          if not options.filter or options.filter(name, mod) then
            ServiceLoader.register_plugin(name, {
              module_path = path_pattern,
              metadata = {
                priority = options.priority or ServicePriority.LAZY,
                category = options.category or "discovered",
                description = mod.description or "Discovered service",
                discovered = true
              },
              options = {
                singleton = mod.singleton ~= false,
                depends = mod._dependencies
              }
            })

            table.insert(discovered, name)
          end
        end
      end
      break
    end
  end

  return discovered
end

--- Discover services from a list of module paths
-- More explicit discovery than path-based scanning
-- @param modules table Array of module path strings
-- @param options table|nil Discovery options (same as discover)
-- @return table Array of discovered service names
function ServiceLoader.discover_modules(modules, options)
  options = options or {}
  local discovered = {}

  for _, module_path in ipairs(modules) do
    local success, mod = pcall(require, module_path)

    if success and type(mod) == "table" then
      -- Check if it looks like a service module
      if mod.new or mod.create or mod._dependencies then
        local name = mod.name or module_path:match("([^%.]+)$") or "unknown"

        -- Apply filter if provided
        if not options.filter or options.filter(name, mod) then
          ServiceLoader.register_plugin(name, {
            module_path = module_path,
            metadata = {
              priority = options.priority or ServicePriority.LAZY,
              category = options.category or "discovered",
              description = mod.description or "Discovered service",
              discovered = true
            },
            options = {
              singleton = mod.singleton ~= false,
              depends = mod._dependencies
            }
          })

          table.insert(discovered, name)
        end
      end
    end
  end

  return discovered
end

--- Get service status
-- @param name string The service name
-- @return string|nil The status, or nil if not tracked
function ServiceLoader.get_status(name)
  return ServiceLoader._service_status[name]
end

--- Set service status
-- @param name string The service name
-- @param status string The new status
function ServiceLoader.set_status(name, status)
  ServiceLoader._service_status[name] = status
end

--- Get all services (core + plugin)
-- @return table Map of service name to config
function ServiceLoader.get_all_services()
  local all = {}

  -- Add core services
  for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
    all[name] = {
      module_path = config.module_path,
      options = config.options,
      metadata = config.metadata,
      is_core = true,
      is_plugin = false
    }
  end

  -- Add plugin services
  for name, config in pairs(ServiceLoader._plugin_services) do
    all[name] = {
      module_path = config.module_path,
      factory = config.factory,
      options = config.options,
      metadata = config.metadata,
      is_core = false,
      is_plugin = true
    }
  end

  return all
end

--- Get services matching a metadata query
-- @param query table Key-value pairs to match against metadata
-- @return table Array of matching service names
function ServiceLoader.query(query)
  local matches = {}

  for name, service in pairs(ServiceLoader.get_all_services()) do
    local match = true

    for key, value in pairs(query) do
      local meta_value = service.metadata and service.metadata[key]
      if meta_value ~= value then
        match = false
        break
      end
    end

    if match then
      table.insert(matches, name)
    end
  end

  table.sort(matches)
  return matches
end

--- Get services by interface
-- @param interface_name string The interface name (e.g., "IState")
-- @return table Array of service names implementing the interface
function ServiceLoader.get_by_interface(interface_name)
  local matches = {}

  for name, service in pairs(ServiceLoader.get_all_services()) do
    if service.options and service.options.implements == interface_name then
      table.insert(matches, name)
    end
  end

  table.sort(matches)
  return matches
end

--- Clear all plugin services (useful for testing)
function ServiceLoader.clear_plugins()
  ServiceLoader._plugin_services = {}
  ServiceLoader._service_status = {}
end

return ServiceLoader
