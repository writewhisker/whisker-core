--- Test Reporter Tests
-- Unit tests for the TestReporter class
-- @module tests.testing.test_reporter_spec

local helper = require("tests.test_helper")
local TestReporter = require("whisker.testing.test_reporter")

describe("TestReporter", function()
  local function create_summary(passed, failed)
    local results = {}
    for i = 1, passed do
      table.insert(results, {
        scenario_id = "pass-" .. i,
        scenario_name = "Passing Test " .. i,
        passed = true,
        duration = 10,
        total_steps = 2,
        passed_steps = 2,
        failed_steps = 0,
        step_results = {
          { step_index = 1, passed = true, message = "Started" },
          { step_index = 2, passed = true, message = "Completed" },
        },
      })
    end
    for i = 1, failed do
      table.insert(results, {
        scenario_id = "fail-" .. i,
        scenario_name = "Failing Test " .. i,
        passed = false,
        duration = 5,
        total_steps = 2,
        passed_steps = 1,
        failed_steps = 1,
        step_results = {
          { step_index = 1, passed = true, message = "Started" },
          { step_index = 2, passed = false, message = "Expected 100, got 0" },
        },
      })
    end

    return {
      total = passed + failed,
      passed = passed,
      failed = failed,
      duration = (passed + failed) * 10,
      success = failed == 0,
      results = results,
    }
  end

  describe("new", function()
    it("should create a reporter with default options", function()
      local reporter = TestReporter.new()

      assert.is_not_nil(reporter)
    end)

    it("should accept format option", function()
      local reporter = TestReporter.new({ format = "json" })

      assert.equals("json", reporter._format)
    end)

    it("should accept verbose option", function()
      local reporter = TestReporter.new({ verbose = true })

      assert.is_true(reporter._verbose)
    end)

    it("should accept colors option", function()
      local reporter = TestReporter.new({ colors = false })

      assert.is_false(reporter._colors)
    end)
  end)

  describe("format_text", function()
    it("should include test results", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(2, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Passing Test 1"))
      assert.truthy(output:find("Passing Test 2"))
    end)

    it("should include PASS status for passing tests", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(1, 0)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("PASS"))
    end)

    it("should include FAIL status for failing tests", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(0, 1)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("FAIL"))
    end)

    it("should show failed step info", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(0, 1)

      local output = reporter:format_text(summary)

      assert.truthy(output:find("Expected 100"))
    end)
  end)

  describe("format_summary_text", function()
    it("should include total count", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(3, 2)

      local output = reporter:format_summary_text(summary)

      assert.truthy(output:find("Total:%s+5"))
    end)

    it("should include passed count", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(3, 2)

      local output = reporter:format_summary_text(summary)

      assert.truthy(output:find("Passed:%s+3"))
    end)

    it("should include failed count", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(3, 2)

      local output = reporter:format_summary_text(summary)

      assert.truthy(output:find("Failed:%s+2"))
    end)

    it("should show ALL PASSED for success", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(5, 0)

      local output = reporter:format_summary_text(summary)

      assert.truthy(output:find("ALL PASSED"))
    end)

    it("should show SOME FAILED for failures", function()
      local reporter = TestReporter.new({ colors = false })
      local summary = create_summary(3, 2)

      local output = reporter:format_summary_text(summary)

      assert.truthy(output:find("SOME FAILED"))
    end)
  end)

  describe("format_json", function()
    it("should produce valid JSON structure", function()
      local reporter = TestReporter.new({ format = "json" })
      local summary = create_summary(1, 1)

      local output = reporter:format_json(summary)

      assert.truthy(output:find('"total"'))
      assert.truthy(output:find('"passed"'))
      assert.truthy(output:find('"failed"'))
      assert.truthy(output:find('"results"'))
    end)

    it("should escape special characters", function()
      local reporter = TestReporter.new({ format = "json" })
      local summary = {
        total = 1,
        passed = 1,
        failed = 0,
        success = true,
        results = {
          {
            scenario_name = 'Test with "quotes" and \\slashes',
            passed = true,
          },
        },
      }

      local output = reporter:format_json(summary)

      assert.truthy(output:find('\\"quotes\\"'))
      assert.truthy(output:find('\\\\slashes'))
    end)
  end)

  describe("format_tap", function()
    it("should include TAP version", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(2, 0)

      local output = reporter:format_tap(summary)

      assert.truthy(output:find("TAP version 13"))
    end)

    it("should include plan line", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(3, 0)

      local output = reporter:format_tap(summary)

      assert.truthy(output:find("1..3"))
    end)

    it("should show ok for passing tests", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(1, 0)

      local output = reporter:format_tap(summary)

      assert.truthy(output:find("ok 1"))
    end)

    it("should show not ok for failing tests", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(0, 1)

      local output = reporter:format_tap(summary)

      assert.truthy(output:find("not ok 1"))
    end)

    it("should include diagnostic info for failures", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(0, 1)

      local output = reporter:format_tap(summary)

      assert.truthy(output:find("message:"))
    end)
  end)

  describe("format_junit", function()
    it("should include XML declaration", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = create_summary(1, 0)

      local output = reporter:format_junit(summary)

      assert.truthy(output:find('<?xml version="1.0"'))
    end)

    it("should include testsuite element", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = create_summary(2, 1)

      local output = reporter:format_junit(summary)

      assert.truthy(output:find('<testsuite'))
      assert.truthy(output:find('tests="3"'))
      assert.truthy(output:find('failures="1"'))
    end)

    it("should include testcase elements", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = create_summary(1, 0)

      local output = reporter:format_junit(summary)

      assert.truthy(output:find('<testcase'))
      assert.truthy(output:find('name="Passing Test 1"'))
    end)

    it("should include failure element for failed tests", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = create_summary(0, 1)

      local output = reporter:format_junit(summary)

      assert.truthy(output:find('<failure'))
    end)

    it("should escape XML special characters", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = {
        total = 1,
        passed = 0,
        failed = 1,
        success = false,
        results = {
          {
            scenario_name = "Test <with> & special",
            passed = false,
            step_results = {
              { passed = false, message = "Error: value < expected" },
            },
          },
        },
      }

      local output = reporter:format_junit(summary)

      assert.truthy(output:find("&lt;with&gt;"))
      assert.truthy(output:find("&amp;"))
    end)
  end)

  describe("format", function()
    it("should use text format by default", function()
      local reporter = TestReporter.new()
      local summary = create_summary(1, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("Running Tests"))
    end)

    it("should use json format when specified", function()
      local reporter = TestReporter.new({ format = "json" })
      local summary = create_summary(1, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find('"total"'))
    end)

    it("should use tap format when specified", function()
      local reporter = TestReporter.new({ format = "tap" })
      local summary = create_summary(1, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("TAP version"))
    end)

    it("should use junit format when specified", function()
      local reporter = TestReporter.new({ format = "junit" })
      local summary = create_summary(1, 0)

      local output = reporter:format(summary)

      assert.truthy(output:find("<?xml"))
    end)
  end)

  describe("report", function()
    it("should call output function if provided", function()
      local captured = nil
      local reporter = TestReporter.new({
        output = function(text)
          captured = text
        end,
      })
      local summary = create_summary(1, 0)

      reporter:report(summary)

      assert.is_not_nil(captured)
      assert.truthy(captured:find("Running Tests"))
    end)

    it("should return formatted output", function()
      local reporter = TestReporter.new({
        output = function() end, -- suppress print
      })
      local summary = create_summary(1, 0)

      local output = reporter:report(summary)

      assert.is_string(output)
    end)
  end)

  describe("FORMATS constant", function()
    it("should export format constants", function()
      assert.equals("text", TestReporter.FORMATS.TEXT)
      assert.equals("json", TestReporter.FORMATS.JSON)
      assert.equals("tap", TestReporter.FORMATS.TAP)
      assert.equals("junit", TestReporter.FORMATS.JUNIT)
    end)
  end)
end)
