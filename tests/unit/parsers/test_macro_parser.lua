-- Unit Tests for Macro Parser
local macro_parser = require("whisker.format.parsers.macro_parser")

describe("Macro Parser", function()
  describe("extract_harlowe_macros", function()
    it("should extract simple macros", function()
      local content = "(set: $x to 1)(print: $x)"
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.equals(2, #macros)
      assert.equals("set", macros[1].name)
      assert.equals("print", macros[2].name)
    end)

    it("should extract macro arguments", function()
      local content = '(set: $name to "Hero")'
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.equals(1, #macros)
      assert.equals("set", macros[1].name)
      -- Harlowe uses 'to' keyword, so args are not comma-separated
      assert.equals(1, #macros[1].args)
      assert.matches("$name", macros[1].args[1])
    end)

    it("should extract comma-separated arguments", function()
      local content = "(a: 1, 2, 3)"
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.equals(1, #macros)
      assert.equals("a", macros[1].name)
      assert.equals(3, #macros[1].args)
      assert.equals("1", macros[1].args[1])
    end)

    it("should handle nested macros", function()
      local content = "(set: $arr to (a: 1, 2, 3))"
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.is_true(#macros >= 1)
    end)

    it("should extract macro without args", function()
      local content = "(undo)"
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.equals(1, #macros)
      assert.equals("undo", macros[1].name)
      assert.equals(0, #macros[1].args)
    end)

    it("should extract if macro", function()
      local content = "(if: $x > 5)"
      local macros = macro_parser.extract_harlowe_macros(content)

      assert.equals(1, #macros)
      assert.equals("if", macros[1].name)
    end)
  end)

  describe("extract_sugarcube_macros", function()
    it("should extract simple macros", function()
      local content = "<<set $x to 1>><<print $x>>"
      local macros = macro_parser.extract_sugarcube_macros(content)

      assert.equals(2, #macros)
      assert.equals("set", macros[1].name)
      assert.equals("print", macros[2].name)
    end)

    it("should extract closing tags", function()
      local content = "<<if $x>>Hello<</if>>"
      local macros = macro_parser.extract_sugarcube_macros(content)

      assert.equals(2, #macros)
      assert.equals("if", macros[1].name)
      assert.equals("/if", macros[2].name)
      assert.is_true(macros[2].is_close)
    end)

    it("should extract macro arguments", function()
      local content = '<<set $name to "Bob">>'
      local macros = macro_parser.extract_sugarcube_macros(content)

      assert.equals(1, #macros)
      assert.is_true(#macros[1].args >= 1)
    end)
  end)

  describe("parse_args", function()
    it("should parse simple arguments", function()
      local args = macro_parser.parse_args("$x, 1, 'hello'")
      assert.equals(3, #args)
      assert.equals("$x", args[1])
      assert.equals("1", args[2])
      assert.equals("'hello'", args[3])
    end)

    it("should handle nested parentheses", function()
      local args = macro_parser.parse_args("(a: 1, 2), 3")
      assert.equals(2, #args)
      assert.equals("(a: 1, 2)", args[1])
      assert.equals("3", args[2])
    end)

    it("should handle strings with commas", function()
      local args = macro_parser.parse_args('"hello, world", 2')
      assert.equals(2, #args)
      assert.equals('"hello, world"', args[1])
    end)

    it("should handle empty args", function()
      local args = macro_parser.parse_args("")
      assert.equals(0, #args)
    end)
  end)

  describe("validate_harlowe_macro", function()
    it("should validate correct usage", function()
      local macro = {name = "set", args = {"$x", "1"}}
      local valid, err = macro_parser.validate_harlowe_macro(macro)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should detect missing arguments", function()
      local macro = {name = "set", args = {"$x"}}
      local valid, err = macro_parser.validate_harlowe_macro(macro)
      assert.is_false(valid)
      assert.matches("requires", err)
    end)

    it("should allow unknown macros", function()
      local macro = {name = "custom-macro", args = {"arg1"}}
      local valid, err = macro_parser.validate_harlowe_macro(macro)
      assert.is_true(valid)
    end)

    it("should validate goto macro", function()
      local macro = {name = "goto", args = {'"Next"'}}
      local valid, err = macro_parser.validate_harlowe_macro(macro)
      assert.is_true(valid)
    end)
  end)

  describe("validate_sugarcube_macro", function()
    it("should validate correct usage", function()
      local macro = {name = "set", args = {"$x to 1"}}
      local valid, err = macro_parser.validate_sugarcube_macro(macro)
      assert.is_true(valid)
    end)

    it("should skip closing tags", function()
      local macro = {name = "/if", args = {}, is_close = true}
      local valid, err = macro_parser.validate_sugarcube_macro(macro)
      assert.is_true(valid)
    end)
  end)

  describe("analyze_harlowe", function()
    it("should provide complete analysis", function()
      local content = [[
(set: $gold to 100)
(if: $gold > 50)[Rich!]
(print: $gold)
]]
      local results = macro_parser.analyze_harlowe(content)

      assert.equals(3, results.stats.total)
      assert.is_not_nil(results.stats.by_category.data)
      assert.is_not_nil(results.stats.by_category.control)
      assert.is_not_nil(results.stats.by_category.output)
    end)

    it("should detect errors", function()
      local content = "(set: $x)"
      local results = macro_parser.analyze_harlowe(content)

      assert.is_true(#results.errors > 0)
    end)

    it("should track category stats", function()
      local content = "(set: $a to 1)(set: $b to 2)(goto: 'End')"
      local results = macro_parser.analyze_harlowe(content)

      assert.equals(2, results.stats.by_category.data)
      assert.equals(1, results.stats.by_category.navigation)
    end)
  end)

  describe("analyze_sugarcube", function()
    it("should provide complete analysis", function()
      local content = [[
<<set $gold to 100>>
<<if $gold > 50>>Rich!<</if>>
<<print $gold>>
]]
      local results = macro_parser.analyze_sugarcube(content)

      assert.is_true(results.stats.total >= 3)
    end)
  end)
end)
