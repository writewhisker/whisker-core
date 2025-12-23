--- Benchmark Suite Tests
-- Tests for the benchmark framework
-- @module tests.unit.benchmarks.suite_spec

describe("BenchmarkSuite", function()
  local BenchmarkSuite

  before_each(function()
    BenchmarkSuite = require("whisker.benchmarks.suite")
  end)

  describe("new", function()
    it("creates a new suite", function()
      local suite = BenchmarkSuite.new("Test Suite")
      assert.is_table(suite)
    end)

    it("uses default name if not provided", function()
      local suite = BenchmarkSuite.new()
      assert.is_table(suite)
    end)
  end)

  describe("register", function()
    it("registers a benchmark", function()
      local suite = BenchmarkSuite.new()

      suite:register("test", function() end)

      assert.equals(1, suite:count())
    end)

    it("accepts options", function()
      local suite = BenchmarkSuite.new()

      suite:register("test", function() end, {
        iterations = 500,
        warmup = 5,
      })

      assert.equals(1, suite:count())
    end)
  end)

  describe("run", function()
    it("runs all registered benchmarks", function()
      local suite = BenchmarkSuite.new("Test")
      local run_count = 0

      suite:register("bench1", function()
        run_count = run_count + 1
      end, { iterations = 10, warmup = 1 })

      suite:run()

      -- Should run warmup (1) + iterations (10)
      assert.truthy(run_count >= 10)
    end)

    it("respects filter", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("include_me", function() end, { iterations = 10 })
      suite:register("skip_this", function() end, { iterations = 10 })

      suite:run("include")

      local results = suite:get_results()
      assert.equals(1, #results)
      assert.equals("include_me", results[1].name)
    end)

    it("returns report", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("test", function()
        local sum = 0
        for i = 1, 100 do sum = sum + i end
      end, { iterations = 100, warmup = 1 })

      local report = suite:run()

      assert.is_string(report)
      assert.truthy(report:match("test"))
    end)
  end)

  describe("get_results", function()
    it("returns array of results", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("bench1", function() end, { iterations = 10 })
      suite:register("bench2", function() end, { iterations = 10 })

      suite:run()

      local results = suite:get_results()
      assert.equals(2, #results)
    end)

    it("includes timing information", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("bench", function()
        local t = {}
        for i = 1, 100 do t[i] = i end
      end, { iterations = 100 })

      suite:run()

      local results = suite:get_results()
      assert.equals(1, #results)
      assert.is_number(results[1].elapsed)
      assert.is_number(results[1].per_iteration)
      assert.is_number(results[1].iterations)
      assert.truthy(results[1].per_iteration > 0)
    end)
  end)

  describe("baseline comparison", function()
    it("accepts baseline data", function()
      local suite = BenchmarkSuite.new("Test")

      local baseline = {
        { name = "bench1", per_iteration = 0.001 },
      }

      suite:set_baseline(baseline)
      -- No error means success
    end)

    it("compares to baseline", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("bench1", function()
        local sum = 0
        for i = 1, 50 do sum = sum + i end
      end, { iterations = 100 })

      -- Set baseline with known value
      suite:set_baseline({
        { name = "bench1", per_iteration = 0.0001 },
      })

      suite:run()

      local comparison = suite:compare_to_baseline()

      assert.is_table(comparison)
      assert.truthy(#comparison > 0)
      assert.equals("bench1", comparison[1].name)
      assert.is_number(comparison[1].ratio)
    end)
  end)

  describe("save_results", function()
    it("saves results to file", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("bench1", function() end, { iterations = 10 })
      suite:run()

      local path = "/tmp/test_benchmark_" .. os.time() .. ".lua"
      local success = suite:save_results(path)

      assert.is_true(success)

      -- Verify file exists and is valid Lua
      local chunk = loadfile(path)
      assert.is_function(chunk)

      local data = chunk()
      assert.is_table(data)

      -- Cleanup
      os.remove(path)
    end)
  end)

  describe("load_baseline", function()
    it("loads baseline from file", function()
      local suite = BenchmarkSuite.new("Test")

      -- Create baseline file
      local path = "/tmp/test_baseline_" .. os.time() .. ".lua"
      local file = io.open(path, "w")
      file:write('return {{ name = "bench1", per_iteration = 0.001 }}')
      file:close()

      local success = suite:load_baseline(path)
      assert.is_true(success)

      -- Cleanup
      os.remove(path)
    end)

    it("returns false for missing file", function()
      local suite = BenchmarkSuite.new("Test")

      local success = suite:load_baseline("/nonexistent/file.lua")
      assert.is_false(success)
    end)
  end)

  describe("clear", function()
    it("removes all benchmarks", function()
      local suite = BenchmarkSuite.new("Test")

      suite:register("bench1", function() end)
      suite:register("bench2", function() end)
      assert.equals(2, suite:count())

      suite:clear()
      assert.equals(0, suite:count())
    end)
  end)
end)
