--- Code Profiler
-- Uses Lua debug hooks to track function calls and execution time
-- @module whisker.profiling.profiler
-- @author Whisker Core Team
-- @license MIT

local Profiler = {}
Profiler._dependencies = {}
Profiler.__index = Profiler

--- Create a new profiler instance
-- @return Profiler A new profiler
function Profiler.new(deps)
  deps = deps or {}
  local self = setmetatable({}, Profiler)
  self._call_counts = {}
  self._call_times = {}
  self._call_stack = {}
  self._active = false
  self._start_time = nil
  return self
end

--- Start profiling
function Profiler:start()
  self._active = true
  self._call_counts = {}
  self._call_times = {}
  self._call_stack = {}
  self._start_time = os.clock()

  local profiler = self

  debug.sethook(function(event)
    if event == "call" then
      profiler:_on_call()
    elseif event == "return" or event == "tail return" then
      profiler:_on_return()
    end
  end, "cr")
end

--- Stop profiling and return report
-- @return table Array of profiling entries sorted by total time
function Profiler:stop()
  debug.sethook()
  self._active = false
  return self:get_report()
end

--- Check if profiler is active
-- @return boolean True if profiling
function Profiler:is_active()
  return self._active
end

--- Handle function call event
function Profiler:_on_call()
  local info = debug.getinfo(3, "nSl")
  if not info then return end

  local key = self:_get_function_key(info)

  -- Track call count
  self._call_counts[key] = (self._call_counts[key] or 0) + 1

  -- Push onto stack with timestamp
  table.insert(self._call_stack, {
    key = key,
    start_time = os.clock(),
  })
end

--- Handle function return event
function Profiler:_on_return()
  if #self._call_stack == 0 then return end

  local frame = table.remove(self._call_stack)
  local elapsed = os.clock() - frame.start_time

  -- Track cumulative time
  self._call_times[frame.key] = (self._call_times[frame.key] or 0) + elapsed
end

--- Get function key from debug info
-- @param info table Debug info table
-- @return string Function identifier
function Profiler:_get_function_key(info)
  local name = info.name or "<anonymous>"
  local source = info.short_src or "?"
  local line = info.linedefined or 0

  -- Include line number for anonymous functions
  if name == "<anonymous>" and line > 0 then
    return source .. ":" .. line
  end

  return source .. ":" .. name
end

--- Get profiling report
-- @return table Array of {location, count, total_time, avg_time}
function Profiler:get_report()
  local report = {}

  for key, count in pairs(self._call_counts) do
    local total_time = self._call_times[key] or 0
    table.insert(report, {
      location = key,
      count = count,
      total_time = total_time,
      avg_time = total_time / count,
    })
  end

  -- Sort by total time descending
  table.sort(report, function(a, b)
    return a.total_time > b.total_time
  end)

  return report
end

--- Get total execution time
-- @return number Seconds since start
function Profiler:get_elapsed_time()
  if self._start_time then
    return os.clock() - self._start_time
  end
  return 0
end

--- Get call count for a function
-- @param key string Function key
-- @return number Call count
function Profiler:get_call_count(key)
  return self._call_counts[key] or 0
end

--- Get total time for a function
-- @param key string Function key
-- @return number Total time in seconds
function Profiler:get_total_time(key)
  return self._call_times[key] or 0
end

--- Reset profiler data
function Profiler:reset()
  self._call_counts = {}
  self._call_times = {}
  self._call_stack = {}
  self._start_time = nil
end

--- Profile a specific function
-- @param fn function Function to profile
-- @param iterations number Number of iterations (default 1)
-- @return table Profiling result
function Profiler.profile_function(fn, iterations)
  iterations = iterations or 1

  local profiler = Profiler.new()
  profiler:start()

  for i = 1, iterations do
    fn()
  end

  local report = profiler:stop()
  local elapsed = profiler:get_elapsed_time()

  return {
    elapsed = elapsed,
    per_iteration = elapsed / iterations,
    report = report,
  }
end

return Profiler
