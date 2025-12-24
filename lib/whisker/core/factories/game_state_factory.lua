--- GameState Factory
-- Factory implementation for creating GameState instances
-- Implements IGameStateFactory interface
-- @module whisker.core.factories.game_state_factory
-- @author Whisker Core Team
-- @license MIT

local GameState = require("whisker.core.game_state")

local GameStateFactory = {}
GameStateFactory.__index = GameStateFactory

-- Dependencies for DI pattern (none for GameStateFactory)
GameStateFactory._dependencies = {}

--- Create a new GameStateFactory instance
-- @param deps table|nil Dependencies from container
-- @return GameStateFactory The factory instance
function GameStateFactory.new(deps)
  local self = setmetatable({}, GameStateFactory)
  self._deps = deps or {}
  return self
end

--- Create a new GameState instance
-- Implements IGameStateFactory:create
-- @param options table|nil GameState options
-- @return GameState The new game state instance
function GameStateFactory:create(options)
  local game_state = GameState.new()
  if options then
    -- Apply any options (e.g., max_history)
    if options.max_history then
      game_state.max_history = options.max_history
    end
  end
  return game_state
end

--- Get the GameState class (for type checking)
-- @return table The GameState class table
function GameStateFactory:get_class()
  return GameState
end

return GameStateFactory
