-- tests/unit/script/i18n_tags_spec.lua
-- Unit tests for i18n tags parser (Stage 7)

describe("I18n Tag Parser", function()
  local I18nTags

  before_each(function()
    package.loaded["whisker.script.i18n_tags"] = nil
    I18nTags = require("whisker.script.i18n_tags")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", I18nTags._VERSION)
    end)
  end)

  describe("@@t syntax", function()
    it("parses simple key", function()
      local node = I18nTags.parse("@@t greeting")

      assert.equals("i18n_translate", node.type)
      assert.equals("greeting", node.key)
      assert.same({}, node.args)
    end)

    it("parses with single variable", function()
      local node = I18nTags.parse("@@t welcome name=playerName")

      assert.equals("welcome", node.key)
      assert.is_not_nil(node.args.name)
      assert.equals("playerName", node.args.name.expression)
      assert.equals("name", node.args.name.name)
    end)

    it("parses with multiple variables", function()
      local node = I18nTags.parse("@@t message user=player.name item=sword.name")

      assert.is_not_nil(node.args.user)
      assert.is_not_nil(node.args.item)
      assert.equals("player.name", node.args.user.expression)
      assert.equals("sword.name", node.args.item.expression)
    end)

    it("parses dotted keys", function()
      local node = I18nTags.parse("@@t dialogue.npc.greeting")

      assert.equals("dialogue.npc.greeting", node.key)
    end)

    it("parses deeply nested keys", function()
      local node = I18nTags.parse("@@t game.world.zone.npc.dialogue.intro")

      assert.equals("game.world.zone.npc.dialogue.intro", node.key)
    end)

    it("stores raw text", function()
      local text = "@@t welcome name=player"
      local node = I18nTags.parse(text)

      assert.equals(text, node.raw)
    end)

    it("errors when key is missing", function()
      assert.has_error(function()
        I18nTags.parse("@@t ")
      end)
    end)

    it("returns nil for non-i18n text", function()
      local node = I18nTags.parse("Hello world")
      assert.is_nil(node)
    end)

    it("returns nil for empty text", function()
      local node = I18nTags.parse("")
      assert.is_nil(node)
    end)

    it("returns nil for nil input", function()
      local node = I18nTags.parse(nil)
      assert.is_nil(node)
    end)
  end)

  describe("@@p syntax", function()
    it("parses with count", function()
      local node = I18nTags.parse("@@p items.count count=inventory.size")

      assert.equals("i18n_plural", node.type)
      assert.equals("items.count", node.key)
      assert.equals("inventory.size", node.args.count.expression)
    end)

    it("stores count separately", function()
      local node = I18nTags.parse("@@p items count=n")

      assert.is_not_nil(node.count)
      assert.equals("n", node.count.expression)
    end)

    it("errors without count", function()
      assert.has_error(function()
        I18nTags.parse("@@p items.count")
      end)
    end)

    it("parses with count and other variables", function()
      local node = I18nTags.parse("@@p found count=n item=itemName location=room")

      assert.equals("n", node.args.count.expression)
      assert.equals("itemName", node.args.item.expression)
      assert.equals("room", node.args.location.expression)
    end)

    it("parses dotted count expression", function()
      local node = I18nTags.parse("@@p items count=player.inventory.size")

      assert.equals("player.inventory.size", node.args.count.expression)
    end)
  end)

  describe("parseArgs()", function()
    it("parses empty args", function()
      local args = I18nTags.parseArgs("")
      assert.same({}, args)
    end)

    it("parses nil args", function()
      local args = I18nTags.parseArgs(nil)
      assert.same({}, args)
    end)

    it("parses single arg", function()
      local args = I18nTags.parseArgs("name=value")

      assert.is_not_nil(args.name)
      assert.equals("value", args.name.expression)
    end)

    it("parses multiple args", function()
      local args = I18nTags.parseArgs("a=1 b=2 c=3")

      assert.equals("1", args.a.expression)
      assert.equals("2", args.b.expression)
      assert.equals("3", args.c.expression)
    end)

    it("parses dotted values", function()
      local args = I18nTags.parseArgs("name=player.character.name")

      assert.equals("player.character.name", args.name.expression)
    end)
  end)

  describe("validate()", function()
    it("validates valid translate node", function()
      local node = {
        type = "i18n_translate",
        key = "greeting",
        args = {}
      }

      local ok, err = I18nTags.validate(node)
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it("validates valid plural node", function()
      local node = {
        type = "i18n_plural",
        key = "items.count",
        args = {
          count = { expression = "n" }
        }
      }

      local ok, err = I18nTags.validate(node)
      assert.is_true(ok)
    end)

    it("rejects nil node", function()
      local ok, err = I18nTags.validate(nil)
      assert.is_false(ok)
      assert.equals("Node is nil", err)
    end)

    it("rejects invalid key format", function()
      local node = {
        type = "i18n_translate",
        key = "invalid key with spaces",
        args = {}
      }

      local ok, err = I18nTags.validate(node)
      assert.is_false(ok)
      assert.matches("Invalid translation key", err)
    end)

    it("validates dotted keys", function()
      local node = {
        type = "i18n_translate",
        key = "deeply.nested.key.here",
        args = {}
      }

      local ok = I18nTags.validate(node)
      assert.is_true(ok)
    end)
  end)

  describe("isI18nTag()", function()
    it("returns true for @@t", function()
      assert.is_true(I18nTags.isI18nTag("@@t greeting"))
    end)

    it("returns true for @@p", function()
      assert.is_true(I18nTags.isI18nTag("@@p items count=n"))
    end)

    it("returns false for regular text", function()
      assert.is_false(I18nTags.isI18nTag("Hello world"))
    end)

    it("returns false for nil", function()
      assert.is_false(I18nTags.isI18nTag(nil))
    end)

    it("returns false for @@t without space", function()
      assert.is_false(I18nTags.isI18nTag("@@tgreeting"))
    end)
  end)

  describe("getTagType()", function()
    it("returns 't' for translate tag", function()
      assert.equals("t", I18nTags.getTagType("@@t greeting"))
    end)

    it("returns 'p' for plural tag", function()
      assert.equals("p", I18nTags.getTagType("@@p items count=n"))
    end)

    it("returns nil for non-tag", function()
      assert.is_nil(I18nTags.getTagType("Hello"))
    end)

    it("returns nil for nil input", function()
      assert.is_nil(I18nTags.getTagType(nil))
    end)
  end)

  describe("countArgs()", function()
    it("returns 0 for nil node", function()
      assert.equals(0, I18nTags.countArgs(nil))
    end)

    it("returns 0 for empty args", function()
      local node = I18nTags.parse("@@t greeting")
      assert.equals(0, I18nTags.countArgs(node))
    end)

    it("counts single arg", function()
      local node = I18nTags.parse("@@t welcome name=player")
      assert.equals(1, I18nTags.countArgs(node))
    end)

    it("counts multiple args", function()
      local node = I18nTags.parse("@@t message a=1 b=2 c=3")
      assert.equals(3, I18nTags.countArgs(node))
    end)
  end)

  describe("getArgNames()", function()
    it("returns empty for no args", function()
      local node = I18nTags.parse("@@t greeting")
      assert.same({}, I18nTags.getArgNames(node))
    end)

    it("returns sorted arg names", function()
      local node = I18nTags.parse("@@t message c=3 a=1 b=2")
      local names = I18nTags.getArgNames(node)
      assert.same({"a", "b", "c"}, names)
    end)
  end)
end)
