--- Profiler Tests
-- Tests for the code profiler module
-- @module tests.unit.profiling.profiler_spec

describe("Profiler", function()
  local Profiler

  before_each(function()
    Profiler = require("whisker.profiling.profiler")
  end)

  describe("new", function()
    it("creates a new profiler instance", function()
      local profiler = Profiler.new()
      assert.is_table(profiler)
      assert.is_false(profiler:is_active())
    end)
  end)

  describe("start/stop", function()
    it("activates and deactivates profiling", function()
      local profiler = Profiler.new()

      profiler:start()
      assert.is_true(profiler:is_active())

      local report = profiler:stop()
      assert.is_false(profiler:is_active())
      assert.is_table(report)
    end)

    it("returns a report on stop", function()
      local profiler = Profiler.new()

      profiler:start()

      -- Do some work
      local function test_func()
        local sum = 0
        for i = 1, 100 do
          sum = sum + i
        end
        return sum
      end

      for i = 1, 10 do
        test_func()
      end

      local report = profiler:stop()

      assert.is_table(report)
      -- Should have captured some function calls
      assert.truthy(#report > 0)
    end)
  end)

  describe("get_report", function()
    it("returns entries with location, count, total_time, avg_time", function()
      local profiler = Profiler.new()

      profiler:start()

      local function work()
        local t = {}
        for i = 1, 50 do
          t[i] = i * 2
        end
        return t
      end

      for i = 1, 5 do
        work()
      end

      local report = profiler:stop()

      -- Find our function in the report
      for _, entry in ipairs(report) do
        assert.is_string(entry.location)
        assert.is_number(entry.count)
        assert.is_number(entry.total_time)
        assert.is_number(entry.avg_time)
      end
    end)

    it("sorts by total time descending", function()
      local profiler = Profiler.new()

      profiler:start()

      local function fast() return 1 end
      local function slow()
        local t = {}
        for i = 1, 1000 do
          t[i] = i
        end
        return t
      end

      for i = 1, 100 do
        fast()
        if i % 10 == 0 then
          slow()
        end
      end

      local report = profiler:stop()

      -- Check sorted order
      for i = 2, #report do
        assert.truthy(report[i-1].total_time >= report[i].total_time)
      end
    end)
  end)

  describe("profile_function", function()
    it("profiles a single function", function()
      local result = Profiler.profile_function(function()
        local sum = 0
        for i = 1, 1000 do
          sum = sum + i
        end
        return sum
      end, 10)

      assert.is_table(result)
      assert.is_number(result.elapsed)
      assert.is_number(result.per_iteration)
      assert.is_table(result.report)
    end)

    it("respects iteration count", function()
      local call_count = 0

      Profiler.profile_function(function()
        call_count = call_count + 1
      end, 50)

      assert.equals(50, call_count)
    end)
  end)

  describe("reset", function()
    it("clears profiler data", function()
      local profiler = Profiler.new()

      profiler:start()
      local function test() end
      for i = 1, 10 do test() end
      profiler:stop()

      local report_before = profiler:get_report()
      assert.truthy(#report_before > 0)

      profiler:reset()

      local report_after = profiler:get_report()
      assert.equals(0, #report_after)
    end)
  end)

  describe("get_elapsed_time", function()
    it("returns time since start", function()
      local profiler = Profiler.new()

      profiler:start()

      -- Do some work
      local sum = 0
      for i = 1, 100000 do
        sum = sum + i
      end

      local elapsed = profiler:get_elapsed_time()
      profiler:stop()

      assert.is_number(elapsed)
      assert.truthy(elapsed > 0)
    end)
  end)
end)
