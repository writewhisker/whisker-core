--- Profiling Module
-- Entry point for profiling and benchmarking tools
-- @module whisker.profiling
-- @author Whisker Core Team
-- @license MIT

local Profiling = {}

-- Lazy load submodules
local _profiler, _memory, _report

function Profiling.profiler()
  if not _profiler then
    _profiler = require("whisker.profiling.profiler")
  end
  return _profiler
end

function Profiling.memory()
  if not _memory then
    _memory = require("whisker.profiling.memory")
  end
  return _memory
end

function Profiling.report()
  if not _report then
    _report = require("whisker.profiling.report")
  end
  return _report
end

--- Create a new profiler instance
-- @return Profiler
function Profiling.new_profiler()
  return Profiling.profiler().new()
end

--- Take a memory snapshot
-- @return table Memory snapshot
function Profiling.memory_snapshot()
  return Profiling.memory().snapshot()
end

--- Profile a function
-- @param fn function Function to profile
-- @param iterations number Number of iterations
-- @return table Profiling result
function Profiling.profile(fn, iterations)
  return Profiling.profiler().profile_function(fn, iterations)
end

--- Profile memory usage of a function
-- @param fn function Function to profile
-- @param iterations number Number of iterations
-- @return table Memory result
function Profiling.profile_memory(fn, iterations)
  return Profiling.memory().profile_function(fn, iterations)
end

--- Detect memory leaks
-- @param fn function Function to test
-- @param iterations number Number of iterations
-- @param threshold_kb number Growth threshold
-- @return table Leak detection result
function Profiling.detect_leak(fn, iterations, threshold_kb)
  return Profiling.memory().detect_leak(fn, iterations, threshold_kb)
end

return Profiling
