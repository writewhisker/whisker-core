--- Integration Tests
-- Central module for integration test utilities
-- @module tests.integration
-- @author Whisker Core Team

-- Integration tests are run via busted
-- This file provides shared utilities if needed

local M = {}

--- Create a test story for integration testing
-- @return Story A simple test story
function M.create_test_story()
  local Story = require("whisker.core.story")
  local Passage = require("whisker.core.passage")
  local Choice = require("whisker.core.choice")

  local story = Story.new({ title = "Integration Test Story" })

  local start = Passage.new({ id = "start", name = "Start" })
  start.content = "This is the beginning."
  start:add_choice(Choice.new({ text = "Continue", target = "middle" }))

  local middle = Passage.new({ id = "middle", name = "Middle" })
  middle.content = "This is the middle."
  middle:add_choice(Choice.new({ text = "Finish", target = "end" }))

  local ending = Passage.new({ id = "end", name = "End" })
  ending.content = "The end."

  story:add_passage(start)
  story:add_passage(middle)
  story:add_passage(ending)
  story:set_start_passage("start")

  return story
end

--- Create a branching test story
-- @return Story A story with multiple branches
function M.create_branching_story()
  local Story = require("whisker.core.story")
  local Passage = require("whisker.core.passage")
  local Choice = require("whisker.core.choice")

  local story = Story.new({ title = "Branching Story" })

  local start = Passage.new({ id = "start", name = "Crossroads" })
  start.content = "You stand at a crossroads."
  start:add_choice(Choice.new({ text = "Go left", target = "left" }))
  start:add_choice(Choice.new({ text = "Go right", target = "right" }))

  local left = Passage.new({ id = "left", name = "Left Path" })
  left.content = "You took the left path."
  left:add_choice(Choice.new({ text = "Continue", target = "end" }))

  local right = Passage.new({ id = "right", name = "Right Path" })
  right.content = "You took the right path."
  right:add_choice(Choice.new({ text = "Continue", target = "end" }))

  local ending = Passage.new({ id = "end", name = "Destination" })
  ending.content = "You have arrived."

  story:add_passage(start)
  story:add_passage(left)
  story:add_passage(right)
  story:add_passage(ending)
  story:set_start_passage("start")

  return story
end

return M
