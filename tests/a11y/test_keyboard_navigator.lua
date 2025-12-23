--- Keyboard Navigator Tests
-- Tests for KeyboardNavigator implementation
-- @module tests.a11y.keyboard_navigator_spec

describe("KeyboardNavigator", function()
  local KeyboardNavigator
  local navigator
  local mock_event_bus
  local mock_focus_manager
  local mock_logger

  setup(function()
    KeyboardNavigator = require("whisker.a11y.keyboard_navigator")
  end)

  before_each(function()
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end,
    }

    mock_focus_manager = {
      focused_element = nil,
      focus = function(self, element)
        self.focused_element = element
        return true
      end,
      handle_tab = function(self, shift)
        return true
      end,
    }

    mock_logger = {
      debug = function() end,
    }

    navigator = KeyboardNavigator.new({
      event_bus = mock_event_bus,
      logger = mock_logger,
      focus_manager = mock_focus_manager,
    })
  end)

  describe("new()", function()
    it("should create a navigator instance", function()
      assert.is_not_nil(navigator)
      assert.is_table(navigator)
    end)

    it("should be enabled by default", function()
      assert.is_true(navigator:is_enabled())
    end)

    it("should default to browse mode", function()
      assert.equals("browse", navigator:get_mode())
    end)
  end)

  describe("handle_key_event()", function()
    it("should handle Tab key", function()
      local result = navigator:handle_key_event({key = "Tab"})
      assert.is_true(result)
    end)

    it("should handle Enter key", function()
      local result = navigator:handle_key_event({key = "Enter"})
      assert.is_true(result)
    end)

    it("should handle Escape key", function()
      local result = navigator:handle_key_event({key = "Escape"})
      assert.is_true(result)
    end)

    it("should handle Space key", function()
      local result = navigator:handle_key_event({key = "Space"})
      assert.is_true(result)
    end)

    it("should handle ArrowDown key", function()
      local result = navigator:handle_key_event({key = "ArrowDown"})
      -- Returns false when no choices set
      assert.is_false(result)
    end)

    it("should return false for unhandled keys", function()
      local result = navigator:handle_key_event({key = "X"})
      assert.is_false(result)
    end)

    it("should return false when disabled", function()
      navigator:disable()
      local result = navigator:handle_key_event({key = "Enter"})
      assert.is_false(result)
    end)

    it("should handle keyCode fallback", function()
      local result = navigator:handle_key_event({keyCode = 13}) -- Enter
      assert.is_true(result)
    end)
  end)

  describe("enable() / disable()", function()
    it("should toggle enabled state", function()
      navigator:disable()
      assert.is_false(navigator:is_enabled())

      navigator:enable()
      assert.is_true(navigator:is_enabled())
    end)

    it("should emit events on state change", function()
      navigator:disable()
      navigator:enable()

      assert.equals(2, #mock_event_bus.events)
      assert.equals("a11y.keyboard_disabled", mock_event_bus.events[1].event)
      assert.equals("a11y.keyboard_enabled", mock_event_bus.events[2].event)
    end)
  end)

  describe("set_mode()", function()
    it("should set mode to focus", function()
      navigator:set_mode("focus")
      assert.equals("focus", navigator:get_mode())
    end)

    it("should set mode to browse", function()
      navigator:set_mode("browse")
      assert.equals("browse", navigator:get_mode())
    end)

    it("should ignore invalid modes", function()
      navigator:set_mode("invalid")
      assert.equals("browse", navigator:get_mode())
    end)

    it("should emit mode_changed event", function()
      navigator:set_mode("focus")

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "a11y.mode_changed" then
          found = true
          assert.equals("focus", e.data.mode)
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("set_choices()", function()
    it("should store choice list", function()
      local choices = {{id = "1"}, {id = "2"}, {id = "3"}}
      navigator:set_choices(choices)

      assert.equals(1, navigator:get_current_choice_index())
    end)

    it("should handle empty choices", function()
      navigator:set_choices({})
      assert.equals(0, navigator:get_current_choice_index())
    end)
  end)

  describe("arrow key navigation", function()
    local choices

    before_each(function()
      choices = {
        {id = "1", text = "Choice 1"},
        {id = "2", text = "Choice 2"},
        {id = "3", text = "Choice 3"},
      }
      navigator:set_choices(choices)
    end)

    it("should navigate down through choices", function()
      assert.equals(1, navigator:get_current_choice_index())

      navigator:handle_key_event({key = "ArrowDown"})
      assert.equals(2, navigator:get_current_choice_index())

      navigator:handle_key_event({key = "ArrowDown"})
      assert.equals(3, navigator:get_current_choice_index())
    end)

    it("should wrap to first choice after last", function()
      navigator:set_choices(choices)
      navigator:handle_key_event({key = "End"})
      assert.equals(3, navigator:get_current_choice_index())

      navigator:handle_key_event({key = "ArrowDown"})
      assert.equals(1, navigator:get_current_choice_index())
    end)

    it("should navigate up through choices", function()
      navigator:set_choices(choices)
      navigator:handle_key_event({key = "End"})

      navigator:handle_key_event({key = "ArrowUp"})
      assert.equals(2, navigator:get_current_choice_index())
    end)

    it("should wrap to last choice before first", function()
      assert.equals(1, navigator:get_current_choice_index())

      navigator:handle_key_event({key = "ArrowUp"})
      assert.equals(3, navigator:get_current_choice_index())
    end)

    it("should jump to first choice with Home", function()
      navigator:handle_key_event({key = "End"})
      navigator:handle_key_event({key = "Home"})

      assert.equals(1, navigator:get_current_choice_index())
    end)

    it("should jump to last choice with End", function()
      navigator:handle_key_event({key = "End"})

      assert.equals(3, navigator:get_current_choice_index())
    end)

    it("should emit choice_focused event", function()
      mock_event_bus.events = {}
      navigator:handle_key_event({key = "ArrowDown"})

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "a11y.choice_focused" then
          found = true
          assert.equals(2, e.data.index)
          assert.equals(3, e.data.total)
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("register_handler()", function()
    it("should allow custom key handlers", function()
      local handled = false
      navigator:register_handler("F1", function()
        handled = true
        return true
      end)

      navigator:handle_key_event({key = "F1"})
      assert.is_true(handled)
    end)

    it("should allow multiple handlers for same key", function()
      local count = 0
      navigator:register_handler("F2", function()
        count = count + 1
        return false -- Don't stop propagation
      end)
      navigator:register_handler("F2", function()
        count = count + 1
        return true -- Stop propagation
      end)

      navigator:handle_key_event({key = "F2"})
      assert.equals(2, count)
    end)
  end)

  describe("get_handled_keys()", function()
    it("should return list of handled keys", function()
      local keys = navigator:get_handled_keys()

      assert.is_table(keys)
      assert.is_true(#keys > 0)
    end)
  end)

  describe("create_event()", function()
    it("should normalize DOM-like event", function()
      local event = KeyboardNavigator.create_event({
        key = "Enter",
        shiftKey = true,
        ctrlKey = false,
      })

      assert.equals("Enter", event.key)
      assert.is_true(event.shift)
      assert.is_false(event.ctrl)
    end)
  end)

  describe("get_key_code()", function()
    it("should return key code for known keys", function()
      assert.equals(13, KeyboardNavigator.get_key_code("Enter"))
      assert.equals(27, KeyboardNavigator.get_key_code("Escape"))
      assert.equals(9, KeyboardNavigator.get_key_code("Tab"))
    end)

    it("should return nil for unknown keys", function()
      assert.is_nil(KeyboardNavigator.get_key_code("Unknown"))
    end)
  end)
end)
