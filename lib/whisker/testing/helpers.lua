--- Test Helpers Library
-- Comprehensive testing utilities for Busted framework
--
-- @module whisker.testing.helpers
-- @author Whisker Team
-- @license MIT
-- @usage
-- local helpers = require("whisker.testing.helpers")
-- local story = helpers.story_builder():title("Test"):build()

local helpers = {}

--- Story Builder
-- Fluent API for creating test stories
-- @type StoryBuilder
local StoryBuilder = {}
StoryBuilder.__index = StoryBuilder

--- Create new story builder
-- @return StoryBuilder New builder instance
function helpers.story_builder()
  local self = setmetatable({}, StoryBuilder)
  self.data = {
    id = "test-story-" .. os.time(),
    metadata = {},
    passages = {},
    variables = {},
    tags = {}
  }
  self.passage_map = {}  -- For quick lookup
  return self
end

--- Set story title
-- @param title string Story title
-- @return StoryBuilder self (for chaining)
function StoryBuilder:title(title)
  self.data.metadata.title = title
  return self
end

--- Set story author
-- @param author string Story author
-- @return StoryBuilder self (for chaining)
function StoryBuilder:author(author)
  self.data.metadata.author = author
  return self
end

--- Set story ID
-- @param id string Story ID
-- @return StoryBuilder self (for chaining)
function StoryBuilder:id(id)
  self.data.id = id
  return self
end

--- Add passage to story
-- @param id string Passage ID
-- @param text string Passage text
-- @param options table Optional passage properties
-- @return StoryBuilder self (for chaining)
function StoryBuilder:add_passage(id, text, options)
  options = options or {}
  
  local passage = {
    id = id,
    name = options.name or id,
    text = text or "",
    tags = options.tags or {},
    position = options.position or { x = 0, y = 0 },
    links = {}
  }
  
  table.insert(self.data.passages, passage)
  self.passage_map[id] = passage
  
  return self
end

--- Connect two passages with a choice
-- @param from_id string Source passage ID
-- @param to_id string Target passage ID
-- @param choice_text string Text for the choice
-- @return StoryBuilder self (for chaining)
function StoryBuilder:connect(from_id, to_id, choice_text)
  local passage = self.passage_map[from_id]
  if not passage then
    error(string.format("Passage '%s' not found", from_id))
  end
  
  table.insert(passage.links, {
    target = to_id,
    text = choice_text or to_id
  })
  
  return self
end

--- Add variable to story
-- @param name string Variable name
-- @param value any Variable value
-- @param var_type string Variable type (optional)
-- @return StoryBuilder self (for chaining)
function StoryBuilder:add_variable(name, value, var_type)
  if var_type then
    self.data.variables[name] = {
      type = var_type,
      default = value
    }
  else
    self.data.variables[name] = value
  end
  return self
end

--- Add tag to story
-- @param tag string Tag name
-- @return StoryBuilder self (for chaining)
function StoryBuilder:add_tag(tag)
  table.insert(self.data.tags, tag)
  return self
end

--- Build the story
-- @return table Story data
function StoryBuilder:build()
  return self.data
end

--- Passage Builder
-- Fluent API for creating test passages
-- @type PassageBuilder
local PassageBuilder = {}
PassageBuilder.__index = PassageBuilder

--- Create new passage builder
-- @param id string Passage ID
-- @return PassageBuilder New builder instance
function helpers.passage_builder(id)
  local self = setmetatable({}, PassageBuilder)
  self.data = {
    id = id or ("passage-" .. os.time()),
    name = id or "Unnamed",
    text = "",
    tags = {},
    links = {},
    position = { x = 0, y = 0 }
  }
  return self
end

--- Set passage name
-- @param name string Passage name
-- @return PassageBuilder self
function PassageBuilder:name(name)
  self.data.name = name
  return self
end

--- Set passage text
-- @param text string Passage text
-- @return PassageBuilder self
function PassageBuilder:text(text)
  self.data.text = text
  return self
end

--- Add tag to passage
-- @param tag string Tag name
-- @return PassageBuilder self
function PassageBuilder:add_tag(tag)
  table.insert(self.data.tags, tag)
  return self
end

--- Add link to passage
-- @param target string Target passage ID
-- @param link_text string Link text
-- @return PassageBuilder self
function PassageBuilder:add_link(target, link_text)
  table.insert(self.data.links, {
    target = target,
    text = link_text or target
  })
  return self
end

--- Set passage position
-- @param x number X coordinate
-- @param y number Y coordinate
-- @return PassageBuilder self
function PassageBuilder:position(x, y)
  self.data.position = { x = x, y = y }
  return self
end

--- Build the passage
-- @return table Passage data
function PassageBuilder:build()
  return self.data
end

--- Choice Builder
-- Fluent API for creating test choices
-- @type ChoiceBuilder
local ChoiceBuilder = {}
ChoiceBuilder.__index = ChoiceBuilder

--- Create new choice builder
-- @return ChoiceBuilder New builder instance
function helpers.choice_builder()
  local self = setmetatable({}, ChoiceBuilder)
  self.data = {
    text = "",
    target = "",
    condition = nil,
    effects = {}
  }
  return self
end

--- Set choice text
-- @param text string Choice text
-- @return ChoiceBuilder self
function ChoiceBuilder:text(text)
  self.data.text = text
  return self
end

--- Set choice target
-- @param target string Target passage ID
-- @return ChoiceBuilder self
function ChoiceBuilder:target(target)
  self.data.target = target
  return self
end

--- Set choice condition
-- @param condition string Condition expression
-- @return ChoiceBuilder self
function ChoiceBuilder:condition(condition)
  self.data.condition = condition
  return self
end

--- Add effect to choice
-- @param effect table Effect data
-- @return ChoiceBuilder self
function ChoiceBuilder:add_effect(effect)
  table.insert(self.data.effects, effect)
  return self
end

--- Build the choice
-- @return table Choice data
function ChoiceBuilder:build()
  return self.data
end

--- Assertion Helpers
-- Custom assertions for story testing

--- Assert story is valid
-- @param story table Story data
-- @return boolean valid True if story is valid
-- @usage assert_story_valid(story)
function helpers.assert_story_valid(story)
  assert(story, "Story is nil")
  assert(type(story) == "table", "Story must be a table")
  assert(story.id, "Story missing ID")
  assert(story.passages, "Story missing passages")
  assert(type(story.passages) == "table", "Passages must be a table")
  return true
end

--- Assert passage exists in story
-- @param story table Story data
-- @param passage_id string Passage ID
-- @return boolean exists True if passage exists
function helpers.assert_passage_exists(story, passage_id)
  for _, passage in ipairs(story.passages or {}) do
    if passage.id == passage_id then
      return true
    end
  end
  error(string.format("Passage '%s' not found in story", passage_id))
end

--- Assert choice leads to target passage
-- @param choice table Choice data
-- @param target string Expected target passage ID
-- @return boolean matches True if choice leads to target
function helpers.assert_choice_leads_to(choice, target)
  assert(choice, "Choice is nil")
  assert(choice.target == target, 
    string.format("Choice leads to '%s', expected '%s'", choice.target or "nil", target))
  return true
end

--- Wait for condition (async helper)
-- @param condition function Condition to wait for
-- @param timeout number Timeout in seconds (default: 5)
-- @param interval number Check interval in seconds (default: 0.1)
-- @return boolean success True if condition met
function helpers.wait_for(condition, timeout, interval)
  timeout = timeout or 5
  interval = interval or 0.1
  
  local start_time = os.time()
  
  while os.time() - start_time < timeout do
    if condition() then
      return true
    end
    
    -- Simple sleep implementation
    local sleep_until = os.time() + interval
    while os.time() < sleep_until do
      -- Busy wait (not ideal, but works for testing)
    end
  end
  
  return false
end

--- Expect async operation result
-- @param fn function Async function to call
-- @param expected any Expected result
-- @param timeout number Timeout in seconds
-- @return boolean success True if expectation met
function helpers.expect_async(fn, expected, timeout)
  timeout = timeout or 5
  
  local result = nil
  local completed = false
  
  -- Call function with callback
  fn(function(res)
    result = res
    completed = true
  end)
  
  -- Wait for completion
  local success = helpers.wait_for(function() return completed end, timeout)
  
  if not success then
    error("Async operation timed out")
  end
  
  assert(result == expected, 
    string.format("Expected '%s', got '%s'", tostring(expected), tostring(result)))
  
  return true
end

--- Snapshot Testing
-- Save and compare data snapshots

local snapshot_dir = ".snapshots"

--- Create snapshot
-- @param data table Data to snapshot
-- @param name string Snapshot name
-- @return boolean success
function helpers.create_snapshot(data, name)
  local lfs = require("lfs")
  local json = require("cjson")
  
  -- Create snapshots directory
  lfs.mkdir(snapshot_dir)
  
  -- Save snapshot
  local file_path = snapshot_dir .. "/" .. name .. ".json"
  local file = io.open(file_path, "w")
  
  if not file then
    error("Failed to create snapshot file: " .. file_path)
  end
  
  file:write(json.encode(data))
  file:close()
  
  return true
end

--- Match snapshot
-- @param data table Data to compare
-- @param name string Snapshot name
-- @return boolean matches True if data matches snapshot
function helpers.match_snapshot(data, name)
  local json = require("cjson")
  
  local file_path = snapshot_dir .. "/" .. name .. ".json"
  local file = io.open(file_path, "r")
  
  if not file then
    -- Snapshot doesn't exist, create it
    helpers.create_snapshot(data, name)
    return true
  end
  
  local snapshot_data = json.decode(file:read("*all"))
  file:close()
  
  -- Deep comparison
  local function deep_equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    
    for k, v in pairs(a) do
      if not deep_equal(v, b[k]) then return false end
    end
    
    for k in pairs(b) do
      if a[k] == nil then return false end
    end
    
    return true
  end
  
  if not deep_equal(data, snapshot_data) then
    error(string.format("Snapshot '%s' does not match current data", name))
  end
  
  return true
end

--- Update snapshot
-- @param data table New data
-- @param name string Snapshot name
-- @return boolean success
function helpers.update_snapshot(data, name)
  return helpers.create_snapshot(data, name)
end

--- Mock Helpers
-- Simple mock object creation

--- Create mock function
-- @param return_value any Value to return
-- @return function Mock function
function helpers.mock_fn(return_value)
  local calls = {}
  
  local mock = function(...)
    table.insert(calls, {...})
    return return_value
  end
  
  mock.calls = calls
  mock.call_count = function() return #calls end
  mock.was_called = function() return #calls > 0 end
  mock.was_called_with = function(...)
    local expected = {...}
    for _, call_args in ipairs(calls) do
      local match = true
      for i, arg in ipairs(expected) do
        if call_args[i] ~= arg then
          match = false
          break
        end
      end
      if match then return true end
    end
    return false
  end
  
  return mock
end

--- Create spy on existing function
-- @param obj table Object containing function
-- @param method_name string Method name to spy on
-- @return function Original function (wrapped)
function helpers.spy(obj, method_name)
  local original = obj[method_name]
  local calls = {}
  
  obj[method_name] = function(...)
    table.insert(calls, {...})
    return original(...)
  end
  
  obj[method_name].calls = calls
  obj[method_name].restore = function()
    obj[method_name] = original
  end
  
  return original
end

--- Stub a method
-- @param obj table Object containing method
-- @param method_name string Method name to stub
-- @param return_value any Value to return
-- @return function Original function
function helpers.stub(obj, method_name, return_value)
  local original = obj[method_name]
  
  obj[method_name] = function()
    return return_value
  end
  
  obj[method_name].restore = function()
    obj[method_name] = original
  end
  
  return original
end

--- Test Data Generators
-- Generate realistic test data

--- Generate random string
-- @param length number String length
-- @return string Random string
function helpers.random_string(length)
  length = length or 10
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local result = {}
  
  for i = 1, length do
    local index = math.random(1, #chars)
    result[i] = chars:sub(index, index)
  end
  
  return table.concat(result)
end

--- Generate Lorem Ipsum text
-- @param words number Number of words
-- @return string Lorem Ipsum text
function helpers.lorem_ipsum(words)
  words = words or 50
  local lorem_words = {
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
    "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
    "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud"
  }
  
  local result = {}
  for i = 1, words do
    result[i] = lorem_words[math.random(1, #lorem_words)]
  end
  
  return table.concat(result, " ")
end

return helpers
