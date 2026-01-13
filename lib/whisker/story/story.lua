-- lib/whisker/story/story.lua
-- Simple Story class for testing

local Story = {}
Story.__index = Story

function Story.new()
  local self = setmetatable({}, Story)
  self.passages = {}
  return self
end

function Story:add_passage(passage)
  self.passages[passage.name] = passage
end

function Story:get_passage(name)
  return self.passages[name]
end

return Story
