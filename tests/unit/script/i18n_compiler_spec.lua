-- tests/unit/script/i18n_compiler_spec.lua
-- Unit tests for i18n compiler (Stage 7)

describe("I18n Compiler", function()
  local I18nCompiler
  local I18nTags
  local TextParser

  before_each(function()
    package.loaded["whisker.script.i18n_compiler"] = nil
    package.loaded["whisker.script.i18n_tags"] = nil
    package.loaded["whisker.script.text_parser"] = nil
    I18nCompiler = require("whisker.script.i18n_compiler")
    I18nTags = require("whisker.script.i18n_tags")
    TextParser = require("whisker.script.text_parser")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", I18nCompiler._VERSION)
    end)
  end)

  describe("compileTranslate()", function()
    it("compiles @@t with no variables", function()
      local node = {
        type = "i18n_translate",
        key = "greeting",
        args = {}
      }

      local code = I18nCompiler.compileTranslate(node, { locals = {} })
      assert.equals('_i18n:t("greeting", {})', code)
    end)

    it("compiles @@t with variables", function()
      local node = {
        type = "i18n_translate",
        key = "welcome",
        args = {
          name = { name = "name", expression = "player.name" }
        }
      }

      local code = I18nCompiler.compileTranslate(node, { locals = {} })
      assert.equals('_i18n:t("welcome", {name = _ctx.player.name})', code)
    end)

    it("compiles with dotted key", function()
      local node = {
        type = "i18n_translate",
        key = "dialogue.npc.intro",
        args = {}
      }

      local code = I18nCompiler.compileTranslate(node, { locals = {} })
      assert.equals('_i18n:t("dialogue.npc.intro", {})', code)
    end)

    it("compiles with multiple variables", function()
      local node = {
        type = "i18n_translate",
        key = "message",
        args = {
          a = { name = "a", expression = "val1" },
          b = { name = "b", expression = "val2" }
        }
      }

      local code = I18nCompiler.compileTranslate(node, { locals = {} })
      -- Variables should be sorted alphabetically
      assert.matches('_i18n:t%("message", {a = _ctx.val1, b = _ctx.val2}%)', code)
    end)
  end)

  describe("compilePlural()", function()
    it("compiles @@p with count only", function()
      local node = {
        type = "i18n_plural",
        key = "items.count",
        args = {
          count = { name = "count", expression = "inventory.size" }
        }
      }

      local code = I18nCompiler.compilePlural(node, { locals = {} })
      assert.equals('_i18n:p("items.count", _ctx.inventory.size, {})', code)
    end)

    it("compiles @@p with count and other variables", function()
      local node = {
        type = "i18n_plural",
        key = "found",
        args = {
          count = { name = "count", expression = "n" },
          item = { name = "item", expression = "itemName" }
        }
      }

      local code = I18nCompiler.compilePlural(node, { locals = {} })
      assert.equals('_i18n:p("found", _ctx.n, {item = _ctx.itemName})', code)
    end)
  end)

  describe("compileText()", function()
    it("compiles plain text", function()
      local node = {
        type = "text",
        value = "Hello world"
      }

      local code = I18nCompiler.compileText(node, {})
      assert.equals('"Hello world"', code)
    end)

    it("escapes quotes", function()
      local node = {
        type = "text",
        value = 'Say "Hello"'
      }

      local code = I18nCompiler.compileText(node, {})
      assert.equals('"Say \\"Hello\\""', code)
    end)

    it("escapes backslashes", function()
      local node = {
        type = "text",
        value = "Path\\to\\file"
      }

      local code = I18nCompiler.compileText(node, {})
      assert.equals('"Path\\\\to\\\\file"', code)
    end)

    it("escapes newlines", function()
      local node = {
        type = "text",
        value = "Line1\nLine2"
      }

      local code = I18nCompiler.compileText(node, {})
      assert.equals('"Line1\\nLine2"', code)
    end)
  end)

  describe("compileTextBlock()", function()
    it("compiles empty block", function()
      local node = {
        type = "text_block",
        nodes = {}
      }

      local code = I18nCompiler.compileTextBlock(node, { locals = {} })
      assert.equals('""', code)
    end)

    it("compiles single text node", function()
      local node = {
        type = "text_block",
        nodes = {
          { type = "text", value = "Hello" }
        }
      }

      local code = I18nCompiler.compileTextBlock(node, { locals = {} })
      assert.equals('"Hello"', code)
    end)

    it("compiles single i18n node", function()
      local node = {
        type = "text_block",
        nodes = {
          { type = "i18n_translate", key = "greeting", args = {} }
        }
      }

      local code = I18nCompiler.compileTextBlock(node, { locals = {} })
      assert.equals('_i18n:t("greeting", {})', code)
    end)

    it("concatenates multiple nodes", function()
      local node = {
        type = "text_block",
        nodes = {
          { type = "text", value = "Say " },
          { type = "i18n_translate", key = "greeting", args = {} }
        }
      }

      local code = I18nCompiler.compileTextBlock(node, { locals = {} })
      assert.equals('"Say " .. _i18n:t("greeting", {})', code)
    end)
  end)

  describe("compileVars()", function()
    it("compiles empty vars", function()
      local code = I18nCompiler.compileVars({}, { locals = {} })
      assert.equals("{}", code)
    end)

    it("compiles nil vars", function()
      local code = I18nCompiler.compileVars(nil, { locals = {} })
      assert.equals("{}", code)
    end)

    it("compiles single var", function()
      local args = {
        name = { name = "name", expression = "player" }
      }

      local code = I18nCompiler.compileVars(args, { locals = {} })
      assert.equals("{name = _ctx.player}", code)
    end)

    it("sorts multiple vars", function()
      local args = {
        z = { expression = "zval" },
        a = { expression = "aval" }
      }

      local code = I18nCompiler.compileVars(args, { locals = {} })
      assert.equals("{a = _ctx.aval, z = _ctx.zval}", code)
    end)
  end)

  describe("compileExpr()", function()
    it("compiles simple variable to context", function()
      local code = I18nCompiler.compileExpr("name", { locals = {} })
      assert.equals("_ctx.name", code)
    end)

    it("compiles dotted variable to context", function()
      local code = I18nCompiler.compileExpr("player.name", { locals = {} })
      assert.equals("_ctx.player.name", code)
    end)

    it("compiles local variable without context prefix", function()
      local code = I18nCompiler.compileExpr("localVar", { locals = { localVar = true } })
      assert.equals("localVar", code)
    end)

    it("compiles local with dotted access", function()
      local code = I18nCompiler.compileExpr("localVar.field", { locals = { localVar = true } })
      assert.equals("localVar.field", code)
    end)

    it("handles deeply nested paths", function()
      local code = I18nCompiler.compileExpr("a.b.c.d.e", { locals = {} })
      assert.equals("_ctx.a.b.c.d.e", code)
    end)
  end)

  describe("compile() dispatch", function()
    it("compiles i18n_translate", function()
      local node = I18nTags.parse("@@t greeting")
      local code = I18nCompiler.compile(node, { locals = {} })
      assert.equals('_i18n:t("greeting", {})', code)
    end)

    it("compiles i18n_plural", function()
      local node = I18nTags.parse("@@p items count=n")
      local code = I18nCompiler.compile(node, { locals = {} })
      assert.equals('_i18n:p("items", _ctx.n, {})', code)
    end)

    it("compiles text", function()
      local node = { type = "text", value = "Hello" }
      local code = I18nCompiler.compile(node, {})
      assert.equals('"Hello"', code)
    end)

    it("compiles text_block", function()
      local node = TextParser.parse("Hello @@t world")
      local code = I18nCompiler.compile(node, { locals = {} })
      assert.equals('"Hello " .. _i18n:t("world", {})', code)
    end)
  end)

  describe("generateOutput()", function()
    it("generates assignment", function()
      local node = { type = "text", value = "Hello" }
      local code = I18nCompiler.generateOutput(node, {}, "result")
      assert.equals('local result = "Hello"', code)
    end)

    it("generates expression without varName", function()
      local node = { type = "text", value = "Hello" }
      local code = I18nCompiler.generateOutput(node, {})
      assert.equals('"Hello"', code)
    end)
  end)

  describe("generatePrint()", function()
    it("generates print statement", function()
      local node = { type = "text", value = "Hello" }
      local code = I18nCompiler.generatePrint(node, {})
      assert.equals('print("Hello")', code)
    end)

    it("generates print with i18n", function()
      local node = I18nTags.parse("@@t greeting")
      local code = I18nCompiler.generatePrint(node, { locals = {} })
      assert.equals('print(_i18n:t("greeting", {}))', code)
    end)
  end)
end)

describe("I18n Integration", function()
  local Script
  local I18n

  before_each(function()
    package.loaded["whisker.script"] = nil
    package.loaded["whisker.script.i18n_tags"] = nil
    package.loaded["whisker.script.text_parser"] = nil
    package.loaded["whisker.script.i18n_compiler"] = nil
    package.loaded["whisker.i18n"] = nil
    package.loaded["whisker.i18n.init"] = nil

    Script = require("whisker.script")
    I18n = require("whisker.i18n")
  end)

  describe("Script module i18n functions", function()
    it("has getI18nTags", function()
      assert.is_function(Script.getI18nTags)
    end)

    it("has getTextParser", function()
      assert.is_function(Script.getTextParser)
    end)

    it("has getI18nCompiler", function()
      assert.is_function(Script.getI18nCompiler)
    end)

    it("has parseI18nTag", function()
      assert.is_function(Script.parseI18nTag)
    end)

    it("has parseI18nText", function()
      assert.is_function(Script.parseI18nText)
    end)

    it("has compileI18n", function()
      assert.is_function(Script.compileI18n)
    end)

    it("has hasI18nTags", function()
      assert.is_function(Script.hasI18nTags)
    end)

    it("has extractI18nKeys", function()
      assert.is_function(Script.extractI18nKeys)
    end)
  end)

  describe("parseI18nTag()", function()
    it("parses translate tag", function()
      local node = Script.parseI18nTag("@@t greeting")
      assert.equals("i18n_translate", node.type)
      assert.equals("greeting", node.key)
    end)

    it("parses plural tag", function()
      local node = Script.parseI18nTag("@@p items count=n")
      assert.equals("i18n_plural", node.type)
    end)
  end)

  describe("parseI18nText()", function()
    it("parses text with i18n", function()
      local node = Script.parseI18nText("Hello @@t world")
      assert.equals("text_block", node.type)
      assert.equals(2, #node.nodes)
    end)
  end)

  describe("compileI18n()", function()
    it("compiles i18n AST", function()
      local ast = Script.parseI18nText("@@t greeting")
      local code = Script.compileI18n(ast, { locals = {} })
      assert.equals('_i18n:t("greeting", {})', code)
    end)
  end)

  describe("hasI18nTags()", function()
    it("detects i18n tags", function()
      assert.is_true(Script.hasI18nTags("@@t greeting"))
      assert.is_false(Script.hasI18nTags("Hello"))
    end)
  end)

  describe("extractI18nKeys()", function()
    it("extracts keys", function()
      -- Tags on same line are combined, so need newlines
      local keys = Script.extractI18nKeys("@@t hello\n@@t world")
      assert.equals(2, #keys)
    end)

    it("extracts single key", function()
      local keys = Script.extractI18nKeys("@@t greeting")
      assert.equals(1, #keys)
      assert.equals("greeting", keys[1])
    end)
  end)

  describe("full pipeline", function()
    it("parses, compiles, and evaluates", function()
      -- Create i18n instance with translations
      local i18n = I18n.new():init({ autoDetect = false })
      i18n:loadData("en", {
        greeting = "Hello!",
        welcome = "Welcome, {name}!",
        items = {
          count = {
            one = "{count} item",
            other = "{count} items"
          }
        }
      })

      -- Parse source
      local source = "@@t greeting"
      local ast = Script.parseI18nText(source)

      -- Compile to Lua
      local code = Script.compileI18n(ast, { locals = {} })
      assert.equals('_i18n:t("greeting", {})', code)

      -- Execute compiled code
      local env = {
        _i18n = i18n,
        _ctx = {}
      }

      local func = load("return " .. code, "test", "t", env)
      local result = func()

      assert.equals("Hello!", result)
    end)

    it("handles variables in translation", function()
      local i18n = I18n.new():init({ autoDetect = false })
      i18n:loadData("en", {
        welcome = "Welcome, {name}!"
      })

      local ast = Script.parseI18nText("@@t welcome name=player.name")
      local code = Script.compileI18n(ast, { locals = {} })

      local env = {
        _i18n = i18n,
        _ctx = {
          player = { name = "Alice" }
        }
      }

      local func = load("return " .. code, "test", "t", env)
      local result = func()

      assert.equals("Welcome, Alice!", result)
    end)

    it("handles pluralization", function()
      local i18n = I18n.new():init({ autoDetect = false })
      i18n:loadData("en", {
        items = {
          one = "{count} item",
          other = "{count} items"
        }
      })

      local ast = Script.parseI18nText("@@p items count=inventory.size")
      local code = Script.compileI18n(ast, { locals = {} })

      -- Test with count=1
      local env1 = {
        _i18n = i18n,
        _ctx = {
          inventory = { size = 1 }
        }
      }
      local func1 = load("return " .. code, "test", "t", env1)
      assert.equals("1 item", func1())

      -- Test with count=5
      local env5 = {
        _i18n = i18n,
        _ctx = {
          inventory = { size = 5 }
        }
      }
      local func5 = load("return " .. code, "test", "t", env5)
      assert.equals("5 items", func5())
    end)

    it("handles mixed text and i18n", function()
      local i18n = I18n.new():init({ autoDetect = false })
      i18n:loadData("en", {
        world = "World"
      })

      local ast = Script.parseI18nText("Hello @@t world")
      local code = Script.compileI18n(ast, { locals = {} })

      local env = {
        _i18n = i18n,
        _ctx = {}
      }

      local func = load("return " .. code, "test", "t", env)
      local result = func()

      assert.equals("Hello World", result)
    end)
  end)
end)
