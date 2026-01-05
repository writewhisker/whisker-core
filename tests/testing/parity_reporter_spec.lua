--- Parity Reporter Tests
-- Unit tests for the ParityReporter class
-- @module tests.testing.parity_reporter_spec

local helper = require("tests.test_helper")
local ParityReporter = require("whisker.testing.parity_reporter")

describe("ParityReporter", function()
  local function create_summary(matched, mismatched, missing_ref, missing_lua)
    matched = matched or 0
    mismatched = mismatched or 0
    missing_ref = missing_ref or 0
    missing_lua = missing_lua or 0

    local total = matched + mismatched + missing_ref + missing_lua
    local comparisons = {}

    for i = 1, matched do
      table.insert(comparisons, {
        passed = true,
        scenario_id = "match-" .. i,
        scenario_name = "Matched Test " .. i,
        lua_passed = true,
        ref_passed = true,
        difference_count = 0,
        differences = {},
      })
    end

    for i = 1, mismatched do
      table.insert(comparisons, {
        passed = false,
        scenario_id = "mismatch-" .. i,
        scenario_name = "Mismatched Test " .. i,
        lua_passed = true,
        ref_passed = false,
        difference_count = 2,
        differences = {
          { type = "mismatch", path = "passed", lua_value = true, reference = false },
          { type = "mismatch", path = "score", lua_value = 10, reference = 20 },
        },
      })
    end

    for i = 1, missing_ref do
      table.insert(comparisons, {
        passed = false,
        scenario_id = "missing-ref-" .. i,
        scenario_name = "Missing Ref " .. i,
        lua_passed = true,
        ref_passed = nil,
        difference_count = 1,
        differences = {
          { type = "missing_ref", path = "scenario", message = "No reference result" },
        },
      })
    end

    for i = 1, missing_lua do
      table.insert(comparisons, {
        passed = false,
        scenario_id = "missing-lua-" .. i,
        scenario_name = "Missing Lua " .. i,
        lua_passed = nil,
        ref_passed = true,
        difference_count = 1,
        differences = {
          { type = "missing_lua", path = "scenario", message = "No Lua result" },
        },
      })
    end

    return {
      total = total,
      matched = matched,
      mismatched = mismatched,
      missing_ref = missing_ref,
      missing_lua = missing_lua,
      parity_score = total > 0 and (matched / total * 100) or 100,
      passed = mismatched == 0 and missing_ref == 0 and missing_lua == 0,
      comparisons = comparisons,
    }
  end

  describe("new", function()
    it("should create a reporter with default options", function()
      local reporter = ParityReporter.new()
      assert.is_not_nil(reporter)
    end)

    it("should accept format option", function()
      local reporter = ParityReporter.new({ format = "json" })
      assert.equals("json", reporter._format)
    end)

    it("should accept verbose option", function()
      local reporter = ParityReporter.new({ verbose = true })
      assert.is_true(reporter._verbose)
    end)

    it("should accept colors option", function()
      local reporter = ParityReporter.new({ colors = false })
      assert.is_false(reporter._colors)
    end)
  end)

  describe("format_text", function()
    it("should include parity score", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(8, 2, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("80.0%%"))
    end)

    it("should include total count", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(5, 0, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Total Scenarios: 5"))
    end)

    it("should show PASSED for successful parity", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(5, 0, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("PARITY CHECK PASSED"))
    end)

    it("should show FAILED for failed parity", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(3, 2, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("PARITY CHECK FAILED"))
    end)

    it("should include matched count", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(7, 3, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Matched: 7"))
    end)

    it("should include mismatched count", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(7, 3, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Mismatched: 3"))
    end)
  end)

  describe("format_json", function()
    it("should produce valid JSON structure", function()
      local reporter = ParityReporter.new({ format = "json" })
      local summary = create_summary(2, 1, 0, 0)

      local output = reporter:format_json(summary)

      assert.truthy(output:find('"total"'))
      assert.truthy(output:find('"matched"'))
      assert.truthy(output:find('"mismatched"'))
      assert.truthy(output:find('"parity_score"'))
    end)

    it("should include comparisons array", function()
      local reporter = ParityReporter.new({ format = "json" })
      local summary = create_summary(1, 1, 0, 0)

      local output = reporter:format_json(summary)

      assert.truthy(output:find('"comparisons"'))
    end)
  end)

  describe("format_markdown", function()
    it("should include header", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(2, 0, 0, 0)

      local output = reporter:format_markdown(summary)

      assert.truthy(output:find("# Parity Report"))
    end)

    it("should include summary table", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(2, 0, 0, 0)

      local output = reporter:format_markdown(summary)

      assert.truthy(output:find("| Metric | Value |"))
      assert.truthy(output:find("Parity Score"))
    end)

    it("should show checkmark for passed", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(5, 0, 0, 0)

      local output = reporter:format_markdown(summary)

      assert.truthy(output:find(":white_check_mark:"))
    end)

    it("should show X for failed", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(3, 2, 0, 0)

      local output = reporter:format_markdown(summary)

      assert.truthy(output:find(":x:"))
    end)

    it("should include mismatched scenarios section", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(0, 1, 0, 0)

      local output = reporter:format_markdown(summary)

      assert.truthy(output:find("### Mismatched Scenarios"))
    end)
  end)

  describe("format_html", function()
    it("should produce valid HTML structure", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(2, 0, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find("<!DOCTYPE html>"))
      assert.truthy(output:find("<html>"))
      assert.truthy(output:find("</html>"))
    end)

    it("should include title", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(2, 0, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find("<title>Parity Report</title>"))
    end)

    it("should include parity score", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(8, 2, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find("80.0%% Parity"))
    end)

    it("should include results table", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(1, 1, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find("<table>"))
      assert.truthy(output:find("<th>Scenario</th>"))
    end)

    it("should use pass class for passed status", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(5, 0, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find('class="status pass"'))
    end)

    it("should use fail class for failed status", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(3, 2, 0, 0)

      local output = reporter:format_html(summary)

      assert.truthy(output:find('class="status fail"'))
    end)
  end)

  describe("format", function()
    it("should use text format by default", function()
      local reporter = ParityReporter.new()
      local summary = create_summary(1, 0, 0, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("PARITY REPORT"))
    end)

    it("should use json format when specified", function()
      local reporter = ParityReporter.new({ format = "json" })
      local summary = create_summary(1, 0, 0, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find('"total"'))
    end)

    it("should use markdown format when specified", function()
      local reporter = ParityReporter.new({ format = "markdown" })
      local summary = create_summary(1, 0, 0, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("# Parity Report"))
    end)

    it("should use html format when specified", function()
      local reporter = ParityReporter.new({ format = "html" })
      local summary = create_summary(1, 0, 0, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("<!DOCTYPE html>"))
    end)
  end)

  describe("report", function()
    it("should call output function if provided", function()
      local captured = nil
      local reporter = ParityReporter.new({
        output = function(text)
          captured = text
        end,
        colors = false,
      })
      local summary = create_summary(1, 0, 0, 0)

      reporter:report(summary)

      assert.is_not_nil(captured)
      assert.truthy(captured:find("PARITY REPORT"))
    end)

    it("should return formatted output", function()
      local reporter = ParityReporter.new({
        output = function() end, -- suppress print
        colors = false,
      })
      local summary = create_summary(1, 0, 0, 0)

      local output = reporter:report(summary)

      assert.is_string(output)
    end)
  end)

  describe("FORMATS constant", function()
    it("should export format constants", function()
      assert.equals("text", ParityReporter.FORMATS.TEXT)
      assert.equals("json", ParityReporter.FORMATS.JSON)
      assert.equals("markdown", ParityReporter.FORMATS.MARKDOWN)
      assert.equals("html", ParityReporter.FORMATS.HTML)
    end)
  end)

  describe("edge cases", function()
    it("should handle empty summary", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(0, 0, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("100.0%%"))
      assert.truthy(output:find("PARITY CHECK PASSED"))
    end)

    it("should handle all mismatched", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(0, 5, 0, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("0.0%%"))
      assert.truthy(output:find("PARITY CHECK FAILED"))
    end)

    it("should handle mixed missing results", function()
      local reporter = ParityReporter.new({ colors = false })
      local summary = create_summary(2, 1, 1, 1)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Missing Reference: 1"))
      assert.truthy(output:find("Missing Lua: 1"))
    end)
  end)
end)
