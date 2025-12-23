--- Hook Types Tests
-- @module tests.unit.plugin.hook_types_spec

describe("HookTypes", function()
  local HookTypes

  before_each(function()
    package.loaded["whisker.plugin.hook_types"] = nil
    HookTypes = require("whisker.plugin.hook_types")
  end)

  describe("MODE constants", function()
    it("defines OBSERVER mode", function()
      assert.equal("observer", HookTypes.MODE.OBSERVER)
    end)

    it("defines TRANSFORM mode", function()
      assert.equal("transform", HookTypes.MODE.TRANSFORM)
    end)
  end)

  describe("hook event constants", function()
    it("defines story lifecycle hooks", function()
      assert.equal("on_story_start", HookTypes.STORY.START)
      assert.equal("on_story_end", HookTypes.STORY.END)
      assert.equal("on_story_reset", HookTypes.STORY.RESET)
    end)

    it("defines passage hooks", function()
      assert.equal("on_passage_enter", HookTypes.PASSAGE.ENTER)
      assert.equal("on_passage_exit", HookTypes.PASSAGE.EXIT)
      assert.equal("on_passage_render", HookTypes.PASSAGE.RENDER)
    end)

    it("defines choice hooks", function()
      assert.equal("on_choice_present", HookTypes.CHOICE.PRESENT)
      assert.equal("on_choice_select", HookTypes.CHOICE.SELECT)
    end)

    it("defines variable hooks", function()
      assert.equal("on_variable_set", HookTypes.VARIABLE.SET)
      assert.equal("on_variable_get", HookTypes.VARIABLE.GET)
      assert.equal("on_state_change", HookTypes.VARIABLE.CHANGE)
    end)

    it("defines persistence hooks", function()
      assert.equal("on_save", HookTypes.PERSISTENCE.SAVE)
      assert.equal("on_load", HookTypes.PERSISTENCE.LOAD)
    end)

    it("defines error hooks", function()
      assert.equal("on_error", HookTypes.ERROR.ERROR)
    end)
  end)

  describe("ALL_EVENTS", function()
    it("contains all hook events", function()
      assert.is_not_nil(HookTypes.ALL_EVENTS["on_story_start"])
      assert.is_not_nil(HookTypes.ALL_EVENTS["on_passage_enter"])
      assert.is_not_nil(HookTypes.ALL_EVENTS["on_save"])
    end)

    it("specifies mode for each event", function()
      for event, info in pairs(HookTypes.ALL_EVENTS) do
        assert.is_not_nil(info.mode, "Event " .. event .. " missing mode")
        assert.is_true(
          info.mode == HookTypes.MODE.OBSERVER or info.mode == HookTypes.MODE.TRANSFORM,
          "Event " .. event .. " has invalid mode"
        )
      end
    end)

    it("specifies category for each event", function()
      for event, info in pairs(HookTypes.ALL_EVENTS) do
        assert.is_not_nil(info.category, "Event " .. event .. " missing category")
        assert.is_string(info.category)
      end
    end)
  end)

  describe("get_all_events()", function()
    it("returns array of event names", function()
      local events = HookTypes.get_all_events()
      assert.is_table(events)
      assert.is_true(#events > 0)
    end)

    it("returns sorted array", function()
      local events = HookTypes.get_all_events()
      for i = 2, #events do
        assert.is_true(events[i-1] < events[i], "Events not sorted")
      end
    end)
  end)

  describe("get_mode()", function()
    it("returns observer for on_story_start", function()
      assert.equal(HookTypes.MODE.OBSERVER, HookTypes.get_mode("on_story_start"))
    end)

    it("returns transform for on_passage_render", function()
      assert.equal(HookTypes.MODE.TRANSFORM, HookTypes.get_mode("on_passage_render"))
    end)

    it("returns transform for on_variable_set", function()
      assert.equal(HookTypes.MODE.TRANSFORM, HookTypes.get_mode("on_variable_set"))
    end)

    it("returns nil for unknown event", function()
      assert.is_nil(HookTypes.get_mode("unknown_event"))
    end)
  end)

  describe("get_category()", function()
    it("returns story for on_story_start", function()
      assert.equal("story", HookTypes.get_category("on_story_start"))
    end)

    it("returns passage for on_passage_enter", function()
      assert.equal("passage", HookTypes.get_category("on_passage_enter"))
    end)

    it("returns nil for unknown event", function()
      assert.is_nil(HookTypes.get_category("unknown_event"))
    end)
  end)

  describe("is_transform_hook()", function()
    it("returns true for transform hooks", function()
      assert.is_true(HookTypes.is_transform_hook("on_passage_render"))
      assert.is_true(HookTypes.is_transform_hook("on_variable_set"))
      assert.is_true(HookTypes.is_transform_hook("on_save"))
    end)

    it("returns false for observer hooks", function()
      assert.is_false(HookTypes.is_transform_hook("on_story_start"))
      assert.is_false(HookTypes.is_transform_hook("on_passage_enter"))
    end)
  end)

  describe("is_observer_hook()", function()
    it("returns true for observer hooks", function()
      assert.is_true(HookTypes.is_observer_hook("on_story_start"))
      assert.is_true(HookTypes.is_observer_hook("on_passage_enter"))
      assert.is_true(HookTypes.is_observer_hook("on_choice_select"))
    end)

    it("returns false for transform hooks", function()
      assert.is_false(HookTypes.is_observer_hook("on_passage_render"))
      assert.is_false(HookTypes.is_observer_hook("on_variable_set"))
    end)
  end)

  describe("is_known_event()", function()
    it("returns true for known events", function()
      assert.is_true(HookTypes.is_known_event("on_story_start"))
      assert.is_true(HookTypes.is_known_event("on_passage_enter"))
      assert.is_true(HookTypes.is_known_event("on_save"))
    end)

    it("returns false for unknown events", function()
      assert.is_false(HookTypes.is_known_event("on_unknown"))
      assert.is_false(HookTypes.is_known_event(""))
      assert.is_false(HookTypes.is_known_event("random"))
    end)
  end)

  describe("get_events_by_category()", function()
    it("returns story events", function()
      local events = HookTypes.get_events_by_category("story")
      assert.is_table(events)
      assert.is_true(#events >= 3)
      for _, event in ipairs(events) do
        assert.equal("story", HookTypes.get_category(event))
      end
    end)

    it("returns passage events", function()
      local events = HookTypes.get_events_by_category("passage")
      assert.is_table(events)
      assert.is_true(#events >= 3)
    end)

    it("returns sorted array", function()
      local events = HookTypes.get_events_by_category("story")
      for i = 2, #events do
        assert.is_true(events[i-1] < events[i])
      end
    end)

    it("returns empty array for unknown category", function()
      local events = HookTypes.get_events_by_category("unknown")
      assert.is_table(events)
      assert.equal(0, #events)
    end)
  end)

  describe("get_categories()", function()
    it("returns all categories", function()
      local categories = HookTypes.get_categories()
      assert.is_table(categories)
      assert.is_true(#categories >= 5)  -- story, passage, choice, variable, persistence, error
    end)

    it("includes expected categories", function()
      local categories = HookTypes.get_categories()
      local has_story = false
      local has_passage = false
      for _, cat in ipairs(categories) do
        if cat == "story" then has_story = true end
        if cat == "passage" then has_passage = true end
      end
      assert.is_true(has_story)
      assert.is_true(has_passage)
    end)

    it("returns sorted array", function()
      local categories = HookTypes.get_categories()
      for i = 2, #categories do
        assert.is_true(categories[i-1] < categories[i])
      end
    end)
  end)
end)
