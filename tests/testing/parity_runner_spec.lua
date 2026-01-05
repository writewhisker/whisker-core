--- Parity Runner Tests
-- Unit tests for the ParityRunner class
-- @module tests.testing.parity_runner_spec

local helper = require("tests.test_helper")
local ParityRunner = require("whisker.testing.parity_runner")

describe("ParityRunner", function()
  describe("new", function()
    it("should create a runner with default options", function()
      local runner = ParityRunner.new()
      assert.is_not_nil(runner)
    end)

    it("should accept tolerance option", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.LENIENT })
      assert.equals(ParityRunner.TOLERANCE.LENIENT, runner._tolerance)
    end)

    it("should accept numeric_epsilon option", function()
      local runner = ParityRunner.new({ numeric_epsilon = 0.01 })
      assert.equals(0.01, runner._numeric_epsilon)
    end)

    it("should accept ignore_fields option", function()
      local runner = ParityRunner.new({ ignore_fields = { "time", "date" } })
      assert.same({ "time", "date" }, runner._ignore_fields)
    end)
  end)

  describe("_compare_values", function()
    it("should match identical strings", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values("hello", "hello", "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should detect string mismatch", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values("hello", "world", "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)

    it("should match identical numbers", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(42, 42, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should detect number mismatch", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(42, 43, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)

    it("should match identical booleans", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(true, true, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should detect boolean mismatch", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(true, false, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)

    it("should detect type mismatch", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values("42", 42, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.TYPE_MISMATCH, result.type)
    end)

    it("should detect missing lua value", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(nil, "value", "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MISSING_LUA, result.type)
    end)

    it("should detect missing reference value", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values("value", nil, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MISSING_REF, result.type)
    end)

    it("should match both nil values", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_values(nil, nil, "test")
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)
  end)

  describe("_compare_numbers", function()
    it("should match exact numbers in strict mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.STRICT })
      assert.is_true(runner:_compare_numbers(1.0, 1.0))
    end)

    it("should not match different numbers in strict mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.STRICT })
      assert.is_false(runner:_compare_numbers(1.0, 1.0001))
    end)

    it("should match within epsilon in lenient mode", function()
      local runner = ParityRunner.new({
        tolerance = ParityRunner.TOLERANCE.LENIENT,
        numeric_epsilon = 0.001,
      })
      assert.is_true(runner:_compare_numbers(1.0, 1.0005))
    end)

    it("should not match beyond epsilon", function()
      local runner = ParityRunner.new({
        tolerance = ParityRunner.TOLERANCE.LENIENT,
        numeric_epsilon = 0.001,
      })
      assert.is_false(runner:_compare_numbers(1.0, 1.01))
    end)
  end)

  describe("_compare_strings", function()
    it("should match exact strings in strict mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.STRICT })
      assert.is_true(runner:_compare_strings("Hello World", "Hello World"))
    end)

    it("should not match case differences in strict mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.STRICT })
      assert.is_false(runner:_compare_strings("Hello", "hello"))
    end)

    it("should match case differences in lenient mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.LENIENT })
      assert.is_true(runner:_compare_strings("Hello", "hello"))
    end)

    it("should normalize whitespace in lenient mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.LENIENT })
      assert.is_true(runner:_compare_strings("hello  world", "hello world"))
    end)

    it("should trim whitespace in lenient mode", function()
      local runner = ParityRunner.new({ tolerance = ParityRunner.TOLERANCE.LENIENT })
      assert.is_true(runner:_compare_strings("  hello  ", "hello"))
    end)
  end)

  describe("_compare_tables", function()
    it("should match identical tables", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { a = 1, b = 2 },
        { a = 1, b = 2 },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should detect different values", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { a = 1 },
        { a = 2 },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)

    it("should detect missing keys", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { a = 1 },
        { a = 1, b = 2 },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)

    it("should match nested tables", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { a = { b = 1 } },
        { a = { b = 1 } },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should match arrays", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { 1, 2, 3 },
        { 1, 2, 3 },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should detect array differences", function()
      local runner = ParityRunner.new()
      local result = runner:_compare_tables(
        { 1, 2, 3 },
        { 1, 2, 4 },
        "test"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)
  end)

  describe("ignore_fields", function()
    it("should ignore specified fields", function()
      local runner = ParityRunner.new({ ignore_fields = { "timestamp" } })
      local result = runner:_compare_values(
        { name = "test", timestamp = 12345 },
        { name = "test", timestamp = 99999 },
        "root"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MATCH, result.type)
    end)

    it("should compare non-ignored fields", function()
      local runner = ParityRunner.new({ ignore_fields = { "timestamp" } })
      local result = runner:_compare_values(
        { name = "test1", timestamp = 12345 },
        { name = "test2", timestamp = 12345 },
        "root"
      )
      assert.equals(ParityRunner.COMPARISON_TYPES.MISMATCH, result.type)
    end)
  end)

  describe("compare_results", function()
    it("should compare test results", function()
      local runner = ParityRunner.new()

      local lua_result = {
        scenario_id = "test-1",
        scenario_name = "Test 1",
        passed = true,
        passed_steps = 2,
        failed_steps = 0,
      }

      local ref_result = {
        scenario_id = "test-1",
        scenario_name = "Test 1",
        passed = true,
        passed_steps = 2,
        failed_steps = 0,
      }

      local comparison = runner:compare_results(lua_result, ref_result)

      assert.is_true(comparison.passed)
      assert.equals("test-1", comparison.scenario_id)
    end)

    it("should detect result differences", function()
      local runner = ParityRunner.new()

      local lua_result = {
        scenario_id = "test-1",
        passed = true,
      }

      local ref_result = {
        scenario_id = "test-1",
        passed = false,
      }

      local comparison = runner:compare_results(lua_result, ref_result)

      assert.is_false(comparison.passed)
      assert.is_true(comparison.difference_count > 0)
    end)
  end)

  describe("compare_all", function()
    it("should compare multiple scenarios", function()
      local runner = ParityRunner.new()

      local lua_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = true },
      }

      local ref_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = true },
      }

      local summary = runner:compare_all(lua_results, ref_results)

      assert.equals(2, summary.total)
      assert.equals(2, summary.matched)
      assert.equals(0, summary.mismatched)
      assert.is_true(summary.passed)
      assert.equals(100, summary.parity_score)
    end)

    it("should detect missing reference results", function()
      local runner = ParityRunner.new()

      local lua_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = true },
      }

      local ref_results = {
        { scenario_id = "s1", passed = true },
      }

      local summary = runner:compare_all(lua_results, ref_results)

      assert.equals(2, summary.total)
      assert.equals(1, summary.matched)
      assert.equals(1, summary.missing_ref)
      assert.is_false(summary.passed)
    end)

    it("should detect missing lua results", function()
      local runner = ParityRunner.new()

      local lua_results = {
        { scenario_id = "s1", passed = true },
      }

      local ref_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = true },
      }

      local summary = runner:compare_all(lua_results, ref_results)

      assert.equals(2, summary.total)
      assert.equals(1, summary.matched)
      assert.equals(1, summary.missing_lua)
      assert.is_false(summary.passed)
    end)

    it("should calculate parity score", function()
      local runner = ParityRunner.new()

      local lua_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = false },
        { scenario_id = "s3", passed = true },
        { scenario_id = "s4", passed = true },
      }

      local ref_results = {
        { scenario_id = "s1", passed = true },
        { scenario_id = "s2", passed = true }, -- mismatch
        { scenario_id = "s3", passed = true },
        { scenario_id = "s4", passed = true },
      }

      local summary = runner:compare_all(lua_results, ref_results)

      assert.equals(4, summary.total)
      assert.equals(3, summary.matched)
      assert.equals(1, summary.mismatched)
      assert.equals(75, summary.parity_score)
    end)
  end)

  describe("COMPARISON_TYPES", function()
    it("should export comparison type constants", function()
      assert.equals("match", ParityRunner.COMPARISON_TYPES.MATCH)
      assert.equals("mismatch", ParityRunner.COMPARISON_TYPES.MISMATCH)
      assert.equals("missing_lua", ParityRunner.COMPARISON_TYPES.MISSING_LUA)
      assert.equals("missing_ref", ParityRunner.COMPARISON_TYPES.MISSING_REF)
      assert.equals("type_mismatch", ParityRunner.COMPARISON_TYPES.TYPE_MISMATCH)
    end)
  end)

  describe("TOLERANCE", function()
    it("should export tolerance constants", function()
      assert.equals("strict", ParityRunner.TOLERANCE.STRICT)
      assert.equals("lenient", ParityRunner.TOLERANCE.LENIENT)
      assert.equals("numeric", ParityRunner.TOLERANCE.NUMERIC)
    end)
  end)
end)
