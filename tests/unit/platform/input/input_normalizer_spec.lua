--- InputNormalizer Tests
--- Tests for input normalization.

describe("InputNormalizer", function()
  local InputNormalizer

  before_each(function()
    package.loaded["whisker.platform.input.input_normalizer"] = nil
    InputNormalizer = require("whisker.platform.input.input_normalizer")
  end)

  describe("new", function()
    it("creates normalizer", function()
      local normalizer = InputNormalizer.new()
      assert.is_not_nil(normalizer)
    end)
  end)

  describe("event subscription", function()
    it("registers listeners with on()", function()
      local normalizer = InputNormalizer.new()
      local called = false

      normalizer:on("select", function()
        called = true
      end)

      normalizer:trigger("select", {})
      assert.is_true(called)
    end)

    it("returns unsubscribe function", function()
      local normalizer = InputNormalizer.new()
      local count = 0

      local unsub = normalizer:on("select", function()
        count = count + 1
      end)

      normalizer:trigger("select", {})
      assert.equals(1, count)

      unsub()  -- Unsubscribe

      normalizer:trigger("select", {})
      assert.equals(1, count)  -- Should not have been called again
    end)

    it("unregisters with off()", function()
      local normalizer = InputNormalizer.new()
      local count = 0
      local listener = function()
        count = count + 1
      end

      normalizer:on("select", listener)
      normalizer:trigger("select", {})
      assert.equals(1, count)

      normalizer:off("select", listener)
      normalizer:trigger("select", {})
      assert.equals(1, count)
    end)

    it("supports multiple listeners", function()
      local normalizer = InputNormalizer.new()
      local calls = {}

      normalizer:on("select", function() table.insert(calls, "a") end)
      normalizer:on("select", function() table.insert(calls, "b") end)

      normalizer:trigger("select", {})

      assert.equals(2, #calls)
      assert.equals("a", calls[1])
      assert.equals("b", calls[2])
    end)
  end)

  describe("mouse input", function()
    it("normalizes left click to select", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("select", function(data)
        event = data
      end)

      normalizer:on_mouse_click(100, 200, "left")

      assert.is_not_nil(event)
      assert.equals(100, event.x)
      assert.equals(200, event.y)
      assert.equals("mouse", event.source)
    end)

    it("normalizes right click to context_menu", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("context_menu", function(data)
        event = data
      end)

      normalizer:on_mouse_click(100, 200, "right")

      assert.is_not_nil(event)
      assert.equals("mouse", event.source)
    end)

    it("normalizes scroll to scroll event", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("scroll", function(data)
        event = data
      end)

      -- Positive delta_y = scroll up (content moves down)
      normalizer:on_mouse_scroll(0, 10)

      assert.is_not_nil(event)
      assert.equals("mouse", event.source)
      assert.equals("up", event.direction)
    end)
  end)

  describe("touch input", function()
    it("normalizes tap to select", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("select", function(data)
        event = data
      end)

      normalizer:on_touch_tap(150, 250)

      assert.is_not_nil(event)
      assert.equals(150, event.x)
      assert.equals(250, event.y)
      assert.equals("touch", event.source)
    end)

    it("normalizes long-press to context_menu", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("context_menu", function(data)
        event = data
      end)

      normalizer:on_touch_long_press(150, 250)

      assert.is_not_nil(event)
      assert.equals("touch", event.source)
    end)

    it("normalizes horizontal swipe to navigate", function()
      local normalizer = InputNormalizer.new()
      local events = {}

      normalizer:on("navigate", function(data)
        table.insert(events, data)
      end)

      normalizer:on_swipe("left", 100)
      assert.equals(1, #events)
      assert.equals("forward", events[1].direction)

      normalizer:on_swipe("right", 100)
      assert.equals(2, #events)
      assert.equals("back", events[2].direction)
    end)

    it("normalizes vertical swipe to scroll", function()
      local normalizer = InputNormalizer.new()
      local events = {}

      normalizer:on("scroll", function(data)
        table.insert(events, data)
      end)

      normalizer:on_swipe("up", 100)
      assert.equals(1, #events)
      assert.equals("up", events[1].direction)

      normalizer:on_swipe("down", 100)
      assert.equals(2, #events)
      assert.equals("down", events[2].direction)
    end)
  end)

  describe("keyboard input", function()
    it("normalizes Enter to select", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("select", function(data)
        event = data
      end)

      normalizer:on_key_press("Enter")

      assert.is_not_nil(event)
      assert.equals("keyboard", event.source)
    end)

    it("normalizes Space to select", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("select", function(data)
        event = data
      end)

      normalizer:on_key_press("Space")

      assert.is_not_nil(event)
    end)

    it("normalizes Escape to cancel", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("cancel", function(data)
        event = data
      end)

      normalizer:on_key_press("Escape")

      assert.is_not_nil(event)
      assert.equals("keyboard", event.source)
    end)

    it("normalizes arrow keys to navigate", function()
      local normalizer = InputNormalizer.new()
      local events = {}

      normalizer:on("navigate", function(data)
        table.insert(events, data)
      end)

      normalizer:on_key_press("ArrowUp")
      normalizer:on_key_press("ArrowDown")
      normalizer:on_key_press("ArrowLeft")
      normalizer:on_key_press("ArrowRight")

      assert.equals(4, #events)
      assert.equals("up", events[1].direction)
      assert.equals("down", events[2].direction)
      assert.equals("left", events[3].direction)
      assert.equals("right", events[4].direction)
    end)

    it("normalizes Tab to navigate", function()
      local normalizer = InputNormalizer.new()
      local events = {}

      normalizer:on("navigate", function(data)
        table.insert(events, data)
      end)

      normalizer:on_key_press("Tab", {})
      assert.equals("forward", events[1].direction)

      normalizer:on_key_press("Tab", {shift = true})
      assert.equals("back", events[2].direction)
    end)

    it("handles text input", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("text_input", function(data)
        event = data
      end)

      normalizer:on_text_input("hello")

      assert.is_not_nil(event)
      assert.equals("hello", event.text)
    end)
  end)

  describe("gamepad input", function()
    it("normalizes A button to select", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("select", function(data)
        event = data
      end)

      normalizer:on_gamepad_button("A")

      assert.is_not_nil(event)
      assert.equals("gamepad", event.source)
    end)

    it("normalizes B button to cancel", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("cancel", function(data)
        event = data
      end)

      normalizer:on_gamepad_button("B")

      assert.is_not_nil(event)
    end)

    it("normalizes D-pad to navigate", function()
      local normalizer = InputNormalizer.new()
      local event = nil

      normalizer:on("navigate", function(data)
        event = data
      end)

      normalizer:on_gamepad_direction("up")

      assert.is_not_nil(event)
      assert.equals("up", event.direction)
      assert.equals("gamepad", event.source)
    end)
  end)

  describe("focus management", function()
    it("tracks focus index", function()
      local normalizer = InputNormalizer.new()
      normalizer:set_focus_max(5)

      assert.equals(0, normalizer:get_focus_index())

      normalizer:set_focus_index(3)
      assert.equals(3, normalizer:get_focus_index())
    end)

    it("clamps focus index to valid range", function()
      local normalizer = InputNormalizer.new()
      normalizer:set_focus_max(5)

      normalizer:set_focus_index(10)  -- Too high
      assert.equals(0, normalizer:get_focus_index())  -- Should stay at 0

      normalizer:set_focus_index(-1)  -- Too low
      assert.equals(0, normalizer:get_focus_index())  -- Should stay at 0
    end)

    it("moves focus in direction", function()
      local normalizer = InputNormalizer.new()
      normalizer:set_focus_max(5)
      normalizer:set_focus_index(2)

      normalizer:move_focus("down")
      assert.equals(3, normalizer:get_focus_index())

      normalizer:move_focus("up")
      assert.equals(2, normalizer:get_focus_index())
    end)

    it("clamps focus movement to bounds", function()
      local normalizer = InputNormalizer.new()
      normalizer:set_focus_max(3)
      normalizer:set_focus_index(0)

      normalizer:move_focus("up")
      assert.equals(0, normalizer:get_focus_index())  -- Can't go below 0

      normalizer:set_focus_index(3)
      normalizer:move_focus("down")
      assert.equals(3, normalizer:get_focus_index())  -- Can't go above max
    end)
  end)

  describe("clear", function()
    it("removes all listeners", function()
      local normalizer = InputNormalizer.new()
      local called = false

      normalizer:on("select", function() called = true end)
      normalizer:clear()
      normalizer:trigger("select", {})

      assert.is_false(called)
    end)
  end)

  describe("constants", function()
    it("defines event types", function()
      assert.equals("select", InputNormalizer.EVENT.SELECT)
      assert.equals("context_menu", InputNormalizer.EVENT.CONTEXT_MENU)
      assert.equals("navigate", InputNormalizer.EVENT.NAVIGATE)
      assert.equals("scroll", InputNormalizer.EVENT.SCROLL)
      assert.equals("cancel", InputNormalizer.EVENT.CANCEL)
    end)

    it("defines directions", function()
      assert.equals("up", InputNormalizer.DIRECTION.UP)
      assert.equals("down", InputNormalizer.DIRECTION.DOWN)
      assert.equals("left", InputNormalizer.DIRECTION.LEFT)
      assert.equals("right", InputNormalizer.DIRECTION.RIGHT)
    end)

    it("defines sources", function()
      assert.equals("mouse", InputNormalizer.SOURCE.MOUSE)
      assert.equals("touch", InputNormalizer.SOURCE.TOUCH)
      assert.equals("keyboard", InputNormalizer.SOURCE.KEYBOARD)
      assert.equals("gamepad", InputNormalizer.SOURCE.GAMEPAD)
    end)
  end)
end)
