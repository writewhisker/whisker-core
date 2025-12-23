--- Report Generator Tests
-- Tests for the report formatter module
-- @module tests.unit.profiling.report_spec

describe("Report", function()
  local Report

  before_each(function()
    Report = require("whisker.profiling.report")
  end)

  describe("format_profiler_report", function()
    it("formats profiler results", function()
      local report = {
        { location = "test.lua:func1", count = 100, total_time = 0.5, avg_time = 0.005 },
        { location = "test.lua:func2", count = 50, total_time = 0.25, avg_time = 0.005 },
      }

      local formatted = Report.format_profiler_report(report)

      assert.is_string(formatted)
      assert.truthy(formatted:match("Profiling Report"))
      assert.truthy(formatted:match("func1"))
      assert.truthy(formatted:match("func2"))
      assert.truthy(formatted:match("100"))
    end)

    it("respects top_n option", function()
      local report = {}
      for i = 1, 50 do
        table.insert(report, {
          location = "test.lua:func" .. i,
          count = 10,
          total_time = 0.01,
          avg_time = 0.001,
        })
      end

      local formatted = Report.format_profiler_report(report, { top_n = 5 })

      -- Should mention that more functions exist
      assert.truthy(formatted:match("and %d+ more functions"))
    end)

    it("truncates long location names", function()
      local report = {
        {
          location = "very/long/path/to/some/deeply/nested/module/file.lua:some_very_long_function_name",
          count = 10,
          total_time = 0.1,
          avg_time = 0.01,
        },
      }

      local formatted = Report.format_profiler_report(report)

      -- Should not exceed reasonable line width
      for line in formatted:gmatch("[^\n]+") do
        assert.truthy(#line <= 100, "Line too long: " .. #line)
      end
    end)
  end)

  describe("format_memory_report", function()
    it("formats memory profiling results", function()
      local result = {
        total_kb = 256.5,
        per_iteration_kb = 2.565,
        elapsed = 1.234,
        iterations = 100,
      }

      local formatted = Report.format_memory_report(result)

      assert.is_string(formatted)
      assert.truthy(formatted:match("Memory Profiling"))
      assert.truthy(formatted:match("256%.50"))
      assert.truthy(formatted:match("2%.56"))
    end)
  end)

  describe("format_tracker_stats", function()
    it("formats tracker statistics", function()
      local stats = {
        name = "test_tracker",
        sample_count = 10,
        min_kb = 100,
        max_kb = 200,
        avg_kb = 150,
        growth_kb = 100,
        duration = 5.5,
      }

      local formatted = Report.format_tracker_stats(stats)

      assert.is_string(formatted)
      assert.truthy(formatted:match("test_tracker"))
      assert.truthy(formatted:match("10"))
      assert.truthy(formatted:match("100"))
      assert.truthy(formatted:match("200"))
    end)

    it("handles nil stats", function()
      local formatted = Report.format_tracker_stats(nil)

      assert.equals("No samples recorded", formatted)
    end)
  end)

  describe("format_leak_report", function()
    it("formats leak detection results", function()
      local result = {
        is_leak = true,
        baseline_kb = 1000,
        final_kb = 1500,
        growth_kb = 500,
        per_iteration_kb = 5,
        consistent_growth = true,
      }

      local formatted = Report.format_leak_report(result)

      assert.is_string(formatted)
      assert.truthy(formatted:match("POTENTIAL LEAK DETECTED"))
      assert.truthy(formatted:match("1000"))
      assert.truthy(formatted:match("1500"))
    end)

    it("reports no leak when clean", function()
      local result = {
        is_leak = false,
        baseline_kb = 1000,
        final_kb = 1010,
        growth_kb = 10,
        per_iteration_kb = 0.1,
        consistent_growth = false,
      }

      local formatted = Report.format_leak_report(result)

      assert.truthy(formatted:match("No leak detected"))
    end)
  end)

  describe("format_benchmark_report", function()
    it("formats benchmark results", function()
      local results = {
        { name = "benchmark_1", iterations = 1000, per_iteration = 0.001, memory_kb = 5 },
        { name = "benchmark_2", iterations = 500, per_iteration = 0.002, memory_kb = 10 },
      }

      local formatted = Report.format_benchmark_report(results)

      assert.is_string(formatted)
      assert.truthy(formatted:match("Benchmark Results"))
      assert.truthy(formatted:match("benchmark_1"))
      assert.truthy(formatted:match("benchmark_2"))
      assert.truthy(formatted:match("1000"))
    end)

    it("accepts custom title", function()
      local formatted = Report.format_benchmark_report({}, { title = "Custom Title" })

      assert.truthy(formatted:match("Custom Title"))
    end)
  end)

  describe("to_json", function()
    it("serializes to JSON format", function()
      local data = {
        name = "test",
        count = 42,
        active = true,
      }

      local json = Report.to_json(data)

      assert.is_string(json)
      assert.truthy(json:match('"name"'))
      assert.truthy(json:match('"test"'))
      assert.truthy(json:match('"count"'))
      assert.truthy(json:match("42"))
    end)

    it("handles arrays", function()
      local data = { 1, 2, 3, 4, 5 }

      local json = Report.to_json(data)

      assert.truthy(json:match("%["))
      assert.truthy(json:match("%]"))
    end)

    it("escapes special characters", function()
      local data = { text = 'Hello "world"\nNew line' }

      local json = Report.to_json(data)

      assert.truthy(json:match('\\"'))
      assert.truthy(json:match('\\n'))
    end)
  end)

  describe("save", function()
    it("saves content to file", function()
      local test_file = "/tmp/test_report_" .. os.time() .. ".txt"
      local content = "Test report content"

      local success = Report.save(content, test_file)
      assert.is_true(success)

      -- Verify content
      local file = io.open(test_file, "r")
      if file then
        local saved = file:read("*all")
        file:close()
        assert.equals(content, saved)

        -- Cleanup
        os.remove(test_file)
      end
    end)

    it("returns false for invalid path", function()
      local success = Report.save("test", "/nonexistent/path/file.txt")
      assert.is_false(success)
    end)
  end)
end)
