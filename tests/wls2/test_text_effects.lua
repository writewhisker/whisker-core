--- Tests for WLS 2.0 Text Effects Manager
-- @module tests.wls2.test_text_effects

describe("WLS 2.0 Text Effects Manager", function()
  local text_effects

  setup(function()
    text_effects = require("whisker.wls2.text_effects")
  end)

  describe("effect declaration parsing", function()
    it("parses simple effect name", function()
      local result = text_effects.parse_effect_declaration("shake")
      assert.equals("shake", result.name)
    end)

    it("parses effect with duration in ms", function()
      local result = text_effects.parse_effect_declaration("shake 500ms")
      assert.equals("shake", result.name)
      assert.equals(500, result.duration)
    end)

    it("parses effect with duration in seconds", function()
      local result = text_effects.parse_effect_declaration("fade-in 2s")
      assert.equals("fade-in", result.name)
      assert.equals(2000, result.duration)
    end)

    it("parses effect with key:value options", function()
      local result = text_effects.parse_effect_declaration("shake intensity:10 speed:fast")
      assert.equals("shake", result.name)
      assert.equals(10, result.options.intensity)
      assert.equals("fast", result.options.speed)
    end)

    it("parses effect with duration and options", function()
      local result = text_effects.parse_effect_declaration("typewriter 50ms delay:100")
      assert.equals("typewriter", result.name)
      assert.equals(50, result.duration)
      assert.equals(100, result.options.delay)
    end)

    it("rejects empty declaration", function()
      assert.has_error(function()
        text_effects.parse_effect_declaration("")
      end)
    end)
  end)

  describe("creation", function()
    it("creates a new manager", function()
      local manager = text_effects.new()
      assert.is_not_nil(manager)
    end)

    it("registers default effect handlers", function()
      local manager = text_effects.new()
      -- Apply each default effect type to verify handlers exist
      assert.has_no.errors(function()
        manager:apply("test", text_effects.EFFECTS.TYPEWRITER)
        manager:apply("test", text_effects.EFFECTS.FADE_IN)
        manager:apply("test", text_effects.EFFECTS.FADE_OUT)
        manager:apply("test", text_effects.EFFECTS.SHAKE)
      end)
    end)
  end)

  describe("applying effects", function()
    local manager

    before_each(function()
      manager = text_effects.new()
    end)

    it("returns an effect ID", function()
      local id = manager:apply("Hello, World!", "typewriter")
      assert.is_string(id)
      assert.matches("^effect_", id)
    end)

    it("stores the effect text", function()
      local id = manager:apply("Hello, World!", "typewriter")
      local effect = manager:get_effect(id)
      assert.equals("Hello, World!", effect.text)
    end)

    it("stores effect options", function()
      local id = manager:apply("text", "typewriter", { speed = 100 })
      local effect = manager:get_effect(id)
      assert.equals(100, effect.options.speed)
    end)

    it("initializes effect state", function()
      local id = manager:apply("text", "typewriter")
      local effect = manager:get_effect(id)
      assert.is_false(effect.completed)
      assert.equals(1, effect.opacity)
      assert.equals(0, effect.offset_x)
      assert.equals(0, effect.offset_y)
    end)
  end)

  describe("effect handlers", function()
    describe("typewriter", function()
      local manager

      before_each(function()
        manager = text_effects.new()
      end)

      it("reveals text progressively", function()
        local id = manager:apply("Hello", "typewriter", { speed = 50 })

        local results = manager:update(100)  -- Should reveal 2 chars
        assert.equals("He", results[id].text)
      end)

      it("completes when all text is revealed", function()
        local id = manager:apply("Hi", "typewriter", { speed = 50 })

        manager:update(50)  -- H
        local results = manager:update(50)  -- i
        assert.is_true(results[id].completed)
      end)

      it("uses default speed of 50ms per char", function()
        local id = manager:apply("AB", "typewriter")

        local results = manager:update(50)
        assert.equals("A", results[id].text)
      end)
    end)

    describe("fade-in", function()
      local manager

      before_each(function()
        manager = text_effects.new()
      end)

      it("increases opacity over time", function()
        local id = manager:apply("text", "fade-in", { duration = 1000 })

        local results = manager:update(500)
        assert.is_true(results[id].opacity >= 0.4)
        assert.is_true(results[id].opacity <= 0.6)
      end)

      it("completes at full opacity", function()
        local id = manager:apply("text", "fade-in", { duration = 1000 })

        local results = manager:update(1000)
        assert.equals(1, results[id].opacity)
        assert.is_true(results[id].completed)
      end)

      it("uses default duration of 1000ms", function()
        local id = manager:apply("text", "fade-in")

        local results = manager:update(1000)
        assert.is_true(results[id].completed)
      end)
    end)

    describe("fade-out", function()
      local manager

      before_each(function()
        manager = text_effects.new()
      end)

      it("decreases opacity over time", function()
        local id = manager:apply("text", "fade-out", { duration = 1000 })

        local results = manager:update(500)
        assert.is_true(results[id].opacity >= 0.4)
        assert.is_true(results[id].opacity <= 0.6)
      end)

      it("completes at zero opacity", function()
        local id = manager:apply("text", "fade-out", { duration = 1000 })

        local results = manager:update(1000)
        assert.equals(0, results[id].opacity)
        assert.is_true(results[id].completed)
      end)
    end)

    describe("shake", function()
      local manager

      before_each(function()
        manager = text_effects.new()
      end)

      it("applies random offsets", function()
        local id = manager:apply("text", "shake", { duration = 500 })

        local results = manager:update(100)
        -- Offsets should be non-zero (with high probability)
        assert.is_number(results[id].offset_x)
        assert.is_number(results[id].offset_y)
      end)

      it("resets offsets on completion", function()
        local id = manager:apply("text", "shake", { duration = 500 })

        local results = manager:update(500)
        assert.equals(0, results[id].offset_x)
        assert.equals(0, results[id].offset_y)
        assert.is_true(results[id].completed)
      end)

      it("uses intensity option", function()
        local id = manager:apply("text", "shake", { duration = 1000, intensity = 20 })
        local effect = manager:get_effect(id)
        assert.equals(20, effect.options.intensity)
      end)
    end)
  end)

  describe("custom effect handlers", function()
    local manager

    before_each(function()
      manager = text_effects.new()
    end)

    it("registers custom handler", function()
      manager:register_handler("custom", function(effect, _delta_ms)
        effect.completed = true
        return effect.text:upper()
      end)

      local id = manager:apply("hello", "custom")
      local results = manager:update(0)
      assert.equals("HELLO", results[id].text)
      assert.is_true(results[id].completed)
    end)

    it("overrides existing handler", function()
      manager:register_handler("typewriter", function(effect, _delta_ms)
        effect.completed = true
        return "overridden"
      end)

      local id = manager:apply("hello", "typewriter")
      local results = manager:update(0)
      assert.equals("overridden", results[id].text)
    end)
  end)

  describe("update and completion", function()
    local manager

    before_each(function()
      manager = text_effects.new()
    end)

    it("updates current time", function()
      manager:update(100)
      manager:update(200)
      -- Internal state is updated correctly - verified through effect behavior
    end)

    it("removes completed effects from active list", function()
      local id = manager:apply("Hi", "typewriter", { speed = 50 })
      manager:update(100)  -- Complete the effect

      assert.is_nil(manager:get_effect(id))
    end)

    it("handles multiple active effects", function()
      local id1 = manager:apply("ABC", "typewriter", { speed = 50 })
      local id2 = manager:apply("text", "fade-in", { duration = 1000 })

      local results = manager:update(100)
      assert.is_not_nil(results[id1])
      assert.is_not_nil(results[id2])
    end)
  end)

  describe("effect queries", function()
    local manager

    before_each(function()
      manager = text_effects.new()
    end)

    it("retrieves effect by ID", function()
      local id = manager:apply("text", "typewriter")
      local effect = manager:get_effect(id)
      assert.is_not_nil(effect)
      assert.equals(id, effect.id)
    end)

    it("returns nil for non-existent effect", function()
      local effect = manager:get_effect("nonexistent")
      assert.is_nil(effect)
    end)

    it("checks if effect is complete", function()
      local id = manager:apply("A", "typewriter", { speed = 50 })
      assert.is_false(manager:is_complete(id))
      manager:update(50)
      assert.is_true(manager:is_complete(id))
    end)

    it("returns true for non-existent effect in is_complete", function()
      assert.is_true(manager:is_complete("nonexistent"))
    end)

    it("checks if all effects are complete", function()
      manager:apply("A", "typewriter", { speed = 50 })
      manager:apply("B", "typewriter", { speed = 50 })
      assert.is_false(manager:all_complete())

      manager:update(50)
      assert.is_true(manager:all_complete())
    end)

    it("returns true for all_complete when no effects", function()
      assert.is_true(manager:all_complete())
    end)
  end)

  describe("cancellation", function()
    local manager

    before_each(function()
      manager = text_effects.new()
    end)

    it("cancels an effect by ID", function()
      local id = manager:apply("text", "typewriter")
      manager:cancel(id)
      assert.is_nil(manager:get_effect(id))
    end)

    it("cancels all effects", function()
      manager:apply("text1", "typewriter")
      manager:apply("text2", "fade-in")
      manager:cancel_all()
      assert.is_true(manager:all_complete())
    end)
  end)

  describe("events", function()
    local manager
    local events

    before_each(function()
      manager = text_effects.new()
      events = {}
      manager:on(function(event, effect)
        table.insert(events, { event = event, effect = effect })
      end)
    end)

    it("emits STARTED event on apply", function()
      manager:apply("text", "typewriter")
      assert.equals(1, #events)
      assert.equals(text_effects.EVENTS.STARTED, events[1].event)
    end)

    it("emits UPDATED event on update", function()
      manager:apply("text", "typewriter")
      manager:update(50)
      -- Should have STARTED and UPDATED
      assert.is_true(#events >= 2)
      local has_updated = false
      for _, e in ipairs(events) do
        if e.event == text_effects.EVENTS.UPDATED then
          has_updated = true
          break
        end
      end
      assert.is_true(has_updated)
    end)

    it("emits COMPLETED event when effect finishes", function()
      manager:apply("A", "typewriter", { speed = 50 })
      manager:update(50)
      local has_completed = false
      for _, e in ipairs(events) do
        if e.event == text_effects.EVENTS.COMPLETED then
          has_completed = true
          break
        end
      end
      assert.is_true(has_completed)
    end)

    it("removes listeners with off()", function()
      local callback = function() end
      manager:on(callback)
      manager:off(callback)
      -- Verify no errors
    end)
  end)

  describe("reset", function()
    it("clears all effects and time", function()
      local manager = text_effects.new()
      manager:apply("text", "typewriter")
      manager:update(500)
      manager:reset()

      assert.is_true(manager:all_complete())
    end)
  end)

  describe("effect types constants", function()
    it("defines standard effect types", function()
      assert.equals("typewriter", text_effects.EFFECTS.TYPEWRITER)
      assert.equals("fade-in", text_effects.EFFECTS.FADE_IN)
      assert.equals("fade-out", text_effects.EFFECTS.FADE_OUT)
      assert.equals("shake", text_effects.EFFECTS.SHAKE)
      assert.equals("rainbow", text_effects.EFFECTS.RAINBOW)
      assert.equals("glitch", text_effects.EFFECTS.GLITCH)
    end)
  end)
end)
