#!/usr/bin/env lua
--- Hot Path Analyzer
-- Analyzes profiling data to identify optimization targets
-- @module tools.analyze_hot_paths
-- @author Whisker Core Team
-- @license MIT

local HotPathAnalyzer = {}

--- Calculate optimization priority
-- Higher values = higher priority
-- @param entry table Profiling entry
-- @param percentage number Percentage of total time
-- @return number Priority score
local function calculate_priority(entry, percentage)
  -- Priority factors:
  -- 1. High percentage of total time
  -- 2. High call count (more impact if optimized)
  -- 3. High average time per call (easier to optimize)

  local call_factor = math.log10(entry.count + 1) + 1
  local avg_factor = entry.avg_time > 0.0001 and 1.5 or 1.0

  return percentage * call_factor * avg_factor
end

--- Analyze profiling report for hot paths
-- @param report table Array of profiling entries
-- @param options table Options:
--   - threshold: number (minimum percentage to include, default 5)
--   - top_n: number (max hot paths to return, default 20)
-- @return table Array of hot path entries
function HotPathAnalyzer.analyze(report, options)
  options = options or {}
  local threshold = options.threshold or 5
  local top_n = options.top_n or 20

  -- Calculate total time
  local total_time = 0
  for _, entry in ipairs(report) do
    total_time = total_time + entry.total_time
  end

  if total_time == 0 then
    return {}
  end

  -- Find hot paths
  local hot_paths = {}

  for _, entry in ipairs(report) do
    local percentage = (entry.total_time / total_time) * 100

    if percentage >= threshold then
      table.insert(hot_paths, {
        location = entry.location,
        percentage = percentage,
        total_time = entry.total_time,
        calls = entry.count,
        avg_time = entry.avg_time,
        priority = calculate_priority(entry, percentage),
      })
    end
  end

  -- Sort by priority
  table.sort(hot_paths, function(a, b)
    return a.priority > b.priority
  end)

  -- Limit to top_n
  if #hot_paths > top_n then
    local trimmed = {}
    for i = 1, top_n do
      trimmed[i] = hot_paths[i]
    end
    hot_paths = trimmed
  end

  return hot_paths
end

--- Categorize hot paths by type
-- @param hot_paths table Array of hot path entries
-- @return table Categorized paths
function HotPathAnalyzer.categorize(hot_paths)
  local categories = {
    lookup = {},
    string_ops = {},
    table_ops = {},
    io = {},
    other = {},
  }

  for _, path in ipairs(hot_paths) do
    local loc = path.location:lower()

    if loc:match("find") or loc:match("lookup") or loc:match("get") then
      table.insert(categories.lookup, path)
    elseif loc:match("string") or loc:match("gsub") or loc:match("match") then
      table.insert(categories.string_ops, path)
    elseif loc:match("table") or loc:match("insert") or loc:match("ipairs") then
      table.insert(categories.table_ops, path)
    elseif loc:match("read") or loc:match("write") or loc:match("file") then
      table.insert(categories.io, path)
    else
      table.insert(categories.other, path)
    end
  end

  return categories
end

--- Generate optimization recommendations
-- @param hot_paths table Array of hot path entries
-- @return table Array of recommendation entries
function HotPathAnalyzer.recommend(hot_paths)
  local recommendations = {}

  for _, path in ipairs(hot_paths) do
    local rec = {
      location = path.location,
      percentage = path.percentage,
      priority = "low",
    }

    -- Determine priority
    if path.percentage > 20 then
      rec.priority = "high"
    elseif path.percentage > 10 then
      rec.priority = "medium"
    end

    -- Generate recommendations based on location
    local loc = path.location:lower()

    if loc:match("find") and path.calls > 1000 then
      rec.suggestion = "Use hash table for O(1) lookup instead of linear search"
      rec.potential_improvement = path.percentage * 0.9
    elseif loc:match("gsub") and path.calls > 1000 then
      rec.suggestion = "Cache compiled patterns or use string.find for simple cases"
      rec.potential_improvement = path.percentage * 0.3
    elseif loc:match("ipairs") and path.percentage > 10 then
      rec.suggestion = "Consider numeric for loop for large arrays"
      rec.potential_improvement = path.percentage * 0.2
    elseif loc:match("concat") and path.calls > 1000 then
      rec.suggestion = "Use table.concat for building strings"
      rec.potential_improvement = path.percentage * 0.5
    elseif path.avg_time > 0.001 then
      rec.suggestion = "High average time - consider algorithmic optimization"
      rec.potential_improvement = path.percentage * 0.5
    else
      rec.suggestion = "Profile more deeply to identify specific bottleneck"
      rec.potential_improvement = path.percentage * 0.1
    end

    table.insert(recommendations, rec)
  end

  return recommendations
end

--- Generate formatted analysis report
-- @param report table Profiling report
-- @param options table Options
-- @return string Formatted report
function HotPathAnalyzer.format_report(report, options)
  local hot_paths = HotPathAnalyzer.analyze(report, options)
  local recommendations = HotPathAnalyzer.recommend(hot_paths)

  local lines = {}
  local width = 80

  table.insert(lines, "Hot Path Analysis Report")
  table.insert(lines, string.rep("=", width))
  table.insert(lines, "")

  -- Summary
  local total_time = 0
  local total_calls = 0
  for _, entry in ipairs(report) do
    total_time = total_time + entry.total_time
    total_calls = total_calls + entry.count
  end

  table.insert(lines, "Summary")
  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("  Total profiling time: %.3f seconds", total_time))
  table.insert(lines, string.format("  Total function calls: %d", total_calls))
  table.insert(lines, string.format("  Functions analyzed: %d", #report))
  table.insert(lines, string.format("  Hot paths identified: %d", #hot_paths))
  table.insert(lines, "")

  -- Hot paths
  table.insert(lines, "Top Hot Paths")
  table.insert(lines, string.rep("-", 40))

  for i, path in ipairs(hot_paths) do
    table.insert(lines, "")
    table.insert(lines, string.format("%d. %s (%.1f%%)", i, path.location, path.percentage))
    table.insert(lines, string.format("   Calls: %d, Total: %.4fs, Avg: %.6fs",
      path.calls, path.total_time, path.avg_time))
    table.insert(lines, string.format("   Priority score: %.2f", path.priority))
  end

  table.insert(lines, "")

  -- Recommendations
  table.insert(lines, "Optimization Recommendations")
  table.insert(lines, string.rep("-", 40))

  for i, rec in ipairs(recommendations) do
    if i <= 10 then
      table.insert(lines, "")
      table.insert(lines, string.format("[%s] %s", rec.priority:upper(), rec.location))
      table.insert(lines, "   " .. rec.suggestion)
      table.insert(lines, string.format("   Potential improvement: %.1f%%", rec.potential_improvement or 0))
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("=", width))

  return table.concat(lines, "\n")
end

return HotPathAnalyzer
