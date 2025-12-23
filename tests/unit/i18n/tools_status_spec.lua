-- tests/unit/i18n/tools_status_spec.lua
-- Unit tests for status report tool (Stage 8)

describe("Status Tool", function()
  local Status

  before_each(function()
    package.loaded["whisker.i18n.tools.status"] = nil
    Status = require("whisker.i18n.tools.status")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", Status._VERSION)
    end)
  end)

  describe("countKeys()", function()
    it("counts flat keys", function()
      local data = { a = "1", b = "2", c = "3" }
      assert.equals(3, Status.countKeys(data))
    end)

    it("counts nested keys", function()
      local data = {
        outer = {
          inner1 = "value",
          inner2 = "value"
        }
      }
      assert.equals(2, Status.countKeys(data))
    end)

    it("counts deeply nested", function()
      local data = {
        a = {
          b = {
            c = "value"
          }
        }
      }
      assert.equals(1, Status.countKeys(data))
    end)

    it("handles empty table", function()
      assert.equals(0, Status.countKeys({}))
    end)

    it("handles mixed nesting", function()
      local data = {
        simple = "value",
        nested = {
          a = "1",
          b = "2"
        }
      }
      assert.equals(3, Status.countKeys(data))
    end)
  end)

  describe("calculateCoverage()", function()
    it("returns 100 for identical data", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x", b = "y" }

      local coverage = Status.calculateCoverage(base, target)
      assert.equals(100, coverage)
    end)

    it("returns 50 for half coverage", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x" }

      local coverage = Status.calculateCoverage(base, target)
      assert.equals(50, coverage)
    end)

    it("returns 0 for no coverage", function()
      local base = { a = "1", b = "2" }
      local target = {}

      local coverage = Status.calculateCoverage(base, target)
      assert.equals(0, coverage)
    end)

    it("handles nested structures", function()
      local base = {
        outer = { a = "1", b = "2" }
      }
      local target = {
        outer = { a = "x" }
      }

      local coverage = Status.calculateCoverage(base, target)
      assert.equals(50, coverage)
    end)

    it("returns 100 for empty base", function()
      local coverage = Status.calculateCoverage({}, { a = "1" })
      assert.equals(100, coverage)
    end)
  end)

  describe("getLocaleStatus()", function()
    it("returns complete status info", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x", b = "y" }

      local status = Status.getLocaleStatus(base, target, "es")

      assert.equals("es", status.locale)
      assert.equals(2, status.baseKeys)
      assert.equals(2, status.targetKeys)
      assert.equals(2, status.matchingKeys)
      assert.equals(100, status.coverage)
      assert.equals("complete", status.status)
      assert.is_true(status.complete)
    end)

    it("returns partial status", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x" }

      local status = Status.getLocaleStatus(base, target, "es")

      assert.equals(50, status.coverage)
      assert.equals("partial", status.status)
      assert.is_false(status.complete)
    end)
  end)

  describe("getCoverageStatus()", function()
    it("returns complete for 100%", function()
      assert.equals("complete", Status.getCoverageStatus(100))
    end)

    it("returns good for 80%+", function()
      assert.equals("good", Status.getCoverageStatus(90))
      assert.equals("good", Status.getCoverageStatus(80))
    end)

    it("returns partial for 50%+", function()
      assert.equals("partial", Status.getCoverageStatus(70))
      assert.equals("partial", Status.getCoverageStatus(50))
    end)

    it("returns incomplete for <50%", function()
      assert.equals("incomplete", Status.getCoverageStatus(30))
      assert.equals("incomplete", Status.getCoverageStatus(0))
    end)
  end)

  describe("report()", function()
    it("generates report text", function()
      local localesData = {
        en = { greeting = "Hello" },
        es = { greeting = "Hola" }
      }

      local report = Status.report("en", localesData)

      assert.matches("Translation Status Report", report)
      assert.matches("en", report)
      assert.matches("es", report)
    end)

    it("shows key counts", function()
      local localesData = {
        en = { a = "1", b = "2" },
        es = { a = "x" }
      }

      local report = Status.report("en", localesData)
      assert.matches("1/2", report)
    end)

    it("handles missing base locale", function()
      local localesData = { es = { a = "1" } }
      local report = Status.report("en", localesData)
      assert.matches("not found", report)
    end)

    it("handles no other locales", function()
      local localesData = { en = { a = "1" } }
      local report = Status.report("en", localesData)
      assert.matches("No other locales", report)
    end)
  end)

  describe("getStatusIcon()", function()
    it("returns icon for complete", function()
      local icon = Status.getStatusIcon("complete")
      assert.is_string(icon)
      assert.is_true(#icon > 0)
    end)

    it("returns different icons for different statuses", function()
      local complete = Status.getStatusIcon("complete")
      local incomplete = Status.getStatusIcon("incomplete")
      assert.is_not.equals(complete, incomplete)
    end)

    it("handles unknown status", function()
      local icon = Status.getStatusIcon("unknown")
      assert.is_string(icon)
    end)
  end)

  describe("getMissingKeys()", function()
    it("finds missing keys", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x" }

      local missing = Status.getMissingKeys(base, target)

      assert.equals(1, #missing)
      assert.equals("b", missing[1])
    end)

    it("finds nested missing keys", function()
      local base = {
        outer = { a = "1", b = "2" }
      }
      local target = {
        outer = { a = "x" }
      }

      local missing = Status.getMissingKeys(base, target)

      assert.equals(1, #missing)
      assert.equals("outer.b", missing[1])
    end)

    it("returns empty for complete translation", function()
      local base = { a = "1" }
      local target = { a = "x" }

      local missing = Status.getMissingKeys(base, target)
      assert.equals(0, #missing)
    end)

    it("handles nil target", function()
      local base = { a = "1" }
      local missing = Status.getMissingKeys(base, nil)
      assert.equals(1, #missing)
    end)
  end)

  describe("detailedReport()", function()
    it("generates detailed report", function()
      local base = { a = "1", b = "2" }
      local target = { a = "x" }

      local report = Status.detailedReport(base, target, "es")

      assert.matches("es", report)
      assert.matches("partial", report)
      assert.matches("1/2", report)
      assert.matches("Missing", report)
    end)

    it("limits missing keys shown", function()
      local base = {}
      local target = {}
      for i = 1, 20 do
        base["key" .. i] = "value"
      end

      local report = Status.detailedReport(base, target, "es", 5)
      assert.matches("and %d+ more", report)
    end)

    it("reports no missing when complete", function()
      local base = { a = "1" }
      local target = { a = "x" }

      local report = Status.detailedReport(base, target, "es")
      assert.matches("No missing", report)
    end)
  end)

  describe("getSummary()", function()
    it("returns summary statistics", function()
      local localesData = {
        en = { a = "1", b = "2" },
        es = { a = "x", b = "y" },
        fr = { a = "z" }
      }

      local summary = Status.getSummary("en", localesData)

      assert.equals("en", summary.baseLocale)
      assert.equals(2, summary.baseKeys)
      assert.equals(2, summary.totalLocales)
      assert.equals(1, summary.completeCount)  -- Only es is complete
    end)

    it("calculates average coverage", function()
      local localesData = {
        en = { a = "1", b = "2" },
        es = { a = "x", b = "y" },  -- 100%
        fr = { a = "z" }            -- 50%
      }

      local summary = Status.getSummary("en", localesData)
      assert.equals(75, summary.averageCoverage)
    end)

    it("returns nil for missing base", function()
      local summary = Status.getSummary("en", { es = { a = "1" } })
      assert.is_nil(summary)
    end)
  end)
end)
