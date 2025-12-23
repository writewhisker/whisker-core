--- ARIA Manager Tests
-- Tests for AriaManager implementation
-- @module tests.a11y.aria_manager_spec

describe("AriaManager", function()
  local AriaManager
  local manager

  setup(function()
    AriaManager = require("whisker.a11y.aria_manager")
  end)

  before_each(function()
    manager = AriaManager.new({})
  end)

  describe("new()", function()
    it("should create a manager instance", function()
      assert.is_not_nil(manager)
      assert.is_table(manager)
    end)
  end)

  describe("get_passage_aria()", function()
    it("should return role and label", function()
      local passage = {id = "test", title = "Test Passage"}
      local attrs = manager:get_passage_aria(passage, false)

      assert.equals("article", attrs.role)
      assert.equals("Test Passage", attrs["aria-label"])
    end)

    it("should set aria-current for current passage", function()
      local passage = {id = "test", title = "Test"}
      local attrs = manager:get_passage_aria(passage, true)

      assert.equals("page", attrs["aria-current"])
    end)

    it("should fallback to passage ID if no title", function()
      local passage = {id = "test-id"}
      local attrs = manager:get_passage_aria(passage, false)

      assert.truthy(attrs["aria-label"]:match("test%-id"))
    end)
  end)

  describe("get_choice_list_aria()", function()
    it("should return listbox role", function()
      local choices = {{}, {}, {}}
      local attrs = manager:get_choice_list_aria(choices)

      assert.equals("listbox", attrs.role)
    end)

    it("should include choice count in label", function()
      local choices = {{}, {}, {}}
      local attrs = manager:get_choice_list_aria(choices)

      assert.truthy(attrs["aria-label"]:match("3"))
    end)

    it("should handle singular choice", function()
      local choices = {{}}
      local attrs = manager:get_choice_list_aria(choices)

      assert.truthy(attrs["aria-label"]:match("1 choice"))
    end)
  end)

  describe("get_choice_aria()", function()
    it("should return option role", function()
      local choice = {text = "Go north"}
      local attrs = manager:get_choice_aria(choice, 1, 3, false)

      assert.equals("option", attrs.role)
    end)

    it("should include position info", function()
      local choice = {text = "Go north"}
      local attrs = manager:get_choice_aria(choice, 2, 5, false)

      assert.equals("2", attrs["aria-posinset"])
      assert.equals("5", attrs["aria-setsize"])
    end)

    it("should set aria-selected for selected choice", function()
      local choice = {text = "Go north"}
      local attrs = manager:get_choice_aria(choice, 1, 3, true)

      assert.equals("true", attrs["aria-selected"])
      assert.equals("0", attrs.tabindex)
    end)

    it("should set tabindex -1 for non-selected", function()
      local choice = {text = "Go north"}
      local attrs = manager:get_choice_aria(choice, 1, 3, false)

      assert.equals("-1", attrs.tabindex)
    end)
  end)

  describe("get_dialog_aria()", function()
    it("should return dialog role", function()
      local attrs = manager:get_dialog_aria("Settings")

      assert.equals("dialog", attrs.role)
      assert.equals("true", attrs["aria-modal"])
    end)

    it("should include description if provided", function()
      local attrs = manager:get_dialog_aria("Settings", "desc-id")

      assert.equals("desc-id", attrs["aria-describedby"])
    end)
  end)

  describe("get_navigation_aria()", function()
    it("should return navigation role", function()
      local attrs = manager:get_navigation_aria("Story controls")

      assert.equals("navigation", attrs.role)
      assert.equals("Story controls", attrs["aria-label"])
    end)
  end)

  describe("get_button_aria()", function()
    it("should return button role", function()
      local attrs = manager:get_button_aria("Save")

      assert.equals("button", attrs.role)
      assert.equals("Save", attrs["aria-label"])
    end)

    it("should include pressed state for toggle buttons", function()
      local attrs = manager:get_button_aria("Mute", true)

      assert.equals("true", attrs["aria-pressed"])
    end)

    it("should include disabled state", function()
      local attrs = manager:get_button_aria("Submit", nil, true)

      assert.equals("true", attrs["aria-disabled"])
    end)
  end)

  describe("get_live_region_aria()", function()
    it("should set aria-live property", function()
      local attrs = manager:get_live_region_aria("polite", true)

      assert.equals("polite", attrs["aria-live"])
      assert.equals("true", attrs["aria-atomic"])
    end)

    it("should default to polite", function()
      local attrs = manager:get_live_region_aria()

      assert.equals("polite", attrs["aria-live"])
    end)
  end)

  describe("get_loading_aria()", function()
    it("should set aria-busy when loading", function()
      local attrs = manager:get_loading_aria(true)

      assert.equals("true", attrs["aria-busy"])
    end)

    it("should unset aria-busy when not loading", function()
      local attrs = manager:get_loading_aria(false)

      assert.equals("false", attrs["aria-busy"])
    end)
  end)

  describe("get_heading_aria()", function()
    it("should set heading role and level", function()
      local attrs = manager:get_heading_aria(2)

      assert.equals("heading", attrs.role)
      assert.equals("2", attrs["aria-level"])
    end)
  end)

  describe("get_skip_link_aria()", function()
    it("should return skip link attributes", function()
      local attrs = manager:get_skip_link_aria("main-content")

      assert.equals("#main-content", attrs.href)
      assert.equals("Skip to main content", attrs["aria-label"])
    end)
  end)

  describe("get_main_aria()", function()
    it("should return main role", function()
      local attrs = manager:get_main_aria()

      assert.equals("main", attrs.role)
    end)

    it("should include label if provided", function()
      local attrs = manager:get_main_aria("Story content")

      assert.equals("Story content", attrs["aria-label"])
    end)
  end)

  describe("is_valid_role()", function()
    it("should return true for valid roles", function()
      assert.is_true(manager:is_valid_role("button"))
      assert.is_true(manager:is_valid_role("dialog"))
      assert.is_true(manager:is_valid_role("listbox"))
    end)

    it("should return false for invalid roles", function()
      assert.is_false(manager:is_valid_role("invalid"))
      assert.is_false(manager:is_valid_role("widget"))
    end)
  end)

  describe("is_valid_aria_attribute()", function()
    it("should return true for valid attributes", function()
      assert.is_true(manager:is_valid_aria_attribute("aria-label"))
      assert.is_true(manager:is_valid_aria_attribute("aria-hidden"))
    end)

    it("should return false for invalid attributes", function()
      assert.is_false(manager:is_valid_aria_attribute("aria-invalid-attr"))
    end)
  end)

  describe("to_html_attrs()", function()
    it("should format attributes as HTML string", function()
      local attrs = {role = "button", ["aria-label"] = "Test"}
      local html = manager:to_html_attrs(attrs)

      assert.truthy(html:match('role="button"'))
      assert.truthy(html:match('aria%-label="Test"'))
    end)

    it("should skip nil and empty values", function()
      local attrs = {role = "button", ["aria-label"] = nil, ["aria-hidden"] = ""}
      local html = manager:to_html_attrs(attrs)

      assert.truthy(html:match('role="button"'))
      assert.is_nil(html:match("aria%-label"))
      assert.is_nil(html:match("aria%-hidden"))
    end)
  end)

  describe("merge_aria()", function()
    it("should merge two attribute tables", function()
      local base = {role = "button", ["aria-label"] = "Base"}
      local override = {["aria-label"] = "Override", ["aria-pressed"] = "true"}

      local result = manager:merge_aria(base, override)

      assert.equals("button", result.role)
      assert.equals("Override", result["aria-label"])
      assert.equals("true", result["aria-pressed"])
    end)

    it("should handle nil override", function()
      local base = {role = "button"}
      local result = manager:merge_aria(base, nil)

      assert.equals("button", result.role)
    end)
  end)
end)
