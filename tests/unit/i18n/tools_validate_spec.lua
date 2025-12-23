-- tests/unit/i18n/tools_validate_spec.lua
-- Unit tests for validation tool (Stage 8)

describe("Validate Tool", function()
  local Validate

  before_each(function()
    package.loaded["whisker.i18n.tools.validate"] = nil
    Validate = require("whisker.i18n.tools.validate")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", Validate._VERSION)
    end)
  end)

  describe("findMissing()", function()
    it("finds missing keys", function()
      local base = { greeting = "Hello", farewell = "Goodbye" }
      local target = { greeting = "Hola" }  -- Missing 'farewell'
      local issues = {}

      Validate.findMissing(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("missing_key", issues[1].type)
      assert.equals("farewell", issues[1].path)
    end)

    it("finds missing sections", function()
      local base = { dialogue = { intro = "Hi" } }
      local target = {}  -- Missing 'dialogue' section
      local issues = {}

      Validate.findMissing(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("missing_section", issues[1].type)
      assert.equals("dialogue", issues[1].path)
    end)

    it("finds missing nested keys", function()
      local base = { dialogue = { intro = "Hi", outro = "Bye" } }
      local target = { dialogue = { intro = "Hola" } }
      local issues = {}

      Validate.findMissing(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("dialogue.outro", issues[1].path)
    end)

    it("reports no issues when complete", function()
      local base = { greeting = "Hello" }
      local target = { greeting = "Hola" }
      local issues = {}

      Validate.findMissing(base, target, "", issues)

      assert.equals(0, #issues)
    end)
  end)

  describe("findUnused()", function()
    it("finds unused keys", function()
      local base = { greeting = "Hello" }
      local target = { greeting = "Hola", extra = "Extra" }
      local issues = {}

      Validate.findUnused(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("unused_key", issues[1].type)
      assert.equals("extra", issues[1].path)
    end)

    it("finds unused sections", function()
      local base = {}
      local target = { extra = { nested = "value" } }
      local issues = {}

      Validate.findUnused(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("unused_section", issues[1].type)
    end)

    it("reports no issues when no extras", function()
      local base = { greeting = "Hello" }
      local target = { greeting = "Hola" }
      local issues = {}

      Validate.findUnused(base, target, "", issues)

      assert.equals(0, #issues)
    end)
  end)

  describe("checkVariables()", function()
    it("finds missing variables", function()
      local base = { greeting = "Hello, {name}!" }
      local target = { greeting = "Hola!" }  -- Missing {name}
      local issues = {}

      Validate.checkVariables(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("missing_variable", issues[1].type)
      assert.equals("name", issues[1].variable)
    end)

    it("finds extra variables", function()
      local base = { greeting = "Hello!" }
      local target = { greeting = "Hola, {name}!" }  -- Extra {name}
      local issues = {}

      Validate.checkVariables(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("extra_variable", issues[1].type)
    end)

    it("handles multiple variables", function()
      local base = { msg = "Hello {a} and {b}!" }
      local target = { msg = "Hola {a}!" }  -- Missing {b}
      local issues = {}

      Validate.checkVariables(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("b", issues[1].variable)
    end)

    it("reports no issues when variables match", function()
      local base = { greeting = "Hello, {name}!" }
      local target = { greeting = "Hola, {name}!" }
      local issues = {}

      Validate.checkVariables(base, target, "", issues)

      assert.equals(0, #issues)
    end)

    it("handles nested structures", function()
      local base = { outer = { inner = "Hello {name}" } }
      local target = { outer = { inner = "Hola" } }
      local issues = {}

      Validate.checkVariables(base, target, "", issues)

      assert.equals(1, #issues)
      assert.equals("outer.inner", issues[1].path)
    end)
  end)

  describe("extractVariables()", function()
    it("extracts single variable", function()
      local vars = Validate.extractVariables("Hello {name}!")
      assert.equals(1, #vars)
      assert.equals("name", vars[1])
    end)

    it("extracts multiple variables", function()
      local vars = Validate.extractVariables("{a} and {b} and {c}")
      assert.equals(3, #vars)
    end)

    it("returns empty for no variables", function()
      local vars = Validate.extractVariables("No variables here")
      assert.equals(0, #vars)
    end)

    it("handles empty string", function()
      local vars = Validate.extractVariables("")
      assert.equals(0, #vars)
    end)
  end)

  describe("compare()", function()
    it("finds all issue types", function()
      local base = {
        greeting = "Hello {name}",
        farewell = "Goodbye"
      }
      local target = {
        greeting = "Hola",  -- Missing {name}
        extra = "Extra"     -- Unused key
        -- Missing: farewell
      }

      local issues = Validate.compare(base, target)

      -- Should have: missing_key, missing_variable, unused_key
      assert.is_true(#issues >= 3)

      local hasMissing = false
      local hasMissingVar = false
      local hasUnused = false

      for _, issue in ipairs(issues) do
        if issue.type == "missing_key" then hasMissing = true end
        if issue.type == "missing_variable" then hasMissingVar = true end
        if issue.type == "unused_key" then hasUnused = true end
      end

      assert.is_true(hasMissing)
      assert.is_true(hasMissingVar)
      assert.is_true(hasUnused)
    end)
  end)

  describe("countIssues()", function()
    it("counts errors and warnings", function()
      local issues = {
        { severity = "error" },
        { severity = "error" },
        { severity = "warning" }
      }

      local errors, warnings = Validate.countIssues(issues)
      assert.equals(2, errors)
      assert.equals(1, warnings)
    end)

    it("returns zeros for empty list", function()
      local errors, warnings = Validate.countIssues({})
      assert.equals(0, errors)
      assert.equals(0, warnings)
    end)
  end)

  describe("report()", function()
    it("generates report text", function()
      local issues = {
        { type = "missing_key", path = "test", severity = "error" }
      }

      local report = Validate.report(issues)

      assert.matches("Translation Validation Report", report)
      assert.matches("error", report:lower())
    end)

    it("reports no issues", function()
      local report = Validate.report({})
      assert.matches("No issues found", report)
    end)

    it("includes variable info", function()
      local issues = {
        { type = "missing_variable", path = "test", variable = "name", severity = "error" }
      }

      local report = Validate.report(issues)
      assert.matches("name", report)
    end)
  end)

  describe("flattenData()", function()
    it("flattens nested structure", function()
      local data = {
        outer = {
          inner = "value"
        }
      }

      local flat = Validate.flattenData(data)
      assert.equals("value", flat["outer.inner"])
    end)

    it("handles deeply nested", function()
      local data = {
        a = { b = { c = "deep" } }
      }

      local flat = Validate.flattenData(data)
      assert.equals("deep", flat["a.b.c"])
    end)

    it("handles simple values", function()
      local data = { key = "value" }
      local flat = Validate.flattenData(data)
      assert.equals("value", flat["key"])
    end)
  end)

  describe("validateSourceKeys()", function()
    it("finds undefined keys", function()
      local sourceKeys = {
        { key = "existing", file = "test", line = 1 },
        { key = "missing", file = "test", line = 2 }
      }
      local localeData = { existing = "value" }

      local issues = Validate.validateSourceKeys(sourceKeys, localeData)

      assert.equals(1, #issues)
      assert.equals("undefined_key", issues[1].type)
      assert.equals("missing", issues[1].path)
    end)

    it("reports no issues when all keys exist", function()
      local sourceKeys = {
        { key = "test", file = "test", line = 1 }
      }
      local localeData = { test = "value" }

      local issues = Validate.validateSourceKeys(sourceKeys, localeData)
      assert.equals(0, #issues)
    end)
  end)

  describe("checkPluralCompleteness()", function()
    it("finds missing plural categories", function()
      local data = {
        items = {
          one = "1 item"
          -- Missing: other
        }
      }
      local issues = {}

      Validate.checkPluralCompleteness(data, { "one", "other" }, "", issues)

      assert.equals(1, #issues)
      assert.equals("missing_plural", issues[1].type)
      assert.equals("other", issues[1].category)
    end)

    it("reports no issues when complete", function()
      local data = {
        items = {
          one = "1 item",
          other = "{count} items"
        }
      }
      local issues = {}

      Validate.checkPluralCompleteness(data, { "one", "other" }, "", issues)
      assert.equals(0, #issues)
    end)
  end)
end)
