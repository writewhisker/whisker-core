-- spec/engines/default_spec.lua
-- Unit tests for DefaultEngine

describe("DefaultEngine", function()
  local DefaultEngine
  local Fixtures

  -- Create a simple story for testing
  local function create_test_story()
    return {
      start_passage = "start",
      passages = {
        start = {
          id = "start",
          name = "Start",
          content = "Welcome!",
          choices = {
            {id = "c1", text = "Go left", target = "left"},
            {id = "c2", text = "Go right", target = "right"}
          },
          get_choices = function(self) return self.choices end
        },
        left = {
          id = "left",
          name = "Left Path",
          content = "You went left.",
          choices = {},
          get_choices = function(self) return self.choices end
        },
        right = {
          id = "right",
          name = "Right Path",
          content = "You went right.",
          choices = {
            {id = "c3", text = "Continue", target = "end_passage"}
          },
          get_choices = function(self) return self.choices end
        },
        end_passage = {
          id = "end_passage",
          name = "The End",
          content = "The end.",
          choices = {},
          get_choices = function(self) return self.choices end
        }
      },
      get_passage = function(self, id)
        return self.passages[id]
      end,
      get_start_passage = function(self)
        return self.start_passage
      end
    }
  end

  before_each(function()
    package.loaded["whisker.engines.default"] = nil
    DefaultEngine = require("whisker.engines.default")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(DefaultEngine._whisker)
      assert.are.equal("DefaultEngine", DefaultEngine._whisker.name)
      assert.is_string(DefaultEngine._whisker.version)
      assert.are.equal("IEngine", DefaultEngine._whisker.implements)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #DefaultEngine._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with default values", function()
      local e = DefaultEngine.new()
      assert.is_nil(e._story)
      assert.is_nil(e._current_passage)
      assert.is_false(e._is_running)
    end)

    it("should accept injected services", function()
      local state = {}
      local e = DefaultEngine.new({state = state})
      assert.are.equal(state, e._state)
    end)
  end)

  describe("load", function()
    it("should accept a story object", function()
      local e = DefaultEngine.new()
      local story = create_test_story()
      assert.has_no.errors(function()
        e:load(story)
      end)
      assert.are.equal(story, e._story)
    end)

    it("should reset engine state", function()
      local e = DefaultEngine.new()
      e._is_running = true
      e:load(create_test_story())
      assert.is_false(e._is_running)
    end)

    it("should emit story_loaded event", function()
      local e = DefaultEngine.new()
      local emitted = nil
      e:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      e:load(create_test_story())
      assert.are.equal("engine:story_loaded", emitted.event)
    end)
  end)

  describe("start", function()
    it("should error without loaded story", function()
      local e = DefaultEngine.new()
      assert.has_error(function()
        e:start()
      end)
    end)

    it("should start the story", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      assert.has_no.errors(function()
        e:start()
      end)
      assert.is_true(e._is_running)
    end)

    it("should position at start passage", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      local passage = e:get_current_passage()
      assert.is_not_nil(passage)
      assert.are.equal("start", passage.id)
    end)

    it("should emit started event", function()
      local e = DefaultEngine.new()
      local emitted = nil
      e:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      e:load(create_test_story())
      e:start()
      assert.are.equal("passage:entered", emitted.event) -- Last event
    end)
  end)

  describe("get_current_passage", function()
    it("should return nil before start", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      assert.is_nil(e:get_current_passage())
    end)

    it("should return current passage after start", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      local passage = e:get_current_passage()
      assert.is_not_nil(passage)
    end)
  end)

  describe("get_available_choices", function()
    it("should return a table", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      local choices = e:get_available_choices()
      assert.is_table(choices)
    end)

    it("should return choices for start passage", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      local choices = e:get_available_choices()
      assert.are.equal(2, #choices)
    end)

    it("should return empty for ending passage", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      e:make_choice(1) -- Go left (ending)
      local choices = e:get_available_choices()
      assert.are.equal(0, #choices)
    end)
  end)

  describe("make_choice", function()
    it("should accept valid choice index", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.has_no.errors(function()
        e:make_choice(1)
      end)
    end)

    it("should advance to new passage", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      e:make_choice(1)
      local passage = e:get_current_passage()
      assert.are.equal("left", passage.id)
    end)

    it("should error on invalid index", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.has_error(function()
        e:make_choice(999)
      end)
    end)

    it("should error on zero index", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.has_error(function()
        e:make_choice(0)
      end)
    end)

    it("should error on negative index", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.has_error(function()
        e:make_choice(-1)
      end)
    end)

    it("should emit choice:made event", function()
      local e = DefaultEngine.new()
      local emitted = nil
      e:set_event_emitter({
        emit = function(_, event, data)
          if event == "choice:made" then
            emitted = {event = event, data = data}
          end
        end
      })
      e:load(create_test_story())
      e:start()
      e:make_choice(1)
      assert.are.equal("choice:made", emitted.event)
      assert.are.equal(1, emitted.data.index)
    end)
  end)

  describe("can_continue", function()
    it("should return boolean", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.is_boolean(e:can_continue())
    end)

    it("should return true when choices available", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      assert.is_true(e:can_continue())
    end)

    it("should return false at ending passage", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      e:make_choice(1) -- Go left (ending)
      assert.is_false(e:can_continue())
    end)

    it("should return false before start", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      assert.is_false(e:can_continue())
    end)
  end)

  describe("reset", function()
    it("should clear engine state", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()
      e:reset()
      assert.is_nil(e:get_current_passage())
      assert.is_false(e._is_running)
    end)

    it("should clear state service if set", function()
      local state_cleared = false
      local state_values = {}
      local state = {
        get = function(_, key) return state_values[key] end,
        set = function(_, key, value) state_values[key] = value end,
        clear = function() state_cleared = true; state_values = {} end
      }
      local e = DefaultEngine.new({state = state})
      e:load(create_test_story())
      e:start()
      e:reset()
      assert.is_true(state_cleared)
    end)
  end)

  describe("dependency injection", function()
    it("should use injected state", function()
      local state_values = {}
      local state = {
        get = function(_, key) return state_values[key] end,
        set = function(_, key, value) state_values[key] = value end,
        clear = function() state_values = {} end
      }
      local e = DefaultEngine.new({state = state})
      e:load(create_test_story())
      e:start()
      assert.are.equal("start", state_values._current_passage)
    end)

    it("should use injected condition evaluator", function()
      local condition_checked = false
      local evaluator = {
        evaluate = function(_, condition, context)
          condition_checked = true
          return true
        end
      }
      -- Create story with conditional choice
      local story = create_test_story()
      story.passages.start.choices[1].condition = "has_key"
      story.passages.start.choices[1].get_condition = function(self)
        return self.condition
      end

      local e = DefaultEngine.new({condition_evaluator = evaluator})
      e:load(story)
      e:start()
      assert.is_true(condition_checked)
    end)
  end)

  describe("story progression", function()
    it("should allow multiple choices in sequence", function()
      local e = DefaultEngine.new()
      e:load(create_test_story())
      e:start()

      -- Go right
      e:make_choice(2)
      assert.are.equal("right", e:get_current_passage().id)

      -- Continue to end
      e:make_choice(1)
      assert.are.equal("end_passage", e:get_current_passage().id)
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.engines.default"] = nil
      local ok, result = pcall(require, "whisker.engines.default")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)

-- Contract tests - inline from engine_contract.lua
describe("DefaultEngine Contract Tests", function()
  local DefaultEngine = require("whisker.engines.default")
  local Fixtures = require("tests.support.fixtures")
  local engine
  local story

  before_each(function()
    story = Fixtures.load_story("simple")
    engine = DefaultEngine.new()
  end)

  describe("load", function()
    it("should accept a story object", function()
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
  end)

  describe("get_current_passage", function()
    it("should return current passage after start", function()
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not_nil(passage)
    end)
  end)

  describe("get_available_choices", function()
    it("should return a table", function()
      engine:load(story)
      engine:start()
      local choices = engine:get_available_choices()
      assert.is_table(choices)
    end)
  end)

  describe("make_choice", function()
    it("should accept valid choice index", function()
      engine:load(story)
      engine:start()
      local choices = engine:get_available_choices()
      if #choices > 0 then
        assert.has_no.errors(function()
          engine:make_choice(1)
        end)
      end
    end)

    it("should error on invalid index", function()
      engine:load(story)
      engine:start()
      assert.has_error(function()
        engine:make_choice(999)
      end)
    end)
  end)

  describe("can_continue", function()
    it("should return boolean", function()
      engine:load(story)
      engine:start()
      assert.is_boolean(engine:can_continue())
    end)
  end)
end)
