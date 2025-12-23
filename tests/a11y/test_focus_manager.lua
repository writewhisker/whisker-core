--- Focus Manager Tests
-- Tests for FocusManager implementation
-- @module tests.a11y.focus_manager_spec

describe("FocusManager", function()
  local FocusManager
  local manager
  local mock_event_bus
  local mock_logger

  setup(function()
    FocusManager = require("whisker.a11y.focus_manager")
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

    manager = FocusManager.new({
      event_bus = mock_event_bus,
      logger = mock_logger,
    })
  end)

  describe("new()", function()
    it("should create a manager instance", function()
      assert.is_not_nil(manager)
      assert.is_table(manager)
    end)

    it("should not have focus trapped by default", function()
      assert.is_false(manager:is_focus_trapped())
    end)
  end)

  describe("focus()", function()
    it("should focus an element with focus method", function()
      local focused = false
      local element = {
        focus = function()
          focused = true
        end,
      }

      local result = manager:focus(element)

      assert.is_true(result)
      assert.is_true(focused)
    end)

    it("should return false for nil element", function()
      local result = manager:focus(nil)
      assert.is_false(result)
    end)

    it("should emit focus_change event", function()
      local element = {focus = function() end}
      manager:focus(element)

      assert.equals(1, #mock_event_bus.events)
      assert.equals("a11y.focus_change", mock_event_bus.events[1].event)
    end)

    it("should track focused element", function()
      local element = {focus = function() end}
      manager:focus(element)

      assert.equals(element, manager:get_focused_element())
    end)
  end)

  describe("save_focus() / restore_focus()", function()
    it("should save and restore focus", function()
      local element = {focus = function() end}
      manager:focus(element)

      manager:save_focus("test")

      -- Focus something else
      local other = {focus = function() end}
      manager:focus(other)

      -- Restore
      local result = manager:restore_focus("test")
      assert.is_true(result)
    end)

    it("should use default key when not specified", function()
      local element = {focus = function() end}
      manager:focus(element)

      manager:save_focus()
      manager:restore_focus()

      -- Should not throw error
      assert.is_true(true)
    end)

    it("should return false when no saved focus", function()
      local result = manager:restore_focus("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("trap_focus()", function()
    it("should enable focus trapping", function()
      local container = {
        get_focusable_children = function()
          return {}
        end,
      }

      manager:trap_focus(container)

      assert.is_true(manager:is_focus_trapped())
    end)

    it("should emit focus_trap_enabled event", function()
      local container = {
        get_focusable_children = function()
          return {}
        end,
      }

      manager:trap_focus(container)

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "a11y.focus_trap_enabled" then
          found = true
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("release_focus_trap()", function()
    it("should release focus trap", function()
      local container = {
        get_focusable_children = function()
          return {}
        end,
      }

      manager:trap_focus(container)
      manager:release_focus_trap()

      assert.is_false(manager:is_focus_trapped())
    end)

    it("should emit focus_trap_released event", function()
      local container = {
        get_focusable_children = function()
          return {}
        end,
      }

      manager:trap_focus(container)
      mock_event_bus.events = {}
      manager:release_focus_trap()

      assert.equals("a11y.focus_trap_released", mock_event_bus.events[1].event)
    end)
  end)

  describe("get_focusable_elements()", function()
    it("should return empty array for nil container", function()
      local result = manager:get_focusable_elements(nil)
      assert.equals(0, #result)
    end)

    it("should use get_focusable_children if available", function()
      local elements = {{id = 1}, {id = 2}}
      local container = {
        get_focusable_children = function()
          return elements
        end,
      }

      local result = manager:get_focusable_elements(container)
      assert.equals(2, #result)
    end)
  end)

  describe("focus_first() / focus_last()", function()
    it("should focus first element", function()
      local focused_id = nil
      local elements = {
        {id = 1, focus = function(self) focused_id = self.id end},
        {id = 2, focus = function(self) focused_id = self.id end},
      }
      local container = {
        get_focusable_children = function()
          return elements
        end,
      }

      manager:focus_first(container)
      assert.equals(1, focused_id)
    end)

    it("should focus last element", function()
      local focused_id = nil
      local elements = {
        {id = 1, focus = function(self) focused_id = self.id end},
        {id = 2, focus = function(self) focused_id = self.id end},
      }
      local container = {
        get_focusable_children = function()
          return elements
        end,
      }

      manager:focus_last(container)
      assert.equals(2, focused_id)
    end)

    it("should return false for empty container", function()
      local container = {
        get_focusable_children = function()
          return {}
        end,
      }

      assert.is_false(manager:focus_first(container))
      assert.is_false(manager:focus_last(container))
    end)
  end)

  describe("handle_tab()", function()
    it("should return false when not trapped", function()
      assert.is_false(manager:handle_tab(false))
    end)

    it("should call focus_next when not shift", function()
      local elements = {
        {id = 1, focus = function() end},
        {id = 2, focus = function() end},
      }
      local container = {
        get_focusable_children = function()
          return elements
        end,
      }

      manager:trap_focus(container)
      local result = manager:handle_tab(false)
      assert.is_true(result)
    end)

    it("should call focus_previous when shift", function()
      local elements = {
        {id = 1, focus = function() end},
        {id = 2, focus = function() end},
      }
      local container = {
        get_focusable_children = function()
          return elements
        end,
      }

      manager:trap_focus(container)
      local result = manager:handle_tab(true)
      assert.is_true(result)
    end)
  end)

  describe("get_focusable_selector()", function()
    it("should return CSS selector string", function()
      local selector = manager:get_focusable_selector()
      assert.is_string(selector)
      assert.truthy(selector:match("button"))
    end)
  end)
end)
