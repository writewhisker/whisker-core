--- Link & Navigation Macros Unit Tests
-- Tests for link creation and navigation macros
-- @module tests.unit.script.macros.link.test_link_spec

describe("Link Macros", function()
  local Macros, Link, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Link = require("whisker.script.macros.link")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Link.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Link.VERSION)
    end)

    it("exports basic link macros", function()
      assert.is_table(Link.link_macro)
      assert.is_table(Link.linkgoto_macro)
      assert.is_table(Link.linkreveal_macro)
      assert.is_table(Link.linkrepeat_macro)
      assert.is_table(Link.linkreplace_macro)
    end)

    it("exports navigation macros", function()
      assert.is_table(Link.goto_macro)
      assert.is_table(Link.back_macro)
      assert.is_table(Link.return_macro)
    end)

    it("exports click macros", function()
      assert.is_table(Link.click_macro)
      assert.is_table(Link.clickreplace_macro)
      assert.is_table(Link.clickappend_macro)
      assert.is_table(Link.clickprepend_macro)
    end)

    it("exports choice macros", function()
      assert.is_table(Link.choice_macro)
      assert.is_table(Link.actions_macro)
    end)

    it("exports URL macros", function()
      assert.is_table(Link.url_macro)
      assert.is_table(Link.open_macro)
    end)

    it("exports link state macros", function()
      assert.is_table(Link.linkshow_macro)
      assert.is_table(Link.linkonce_macro)
      assert.is_table(Link.linkvisited_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Link.register_all)
    end)
  end)

  describe("link macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link data", function()
      local result = Link.link_macro.handler(ctx, { "Click me" })
      assert.is_table(result)
      assert.equals("link", result._type)
      assert.equals("Click me", result.text)
    end)

    it("accepts action", function()
      local result = Link.link_macro.handler(ctx, { "Click", "action code" })
      assert.equals("action code", result.action)
    end)

    it("is link category", function()
      assert.equals("link", Link.link_macro.category)
    end)
  end)

  describe("linkgoto macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link goto data", function()
      local result = Link.linkgoto_macro.handler(ctx, { "Go", "passage" })
      assert.is_table(result)
      assert.equals("link_goto", result._type)
      assert.equals("Go", result.text)
      assert.equals("passage", result.passage)
    end)

    it("defaults passage to text", function()
      local result = Link.linkgoto_macro.handler(ctx, { "Chapter 2" })
      assert.equals("Chapter 2", result.passage)
    end)

    it("accepts setter", function()
      local result = Link.linkgoto_macro.handler(ctx, { "Go", "target", "setter code" })
      assert.equals("setter code", result.setter)
    end)
  end)

  describe("linkreveal macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link reveal data", function()
      local result = Link.linkreveal_macro.handler(ctx, { "Reveal", "content" })
      assert.is_table(result)
      assert.equals("link_reveal", result._type)
      assert.equals("Reveal", result.text)
      assert.equals("content", result.content)
    end)

    it("is not revealed initially", function()
      local result = Link.linkreveal_macro.handler(ctx, { "Show" })
      assert.is_false(result.revealed)
    end)

    it("is once by default", function()
      local result = Link.linkreveal_macro.handler(ctx, { "Show" })
      assert.is_true(result.once)
    end)
  end)

  describe("linkrepeat macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link repeat data", function()
      local result = Link.linkrepeat_macro.handler(ctx, { "Click", "action" })
      assert.is_table(result)
      assert.equals("link_repeat", result._type)
    end)

    it("initializes click count to 0", function()
      local result = Link.linkrepeat_macro.handler(ctx, { "Click" })
      assert.equals(0, result.click_count)
    end)
  end)

  describe("linkreplace macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link replace data", function()
      local result = Link.linkreplace_macro.handler(ctx, { "Open box", "A key!" })
      assert.is_table(result)
      assert.equals("link_replace", result._type)
      assert.equals("Open box", result.text)
      assert.equals("A key!", result.content)
    end)
  end)

  describe("goto macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates goto data", function()
      local result = Link.goto_macro.handler(ctx, { "target-passage" })
      assert.is_table(result)
      assert.equals("goto", result._type)
      assert.equals("target-passage", result.passage)
    end)

    it("requires passage name", function()
      local result, err = Link.goto_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("is async", function()
      assert.is_true(Link.goto_macro.async)
    end)
  end)

  describe("back macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_passage_history", { "intro", "chapter1", "chapter2", "current" })
    end)

    it("creates back data", function()
      local result = Link.back_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("back", result._type)
      assert.equals(1, result.steps)
    end)

    it("finds correct target", function()
      local result = Link.back_macro.handler(ctx, {})
      assert.equals("chapter2", result.target)
    end)

    it("accepts steps parameter", function()
      local result = Link.back_macro.handler(ctx, { 2 })
      assert.equals(2, result.steps)
      assert.equals("chapter1", result.target)
    end)

    it("returns nil target when history too short", function()
      ctx:set("_passage_history", { "only" })
      local result = Link.back_macro.handler(ctx, {})
      assert.is_nil(result.target)
    end)

    it("is async", function()
      assert.is_true(Link.back_macro.async)
    end)
  end)

  describe("return macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_passage_history", { "intro", "chapter1", "current" })
    end)

    it("creates return data", function()
      local result = Link.return_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("return", result._type)
    end)

    it("returns to previous by default", function()
      local result = Link.return_macro.handler(ctx, {})
      assert.equals("chapter1", result.passage)
    end)

    it("accepts specific passage", function()
      local result = Link.return_macro.handler(ctx, { "intro" })
      assert.equals("intro", result.passage)
    end)
  end)

  describe("click macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates click handler data", function()
      local result = Link.click_macro.handler(ctx, { "#button", "action" })
      assert.is_table(result)
      assert.equals("click_handler", result._type)
      assert.equals("#button", result.selector)
      assert.equals("action", result.action)
    end)
  end)

  describe("clickreplace macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates click replace data", function()
      local result = Link.clickreplace_macro.handler(ctx, { "#target", "new content" })
      assert.is_table(result)
      assert.equals("click_replace", result._type)
      assert.equals("#target", result.selector)
      assert.equals("new content", result.content)
    end)
  end)

  describe("clickappend macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates click append data", function()
      local result = Link.clickappend_macro.handler(ctx, { "#log", "line" })
      assert.is_table(result)
      assert.equals("click_append", result._type)
    end)
  end)

  describe("clickprepend macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates click prepend data", function()
      local result = Link.clickprepend_macro.handler(ctx, { "#messages", "new" })
      assert.is_table(result)
      assert.equals("click_prepend", result._type)
    end)
  end)

  describe("choice macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates choice data", function()
      local result = Link.choice_macro.handler(ctx, { "Fight", "battle" })
      assert.is_table(result)
      assert.equals("choice", result._type)
      assert.equals("Fight", result.text)
      assert.equals("battle", result.target)
    end)

    it("is enabled by default", function()
      local result = Link.choice_macro.handler(ctx, { "Option" })
      assert.is_true(result.enabled)
    end)

    it("evaluates boolean condition", function()
      local result = Link.choice_macro.handler(ctx, { "Option", "target", false })
      assert.is_false(result.enabled)
    end)

    it("evaluates function condition", function()
      local result = Link.choice_macro.handler(ctx, { "Option", "target", function() return true end })
      assert.is_true(result.enabled)
    end)
  end)

  describe("actions macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates actions data", function()
      local result = Link.actions_macro.handler(ctx, { "North", "South", "East" })
      assert.is_table(result)
      assert.equals("actions", result._type)
      assert.equals(3, #result.choices)
    end)

    it("converts strings to choice objects", function()
      local result = Link.actions_macro.handler(ctx, { "Go North" })
      assert.equals("Go North", result.choices[1].text)
      assert.equals("Go North", result.choices[1].target)
    end)

    it("accepts table choices", function()
      local result = Link.actions_macro.handler(ctx, { { text = "Fight", target = "battle" } })
      assert.equals("Fight", result.choices[1].text)
      assert.equals("battle", result.choices[1].target)
    end)
  end)

  describe("url macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates url data", function()
      local result = Link.url_macro.handler(ctx, { "https://example.com" })
      assert.is_table(result)
      assert.equals("url", result._type)
      assert.equals("https://example.com", result.url)
    end)

    it("defaults text to url", function()
      local result = Link.url_macro.handler(ctx, { "https://example.com" })
      assert.equals("https://example.com", result.text)
    end)

    it("accepts custom text", function()
      local result = Link.url_macro.handler(ctx, { "https://example.com", "Example" })
      assert.equals("Example", result.text)
    end)

    it("defaults target to _blank", function()
      local result = Link.url_macro.handler(ctx, { "https://example.com" })
      assert.equals("_blank", result.target)
    end)
  end)

  describe("open macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates open data", function()
      local result = Link.open_macro.handler(ctx, { "https://example.com" })
      assert.is_table(result)
      assert.equals("open", result._type)
      assert.equals("https://example.com", result.url)
    end)

    it("defaults target to _blank", function()
      local result = Link.open_macro.handler(ctx, { "https://example.com" })
      assert.equals("_blank", result.target)
    end)

    it("accepts options", function()
      local result = Link.open_macro.handler(ctx, { "url", { target = "_self" } })
      assert.equals("_self", result.target)
    end)
  end)

  describe("linkshow macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("shows link when condition is true", function()
      local result = Link.linkshow_macro.handler(ctx, { true, "Click", "action" })
      assert.is_table(result)
      assert.is_true(result.visible)
    end)

    it("hides link when condition is false", function()
      local result = Link.linkshow_macro.handler(ctx, { false, "Click" })
      assert.is_false(result.visible)
    end)

    it("evaluates function condition", function()
      local result = Link.linkshow_macro.handler(ctx, { function() return true end, "Click" })
      assert.is_true(result.visible)
    end)
  end)

  describe("linkonce macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link once data", function()
      local result = Link.linkonce_macro.handler(ctx, { "secret", "Open", "action" })
      assert.is_table(result)
      assert.equals("link_once", result._type)
      assert.equals("secret", result.id)
    end)

    it("is enabled when not clicked", function()
      local result = Link.linkonce_macro.handler(ctx, { "new-link", "Click" })
      assert.is_true(result.enabled)
      assert.is_false(result.clicked)
    end)

    it("is disabled when already clicked", function()
      ctx:set("_clicked_links", { ["used-link"] = true })
      local result = Link.linkonce_macro.handler(ctx, { "used-link", "Click" })
      assert.is_false(result.enabled)
      assert.is_true(result.clicked)
    end)
  end)

  describe("linkvisited macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_clicked_links", {
        ["clicked-link"] = true,
      })
    end)

    it("returns true for clicked link", function()
      local result = Link.linkvisited_macro.handler(ctx, { "clicked-link" })
      assert.is_true(result)
    end)

    it("returns false for unclicked link", function()
      local result = Link.linkvisited_macro.handler(ctx, { "unclicked" })
      assert.is_false(result)
    end)

    it("is pure", function()
      assert.is_true(Link.linkvisited_macro.pure)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Link.register_all(registry)

      assert.is_true(count >= 18)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Link.register_all(registry)

      assert.is_not_nil(registry:get("link"))
      assert.is_not_nil(registry:get("linkgoto"))
      assert.is_not_nil(registry:get("goto"))
      assert.is_not_nil(registry:get("back"))
      assert.is_not_nil(registry:get("choice"))
      assert.is_not_nil(registry:get("url"))
    end)

    it("macros have link category", function()
      local registry = Registry.new()
      Link.register_all(registry)

      local macro = registry:get("link")
      assert.equals("link", macro.category)
    end)
  end)
end)
