-- spec/formats/ink/validator_spec.lua
-- Tests for conversion validation

describe("Validator", function()
  local Validator

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.validator") then
        package.loaded[k] = nil
      end
    end

    Validator = require("whisker.formats.ink.validator")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Validator._whisker)
      assert.are.equal("InkValidator", Validator._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.validator", Validator._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local validator = Validator.new()
      assert.is_table(validator)
    end)

    it("should initialize empty collections", function()
      local validator = Validator.new()
      assert.are.same({}, validator.errors)
      assert.are.same({}, validator.warnings)
      assert.are.same({}, validator.info)
    end)
  end)

  describe("SEVERITY", function()
    it("should define severity levels", function()
      assert.are.equal("error", Validator.SEVERITY.ERROR)
      assert.are.equal("warning", Validator.SEVERITY.WARNING)
      assert.are.equal("info", Validator.SEVERITY.INFO)
    end)
  end)

  describe("add_issue", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should add error", function()
      validator:add_issue(Validator.SEVERITY.ERROR, "Test error")
      assert.are.equal(1, #validator.errors)
      assert.are.equal("Test error", validator.errors[1].message)
    end)

    it("should add warning", function()
      validator:add_issue(Validator.SEVERITY.WARNING, "Test warning")
      assert.are.equal(1, #validator.warnings)
      assert.are.equal("Test warning", validator.warnings[1].message)
    end)

    it("should add info", function()
      validator:add_issue(Validator.SEVERITY.INFO, "Test info")
      assert.are.equal(1, #validator.info)
      assert.are.equal("Test info", validator.info[1].message)
    end)

    it("should include context", function()
      validator:add_issue(Validator.SEVERITY.ERROR, "Error", { passage = "test" })
      assert.are.equal("test", validator.errors[1].context.passage)
    end)
  end)

  describe("validate", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should return error for nil story", function()
      local result = validator:validate(nil)
      assert.is_false(result.success)
      assert.are.equal(1, #result.errors)
    end)

    it("should pass for valid story", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello" }
        },
        variables = {}
      }

      local result = validator:validate(story)
      assert.is_true(result.success)
      assert.are.equal(0, #result.errors)
    end)

    it("should count passages", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start" },
          other = { id = "other" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(2, result.stats.passages)
    end)

    it("should count choices", function()
      local story = {
        start = "start",
        passages = {
          start = {
            id = "start",
            choices = {
              { text = "One", target = "start" },
              { text = "Two", target = "start" }
            }
          }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(2, result.stats.choices)
    end)

    it("should count variables", function()
      local story = {
        start = "start",
        passages = { start = { id = "start" } },
        variables = {
          health = { name = "health", type = "integer", default = 100 },
          name = { name = "name", type = "string", default = "Player" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(2, result.stats.variables)
    end)
  end)

  describe("passage validation", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should error on missing passage id", function()
      local story = {
        passages = {
          test = { content = "No id field" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(1, #result.errors)
      assert.truthy(result.errors[1].message:match("missing id"))
    end)

    it("should warn on choice without text", function()
      local story = {
        start = "start",
        passages = {
          start = {
            id = "start",
            choices = {
              { target = "start" }
            }
          }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(1, #result.warnings)
      assert.truthy(result.warnings[1].message:match("no text"))
    end)

    it("should error on choice targeting non-existent passage", function()
      local story = {
        start = "start",
        passages = {
          start = {
            id = "start",
            choices = {
              { text = "Go", target = "nonexistent" }
            }
          }
        }
      }

      local result = validator:validate(story)
      assert.is_false(result.success)
      assert.truthy(result.errors[1].message:match("non%-existent passage"))
    end)
  end)

  describe("link validation", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should error on invalid next passage", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", next = "missing" }
        }
      }

      local result = validator:validate(story)
      assert.is_false(result.success)
      assert.truthy(result.errors[1].message:match("Next passage does not exist"))
    end)

    it("should error on invalid divert", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", divert = "missing" }
        }
      }

      local result = validator:validate(story)
      assert.is_false(result.success)
      assert.truthy(result.errors[1].message:match("Divert target does not exist"))
    end)

    it("should count links", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", next = "other" },
          other = { id = "other", divert = "start" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(2, result.stats.links)
    end)
  end)

  describe("orphaned content detection", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should warn on orphaned passage", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start" },
          orphan = { id = "orphan" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(1, #result.warnings)
      assert.truthy(result.warnings[1].message:match("not reachable"))
    end)

    it("should not warn for reachable passages", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", next = "middle" },
          middle = { id = "middle", divert = "end" },
          ["end"] = { id = "end" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(0, #result.warnings)
    end)

    it("should follow choice targets", function()
      local story = {
        start = "start",
        passages = {
          start = {
            id = "start",
            choices = {
              { text = "Go", target = "destination" }
            }
          },
          destination = { id = "destination" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(0, result.stats.orphaned)
    end)

    it("should count orphaned passages", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start" },
          orphan1 = { id = "orphan1" },
          orphan2 = { id = "orphan2" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(2, result.stats.orphaned)
    end)

    it("should warn when no start defined", function()
      local story = {
        passages = {
          test = { id = "test" }
        }
      }

      local result = validator:validate(story)
      assert.truthy(#result.warnings > 0)
    end)

    it("should error when start does not exist", function()
      local story = {
        start = "missing",
        passages = {
          test = { id = "test" }
        }
      }

      local result = validator:validate(story)
      assert.is_false(result.success)
    end)
  end)

  describe("variable validation", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should accept valid variable types", function()
      local story = {
        start = "start",
        passages = { start = { id = "start" } },
        variables = {
          int_var = { type = "integer", default = 10 },
          str_var = { type = "string", default = "hello" },
          bool_var = { type = "boolean", default = true }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(0, #result.warnings)
    end)

    it("should warn on unknown variable type", function()
      local story = {
        start = "start",
        passages = { start = { id = "start" } },
        variables = {
          weird = { type = "unknown_type", default = nil }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(1, #result.warnings)
      assert.truthy(result.warnings[1].message:match("Unknown variable type"))
    end)

    it("should warn on type mismatch", function()
      local story = {
        start = "start",
        passages = { start = { id = "start" } },
        variables = {
          mismatch = { type = "integer", default = "not a number" }
        }
      }

      local result = validator:validate(story)
      assert.are.equal(1, #result.warnings)
      assert.truthy(result.warnings[1].message:match("type mismatch"))
    end)
  end)

  describe("get_result", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("should return success true when no errors", function()
      local result = validator:get_result()
      assert.is_true(result.success)
    end)

    it("should return success false when errors exist", function()
      validator:add_issue(Validator.SEVERITY.ERROR, "Error")
      local result = validator:get_result()
      assert.is_false(result.success)
    end)

    it("should include all collections", function()
      local result = validator:get_result()
      assert.is_table(result.errors)
      assert.is_table(result.warnings)
      assert.is_table(result.info)
      assert.is_table(result.stats)
    end)
  end)

  describe("helper methods", function()
    local validator

    before_each(function()
      validator = Validator.new()
    end)

    it("is_valid should return true with no errors", function()
      assert.is_true(validator:is_valid())
    end)

    it("is_valid should return false with errors", function()
      validator:add_issue(Validator.SEVERITY.ERROR, "Error")
      assert.is_false(validator:is_valid())
    end)

    it("error_count should return count", function()
      validator:add_issue(Validator.SEVERITY.ERROR, "One")
      validator:add_issue(Validator.SEVERITY.ERROR, "Two")
      assert.are.equal(2, validator:error_count())
    end)

    it("warning_count should return count", function()
      validator:add_issue(Validator.SEVERITY.WARNING, "One")
      validator:add_issue(Validator.SEVERITY.WARNING, "Two")
      validator:add_issue(Validator.SEVERITY.WARNING, "Three")
      assert.are.equal(3, validator:warning_count())
    end)
  end)
end)

describe("Report", function()
  local Report

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.report") then
        package.loaded[k] = nil
      end
    end

    Report = require("whisker.formats.ink.report")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Report._whisker)
      assert.are.equal("ConversionReport", Report._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.report", Report._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local report = Report.new()
      assert.is_table(report)
    end)

    it("should have default title", function()
      local report = Report.new()
      assert.are.equal("Ink Conversion Report", report.title)
    end)

    it("should have timestamp", function()
      local report = Report.new()
      assert.is_number(report.timestamp)
    end)
  end)

  describe("set_source", function()
    it("should set source info", function()
      local report = Report.new()
      report:set_source({ path = "test.json", ink_version = 20 })
      assert.are.equal("test.json", report.source_info.path)
      assert.are.equal(20, report.source_info.ink_version)
    end)
  end)

  describe("set_stats", function()
    it("should set conversion stats", function()
      local report = Report.new()
      report:set_stats({ passages = 10, choices = 5 })
      assert.are.equal(10, report.conversion_stats.passages)
    end)
  end)

  describe("set_validation", function()
    it("should set validation result", function()
      local report = Report.new()
      local result = { success = true, errors = {}, warnings = {} }
      report:set_validation(result)
      assert.is_true(report.validation_result.success)
    end)
  end)

  describe("add_feature", function()
    it("should add feature support info", function()
      local report = Report.new()
      report:add_feature("Knots", "full")
      report:add_feature("Threads", "partial", "Basic support")

      assert.are.equal(2, #report.feature_support)
      assert.are.equal("Knots", report.feature_support[1].feature)
      assert.are.equal("full", report.feature_support[1].level)
      assert.are.equal("Basic support", report.feature_support[2].notes)
    end)
  end)

  describe("get_summary", function()
    it("should return summary statistics", function()
      local report = Report.new()
      report:set_source({ path = "test.json" })
      report:set_stats({ passages = 5 })
      report:set_validation({ success = true, errors = {}, warnings = { {} } })
      report:add_feature("Test", "full")
      report:add_feature("Test2", "partial")

      local summary = report:get_summary()

      assert.are.equal("test.json", summary.source.path)
      assert.are.equal(5, summary.conversion.passages)
      assert.is_true(summary.validation.success)
      assert.are.equal(0, summary.validation.errors)
      assert.are.equal(1, summary.validation.warnings)
      assert.are.equal(1, summary.features_full)
      assert.are.equal(1, summary.features_partial)
    end)
  end)

  describe("to_text", function()
    it("should generate text report", function()
      local report = Report.new()
      report:set_source({ path = "test.json" })
      report:set_validation({ success = true, errors = {}, warnings = {} })

      local text = report:to_text()

      assert.is_string(text)
      assert.truthy(text:match("Ink Conversion Report"))
      assert.truthy(text:match("test%.json"))
    end)

    it("should include errors when present", function()
      local report = Report.new()
      report:set_validation({
        success = false,
        errors = { { message = "Test error" } },
        warnings = {}
      })

      local text = report:to_text()
      assert.truthy(text:match("FAILED"))
      assert.truthy(text:match("Test error"))
    end)

    it("should include warnings when present", function()
      local report = Report.new()
      report:set_validation({
        success = true,
        errors = {},
        warnings = { { message = "Test warning" } }
      })

      local text = report:to_text()
      assert.truthy(text:match("Test warning"))
    end)

    it("should limit warnings to 10", function()
      local report = Report.new()
      local warnings = {}
      for i = 1, 15 do
        table.insert(warnings, { message = "Warning " .. i })
      end
      report:set_validation({
        success = true,
        errors = {},
        warnings = warnings
      })

      local text = report:to_text()
      assert.truthy(text:match("and 5 more"))
    end)
  end)

  describe("to_table", function()
    it("should return serializable table", function()
      local report = Report.new()
      report:set_source({ path = "test.json" })

      local data = report:to_table()

      assert.is_table(data)
      assert.are.equal("Ink Conversion Report", data.title)
      assert.are.equal("test.json", data.source.path)
      assert.is_table(data.summary)
    end)
  end)

  describe("from_conversion", function()
    it("should create report from conversion result", function()
      local report = Report.from_conversion(
        { path = "test.json" },
        { passages = 10 },
        { success = true, errors = {}, warnings = {} }
      )

      assert.are.equal("test.json", report.source_info.path)
      assert.are.equal(10, report.conversion_stats.passages)
      assert.is_true(report.validation_result.success)
    end)

    it("should include default feature support", function()
      local report = Report.from_conversion({}, {}, { success = true, errors = {}, warnings = {} })

      assert.is_true(#report.feature_support > 0)

      -- Check some features are included
      local has_knots = false
      local has_threads = false
      for _, f in ipairs(report.feature_support) do
        if f.feature == "Knots" then has_knots = true end
        if f.feature == "Threads" then has_threads = true end
      end
      assert.is_true(has_knots)
      assert.is_true(has_threads)
    end)
  end)
end)
