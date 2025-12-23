--- Accessibility Interfaces Tests
-- Tests for accessibility interface definitions
-- @module tests.a11y.interfaces_spec

describe("Accessibility Interfaces", function()
  local IAccessible
  local IKeyboardHandler
  local IScreenReaderAdapter
  local IFocusManager

  setup(function()
    IAccessible = require("whisker.interfaces.accessible")
    IKeyboardHandler = require("whisker.interfaces.keyboard_handler")
    IScreenReaderAdapter = require("whisker.interfaces.screen_reader")
    IFocusManager = require("whisker.interfaces.focus_manager")
  end)

  describe("IAccessible", function()
    it("should define get_accessible_name method", function()
      assert.is_function(IAccessible.get_accessible_name)
    end)

    it("should define get_role method", function()
      assert.is_function(IAccessible.get_role)
    end)

    it("should define get_accessible_description method", function()
      assert.is_function(IAccessible.get_accessible_description)
    end)

    it("should define is_focusable method", function()
      assert.is_function(IAccessible.is_focusable)
    end)

    it("should define is_disabled method", function()
      assert.is_function(IAccessible.is_disabled)
    end)

    it("should define get_state method", function()
      assert.is_function(IAccessible.get_state)
    end)

    it("should define get_aria_attributes method", function()
      assert.is_function(IAccessible.get_aria_attributes)
    end)

    it("should define get_keyboard_shortcuts method", function()
      assert.is_function(IAccessible.get_keyboard_shortcuts)
    end)

    it("should define announce method", function()
      assert.is_function(IAccessible.announce)
    end)

    it("should throw error when calling unimplemented methods", function()
      assert.has_error(function()
        IAccessible:get_accessible_name()
      end)
    end)
  end)

  describe("IKeyboardHandler", function()
    it("should define handle_key_event method", function()
      assert.is_function(IKeyboardHandler.handle_key_event)
    end)

    it("should define get_handled_keys method", function()
      assert.is_function(IKeyboardHandler.get_handled_keys)
    end)

    it("should define is_enabled method", function()
      assert.is_function(IKeyboardHandler.is_enabled)
    end)

    it("should define enable method", function()
      assert.is_function(IKeyboardHandler.enable)
    end)

    it("should define disable method", function()
      assert.is_function(IKeyboardHandler.disable)
    end)

    it("should define get_mode method", function()
      assert.is_function(IKeyboardHandler.get_mode)
    end)

    it("should define set_mode method", function()
      assert.is_function(IKeyboardHandler.set_mode)
    end)

    it("should throw error when calling unimplemented methods", function()
      assert.has_error(function()
        IKeyboardHandler:handle_key_event({})
      end)
    end)
  end)

  describe("IScreenReaderAdapter", function()
    it("should define announce method", function()
      assert.is_function(IScreenReaderAdapter.announce)
    end)

    it("should define clear_announcements method", function()
      assert.is_function(IScreenReaderAdapter.clear_announcements)
    end)

    it("should define get_live_region method", function()
      assert.is_function(IScreenReaderAdapter.get_live_region)
    end)

    it("should define create_live_regions method", function()
      assert.is_function(IScreenReaderAdapter.create_live_regions)
    end)

    it("should define announce_passage_change method", function()
      assert.is_function(IScreenReaderAdapter.announce_passage_change)
    end)

    it("should define announce_choice_selection method", function()
      assert.is_function(IScreenReaderAdapter.announce_choice_selection)
    end)

    it("should define announce_error method", function()
      assert.is_function(IScreenReaderAdapter.announce_error)
    end)

    it("should define announce_loading method", function()
      assert.is_function(IScreenReaderAdapter.announce_loading)
    end)
  end)

  describe("IFocusManager", function()
    it("should define focus method", function()
      assert.is_function(IFocusManager.focus)
    end)

    it("should define get_focused_element method", function()
      assert.is_function(IFocusManager.get_focused_element)
    end)

    it("should define save_focus method", function()
      assert.is_function(IFocusManager.save_focus)
    end)

    it("should define restore_focus method", function()
      assert.is_function(IFocusManager.restore_focus)
    end)

    it("should define trap_focus method", function()
      assert.is_function(IFocusManager.trap_focus)
    end)

    it("should define release_focus_trap method", function()
      assert.is_function(IFocusManager.release_focus_trap)
    end)

    it("should define is_focus_trapped method", function()
      assert.is_function(IFocusManager.is_focus_trapped)
    end)

    it("should define get_focusable_elements method", function()
      assert.is_function(IFocusManager.get_focusable_elements)
    end)

    it("should define focus_first method", function()
      assert.is_function(IFocusManager.focus_first)
    end)

    it("should define focus_last method", function()
      assert.is_function(IFocusManager.focus_last)
    end)

    it("should define focus_next method", function()
      assert.is_function(IFocusManager.focus_next)
    end)

    it("should define focus_previous method", function()
      assert.is_function(IFocusManager.focus_previous)
    end)
  end)
end)
