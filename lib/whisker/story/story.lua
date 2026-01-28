-- lib/whisker/story/story.lua
-- Simple Story class for testing

local Story = {}
Story.__index = Story

function Story.new()
  local self = setmetatable({}, Story)
  self.passages = {}
  self.start_passage = nil
  return self
end

function Story:add_passage(passage)
  self.passages[passage.name or passage.id] = passage
end

function Story:get_passage(name)
  return self.passages[name]
end

function Story:get_start_passage()
  if self.start_passage then
    return self.passages[self.start_passage] or self.start_passage
  end
  return self.passages["start"] or self.passages["Start"]
end

function Story:set_start_passage(passage_id)
  self.start_passage = passage_id
end

--- Restore metatable to a plain table
-- @param data table Plain table to restore
-- @return Story Story object with metatable
function Story.restore_metatable(data)
  if not data or type(data) ~= "table" then
    return nil
  end

  -- If already has Story metatable, return as-is
  if getmetatable(data) == Story then
    return data
  end

  -- Set the Story metatable
  setmetatable(data, Story)

  -- Initialize passages if not present
  data.passages = data.passages or {}

  return data
end

--- Create Story from plain table (alias for restore_metatable)
-- @param data table Plain table to convert
-- @return Story Story object
function Story.from_table(data)
  return Story.restore_metatable(data)
end

return Story
