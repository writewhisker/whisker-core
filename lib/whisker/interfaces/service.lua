--- Service Interfaces
-- Interface definitions for the service layer
-- @module whisker.interfaces.service
-- @author Whisker Core Team
-- @license MIT

--- IService Interface
-- Base interface that all services must implement
-- Services are long-lived components that manage stateful operations
-- @table IService
local IService = {}

--- Get the service name
-- @return string The unique service identifier
function IService:getName()
  error("IService:getName must be implemented")
end

--- Initialize the service
-- Called when the service is first resolved from the container
-- @param deps table Dependencies injected from the container
function IService:initialize(deps)
  error("IService:initialize must be implemented")
end

--- Check if the service is initialized
-- @return boolean True if the service has been initialized
function IService:isInitialized()
  error("IService:isInitialized must be implemented")
end

--- Destroy the service and release resources
-- Called when the container is destroying services
function IService:destroy()
  error("IService:destroy must be implemented")
end

--- IServiceRegistry Interface
-- Interface for registering and discovering services
-- @table IServiceRegistry
local IServiceRegistry = {}

--- Register a service with the registry
-- @param name string The unique service name
-- @param module_path string The module path for lazy loading
-- @param options table|nil Registration options
-- @param options.singleton boolean Create only one instance (default true)
-- @param options.lazy boolean Lazy load the service (default true)
-- @param options.depends table Array of dependency names
-- @param options.implements string Interface this service implements
-- @param options.metadata table Additional metadata for discovery
function IServiceRegistry:register(name, module_path, options)
  error("IServiceRegistry:register must be implemented")
end

--- Unregister a service
-- @param name string The service name
-- @return boolean True if the service was unregistered
function IServiceRegistry:unregister(name)
  error("IServiceRegistry:unregister must be implemented")
end

--- Check if a service is registered
-- @param name string The service name
-- @return boolean True if the service is registered
function IServiceRegistry:has(name)
  error("IServiceRegistry:has must be implemented")
end

--- Get a service by name
-- @param name string The service name
-- @return table The service instance
function IServiceRegistry:get(name)
  error("IServiceRegistry:get must be implemented")
end

--- Get all registered service names
-- @return table Array of service names
function IServiceRegistry:getNames()
  error("IServiceRegistry:getNames must be implemented")
end

--- Get services by interface
-- @param interface_name string The interface name (e.g., "IState")
-- @return table Array of services implementing the interface
function IServiceRegistry:getByInterface(interface_name)
  error("IServiceRegistry:getByInterface must be implemented")
end

--- Get services by metadata
-- @param key string The metadata key
-- @param value any The value to match (optional, if nil returns all with key)
-- @return table Array of matching services
function IServiceRegistry:getByMetadata(key, value)
  error("IServiceRegistry:getByMetadata must be implemented")
end

--- Discover services from a directory
-- Scans a directory for service modules and registers them
-- @param path string The directory path to scan
-- @param options table|nil Discovery options
-- @return table Array of discovered service names
function IServiceRegistry:discover(path, options)
  error("IServiceRegistry:discover must be implemented")
end

--- IServiceLifecycle Interface
-- Lifecycle hooks for services
-- @table IServiceLifecycle
local IServiceLifecycle = {}

--- Called before the service is initialized
-- @param deps table Dependencies that will be injected
function IServiceLifecycle:onBeforeInit(deps)
  -- Optional hook, default implementation does nothing
end

--- Called after the service is initialized
-- @param deps table Dependencies that were injected
function IServiceLifecycle:onAfterInit(deps)
  -- Optional hook, default implementation does nothing
end

--- Called before the service is destroyed
function IServiceLifecycle:onBeforeDestroy()
  -- Optional hook, default implementation does nothing
end

--- Called after the service is destroyed
function IServiceLifecycle:onAfterDestroy()
  -- Optional hook, default implementation does nothing
end

--- Called when the service is suspended (e.g., app backgrounded)
function IServiceLifecycle:onSuspend()
  -- Optional hook, default implementation does nothing
end

--- Called when the service is resumed (e.g., app foregrounded)
function IServiceLifecycle:onResume()
  -- Optional hook, default implementation does nothing
end

--- Service status constants
-- @table ServiceStatus
local ServiceStatus = {
  UNREGISTERED = "unregistered",
  REGISTERED = "registered",
  INITIALIZING = "initializing",
  READY = "ready",
  SUSPENDED = "suspended",
  DESTROYING = "destroying",
  DESTROYED = "destroyed",
  ERROR = "error"
}

--- Service priority constants for initialization order
-- @table ServicePriority
local ServicePriority = {
  CRITICAL = 0,    -- Core services (events, container)
  HIGH = 100,      -- Foundation services (state, logging)
  NORMAL = 500,    -- Standard services (history, variables)
  LOW = 900,       -- Optional services (analytics, telemetry)
  LAZY = 1000      -- On-demand services (bundlers)
}

return {
  IService = IService,
  IServiceRegistry = IServiceRegistry,
  IServiceLifecycle = IServiceLifecycle,
  ServiceStatus = ServiceStatus,
  ServicePriority = ServicePriority
}
