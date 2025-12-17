-- tests/integration/script/roundtrip_spec.lua
-- Integration tests for Whisker Script roundtrip (import -> export -> import)

describe("Whisker Script Roundtrip", function()
  local script_module

  before_each(function()
    -- Clear cached modules for clean state
    package.loaded["whisker.script"] = nil
    package.loaded["whisker.script.format"] = nil
    package.loaded["whisker.script.writer"] = nil

    script_module = require("whisker.script")
  end)

  describe("simple story roundtrip", function()
    it("should preserve passage names", function()
      local source = [[
:: Start
Welcome to the story!

:: End
The end.
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)
      local reimported = script_module.import(exported)

      -- Check passages exist
      local start_passage = reimported:get_passage("Start")
      local end_passage = reimported:get_passage("End")

      assert.is_not_nil(start_passage)
      assert.is_not_nil(end_passage)
    end)

    it("should preserve passage content", function()
      local source = [[
:: Start
This is the start of our adventure.
Multiple lines of text.

:: End
The end.
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)
      local reimported = script_module.import(exported)

      local passage = reimported:get_passage("Start")
      assert.is_not_nil(passage)
      assert.is_truthy(passage.content:find("adventure"))
    end)
  end)

  describe("metadata roundtrip", function()
    it("should preserve title", function()
      local source = [[
@@ title: My Great Adventure

:: Start
Hello!
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)

      assert.is_truthy(exported:find("@@ title: My Great Adventure"))
    end)

    it("should preserve author", function()
      local source = [[
@@ author: Jane Writer

:: Start
Hello!
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)

      assert.is_truthy(exported:find("@@ author: Jane Writer"))
    end)
  end)

  describe("choices roundtrip", function()
    it("should preserve choice text and targets", function()
      local source = [[
:: Start
Make a choice:

+ [Go north] -> North
+ [Go south] -> South

:: North
You went north.

:: South
You went south.
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)

      assert.is_truthy(exported:find("%+ %[Go north%] %-> North"))
      assert.is_truthy(exported:find("%+ %[Go south%] %-> South"))
    end)
  end)

  describe("tags roundtrip", function()
    it("should preserve passage tags", function()
      local source = [[
:: Start [intro, important]
This is tagged content.

:: End [outro]
Done.
]]
      local story = script_module.import(source)
      local exported = script_module.export(story)

      assert.is_truthy(exported:find(":: Start %["))
      -- Tags should be present (order may vary)
      assert.is_truthy(exported:find("intro"))
      assert.is_truthy(exported:find("important"))
    end)
  end)

  describe("fixture file roundtrip", function()
    local fixtures_path = "tests/fixtures/script/generator/"

    it("should roundtrip simple_passage.wsk", function()
      local file = io.open(fixtures_path .. "simple_passage.wsk", "r")
      if file then
        local source = file:read("*a")
        file:close()

        local story = script_module.import(source)
        local exported = script_module.export(story)
        local reimported = script_module.import(exported)

        -- Should have same number of passages
        local original_passages = story:get_all_passages()
        local reimported_passages = reimported:get_all_passages()

        assert.are.equal(#original_passages, #reimported_passages)
      end
    end)

    it("should roundtrip with_choices.wsk", function()
      local file = io.open(fixtures_path .. "with_choices.wsk", "r")
      if file then
        local source = file:read("*a")
        file:close()

        local story = script_module.import(source)
        local exported = script_module.export(story)

        -- Should preserve choice structure
        assert.is_truthy(exported:find("%+ %["))
        assert.is_truthy(exported:find("%->"))
      end
    end)
  end)

  describe("semantic preservation", function()
    it("should produce equivalent AST after roundtrip", function()
      local source = [[
:: Start
Welcome!

+ [Continue] -> End

:: End
Goodbye!
]]
      -- First pass
      local result1 = script_module.parse_only(source)

      -- Export and re-import
      local story = script_module.import(source)
      local exported = script_module.export(story)
      local result2 = script_module.parse_only(exported)

      -- Both should parse successfully
      assert.are.equal(0, #result1.diagnostics)
      assert.are.equal(0, #result2.diagnostics)

      -- Both should have same passage count
      local passage_count1 = 0
      local passage_count2 = 0

      if result1.ast and result1.ast.passages then
        passage_count1 = #result1.ast.passages
      end
      if result2.ast and result2.ast.passages then
        passage_count2 = #result2.ast.passages
      end

      assert.are.equal(passage_count1, passage_count2)
    end)
  end)

  describe("module-level convenience functions", function()
    it("should support can_import()", function()
      assert.is_true(script_module.can_import(":: Start\nHello"))
      assert.is_false(script_module.can_import("Just plain text"))
    end)

    it("should support can_export()", function()
      local story = {
        passages = { { name = "Start", content = "Hello" } }
      }
      assert.is_true(script_module.can_export(story))
      assert.is_false(script_module.can_export("not a story"))
    end)

    it("should support compile()", function()
      local result = script_module.compile(":: Start\nHello!")
      assert.is_not_nil(result)
      assert.is_not_nil(result.story)
      assert.is_table(result.diagnostics)
    end)

    it("should support validate()", function()
      local diagnostics = script_module.validate(":: Start\nHello!")
      assert.is_table(diagnostics)
    end)

    it("should support get_tokens()", function()
      local tokens = script_module.get_tokens(":: Start")
      assert.is_not_nil(tokens)
    end)
  end)
end)
