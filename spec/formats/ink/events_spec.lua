-- spec/formats/ink/events_spec.lua
-- Tests for InkEvents definitions and utilities

describe("InkEvents", function()
  local InkEvents

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.events") then
        package.loaded[k] = nil
      end
    end

    InkEvents = require("whisker.formats.ink.events")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkEvents._whisker)
      assert.are.equal("InkEvents", InkEvents._whisker.name)
    end)

    it("should have version", function()
      assert.is_string(InkEvents._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.events", InkEvents._whisker.capability)
    end)
  end)

  describe("event names", function()
    it("should define STORY_LOADED", function()
      assert.are.equal("ink.story.loaded", InkEvents.STORY_LOADED)
    end)

    it("should define STORY_STARTED", function()
      assert.are.equal("ink.engine.started", InkEvents.STORY_STARTED)
    end)

    it("should define STORY_CONTINUED", function()
      assert.are.equal("ink.engine.continued", InkEvents.STORY_CONTINUED)
    end)

    it("should define STORY_ENDED", function()
      assert.are.equal("ink.story.ended", InkEvents.STORY_ENDED)
    end)

    it("should define CHOICE_MADE", function()
      assert.are.equal("ink.choice.made", InkEvents.CHOICE_MADE)
    end)

    it("should define VARIABLE_CHANGED", function()
      assert.are.equal("ink.variable.changed", InkEvents.VARIABLE_CHANGED)
    end)

    it("should define STATE_RESTORED", function()
      assert.are.equal("ink.state.restored", InkEvents.STATE_RESTORED)
    end)

    it("should define EXTERNAL_CALLED", function()
      assert.are.equal("ink.external.called", InkEvents.EXTERNAL_CALLED)
    end)

    it("should define ERROR", function()
      assert.are.equal("ink.error", InkEvents.ERROR)
    end)
  end)

  describe("ALL events list", function()
    it("should contain all event names", function()
      assert.is_table(InkEvents.ALL)
      assert.are.equal(9, #InkEvents.ALL)
    end)

    it("should include each defined event", function()
      local all_set = {}
      for _, name in ipairs(InkEvents.ALL) do
        all_set[name] = true
      end

      assert.is_true(all_set[InkEvents.STORY_LOADED])
      assert.is_true(all_set[InkEvents.STORY_STARTED])
      assert.is_true(all_set[InkEvents.STORY_CONTINUED])
      assert.is_true(all_set[InkEvents.STORY_ENDED])
      assert.is_true(all_set[InkEvents.CHOICE_MADE])
      assert.is_true(all_set[InkEvents.VARIABLE_CHANGED])
      assert.is_true(all_set[InkEvents.STATE_RESTORED])
      assert.is_true(all_set[InkEvents.EXTERNAL_CALLED])
      assert.is_true(all_set[InkEvents.ERROR])
    end)
  end)

  describe("payload builders", function()
    describe("story_loaded", function()
      it("should create payload with ink_version", function()
        local payload = InkEvents.story_loaded(21)
        assert.are.equal(InkEvents.STORY_LOADED, payload.event)
        assert.are.equal(21, payload.ink_version)
      end)

      it("should include story when provided", function()
        local mock_story = { id = "test" }
        local payload = InkEvents.story_loaded(21, mock_story)
        assert.are.equal(mock_story, payload.story)
      end)
    end)

    describe("story_started", function()
      it("should create payload", function()
        local payload = InkEvents.story_started()
        assert.are.equal(InkEvents.STORY_STARTED, payload.event)
      end)

      it("should include engine when provided", function()
        local mock_engine = { id = "test" }
        local payload = InkEvents.story_started(mock_engine)
        assert.are.equal(mock_engine, payload.engine)
      end)
    end)

    describe("story_continued", function()
      it("should create payload with text and tags", function()
        local payload = InkEvents.story_continued("Hello", {"tag1"}, true)
        assert.are.equal(InkEvents.STORY_CONTINUED, payload.event)
        assert.are.equal("Hello", payload.text)
        assert.are.same({"tag1"}, payload.tags)
        assert.is_true(payload.can_continue)
      end)

      it("should default tags to empty array", function()
        local payload = InkEvents.story_continued("Hello", nil, false)
        assert.are.same({}, payload.tags)
      end)
    end)

    describe("story_ended", function()
      it("should create payload with final text", function()
        local payload = InkEvents.story_ended("The End")
        assert.are.equal(InkEvents.STORY_ENDED, payload.event)
        assert.are.equal("The End", payload.text)
      end)
    end)

    describe("choice_made", function()
      it("should create payload with choice info", function()
        local payload = InkEvents.choice_made(1, "Go north", "start.choice1")
        assert.are.equal(InkEvents.CHOICE_MADE, payload.event)
        assert.are.equal(1, payload.index)
        assert.are.equal("Go north", payload.text)
        assert.are.equal("start.choice1", payload.path)
      end)

      it("should allow nil path", function()
        local payload = InkEvents.choice_made(2, "Go south")
        assert.is_nil(payload.path)
      end)
    end)

    describe("variable_changed", function()
      it("should create payload with variable info", function()
        local payload = InkEvents.variable_changed("health", 100, 80)
        assert.are.equal(InkEvents.VARIABLE_CHANGED, payload.event)
        assert.are.equal("health", payload.key)
        assert.are.equal(100, payload.old_value)
        assert.are.equal(80, payload.new_value)
      end)

      it("should handle nil values", function()
        local payload = InkEvents.variable_changed("new_var", nil, 50)
        assert.is_nil(payload.old_value)
        assert.are.equal(50, payload.new_value)
      end)
    end)

    describe("state_restored", function()
      it("should create payload", function()
        local payload = InkEvents.state_restored()
        assert.are.equal(InkEvents.STATE_RESTORED, payload.event)
      end)
    end)

    describe("external_called", function()
      it("should create payload with function info", function()
        local payload = InkEvents.external_called("add", {1, 2}, 3)
        assert.are.equal(InkEvents.EXTERNAL_CALLED, payload.event)
        assert.are.equal("add", payload.name)
        assert.are.same({1, 2}, payload.args)
        assert.are.equal(3, payload.result)
      end)

      it("should default args to empty array", function()
        local payload = InkEvents.external_called("get_time", nil, 12345)
        assert.are.same({}, payload.args)
      end)
    end)

    describe("error", function()
      it("should create payload with error info", function()
        local payload = InkEvents.error("Something failed", "parser")
        assert.are.equal(InkEvents.ERROR, payload.event)
        assert.are.equal("Something failed", payload.message)
        assert.are.equal("parser", payload.source)
      end)

      it("should allow nil source", function()
        local payload = InkEvents.error("Unknown error")
        assert.is_nil(payload.source)
      end)
    end)
  end)

  describe("is_ink_event", function()
    it("should return true for valid Ink events", function()
      assert.is_true(InkEvents.is_ink_event("ink.story.loaded"))
      assert.is_true(InkEvents.is_ink_event("ink.engine.started"))
      assert.is_true(InkEvents.is_ink_event("ink.choice.made"))
    end)

    it("should return false for non-Ink events", function()
      assert.is_false(InkEvents.is_ink_event("unknown.event"))
      assert.is_false(InkEvents.is_ink_event("twine.story.loaded"))
      assert.is_false(InkEvents.is_ink_event(""))
    end)
  end)

  describe("get_namespace", function()
    it("should return ink namespace", function()
      assert.are.equal("ink", InkEvents.get_namespace())
    end)
  end)
end)
