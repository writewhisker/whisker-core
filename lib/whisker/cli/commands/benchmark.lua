--- Benchmark CLI Command
-- Command-line interface for running performance benchmarks
-- @module whisker.cli.commands.benchmark
-- @author Whisker Core Team
-- @license MIT

local BenchmarkCommand = {}

--- Parse command-line arguments
-- @param args table Raw arguments array
-- @return table Parsed arguments
local function parse_args(args)
  local parsed = {
    filter = nil,
    output = nil,
    baseline = nil,
    save_baseline = nil,
    help = false,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == "--help" or arg == "-h" then
      parsed.help = true
    elseif arg:match("^%-%-filter=") then
      parsed.filter = arg:match("^%-%-filter=(.+)")
    elseif arg == "--filter" or arg == "-f" then
      i = i + 1
      parsed.filter = args[i]
    elseif arg:match("^%-%-output=") then
      parsed.output = arg:match("^%-%-output=(.+)")
    elseif arg == "--output" or arg == "-o" then
      i = i + 1
      parsed.output = args[i]
    elseif arg:match("^%-%-baseline=") then
      parsed.baseline = arg:match("^%-%-baseline=(.+)")
    elseif arg == "--baseline" or arg == "-b" then
      i = i + 1
      parsed.baseline = args[i]
    elseif arg:match("^%-%-save%-baseline=") then
      parsed.save_baseline = arg:match("^%-%-save%-baseline=(.+)")
    elseif arg == "--save-baseline" then
      i = i + 1
      parsed.save_baseline = args[i]
    end

    i = i + 1
  end

  return parsed
end

--- Show help text
-- @return number Exit code
local function show_help()
  print([[
whisker benchmark - Run performance benchmarks

USAGE:
  whisker benchmark [OPTIONS]

OPTIONS:
  -f, --filter=PATTERN      Run only matching benchmarks
  -o, --output=FILE         Save report to file
  -b, --baseline=FILE       Compare against baseline results
  --save-baseline=FILE      Save results as new baseline
  -h, --help                Show this help message

EXAMPLES:
  whisker benchmark
  whisker benchmark --filter=passage
  whisker benchmark --save-baseline=baseline.lua
  whisker benchmark --baseline=baseline.lua

BENCHMARK SUITES:
  - Passage Navigation: Lookup and traversal operations
  - State Operations: Variable and flag management
  - Export Operations: Story serialization and export

OUTPUT:
  Shows time per iteration for each benchmark. Lower is better.
  When comparing to baseline, shows FASTER/SLOWER indicators.
]])

  return 0
end

--- Execute benchmark command
-- @param args table Command-line arguments
-- @param whisker table|nil Whisker instance (optional)
-- @return number Exit code
function BenchmarkCommand.execute(args, whisker)
  local parsed = parse_args(args)

  if parsed.help then
    return show_help()
  end

  print("Running benchmarks...")
  print()

  -- Load benchmark suites
  local Benchmarks = require("whisker.benchmarks.init")
  local suites = Benchmarks.get_all_suites()

  local all_results = {}
  local all_reports = {}

  for _, suite in ipairs(suites) do
    -- Load baseline if specified
    if parsed.baseline then
      if suite:load_baseline(parsed.baseline) then
        print("Loaded baseline: " .. parsed.baseline)
      end
    end

    -- Run benchmarks
    local report = suite:run(parsed.filter)
    table.insert(all_reports, report)

    -- Collect results for saving
    for _, result in ipairs(suite:get_results()) do
      table.insert(all_results, result)
    end

    -- Show comparison if baseline was loaded
    if parsed.baseline then
      local comparison = suite:compare_to_baseline()
      if comparison and #comparison > 0 then
        print("\nComparison to Baseline:")
        print(string.rep("-", 60))

        local regressions = 0
        local improvements = 0

        for _, c in ipairs(comparison) do
          local status
          if c.regressed then
            status = string.format("SLOWER %.1fx", c.ratio)
            regressions = regressions + 1
          elseif c.improved then
            status = string.format("FASTER %.1fx", 1/c.ratio)
            improvements = improvements + 1
          else
            status = "same"
          end
          print(string.format("  %-40s %s", c.name, status))
        end

        print()
        print(string.format("Summary: %d improved, %d regressed, %d unchanged",
          improvements, regressions, #comparison - improvements - regressions))
      end
    end

    print()
  end

  -- Save results as baseline if requested
  if parsed.save_baseline then
    -- Create a temporary suite to save all results
    local BenchmarkSuite = require("whisker.benchmarks.suite")
    local combined = BenchmarkSuite.new("Combined Results")

    -- Manually set results
    combined._results = all_results

    if combined:save_results(parsed.save_baseline) then
      print("Baseline saved to: " .. parsed.save_baseline)
    else
      print("Error: Cannot save baseline to: " .. parsed.save_baseline)
      return 1
    end
  end

  -- Save report if requested
  if parsed.output then
    local combined_report = table.concat(all_reports, "\n\n")
    combined_report = "Benchmark Report\n" ..
                     "Generated: " .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n\n" ..
                     combined_report

    local file = io.open(parsed.output, "w")
    if file then
      file:write(combined_report)
      file:close()
      print("Report saved to: " .. parsed.output)
    else
      print("Error: Cannot write to: " .. parsed.output)
      return 1
    end
  end

  return 0
end

--- Get command help text (for CLI integration)
-- @return string Help text
function BenchmarkCommand.help()
  return "Run performance benchmarks"
end

--- Get command name
-- @return string Command name
function BenchmarkCommand.name()
  return "benchmark"
end

return BenchmarkCommand
