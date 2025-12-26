-- Tests for Harlowe Converter Report Integration
local harlowe_parser = require("whisker.format.parsers.harlowe")
local converter = require("whisker.format.converters.harlowe")
local Report = require("whisker.format.converters.report")

describe("Harlowe Converter with Report", function()

  describe("to_chapbook_with_report", function()
    it("should return both converted content and report", function()
      local story = [[
:: Start
(set: $name to "Hero")
Welcome!
]]
      local parsed = harlowe_parser.parse(story)
      local result, report = converter.to_chapbook_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("harlowe", report.source_format)
      assert.equals("chapbook", report.target_format)
    end)

    it("should track converted set macros", function()
      local story = [[
:: Start
(set: $name to "Hero")
(set: $gold to 100)
Welcome!
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local summary = report:get_summary()
      assert.is_true(summary.converted >= 2)
    end)

    it("should track converted if macros", function()
      local story = [[
:: Start
(if: $gold > 0)[You have gold]
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local details = report:get_details(Report.ENTRY_TYPES.CONVERTED)
      local has_if = false
      for _, entry in ipairs(details) do
        if entry.feature == "if" then
          has_if = true
          break
        end
      end
      assert.is_true(has_if)
    end)

    it("should track converted dropdown macros", function()
      local story = [[
:: Start
(dropdown: bind $choice, "a", "b", "c")
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local details = report:get_details(Report.ENTRY_TYPES.CONVERTED)
      local has_dropdown = false
      for _, entry in ipairs(details) do
        if entry.feature == "dropdown" then
          has_dropdown = true
          break
        end
      end
      assert.is_true(has_dropdown)
    end)

    it("should track lost enchant macros", function()
      local story = [[
:: Start
(enchant: ?link, (text-style: "bold"))
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      assert.equals(1, #lost)
      assert.equals("enchant", lost[1].feature)
    end)

    it("should track lost live macros", function()
      local story = [[
:: Timer
(live: 2s)[Time: $time]
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      local has_live = false
      for _, entry in ipairs(lost) do
        if entry.feature == "live" then
          has_live = true
          break
        end
      end
      assert.is_true(has_live)
    end)

    it("should set correct passage count", function()
      local story = [[
:: Start
First passage

:: Middle
Second passage

:: End
Third passage
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      assert.equals(3, report.passage_count)
    end)

    it("should calculate quality score based on conversions", function()
      local story = [[
:: Start
(set: $x to 5)
(enchant: ?hook, (text-style: "bold"))
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      -- Has both converted and lost features
      local score = report:get_quality_score()
      assert.is_true(score > 0 and score < 100)
    end)
  end)

  describe("to_sugarcube_with_report", function()
    it("should return both converted content and report", function()
      local story = [[
:: Start
(set: $name to "Hero")
Welcome!
]]
      local parsed = harlowe_parser.parse(story)
      local result, report = converter.to_sugarcube_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("harlowe", report.source_format)
      assert.equals("sugarcube", report.target_format)
    end)

    it("should track converted set/if/print macros", function()
      local story = [[
:: Start
(set: $name to "Hero")
(if: $gold > 0)[Rich]
(print: $name)
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      local summary = report:get_summary()
      assert.is_true(summary.converted >= 3)
    end)

    it("should track converted arrays and datamaps", function()
      local story = [[
:: Start
(set: $inv to (a: "sword", "potion"))
(set: $player to (dm: "hp", 100))
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      local details = report:get_details(Report.ENTRY_TYPES.CONVERTED)
      local has_array = false
      local has_datamap = false
      for _, entry in ipairs(details) do
        if entry.feature == "array" then has_array = true end
        if entry.feature == "datamap" then has_datamap = true end
      end
      assert.is_true(has_array)
      assert.is_true(has_datamap)
    end)

    it("should track approximated live macro", function()
      local story = [[
:: Timer
(live: 2s)[Countdown: $time]
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      local approx = report:get_details(Report.ENTRY_TYPES.APPROXIMATED)
      assert.equals(1, #approx)
      assert.equals("live", approx[1].feature)
    end)

    it("should track lost enchant macro", function()
      local story = [[
:: Styled
(enchant: ?hook, (text-style: "bold"))
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      assert.equals(1, #lost)
      assert.equals("enchant", lost[1].feature)
    end)

    it("should achieve 100% quality for basic story", function()
      local story = [=[
:: Start
(set: $x to 5)
(if: $x > 0)[Positive]
[[Next->End]]

:: End
The end!
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      assert.equals(100, report:get_quality_score())
    end)
  end)

  describe("to_snowman_with_report", function()
    it("should return both converted content and report", function()
      local story = [[
:: Start
(set: $name to "Hero")
Welcome, $name!
]]
      local parsed = harlowe_parser.parse(story)
      local result, report = converter.to_snowman_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("harlowe", report.source_format)
      assert.equals("snowman", report.target_format)
    end)

    it("should track converted set and variable references", function()
      local story = [[
:: Start
(set: $name to "Hero")
Welcome, $name! You have $gold gold.
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_snowman_with_report(parsed)

      local summary = report:get_summary()
      -- Should have set and variable conversions
      assert.is_true(summary.converted >= 1)
    end)

    it("should track approximated if conditionals", function()
      local story = [[
:: Start
(if: $x > 0)[Positive]
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_snowman_with_report(parsed)

      local approx = report:get_details(Report.ENTRY_TYPES.APPROXIMATED)
      local has_if = false
      for _, entry in ipairs(approx) do
        if entry.feature == "if" then
          has_if = true
          break
        end
      end
      assert.is_true(has_if)
    end)

    it("should track lost interactive features", function()
      local story = [[
:: Interactive
(dropdown: bind $choice, "a", "b")
(cycling-link: bind $opt, "x", "y")
(click: ?hook)[action]
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_snowman_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      assert.is_true(#lost >= 3)
    end)

    it("should report lower quality for complex stories", function()
      local story = [[
:: Start
(set: $x to 5)
(live: 1s)[Timer: $time]
(enchant: ?hook, (css: "color", "red"))
(dropdown: bind $choice, "a", "b")
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_snowman_with_report(parsed)

      -- Should have lower quality due to lost/approximated features
      local score = report:get_quality_score()
      assert.is_true(score < 100)
    end)
  end)

  describe("Backwards Compatibility", function()
    it("should still support to_chapbook_with_warnings", function()
      local story = [[
:: Start
(set: $x to 5)
(live: 1s)[Timer]
]]
      local parsed = harlowe_parser.parse(story)
      local result, warnings = converter.to_chapbook_with_warnings(parsed)

      assert.is_string(result)
      assert.is_table(warnings)
    end)

    it("to_chapbook_with_warnings should detect incompatible features", function()
      local story = [[
:: Start
(enchant: ?hook, (text-style: "bold"))
(live: 1s)[Timer]
]]
      local parsed = harlowe_parser.parse(story)
      local _, warnings = converter.to_chapbook_with_warnings(parsed)

      assert.is_true(#warnings >= 2)
    end)
  end)

  describe("Report Accuracy", function()
    it("should count multiple occurrences in same passage", function()
      local story = [[
:: Start
(set: $a to 1)
(set: $b to 2)
(set: $c to 3)
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_chapbook_with_report(parsed)

      local converted = report:get_details(Report.ENTRY_TYPES.CONVERTED)
      local set_count = 0
      for _, entry in ipairs(converted) do
        if entry.feature == "set" then
          set_count = set_count + 1
        end
      end
      assert.equals(3, set_count)
    end)

    it("should track features across multiple passages", function()
      local story = [[
:: Start
(set: $x to 1)

:: Middle
(set: $y to 2)

:: End
(set: $z to 3)
]]
      local parsed = harlowe_parser.parse(story)
      local _, report = converter.to_sugarcube_with_report(parsed)

      local by_passage = report:get_by_passage()
      assert.is_not_nil(by_passage["Start"])
      assert.is_not_nil(by_passage["Middle"])
      assert.is_not_nil(by_passage["End"])
    end)
  end)

end)
