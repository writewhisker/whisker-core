--- ServiceLoader
-- Registers all core services with the DI container
-- @module whisker.services
-- @author Whisker Core Team
-- @license MIT

local ServiceLoader = {}

--- Register all core services with the container
-- @param container Container The DI container
function ServiceLoader.register_all(container)
  local StateManager = require("whisker.services.state")
  local HistoryService = require("whisker.services.history")
  local VariableService = require("whisker.services.variables")
  local PersistenceService = require("whisker.services.persistence")

  -- Register state manager (singleton, implements IState)
  container:register("state", StateManager, {
    singleton = true,
    implements = "IState",
  })

  -- Register history service (singleton, depends on events)
  container:register("history", HistoryService, {
    singleton = true,
    depends = {"events"},
  })

  -- Register variable service (singleton, depends on state and events)
  container:register("variables", VariableService, {
    singleton = true,
    depends = {"state", "events"},
  })

  -- Register persistence service (singleton, depends on state, serializer, events)
  container:register("persistence", PersistenceService, {
    singleton = true,
    depends = {"state", "events"},
  })
end

--- Register only state service
-- @param container Container The DI container
function ServiceLoader.register_state(container)
  local StateManager = require("whisker.services.state")
  container:register("state", StateManager, {
    singleton = true,
    implements = "IState",
  })
end

--- Register only history service
-- @param container Container The DI container
function ServiceLoader.register_history(container)
  local HistoryService = require("whisker.services.history")
  container:register("history", HistoryService, {
    singleton = true,
    depends = {"events"},
  })
end

--- Register only variable service
-- @param container Container The DI container
function ServiceLoader.register_variables(container)
  local VariableService = require("whisker.services.variables")
  container:register("variables", VariableService, {
    singleton = true,
    depends = {"state", "events"},
  })
end

--- Register only persistence service
-- @param container Container The DI container
function ServiceLoader.register_persistence(container)
  local PersistenceService = require("whisker.services.persistence")
  container:register("persistence", PersistenceService, {
    singleton = true,
    depends = {"state", "events"},
  })
end

return ServiceLoader
