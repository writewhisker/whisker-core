-- spec/wls2/timed_content_spec.lua
-- Tests for WLS 2.0 Timed Content

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("TimedContent", function()
    local TimedContent

    before_each(function()
        TimedContent = require("whisker.wls2.timed_content")
    end)

    describe("parseTimeString", function()
        it("parses milliseconds", function()
            assert.equals(500, TimedContent.parseTimeString("500ms"))
        end)

        it("parses seconds", function()
            assert.equals(2000, TimedContent.parseTimeString("2s"))
        end)

        it("parses minutes", function()
            assert.equals(60000, TimedContent.parseTimeString("1m"))
        end)

        it("parses hours", function()
            assert.equals(3600000, TimedContent.parseTimeString("1h"))
        end)

        it("parses plain number", function()
            assert.equals(100, TimedContent.parseTimeString(100))
        end)

        it("throws for invalid string", function()
            assert.has_error(function()
                TimedContent.parseTimeString("invalid")
            end)
        end)

        it("throws for unknown unit", function()
            assert.has_error(function()
                TimedContent.parseTimeString("10x")
            end)
        end)
    end)

    describe("constants", function()
        it("defines timer states", function()
            assert.equals("pending", TimedContent.STATE.PENDING)
            assert.equals("running", TimedContent.STATE.RUNNING)
            assert.equals("paused", TimedContent.STATE.PAUSED)
            assert.equals("completed", TimedContent.STATE.COMPLETED)
            assert.equals("cancelled", TimedContent.STATE.CANCELLED)
        end)
    end)

    describe("manager", function()
        local manager

        before_each(function()
            manager = TimedContent.new()
        end)

        it("creates a new manager", function()
            assert.is_not_nil(manager)
        end)

        it("schedules one-shot timer", function()
            local timerId = manager:schedule(1000, {"content"})
            assert.is_not_nil(timerId)

            local timer = manager:getTimer(timerId)
            assert.equals("oneshot", timer.type)
            assert.equals(1000, timer.delay)
        end)

        it("schedules with time string", function()
            local timerId = manager:schedule("2s", {"content"})
            local timer = manager:getTimer(timerId)
            assert.equals(2000, timer.delay)
        end)

        it("fires one-shot timer", function()
            local content = {"test content"}
            local callbackFired = false

            manager:schedule(100, content, function(c)
                callbackFired = true
                assert.same(content, c)
            end)

            -- Update past the delay
            local fired = manager:update(150)
            assert.equals(1, #fired)
            assert.same(content, fired[1].content)
            assert.is_true(callbackFired)
        end)

        it("schedules repeating timer", function()
            local timerId = manager:every(500, {"content"}, 3)

            local timer = manager:getTimer(timerId)
            assert.equals("repeating", timer.type)
            assert.equals(500, timer.interval)
            assert.equals(3, timer.maxFires)
        end)

        it("fires repeating timer multiple times", function()
            local fireCount = 0
            manager:every(100, {"content"}, nil, function()
                fireCount = fireCount + 1
            end)

            manager:update(350)
            assert.equals(3, fireCount)
        end)

        it("respects max fires limit", function()
            local fireCount = 0
            manager:every(100, {"content"}, 2, function()
                fireCount = fireCount + 1
            end)

            manager:update(500)
            assert.equals(2, fireCount)
        end)

        it("cancels timer", function()
            local fired = false
            local timerId = manager:schedule(100, {"content"}, function()
                fired = true
            end)

            manager:cancel(timerId)
            manager:update(200)
            assert.is_false(fired)
        end)

        it("pauses and resumes timer", function()
            local fired = false
            local timerId = manager:schedule(100, {"content"}, function()
                fired = true
            end)

            manager:update(50)  -- Start the timer
            manager:pauseTimer(timerId)
            manager:update(100)  -- Should not fire while paused
            assert.is_false(fired)

            manager:resumeTimer(timerId)
            manager:update(100)  -- Should fire after resume
            assert.is_true(fired)
        end)

        it("pauses all timers globally", function()
            local fired = false
            manager:schedule(100, {"content"}, function()
                fired = true
            end)

            manager:pause()
            assert.is_true(manager:isPaused())

            manager:update(200)
            assert.is_false(fired)

            manager:resume()
            manager:update(200)
            assert.is_true(fired)
        end)

        it("gets active timers", function()
            manager:schedule(100, {"a"})
            manager:schedule(200, {"b"})
            local completedId = manager:schedule(10, {"c"})

            manager:update(50)  -- Complete the 10ms timer

            local active = manager:getActiveTimers()
            assert.equals(2, #active)
        end)

        it("gets timer counts by state", function()
            manager:schedule(100, {"a"})
            manager:schedule(100, {"b"})
            local cancelledId = manager:schedule(100, {"c"})
            manager:cancel(cancelledId)

            manager:update(0)  -- Move to running state

            local counts = manager:getTimerCounts()
            assert.equals(2, counts[TimedContent.STATE.RUNNING])
            assert.equals(1, counts[TimedContent.STATE.CANCELLED])
        end)

        it("tracks elapsed time", function()
            assert.equals(0, manager:getElapsed())

            manager:update(100)
            assert.equals(100, manager:getElapsed())

            manager:update(50)
            assert.equals(150, manager:getElapsed())
        end)

        it("cancels all timers", function()
            manager:schedule(100, {"a"})
            manager:schedule(200, {"b"})
            manager:schedule(300, {"c"})

            manager:cancelAll()

            local counts = manager:getTimerCounts()
            assert.equals(3, counts[TimedContent.STATE.CANCELLED])
        end)

        it("clears all state", function()
            manager:schedule(100, {"content"})
            manager:update(50)

            manager:clear()

            assert.equals(0, manager:getElapsed())
            assert.equals(0, #manager:getActiveTimers())
        end)
    end)
end)
