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

  -- Create and register registry
  local registry = Registry.new()
  container:register("registry", registry, {singleton = true})

  -- Create and register loader
  local loader = Loader.new(container, registry)
  container:register("loader", loader, {singleton = true})

  -- Create logger (simple default)
  local logger = {
    level = options.log_level or "info",
    log = function(self, level, msg)
      if options.debug then
        print(string.format("[%s] %s", level:upper(), msg))
      end
    end,
    info = function(self, msg) self:log("info", msg) end,
    warn = function(self, msg) self:log("warn", msg) end,
    error = function(self, msg) self:log("error", msg) end,
    debug = function(self, msg) self:log("debug", msg) end,
  }
  container:register("logger", logger, {singleton = true})

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
    logger = logger,
  }
end

--- Initialize whisker-core with default modules
-- @param options table|nil Bootstrap options
-- @return table The initialized kernel with modules loaded
function Bootstrap.init(options)
  local kernel = Bootstrap.create(options)

  -- Register core modules in registry
  -- These would be loaded from the actual module files

  -- Emit ready event
  kernel.events:emit("kernel:ready", {
    container = kernel.container,
  })

  return kernel
end

return Bootstrap
