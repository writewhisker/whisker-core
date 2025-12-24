--- Snowman handler unit tests
-- Tests Snowman ERB-style template parsing and JavaScript translation
--
-- tests/unit/twine/formats/snowman/handler_spec.lua

describe("SnowmanHandler", function()
  local SnowmanHandler
  local TemplateParser
  local JSTranslator
  local LinkParser

  before_each(function()
    package.loaded['whisker.twine.formats.snowman.handler'] = nil
    package.loaded['whisker.twine.formats.snowman.template_parser'] = nil
    package.loaded['whisker.twine.formats.snowman.js_translator'] = nil
    package.loaded['whisker.twine.formats.snowman.link_parser'] = nil
    SnowmanHandler = require('whisker.twine.formats.snowman.handler')
    TemplateParser = require('whisker.twine.formats.snowman.template_parser')
    JSTranslator = require('whisker.twine.formats.snowman.js_translator')
    LinkParser = require('whisker.twine.formats.snowman.link_parser')
  end)

  describe("initialization", function()
    it("creates a new handler instance", function()
      local handler = SnowmanHandler.new()
      assert.is_not_nil(handler)
      assert.equals("snowman", handler.format_name)
    end)

    it("supports Snowman versions", function()
      local handler = SnowmanHandler.new()
      assert.is_true(#handler.supported_versions > 0)
      assert.is_true(handler:is_version_supported("2.0"))
    end)
  end)

  describe("format detection", function()
    it("detects Snowman format", function()
      local handler = SnowmanHandler.new()
      local html_data = { metadata = { format = "Snowman" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("detects Snowman with version", function()
      local handler = SnowmanHandler.new()
      local html_data = { metadata = { format = "Snowman-2.0.2" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("rejects non-Snowman format", function()
      local handler = SnowmanHandler.new()
      local html_data = { metadata = { format = "SugarCube" } }
      assert.is_false(handler:detect(html_data))
    end)
  end)

  describe("TemplateParser", function()
    describe("parse_template_tag", function()
      it("parses expression tag <%=", function()
        local content = "Health: <%= s.health %>"
        local node, pos = TemplateParser.parse_template_tag(content, 9)

        assert.is_not_nil(node)
        assert.equals("expression", node.type)
        assert.equals("s.health", node.code)
        assert.equals(24, pos)
      end)

      it("parses code block <%", function()
        local content = "<% s.gold = 100 %>"
        local node, pos = TemplateParser.parse_template_tag(content, 1)

        assert.is_not_nil(node)
        assert.equals("code_block", node.type)
        assert.equals("s.gold = 100", node.code)
      end)

      it("returns nil for non-template content", function()
        local content = "Just text"
        local node = TemplateParser.parse_template_tag(content, 1)
        assert.is_nil(node)
      end)

      it("handles string literals in templates", function()
        local content = '<% s.name = "Hero" %>'
        local node, pos = TemplateParser.parse_template_tag(content, 1)

        assert.is_not_nil(node)
        assert.equals("code_block", node.type)
        assert.equals('s.name = "Hero"', node.code)
      end)
    end)
  end)

  describe("JSTranslator", function()
    describe("translate_expression", function()
      it("translates s.variable to variable", function()
        local lua_expr, warnings = JSTranslator.translate_expression("s.health")
        assert.equals("health", lua_expr)
      end)

      it("translates s.obj.prop to obj.prop", function()
        local lua_expr, warnings = JSTranslator.translate_expression("s.player.name")
        assert.equals("player.name", lua_expr)
      end)

      it("handles string literals", function()
        local lua_expr, warnings = JSTranslator.translate_expression('"hello"')
        assert.equals('"hello"', lua_expr)
      end)

      it("handles numbers", function()
        local lua_expr, warnings = JSTranslator.translate_expression("42")
        assert.equals("42", lua_expr)
      end)

      it("handles booleans", function()
        local lua_expr, warnings = JSTranslator.translate_expression("true")
        assert.equals("true", lua_expr)
      end)

      it("translates array access with index adjustment", function()
        local lua_expr, warnings = JSTranslator.translate_expression("s.items[0]")
        assert.equals("items[1]", lua_expr)
      end)

      it("translates passage.name", function()
        local lua_expr, warnings = JSTranslator.translate_expression("passage.name")
        assert.equals("current_passage_name", lua_expr)
      end)

      it("returns nil for untranslatable expressions", function()
        local lua_expr, warnings = JSTranslator.translate_expression("complex.function()")
        assert.is_nil(lua_expr)
        assert.is_true(#warnings > 0)
      end)
    end)

    describe("translate_block", function()
      it("translates variable assignment", function()
        local lua_code, warnings = JSTranslator.translate_block("s.gold = 100;")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("gold = 100") ~= nil)
      end)

      it("translates initialization pattern", function()
        local lua_code, warnings = JSTranslator.translate_block("s.gold = s.gold || 50;")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("gold = gold or 50") ~= nil)
      end)

      it("translates compound assignment +=", function()
        local lua_code, warnings = JSTranslator.translate_block("s.gold += 10;")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("gold = gold %+ 10") ~= nil)
      end)

      it("translates compound assignment -=", function()
        local lua_code, warnings = JSTranslator.translate_block("s.health -= 5;")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("health = health %- 5") ~= nil)
      end)

      it("translates if statement", function()
        local lua_code, warnings = JSTranslator.translate_block("if (s.gold > 50) {")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("if gold > 50 then") ~= nil)
      end)

      it("translates else if statement", function()
        local lua_code, warnings = JSTranslator.translate_block("} else if (s.gold > 25) {")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("elseif gold > 25 then") ~= nil)
      end)

      it("translates else statement", function()
        local lua_code, warnings = JSTranslator.translate_block("} else {")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("else") ~= nil)
      end)

      it("translates closing brace to end", function()
        local lua_code, warnings = JSTranslator.translate_block("}")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("end") ~= nil)
      end)

      it("translates window.story.show", function()
        local lua_code, warnings = JSTranslator.translate_block("window.story.show('NextPassage');")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find('goto%("NextPassage"%)') ~= nil)
      end)

      it("translates story.show without window prefix", function()
        local lua_code, warnings = JSTranslator.translate_block("story.show('NextPassage');")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find('goto%("NextPassage"%)') ~= nil)
      end)

      it("translates JavaScript comments", function()
        local lua_code, warnings = JSTranslator.translate_block("// This is a comment")
        assert.is_not_nil(lua_code)
        assert.is_true(lua_code:find("-- ") ~= nil)
      end)

      it("returns nil for empty code", function()
        local lua_code, warnings = JSTranslator.translate_block("")
        assert.is_nil(lua_code)
      end)
    end)

    describe("_translate_condition", function()
      it("translates === to ==", function()
        local lua_cond = JSTranslator._translate_condition("s.state === 'ready'")
        assert.is_true(lua_cond:find("==") ~= nil)
        assert.is_nil(lua_cond:find("==="))
      end)

      it("translates !== to ~=", function()
        local lua_cond = JSTranslator._translate_condition("s.state !== 'error'")
        assert.is_true(lua_cond:find("~=") ~= nil)
      end)

      it("translates != to ~=", function()
        local lua_cond = JSTranslator._translate_condition("s.state != 'error'")
        assert.is_true(lua_cond:find("~=") ~= nil)
      end)

      it("translates && to and", function()
        local lua_cond = JSTranslator._translate_condition("s.a && s.b")
        assert.is_true(lua_cond:find(" and ") ~= nil)
      end)

      it("translates || to or", function()
        local lua_cond = JSTranslator._translate_condition("s.a || s.b")
        assert.is_true(lua_cond:find(" or ") ~= nil)
      end)

      it("translates ! to not", function()
        local lua_cond = JSTranslator._translate_condition("!s.flag")
        assert.is_true(lua_cond:find("not ") ~= nil)
      end)

      it("removes s. prefix from variables", function()
        local lua_cond = JSTranslator._translate_condition("s.health > 50")
        assert.equals("health > 50", lua_cond)
      end)
    end)
  end)

  describe("LinkParser", function()
    describe("parse_links", function()
      it("extracts data-passage links", function()
        local html = '<a href="#" data-passage="Forest">Go to forest</a>'
        local links = LinkParser.parse_links(html)

        assert.equals(1, #links)
        assert.equals("Go to forest", links[1].text)
        assert.equals("Forest", links[1].destination)
      end)

      it("extracts multiple links", function()
        local html = '<a data-passage="A">Link A</a> and <a data-passage="B">Link B</a>'
        local links = LinkParser.parse_links(html)

        assert.equals(2, #links)
      end)
    end)

    describe("replace_links_with_choices", function()
      it("converts links to choice nodes", function()
        local html = '<a data-passage="Forest">Go to forest</a>'
        local nodes = LinkParser.replace_links_with_choices(html)

        assert.equals(1, #nodes)
        assert.equals("choice", nodes[1].type)
        assert.equals("Go to forest", nodes[1].text)
        assert.equals("Forest", nodes[1].destination)
      end)

      it("preserves text before links", function()
        local html = 'You see a path. <a data-passage="Forest">Follow it</a>'
        local nodes = LinkParser.replace_links_with_choices(html)

        assert.equals(2, #nodes)
        assert.equals("text", nodes[1].type)
        assert.equals("choice", nodes[2].type)
      end)
    end)

    describe("has_data_passage_links", function()
      it("returns true for content with links", function()
        local html = '<a data-passage="Test">Link</a>'
        assert.is_true(LinkParser.has_data_passage_links(html))
      end)

      it("returns false for content without links", function()
        local html = 'Just plain text'
        assert.is_false(LinkParser.has_data_passage_links(html))
      end)
    end)
  end)

  describe("parse_passage", function()
    it("parses expression template", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "Gold: <%= s.gold %>" }
      local ast = handler:parse_passage(passage)

      assert.equals(2, #ast)
      assert.equals("text", ast[1].type)
      assert.equals("print", ast[2].type)
      assert.equals("gold", ast[2].expression)
    end)

    it("parses code block template", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "<% s.health = 100 %>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("script_block", ast[1].type)
    end)

    it("parses mixed content", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "You have <%= s.gold %> gold." }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 2)
      -- Should have text, print, text
      local has_print = false
      local has_text = false
      for _, node in ipairs(ast) do
        if node.type == "print" then has_print = true end
        if node.type == "text" then has_text = true end
      end
      assert.is_true(has_print)
      assert.is_true(has_text)
    end)

    it("handles conditional blocks", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "<% if (s.gold > 50) { %>Rich!<% } %>" }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 1)
    end)

    it("parses data-passage links", function()
      local handler = SnowmanHandler.new()
      local passage = { content = '<a data-passage="Forest">Go to forest</a>' }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 1)
      -- Should contain a choice node
      local has_choice = false
      for _, node in ipairs(ast) do
        if node.type == "choice" then
          has_choice = true
        elseif node.type == "fragment" then
          for _, child in ipairs(node.children or {}) do
            if child.type == "choice" then has_choice = true end
          end
        end
      end
      assert.is_true(has_choice)
    end)

    it("returns empty for empty content", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "" }
      local ast = handler:parse_passage(passage)
      assert.equals(0, #ast)
    end)

    it("generates warning for untranslatable code", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "<% document.querySelector('div').innerHTML = 'test'; %>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("warning", ast[1].type)
    end)
  end)

  describe("complex scenarios", function()
    it("handles initialization and display", function()
      local handler = SnowmanHandler.new()
      local passage = { content = "<% s.gold = s.gold || 100 %>\nYou have <%= s.gold %> gold." }
      local ast = handler:parse_passage(passage)

      local has_script = false
      local has_print = false
      for _, node in ipairs(ast) do
        if node.type == "script_block" then has_script = true end
        if node.type == "print" then has_print = true end
      end
      assert.is_true(has_script)
      assert.is_true(has_print)
    end)

    it("handles nested conditional with links", function()
      local handler = SnowmanHandler.new()
      local passage = { content = '<% if (s.hasKey) { %><a data-passage="Chest">Open chest</a><% } %>' }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 1)
    end)
  end)
end)
