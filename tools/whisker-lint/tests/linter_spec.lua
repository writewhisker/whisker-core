-- Tests for whisker-lint

package.path = "./tools/whisker-lint/?.lua;./tools/whisker-lint/lib/?.lua;" .. package.path

describe("whisker-lint", function()
  local linter_module

  before_each(function()
    linter_module = require("whisker-lint")
  end)

  describe("StoryParser", function()
    local parser

    before_each(function()
      parser = linter_module.StoryParser
    end)

    describe("parse_ink", function()
      it("parses passage headers", function()
        local content = [[
=== Start ===
Welcome to the story.

=== Chapter1 ===
This is chapter 1.
]]
        local ast = parser.parse(content, "ink")
        assert.is_not_nil(ast.passages["Start"])
        assert.is_not_nil(ast.passages["Chapter1"])
        assert.equals(1, ast.passages["Start"].line)
        assert.equals(4, ast.passages["Chapter1"].line)
      end)

      it("parses diverts", function()
        local content = [[
=== Start ===
Welcome!
-> Chapter1

=== Chapter1 ===
The end.
]]
        local ast = parser.parse(content, "ink")
        assert.equals(1, #ast.passages["Start"].targets)
        assert.equals("Chapter1", ast.passages["Start"].targets[1].name)
      end)

      it("parses choices with targets", function()
        local content = [[
=== Start ===
What do you do?
* [Go left] -> Left
* [Go right] -> Right

=== Left ===
You went left.

=== Right ===
You went right.
]]
        local ast = parser.parse(content, "ink")
        assert.equals(2, #ast.passages["Start"].targets)
      end)

      it("parses variable assignments", function()
        local content = [[
=== Start ===
~ health = 100
~ name = "Player"
Your health is {health}.
]]
        local ast = parser.parse(content, "ink")
        assert.is_not_nil(ast.variables["health"])
        assert.is_not_nil(ast.variables["name"])
        assert.equals(1, #ast.variables["health"].assignments)
        assert.equals(1, #ast.variables["health"].reads)
      end)
    end)

    describe("parse_twee", function()
      it("parses passage headers", function()
        local content = [[
:: Start
Welcome to the story.

:: Chapter1
This is chapter 1.
]]
        local ast = parser.parse(content, "twee")
        assert.is_not_nil(ast.passages["Start"])
        assert.is_not_nil(ast.passages["Chapter1"])
      end)

      it("parses links", function()
        local content = [=[
:: Start
Welcome!
[[Go to Chapter 1|Chapter1]]
[[Chapter2]]

:: Chapter1
Chapter 1.

:: Chapter2
Chapter 2.
]=]
        local ast = parser.parse(content, "twee")
        assert.equals(2, #ast.passages["Start"].targets)
        assert.equals("Chapter1", ast.passages["Start"].targets[1].name)
        assert.equals("Chapter2", ast.passages["Start"].targets[2].name)
      end)
    end)

    describe("parse_wscript", function()
      it("parses passage declarations", function()
        local content = [[
passage "Start" {
  text "Welcome!"
  -> Chapter1
}

passage "Chapter1" {
  text "The end."
}
]]
        local ast = parser.parse(content, "wscript")
        assert.is_not_nil(ast.passages["Start"])
        assert.is_not_nil(ast.passages["Chapter1"])
      end)
    end)
  end)

  describe("Rules", function()
    local Rules, StoryParser

    before_each(function()
      Rules = linter_module.Rules
      StoryParser = linter_module.StoryParser
    end)

    describe("missing-start", function()
      it("reports when no Start passage exists", function()
        local content = [[
=== Chapter1 ===
Some content.

=== Chapter2 ===
More content.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["missing-start"].check(ast, {file = "test.ink"})
        assert.equals(1, #issues)
        assert.equals("missing-start", issues[1].rule)
      end)

      it("does not report when Start passage exists", function()
        local content = [[
=== Start ===
Welcome!

=== Chapter1 ===
Some content.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["missing-start"].check(ast, {file = "test.ink"})
        assert.equals(0, #issues)
      end)
    end)

    describe("unreachable-passage", function()
      it("reports unreachable passages", function()
        local content = [[
=== Start ===
Welcome!
-> Chapter1

=== Chapter1 ===
The end.

=== Orphan ===
This is never visited.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["unreachable-passage"].check(ast, {file = "test.ink"})
        assert.equals(1, #issues)
        assert.equals("unreachable-passage", issues[1].rule)
        assert.truthy(issues[1].message:match("Orphan"))
      end)

      it("does not report reachable passages", function()
        local content = [[
=== Start ===
Welcome!
* [Go to A] -> PassageA
* [Go to B] -> PassageB

=== PassageA ===
You chose A.

=== PassageB ===
You chose B.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["unreachable-passage"].check(ast, {file = "test.ink"})
        assert.equals(0, #issues)
      end)
    end)

    describe("undefined-reference", function()
      it("reports references to undefined passages", function()
        local content = [[
=== Start ===
Welcome!
-> NonExistent
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["undefined-reference"].check(ast, {file = "test.ink"})
        assert.equals(1, #issues)
        assert.equals("undefined-reference", issues[1].rule)
        assert.truthy(issues[1].message:match("NonExistent"))
      end)

      it("does not report valid references", function()
        local content = [[
=== Start ===
Welcome!
-> Chapter1

=== Chapter1 ===
The end.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["undefined-reference"].check(ast, {file = "test.ink"})
        assert.equals(0, #issues)
      end)
    end)

    describe("unused-variable", function()
      it("reports variables that are set but never read", function()
        local content = [[
=== Start ===
~ unused_var = 100
Hello world!
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["unused-variable"].check(ast, {file = "test.ink"})
        assert.equals(1, #issues)
        assert.equals("unused-variable", issues[1].rule)
        assert.truthy(issues[1].message:match("unused_var"))
      end)

      it("does not report variables that are read", function()
        local content = [[
=== Start ===
~ health = 100
Your health is {health}.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["unused-variable"].check(ast, {file = "test.ink"})
        assert.equals(0, #issues)
      end)
    end)

    describe("empty-passage", function()
      it("reports passages with no content", function()
        local content = [[
=== Start ===
Welcome!
-> Empty

=== Empty ===

=== Chapter1 ===
Content here.
]]
        local ast = StoryParser.parse(content, "ink")
        local issues = Rules["empty-passage"].check(ast, {file = "test.ink"})
        assert.equals(1, #issues)
        assert.equals("empty-passage", issues[1].rule)
      end)
    end)
  end)

  describe("ConfigLoader", function()
    local ConfigLoader

    before_each(function()
      ConfigLoader = linter_module.ConfigLoader
    end)

    it("returns default config when no file exists", function()
      local config = ConfigLoader.load("nonexistent.json")
      assert.is_not_nil(config.rules)
      assert.equals("warn", config.rules["unreachable-passage"])
      assert.equals("error", config.rules["undefined-reference"])
    end)
  end)

  describe("Reporters", function()
    local Reporters

    before_each(function()
      Reporters = linter_module.Reporters
    end)

    it("has text reporter", function()
      assert.is_function(Reporters.text)
    end)

    it("has json reporter", function()
      assert.is_function(Reporters.json)
    end)
  end)

  describe("Linter", function()
    local Linter

    before_each(function()
      Linter = linter_module.Linter
    end)

    it("can be instantiated", function()
      local linter = Linter.new()
      assert.is_not_nil(linter)
      assert.is_not_nil(linter.config)
      assert.is_not_nil(linter.rules)
    end)

    it("lints content and returns issues", function()
      local linter = Linter.new()
      -- Create a test file
      local test_file = "/tmp/test_story.ink"
      local f = io.open(test_file, "w")
      f:write([[
=== Start ===
Welcome!
-> NonExistent
]])
      f:close()

      local issues = linter:lint_file(test_file)
      assert.is_table(issues)
      assert.is_true(#issues > 0)

      os.remove(test_file)
    end)
  end)
end)
