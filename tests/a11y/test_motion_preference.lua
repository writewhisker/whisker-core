--- Motion Preference Tests
-- Tests for MotionPreference implementation
-- @module tests.a11y.motion_preference_spec

describe("MotionPreference", function()
  local MotionPreference
  local pref
  local mock_event_bus
  local mock_logger

  setup(function()
    MotionPreference = require("whisker.a11y.motion_preference")
  end)

  before_each(function()
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end,
    }

    mock_logger = {
      debug = function() end,
    }

    pref = MotionPreference.new({
      event_bus = mock_event_bus,
      logger = mock_logger,
    })
  end)

  describe("new()", function()
    it("should create a preference instance", function()
      assert.is_not_nil(pref)
      assert.is_table(pref)
    end)

    it("should default to reduced motion disabled", function()
      assert.is_false(pref:is_reduced_motion())
    end)
  end)

  describe("is_reduced_motion()", function()
    it("should return false by default", function()
      assert.is_false(pref:is_reduced_motion())
    end)

    it("should return user override if set", function()
      pref:enable_reduced_motion()
      assert.is_true(pref:is_reduced_motion())
    end)
  end)

  describe("set_system_preference()", function()
    it("should update system preference", function()
      pref:set_system_preference(true)
      assert.is_true(pref:is_reduced_motion())
    end)

    it("should emit event when no user override", function()
      pref:set_system_preference(true)

      assert.equals(1, #mock_event_bus.events)
      assert.equals("a11y.motion_preference_changed", mock_event_bus.events[1].event)
      assert.equals("system", mock_event_bus.events[1].data.source)
    end)

    it("should not emit event when user override exists", function()
      pref:enable_reduced_motion()
      mock_event_bus.events = {}

      pref:set_system_preference(false)

      -- Should still be true due to user override
      assert.is_true(pref:is_reduced_motion())
      -- Should not emit event for system change when user overrode
      assert.equals(0, #mock_event_bus.events)
    end)
  end)

  describe("enable_reduced_motion()", function()
    it("should enable reduced motion", function()
      pref:enable_reduced_motion()
      assert.is_true(pref:is_reduced_motion())
    end)

    it("should emit event", function()
      pref:enable_reduced_motion()

      assert.equals("a11y.motion_preference_changed", mock_event_bus.events[1].event)
      assert.is_true(mock_event_bus.events[1].data.reduced_motion)
      assert.equals("user", mock_event_bus.events[1].data.source)
    end)
  end)

  describe("disable_reduced_motion()", function()
    it("should disable reduced motion", function()
      pref:enable_reduced_motion()
      pref:disable_reduced_motion()
      assert.is_false(pref:is_reduced_motion())
    end)

    it("should override system preference", function()
      pref:set_system_preference(true)
      pref:disable_reduced_motion()
      assert.is_false(pref:is_reduced_motion())
    end)
  end)

  describe("reset_to_system()", function()
    it("should clear user override", function()
      pref:set_system_preference(true)
      pref:disable_reduced_motion()
      assert.is_false(pref:is_reduced_motion())

      pref:reset_to_system()
      assert.is_true(pref:is_reduced_motion())
    end)
  end)

  describe("toggle()", function()
    it("should toggle preference on", function()
      pref:toggle()
      assert.is_true(pref:is_reduced_motion())
    end)

    it("should toggle preference off", function()
      pref:enable_reduced_motion()
      pref:toggle()
      assert.is_false(pref:is_reduced_motion())
    end)
  end)

  describe("get_animation_duration()", function()
    it("should return normal duration when motion allowed", function()
      local duration = pref:get_animation_duration(300, 10)
      assert.equals(300, duration)
    end)

    it("should return reduced duration when motion reduced", function()
      pref:enable_reduced_motion()
      local duration = pref:get_animation_duration(300, 10)
      assert.equals(10, duration)
    end)

    it("should default reduced duration to 1", function()
      pref:enable_reduced_motion()
      local duration = pref:get_animation_duration(300)
      assert.equals(1, duration)
    end)
  end)

  describe("should_animate()", function()
    it("should return true when motion allowed", function()
      assert.is_true(pref:should_animate(false))
    end)

    it("should return false for non-essential when reduced", function()
      pref:enable_reduced_motion()
      assert.is_false(pref:should_animate(false))
    end)

    it("should return true for essential animations always", function()
      pref:enable_reduced_motion()
      assert.is_true(pref:should_animate(true))
    end)
  end)

  describe("get_css()", function()
    it("should return CSS with media query", function()
      local css = pref:get_css()
      assert.truthy(css:match("prefers%-reduced%-motion: reduce"))
    end)

    it("should include data attribute selector", function()
      local css = pref:get_css()
      assert.truthy(css:match('data%-reduced%-motion="true"'))
    end)
  end)

  describe("get_detection_js()", function()
    it("should return JavaScript code", function()
      local js = pref:get_detection_js()
      assert.truthy(js:match("matchMedia"))
      assert.truthy(js:match("prefers%-reduced%-motion"))
    end)
  end)

  describe("get_source()", function()
    it("should return system by default", function()
      assert.equals("system", pref:get_source())
    end)

    it("should return user when user overrides", function()
      pref:enable_reduced_motion()
      assert.equals("user", pref:get_source())
    end)
  end)

  describe("serialize() / deserialize()", function()
    it("should serialize preference state", function()
      pref:enable_reduced_motion()
      local data = pref:serialize()

      assert.is_true(data.user_override)
    end)

    it("should deserialize preference state", function()
      local new_pref = MotionPreference.new({})
      new_pref:deserialize({
        user_override = true,
        system_preference = false,
      })

      assert.is_true(new_pref:is_reduced_motion())
    end)

    it("should handle nil data", function()
      pref:deserialize(nil)
      -- Should not throw error
      assert.is_true(true)
    end)
  end)
end)
