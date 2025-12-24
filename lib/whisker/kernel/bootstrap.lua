--- Bootstrap
-- Initializes the whisker-core kernel
-- @module whisker.kernel.bootstrap
-- @author Whisker Core Team
-- @license MIT

-- Ensure microkernel is initialized first
require("whisker.kernel.init")

local Container = require("whisker.kernel.container")
local EventBus = require("whisker.kernel.events")
local Registry = require("whisker.kernel.registry")
local Loader = require("whisker.kernel.loader")

local Bootstrap = {}

--- Create and initialize a new whisker-core instance
-- @param options table|nil Bootstrap options
-- @return table The initialized kernel components
function Bootstrap.create(options)
  options = options or {}

  -- Create container
  local container = Container.new()

  -- Create and register event bus
  local events = EventBus.new()
  container:register("events", events, {singleton = true})
  container:register("event_bus", events, {singleton = true})  -- Alias

  -- Create and register registry
  local registry = Registry.new()
  container:register("registry", registry, {singleton = true})

  -- Create and register loader
  local loader = Loader.new(container, registry)
  container:register("loader", loader, {singleton = true})

  -- Load extensions (services, core, media) with options
  local Extensions = require("whisker.extensions")
  Extensions.load_all(container, events, options)

  -- Emit bootstrap event
  events:emit("kernel:bootstrap", {
    container = container,
    options = options,
  })

  -- Attach to global whisker hooks
  whisker.container = container
  whisker.events = events
  whisker.loader = loader

  return {
    container = container,
    events = events,
    registry = registry,
    loader = loader,
    logger = container:resolve("logger"),
  }
end

--- Initialize whisker-core with default modules
-- @param options table|nil Bootstrap options
-- @return table The initialized kernel with modules loaded
function Bootstrap.init(options)
  local kernel = Bootstrap.create(options)

  -- Emit ready event
  kernel.events:emit("kernel:ready", {
    container = kernel.container,
  })

  return kernel
end

return Bootstrap
