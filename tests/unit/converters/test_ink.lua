-- Unit Tests for Ink Converter
local InkConverter = require("whisker.format.converters.ink")
local InkCompat = require("whisker.format.converters.ink_compat")

describe("Ink Converter", function()

  describe("parse", function()
    it("should parse simple Ink content", function()
      local ink_content = [[
=== Start ===
Hello, world!
-> End

=== End ===
Goodbye!
]]
      local parsed = InkConverter.parse(ink_content)

      assert.is_not_nil(parsed)
      assert.equals(2, #parsed.passages)
      assert.equals("Start", parsed.passages[1].name)
      assert.equals("End", parsed.passages[2].name)
    end)

    it("should extract VAR declarations", function()
      local ink_content = [[
VAR name = "Hero"
VAR score = 0

=== Start ===
Hello!
]]
      local parsed = InkConverter.parse(ink_content)

      assert.is_not_nil(parsed)
      assert.equals('"Hero"', parsed.variables.name)
      assert.equals("0", parsed.variables.score)
    end)

    it("should handle content before first knot", function()
      local ink_content = [[
This is the beginning.
-> Start

=== Start ===
Welcome!
]]
      local parsed = InkConverter.parse(ink_content)

      assert.is_not_nil(parsed)
      assert.is_true(#parsed.passages >= 1)
    end)
  end)

  describe("to_harlowe", function()
    it("should convert knots to passages", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result = InkConverter.to_harlowe(ink_content)

      assert.matches(":: Start", result)
      assert.matches("Hello!", result)
    end)

    it("should convert variable declarations", function()
      local ink_content = [[
VAR score = 0

=== Start ===
Your score is {score}
]]
      local result = InkConverter.to_harlowe(ink_content)

      assert.matches("%(set: %$score to 0%)", result)
      assert.matches("%$score", result)
    end)

    it("should convert choices to links", function()
      local ink_content = [[
=== Start ===
* [Go north] -> North
* [Go south] -> South
]]
      local result = InkConverter.to_harlowe(ink_content)

      assert.matches("%[%[Go north%->North%]%]", result)
      assert.matches("%[%[Go south%->South%]%]", result)
    end)

    it("should convert diverts to links", function()
      local ink_content = [[
=== Start ===
Let's go!
-> Next
]]
      local result = InkConverter.to_harlowe(ink_content)

      assert.matches("%[%[Next%]%]", result)
    end)
  end)

  describe("to_sugarcube", function()
    it("should convert knots to passages", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result = InkConverter.to_sugarcube(ink_content)

      assert.matches(":: Start", result)
      assert.matches("Hello!", result)
    end)

    it("should convert variable declarations", function()
      local ink_content = [[
VAR score = 0

=== Start ===
Your score
]]
      local result = InkConverter.to_sugarcube(ink_content)

      assert.matches("<<set %$score to 0>>", result)
    end)

    it("should convert choices to SugarCube links", function()
      local ink_content = [[
=== Start ===
* [Go north] -> North
]]
      local result = InkConverter.to_sugarcube(ink_content)

      assert.matches("%[%[Go north|North%]%]", result)
    end)
  end)

  describe("to_chapbook", function()
    it("should convert knots to passages", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result = InkConverter.to_chapbook(ink_content)

      assert.matches(":: Start", result)
      assert.matches("Hello!", result)
    end)

    it("should put variables in vars section", function()
      local ink_content = [[
VAR name = "Hero"

=== Start ===
Welcome, {name}!
]]
      local result = InkConverter.to_chapbook(ink_content)

      assert.matches("name: \"Hero\"", result)
      assert.matches("%-%-", result)
    end)
  end)

  describe("to_snowman", function()
    it("should convert knots to passages", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result = InkConverter.to_snowman(ink_content)

      assert.matches(":: Start", result)
      assert.matches("Hello!", result)
    end)

    it("should convert variable declarations", function()
      local ink_content = [[
VAR score = 0

=== Start ===
Score
]]
      local result = InkConverter.to_snowman(ink_content)

      assert.matches("<%% s%.score = 0", result)
    end)

    it("should convert interpolation to Snowman syntax", function()
      local ink_content = [[
=== Start ===
Hello {name}!
]]
      local result = InkConverter.to_snowman(ink_content)

      assert.matches("<%%=%s*s%.name%s*%%>", result)
    end)

    it("should convert links to Markdown style", function()
      local ink_content = [[
=== Start ===
* [Go there] -> Target
]]
      local result = InkConverter.to_snowman(ink_content)

      assert.matches("%[Go there%]%(Target%)", result)
    end)
  end)

  describe("with_report functions", function()
    it("should return report with to_harlowe_with_report", function()
      local ink_content = [[
VAR x = 5
=== Start ===
~ x = 10
Hello!
-> End
]]
      local result, report = InkConverter.to_harlowe_with_report(ink_content)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("ink", report.source_format)
      assert.equals("harlowe", report.target_format)
    end)

    it("should return report with to_sugarcube_with_report", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result, report = InkConverter.to_sugarcube_with_report(ink_content)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("ink", report.source_format)
      assert.equals("sugarcube", report.target_format)
    end)

    it("should return report with to_chapbook_with_report", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result, report = InkConverter.to_chapbook_with_report(ink_content)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("ink", report.source_format)
      assert.equals("chapbook", report.target_format)
    end)

    it("should return report with to_snowman_with_report", function()
      local ink_content = [[
=== Start ===
Hello!
]]
      local result, report = InkConverter.to_snowman_with_report(ink_content)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("ink", report.source_format)
      assert.equals("snowman", report.target_format)
    end)
  end)

end)

describe("Ink Compatibility", function()

  describe("is_ink_feature_supported", function()
    it("should return true for supported features", function()
      local supported, notes = InkCompat.is_ink_feature_supported("knot", "harlowe")
      assert.is_true(supported)
      assert.is_not_nil(notes)
    end)

    it("should return false for incompatible features", function()
      local supported, notes = InkCompat.is_ink_feature_supported("thread", "harlowe")
      assert.is_false(supported)
      assert.matches("incompatible", notes)
    end)
  end)

  describe("is_twine_feature_supported", function()
    it("should return true for supported features", function()
      local supported, notes = InkCompat.is_twine_feature_supported("passage", "harlowe")
      assert.is_true(supported)
      assert.is_not_nil(notes)
    end)

    it("should return false for incompatible features", function()
      local supported, notes = InkCompat.is_twine_feature_supported("enchant", "harlowe")
      assert.is_false(supported)
      assert.matches("incompatible", notes)
    end)
  end)

  describe("compatibility tables", function()
    it("should have INK_TO_TWINE_SUPPORTED", function()
      local supported = InkCompat.INK_TO_TWINE_SUPPORTED
      assert.is_table(supported)
      assert.is_true(#supported > 0)
    end)

    it("should have INK_TO_TWINE_APPROXIMATED", function()
      local approximated = InkCompat.INK_TO_TWINE_APPROXIMATED
      assert.is_table(approximated)
      assert.is_true(#approximated > 0)
    end)

    it("should have INK_TO_TWINE_INCOMPATIBLE", function()
      local incompatible = InkCompat.INK_TO_TWINE_INCOMPATIBLE
      assert.is_table(incompatible)
      assert.is_true(#incompatible > 0)
    end)
  end)

end)
