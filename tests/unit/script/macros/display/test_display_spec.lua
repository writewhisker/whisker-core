--- DOM & Display Macros Unit Tests
-- Tests for DOM manipulation and display control macros
-- @module tests.unit.script.macros.display.test_display_spec

describe("Display Macros", function()
  local Macros, Display, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Display = require("whisker.script.macros.display")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Display.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Display.VERSION)
    end)

    it("exports hook manipulation macros", function()
      assert.is_table(Display.append_macro)
      assert.is_table(Display.prepend_macro)
      assert.is_table(Display.replace_macro)
      assert.is_table(Display.remove_macro)
    end)

    it("exports visibility macros", function()
      assert.is_table(Display.show_macro)
      assert.is_table(Display.hide_macro)
      assert.is_table(Display.toggle_macro)
    end)

    it("exports CSS/style macros", function()
      assert.is_table(Display.addclass_macro)
      assert.is_table(Display.removeclass_macro)
      assert.is_table(Display.toggleclass_macro)
      assert.is_table(Display.css_macro)
      assert.is_table(Display.style_macro)
    end)

    it("exports color/appearance macros", function()
      assert.is_table(Display.color_macro)
      assert.is_table(Display.background_macro)
    end)

    it("exports alignment/layout macros", function()
      assert.is_table(Display.align_macro)
      assert.is_table(Display.box_macro)
      assert.is_table(Display.columns_macro)
    end)

    it("exports hook macros", function()
      assert.is_table(Display.hook_macro)
      assert.is_table(Display.gethook_macro)
      assert.is_table(Display.hashook_macro)
    end)

    it("exports element query macros", function()
      assert.is_table(Display.element_macro)
      assert.is_table(Display.attr_macro)
      assert.is_table(Display.data_macro)
    end)

    it("exports focus/scroll macros", function()
      assert.is_table(Display.focus_macro)
      assert.is_table(Display.scroll_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Display.register_all)
    end)
  end)

  describe("append macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates append data", function()
      local result = Display.append_macro.handler(ctx, { "#target", "content" })
      assert.is_table(result)
      assert.equals("append", result._type)
      assert.equals("#target", result.target)
      assert.equals("content", result.content)
    end)

    it("updates hook when target is hook name", function()
      ctx:define_hook("test", "initial")
      Display.append_macro.handler(ctx, { "?test", " appended" })
      assert.equals("initial appended", ctx:get_hook("test"))
    end)
  end)

  describe("prepend macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates prepend data", function()
      local result = Display.prepend_macro.handler(ctx, { "#target", "content" })
      assert.is_table(result)
      assert.equals("prepend", result._type)
    end)
  end)

  describe("replace macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates replace data", function()
      local result = Display.replace_macro.handler(ctx, { "#target", "new" })
      assert.is_table(result)
      assert.equals("replace", result._type)
      assert.equals("new", result.content)
    end)

    it("updates hook when target is hook name", function()
      ctx:define_hook("test", "old")
      Display.replace_macro.handler(ctx, { "?test", "new" })
      assert.equals("new", ctx:get_hook("test"))
    end)
  end)

  describe("remove macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates remove data", function()
      local result = Display.remove_macro.handler(ctx, { "#target" })
      assert.is_table(result)
      assert.equals("remove", result._type)
    end)

    it("clears hook when target is hook name", function()
      ctx:define_hook("test", "content")
      Display.remove_macro.handler(ctx, { "?test" })
      assert.equals("", ctx:get_hook("test"))
    end)
  end)

  describe("show macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates show data", function()
      local result = Display.show_macro.handler(ctx, { "#hidden" })
      assert.is_table(result)
      assert.equals("show", result._type)
      assert.equals("#hidden", result.target)
    end)
  end)

  describe("hide macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates hide data", function()
      local result = Display.hide_macro.handler(ctx, { "#visible" })
      assert.is_table(result)
      assert.equals("hide", result._type)
    end)
  end)

  describe("toggle macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates toggle data", function()
      local result = Display.toggle_macro.handler(ctx, { "#panel" })
      assert.is_table(result)
      assert.equals("toggle", result._type)
    end)
  end)

  describe("addclass macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates addclass data", function()
      local result = Display.addclass_macro.handler(ctx, { "#elem", "highlight" })
      assert.is_table(result)
      assert.equals("addclass", result._type)
      assert.equals("#elem", result.target)
      assert.equals("highlight", result.class)
    end)
  end)

  describe("removeclass macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates removeclass data", function()
      local result = Display.removeclass_macro.handler(ctx, { "#elem", "active" })
      assert.is_table(result)
      assert.equals("removeclass", result._type)
    end)
  end)

  describe("toggleclass macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates toggleclass data", function()
      local result = Display.toggleclass_macro.handler(ctx, { "#elem", "expanded" })
      assert.is_table(result)
      assert.equals("toggleclass", result._type)
    end)
  end)

  describe("css macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates css data with string styles", function()
      local result = Display.css_macro.handler(ctx, { "#box", "color: red" })
      assert.is_table(result)
      assert.equals("css", result._type)
      assert.equals("color: red", result.styles)
    end)

    it("creates css data with table styles", function()
      local styles = { color = "red", fontSize = "20px" }
      local result = Display.css_macro.handler(ctx, { "#box", styles })
      assert.is_table(result.styles)
    end)
  end)

  describe("style macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates style changer", function()
      local result = Display.style_macro.handler(ctx, { "bold" })
      assert.is_table(result)
      assert.equals("style", result._type)
      assert.equals("bold", result.style)
      assert.is_true(result._is_changer)
    end)

    it("is pure", function()
      assert.is_true(Display.style_macro.pure)
    end)
  end)

  describe("color macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates color changer", function()
      local result = Display.color_macro.handler(ctx, { "red" })
      assert.is_table(result)
      assert.equals("color", result._type)
      assert.equals("red", result.color)
      assert.is_true(result._is_changer)
    end)

    it("is pure", function()
      assert.is_true(Display.color_macro.pure)
    end)
  end)

  describe("background macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates background changer", function()
      local result = Display.background_macro.handler(ctx, { "yellow" })
      assert.is_table(result)
      assert.equals("background", result._type)
      assert.equals("yellow", result.color)
      assert.is_true(result._is_changer)
    end)
  end)

  describe("align macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates align changer", function()
      local result = Display.align_macro.handler(ctx, { "center" })
      assert.is_table(result)
      assert.equals("align", result._type)
      assert.equals("center", result.alignment)
      assert.is_true(result._is_changer)
    end)

    it("is pure", function()
      assert.is_true(Display.align_macro.pure)
    end)
  end)

  describe("box macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates box changer with default width", function()
      local result = Display.box_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("box", result._type)
      assert.equals("100%", result.width)
    end)

    it("accepts custom width", function()
      local result = Display.box_macro.handler(ctx, { "50%" })
      assert.equals("50%", result.width)
    end)

    it("accepts options", function()
      local result = Display.box_macro.handler(ctx, { "80%", { padding = "10px" } })
      assert.equals("10px", result.padding)
    end)
  end)

  describe("columns macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates columns changer with default count", function()
      local result = Display.columns_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("columns", result._type)
      assert.equals(2, result.count)
    end)

    it("accepts custom count", function()
      local result = Display.columns_macro.handler(ctx, { 3 })
      assert.equals(3, result.count)
    end)
  end)

  describe("hook macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates hook data", function()
      local result = Display.hook_macro.handler(ctx, { "status", "Ready" })
      assert.is_table(result)
      assert.equals("hook", result._type)
      assert.equals("status", result.name)
      assert.equals("Ready", result.content)
    end)

    it("defines hook in context", function()
      Display.hook_macro.handler(ctx, { "myHook", "content" })
      assert.equals("content", ctx:get_hook("myHook"))
    end)
  end)

  describe("gethook macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:define_hook("test", "test content")
    end)

    it("gets hook content", function()
      local result = Display.gethook_macro.handler(ctx, { "test" })
      assert.equals("test content", result)
    end)

    it("returns nil for nonexistent hook", function()
      local result = Display.gethook_macro.handler(ctx, { "nonexistent" })
      assert.is_nil(result)
    end)

    it("is pure", function()
      assert.is_true(Display.gethook_macro.pure)
    end)
  end)

  describe("hashook macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:define_hook("exists", "content")
    end)

    it("returns true for existing hook", function()
      local result = Display.hashook_macro.handler(ctx, { "exists" })
      assert.is_true(result)
    end)

    it("returns false for nonexistent hook", function()
      local result = Display.hashook_macro.handler(ctx, { "missing" })
      assert.is_false(result)
    end)

    it("is pure", function()
      assert.is_true(Display.hashook_macro.pure)
    end)
  end)

  describe("element macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates element query data", function()
      local result = Display.element_macro.handler(ctx, { "#main" })
      assert.is_table(result)
      assert.equals("element_query", result._type)
      assert.equals("#main", result.selector)
    end)
  end)

  describe("attr macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates attr data", function()
      local result = Display.attr_macro.handler(ctx, { "#input", "disabled", true })
      assert.is_table(result)
      assert.equals("attr", result._type)
      assert.equals("disabled", result.attribute)
      assert.is_true(result.value)
    end)
  end)

  describe("data macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates data attr data", function()
      local result = Display.data_macro.handler(ctx, { "#item", "id", 123 })
      assert.is_table(result)
      assert.equals("data_attr", result._type)
      assert.equals("id", result.key)
      assert.equals(123, result.value)
    end)
  end)

  describe("focus macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates focus data", function()
      local result = Display.focus_macro.handler(ctx, { "#input" })
      assert.is_table(result)
      assert.equals("focus", result._type)
      assert.equals("#input", result.target)
    end)
  end)

  describe("scroll macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates scroll data", function()
      local result = Display.scroll_macro.handler(ctx, { "#section" })
      assert.is_table(result)
      assert.equals("scroll", result._type)
      assert.equals("#section", result.target)
    end)

    it("defaults to smooth behavior", function()
      local result = Display.scroll_macro.handler(ctx, { "#section" })
      assert.equals("smooth", result.behavior)
    end)

    it("accepts options", function()
      local result = Display.scroll_macro.handler(ctx, { "#section", { behavior = "instant" } })
      assert.equals("instant", result.behavior)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Display.register_all(registry)

      assert.is_true(count >= 24)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Display.register_all(registry)

      assert.is_not_nil(registry:get("append"))
      assert.is_not_nil(registry:get("replace"))
      assert.is_not_nil(registry:get("show"))
      assert.is_not_nil(registry:get("hide"))
      assert.is_not_nil(registry:get("addclass"))
      assert.is_not_nil(registry:get("color"))
      assert.is_not_nil(registry:get("hook"))
    end)

    it("text macros have text category", function()
      local registry = Registry.new()
      Display.register_all(registry)

      local macro = registry:get("append")
      assert.equals("text", macro.category)
    end)

    it("ui macros have ui category", function()
      local registry = Registry.new()
      Display.register_all(registry)

      local macro = registry:get("show")
      assert.equals("ui", macro.category)
    end)
  end)
end)
