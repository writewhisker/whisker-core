--- AsyncEvent Unit Tests
-- Comprehensive unit tests for the AsyncEvent module
-- @module tests.unit.core.test_async_event_spec
-- @author Whisker Core Team

describe("AsyncEvent", function()
  local AsyncEvent

  before_each(function()
    AsyncEvent = require("whisker.core.async_event")
  end)

  describe("initialization", function()
    it("creates event in pending state", function()
      local event = AsyncEvent.new()

      assert.is_not_nil(event)
      assert.equals(AsyncEvent.STATE.PENDING, event.state)
    end)

    it("creates event with default event type", function()
      local event = AsyncEvent.new()

      assert.equals("async", event.event_type)
    end)

    it("creates event with custom event type", function()
      local event = AsyncEvent.new("custom_type")

      assert.equals("custom_type", event.event_type)
    end)

    it("initializes result and error as nil", function()
      local event = AsyncEvent.new()

      assert.is_nil(event.result)
      assert.is_nil(event.error)
    end)

    it("initializes empty callback arrays", function()
      local event = AsyncEvent.new()

      assert.is_table(event._then_callbacks)
      assert.is_table(event._catch_callbacks)
      assert.is_table(event._finally_callbacks)
      assert.equals(0, #event._then_callbacks)
    end)
  end)

  describe("STATE constants", function()
    it("defines PENDING state", function()
      assert.equals("pending", AsyncEvent.STATE.PENDING)
    end)

    it("defines RESOLVED state", function()
      assert.equals("resolved", AsyncEvent.STATE.RESOLVED)
    end)

    it("defines REJECTED state", function()
      assert.equals("rejected", AsyncEvent.STATE.REJECTED)
    end)
  end)

  describe("then_do", function()
    it("registers callback when pending", function()
      local event = AsyncEvent.new()
      local called = false

      event:then_do(function() called = true end)

      assert.equals(1, #event._then_callbacks)
    end)

    it("throws error for non-function callback", function()
      local event = AsyncEvent.new()

      assert.has_error(function()
        event:then_do("not a function")
      end)
    end)

    it("calls callback immediately if already resolved", function()
      local event = AsyncEvent.new()
      event:resolve("result")

      local received = nil
      event:then_do(function(result) received = result end)

      assert.equals("result", received)
    end)

    it("does not call callback if rejected", function()
      local event = AsyncEvent.new()
      event:reject("error")

      local called = false
      event:then_do(function() called = true end)

      assert.is_false(called)
    end)

    it("returns self for chaining", function()
      local event = AsyncEvent.new()

      local result = event:then_do(function() end)

      assert.equals(event, result)
    end)
  end)

  describe("catch", function()
    it("registers error handler when pending", function()
      local event = AsyncEvent.new()

      event:catch(function() end)

      assert.equals(1, #event._catch_callbacks)
    end)

    it("throws error for non-function handler", function()
      local event = AsyncEvent.new()

      assert.has_error(function()
        event:catch(123)
      end)
    end)

    it("calls handler immediately if already rejected", function()
      local event = AsyncEvent.new()
      event:reject("error message")

      local received = nil
      event:catch(function(err) received = err end)

      assert.equals("error message", received)
    end)

    it("does not call handler if resolved", function()
      local event = AsyncEvent.new()
      event:resolve("result")

      local called = false
      event:catch(function() called = true end)

      assert.is_false(called)
    end)

    it("returns self for chaining", function()
      local event = AsyncEvent.new()

      local result = event:catch(function() end)

      assert.equals(event, result)
    end)
  end)

  describe("finally", function()
    it("registers callback when pending", function()
      local event = AsyncEvent.new()

      event:finally(function() end)

      assert.equals(1, #event._finally_callbacks)
    end)

    it("throws error for non-function callback", function()
      local event = AsyncEvent.new()

      assert.has_error(function()
        event:finally({})
      end)
    end)

    it("calls callback immediately if already resolved", function()
      local event = AsyncEvent.new()
      event:resolve("result")

      local called = false
      event:finally(function() called = true end)

      assert.is_true(called)
    end)

    it("calls callback immediately if already rejected", function()
      local event = AsyncEvent.new()
      event:reject("error")

      local called = false
      event:finally(function() called = true end)

      assert.is_true(called)
    end)

    it("returns self for chaining", function()
      local event = AsyncEvent.new()

      local result = event:finally(function() end)

      assert.equals(event, result)
    end)
  end)

  describe("resolve", function()
    it("changes state to resolved", function()
      local event = AsyncEvent.new()

      event:resolve("value")

      assert.equals(AsyncEvent.STATE.RESOLVED, event.state)
    end)

    it("stores result", function()
      local event = AsyncEvent.new()

      event:resolve("my result")

      assert.equals("my result", event.result)
    end)

    it("calls then callbacks", function()
      local event = AsyncEvent.new()
      local called = false
      local received = nil
      event:then_do(function(result)
        called = true
        received = result
      end)

      event:resolve("value")

      assert.is_true(called)
      assert.equals("value", received)
    end)

    it("calls finally callbacks", function()
      local event = AsyncEvent.new()
      local called = false
      event:finally(function() called = true end)

      event:resolve("value")

      assert.is_true(called)
    end)

    it("ignores second resolve", function()
      local event = AsyncEvent.new()
      event:resolve("first")

      event:resolve("second")

      assert.equals("first", event.result)
    end)

    it("ignores resolve after reject", function()
      local event = AsyncEvent.new()
      event:reject("error")

      event:resolve("value")

      assert.equals(AsyncEvent.STATE.REJECTED, event.state)
    end)

    it("returns self", function()
      local event = AsyncEvent.new()

      local result = event:resolve("value")

      assert.equals(event, result)
    end)
  end)

  describe("reject", function()
    it("changes state to rejected", function()
      local event = AsyncEvent.new()

      event:reject("error")

      assert.equals(AsyncEvent.STATE.REJECTED, event.state)
    end)

    it("stores error", function()
      local event = AsyncEvent.new()

      event:reject("my error")

      assert.equals("my error", event.error)
    end)

    it("calls catch callbacks", function()
      local event = AsyncEvent.new()
      local received = nil
      event:catch(function(err) received = err end)

      event:reject("error message")

      assert.equals("error message", received)
    end)

    it("calls finally callbacks", function()
      local event = AsyncEvent.new()
      local called = false
      event:finally(function() called = true end)

      event:reject("error")

      assert.is_true(called)
    end)

    it("ignores second reject", function()
      local event = AsyncEvent.new()
      event:reject("first")

      event:reject("second")

      assert.equals("first", event.error)
    end)

    it("ignores reject after resolve", function()
      local event = AsyncEvent.new()
      event:resolve("value")

      event:reject("error")

      assert.equals(AsyncEvent.STATE.RESOLVED, event.state)
    end)

    it("returns self", function()
      local event = AsyncEvent.new()

      local result = event:reject("error")

      assert.equals(event, result)
    end)
  end)

  describe("state queries", function()
    it("is_pending returns true when pending", function()
      local event = AsyncEvent.new()

      assert.is_true(event:is_pending())
    end)

    it("is_pending returns false when resolved", function()
      local event = AsyncEvent.new()
      event:resolve("value")

      assert.is_false(event:is_pending())
    end)

    it("is_resolved returns true when resolved", function()
      local event = AsyncEvent.new()
      event:resolve("value")

      assert.is_true(event:is_resolved())
    end)

    it("is_resolved returns false when pending", function()
      local event = AsyncEvent.new()

      assert.is_false(event:is_resolved())
    end)

    it("is_rejected returns true when rejected", function()
      local event = AsyncEvent.new()
      event:reject("error")

      assert.is_true(event:is_rejected())
    end)

    it("is_rejected returns false when pending", function()
      local event = AsyncEvent.new()

      assert.is_false(event:is_rejected())
    end)

    it("is_settled returns true when resolved", function()
      local event = AsyncEvent.new()
      event:resolve("value")

      assert.is_true(event:is_settled())
    end)

    it("is_settled returns true when rejected", function()
      local event = AsyncEvent.new()
      event:reject("error")

      assert.is_true(event:is_settled())
    end)

    it("is_settled returns false when pending", function()
      local event = AsyncEvent.new()

      assert.is_false(event:is_settled())
    end)

    it("get_state returns current state", function()
      local event = AsyncEvent.new()

      assert.equals(AsyncEvent.STATE.PENDING, event:get_state())

      event:resolve("value")
      assert.equals(AsyncEvent.STATE.RESOLVED, event:get_state())
    end)

    it("get_result returns result when resolved", function()
      local event = AsyncEvent.new()
      event:resolve("my result")

      assert.equals("my result", event:get_result())
    end)

    it("get_result returns nil when not resolved", function()
      local event = AsyncEvent.new()

      assert.is_nil(event:get_result())
    end)

    it("get_error returns error when rejected", function()
      local event = AsyncEvent.new()
      event:reject("my error")

      assert.equals("my error", event:get_error())
    end)

    it("get_error returns nil when not rejected", function()
      local event = AsyncEvent.new()

      assert.is_nil(event:get_error())
    end)
  end)

  describe("await", function()
    it("returns result immediately if resolved", function()
      local event = AsyncEvent.new()
      event:resolve("value")

      -- Must run in coroutine
      local co = coroutine.create(function()
        local result, err = event:await()
        return result, err
      end)

      local ok, result, err = coroutine.resume(co)

      assert.is_true(ok)
      assert.equals("value", result)
      assert.is_nil(err)
    end)

    it("returns error immediately if rejected", function()
      local event = AsyncEvent.new()
      event:reject("error message")

      local co = coroutine.create(function()
        return event:await()
      end)

      local ok, result, err = coroutine.resume(co)

      assert.is_true(ok)
      assert.is_nil(result)
      assert.equals("error message", err)
    end)

    it("throws error if not in coroutine", function()
      local event = AsyncEvent.new()

      assert.has_error(function()
        event:await()
      end)
    end)

    it("yields when pending", function()
      local event = AsyncEvent.new()

      local co = coroutine.create(function()
        return event:await()
      end)

      coroutine.resume(co)

      assert.equals("suspended", coroutine.status(co))
    end)

    it("resumes coroutine on resolve", function()
      local event = AsyncEvent.new()
      local received = nil

      local co = coroutine.create(function()
        local result = event:await()
        received = result
      end)

      coroutine.resume(co)
      event:resolve("async result")

      assert.equals("async result", received)
    end)

    it("resumes coroutine on reject", function()
      local event = AsyncEvent.new()
      local received_err = nil

      local co = coroutine.create(function()
        local _, err = event:await()
        received_err = err
      end)

      coroutine.resume(co)
      event:reject("async error")

      assert.equals("async error", received_err)
    end)
  end)

  describe("AsyncEvent.run", function()
    it("runs function in coroutine", function()
      local called = false

      AsyncEvent.run(function()
        called = true
      end)

      assert.is_true(called)
    end)

    it("returns function result", function()
      local result = AsyncEvent.run(function()
        return "result"
      end)

      assert.equals("result", result)
    end)

    it("propagates errors", function()
      assert.has_error(function()
        AsyncEvent.run(function()
          error("test error")
        end)
      end)
    end)
  end)

  describe("AsyncEvent.all", function()
    it("resolves immediately for empty array", function()
      local all = AsyncEvent.all({})

      assert.is_true(all:is_resolved())
      assert.same({}, all.result)
    end)

    it("resolves with all results when all resolve", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()
      local e3 = AsyncEvent.new()

      local all = AsyncEvent.all({ e1, e2, e3 })

      e1:resolve("a")
      e2:resolve("b")
      e3:resolve("c")

      assert.is_true(all:is_resolved())
      assert.equals("a", all.result[1])
      assert.equals("b", all.result[2])
      assert.equals("c", all.result[3])
    end)

    it("rejects when any event rejects", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local all = AsyncEvent.all({ e1, e2 })

      e1:reject("error")

      assert.is_true(all:is_rejected())
      assert.equals("error", all.error)
    end)

    it("ignores resolve after reject", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local all = AsyncEvent.all({ e1, e2 })

      e1:reject("error")
      e2:resolve("value")

      assert.is_true(all:is_rejected())
    end)
  end)

  describe("AsyncEvent.race", function()
    it("never settles for empty array", function()
      local race = AsyncEvent.race({})

      assert.is_true(race:is_pending())
    end)

    it("resolves with first resolved value", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local race = AsyncEvent.race({ e1, e2 })

      e1:resolve("first")

      assert.is_true(race:is_resolved())
      assert.equals("first", race.result)
    end)

    it("rejects with first rejection", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local race = AsyncEvent.race({ e1, e2 })

      e1:reject("first error")

      assert.is_true(race:is_rejected())
      assert.equals("first error", race.error)
    end)

    it("ignores subsequent settlements", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local race = AsyncEvent.race({ e1, e2 })

      e1:resolve("first")
      e2:resolve("second")

      assert.equals("first", race.result)
    end)
  end)

  describe("AsyncEvent.all_settled", function()
    it("resolves immediately for empty array", function()
      local settled = AsyncEvent.all_settled({})

      assert.is_true(settled:is_resolved())
      assert.same({}, settled.result)
    end)

    it("resolves with all outcomes", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local settled = AsyncEvent.all_settled({ e1, e2 })

      e1:resolve("value")
      e2:reject("error")

      assert.is_true(settled:is_resolved())
      assert.same({ status = "fulfilled", value = "value" }, settled.result[1])
      assert.same({ status = "rejected", reason = "error" }, settled.result[2])
    end)

    it("never rejects", function()
      local e1 = AsyncEvent.new()
      local e2 = AsyncEvent.new()

      local settled = AsyncEvent.all_settled({ e1, e2 })

      e1:reject("error1")
      e2:reject("error2")

      assert.is_true(settled:is_resolved())
      assert.equals("rejected", settled.result[1].status)
      assert.equals("rejected", settled.result[2].status)
    end)
  end)

  describe("AsyncEvent.resolved", function()
    it("creates already resolved event", function()
      local event = AsyncEvent.resolved("value")

      assert.is_true(event:is_resolved())
      assert.equals("value", event.result)
    end)

    it("has event_type 'resolved'", function()
      local event = AsyncEvent.resolved("value")

      assert.equals("resolved", event.event_type)
    end)
  end)

  describe("AsyncEvent.rejected", function()
    it("creates already rejected event", function()
      local event = AsyncEvent.rejected("error")

      assert.is_true(event:is_rejected())
      assert.equals("error", event.error)
    end)

    it("has event_type 'rejected'", function()
      local event = AsyncEvent.rejected("error")

      assert.equals("rejected", event.event_type)
    end)
  end)

  describe("AsyncEvent.delay", function()
    it("resolves immediately without timer function", function()
      local event = AsyncEvent.delay(100, nil)

      assert.is_true(event:is_resolved())
    end)

    it("calls timer function with callback", function()
      local timer_called = false
      local timer_delay = nil

      local timer_fn = function(callback, delay)
        timer_called = true
        timer_delay = delay
        callback()  -- Call immediately for testing
      end

      local event = AsyncEvent.delay(500, timer_fn)

      assert.is_true(timer_called)
      assert.equals(500, timer_delay)
      assert.is_true(event:is_resolved())
    end)

    it("has event_type 'delay'", function()
      local event = AsyncEvent.delay(100, nil)

      assert.equals("delay", event.event_type)
    end)
  end)

  describe("chaining", function()
    it("supports fluent chaining", function()
      local event = AsyncEvent.new()

      local result = event
        :then_do(function() end)
        :catch(function() end)
        :finally(function() end)

      assert.equals(event, result)
    end)

    it("calls callbacks in order", function()
      local event = AsyncEvent.new()
      local order = {}

      event:then_do(function() table.insert(order, 1) end)
      event:then_do(function() table.insert(order, 2) end)
      event:then_do(function() table.insert(order, 3) end)

      event:resolve("value")

      assert.same({ 1, 2, 3 }, order)
    end)
  end)
end)
