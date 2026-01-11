#!/usr/bin/env lua
--[[
  Benchmark Runner
  
  Comprehensive performance testing suite for whisker-core.
  
  Usage:
    lua tests/benchmarks/benchmark_runner.lua
    lua tests/benchmarks/benchmark_runner.lua --suite=search
    lua tests/benchmarks/benchmark_runner.lua --verbose
]]

-- Add lib directory to package path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local json = require("cjson")

-- Benchmark utilities
local Benchmark = {}

--[[
  Measure execution time of a function
  
  @param name string Benchmark name
  @param fn function Function to benchmark
  @param iterations number Number of iterations (default: 1)
  @return table Results with timing information
]]
function Benchmark.measure(name, fn, iterations)
  iterations = iterations or 1
  
  -- Warmup
  if iterations > 1 then
    fn()
  end
  
  -- Collect garbage before benchmark
  collectgarbage("collect")
  
  local start_time = os.clock()
  local start_mem = collectgarbage("count")
  
  for i = 1, iterations do
    fn()
  end
  
  local end_time = os.clock()
  local end_mem = collectgarbage("count")
  
  local total_time = (end_time - start_time) * 1000  -- Convert to ms
  local avg_time = total_time / iterations
  local memory_used = end_mem - start_mem
  
  return {
    name = name,
    iterations = iterations,
    total_time_ms = total_time,
    avg_time_ms = avg_time,
    memory_kb = memory_used,
    ops_per_sec = iterations / (total_time / 1000)
  }
end

--[[
  Run a benchmark suite
  
  @param suite_name string Name of the suite
  @param benchmarks table Array of benchmark definitions
  @return table Array of results
]]
function Benchmark.run_suite(suite_name, benchmarks)
  print(string.format("\n%s BENCHMARK SUITE: %s %s", 
    string.rep("=", 25), suite_name, string.rep("=", 25)))
  print("")
  
  local results = {}
  
  for i, benchmark in ipairs(benchmarks) do
    local name = benchmark.name
    local fn = benchmark.fn
    local iterations = benchmark.iterations or 1
    local target = benchmark.target
    
    io.write(string.format("  [%d/%d] Running: %s... ", i, #benchmarks, name))
    io.flush()
    
    local result = Benchmark.measure(name, fn, iterations)
    table.insert(results, result)
    
    -- Check if target was met
    local status = "✓"
    if target and result.avg_time_ms > target then
      status = "✗ SLOW"
    end
    
    print(string.format("%s (%.2f ms)", status, result.avg_time_ms))
  end
  
  print("")
  return results
end

--[[
  Display benchmark results in a formatted table
]]
function Benchmark.display_results(results)
  print("\nBENCHMARK RESULTS")
  print(string.rep("=", 80))
  print(string.format("%-40s %12s %12s %12s", 
    "Benchmark", "Avg Time", "Memory", "Ops/Sec"))
  print(string.rep("-", 80))
  
  for _, result in ipairs(results) do
    print(string.format("%-40s %9.2f ms %9.1f KB %12.0f",
      result.name,
      result.avg_time_ms,
      result.memory_kb,
      result.ops_per_sec))
  end
  
  print(string.rep("=", 80))
  print("")
end

--[[
  Save results to JSON file
]]
function Benchmark.save_results(results, filename)
  local file = io.open(filename, "w")
  if file then
    file:write(json.encode({
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      results = results,
      lua_version = _VERSION,
      platform = package.config:sub(1,1) == '/' and 'unix' or 'windows'
    }))
    file:close()
    print(string.format("Results saved to: %s\n", filename))
  end
end

--[[
  Compare results with baseline
]]
function Benchmark.compare_with_baseline(results, baseline_file)
  local file = io.open(baseline_file, "r")
  if not file then
    print("No baseline found. Creating baseline...\n")
    Benchmark.save_results(results, baseline_file)
    return
  end
  
  local content = file:read("*all")
  file:close()
  
  local baseline_data = json.decode(content)
  local baseline = {}
  for _, r in ipairs(baseline_data.results) do
    baseline[r.name] = r
  end
  
  print("\nCOMPARISON WITH BASELINE")
  print(string.rep("=", 80))
  print(string.format("%-40s %12s %12s %12s", 
    "Benchmark", "Current", "Baseline", "Change"))
  print(string.rep("-", 80))
  
  for _, result in ipairs(results) do
    local base = baseline[result.name]
    if base then
      local change = ((result.avg_time_ms - base.avg_time_ms) / base.avg_time_ms) * 100
      local change_str = string.format("%+.1f%%", change)
      
      -- Color code based on change
      local indicator = ""
      if change < -5 then
        indicator = "✓ FASTER"
      elseif change > 5 then
        indicator = "✗ SLOWER"
      else
        indicator = "= SAME"
      end
      
      print(string.format("%-40s %9.2f ms %9.2f ms %8s %s",
        result.name,
        result.avg_time_ms,
        base.avg_time_ms,
        change_str,
        indicator))
    else
      print(string.format("%-40s %9.2f ms %12s %12s",
        result.name,
        result.avg_time_ms,
        "N/A",
        "NEW"))
    end
  end
  
  print(string.rep("=", 80))
  print("")
end

return Benchmark
