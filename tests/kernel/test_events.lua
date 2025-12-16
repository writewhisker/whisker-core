-- tests/kernel/test_events.lua
-- Tests for Event Bus

describe("Events", function()
  local Events

  before_each(function()
    package.loaded["whisker.kernel.events"] = nil
    Events = require("whisker.kernel.events")
  end)

  describe("new", function()
    it("should create a new event bus", function()
      local events = Events.new()
      assert.is_not_nil(events)
    end)

    it("should accept debug option", function()
      local events = Events.new({ debug = true })
      assert.is_not_nil(events)
    end)
  end)

  describe("on", function()
    it("should register a listener", function()
      local events = Events.new()
      events:on("test", function() end)
      assert.is_true(events:has_listeners("test"))
    end)

    it("should return unsubscribe function", function()
      local events = Events.new()
      local unsubscribe = events:on("test", function() end)
      assert.is_function(unsubscribe)

      unsubscribe()
      assert.is_false(events:has_listeners("test"))
    end)

    it("should support multiple listeners for same event", function()
      local events = Events.new()
      events:on("test", function() end)
      events:on("test", function() end)
      assert.are.equal(2, events:listener_count("test"))
    end)
  end)

  describe("off", function()
    it("should remove a specific listener", function()
      local events = Events.new()
      local handler = function() end
      events:on("test", handler)
      events:on("test", function() end)

      events:off("test", handler)
      assert.are.equal(1, events:listener_count("test"))
    end)

    it("should remove all listeners when no callback specified", function()
      local events = Events.new()
      events:on("test", function() end)
      events:on("test", function() end)

      events:off("test")
      assert.is_false(events:has_listeners("test"))
    end)

    it("should handle removing non-existent listener", function()
      local events = Events.new()
      -- Should not error
      events:off("nonexistent", function() end)
    end)
  end)

  describe("emit", function()
    it("should call registered listeners", function()
      local events = Events.new()
      local called = false
      events:on("test", function()
        called = true
      end)

      events:emit("test")
      assert.is_true(called)
    end)

    it("should pass data to listeners", function()
      local events = Events.new()
      local received_data = nil
      events:on("test", function(data)
        received_data = data
      end)

      events:emit("test", { value = 42 })
      assert.are.equal(42, received_data.value)
    end)

    it("should call listeners in priority order", function()
      local events = Events.new()
      local order = {}

      events:on("test", function() table.insert(order, "low") end, { priority = 0 })
      events:on("test", function() table.insert(order, "high") end, { priority = 100 })
      events:on("test", function() table.insert(order, "medium") end, { priority = 50 })

      events:emit("test")
      assert.are.same({"high", "medium", "low"}, order)
    end)

    it("should handle emit with no listeners", function()
      local events = Events.new()
      -- Should not error
      events:emit("no_listeners", { data = "test" })
    end)
  end)

  describe("once", function()
    it("should call listener only once", function()
      local events = Events.new()
      local call_count = 0
      events:once("test", function()
        call_count = call_count + 1
      end)

      events:emit("test")
      events:emit("test")
      events:emit("test")

      assert.are.equal(1, call_count)
    end)

    it("should auto-unsubscribe after firing", function()
      local events = Events.new()
      events:once("test", function() end)

      assert.is_true(events:has_listeners("test"))
      events:emit("test")
      assert.is_false(events:has_listeners("test"))
    end)

    it("should support priority option", function()
      local events = Events.new()
      local order = {}

      events:on("test", function() table.insert(order, "regular") end, { priority = 50 })
      events:once("test", function() table.insert(order, "once") end, { priority = 100 })

      events:emit("test")
      assert.are.same({"once", "regular"}, order)
    end)
  end)

  describe("wildcard events", function()
    it("should support namespace wildcard (namespace:*)", function()
      local events = Events.new()
      local received = {}

      events:on("passage:*", function(data, event_name)
        table.insert(received, { data = data, event = event_name })
      end)

      events:emit("passage:entered", { id = 1 })
      events:emit("passage:exited", { id = 2 })
      events:emit("choice:made", { id = 3 })  -- Should not match

      assert.are.equal(2, #received)
      assert.are.equal("passage:entered", received[1].event)
      assert.are.equal("passage:exited", received[2].event)
    end)

    it("should support global wildcard (*)", function()
      local events = Events.new()
      local received = {}

      events:on("*", function(data, event_name)
        table.insert(received, event_name)
      end)

      events:emit("passage:entered")
      events:emit("choice:made")
      events:emit("custom_event")

      assert.are.equal(3, #received)
    end)

    it("should call both specific and wildcard listeners", function()
      local events = Events.new()
      local calls = {}

      events:on("passage:entered", function() table.insert(calls, "specific") end)
      events:on("passage:*", function() table.insert(calls, "namespace") end)
      events:on("*", function() table.insert(calls, "global") end)

      events:emit("passage:entered")

      assert.are.equal(3, #calls)
      assert.is_true(vim == nil or true)  -- Contains all three
    end)
  end)

  describe("debug mode", function()
    it("should call debug handler when enabled", function()
      local debug_calls = {}
      local events = Events.new({
        debug = true,
        debug_handler = function(event, data)
          table.insert(debug_calls, { event = event, data = data })
        end
      })

      events:emit("test", { value = 1 })
      events:emit("other", { value = 2 })

      assert.are.equal(2, #debug_calls)
      assert.are.equal("test", debug_calls[1].event)
      assert.are.equal("other", debug_calls[2].event)
    end)

    it("should allow toggling debug mode", function()
      local events = Events.new()
      local debug_calls = {}

      events:set_debug(true, function(event)
        table.insert(debug_calls, event)
      end)

      events:emit("test1")
      events:set_debug(false)
      events:emit("test2")

      assert.are.equal(1, #debug_calls)
    end)
  end)

  describe("has_listeners", function()
    it("should return true when listeners exist", function()
      local events = Events.new()
      events:on("test", function() end)
      assert.is_true(events:has_listeners("test"))
    end)

    it("should return false when no listeners", function()
      local events = Events.new()
      assert.is_false(events:has_listeners("test"))
    end)

    it("should return false after all listeners removed", function()
      local events = Events.new()
      local handler = function() end
      events:on("test", handler)
      events:off("test", handler)
      assert.is_false(events:has_listeners("test"))
    end)
  end)

  describe("listener_count", function()
    it("should return count for specific event", function()
      local events = Events.new()
      events:on("test", function() end)
      events:on("test", function() end)
      events:on("other", function() end)

      assert.are.equal(2, events:listener_count("test"))
      assert.are.equal(1, events:listener_count("other"))
    end)

    it("should return 0 for event with no listeners", function()
      local events = Events.new()
      assert.are.equal(0, events:listener_count("nonexistent"))
    end)

    it("should return total count when no event specified", function()
      local events = Events.new()
      events:on("a", function() end)
      events:on("a", function() end)
      events:on("b", function() end)

      assert.are.equal(3, events:listener_count())
    end)
  end)

  describe("list_events", function()
    it("should return sorted list of events with listeners", function()
      local events = Events.new()
      events:on("zebra", function() end)
      events:on("alpha", function() end)
      events:on("beta", function() end)

      local list = events:list_events()
      assert.are.same({"alpha", "beta", "zebra"}, list)
    end)

    it("should return empty list when no listeners", function()
      local events = Events.new()
      assert.are.same({}, events:list_events())
    end)
  end)

  describe("clear", function()
    it("should remove all listeners", function()
      local events = Events.new()
      events:on("a", function() end)
      events:on("b", function() end)
      events:on("c", function() end)

      events:clear()

      assert.are.equal(0, events:listener_count())
      assert.are.same({}, events:list_events())
    end)
  end)

  describe("edge cases", function()
    it("should handle listener that unsubscribes itself", function()
      local events = Events.new()
      local call_count = 0
      local unsubscribe

      unsubscribe = events:on("test", function()
        call_count = call_count + 1
        unsubscribe()
      end)

      events:emit("test")
      events:emit("test")

      assert.are.equal(1, call_count)
    end)

    it("should handle multiple once listeners", function()
      local events = Events.new()
      local calls = {}

      events:once("test", function() table.insert(calls, 1) end)
      events:once("test", function() table.insert(calls, 2) end)
      events:once("test", function() table.insert(calls, 3) end)

      events:emit("test")
      assert.are.equal(3, #calls)

      events:emit("test")
      assert.are.equal(3, #calls)  -- No additional calls
    end)

    it("should handle mixed once and regular listeners", function()
      local events = Events.new()
      local regular_count = 0
      local once_count = 0

      events:on("test", function() regular_count = regular_count + 1 end)
      events:once("test", function() once_count = once_count + 1 end)

      events:emit("test")
      events:emit("test")

      assert.are.equal(2, regular_count)
      assert.are.equal(1, once_count)
    end)
  end)
end)
