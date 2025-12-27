--- UI Macros Unit Tests
-- Tests for UI interaction macros
-- @module tests.unit.script.macros.ui.test_ui_spec

describe("UI Macros", function()
  local Macros, UI, Context

  setup(function()
    Macros = require("whisker.script.macros")
    UI = require("whisker.script.macros.ui")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(UI.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", UI.VERSION)
    end)

    it("exports ui macros", function()
      -- Dialogs
      assert.is_table(UI.dialog_macro)
      assert.is_table(UI.alert_macro)
      assert.is_table(UI.confirm_macro)
      assert.is_table(UI.prompt_macro)

      -- Inputs
      assert.is_table(UI.textbox_macro)
      assert.is_table(UI.textarea_macro)
      assert.is_table(UI.checkbox_macro)
      assert.is_table(UI.radiobutton_macro)
      assert.is_table(UI.listbox_macro)
      assert.is_table(UI.numberbox_macro)
      assert.is_table(UI.button_macro)

      -- Timing
      assert.is_table(UI.timed_macro)
      assert.is_table(UI.repeat_macro)
      assert.is_table(UI.stop_timers_macro)

      -- Transitions
      assert.is_table(UI.transition_macro)
      assert.is_table(UI.notify_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(UI.register_all)
    end)
  end)

  describe("dialog macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates dialog data", function()
      local result = UI.dialog_macro.handler(ctx, { "Title", "Content" })
      assert.is_table(result)
      assert.equals("dialog", result._type)
      assert.equals("Title", result.title)
      assert.equals("Content", result.content)
    end)

    it("handles function content", function()
      local fn = function(c) return "dynamic content" end
      local result = UI.dialog_macro.handler(ctx, { "Title", fn })
      assert.equals("dynamic content", result.content)
    end)

    it("is ui category", function()
      assert.equals("ui", UI.dialog_macro.category)
    end)
  end)

  describe("alert macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates alert data", function()
      local result = UI.alert_macro.handler(ctx, { "Alert message!" })
      assert.is_table(result)
      assert.equals("alert", result._type)
      assert.equals("Alert message!", result.message)
    end)
  end)

  describe("confirm macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates confirm data", function()
      local result = UI.confirm_macro.handler(ctx, { "Are you sure?" })
      assert.is_table(result)
      assert.equals("confirm", result._type)
      assert.equals("Are you sure?", result.message)
    end)

    it("accepts default value", function()
      local result = UI.confirm_macro.handler(ctx, { "Continue?", true })
      assert.is_true(result.default)
    end)

    it("is async", function()
      assert.is_true(UI.confirm_macro.async)
    end)
  end)

  describe("prompt macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates prompt data", function()
      local result = UI.prompt_macro.handler(ctx, { "Enter name:", "Anonymous" })
      assert.is_table(result)
      assert.equals("prompt", result._type)
      assert.equals("Enter name:", result.message)
      assert.equals("Anonymous", result.default)
    end)

    it("defaults to empty string", function()
      local result = UI.prompt_macro.handler(ctx, { "Question" })
      assert.equals("", result.default)
    end)
  end)

  describe("textbox macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates textbox data", function()
      local result = UI.textbox_macro.handler(ctx, { "$name", "default" })
      assert.is_table(result)
      assert.equals("textbox", result._type)
      assert.equals("name", result.variable)
    end)

    it("strips $ prefix", function()
      local result = UI.textbox_macro.handler(ctx, { "$playerName", "" })
      assert.equals("playerName", result.variable)
    end)

    it("sets initial value in context", function()
      UI.textbox_macro.handler(ctx, { "$testVar", "initial" })
      assert.equals("initial", ctx:get("testVar"))
    end)
  end)

  describe("textarea macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates textarea data", function()
      local result = UI.textarea_macro.handler(ctx, { "$notes", "" })
      assert.is_table(result)
      assert.equals("textarea", result._type)
      assert.equals("notes", result.variable)
    end)

    it("has default rows and cols", function()
      local result = UI.textarea_macro.handler(ctx, { "$text", "" })
      assert.equals(4, result.rows)
      assert.equals(40, result.cols)
    end)
  end)

  describe("checkbox macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates checkbox data", function()
      local result = UI.checkbox_macro.handler(ctx, { "$enabled", false, true })
      assert.is_table(result)
      assert.equals("checkbox", result._type)
      assert.equals("enabled", result.variable)
      assert.equals(false, result.unchecked_value)
      assert.equals(true, result.checked_value)
    end)

    it("defaults to false/true", function()
      local result = UI.checkbox_macro.handler(ctx, { "$flag" })
      assert.equals(false, result.unchecked_value)
      assert.equals(true, result.checked_value)
    end)

    it("accepts label", function()
      local result = UI.checkbox_macro.handler(ctx, { "$sound", false, true, "Enable Sound" })
      assert.equals("Enable Sound", result.label)
    end)
  end)

  describe("radiobutton macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates radiobutton data", function()
      local result = UI.radiobutton_macro.handler(ctx, { "$choice", "option1", "Option 1" })
      assert.is_table(result)
      assert.equals("radiobutton", result._type)
      assert.equals("choice", result.variable)
      assert.equals("option1", result.value)
      assert.equals("Option 1", result.label)
    end)

    it("defaults label to value", function()
      local result = UI.radiobutton_macro.handler(ctx, { "$choice", "value" })
      assert.equals("value", result.label)
    end)
  end)

  describe("listbox macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates listbox data", function()
      local options = { "red", "green", "blue" }
      local result = UI.listbox_macro.handler(ctx, { "$color", options })
      assert.is_table(result)
      assert.equals("listbox", result._type)
      assert.equals("color", result.variable)
      assert.equals(3, #result.options)
    end)

    it("converts simple array to options", function()
      local result = UI.listbox_macro.handler(ctx, { "$x", { "a", "b" } })
      assert.equals("a", result.options[1].value)
      assert.equals("a", result.options[1].label)
    end)
  end)

  describe("numberbox macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates numberbox data", function()
      local result = UI.numberbox_macro.handler(ctx, { "$age", 18 })
      assert.is_table(result)
      assert.equals("numberbox", result._type)
      assert.equals("age", result.variable)
      assert.equals(18, result.value)
    end)

    it("defaults to 0", function()
      local result = UI.numberbox_macro.handler(ctx, { "$num" })
      assert.equals(0, result.value)
    end)

    it("accepts min/max options", function()
      local result = UI.numberbox_macro.handler(ctx, { "$val", 50, { min = 0, max = 100 } })
      assert.equals(0, result.min)
      assert.equals(100, result.max)
    end)
  end)

  describe("button macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates button data", function()
      local result = UI.button_macro.handler(ctx, { "Click Me" })
      assert.is_table(result)
      assert.equals("button", result._type)
      assert.equals("Click Me", result.text)
    end)

    it("accepts action", function()
      local action = function() end
      local result = UI.button_macro.handler(ctx, { "Submit", action })
      assert.equals(action, result.action)
    end)

    it("accepts disabled option", function()
      local result = UI.button_macro.handler(ctx, { "Disabled", nil, { disabled = true } })
      assert.is_true(result.disabled)
    end)
  end)

  describe("timed macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates timed data", function()
      local result = UI.timed_macro.handler(ctx, { "2s", "content" })
      assert.is_table(result)
      assert.equals("timed", result._type)
      assert.equals(2000, result.delay_ms)
      assert.equals("content", result.content)
    end)

    it("parses seconds", function()
      local result = UI.timed_macro.handler(ctx, { "3sec" })
      assert.equals(3000, result.delay_ms)
    end)

    it("parses milliseconds", function()
      local result = UI.timed_macro.handler(ctx, { "500ms" })
      assert.equals(500, result.delay_ms)
    end)

    it("handles numeric input", function()
      local result = UI.timed_macro.handler(ctx, { 1500 })
      assert.equals(1500, result.delay_ms)
    end)
  end)

  describe("repeat macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates repeat data", function()
      local result = UI.repeat_macro.handler(ctx, { "1s", "tick" })
      assert.is_table(result)
      assert.equals("repeat", result._type)
      assert.equals(1000, result.interval_ms)
    end)

    it("tracks current count", function()
      local result = UI.repeat_macro.handler(ctx, { "500ms" })
      assert.equals(0, result.current_count)
    end)
  end)

  describe("stop_timers macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns true", function()
      local result = UI.stop_timers_macro.handler(ctx, {})
      assert.is_true(result)
    end)
  end)

  describe("transition macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates transition data", function()
      local result = UI.transition_macro.handler(ctx, { "fade", "1s" })
      assert.is_table(result)
      assert.equals("transition", result._type)
      assert.equals("fade", result.transition)
      assert.equals(1000, result.duration_ms)
    end)

    it("defaults to fade", function()
      local result = UI.transition_macro.handler(ctx, {})
      assert.equals("fade", result.transition)
    end)

    it("parses duration", function()
      local result = UI.transition_macro.handler(ctx, { "slide", "500ms" })
      assert.equals(500, result.duration_ms)
    end)
  end)

  describe("notify macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates notification data", function()
      local result = UI.notify_macro.handler(ctx, { "Achievement unlocked!" })
      assert.is_table(result)
      assert.equals("notification", result._type)
      assert.equals("Achievement unlocked!", result.message)
    end)

    it("has default options", function()
      local result = UI.notify_macro.handler(ctx, { "Message" })
      assert.equals(3000, result.duration)
      assert.equals("top-right", result.position)
      assert.equals("info", result.style)
    end)

    it("accepts options", function()
      local result = UI.notify_macro.handler(ctx, { "Warning", { style = "warning" } })
      assert.equals("warning", result.style)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = UI.register_all(registry)

      assert.is_true(count >= 15)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      UI.register_all(registry)

      assert.is_not_nil(registry:get("dialog"))
      assert.is_not_nil(registry:get("alert"))
      assert.is_not_nil(registry:get("textbox"))
      assert.is_not_nil(registry:get("button"))
      assert.is_not_nil(registry:get("timed"))
    end)

    it("all macros are ui category", function()
      local registry = Registry.new()
      UI.register_all(registry)

      local names = { "dialog", "alert", "textbox", "button" }
      for _, name in ipairs(names) do
        local macro = registry:get(name)
        assert.equals("ui", macro.category)
      end
    end)
  end)
end)
