--- Factory Interfaces
-- Interfaces for core object factories (DI pattern)
-- @module whisker.interfaces.factories
-- @author Whisker Core Team
-- @license MIT

local M = {}

--- IChoiceFactory Interface
-- Factory for creating Choice instances
-- @table IChoiceFactory
M.IChoiceFactory = {}

--- Create a new Choice instance
-- @param options table Choice options (text, target, condition, action, metadata)
-- @return Choice The new choice instance
function M.IChoiceFactory:create(options)
  error("IChoiceFactory:create must be implemented")
end

--- Create a Choice from serialized data
-- @param data table Serialized choice data
-- @return Choice The restored choice instance
function M.IChoiceFactory:from_table(data)
  error("IChoiceFactory:from_table must be implemented")
end

--- Restore metatable to a plain table
-- @param data table Plain table with choice data
-- @return Choice The table with Choice metatable restored
function M.IChoiceFactory:restore_metatable(data)
  error("IChoiceFactory:restore_metatable must be implemented")
end


--- IPassageFactory Interface
-- Factory for creating Passage instances
-- @table IPassageFactory
M.IPassageFactory = {}

--- Create a new Passage instance
-- @param options table Passage options (id, name, content, choices, tags, etc.)
-- @return Passage The new passage instance
function M.IPassageFactory:create(options)
  error("IPassageFactory:create must be implemented")
end

--- Create a Passage from serialized data
-- @param data table Serialized passage data
-- @return Passage The restored passage instance
function M.IPassageFactory:from_table(data)
  error("IPassageFactory:from_table must be implemented")
end

--- Restore metatable to a plain table (and nested choices)
-- @param data table Plain table with passage data
-- @return Passage The table with Passage metatable restored
function M.IPassageFactory:restore_metatable(data)
  error("IPassageFactory:restore_metatable must be implemented")
end


--- IStoryFactory Interface
-- Factory for creating Story instances
-- @table IStoryFactory
M.IStoryFactory = {}

--- Create a new Story instance
-- @param options table Story options (title, author, version, passages, etc.)
-- @return Story The new story instance
function M.IStoryFactory:create(options)
  error("IStoryFactory:create must be implemented")
end

--- Create a Story from serialized data
-- @param data table Serialized story data
-- @return Story The restored story instance
function M.IStoryFactory:from_table(data)
  error("IStoryFactory:from_table must be implemented")
end

--- Restore metatable to a plain table (and nested passages/choices)
-- @param data table Plain table with story data
-- @return Story The table with Story metatable restored
function M.IStoryFactory:restore_metatable(data)
  error("IStoryFactory:restore_metatable must be implemented")
end


--- IGameStateFactory Interface
-- Factory for creating GameState instances
-- @table IGameStateFactory
M.IGameStateFactory = {}

--- Create a new GameState instance
-- @param options table|nil GameState options
-- @return GameState The new game state instance
function M.IGameStateFactory:create(options)
  error("IGameStateFactory:create must be implemented")
end


--- ILuaInterpreterFactory Interface
-- Factory for creating LuaInterpreter instances
-- @table ILuaInterpreterFactory
M.ILuaInterpreterFactory = {}

--- Create a new LuaInterpreter instance
-- @param config table|nil Interpreter configuration
-- @return LuaInterpreter The new interpreter instance
function M.ILuaInterpreterFactory:create(config)
  error("ILuaInterpreterFactory:create must be implemented")
end


--- IEngineFactory Interface
-- Factory for creating Engine instances
-- @table IEngineFactory
M.IEngineFactory = {}

--- Create a new Engine instance
-- @param story Story The story to run
-- @param game_state GameState|nil Optional game state
-- @param config table|nil Engine configuration
-- @return Engine The new engine instance
function M.IEngineFactory:create(story, game_state, config)
  error("IEngineFactory:create must be implemented")
end


return M
