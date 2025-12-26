-- Tests for All Converter Report Integration
-- Tests report generation consistency across all converters

local harlowe_parser = require("whisker.format.parsers.harlowe")
local chapbook_parser = require("whisker.format.parsers.chapbook")
local sugarcube_parser = require("whisker.format.parsers.sugarcube")
local snowman_parser = require("whisker.format.parsers.snowman")

local harlowe_converter = require("whisker.format.converters.harlowe")
local chapbook_converter = require("whisker.format.converters.chapbook")
local sugarcube_converter = require("whisker.format.converters.sugarcube")
local snowman_converter = require("whisker.format.converters.snowman")

local Report = require("whisker.format.converters.report")

describe("All Converters Report Integration", function()

  describe("Chapbook Converter Reports", function()
    it("to_harlowe_with_report should return report", function()
      local story = [=[
:: Start
name: "Hero"
--
Welcome, {name}!
]=]
      local parsed = chapbook_parser.parse(story)
      local result, report = chapbook_converter.to_harlowe_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("chapbook", report.source_format)
      assert.equals("harlowe", report.target_format)
    end)

    it("to_sugarcube_with_report should return report", function()
      local story = [=[
:: Start
name: "Hero"
--
Welcome, {name}!
]=]
      local parsed = chapbook_parser.parse(story)
      local result, report = chapbook_converter.to_sugarcube_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("chapbook", report.source_format)
      assert.equals("sugarcube", report.target_format)
    end)

    it("to_snowman_with_report should return report", function()
      local story = [=[
:: Start
name: "Hero"
--
Welcome, {name}!
]=]
      local parsed = chapbook_parser.parse(story)
      local result, report = chapbook_converter.to_snowman_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("chapbook", report.source_format)
      assert.equals("snowman", report.target_format)
    end)

    it("should track approximations when converting to Harlowe", function()
      local story = [=[
:: Timer
[after 5s]
The timer has finished!
[continue]
]=]
      local parsed = chapbook_parser.parse(story)
      local _, report = chapbook_converter.to_harlowe_with_report(parsed)

      local approx = report:get_details(Report.ENTRY_TYPES.APPROXIMATED)
      assert.is_true(#approx >= 1)
    end)
  end)

  describe("SugarCube Converter Reports", function()
    it("to_harlowe_with_report should return report", function()
      local story = [=[
:: Start
<<set $name to "Hero">>
Welcome, $name!
]=]
      local parsed = sugarcube_parser.parse(story)
      local result, report = sugarcube_converter.to_harlowe_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("sugarcube", report.source_format)
      assert.equals("harlowe", report.target_format)
    end)

    it("to_chapbook_with_report should return report", function()
      local story = [=[
:: Start
<<set $name to "Hero">>
Welcome, $name!
]=]
      local parsed = sugarcube_parser.parse(story)
      local result, report = sugarcube_converter.to_chapbook_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("sugarcube", report.source_format)
      assert.equals("chapbook", report.target_format)
    end)

    it("to_snowman_with_report should return report", function()
      local story = [=[
:: Start
<<set $name to "Hero">>
Welcome, $name!
]=]
      local parsed = sugarcube_parser.parse(story)
      local result, report = sugarcube_converter.to_snowman_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("sugarcube", report.source_format)
      assert.equals("snowman", report.target_format)
    end)

    it("should track lost features when converting to Harlowe", function()
      local story = [=[
:: Widgets
<<widget "myWidget">>
Custom widget content
<</widget>>
]=]
      local parsed = sugarcube_parser.parse(story)
      local _, report = sugarcube_converter.to_harlowe_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      assert.is_true(#lost >= 1)
    end)
  end)

  describe("Snowman Converter Reports", function()
    it("to_harlowe_with_report should return report", function()
      local story = [=[
:: Start
<% s.name = "Hero"; %>
Welcome, <%= s.name %>!
]=]
      local parsed = snowman_parser.parse(story)
      local result, report = snowman_converter.to_harlowe_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("snowman", report.source_format)
      assert.equals("harlowe", report.target_format)
    end)

    it("to_sugarcube_with_report should return report", function()
      local story = [=[
:: Start
<% s.name = "Hero"; %>
Welcome, <%= s.name %>!
]=]
      local parsed = snowman_parser.parse(story)
      local result, report = snowman_converter.to_sugarcube_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("snowman", report.source_format)
      assert.equals("sugarcube", report.target_format)
    end)

    it("to_chapbook_with_report should return report", function()
      local story = [=[
:: Start
<% s.name = "Hero"; %>
Welcome, <%= s.name %>!
]=]
      local parsed = snowman_parser.parse(story)
      local result, report = snowman_converter.to_chapbook_with_report(parsed)

      assert.is_string(result)
      assert.is_not_nil(report)
      assert.equals("snowman", report.source_format)
      assert.equals("chapbook", report.target_format)
    end)

    it("should track lost DOM access when converting to Harlowe", function()
      local story = [=[
:: Interactive
<% document.getElementById('foo').style.color = 'red'; %>
]=]
      local parsed = snowman_parser.parse(story)
      local _, report = snowman_converter.to_harlowe_with_report(parsed)

      local lost = report:get_details(Report.ENTRY_TYPES.LOST)
      assert.is_true(#lost >= 1)
    end)
  end)

  describe("Report Consistency Across Converters", function()
    it("all converters should return reports with source and target formats", function()
      local harlowe_story = [=[
:: Start
(set: $x to 5)
]=]
      local chapbook_story = [=[
:: Start
x: 5
--
Content
]=]
      local sugarcube_story = [=[
:: Start
<<set $x to 5>>
]=]
      local snowman_story = [=[
:: Start
<% s.x = 5; %>
]=]

      -- Parse all
      local h_parsed = harlowe_parser.parse(harlowe_story)
      local c_parsed = chapbook_parser.parse(chapbook_story)
      local s_parsed = sugarcube_parser.parse(sugarcube_story)
      local sn_parsed = snowman_parser.parse(snowman_story)

      -- Convert with reports
      local _, h_to_c = harlowe_converter.to_chapbook_with_report(h_parsed)
      local _, c_to_h = chapbook_converter.to_harlowe_with_report(c_parsed)
      local _, s_to_h = sugarcube_converter.to_harlowe_with_report(s_parsed)
      local _, sn_to_h = snowman_converter.to_harlowe_with_report(sn_parsed)

      -- Verify all have correct format info
      assert.equals("harlowe", h_to_c.source_format)
      assert.equals("chapbook", h_to_c.target_format)

      assert.equals("chapbook", c_to_h.source_format)
      assert.equals("harlowe", c_to_h.target_format)

      assert.equals("sugarcube", s_to_h.source_format)
      assert.equals("harlowe", s_to_h.target_format)

      assert.equals("snowman", sn_to_h.source_format)
      assert.equals("harlowe", sn_to_h.target_format)
    end)

    it("all reports should have get_summary method", function()
      local story = [=[
:: Start
(set: $x to 5)
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = harlowe_converter.to_chapbook_with_report(parsed)

      local summary = report:get_summary()
      assert.is_table(summary)
      assert.is_number(summary.converted)
      assert.is_number(summary.approximated)
      assert.is_number(summary.lost)
    end)

    it("all reports should have get_quality_score method", function()
      local story = [=[
:: Start
(set: $x to 5)
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = harlowe_converter.to_sugarcube_with_report(parsed)

      local score = report:get_quality_score()
      assert.is_number(score)
      assert.is_true(score >= 0 and score <= 100)
    end)

    it("all reports should support JSON serialization", function()
      local story = [=[
:: Start
(set: $x to 5)
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = harlowe_converter.to_snowman_with_report(parsed)

      local json_str = report:to_json()
      assert.is_string(json_str)
      assert.matches('"source_format"', json_str)
    end)
  end)

  describe("Quality Score Comparison", function()
    it("conversions with no losses should have 100% quality", function()
      local story = [=[
:: Start
(set: $x to 5)
(if: $x > 0)[Positive]
[[Next->End]]

:: End
Done
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = harlowe_converter.to_sugarcube_with_report(parsed)

      -- SugarCube supports all basic Harlowe features
      assert.equals(100, report:get_quality_score())
    end)

    it("conversions with losses should have lower quality", function()
      local story = [=[
:: Start
(enchant: ?hook, (text-style: "bold"))
(live: 1s)[Timer]
]=]
      local parsed = harlowe_parser.parse(story)
      local _, report = harlowe_converter.to_chapbook_with_report(parsed)

      -- Should have lost features
      assert.is_true(report:get_quality_score() < 100)
    end)
  end)

end)
