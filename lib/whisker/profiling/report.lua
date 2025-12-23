--- Report Generator
-- Formats profiling and benchmark results for output
-- @module whisker.profiling.report
-- @author Whisker Core Team
-- @license MIT

local Report = {}

--- Format a profiler report
-- @param report table Array of profiling entries
-- @param options table Options (top_n, show_avg)
-- @return string Formatted report
function Report.format_profiler_report(report, options)
  options = options or {}
  local top_n = options.top_n or 20
  local show_avg = options.show_avg ~= false

  local lines = {}
  local width = 90

  table.insert(lines, "")
  table.insert(lines, "Profiling Report")
  table.insert(lines, string.rep("=", width))

  if show_avg then
    table.insert(lines, string.format("%-50s %10s %12s %12s",
      "Function", "Calls", "Total (s)", "Avg (s)"))
  else
    table.insert(lines, string.format("%-50s %10s %12s",
      "Function", "Calls", "Total (s)"))
  end

  table.insert(lines, string.rep("-", width))

  local total_time = 0
  local total_calls = 0

  for i = 1, math.min(#report, top_n) do
    local entry = report[i]
    local location = entry.location

    -- Truncate long locations
    if #location > 50 then
      location = "..." .. location:sub(-47)
    end

    if show_avg then
      table.insert(lines, string.format("%-50s %10d %12.6f %12.6f",
        location,
        entry.count,
        entry.total_time,
        entry.avg_time
      ))
    else
      table.insert(lines, string.format("%-50s %10d %12.6f",
        location,
        entry.count,
        entry.total_time
      ))
    end

    total_time = total_time + entry.total_time
    total_calls = total_calls + entry.count
  end

  table.insert(lines, string.rep("-", width))

  if #report > top_n then
    table.insert(lines, string.format("... and %d more functions", #report - top_n))
  end

  table.insert(lines, string.format("Total: %d calls, %.6f seconds", total_calls, total_time))
  table.insert(lines, string.rep("=", width))

  return table.concat(lines, "\n")
end

--- Format a memory profiling result
-- @param result table Memory profiling result
-- @return string Formatted report
function Report.format_memory_report(result)
  local lines = {}

  table.insert(lines, "")
  table.insert(lines, "Memory Profiling Result")
  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("  Total memory: %10.2f KB", result.total_kb))
  table.insert(lines, string.format("  Per iteration: %10.4f KB", result.per_iteration_kb))
  table.insert(lines, string.format("  Elapsed time: %10.6f seconds", result.elapsed))

  if result.iterations then
    table.insert(lines, string.format("  Iterations: %10d", result.iterations))
  end

  return table.concat(lines, "\n")
end

--- Format a memory tracker stats report
-- @param stats table Tracker statistics
-- @return string Formatted report
function Report.format_tracker_stats(stats)
  if not stats then
    return "No samples recorded"
  end

  local lines = {}

  table.insert(lines, "")
  table.insert(lines, string.format("Memory Tracker: %s", stats.name))
  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("  Samples: %10d", stats.sample_count))
  table.insert(lines, string.format("  Min: %14.2f KB", stats.min_kb))
  table.insert(lines, string.format("  Max: %14.2f KB", stats.max_kb))
  table.insert(lines, string.format("  Avg: %14.2f KB", stats.avg_kb))
  table.insert(lines, string.format("  Growth: %11.2f KB", stats.growth_kb))
  table.insert(lines, string.format("  Duration: %9.4f seconds", stats.duration))

  return table.concat(lines, "\n")
end

--- Format a leak detection result
-- @param result table Leak detection result
-- @return string Formatted report
function Report.format_leak_report(result)
  local lines = {}

  table.insert(lines, "")
  table.insert(lines, "Memory Leak Detection")
  table.insert(lines, string.rep("-", 40))

  if result.is_leak then
    table.insert(lines, "  Status: POTENTIAL LEAK DETECTED")
  else
    table.insert(lines, "  Status: No leak detected")
  end

  table.insert(lines, string.format("  Baseline: %10.2f KB", result.baseline_kb))
  table.insert(lines, string.format("  Final: %13.2f KB", result.final_kb))
  table.insert(lines, string.format("  Growth: %12.2f KB", result.growth_kb))
  table.insert(lines, string.format("  Per iteration: %5.4f KB", result.per_iteration_kb))
  table.insert(lines, string.format("  Consistent growth: %s", result.consistent_growth and "Yes" or "No"))

  return table.concat(lines, "\n")
end

--- Format benchmark results
-- @param results table Array of benchmark results
-- @param options table Options (title)
-- @return string Formatted report
function Report.format_benchmark_report(results, options)
  options = options or {}
  local title = options.title or "Benchmark Results"

  local lines = {}
  local width = 80

  table.insert(lines, "")
  table.insert(lines, title)
  table.insert(lines, string.rep("=", width))
  table.insert(lines, string.format("%-40s %12s %12s %12s",
    "Benchmark", "Iterations", "Time/Iter", "Memory"))
  table.insert(lines, string.rep("-", width))

  for _, result in ipairs(results) do
    local name = result.name
    if #name > 40 then
      name = name:sub(1, 37) .. "..."
    end

    table.insert(lines, string.format("%-40s %12d %12.6f %10.2f KB",
      name,
      result.iterations,
      result.per_iteration,
      result.memory_kb or 0
    ))
  end

  table.insert(lines, string.rep("=", width))

  return table.concat(lines, "\n")
end

--- Export results to JSON-like format
-- @param data table Data to export
-- @return string JSON string
function Report.to_json(data)
  local function serialize(val, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local t = type(val)

    if t == "nil" then
      return "null"
    elseif t == "boolean" then
      return val and "true" or "false"
    elseif t == "number" then
      return tostring(val)
    elseif t == "string" then
      return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif t == "table" then
      local parts = {}
      local is_array = #val > 0

      if is_array then
        for i, v in ipairs(val) do
          parts[i] = serialize(v, indent + 1)
        end
        return "[\n" .. indent_str .. "  " .. table.concat(parts, ",\n" .. indent_str .. "  ") .. "\n" .. indent_str .. "]"
      else
        for k, v in pairs(val) do
          table.insert(parts, '"' .. tostring(k) .. '": ' .. serialize(v, indent + 1))
        end
        if #parts == 0 then
          return "{}"
        end
        return "{\n" .. indent_str .. "  " .. table.concat(parts, ",\n" .. indent_str .. "  ") .. "\n" .. indent_str .. "}"
      end
    end

    return "null"
  end

  return serialize(data)
end

--- Save report to file
-- @param content string Report content
-- @param path string Output path
-- @return boolean Success
function Report.save(content, path)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(content)
  file:close()
  return true
end

return Report
