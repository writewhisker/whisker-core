--- Benchmark Suite
-- Framework for running and reporting on performance benchmarks
-- @module whisker.benchmarks.suite
-- @author Whisker Core Team
-- @license MIT

local BenchmarkSuite = {}
BenchmarkSuite._dependencies = {}
BenchmarkSuite.__index = BenchmarkSuite

--- Create a new benchmark suite
-- @param name string Suite name
-- @return BenchmarkSuite A new suite
function BenchmarkSuite.new(name)
  local self = setmetatable({}, BenchmarkSuite)
  self._name = name or "Benchmark Suite"
  self._benchmarks = {}
  self._results = {}
  self._baseline = {}
  return self
end

--- Register a benchmark
-- @param name string Benchmark name
-- @param fn function Function to benchmark
-- @param options table Options (iterations, setup, teardown, warmup)
function BenchmarkSuite:register(name, fn, options)
  options = options or {}

  table.insert(self._benchmarks, {
    name = name,
    fn = fn,
    iterations = options.iterations or 1000,
    setup = options.setup,
    teardown = options.teardown,
    warmup = options.warmup or 10,
    description = options.description,
  })
end

--- Run all benchmarks
-- @param filter string|nil Pattern to filter benchmarks
-- @return string Report
function BenchmarkSuite:run(filter)
  self._results = {}

  print(string.format("\n[%s]", self._name))
  print(string.rep("-", 60))

  for _, benchmark in ipairs(self._benchmarks) do
    if not filter or benchmark.name:match(filter) then
      local result = self:_run_benchmark(benchmark)
      table.insert(self._results, result)

      -- Print progress
      local status = "OK"
      if self._baseline[benchmark.name] then
        local baseline = self._baseline[benchmark.name]
        local ratio = result.per_iteration / baseline.per_iteration
        if ratio > 1.1 then
          status = string.format("SLOWER (%.1fx)", ratio)
        elseif ratio < 0.9 then
          status = string.format("FASTER (%.1fx)", 1/ratio)
        end
      end

      print(string.format("  %-40s %s", benchmark.name, status))
    end
  end

  return self:_generate_report()
end

--- Run a single benchmark
-- @param benchmark table Benchmark definition
-- @return table Result
function BenchmarkSuite:_run_benchmark(benchmark)
  -- Setup
  if benchmark.setup then
    benchmark.setup()
  end

  -- Warmup
  for i = 1, benchmark.warmup do
    benchmark.fn()
  end

  -- Collect garbage before measuring
  collectgarbage("collect")
  collectgarbage("collect")

  -- Measure time
  local start_time = os.clock()
  local start_mem = collectgarbage("count")

  for i = 1, benchmark.iterations do
    benchmark.fn()
  end

  local elapsed = os.clock() - start_time

  -- Measure memory after (with GC)
  collectgarbage("collect")
  local end_mem = collectgarbage("count")
  local mem_delta = end_mem - start_mem

  -- Teardown
  if benchmark.teardown then
    benchmark.teardown()
  end

  return {
    name = benchmark.name,
    iterations = benchmark.iterations,
    elapsed = elapsed,
    per_iteration = elapsed / benchmark.iterations,
    memory_kb = mem_delta,
    description = benchmark.description,
  }
end

--- Generate report from results
-- @return string Report
function BenchmarkSuite:_generate_report()
  local lines = {}
  local width = 85

  table.insert(lines, "")
  table.insert(lines, self._name)
  table.insert(lines, string.rep("=", width))
  table.insert(lines, string.format("%-40s %12s %12s %14s",
    "Benchmark", "Iterations", "Time/Iter", "Memory Delta"))
  table.insert(lines, string.rep("-", width))

  local total_time = 0

  for _, result in ipairs(self._results) do
    local name = result.name
    if #name > 40 then
      name = name:sub(1, 37) .. "..."
    end

    table.insert(lines, string.format("%-40s %12d %12.6f %12.2f KB",
      name,
      result.iterations,
      result.per_iteration,
      result.memory_kb
    ))

    total_time = total_time + result.elapsed
  end

  table.insert(lines, string.rep("-", width))
  table.insert(lines, string.format("Total benchmarks: %d, Total time: %.3f seconds",
    #self._results, total_time))
  table.insert(lines, string.rep("=", width))

  return table.concat(lines, "\n")
end

--- Get results
-- @return table Array of results
function BenchmarkSuite:get_results()
  return self._results
end

--- Set baseline for comparison
-- @param baseline table Previous results to compare against
function BenchmarkSuite:set_baseline(baseline)
  self._baseline = {}
  for _, result in ipairs(baseline) do
    self._baseline[result.name] = result
  end
end

--- Compare current results to baseline
-- @return table Comparison results
function BenchmarkSuite:compare_to_baseline()
  if not self._baseline or not next(self._baseline) then
    return nil
  end

  local comparisons = {}

  for _, result in ipairs(self._results) do
    local baseline = self._baseline[result.name]
    if baseline then
      local ratio = result.per_iteration / baseline.per_iteration
      table.insert(comparisons, {
        name = result.name,
        current = result.per_iteration,
        baseline = baseline.per_iteration,
        ratio = ratio,
        improved = ratio < 0.95,
        regressed = ratio > 1.05,
      })
    end
  end

  return comparisons
end

--- Save results to file
-- @param path string Output path
-- @return boolean Success
function BenchmarkSuite:save_results(path)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write("-- Benchmark Results: " .. self._name .. "\n")
  file:write("-- Generated: " .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n")
  file:write("return {\n")

  for _, result in ipairs(self._results) do
    file:write(string.format("  { name = %q, iterations = %d, per_iteration = %.9f, memory_kb = %.2f },\n",
      result.name,
      result.iterations,
      result.per_iteration,
      result.memory_kb
    ))
  end

  file:write("}\n")
  file:close()

  return true
end

--- Load baseline from file
-- @param path string Input path
-- @return boolean Success
function BenchmarkSuite:load_baseline(path)
  local chunk = loadfile(path)
  if not chunk then
    return false
  end

  local ok, baseline = pcall(chunk)
  if not ok or type(baseline) ~= "table" then
    return false
  end

  self:set_baseline(baseline)
  return true
end

--- Clear all benchmarks
function BenchmarkSuite:clear()
  self._benchmarks = {}
  self._results = {}
end

--- Get benchmark count
-- @return number Number of registered benchmarks
function BenchmarkSuite:count()
  return #self._benchmarks
end

return BenchmarkSuite
