--- Choice Factory
-- Factory implementation for creating Choice instances
-- Implements IChoiceFactory interface
-- @module whisker.core.factories.choice_factory
-- @author Whisker Core Team
-- @license MIT

local Choice = require("whisker.core.choice")

local ChoiceFactory = {}
ChoiceFactory.__index = ChoiceFactory

-- Dependencies for DI pattern (none for ChoiceFactory)
ChoiceFactory._dependencies = {}

--- Create a new ChoiceFactory instance
-- @param deps table|nil Dependencies from container
-- @return ChoiceFactory The factory instance
function ChoiceFactory.new(deps)
  local self = setmetatable({}, ChoiceFactory)
  self._deps = deps or {}
  return self
end

--- Create a new Choice instance
-- Implements IChoiceFactory:create
-- @param options table Choice options (text, target, condition, action, metadata)
-- @return Choice The new choice instance
function ChoiceFactory:create(options)
  return Choice.new(options)
end

--- Create a Choice from serialized data
-- Implements IChoiceFactory:from_table
-- @param data table Serialized choice data
-- @return Choice The restored choice instance
function ChoiceFactory:from_table(data)
  return Choice.from_table(data)
end

--- Restore metatable to a plain table
-- Implements IChoiceFactory:restore_metatable
-- @param data table Plain table with choice data
-- @return Choice The table with Choice metatable restored
function ChoiceFactory:restore_metatable(data)
  return Choice.restore_metatable(data)
end

--- Get the Choice class (for type checking)
-- @return table The Choice class table
function ChoiceFactory:get_class()
  return Choice
end

return ChoiceFactory
