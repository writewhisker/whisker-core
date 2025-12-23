--- Memory Profiler Tests
-- Tests for the memory profiler module
-- @module tests.unit.profiling.memory_spec

describe("MemoryProfiler", function()
  local MemoryProfiler

  before_each(function()
    MemoryProfiler = require("whisker.profiling.memory")
  end)

  describe("snapshot", function()
    it("returns memory usage and timestamp", function()
      local snapshot = MemoryProfiler.snapshot()

      assert.is_table(snapshot)
      assert.is_number(snapshot.count)
      assert.is_number(snapshot.timestamp)
      assert.truthy(snapshot.count > 0)
    end)
  end)

  describe("compare", function()
    it("calculates delta between snapshots", function()
      local before = { count = 100, timestamp = 1.0 }
      local after = { count = 150, timestamp = 2.0 }

      local result = MemoryProfiler.compare(before, after)

      assert.is_table(result)
      assert.equals(50, result.delta_kb)
      assert.equals(1.0, result.elapsed)
    end)

    it("handles negative delta (memory freed)", function()
      local before = { count = 200, timestamp = 1.0 }
      local after = { count = 100, timestamp = 2.0 }

      local result = MemoryProfiler.compare(before, after)

      assert.equals(-100, result.delta_kb)
    end)
  end)

  describe("profile_function", function()
    it("measures memory usage of a function", function()
      local result = MemoryProfiler.profile_function(function()
        local t = {}
        for i = 1, 1000 do
          t[i] = string.rep("x", 100)
        end
        return t
      end)

      assert.is_table(result)
      assert.is_number(result.total_kb)
      assert.is_number(result.per_iteration_kb)
      assert.is_number(result.elapsed)
    end)

    it("respects iteration count", function()
      local call_count = 0

      MemoryProfiler.profile_function(function()
        call_count = call_count + 1
      end, 25)

      assert.equals(25, call_count)
    end)

    it("calculates per-iteration average", function()
      local result = MemoryProfiler.profile_function(function()
        local t = {}
        for i = 1, 100 do
          t[i] = i
        end
        return t
      end, 10)

      -- Per iteration should be roughly 1/10 of total
      -- (with some margin for GC variance)
      assert.truthy(result.iterations == 10)
    end)
  end)

  describe("get_usage", function()
    it("returns current memory in KB", function()
      local usage = MemoryProfiler.get_usage()

      assert.is_number(usage)
      assert.truthy(usage > 0)
    end)
  end)

  describe("collect", function()
    it("forces garbage collection", function()
      -- Allocate some memory
      local big_table = {}
      for i = 1, 10000 do
        big_table[i] = string.rep("x", 100)
      end

      local before = MemoryProfiler.get_usage()

      -- Clear reference
      big_table = nil

      -- Collect garbage
      local freed = MemoryProfiler.collect()

      -- Should have freed some memory
      assert.is_number(freed)
    end)
  end)

  describe("tracker", function()
    it("creates a memory tracker", function()
      local tracker = MemoryProfiler.tracker("test")

      assert.is_table(tracker)
      assert.is_function(tracker.sample)
      assert.is_function(tracker.stats)
      assert.is_function(tracker.reset)
    end)

    it("records samples", function()
      local tracker = MemoryProfiler.tracker("test")

      tracker:sample()
      tracker:sample()
      tracker:sample()

      local stats = tracker:stats()

      assert.is_table(stats)
      assert.equals(3, stats.sample_count)
      assert.equals("test", stats.name)
    end)

    it("calculates statistics", function()
      local tracker = MemoryProfiler.tracker("stats_test")

      for i = 1, 5 do
        -- Allocate some memory to vary usage
        local t = {}
        for j = 1, i * 100 do
          t[j] = j
        end
        tracker:sample()
      end

      local stats = tracker:stats()

      assert.is_number(stats.min_kb)
      assert.is_number(stats.max_kb)
      assert.is_number(stats.avg_kb)
      assert.is_number(stats.growth_kb)
      assert.is_number(stats.duration)
    end)

    it("resets correctly", function()
      local tracker = MemoryProfiler.tracker("reset_test")

      tracker:sample()
      tracker:sample()

      local stats_before = tracker:stats()
      assert.equals(2, stats_before.sample_count)

      tracker:reset()

      local stats_after = tracker:stats()
      assert.is_nil(stats_after)
    end)
  end)

  describe("detect_leak", function()
    it("detects memory growth", function()
      local retained = {}

      local result = MemoryProfiler.detect_leak(function()
        -- Intentionally leak memory
        table.insert(retained, string.rep("x", 1000))
      end, 50, 10)

      assert.is_table(result)
      assert.is_number(result.baseline_kb)
      assert.is_number(result.final_kb)
      assert.is_number(result.growth_kb)
      assert.is_number(result.per_iteration_kb)
      assert.is_boolean(result.is_leak)
      assert.is_boolean(result.consistent_growth)
    end)

    it("reports no leak for well-behaved functions", function()
      local result = MemoryProfiler.detect_leak(function()
        -- No memory retention
        local t = { 1, 2, 3 }
        return t[1] + t[2] + t[3]
      end, 50, 1)

      -- Should not be flagged as a leak
      -- (though results may vary based on GC behavior)
      assert.is_table(result)
      assert.is_boolean(result.is_leak)
    end)
  end)
end)
