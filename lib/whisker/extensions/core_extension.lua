--- Core Extension
-- Registers core factories with the container
-- @module whisker.extensions.core_extension
-- @author Whisker Core Team
-- @license MIT

local CoreExtension = {}

--- Register core factories with the container
-- @param container Container The DI container
-- @param events EventBus The event bus instance
function CoreExtension.register(container, events)
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

return CoreExtension
