--- Widget & Custom Macros Unit Tests
-- Tests for widget definition and custom macro functionality
-- @module tests.unit.script.macros.widget.test_widget_spec

describe("Widget Macros", function()
  local Macros, Widget, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Widget = require("whisker.script.macros.widget")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Widget.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Widget.VERSION)
    end)

    it("exports widget definition macros", function()
      assert.is_table(Widget.widget_macro)
      assert.is_table(Widget.done_macro)
      assert.is_table(Widget.call_macro)
    end)

    it("exports output control macros", function()
      assert.is_table(Widget.capture_macro)
      assert.is_table(Widget.silently_macro)
      assert.is_table(Widget.nobr_macro)
    end)

    it("exports content embedding macros", function()
      assert.is_table(Widget.include_macro)
      assert.is_table(Widget.embed_macro)
      assert.is_table(Widget.display_macro)
    end)

    it("exports text effect macros", function()
      assert.is_table(Widget.type_macro)
      assert.is_table(Widget.print_macro)
      assert.is_table(Widget.verbatim_macro)
    end)

    it("exports cycling/sequence macros", function()
      assert.is_table(Widget.cycling_macro)
      assert.is_table(Widget.sequence_macro)
      assert.is_table(Widget.stop_macro)
      assert.is_table(Widget.shuffle_macro)
    end)

    it("exports script macros", function()
      assert.is_table(Widget.script_macro)
      assert.is_table(Widget.run_macro)
    end)

    it("exports parameter macros", function()
      assert.is_table(Widget.params_macro)
      assert.is_table(Widget.contents_macro)
    end)

    it("exports custom macro definition macros", function()
      assert.is_table(Widget.macro_macro)
      assert.is_table(Widget.output_macro)
    end)

    it("exports template macros", function()
      assert.is_table(Widget.template_macro)
      assert.is_table(Widget.render_macro)
      assert.is_table(Widget.slot_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Widget.register_all)
    end)
  end)

  describe("widget macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates widget data", function()
      local result = Widget.widget_macro.handler(ctx, { "greet", "Hello!" })
      assert.is_table(result)
      assert.equals("widget", result._type)
      assert.equals("greet", result.name)
      assert.equals("Hello!", result.body)
    end)

    it("registers widget in context", function()
      Widget.widget_macro.handler(ctx, { "myWidget", "content" })
      local widgets = ctx:get("_widgets")
      assert.is_not_nil(widgets["myWidget"])
    end)

    it("accepts options", function()
      local result = Widget.widget_macro.handler(ctx, { "box", "body", { container = true } })
      assert.is_true(result.container)
    end)

    it("requires name", function()
      local result, err = Widget.widget_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("done macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates done data", function()
      local result = Widget.done_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("done", result._type)
      assert.is_true(result._stops_execution)
    end)

    it("sets execution halted flag", function()
      Widget.done_macro.handler(ctx, {})
      assert.is_true(ctx:get("_execution_halted"))
    end)
  end)

  describe("call macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_widgets", { greet = { body = "Hello!" } })
    end)

    it("creates call data", function()
      local result = Widget.call_macro.handler(ctx, { "greet" })
      assert.is_table(result)
      assert.equals("widget_call", result._type)
      assert.equals("greet", result.name)
    end)

    it("marks existing widget", function()
      local result = Widget.call_macro.handler(ctx, { "greet" })
      assert.is_true(result.exists)
    end)

    it("marks non-existing widget", function()
      local result = Widget.call_macro.handler(ctx, { "unknown" })
      assert.is_false(result.exists)
    end)

    it("accepts arguments", function()
      local result = Widget.call_macro.handler(ctx, { "greet", { "arg1", "arg2" } })
      assert.equals(2, #result.args)
    end)
  end)

  describe("capture macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates capture data", function()
      local result = Widget.capture_macro.handler(ctx, { "output", "content" })
      assert.is_table(result)
      assert.equals("capture", result._type)
      assert.equals("output", result.variable)
      assert.equals("content", result.content)
    end)

    it("stores content in variable", function()
      Widget.capture_macro.handler(ctx, { "result", "captured text" })
      assert.equals("captured text", ctx:get("result"))
    end)

    it("requires variable name", function()
      local result, err = Widget.capture_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("silently macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates silent data", function()
      local result = Widget.silently_macro.handler(ctx, { "code" })
      assert.is_table(result)
      assert.equals("silent", result._type)
      assert.is_true(result._suppress_output)
    end)
  end)

  describe("nobr macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates nobr changer", function()
      local result = Widget.nobr_macro.handler(ctx, { "text" })
      assert.is_table(result)
      assert.equals("nobr", result._type)
      assert.is_true(result._is_changer)
    end)

    it("is pure", function()
      assert.is_true(Widget.nobr_macro.pure)
    end)
  end)

  describe("include macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates include data", function()
      local result = Widget.include_macro.handler(ctx, { "header" })
      assert.is_table(result)
      assert.equals("include", result._type)
      assert.equals("header", result.passage)
    end)

    it("inherits context by default", function()
      local result = Widget.include_macro.handler(ctx, { "passage" })
      assert.is_true(result.inherit_context)
    end)

    it("accepts options", function()
      local result = Widget.include_macro.handler(ctx, { "passage", { element = "#target" } })
      assert.equals("#target", result.element)
    end)

    it("is async", function()
      assert.is_true(Widget.include_macro.async)
    end)
  end)

  describe("embed macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates embed data", function()
      local result = Widget.embed_macro.handler(ctx, { "stats" })
      assert.is_table(result)
      assert.equals("embed", result._type)
      assert.equals("stats", result.source)
    end)

    it("defaults to passage type", function()
      local result = Widget.embed_macro.handler(ctx, { "content" })
      assert.equals("passage", result.source_type)
    end)

    it("is inline by default", function()
      local result = Widget.embed_macro.handler(ctx, { "content" })
      assert.is_true(result.inline)
    end)
  end)

  describe("display macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates display data", function()
      local result = Widget.display_macro.handler(ctx, { "Chapter 1" })
      assert.is_table(result)
      assert.equals("display", result._type)
      assert.equals("Chapter 1", result.passage)
    end)

    it("requires passage name", function()
      local result, err = Widget.display_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("is async", function()
      assert.is_true(Widget.display_macro.async)
    end)
  end)

  describe("type macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates type effect data", function()
      local result = Widget.type_macro.handler(ctx, { "Hello" })
      assert.is_table(result)
      assert.equals("type_effect", result._type)
      assert.equals("Hello", result.content)
      assert.is_true(result._is_changer)
    end)

    it("has default speed", function()
      local result = Widget.type_macro.handler(ctx, { "text" })
      assert.equals(40, result.speed)
    end)

    it("accepts options", function()
      local result = Widget.type_macro.handler(ctx, { "text", { speed = 100, cursor = false } })
      assert.equals(100, result.speed)
      assert.is_false(result.cursor)
    end)
  end)

  describe("print macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates print data", function()
      local result = Widget.print_macro.handler(ctx, { "Hello" })
      assert.is_table(result)
      assert.equals("print", result._type)
      assert.equals("Hello", result.value)
    end)

    it("renders value to string", function()
      local result = Widget.print_macro.handler(ctx, { 42 })
      assert.equals("42", result.rendered)
    end)

    it("is pure", function()
      assert.is_true(Widget.print_macro.pure)
    end)
  end)

  describe("verbatim macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates verbatim changer", function()
      local result = Widget.verbatim_macro.handler(ctx, { "<<not parsed>>" })
      assert.is_table(result)
      assert.equals("verbatim", result._type)
      assert.is_true(result._is_changer)
      assert.is_true(result._raw_output)
    end)

    it("is pure", function()
      assert.is_true(Widget.verbatim_macro.pure)
    end)
  end)

  describe("cycling macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates cycling data", function()
      local result = Widget.cycling_macro.handler(ctx, { "weapon", "sword", "axe" })
      assert.is_table(result)
      assert.equals("cycling", result._type)
      assert.equals("weapon", result.variable)
      assert.equals(2, #result.options)
    end)

    it("starts at first option", function()
      local result = Widget.cycling_macro.handler(ctx, { "color", "red", "blue" })
      assert.equals(1, result.current_index)
      assert.equals("red", result.current_value)
    end)

    it("sets variable value", function()
      Widget.cycling_macro.handler(ctx, { "size", "small", "medium" })
      assert.equals("small", ctx:get("size"))
    end)

    it("requires variable name", function()
      local result, err = Widget.cycling_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("requires at least one option", function()
      local result, err = Widget.cycling_macro.handler(ctx, { "var" })
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("sequence macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates sequence data", function()
      local result = Widget.sequence_macro.handler(ctx, { "greet", "Hi", "Hello" })
      assert.is_table(result)
      assert.equals("sequence", result._type)
      assert.equals("greet", result.id)
      assert.equals(2, #result.steps)
    end)

    it("starts at step 1", function()
      local result = Widget.sequence_macro.handler(ctx, { "test", "first", "second" })
      assert.equals(1, result.current_step)
      assert.equals("first", result.current_value)
    end)

    it("advances step in context", function()
      Widget.sequence_macro.handler(ctx, { "seq", "a", "b" })
      assert.equals(2, ctx:get("_sequence_seq"))
    end)

    it("stays at last step when exceeded", function()
      ctx:set("_sequence_end", 5)
      local result = Widget.sequence_macro.handler(ctx, { "end", "one", "two" })
      assert.equals("two", result.current_value)
      assert.is_true(result.completed)
    end)
  end)

  describe("stop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates stop data", function()
      local result = Widget.stop_macro.handler(ctx, { "first", "last" })
      assert.is_table(result)
      assert.equals("stop", result._type)
      assert.equals(2, #result.values)
    end)

    it("starts at first value", function()
      local result = Widget.stop_macro.handler(ctx, { "a", "b", "c" })
      assert.equals(1, result.current_position)
      assert.equals("a", result.current_value)
    end)

    it("marks when stopped", function()
      -- Simulate multiple visits
      local key = "_stop_" .. ("final"):sub(1, 32)
      ctx:set(key, 1)
      local result = Widget.stop_macro.handler(ctx, { "final" })
      assert.is_true(result.stopped)
    end)
  end)

  describe("shuffle macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      math.randomseed(12345)
    end)

    it("creates shuffle data", function()
      local result = Widget.shuffle_macro.handler(ctx, { "greet", "Hi", "Hello" })
      assert.is_table(result)
      assert.equals("shuffle", result._type)
      assert.equals("greet", result.id)
    end)

    it("selects from items", function()
      local result = Widget.shuffle_macro.handler(ctx, { "pick", "a", "b", "c" })
      assert.is_not_nil(result.selected)
    end)

    it("tracks remaining items", function()
      local result = Widget.shuffle_macro.handler(ctx, { "items", "x", "y", "z" })
      assert.equals(2, result.remaining_count)
    end)

    it("requires shuffle ID", function()
      local result, err = Widget.shuffle_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("script macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates script data", function()
      local result = Widget.script_macro.handler(ctx, { "console.log('hi')" })
      assert.is_table(result)
      assert.equals("script", result._type)
      assert.equals("console.log('hi')", result.code)
    end)

    it("defaults to javascript", function()
      local result = Widget.script_macro.handler(ctx, { "code" })
      assert.equals("javascript", result.language)
    end)

    it("accepts options", function()
      local result = Widget.script_macro.handler(ctx, { "code", { defer = true } })
      assert.is_true(result.defer)
    end)
  end)

  describe("run macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates run data", function()
      local result = Widget.run_macro.handler(ctx, { "expression" })
      assert.is_table(result)
      assert.equals("run", result._type)
      assert.equals("expression", result.code)
    end)
  end)

  describe("params macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_widget_args", { "arg1", "arg2", "arg3" })
    end)

    it("returns all params without index", function()
      local result = Widget.params_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("params", result._type)
      assert.equals(3, result.count)
    end)

    it("returns specific param by index", function()
      local result = Widget.params_macro.handler(ctx, { 2 })
      assert.equals("arg2", result)
    end)

    it("returns nil for out of range index", function()
      local result = Widget.params_macro.handler(ctx, { 10 })
      assert.is_nil(result)
    end)

    it("is pure", function()
      assert.is_true(Widget.params_macro.pure)
    end)
  end)

  describe("contents macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_widget_slots", { default = "default content", header = "header content" })
    end)

    it("returns default slot", function()
      local result = Widget.contents_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("contents", result._type)
      assert.equals("default", result.slot)
      assert.equals("default content", result.content)
    end)

    it("returns named slot", function()
      local result = Widget.contents_macro.handler(ctx, { "header" })
      assert.equals("header", result.slot)
      assert.equals("header content", result.content)
    end)

    it("indicates when content exists", function()
      local result = Widget.contents_macro.handler(ctx, { "header" })
      assert.is_true(result.has_content)
    end)

    it("indicates when content missing", function()
      local result = Widget.contents_macro.handler(ctx, { "missing" })
      assert.is_false(result.has_content)
    end)

    it("is pure", function()
      assert.is_true(Widget.contents_macro.pure)
    end)
  end)

  describe("macro macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates macro definition", function()
      local result = Widget.macro_macro.handler(ctx, { "greet", { "name" }, "Hello" })
      assert.is_table(result)
      assert.equals("macro_definition", result._type)
      assert.equals("greet", result.name)
    end)

    it("registers in context", function()
      Widget.macro_macro.handler(ctx, { "custom", {}, "body" })
      local macros = ctx:get("_custom_macros")
      assert.is_not_nil(macros["custom"])
    end)

    it("requires name", function()
      local result, err = Widget.macro_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("output macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates output data", function()
      local result = Widget.output_macro.handler(ctx, { "result" })
      assert.is_table(result)
      assert.equals("output", result._type)
      assert.equals("result", result.value)
      assert.is_true(result._is_macro_output)
    end)

    it("is pure", function()
      assert.is_true(Widget.output_macro.pure)
    end)
  end)

  describe("template macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates template data", function()
      local result = Widget.template_macro.handler(ctx, { "card", "body" })
      assert.is_table(result)
      assert.equals("template", result._type)
      assert.equals("card", result.name)
    end)

    it("registers in context", function()
      Widget.template_macro.handler(ctx, { "box", "content" })
      local templates = ctx:get("_templates")
      assert.is_not_nil(templates["box"])
    end)

    it("accepts slots", function()
      local result = Widget.template_macro.handler(ctx, { "layout", "body", { header = true } })
      assert.is_table(result.slots)
    end)

    it("requires name", function()
      local result, err = Widget.template_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("render macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_templates", { card = { body = "Card template" } })
    end)

    it("creates render data", function()
      local result = Widget.render_macro.handler(ctx, { "card" })
      assert.is_table(result)
      assert.equals("render", result._type)
      assert.equals("card", result.template)
    end)

    it("marks existing template", function()
      local result = Widget.render_macro.handler(ctx, { "card" })
      assert.is_true(result.exists)
    end)

    it("marks non-existing template", function()
      local result = Widget.render_macro.handler(ctx, { "unknown" })
      assert.is_false(result.exists)
    end)

    it("accepts slot content", function()
      local result = Widget.render_macro.handler(ctx, { "card", { title = "My Card" } })
      assert.equals("My Card", result.slots.title)
    end)
  end)

  describe("slot macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_current_slots", { header = "Header content" })
    end)

    it("creates slot data", function()
      local result = Widget.slot_macro.handler(ctx, { "header" })
      assert.is_table(result)
      assert.equals("slot", result._type)
      assert.equals("header", result.name)
    end)

    it("returns slot content", function()
      local result = Widget.slot_macro.handler(ctx, { "header" })
      assert.equals("Header content", result.content)
      assert.is_true(result.has_content)
    end)

    it("uses default when slot missing", function()
      local result = Widget.slot_macro.handler(ctx, { "footer", "Default footer" })
      assert.equals("Default footer", result.content)
      assert.is_false(result.has_content)
    end)

    it("defaults to 'default' slot", function()
      ctx:set("_current_slots", { default = "Main content" })
      local result = Widget.slot_macro.handler(ctx, {})
      assert.equals("default", result.name)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Widget.register_all(registry)

      assert.is_true(count >= 25)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Widget.register_all(registry)

      assert.is_not_nil(registry:get("widget"))
      assert.is_not_nil(registry:get("done"))
      assert.is_not_nil(registry:get("capture"))
      assert.is_not_nil(registry:get("include"))
      assert.is_not_nil(registry:get("type"))
      assert.is_not_nil(registry:get("cycling"))
      assert.is_not_nil(registry:get("template"))
    end)

    it("custom macros have custom category", function()
      local registry = Registry.new()
      Widget.register_all(registry)

      local macro = registry:get("widget")
      assert.equals("custom", macro.category)
    end)

    it("text macros have text category", function()
      local registry = Registry.new()
      Widget.register_all(registry)

      local macro = registry:get("print")
      assert.equals("text", macro.category)
    end)
  end)
end)
