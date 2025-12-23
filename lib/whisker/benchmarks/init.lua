--- Benchmarks Module
-- Entry point for benchmark suite
-- @module whisker.benchmarks
-- @author Whisker Core Team
-- @license MIT

local Benchmarks = {}

--- Get all benchmark suites
-- @return table Array of suites
function Benchmarks.get_all_suites()
  return {
    require("whisker.benchmarks.passage_navigation"),
    require("whisker.benchmarks.state_operations"),
    require("whisker.benchmarks.export_benchmarks"),
  }
end

--- Run all benchmarks
-- @param filter string|nil Pattern to filter benchmarks
-- @return string Combined report
function Benchmarks.run_all(filter)
  local reports = {}

  for _, suite in ipairs(Benchmarks.get_all_suites()) do
    local report = suite:run(filter)
    table.insert(reports, report)
  end

  return table.concat(reports, "\n\n")
end

--- Get the benchmark suite class
-- @return BenchmarkSuite
function Benchmarks.Suite()
  return require("whisker.benchmarks.suite")
end

return Benchmarks
