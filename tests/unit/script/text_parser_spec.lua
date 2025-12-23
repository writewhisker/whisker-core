-- tests/unit/script/text_parser_spec.lua
-- Unit tests for text parser with i18n support (Stage 7)

describe("Text Parser", function()
  local TextParser

  before_each(function()
    package.loaded["whisker.script.text_parser"] = nil
    package.loaded["whisker.script.i18n_tags"] = nil
    TextParser = require("whisker.script.text_parser")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", TextParser._VERSION)
    end)
  end)

  describe("parse()", function()
    it("parses plain text", function()
      local result = TextParser.parse("Hello world")

      assert.equals("text_block", result.type)
      assert.equals(1, #result.nodes)
      assert.equals("text", result.nodes[1].type)
      assert.equals("Hello world", result.nodes[1].value)
    end)

    it("parses i18n tag alone", function()
      local result = TextParser.parse("@@t greeting")

      assert.equals("text_block", result.type)
      assert.equals(1, #result.nodes)
      assert.equals("i18n_translate", result.nodes[1].type)
      assert.equals("greeting", result.nodes[1].key)
    end)

    it("parses text followed by i18n tag", function()
      local result = TextParser.parse("Hello @@t greeting")

      assert.equals(2, #result.nodes)
      assert.equals("text", result.nodes[1].type)
      assert.equals("Hello ", result.nodes[1].value)
      assert.equals("i18n_translate", result.nodes[2].type)
    end)

    it("parses i18n tag followed by text", function()
      local result = TextParser.parse("@@t greeting World")

      -- Note: "World" is part of the tag line until newline
      assert.equals(1, #result.nodes)
      assert.equals("i18n_translate", result.nodes[1].type)
    end)

    it("parses plural tag", function()
      local result = TextParser.parse("@@p items count=n")

      assert.equals(1, #result.nodes)
      assert.equals("i18n_plural", result.nodes[1].type)
      assert.equals("items", result.nodes[1].key)
    end)

    it("parses mixed content", function()
      local result = TextParser.parse("You have @@p items count=n in your bag")

      assert.equals(2, #result.nodes)
      assert.equals("text", result.nodes[1].type)
      assert.equals("You have ", result.nodes[1].value)
      assert.equals("i18n_plural", result.nodes[2].type)
    end)

    it("handles empty input", function()
      local result = TextParser.parse("")

      assert.equals("text_block", result.type)
      assert.equals(0, #result.nodes)
    end)

    it("handles nil input", function()
      local result = TextParser.parse(nil)

      assert.equals("text_block", result.type)
      assert.equals(0, #result.nodes)
    end)
  end)

  describe("split()", function()
    it("splits plain text", function()
      local parts = TextParser.split("Hello world")

      assert.equals(1, #parts)
      assert.equals("Hello world", parts[1])
    end)

    it("splits at @@t", function()
      local parts = TextParser.split("Hello @@t greeting")

      assert.equals(2, #parts)
      assert.equals("Hello ", parts[1])
      assert.equals("@@t greeting", parts[2])
    end)

    it("splits at @@p", function()
      local parts = TextParser.split("You have @@p items count=n items")

      assert.equals(2, #parts)
      assert.equals("You have ", parts[1])
      assert.equals("@@p items count=n items", parts[2])
    end)

    it("handles multiple tags on same line", function()
      -- When tags are on the same line, they get merged (until newline)
      local parts = TextParser.split("Say @@t hello then @@t goodbye")

      -- The first tag @@t hello then @@t goodbye is captured as one tag until end
      assert.equals(2, #parts)
      assert.equals("Say ", parts[1])
      assert.equals("@@t hello then @@t goodbye", parts[2])
    end)

    it("handles multiple tags on separate lines", function()
      local parts = TextParser.split("@@t hello\n@@t goodbye")

      assert.equals(3, #parts)
      assert.equals("@@t hello", parts[1])
      assert.equals("\n", parts[2])
      assert.equals("@@t goodbye", parts[3])
    end)

    it("handles newline separation", function()
      local parts = TextParser.split("@@t hello\nworld")

      assert.equals(2, #parts)
      assert.equals("@@t hello", parts[1])
      assert.equals("\nworld", parts[2])
    end)

    it("handles tag at start", function()
      local parts = TextParser.split("@@t greeting")

      assert.equals(1, #parts)
      assert.equals("@@t greeting", parts[1])
    end)

    it("handles empty string", function()
      local parts = TextParser.split("")
      assert.equals(0, #parts)
    end)
  end)

  describe("hasI18nTags()", function()
    it("returns true for @@t", function()
      assert.is_true(TextParser.hasI18nTags("Say @@t greeting"))
    end)

    it("returns true for @@p", function()
      assert.is_true(TextParser.hasI18nTags("You have @@p items count=n"))
    end)

    it("returns false for plain text", function()
      assert.is_false(TextParser.hasI18nTags("Hello world"))
    end)

    it("returns false for nil", function()
      assert.is_false(TextParser.hasI18nTags(nil))
    end)

    it("returns false for @@ without t or p", function()
      assert.is_false(TextParser.hasI18nTags("Email: user@@example.com"))
    end)
  end)

  describe("countI18nTags()", function()
    it("returns 0,0 for plain text", function()
      local t, p = TextParser.countI18nTags("Hello world")
      assert.equals(0, t)
      assert.equals(0, p)
    end)

    it("counts translate tags", function()
      local t, p = TextParser.countI18nTags("@@t a @@t b @@t c")
      assert.equals(3, t)
      assert.equals(0, p)
    end)

    it("counts plural tags", function()
      local t, p = TextParser.countI18nTags("@@p a count=1 @@p b count=2")
      assert.equals(0, t)
      assert.equals(2, p)
    end)

    it("counts mixed tags", function()
      local t, p = TextParser.countI18nTags("@@t hello @@p items count=n @@t goodbye")
      assert.equals(2, t)
      assert.equals(1, p)
    end)

    it("returns 0,0 for nil", function()
      local t, p = TextParser.countI18nTags(nil)
      assert.equals(0, t)
      assert.equals(0, p)
    end)
  end)

  describe("extractKeys()", function()
    it("extracts no keys from plain text", function()
      local keys = TextParser.extractKeys("Hello world")
      assert.same({}, keys)
    end)

    it("extracts key from @@t", function()
      local keys = TextParser.extractKeys("@@t greeting")
      assert.same({"greeting"}, keys)
    end)

    it("extracts key from @@p", function()
      local keys = TextParser.extractKeys("@@p items.count count=n")
      assert.same({"items.count"}, keys)
    end)

    it("extracts multiple keys", function()
      local keys = TextParser.extractKeys("@@t hello\n@@t world\n@@p items count=n")
      assert.equals(3, #keys)
      assert.equals("hello", keys[1])
      assert.equals("world", keys[2])
      assert.equals("items", keys[3])
    end)

    it("extracts dotted keys", function()
      local keys = TextParser.extractKeys("@@t dialogue.npc.greeting")
      assert.same({"dialogue.npc.greeting"}, keys)
    end)
  end)
end)
