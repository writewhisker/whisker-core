-- Tests for Conversion Report Module
local Report = require("whisker.format.converters.report")

describe("Conversion Report", function()

  describe("Report Creation", function()
    it("should create a new report with source and target formats", function()
      local report = Report.new("harlowe", "chapbook")

      assert.is_not_nil(report)
      assert.equals("harlowe", report.source_format)
      assert.equals("chapbook", report.target_format)
    end)

    it("should initialize with empty entries", function()
      local report = Report.new("harlowe", "sugarcube")

      assert.equals(0, #report.entries)
    end)

    it("should handle missing format arguments", function()
      local report = Report.new()

      assert.equals("unknown", report.source_format)
      assert.equals("unknown", report.target_format)
    end)
  end)

  describe("Adding Entries", function()
    it("should add converted feature entries", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("dropdown", "Start", {
        original = "(dropdown: bind $choice, 'a', 'b')",
        result = "{dropdown menu for: 'choice', choices: ['a', 'b']}"
      })

      assert.equals(1, #report.entries)
      assert.equals("converted", report.entries[1].type)
      assert.equals("dropdown", report.entries[1].feature)
      assert.equals("Start", report.entries[1].passage)
    end)

    it("should add approximated feature entries", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_approximated(
        "live",
        "Timer Passage",
        "(live: 2s)[Time left: $timer]",
        "[note]Live update (requires JS)[continue]",
        {severity = "warning", line = 5}
      )

      assert.equals(1, #report.entries)
      assert.equals("approximated", report.entries[1].type)
      assert.equals("live", report.entries[1].feature)
      assert.equals("warning", report.entries[1].severity)
      assert.equals(5, report.entries[1].line)
    end)

    it("should add lost feature entries", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_lost(
        "enchant",
        "Styled Passage",
        "DOM manipulation not available in Chapbook",
        {
          original = "(enchant: ?hook, (text-style: 'bold'))",
          suggestion = "Use CSS classes instead"
        }
      )

      assert.equals(1, #report.entries)
      assert.equals("lost", report.entries[1].type)
      assert.equals("enchant", report.entries[1].feature)
      assert.is_not_nil(report.entries[1].reason)
      assert.is_not_nil(report.entries[1].suggestion)
    end)

    it("should add multiple entries", function()
      local report = Report.new("harlowe", "sugarcube")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      assert.equals(4, #report.entries)
    end)
  end)

  describe("Summary Calculation", function()
    it("should calculate correct summary counts", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_converted("print", "Output", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_approximated("click", "Interactive", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local summary = report:get_summary()

      assert.equals(3, summary.converted)
      assert.equals(2, summary.approximated)
      assert.equals(1, summary.lost)
      assert.equals(6, summary.total_entries)
    end)

    it("should return zero counts for empty report", function()
      local report = Report.new("harlowe", "snowman")

      local summary = report:get_summary()

      assert.equals(0, summary.converted)
      assert.equals(0, summary.approximated)
      assert.equals(0, summary.lost)
      assert.equals(0, summary.total_entries)
    end)

    it("should include passage count in summary", function()
      local report = Report.new("harlowe", "chapbook")
      report:set_passage_count(10)

      local summary = report:get_summary()

      assert.equals(10, summary.passage_count)
    end)

    it("should include format info in summary", function()
      local report = Report.new("harlowe", "chapbook")

      local summary = report:get_summary()

      assert.equals("harlowe", summary.source_format)
      assert.equals("chapbook", summary.target_format)
    end)
  end)

  describe("Quality Score Calculation", function()
    it("should return 100 for empty report", function()
      local report = Report.new("harlowe", "chapbook")

      assert.equals(100, report:get_quality_score())
    end)

    it("should return 100 for all converted features", function()
      local report = Report.new("harlowe", "sugarcube")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_converted("print", "Start", {})

      assert.equals(100, report:get_quality_score())
    end)

    it("should return 50 for all approximated features", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_approximated("live", "Timer", "", "", {})
      report:add_approximated("click", "Interactive", "", "", {})

      assert.equals(50, report:get_quality_score())
    end)

    it("should return 0 for all lost features", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_lost("enchant", "Styled", "No equivalent", {})
      report:add_lost("mouseover", "Interactive", "Not supported", {})

      assert.equals(0, report:get_quality_score())
    end)

    it("should calculate mixed scores correctly", function()
      local report = Report.new("harlowe", "chapbook")

      -- 2 converted (2 * 1.0 = 2.0)
      -- 2 approximated (2 * 0.5 = 1.0)
      -- 1 lost (1 * 0.0 = 0.0)
      -- Total: 5 entries, weighted sum = 3.0
      -- Score = 3.0 / 5.0 * 100 = 60%

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_approximated("click", "Interactive", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      assert.equals(60, report:get_quality_score())
    end)
  end)

  describe("Get Details", function()
    it("should return all entries when no filter specified", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local details = report:get_details()

      assert.equals(3, #details)
    end)

    it("should filter entries by type", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local converted = report:get_details(Report.ENTRY_TYPES.CONVERTED)
      local approximated = report:get_details(Report.ENTRY_TYPES.APPROXIMATED)
      local lost = report:get_details(Report.ENTRY_TYPES.LOST)

      assert.equals(2, #converted)
      assert.equals(1, #approximated)
      assert.equals(1, #lost)
    end)
  end)

  describe("Grouping", function()
    it("should group entries by passage", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local by_passage = report:get_by_passage()

      assert.equals(2, #by_passage["Start"])
      assert.equals(1, #by_passage["Timer"])
      assert.equals(1, #by_passage["Styled"])
    end)

    it("should group entries by feature", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_converted("set", "Shop", {})
      report:add_converted("if", "Start", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local by_feature = report:get_by_feature()

      assert.equals(2, #by_feature["set"])
      assert.equals(1, #by_feature["if"])
      assert.equals(1, #by_feature["enchant"])
    end)
  end)

  describe("JSON Serialization", function()
    it("should serialize report to JSON", function()
      local report = Report.new("harlowe", "chapbook")
      report:set_passage_count(5)

      report:add_converted("set", "Start", {original = "(set: $x to 5)"})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local json_str = report:to_json()

      assert.is_string(json_str)
      assert.matches('"source_format"', json_str)
      assert.matches('"harlowe"', json_str)
      assert.matches('"target_format"', json_str)
      assert.matches('"chapbook"', json_str)
      assert.matches('"entries"', json_str)
    end)

    it("should deserialize report from JSON", function()
      local original = Report.new("harlowe", "sugarcube")
      original:set_passage_count(3)
      original:add_converted("set", "Start", {})
      original:add_approximated("live", "Timer", "(live: 1s)", "<<repeat 1s>>", {})

      local json_str = original:to_json()
      local restored = Report.from_json(json_str)

      assert.is_not_nil(restored)
      assert.equals("harlowe", restored.source_format)
      assert.equals("sugarcube", restored.target_format)
      assert.equals(3, restored.passage_count)
      assert.equals(2, #restored.entries)
    end)

    it("should handle invalid JSON gracefully", function()
      local report, err = Report.from_json("not valid json")

      assert.is_nil(report)
      assert.is_not_nil(err)
    end)
  end)

  describe("Text Output", function()
    it("should generate human-readable text summary", function()
      local report = Report.new("harlowe", "chapbook")
      report:set_passage_count(10)

      report:add_converted("set", "Start", {})
      report:add_approximated("live", "Timer", "(live: 1s)", "[note]...", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      local text = report:to_text()

      assert.matches("harlowe %-> chapbook", text)
      assert.matches("Passages processed: 10", text)
      assert.matches("Features converted: 1", text)
      assert.matches("Features approximated: 1", text)
      assert.matches("Features lost: 1", text)
      assert.matches("Quality score:", text)
    end)
  end)

  describe("Issue Detection", function()
    it("should return false for has_issues when all converted", function()
      local report = Report.new("harlowe", "sugarcube")

      report:add_converted("set", "Start", {})
      report:add_converted("if", "Start", {})

      assert.is_false(report:has_issues())
    end)

    it("should return true for has_issues when approximations exist", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_approximated("live", "Timer", "", "", {})

      assert.is_true(report:has_issues())
    end)

    it("should return true for has_issues when losses exist", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_converted("set", "Start", {})
      report:add_lost("enchant", "Styled", "No equivalent", {})

      assert.is_true(report:has_issues())
    end)
  end)

  describe("Problematic Features", function()
    it("should identify most problematic features", function()
      local report = Report.new("harlowe", "chapbook")

      -- Add multiple issues for 'enchant'
      report:add_lost("enchant", "Page1", "No equiv", {})
      report:add_lost("enchant", "Page2", "No equiv", {})
      report:add_lost("enchant", "Page3", "No equiv", {})

      -- Add fewer issues for 'live'
      report:add_approximated("live", "Timer1", "", "", {})
      report:add_approximated("live", "Timer2", "", "", {})

      -- Add one issue for 'click'
      report:add_approximated("click", "Button", "", "", {})

      local problems = report:get_problematic_features(3)

      assert.equals(3, #problems)
      assert.equals("enchant", problems[1].feature)
      assert.equals(3, problems[1].count)
      assert.equals("live", problems[2].feature)
      assert.equals(2, problems[2].count)
    end)

    it("should respect limit parameter", function()
      local report = Report.new("harlowe", "chapbook")

      report:add_lost("feat1", "P1", "reason", {})
      report:add_lost("feat2", "P2", "reason", {})
      report:add_lost("feat3", "P3", "reason", {})
      report:add_lost("feat4", "P4", "reason", {})
      report:add_lost("feat5", "P5", "reason", {})

      local problems = report:get_problematic_features(2)

      assert.equals(2, #problems)
    end)
  end)

  describe("Report Merging", function()
    it("should merge entries from another report", function()
      local report1 = Report.new("harlowe", "chapbook")
      report1:set_passage_count(5)
      report1:add_converted("set", "Start", {})

      local report2 = Report.new("harlowe", "chapbook")
      report2:set_passage_count(3)
      report2:add_lost("enchant", "End", "No equiv", {})

      report1:merge(report2)

      assert.equals(2, #report1.entries)
      assert.equals(8, report1.passage_count)
    end)
  end)

end)
