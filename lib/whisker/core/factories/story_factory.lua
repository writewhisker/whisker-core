--- Story Factory
-- Factory implementation for creating Story instances
-- Implements IStoryFactory interface
-- @module whisker.core.factories.story_factory
-- @author Whisker Core Team
-- @license MIT

local Story = require("whisker.core.story")

local StoryFactory = {}
StoryFactory.__index = StoryFactory

-- Dependencies for DI pattern
StoryFactory._dependencies = {"passage_factory", "event_bus"}

--- Create a new StoryFactory instance
-- @param deps table Dependencies from container (passage_factory, event_bus)
-- @return StoryFactory The factory instance
function StoryFactory.new(deps)
  local self = setmetatable({}, StoryFactory)
  self._deps = deps or {}
  self._passage_factory = deps and deps.passage_factory or nil
  self._event_bus = deps and deps.event_bus or nil
  return self
end

--- Get the passage factory
-- @return table The passage factory
function StoryFactory:_get_passage_factory()
  if self._passage_factory then
    return self._passage_factory
  end
  -- Lazy load default if not injected
  local PassageFactory = require("whisker.core.factories.passage_factory")
  self._passage_factory = PassageFactory.new()
  return self._passage_factory
end

--- Create a new Story instance
-- Implements IStoryFactory:create
-- @param options table Story options (title, author, version, passages, etc.)
-- @return Story The new story instance
function StoryFactory:create(options)
  return Story.new(options, self:_get_passage_factory(), self._event_bus)
end

--- Create a Story from serialized data
-- Implements IStoryFactory:from_table
-- @param data table Serialized story data
-- @return Story The restored story instance
function StoryFactory:from_table(data)
  return Story.from_table(data, self:_get_passage_factory())
end

--- Restore metatable to a plain table (and nested passages/choices)
-- Implements IStoryFactory:restore_metatable
-- @param data table Plain table with story data
-- @return Story The table with Story metatable restored
function StoryFactory:restore_metatable(data)
  return Story.restore_metatable(data, self:_get_passage_factory())
end

--- Get the Story class (for type checking)
-- @return table The Story class table
function StoryFactory:get_class()
  return Story
end

--- Get the passage factory used by this factory
-- @return table The passage factory
function StoryFactory:get_passage_factory()
  return self:_get_passage_factory()
end

return StoryFactory
