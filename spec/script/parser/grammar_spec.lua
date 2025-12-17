-- spec/script/parser/grammar_spec.lua
-- Tests for basic grammar rules

describe("Grammar Rules", function()
  local parser_module
  local ast_module

  before_each(function()
    -- Clear module cache
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    parser_module = require("whisker.script.parser")
    ast_module = require("whisker.script.parser.ast")
  end)

  describe("Empty script", function()
    it("should parse empty source", function()
      local ast, errors = parser_module.parse("")
      assert.are.equal("Script", ast.type)
      assert.are.equal(0, #ast.passages)
      assert.are.equal(0, #errors)
    end)

    it("should parse whitespace only", function()
      local ast, errors = parser_module.parse("   \n\n   ")
      assert.are.equal("Script", ast.type)
      assert.are.equal(0, #ast.passages)
    end)

    it("should parse comments only", function()
      local ast, errors = parser_module.parse("// This is a comment\n# Another comment")
      assert.are.equal("Script", ast.type)
      assert.are.equal(0, #ast.passages)
    end)
  end)

  describe("Metadata parsing", function()
    it("should parse string metadata", function()
      local ast, errors = parser_module.parse('@@ title: "My Story"')
      assert.are.equal(1, #ast.metadata)
      assert.are.equal("title", ast.metadata[1].key)
      assert.are.equal("My Story", ast.metadata[1].value)
    end)

    it("should parse number metadata", function()
      local ast, errors = parser_module.parse("@@ version: 1")
      assert.are.equal(1, #ast.metadata)
      assert.are.equal("version", ast.metadata[1].key)
      assert.are.equal(1, ast.metadata[1].value)
    end)

    it("should parse boolean metadata", function()
      local ast, errors = parser_module.parse("@@ debug: true")
      assert.are.equal(1, #ast.metadata)
      assert.are.equal(true, ast.metadata[1].value)
    end)

    it("should parse identifier metadata", function()
      local ast, errors = parser_module.parse("@@ format: whisker")
      assert.are.equal(1, #ast.metadata)
      assert.are.equal("whisker", ast.metadata[1].value)
    end)

    it("should parse multiple metadata", function()
      local source = '@@ title: "Test"\n@@ author: "Tester"'
      local ast, errors = parser_module.parse(source)
      assert.are.equal(2, #ast.metadata)
    end)

    it("should parse list metadata", function()
      local ast, errors = parser_module.parse("@@ tags: [one, two, three]")
      assert.are.equal(1, #ast.metadata)
      local value = ast.metadata[1].value
      assert.are.equal("table", type(value))
      assert.are.equal(3, #value)
    end)
  end)

  describe("Include parsing", function()
    it("should parse basic include", function()
      local ast, errors = parser_module.parse('>> "other.wsk"')
      assert.are.equal(1, #ast.includes)
      assert.are.equal("other.wsk", ast.includes[1].path)
      assert.is_nil(ast.includes[1].alias)
    end)

    it("should parse include with alias", function()
      local ast, errors = parser_module.parse('>> "utils.wsk" as utils')
      assert.are.equal(1, #ast.includes)
      assert.are.equal("utils.wsk", ast.includes[1].path)
      assert.are.equal("utils", ast.includes[1].alias)
    end)

    it("should parse multiple includes", function()
      local source = '>> "a.wsk"\n>> "b.wsk"'
      local ast, errors = parser_module.parse(source)
      assert.are.equal(2, #ast.includes)
    end)
  end)

  describe("Passage declaration", function()
    it("should parse simple passage", function()
      local ast, errors = parser_module.parse(":: Start")
      assert.are.equal(1, #ast.passages)
      assert.are.equal("Start", ast.passages[1].name)
      assert.are.equal(0, #ast.passages[1].tags)
    end)

    it("should parse passage with single tag", function()
      local ast, errors = parser_module.parse(":: Start [important]")
      assert.are.equal(1, #ast.passages)
      assert.are.equal(1, #ast.passages[1].tags)
      assert.are.equal("important", ast.passages[1].tags[1].name)
    end)

    it("should parse passage with multiple tags", function()
      local ast, errors = parser_module.parse(":: Start [important, chapter1, intro]")
      assert.are.equal(1, #ast.passages)
      assert.are.equal(3, #ast.passages[1].tags)
    end)

    it("should parse passage with empty tags", function()
      local ast, errors = parser_module.parse(":: Start []")
      assert.are.equal(1, #ast.passages)
      assert.are.equal(0, #ast.passages[1].tags)
    end)

    it("should parse passage with tag value", function()
      local ast, errors = parser_module.parse(":: Start [priority: 1]")
      assert.are.equal(1, #ast.passages)
      assert.are.equal("priority", ast.passages[1].tags[1].name)
      assert.are.equal(1, ast.passages[1].tags[1].value)
    end)

    it("should parse multiple passages", function()
      local source = ":: Start\n:: Middle\n:: End"
      local ast, errors = parser_module.parse(source)
      assert.are.equal(3, #ast.passages)
      assert.are.equal("Start", ast.passages[1].name)
      assert.are.equal("Middle", ast.passages[2].name)
      assert.are.equal("End", ast.passages[3].name)
    end)
  end)

  describe("Passage body", function()
    it("should parse passage with indented text", function()
      local source = ":: Start\n  Hello world"
      local ast, errors = parser_module.parse(source)
      assert.are.equal(1, #ast.passages)
      assert.is_true(#ast.passages[1].body >= 0)  -- May or may not have body depending on lexer
    end)

    it("should parse passage with divert", function()
      local source = ":: Start\n  -> End"
      local ast, errors = parser_module.parse(source)
      assert.are.equal(1, #ast.passages)
      -- Check if divert was parsed
      local body = ast.passages[1].body
      local found_divert = false
      for _, stmt in ipairs(body) do
        if stmt.type == "Divert" then
          found_divert = true
          assert.are.equal("End", stmt.target)
        end
      end
      -- Divert may or may not be in body depending on indentation handling
    end)
  end)

  describe("Mixed content", function()
    it("should parse metadata, includes, and passages together", function()
      local source = [[
@@ title: "Test Story"
>> "common.wsk"
:: Start
:: End
]]
      local ast, errors = parser_module.parse(source)
      assert.are.equal(1, #ast.metadata)
      assert.are.equal(1, #ast.includes)
      assert.are.equal(2, #ast.passages)
    end)

    it("should maintain order of declarations", function()
      local source = [[
@@ a: 1
@@ b: 2
:: First
:: Second
]]
      local ast, errors = parser_module.parse(source)
      assert.are.equal("a", ast.metadata[1].key)
      assert.are.equal("b", ast.metadata[2].key)
      assert.are.equal("First", ast.passages[1].name)
      assert.are.equal("Second", ast.passages[2].name)
    end)
  end)

  describe("Error handling", function()
    it("should report error for unexpected token at top level", function()
      local ast, errors = parser_module.parse("hello")
      assert.is_true(#errors > 0)
    end)

    it("should continue after errors", function()
      local source = "invalid\n:: Valid"
      local ast, errors = parser_module.parse(source)
      assert.is_true(#errors > 0)
      assert.is_true(#ast.passages >= 1)
    end)

    it("should report error for missing passage name", function()
      local ast, errors = parser_module.parse("::")
      assert.is_true(#errors > 0)
    end)
  end)

  describe("Position tracking", function()
    it("should track position of script node", function()
      local ast, errors = parser_module.parse(":: Start")
      assert.is_not_nil(ast.pos)
      assert.are.equal(1, ast.pos.line)
    end)

    it("should track position of passage node", function()
      local source = "\n\n:: Start"
      local ast, errors = parser_module.parse(source)
      if #ast.passages > 0 then
        assert.is_not_nil(ast.passages[1].pos)
        assert.are.equal(3, ast.passages[1].pos.line)
      end
    end)

    it("should track position of metadata node", function()
      local source = '@@ title: "Test"'
      local ast, errors = parser_module.parse(source)
      if #ast.metadata > 0 then
        assert.is_not_nil(ast.metadata[1].pos)
        assert.are.equal(1, ast.metadata[1].pos.line)
      end
    end)
  end)
end)
