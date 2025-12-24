--- Passage Factory
-- Factory implementation for creating Passage instances
-- Implements IPassageFactory interface
-- @module whisker.core.factories.passage_factory
-- @author Whisker Core Team
-- @license MIT

local Passage = require("whisker.core.passage")

local PassageFactory = {}
PassageFactory.__index = PassageFactory

-- Dependencies for DI pattern
PassageFactory._dependencies = {"choice_factory"}

--- Create a new PassageFactory instance
-- @param deps table Dependencies from container (choice_factory)
-- @return PassageFactory The factory instance
function PassageFactory.new(deps)
  local self = setmetatable({}, PassageFactory)
  self._deps = deps or {}
  self._choice_factory = deps and deps.choice_factory or nil
  return self
end

--- Get the choice factory
-- @return table The choice factory
function PassageFactory:_get_choice_factory()
  if self._choice_factory then
    return self._choice_factory
  end
  -- Lazy load default if not injected
  local ChoiceFactory = require("whisker.core.factories.choice_factory")
  self._choice_factory = ChoiceFactory.new()
  return self._choice_factory
end

--- Create a new Passage instance
-- Implements IPassageFactory:create
-- @param options table Passage options (id, name, content, choices, tags, etc.)
-- @return Passage The new passage instance
function PassageFactory:create(options)
  return Passage.new(options, nil, self:_get_choice_factory())
end

--- Create a Passage from serialized data
-- Implements IPassageFactory:from_table
-- @param data table Serialized passage data
-- @return Passage The restored passage instance
function PassageFactory:from_table(data)
  return Passage.from_table(data, self:_get_choice_factory())
end

--- Restore metatable to a plain table (and nested choices)
-- Implements IPassageFactory:restore_metatable
-- @param data table Plain table with passage data
-- @return Passage The table with Passage metatable restored
function PassageFactory:restore_metatable(data)
  return Passage.restore_metatable(data, self:_get_choice_factory())
end

--- Get the Passage class (for type checking)
-- @return table The Passage class table
function PassageFactory:get_class()
  return Passage
end

--- Get the choice factory used by this factory
-- @return table The choice factory
function PassageFactory:get_choice_factory()
  return self:_get_choice_factory()
end

return PassageFactory
