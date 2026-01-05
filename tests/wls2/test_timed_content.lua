--- Tests for WLS 2.0 Timed Content Manager
-- @module tests.wls2.test_timed_content

describe("WLS 2.0 Timed Content Manager", function()
  local timed_content

  setup(function()
    timed_content = require("whisker.wls2.timed_content")
  end)

  describe("time string parsing", function()
    it("parses milliseconds", function()
      assert.equals(500, timed_content.parse_time_string("500"))
      assert.equals(1000, timed_content.parse_time_string("1000"))
    end)

    it("parses milliseconds with ms suffix", function()
      assert.equals(500, timed_content.parse_time_string("500ms"))
      assert.equals(1000, timed_content.parse_time_string("1000ms"))
    end)

    it("parses seconds with s suffix", function()
      assert.equals(1000, timed_content.parse_time_string("1s"))
      assert.equals(2500, timed_content.parse_time_string("2.5s"))
    end)

    it("trims whitespace", function()
      assert.equals(500, timed_content.parse_time_string("  500ms  "))
    end)

    it("rejects invalid formats", function()
      assert.has_error(function()
        timed_content.parse_time_string("abc")
      end)
    end)

    it("rejects invalid units", function()
      assert.has_error(function()
        timed_content.parse_time_string("500min")
      end)
    end)
  end)

  describe("creation", function()
    it("creates a new manager", function()
      local manager = timed_content.new()
      assert.is_not_nil(manager)
    end)

    it("initializes in unpaused state", function()
      local manager = timed_content.new()
      assert.is_false(manager:is_paused())
    end)
  end)

  describe("scheduling", function()
    local manager

    before_each(function()
      manager = timed_content.new()
    end)

    it("schedules content with delay", function()
      local content = { { type = "text", text = "Hello" } }
      local id = manager:schedule(1000, content)
      assert.is_string(id)
      assert.matches("^timer_", id)
    end)

    it("schedules content with custom ID", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content, { id = "custom_timer" })
      assert.equals("custom_timer", id)
    end)

    it("schedules repeating content", function()
      local content = { { type = "text" } }
      local id = manager:schedule_repeat(500, content)
      local timer = manager:get_timer(id)
      assert.is_true(timer.is_repeat)
    end)

    it("schedules with max_fires limit", function()
      local content = { { type = "text" } }
      local id = manager:schedule_repeat(500, content, { max_fires = 3 })
      local timer = manager:get_timer(id)
      assert.equals(3, timer.max_fires)
    end)
  end)

  describe("update and firing", function()
    local manager

    before_each(function()
      manager = timed_content.new()
    end)

    it("does not fire before delay elapsed", function()
      local content = { { type = "text", text = "delayed" } }
      manager:schedule(1000, content)

      local fired = manager:update(500)
      assert.equals(0, #fired)
    end)

    it("fires after delay elapsed", function()
      local content = { { type = "text", text = "delayed" } }
      manager:schedule(1000, content)

      local fired = manager:update(1000)
      assert.equals(1, #fired)
      assert.equals("delayed", fired[1].text)
    end)

    it("fires multiple content items", function()
      local content = {
        { type = "text", text = "first" },
        { type = "text", text = "second" },
      }
      manager:schedule(1000, content)

      local fired = manager:update(1000)
      assert.equals(2, #fired)
    end)

    it("removes one-shot timers after firing", function()
      local content = { { type = "text" } }
      local id = manager:schedule(500, content)

      manager:update(500)
      assert.is_nil(manager:get_timer(id))
    end)

    it("repeats timers with is_repeat", function()
      local content = { { type = "text" } }
      local id = manager:schedule_repeat(500, content)

      -- First fire
      local fired1 = manager:update(500)
      assert.equals(1, #fired1)
      assert.is_not_nil(manager:get_timer(id))

      -- Second fire
      local fired2 = manager:update(500)
      assert.equals(1, #fired2)
    end)

    it("stops repeating after max_fires", function()
      local content = { { type = "text" } }
      local id = manager:schedule_repeat(500, content, { max_fires = 2 })

      manager:update(500)  -- Fire 1
      manager:update(500)  -- Fire 2
      assert.is_nil(manager:get_timer(id))
    end)

    it("calls on_fire callback", function()
      local callback_called = false
      local content = { { type = "text" } }
      manager:schedule(500, content, {
        on_fire = function(block)
          callback_called = true
          assert.is_not_nil(block)
        end
      })

      manager:update(500)
      assert.is_true(callback_called)
    end)
  end)

  describe("pause and resume", function()
    local manager

    before_each(function()
      manager = timed_content.new()
    end)

    it("pauses the manager", function()
      manager:pause()
      assert.is_true(manager:is_paused())
    end)

    it("resumes the manager", function()
      manager:pause()
      manager:resume()
      assert.is_false(manager:is_paused())
    end)

    it("does not fire when paused", function()
      local content = { { type = "text" } }
      manager:schedule(500, content)
      manager:pause()

      local fired = manager:update(1000)
      assert.equals(0, #fired)
    end)

    it("adjusts timer start times on resume", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content)

      manager:update(200)  -- 200ms elapsed
      manager:pause()
      manager:update(500)  -- 500ms while paused (should not count)
      manager:resume()

      -- Should still need ~800ms to fire
      local fired1 = manager:update(700)
      assert.equals(0, #fired1)

      local fired2 = manager:update(200)
      assert.equals(1, #fired2)
    end)
  end)

  describe("cancellation", function()
    local manager

    before_each(function()
      manager = timed_content.new()
    end)

    it("cancels a timer by ID", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content)
      manager:cancel(id)
      assert.is_nil(manager:get_timer(id))
    end)

    it("cancels all timers", function()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      manager:schedule(2000, content)
      manager:schedule(3000, content)

      manager:cancel_all()
      local active = manager:get_active_timers()
      assert.equals(0, #active)
    end)
  end)

  describe("timer queries", function()
    local manager

    before_each(function()
      manager = timed_content.new()
    end)

    it("retrieves timer by ID", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content)
      local timer = manager:get_timer(id)
      assert.is_not_nil(timer)
      assert.equals(id, timer.id)
      assert.equals(1000, timer.delay)
    end)

    it("returns nil for non-existent timer", function()
      local timer = manager:get_timer("nonexistent")
      assert.is_nil(timer)
    end)

    it("gets all active timers", function()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      manager:schedule(2000, content)

      local active = manager:get_active_timers()
      assert.equals(2, #active)
    end)

    it("gets remaining time for timer", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content)
      manager:update(300)

      local remaining = manager:get_remaining(id)
      assert.equals(700, remaining)
    end)

    it("returns nil remaining for non-existent timer", function()
      local remaining = manager:get_remaining("nonexistent")
      assert.is_nil(remaining)
    end)
  end)

  describe("events", function()
    local manager
    local events

    before_each(function()
      manager = timed_content.new()
      events = {}
      manager:on(function(event, block)
        table.insert(events, { event = event, block = block })
      end)
    end)

    it("emits CREATED event on schedule", function()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      assert.equals(1, #events)
      assert.equals(timed_content.EVENTS.CREATED, events[1].event)
    end)

    it("emits FIRED event on timer fire", function()
      local content = { { type = "text" } }
      manager:schedule(500, content)
      manager:update(500)
      assert.equals(2, #events)  -- CREATED + FIRED
      assert.equals(timed_content.EVENTS.FIRED, events[2].event)
    end)

    it("emits CANCELED event on cancel", function()
      local content = { { type = "text" } }
      local id = manager:schedule(1000, content)
      manager:cancel(id)
      assert.equals(2, #events)  -- CREATED + CANCELED
      assert.equals(timed_content.EVENTS.CANCELED, events[2].event)
    end)

    it("emits PAUSED event on pause", function()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      manager:pause()
      assert.equals(2, #events)  -- CREATED + PAUSED
      assert.equals(timed_content.EVENTS.PAUSED, events[2].event)
    end)

    it("emits RESUMED event on resume", function()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      manager:pause()
      manager:resume()
      assert.equals(3, #events)  -- CREATED + PAUSED + RESUMED
      assert.equals(timed_content.EVENTS.RESUMED, events[3].event)
    end)

    it("removes listeners with off()", function()
      local callback = function() end
      manager:on(callback)
      manager:off(callback)
      -- No assertion needed - verify no errors
    end)
  end)

  describe("reset", function()
    it("clears all state", function()
      local manager = timed_content.new()
      local content = { { type = "text" } }
      manager:schedule(1000, content)
      manager:update(500)
      manager:pause()

      manager:reset()

      assert.equals(0, #manager:get_active_timers())
      assert.is_false(manager:is_paused())
    end)
  end)
end)
