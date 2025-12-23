--- Template Engine Tests
-- @module tests.unit.export.template_engine_spec

describe("TemplateEngine", function()
  local TemplateEngine
  local engine

  before_each(function()
    package.loaded["whisker.export.template_engine"] = nil
    TemplateEngine = require("whisker.export.template_engine")
    engine = TemplateEngine.new()
  end)

  describe("new", function()
    it("creates a new template engine", function()
      assert.is_table(engine)
    end)
  end)

  describe("register/get", function()
    it("registers and retrieves templates", function()
      engine:register("test", "Hello {{name}}!")
      assert.equals("Hello {{name}}!", engine:get("test"))
    end)

    it("returns nil for unregistered template", function()
      assert.is_nil(engine:get("unknown"))
    end)
  end)

  describe("register_partial/get_partial", function()
    it("registers and retrieves partials", function()
      engine:register_partial("nav", "<nav>...</nav>")
      assert.equals("<nav>...</nav>", engine:get_partial("nav"))
    end)

    it("returns nil for unregistered partial", function()
      assert.is_nil(engine:get_partial("unknown"))
    end)
  end)

  describe("has_template/has_partial", function()
    it("returns true for registered template", function()
      engine:register("test", "content")
      assert.is_true(engine:has_template("test"))
    end)

    it("returns false for unregistered template", function()
      assert.is_false(engine:has_template("unknown"))
    end)

    it("returns true for registered partial", function()
      engine:register_partial("nav", "content")
      assert.is_true(engine:has_partial("nav"))
    end)

    it("returns false for unregistered partial", function()
      assert.is_false(engine:has_partial("unknown"))
    end)
  end)

  describe("render", function()
    it("throws error for unregistered template", function()
      assert.has_error(function()
        engine:render("unknown", {})
      end)
    end)

    it("renders simple template", function()
      engine:register("test", "Hello World!")
      local result = engine:render("test", {})
      assert.equals("Hello World!", result)
    end)
  end)

  describe("render_string", function()
    describe("variable substitution", function()
      it("renders simple variables", function()
        local result = engine:render_string("Hello {{name}}!", { name = "World" })
        assert.equals("Hello World!", result)
      end)

      it("renders nested variables", function()
        local result = engine:render_string("{{story.title}}", {
          story = { title = "My Story" }
        })
        assert.equals("My Story", result)
      end)

      it("renders deeply nested variables", function()
        local result = engine:render_string("{{a.b.c}}", {
          a = { b = { c = "deep" } }
        })
        assert.equals("deep", result)
      end)

      it("handles missing variables", function()
        local result = engine:render_string("{{missing}}", {})
        assert.equals("", result)
      end)

      it("handles missing nested variables", function()
        local result = engine:render_string("{{a.missing}}", { a = {} })
        assert.equals("", result)
      end)

      it("handles whitespace in variable names", function()
        local result = engine:render_string("{{ name }}", { name = "test" })
        assert.equals("test", result)
      end)
    end)

    describe("triple-brace (unescaped) variables", function()
      it("renders unescaped content", function()
        local result = engine:render_string("{{{content}}}", { content = "<b>bold</b>" })
        assert.equals("<b>bold</b>", result)
      end)
    end)

    describe("partials", function()
      it("renders partials", function()
        engine:register_partial("middle", "MIDDLE")
        local result = engine:render_string("Start {{> middle}} End", {})
        assert.equals("Start MIDDLE End", result)
      end)

      it("renders partials with data", function()
        engine:register_partial("greeting", "Hello {{name}}")
        local result = engine:render_string("{{> greeting}}!", { name = "World" })
        assert.equals("Hello World!", result)
      end)

      it("handles missing partials", function()
        local result = engine:render_string("{{> missing}}", {})
        assert.truthy(result:match("not found"))
      end)

      it("handles nested partials", function()
        engine:register_partial("inner", "INNER")
        engine:register_partial("outer", "[{{> inner}}]")
        local result = engine:render_string("{{> outer}}", {})
        assert.equals("[INNER]", result)
      end)
    end)

    describe("helpers", function()
      it("calls helper functions", function()
        engine:register_helper("upper", function(value)
          return string.upper(value)
        end)
        local result = engine:render_string("{{upper name}}", { name = "hello" })
        assert.equals("HELLO", result)
      end)

      it("handles missing helpers", function()
        local result = engine:render_string("{{unknown_helper value}}", { value = "test" })
        assert.truthy(result:match("not found"))
      end)

      it("passes literal values to helpers", function()
        engine:register_helper("echo", function(value)
          return "Echo: " .. tostring(value)
        end)
        local result = engine:render_string("{{echo literal}}", {})
        assert.equals("Echo: literal", result)
      end)
    end)

    describe("conditionals", function()
      it("renders content when condition is truthy", function()
        local result = engine:render_string("{{#if show}}VISIBLE{{/if}}", { show = true })
        assert.equals("VISIBLE", result)
      end)

      it("hides content when condition is falsy", function()
        local result = engine:render_string("{{#if show}}VISIBLE{{/if}}", { show = false })
        assert.equals("", result)
      end)

      it("hides content when condition is nil", function()
        local result = engine:render_string("{{#if show}}VISIBLE{{/if}}", {})
        assert.equals("", result)
      end)

      it("hides content when condition is empty string", function()
        local result = engine:render_string("{{#if show}}VISIBLE{{/if}}", { show = "" })
        assert.equals("", result)
      end)

      it("works with nested values", function()
        local result = engine:render_string("{{#if story.author}}by {{story.author}}{{/if}}", {
          story = { author = "Jane" }
        })
        assert.equals("by Jane", result)
      end)
    end)
  end)

  describe("get_nested_value", function()
    it("gets simple values", function()
      local value = engine:get_nested_value({ name = "test" }, "name")
      assert.equals("test", value)
    end)

    it("gets nested values", function()
      local value = engine:get_nested_value({ a = { b = "deep" } }, "a.b")
      assert.equals("deep", value)
    end)

    it("returns nil for missing path", function()
      local value = engine:get_nested_value({ a = {} }, "a.b")
      assert.is_nil(value)
    end)

    it("returns nil for nil data", function()
      local value = engine:get_nested_value(nil, "anything")
      assert.is_nil(value)
    end)

    it("returns nil for nil path", function()
      local value = engine:get_nested_value({}, nil)
      assert.is_nil(value)
    end)
  end)

  describe("get_template_names", function()
    it("returns empty array when no templates", function()
      local names = engine:get_template_names()
      assert.same({}, names)
    end)

    it("returns sorted template names", function()
      engine:register("z_template", "")
      engine:register("a_template", "")
      engine:register("m_template", "")

      local names = engine:get_template_names()
      assert.same({"a_template", "m_template", "z_template"}, names)
    end)
  end)

  describe("get_partial_names", function()
    it("returns sorted partial names", function()
      engine:register_partial("footer", "")
      engine:register_partial("header", "")

      local names = engine:get_partial_names()
      assert.same({"footer", "header"}, names)
    end)
  end)

  describe("clear", function()
    it("removes all templates and partials", function()
      engine:register("test", "content")
      engine:register_partial("partial", "content")
      engine:register_helper("helper", function() end)

      engine:clear()

      assert.is_nil(engine:get("test"))
      assert.is_nil(engine:get_partial("partial"))
    end)
  end)
end)
