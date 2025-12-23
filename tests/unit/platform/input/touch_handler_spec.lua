--- TouchHandler Tests
--- Tests for touch gesture recognition.

describe("TouchHandler", function()
  local TouchHandler

  before_each(function()
    package.loaded["whisker.platform.input.touch_handler"] = nil
    TouchHandler = require("whisker.platform.input.touch_handler")
  end)

  describe("new", function()
    it("creates handler with default configuration", function()
      local handler = TouchHandler.new()
      assert.is_not_nil(handler)
      assert.equals(500, handler.long_press_duration)
      assert.equals(50, handler.swipe_threshold)
    end)

    it("accepts custom configuration", function()
      local handler = TouchHandler.new({
        long_press_duration = 1000,
        swipe_threshold = 100,
      })
      assert.equals(1000, handler.long_press_duration)
      assert.equals(100, handler.swipe_threshold)
    end)
  end)

  describe("tap gesture", function()
    it("recognizes simple tap", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        tap_timeout = 300,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(100, 100, 100)  -- 100ms later, same position

      assert.equals(1, #events)
      assert.equals("tap", events[1].type)
      assert.equals(100, events[1].data.x)
      assert.equals(100, events[1].data.y)
    end)

    it("recognizes tap with small movement", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        move_tolerance = 10,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_move(105, 105, 50)  -- 5 pixel movement
      handler:on_touch_end(105, 105, 100)

      assert.equals(1, #events)
      assert.equals("tap", events[1].type)
    end)

    it("does not trigger tap for long press", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        tap_timeout = 300,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(100, 100, 500)  -- 500ms later (too long)

      -- With no timer support, only tap timeout is checked
      assert.equals(0, #events)
    end)
  end)

  describe("swipe gesture", function()
    it("recognizes right swipe", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        swipe_threshold = 50,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(200, 100, 100)  -- 100 pixels right

      assert.equals(1, #events)
      assert.equals("swipe", events[1].type)
      assert.equals("right", events[1].data.direction)
    end)

    it("recognizes left swipe", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
      })

      handler:on_touch_start(200, 100, 0)
      handler:on_touch_end(100, 100, 100)  -- 100 pixels left

      assert.equals(1, #events)
      assert.equals("swipe", events[1].type)
      assert.equals("left", events[1].data.direction)
    end)

    it("recognizes up swipe", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
      })

      handler:on_touch_start(100, 200, 0)
      handler:on_touch_end(100, 100, 100)  -- 100 pixels up

      assert.equals(1, #events)
      assert.equals("swipe", events[1].type)
      assert.equals("up", events[1].data.direction)
    end)

    it("recognizes down swipe", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(100, 200, 100)  -- 100 pixels down

      assert.equals(1, #events)
      assert.equals("swipe", events[1].type)
      assert.equals("down", events[1].data.direction)
    end)

    it("includes swipe data", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(200, 100, 100)

      local data = events[1].data
      assert.equals(100, data.start_x)
      assert.equals(100, data.start_y)
      assert.equals(200, data.end_x)
      assert.equals(100, data.end_y)
      assert.equals(100, data.distance)
      assert.is_number(data.velocity)
    end)

    it("does not trigger for short movements", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        swipe_threshold = 50,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_end(120, 100, 100)  -- Only 20 pixels

      -- Should be a tap, not a swipe
      assert.equals(1, #events)
      assert.equals("tap", events[1].type)
    end)
  end)

  describe("long press gesture", function()
    it("triggers with timer support", function()
      local events = {}
      local timer_callback = nil

      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        long_press_duration = 500,
        set_timeout = function(ms, callback)
          timer_callback = callback
          return 1  -- Timer ID
        end,
        cancel_timeout = function(id) end,
      })

      handler:on_touch_start(100, 100, 0)

      -- Simulate timer firing
      if timer_callback then
        timer_callback()
      end

      assert.equals(1, #events)
      assert.equals("long_press", events[1].type)
      assert.equals(100, events[1].data.x)
      assert.equals(100, events[1].data.y)
    end)

    it("cancels on movement", function()
      local events = {}
      local timer_cancelled = false
      local timer_callback = nil

      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
        move_tolerance = 10,
        set_timeout = function(ms, callback)
          timer_callback = callback
          return 1
        end,
        cancel_timeout = function(id)
          timer_cancelled = true
        end,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_move(150, 100, 100)  -- Move 50 pixels

      assert.is_true(timer_cancelled)
    end)
  end)

  describe("touch cancel", function()
    it("resets state on cancel", function()
      local events = {}
      local handler = TouchHandler.new({
        on_gesture = function(type, data)
          table.insert(events, {type = type, data = data})
        end,
      })

      handler:on_touch_start(100, 100, 0)
      handler:on_touch_cancel()
      handler:on_touch_end(100, 100, 100)  -- Should not trigger anything

      assert.equals(0, #events)
    end)
  end)

  describe("configure", function()
    it("updates configuration at runtime", function()
      local handler = TouchHandler.new({
        swipe_threshold = 50,
      })

      handler:configure({
        swipe_threshold = 100,
        tap_timeout = 200,
      })

      assert.equals(100, handler.swipe_threshold)
      assert.equals(200, handler.tap_timeout)
    end)
  end)

  describe("constants", function()
    it("defines gesture types", function()
      assert.equals("tap", TouchHandler.GESTURE.TAP)
      assert.equals("long_press", TouchHandler.GESTURE.LONG_PRESS)
      assert.equals("swipe", TouchHandler.GESTURE.SWIPE)
      assert.equals("pinch", TouchHandler.GESTURE.PINCH)
    end)

    it("defines directions", function()
      assert.equals("left", TouchHandler.DIRECTION.LEFT)
      assert.equals("right", TouchHandler.DIRECTION.RIGHT)
      assert.equals("up", TouchHandler.DIRECTION.UP)
      assert.equals("down", TouchHandler.DIRECTION.DOWN)
    end)
  end)
end)
