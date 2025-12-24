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

--- Register core factories with lazy loading
-- @param container Container The DI container
-- @param events EventBus The event bus instance
local function register_core_factories(container, events)
  -- Register choice_factory (leaf - no dependencies)
  container:register_lazy("choice_factory", "whisker.core.factories.choice_factory", {
    singleton = true,
    implements = "IChoiceFactory"
  })

  -- Register passage_factory (depends on choice_factory)
  container:register("passage_factory", function(c)
    local PassageFactory = require("whisker.core.factories.passage_factory")
    return PassageFactory.new({
      choice_factory = c:resolve("choice_factory")
    })
  end, {
    singleton = true,
    implements = "IPassageFactory",
    depends = {"choice_factory"}
  })

  -- Register story_factory (depends on passage_factory)
  container:register("story_factory", function(c)
    local StoryFactory = require("whisker.core.factories.story_factory")
    return StoryFactory.new({
      passage_factory = c:resolve("passage_factory"),
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IStoryFactory",
    depends = {"passage_factory", "events"}
  })

  -- Register game_state_factory (leaf - no dependencies)
  container:register_lazy("game_state_factory", "whisker.core.factories.game_state_factory", {
    singleton = true,
    implements = "IGameStateFactory"
  })

  -- Register lua_interpreter_factory (leaf - no dependencies)
  container:register_lazy("lua_interpreter_factory", "whisker.core.factories.lua_interpreter_factory", {
    singleton = true,
    implements = "ILuaInterpreterFactory"
  })

  -- Register engine_factory (depends on all other factories)
  container:register("engine_factory", function(c)
    -- Return a factory function that creates engines
    return {
      create = function(self, story, game_state, config)
        local Engine = require("whisker.core.engine")
        return Engine.new(story, game_state, config, {
          story_factory = c:resolve("story_factory"),
          game_state_factory = c:resolve("game_state_factory"),
          lua_interpreter_factory = c:resolve("lua_interpreter_factory"),
          event_bus = c:resolve("events")
        })
      end
    }
  end, {
    singleton = true,
    implements = "IEngineFactory",
    depends = {"story_factory", "game_state_factory", "lua_interpreter_factory", "events"}
  })
end

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

  -- Register core factories (lazy-loaded)
  register_core_factories(container, events)

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
