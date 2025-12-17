-- tests/contracts/test_engine.lua
-- Apply IEngine contract to SimpleEngine implementation

local Fixtures = require("tests.support.fixtures")

-- SimpleEngine adapter that implements IEngine interface
-- Works with the simplified fixture format
local SimpleEngine = {}
SimpleEngine.__index = SimpleEngine

function SimpleEngine.new()
  return setmetatable({
    _story = nil,
    _current_passage_id = nil,
    _started = false
  }, SimpleEngine)
end

function SimpleEngine:load(story)
  self._story = story
  self._current_passage_id = nil
  self._started = false
end

function SimpleEngine:start()
  if not self._story then
    error("No story loaded")
  end
  self._current_passage_id = self._story.start
  self._started = true
end

function SimpleEngine:get_current_passage()
  if not self._started or not self._current_passage_id then
    return nil
  end
  return self._story.passages[self._current_passage_id]
end

function SimpleEngine:get_available_choices()
  local passage = self:get_current_passage()
  if not passage then
    return {}
  end
  return passage.choices or {}
end

function SimpleEngine:make_choice(index)
  if type(index) ~= "number" then
    error("Choice index must be a number")
  end

  local choices = self:get_available_choices()

  if index < 1 or index > #choices then
    error("Invalid choice index: " .. tostring(index))
  end

  local choice = choices[index]
  local target = choice.target

  if not self._story.passages[target] then
    error("Target passage not found: " .. tostring(target))
  end

  self._current_passage_id = target
  return self:get_current_passage()
end

function SimpleEngine:can_continue()
  local choices = self:get_available_choices()
  return #choices > 0
end

-- IEngine contract tests
describe("SimpleEngine (IEngine Contract)", function()
  local engine
  local story
  local fixture_name = "simple"

  before_each(function()
    story = Fixtures.load_story(fixture_name)
    engine = SimpleEngine.new()
  end)

  describe("load", function()
    it("should accept a story object", function()
      assert.has_no.errors(function()
        engine:load(story)
      end)
    end)

    it("should be callable multiple times", function()
      engine:load(story)
      assert.has_no.errors(function()
        engine:load(story)
      end)
    end)
  end)

  describe("start", function()
    it("should start the story", function()
      engine:load(story)
      assert.has_no.errors(function()
        engine:start()
      end)
    end)

    it("should position at start passage", function()
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not_nil(passage)
    end)

    it("should error without loaded story", function()
      assert.has_error(function()
        engine:start()
      end)
    end)
  end)

  describe("get_current_passage", function()
    it("should return nil before start", function()
      engine:load(story)
      local passage = engine:get_current_passage()
      assert.is_nil(passage)
    end)

    it("should return current passage after start", function()
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not_nil(passage)
    end)

    it("should return passage with content", function()
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not_nil(passage.content)
    end)
  end)

  describe("get_available_choices", function()
    it("should return a table", function()
      engine:load(story)
      engine:start()
      local choices = engine:get_available_choices()
      assert.is_table(choices)
    end)

    it("should return choices for passage with choices", function()
      engine:load(story)
      engine:start()
      local choices = engine:get_available_choices()
      -- simple.json start passage has 2 choices
      assert.are.equal(2, #choices)
    end)

    it("should return empty table before start", function()
      engine:load(story)
      local choices = engine:get_available_choices()
      assert.are.same({}, choices)
    end)
  end)

  describe("make_choice", function()
    it("should accept valid choice index", function()
      engine:load(story)
      engine:start()

      assert.has_no.errors(function()
        engine:make_choice(1)
      end)
    end)

    it("should advance to new passage", function()
      engine:load(story)
      engine:start()
      local initial_passage = engine:get_current_passage()

      engine:make_choice(1)
      local new_passage = engine:get_current_passage()

      assert.is_not_nil(new_passage)
      assert.are_not.equal(initial_passage.id, new_passage.id)
    end)

    it("should return new passage after choice", function()
      engine:load(story)
      engine:start()

      local result = engine:make_choice(1)
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
    end)

    it("should error on invalid index", function()
      engine:load(story)
      engine:start()

      assert.has_error(function()
        engine:make_choice(999)
      end)
    end)

    it("should error on zero index", function()
      engine:load(story)
      engine:start()

      assert.has_error(function()
        engine:make_choice(0)
      end)
    end)

    it("should error on negative index", function()
      engine:load(story)
      engine:start()

      assert.has_error(function()
        engine:make_choice(-1)
      end)
    end)
  end)

  describe("can_continue", function()
    it("should return boolean", function()
      engine:load(story)
      engine:start()
      local result = engine:can_continue()
      assert.is_boolean(result)
    end)

    it("should return true when choices available", function()
      engine:load(story)
      engine:start()
      assert.is_true(engine:can_continue())
    end)

    it("should return false at ending passage", function()
      engine:load(story)
      engine:start()
      engine:make_choice(1) -- Go to left_path or right_path
      assert.is_false(engine:can_continue())
    end)
  end)

  describe("story progression", function()
    it("should navigate through story", function()
      engine:load(story)
      engine:start()

      -- Start passage
      local p1 = engine:get_current_passage()
      assert.are.equal("start", p1.id)

      -- Make choice
      engine:make_choice(1)
      local p2 = engine:get_current_passage()
      assert.are.equal("left_path", p2.id)
    end)

    it("should allow multiple choices in sequence with complex story", function()
      local complex_story = Fixtures.load_story("complex_branching")
      engine:load(complex_story)
      engine:start()

      local max_moves = 5
      local moves = 0

      while engine:can_continue() and moves < max_moves do
        engine:make_choice(1)
        moves = moves + 1
      end

      assert.is_true(moves > 0, "Should make at least one move")
    end)
  end)
end)
