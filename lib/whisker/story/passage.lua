-- lib/whisker/story/passage.lua
-- Simple Passage class for testing

local Passage = {}
Passage.__index = Passage

function Passage.new(id, content)
  local self = setmetatable({}, Passage)
  self.id = id
  self.name = id
  self.content = content
  self.choices = {}
  return self
end

function Passage:get_content()
  return self.content
end

function Passage:get_choices()
  return self.choices
end

function Passage:add_choice(choice)
  table.insert(self.choices, choice)
end

return Passage
