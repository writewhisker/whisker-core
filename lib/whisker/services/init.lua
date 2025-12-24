--- ServiceLoader
-- Registers all core services with the DI container using lazy loading
-- @module whisker.services
-- @author Whisker Core Team
-- @license MIT

local ServicePriority = require("whisker.interfaces.service").ServicePriority

local ServiceLoader = {}

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
  local config = ServiceLoader.SERVICE_MANIFEST[name]
  return config and config.module_path
end

return ServiceLoader
