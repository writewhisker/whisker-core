--- EventBus Unit Tests
-- Tests for the event bus
-- @module tests.unit.kernel.events_spec
-- @author Whisker Core Team
-- @license MIT

local EventBus = require("whisker.kernel.events")

describe("EventBus", function()

  describe("new", function()
    it("creates a new event bus instance", function()
      local events = EventBus.new()
      assert.is_not_nil(events)
      assert.is_table(events)
    end)
  end)

  describe("on", function()
    it("registers an event handler", function()
      local events = EventBus.new()
      events:on("test", function() end)
      assert.equals(1, events:count("test"))
    end)

    it("throws on non-function handler", function()
      local events = EventBus.new()
      assert.has_error(function()
        events:on("test", "not a function")
      end)
    end)

    it("returns unsubscribe function", function()
      local events = EventBus.new()
      local unsub = events:on("test", function() end)
      assert.is_function(unsub)
    end)

    it("supports multiple handlers", function()
      local events = EventBus.new()
      events:on("test", function() end)
      events:on("test", function() end)
      events:on("test", function() end)
      assert.equals(3, events:count("test"))
    end)
  end)

  describe("emit", function()
    it("calls registered handlers", function()
      local events = EventBus.new()
      local called = false

      events:on("test", function()
        called = true
      end)

      events:emit("test")
      assert.is_true(called)
    end)

    it("passes data to handlers", function()
      local events = EventBus.new()
      local received_data

      events:on("test", function(data)
        received_data = data
      end)

      events:emit("test", { value = 42 })
      assert.equals(42, received_data.value)
    end)

    it("adds event_name to data", function()
      local events = EventBus.new()
      local received_data

      events:on("test", function(data)
        received_data = data
      end)

      events:emit("test", {})
      assert.equals("test", received_data.event_name)
    end)

    it("calls handlers in order", function()
      local events = EventBus.new()
      local order = {}

      events:on("test", function() table.insert(order, 1) end)
      events:on("test", function() table.insert(order, 2) end)
      events:on("test", function() table.insert(order, 3) end)

      events:emit("test")

      assert.equals(1, order[1])
      assert.equals(2, order[2])
      assert.equals(3, order[3])
    end)

    it("returns result object", function()
      local events = EventBus.new()
      local result = events:emit("test")

      assert.is_table(result)
      assert.is_false(result.canceled)
      assert.is_table(result.results)
    end)

    it("collects handler return values", function()
      local events = EventBus.new()

      events:on("test", function() return "a" end)
      events:on("test", function() return "b" end)

      local result = events:emit("test")

      assert.equals("a", result.results[1])
      assert.equals("b", result.results[2])
    end)

    it("supports event cancellation", function()
      local events = EventBus.new()
      local second_called = false

      events:on("test", function(data)
        data.cancel = true
      end)

      events:on("test", function()
        second_called = true
      end)

      local result = events:emit("test")

      assert.is_true(result.canceled)
      assert.is_false(second_called)
    end)
  end)

  describe("off", function()
    it("removes a handler", function()
      local events = EventBus.new()
      local handler = function() end

      events:on("test", handler)
      assert.equals(1, events:count("test"))

      events:off("test", handler)
      assert.equals(0, events:count("test"))
    end)

    it("only removes the specified handler", function()
      local events = EventBus.new()
      local handler1 = function() end
      local handler2 = function() end

      events:on("test", handler1)
      events:on("test", handler2)

      events:off("test", handler1)

      assert.equals(1, events:count("test"))
    end)
  end)

  describe("once", function()
    it("handler called only once", function()
      local events = EventBus.new()
      local call_count = 0

      events:once("test", function()
        call_count = call_count + 1
      end)

      events:emit("test")
      events:emit("test")
      events:emit("test")

      assert.equals(1, call_count)
    end)

    it("handler removed after first call", function()
      local events = EventBus.new()

      events:once("test", function() end)
      assert.equals(1, events:count("test"))

      events:emit("test")
      assert.equals(0, events:count("test"))
    end)
  end)

  describe("wildcard patterns", function()
    it("matches wildcard * at end", function()
      local events = EventBus.new()
      local called = false

      events:on("user:*", function()
        called = true
      end)

      events:emit("user:login")
      assert.is_true(called)
    end)

    it("matches multiple events", function()
      local events = EventBus.new()
      local call_count = 0

      events:on("user:*", function()
        call_count = call_count + 1
      end)

      events:emit("user:login")
      events:emit("user:logout")
      events:emit("user:register")

      assert.equals(3, call_count)
    end)

    it("does not match non-matching events", function()
      local events = EventBus.new()
      local called = false

      events:on("user:*", function()
        called = true
      end)

      events:emit("system:startup")
      assert.is_false(called)
    end)
  end)

  describe("clear", function()
    it("clears specific event handlers", function()
      local events = EventBus.new()

      events:on("test1", function() end)
      events:on("test2", function() end)

      events:clear("test1")

      assert.equals(0, events:count("test1"))
      assert.equals(1, events:count("test2"))
    end)

    it("clears all handlers when no event specified", function()
      local events = EventBus.new()

      events:on("test1", function() end)
      events:on("test2", function() end)
      events:on("test3", function() end)

      events:clear()

      assert.equals(0, events:count("test1"))
      assert.equals(0, events:count("test2"))
      assert.equals(0, events:count("test3"))
    end)
  end)

  describe("count", function()
    it("returns 0 for no handlers", function()
      local events = EventBus.new()
      assert.equals(0, events:count("nonexistent"))
    end)

    it("counts exact handlers", function()
      local events = EventBus.new()
      events:on("test", function() end)
      events:on("test", function() end)
      assert.equals(2, events:count("test"))
    end)

    it("includes matching wildcard handlers", function()
      local events = EventBus.new()
      events:on("user:login", function() end)
      events:on("user:*", function() end)

      -- user:login matches both exact and wildcard
      assert.equals(2, events:count("user:login"))
    end)
  end)

  describe("namespace", function()
    it("creates namespaced event interface", function()
      local events = EventBus.new()
      local ns = events:namespace("module")

      assert.is_table(ns)
      assert.is_function(ns.on)
      assert.is_function(ns.emit)
      assert.is_function(ns.off)
    end)

    it("prefixes event names", function()
      local events = EventBus.new()
      local ns = events:namespace("module")
      local received_name

      events:on("module:test", function(data)
        received_name = data.event_name
      end)

      ns:emit("test", {})

      assert.equals("module:test", received_name)
    end)

    it("namespace on() subscribes to prefixed events", function()
      local events = EventBus.new()
      local ns = events:namespace("module")
      local called = false

      ns:on("test", function()
        called = true
      end)

      events:emit("module:test")
      assert.is_true(called)
    end)
  end)

  describe("history", function()
    it("enable_history starts tracking", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("test1")
      events:emit("test2")

      local history = events:get_history()
      assert.equals(2, #history)
    end)

    it("history records event names", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("my:event")

      local history = events:get_history()
      assert.equals("my:event", history[1].event)
    end)

    it("history records timestamps", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("test")

      local history = events:get_history()
      assert.is_number(history[1].timestamp)
    end)

    it("history respects max size", function()
      local events = EventBus.new()
      events:enable_history(3)

      events:emit("event1")
      events:emit("event2")
      events:emit("event3")
      events:emit("event4")
      events:emit("event5")

      local history = events:get_history()
      assert.equals(3, #history)
    end)

    it("get_history with filter", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("user:login")
      events:emit("system:startup")
      events:emit("user:logout")

      local user_events = events:get_history("user:*")
      assert.equals(2, #user_events)
    end)

    it("disable_history stops tracking", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("test1")
      events:disable_history()
      events:emit("test2")

      local history = events:get_history()
      assert.equals(0, #history)  -- History is nil after disable
    end)

    it("clear_history empties history", function()
      local events = EventBus.new()
      events:enable_history()

      events:emit("test1")
      events:emit("test2")
      events:clear_history()

      local history = events:get_history()
      assert.equals(0, #history)
    end)
  end)

  describe("error handling", function()
    it("continues after handler error", function()
      local events = EventBus.new()
      local second_called = false

      events:on("test", function()
        error("First handler error")
      end)

      events:on("test", function()
        second_called = true
      end)

      events:emit("test")
      assert.is_true(second_called)
    end)
  end)
end)
