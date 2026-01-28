-- Test suite for CLI Formatter
-- WLS 1.0 GAP-059: CLI output formatter tests

local Formatter = require("lib.whisker.cli.formatter")

describe("CLI Formatter", function()
  describe("plain format", function()
    it("should format error diagnostic with icon", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "WLS-VAR-001",
        message = "Undefined variable",
        severity = "error"
      })

      assert.has.match("WLS%-VAR%-001", output)
      assert.has.match("Undefined variable", output)
      assert.has.match("X", output)  -- Error icon
    end)

    it("should format warning diagnostic", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "WLS-WARN-001",
        message = "Unused passage",
        severity = "warning"
      })

      assert.has.match("WLS%-WARN%-001", output)
      assert.has.match("Unused passage", output)
      assert.has.match("!", output)  -- Warning icon
    end)

    it("should format info diagnostic", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "WLS-INFO-001",
        message = "Helpful hint",
        severity = "info"
      })

      assert.has.match("WLS%-INFO%-001", output)
      assert.has.match("Helpful hint", output)
      assert.has.match("i", output)  -- Info icon
    end)

    it("should include location when provided", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "TEST",
        message = "Test message",
        severity = "error",
        location = { file = "story.ws", line = 10, column = 5 }
      })

      assert.has.match("story%.ws:10:5", output)
      assert.has.match("at", output)
    end)

    it("should include passage_id when provided", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "TEST",
        message = "Test message",
        severity = "error",
        passage_id = "Combat"
      })

      assert.has.match("in passage", output)
      assert.has.match("Combat", output)
    end)

    it("should include suggestion when provided", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_diagnostic({
        code = "TEST",
        message = "Test message",
        severity = "error",
        suggestion = "Try adding a variable"
      })

      assert.has.match("hint:", output)
      assert.has.match("Try adding a variable", output)
    end)
  end)

  describe("json format", function()
    it("should produce valid JSON", function()
      local fmt = Formatter.new({ format = "json" })
      local output = fmt:format_diagnostics({
        { code = "TEST", message = "Test", severity = "error" }
      })

      local json = require("lib.whisker.utils.json")
      local decoded = json.decode(output)
      assert.is_table(decoded)
      assert.equals(1, #decoded)
      assert.equals("TEST", decoded[1].code)
    end)

    it("should encode single diagnostic as JSON", function()
      local fmt = Formatter.new({ format = "json" })
      local output = fmt:format_diagnostic({
        code = "TEST",
        message = "Test message",
        severity = "warning"
      })

      local json = require("lib.whisker.utils.json")
      local decoded = json.decode(output)
      assert.is_table(decoded)
      assert.equals("TEST", decoded.code)
      assert.equals("warning", decoded.severity)
    end)
  end)

  describe("compact format", function()
    it("should produce single line", function()
      local fmt = Formatter.new({ format = "compact" })
      local output = fmt:format_diagnostic({
        code = "WLS-VAR-001",
        message = "Error message",
        severity = "error"
      })

      assert.not_has.match("\n", output)
      assert.has.match("^E ", output)  -- Starts with severity letter
    end)

    it("should include location in compact format", function()
      local fmt = Formatter.new({ format = "compact" })
      local output = fmt:format_diagnostic({
        code = "TEST",
        message = "Error",
        severity = "error",
        location = { file = "test.ws", line = 5 }
      })

      assert.has.match("test%.ws:5:", output)
    end)
  end)

  describe("format_summary", function()
    it("should show errors and warnings count", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_summary(2, 3)

      assert.has.match("2 error%(s%)", output)
      assert.has.match("3 warning%(s%)", output)
    end)

    it("should show success message when no issues", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:format_summary(0, 0)

      assert.has.match("No issues found", output)
    end)

    it("should return empty string for json format", function()
      local fmt = Formatter.new({ format = "json" })
      local output = fmt:format_summary(1, 1)

      assert.equals("", output)
    end)
  end)

  describe("helper methods", function()
    it("should format success message", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:success("Build complete")

      assert.has.match("%[OK%]", output)
      assert.has.match("Build complete", output)
    end)

    it("should format error message", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:error("Build failed")

      assert.has.match("%[ERROR%]", output)
      assert.has.match("Build failed", output)
    end)

    it("should format progress message", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:progress("Processing...")

      assert.has.match("Processing", output)
      assert.has.match("->", output)
    end)

    it("should return JSON for success in json format", function()
      local fmt = Formatter.new({ format = "json" })
      local output = fmt:success("Done")

      local json = require("lib.whisker.utils.json")
      local decoded = json.decode(output)
      assert.is_true(decoded.success)
      assert.equals("Done", decoded.message)
    end)
  end)

  describe("colors", function()
    it("should apply colors when enabled", function()
      local fmt = Formatter.new({ colors = true })
      local output = fmt:color("test", "red")

      assert.has.match("\27%[31m", output)  -- Red ANSI code
      assert.has.match("\27%[0m", output)   -- Reset code
    end)

    it("should not apply colors when disabled", function()
      local fmt = Formatter.new({ colors = false })
      local output = fmt:color("test", "red")

      assert.equals("test", output)
      assert.not_has.match("\27%[", output)
    end)
  end)
end)
