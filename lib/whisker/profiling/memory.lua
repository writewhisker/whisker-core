--- Memory Profiler
-- Tools for measuring and tracking Lua memory usage
-- @module whisker.profiling.memory
-- @author Whisker Core Team
-- @license MIT

local MemoryProfiler = {}

--- Take a memory snapshot
-- @return table Snapshot with count and timestamp
function MemoryProfiler.snapshot()
  collectgarbage("collect")
  return {
    count = collectgarbage("count"),
    timestamp = os.clock(),
  }
end

--- Compare two snapshots
-- @param before table Before snapshot
-- @param after table After snapshot
-- @return table Comparison with delta_kb and elapsed
function MemoryProfiler.compare(before, after)
  return {
    delta_kb = after.count - before.count,
    elapsed = after.timestamp - before.timestamp,
  }
end

--- Profile memory usage of a function
-- @param fn function Function to profile
-- @param iterations number Number of iterations (default 1)
-- @return table Result with total_kb, per_iteration_kb, elapsed
function MemoryProfiler.profile_function(fn, iterations)
  iterations = iterations or 1

  -- Force full GC before measuring
  collectgarbage("collect")
  collectgarbage("collect")

  local before = MemoryProfiler.snapshot()

  for i = 1, iterations do
    fn()
  end

  local after = MemoryProfiler.snapshot()
  local diff = MemoryProfiler.compare(before, after)

  return {
    total_kb = diff.delta_kb,
    per_iteration_kb = diff.delta_kb / iterations,
    elapsed = diff.elapsed,
    iterations = iterations,
  }
end

--- Get current memory usage
-- @return number Memory in KB
function MemoryProfiler.get_usage()
  return collectgarbage("count")
end

--- Force garbage collection and get freed memory
-- @return number KB freed
function MemoryProfiler.collect()
  local before = collectgarbage("count")
  collectgarbage("collect")
  local after = collectgarbage("count")
  return before - after
end

--- Track memory over multiple calls
-- @param name string Name for the tracking session
-- @return table Tracker object
function MemoryProfiler.tracker(name)
  local tracker = {
    name = name,
    samples = {},
    start_time = os.clock(),
  }

  --- Record a sample
  function tracker:sample()
    table.insert(self.samples, {
      memory_kb = collectgarbage("count"),
      time = os.clock() - self.start_time,
    })
  end

  --- Get statistics
  function tracker:stats()
    if #self.samples == 0 then
      return nil
    end

    local min_mem = math.huge
    local max_mem = 0
    local total_mem = 0

    for _, sample in ipairs(self.samples) do
      min_mem = math.min(min_mem, sample.memory_kb)
      max_mem = math.max(max_mem, sample.memory_kb)
      total_mem = total_mem + sample.memory_kb
    end

    return {
      name = self.name,
      sample_count = #self.samples,
      min_kb = min_mem,
      max_kb = max_mem,
      avg_kb = total_mem / #self.samples,
      growth_kb = self.samples[#self.samples].memory_kb - self.samples[1].memory_kb,
      duration = os.clock() - self.start_time,
    }
  end

  --- Clear samples
  function tracker:reset()
    self.samples = {}
    self.start_time = os.clock()
  end

  return tracker
end

--- Detect potential memory leaks by monitoring growth
-- @param fn function Function to test
-- @param iterations number Number of iterations (default 100)
-- @param threshold_kb number Growth threshold for leak warning (default 1)
-- @return table Result with is_leak and details
function MemoryProfiler.detect_leak(fn, iterations, threshold_kb)
  iterations = iterations or 100
  threshold_kb = threshold_kb or 1

  -- Warmup
  for i = 1, 10 do
    fn()
  end

  -- Baseline
  collectgarbage("collect")
  collectgarbage("collect")
  local baseline = collectgarbage("count")

  -- Run iterations and sample memory
  local samples = {}
  local sample_interval = math.max(1, iterations / 10)

  for i = 1, iterations do
    fn()

    if i % sample_interval == 0 then
      collectgarbage("collect")
      table.insert(samples, {
        iteration = i,
        memory_kb = collectgarbage("count"),
      })
    end
  end

  -- Final measurement
  collectgarbage("collect")
  collectgarbage("collect")
  local final = collectgarbage("count")

  local growth = final - baseline
  local per_iteration = growth / iterations

  -- Check for consistent growth pattern
  local growing = true
  for i = 2, #samples do
    if samples[i].memory_kb <= samples[i-1].memory_kb then
      growing = false
      break
    end
  end

  return {
    is_leak = growth > threshold_kb and growing,
    baseline_kb = baseline,
    final_kb = final,
    growth_kb = growth,
    per_iteration_kb = per_iteration,
    samples = samples,
    consistent_growth = growing,
  }
end

return MemoryProfiler
