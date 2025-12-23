-- tests/unit/i18n/tools_extract_spec.lua
-- Unit tests for string extraction tool (Stage 8)

describe("Extract Tool", function()
  local Extract

  before_each(function()
    package.loaded["whisker.i18n.tools.extract"] = nil
    Extract = require("whisker.i18n.tools.extract")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", Extract._VERSION)
    end)
  end)

  describe("fromString()", function()
    it("extracts @@t tags", function()
      local source = "@@t greeting\nSome text\n@@t farewell"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals(2, #keys)
      assert.equals("greeting", keys[1].key)
      assert.equals("translate", keys[1].type)
      assert.equals(1, keys[1].line)
      assert.equals("farewell", keys[2].key)
      assert.equals(3, keys[2].line)
    end)

    it("extracts @@p tags", function()
      local source = "@@p items.count count=n"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals(1, #keys)
      assert.equals("items.count", keys[1].key)
      assert.equals("plural", keys[1].type)
    end)

    it("extracts variables", function()
      local source = "@@t welcome name=player.name location=room"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals(1, #keys)
      assert.equals(2, #keys[1].variables)
      assert.equals("name", keys[1].variables[1])
      assert.equals("location", keys[1].variables[2])
    end)

    it("extracts dotted keys", function()
      local source = "@@t dialogue.npc.intro"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals("dialogue.npc.intro", keys[1].key)
    end)

    it("extracts multiple tags on same line", function()
      local source = "Say @@t hello and @@t goodbye"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals(2, #keys)
      assert.equals("hello", keys[1].key)
      assert.equals("goodbye", keys[2].key)
    end)

    it("stores source file", function()
      local keys = Extract.fromString("@@t test", "myfile.whisker")
      assert.equals("myfile.whisker", keys[1].file)
    end)

    it("stores line number", function()
      local source = "line1\n@@t test\nline3"
      local keys = Extract.fromString(source, "test.whisker")

      assert.equals(2, keys[1].line)
    end)

    it("stores context", function()
      local source = "This is @@t greeting with context"
      local keys = Extract.fromString(source, "test.whisker")

      assert.is_not_nil(keys[1].context)
      assert.matches("greeting", keys[1].context)
    end)

    it("handles empty string", function()
      local keys = Extract.fromString("", "test.whisker")
      assert.equals(0, #keys)
    end)

    it("handles nil input", function()
      local keys = Extract.fromString(nil, "test.whisker")
      assert.equals(0, #keys)
    end)

    it("handles text without tags", function()
      local keys = Extract.fromString("Just plain text", "test.whisker")
      assert.equals(0, #keys)
    end)
  end)

  describe("deduplicate()", function()
    it("removes duplicate keys", function()
      local keys = {
        { key = "greeting", type = "translate", line = 1 },
        { key = "farewell", type = "translate", line = 2 },
        { key = "greeting", type = "translate", line = 3 }
      }

      local unique = Extract.deduplicate(keys)
      assert.equals(2, #unique)
    end)

    it("keeps first occurrence", function()
      local keys = {
        { key = "test", line = 1 },
        { key = "test", line = 5 }
      }

      local unique = Extract.deduplicate(keys)
      assert.equals(1, unique[1].line)
    end)

    it("handles empty list", function()
      local unique = Extract.deduplicate({})
      assert.equals(0, #unique)
    end)
  end)

  describe("buildTree()", function()
    it("builds simple tree", function()
      local keys = {
        { key = "greeting", type = "translate" }
      }

      local tree = Extract.buildTree(keys)
      assert.is_not_nil(tree.greeting)
      assert.is_string(tree.greeting)
    end)

    it("builds nested tree", function()
      local keys = {
        { key = "dialogue.npc.intro", type = "translate" }
      }

      local tree = Extract.buildTree(keys)
      assert.is_table(tree.dialogue)
      assert.is_table(tree.dialogue.npc)
      assert.is_string(tree.dialogue.npc.intro)
    end)

    it("creates plural structure", function()
      local keys = {
        { key = "items.count", type = "plural" }
      }

      local tree = Extract.buildTree(keys)
      assert.is_table(tree.items.count)
      assert.is_string(tree.items.count.one)
      assert.is_string(tree.items.count.other)
    end)
  end)

  describe("toYAML()", function()
    it("generates YAML for simple keys", function()
      local keys = {
        { key = "greeting", type = "translate" }
      }

      local yaml = Extract.toYAML(keys)
      assert.matches("greeting:", yaml)
    end)

    it("generates YAML for nested keys", function()
      local keys = {
        { key = "dialogue.intro", type = "translate" }
      }

      local yaml = Extract.toYAML(keys)
      assert.matches("dialogue:", yaml)
      assert.matches("intro:", yaml)
    end)

    it("generates YAML for plural keys", function()
      local keys = {
        { key = "items", type = "plural" }
      }

      local yaml = Extract.toYAML(keys)
      assert.matches("one:", yaml)
      assert.matches("other:", yaml)
    end)
  end)

  describe("toJSON()", function()
    it("generates valid JSON structure", function()
      local keys = {
        { key = "greeting", type = "translate" }
      }

      local json = Extract.toJSON(keys)
      assert.matches('"greeting":', json)
      assert.matches('{', json)
      assert.matches('}', json)
    end)

    it("generates JSON for nested keys", function()
      local keys = {
        { key = "dialogue.intro", type = "translate" }
      }

      local json = Extract.toJSON(keys)
      assert.matches('"dialogue":', json)
      assert.matches('"intro":', json)
    end)
  end)

  describe("generateTemplate()", function()
    it("generates YAML by default", function()
      local keys = {
        { key = "test", type = "translate" }
      }

      local template = Extract.generateTemplate(keys)
      assert.matches("test:", template)
    end)

    it("generates YAML when specified", function()
      local keys = {
        { key = "test", type = "translate" }
      }

      local template = Extract.generateTemplate(keys, "yaml")
      assert.matches("test:", template)
    end)

    it("generates JSON when specified", function()
      local keys = {
        { key = "test", type = "translate" }
      }

      local template = Extract.generateTemplate(keys, "json")
      assert.matches('"test":', template)
    end)
  end)

  describe("getSummary()", function()
    it("counts total keys", function()
      local keys = {
        { key = "a", type = "translate", file = "f1" },
        { key = "b", type = "plural", file = "f1" },
        { key = "c", type = "translate", file = "f2" }
      }

      local summary = Extract.getSummary(keys)
      assert.equals(3, summary.total)
    end)

    it("counts by type", function()
      local keys = {
        { key = "a", type = "translate", file = "f1" },
        { key = "b", type = "plural", file = "f1" },
        { key = "c", type = "translate", file = "f1" }
      }

      local summary = Extract.getSummary(keys)
      assert.equals(2, summary.translate)
      assert.equals(1, summary.plural)
    end)

    it("counts unique keys", function()
      local keys = {
        { key = "a", type = "translate", file = "f1" },
        { key = "a", type = "translate", file = "f2" },
        { key = "b", type = "translate", file = "f1" }
      }

      local summary = Extract.getSummary(keys)
      assert.equals(2, summary.unique)
    end)

    it("counts files", function()
      local keys = {
        { key = "a", type = "translate", file = "f1" },
        { key = "b", type = "translate", file = "f2" },
        { key = "c", type = "translate", file = "f1" }
      }

      local summary = Extract.getSummary(keys)
      assert.equals(2, summary.files)
    end)
  end)
end)
