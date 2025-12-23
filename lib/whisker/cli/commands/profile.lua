--- Profile CLI Command
-- Command-line interface for profiling Lua scripts
-- @module whisker.cli.commands.profile
-- @author Whisker Core Team
-- @license MIT

local ProfileCommand = {}

--- Parse command-line arguments
-- @param args table Raw arguments array
-- @return table Parsed arguments
local function parse_args(args)
  local parsed = {
    positional = {},
    top_n = 30,
    memory = false,
    leak_check = false,
    iterations = 1,
    output = nil,
    help = false,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == "--help" or arg == "-h" then
      parsed.help = true
    elseif arg:match("^%-%-top%-n=") then
      parsed.top_n = tonumber(arg:match("^%-%-top%-n=(%d+)"))
    elseif arg == "--top-n" or arg == "-n" then
      i = i + 1
      parsed.top_n = tonumber(args[i])
    elseif arg == "--memory" or arg == "-m" then
      parsed.memory = true
    elseif arg == "--leak-check" then
      parsed.leak_check = true
    elseif arg:match("^%-%-iterations=") then
      parsed.iterations = tonumber(arg:match("^%-%-iterations=(%d+)"))
    elseif arg == "--iterations" or arg == "-i" then
      i = i + 1
      parsed.iterations = tonumber(args[i])
    elseif arg:match("^%-%-output=") then
      parsed.output = arg:match("^%-%-output=(.+)")
    elseif arg == "--output" or arg == "-o" then
      i = i + 1
      parsed.output = args[i]
    elseif not arg:match("^%-") then
      table.insert(parsed.positional, arg)
    end

    i = i + 1
  end

  return parsed
end

--- Show help text
-- @return number Exit code
local function show_help()
  print([[
whisker profile - Profile Lua script performance

USAGE:
  whisker profile SCRIPT [OPTIONS]

ARGUMENTS:
  SCRIPT                Path to Lua script to profile

OPTIONS:
  -n, --top-n=N         Show top N functions (default: 30)
  -m, --memory          Also profile memory usage
  --leak-check          Check for memory leaks
  -i, --iterations=N    Number of iterations (default: 1)
  -o, --output=FILE     Save report to file
  -h, --help            Show this help message

EXAMPLES:
  whisker profile script.lua
  whisker profile benchmark.lua --top-n=50
  whisker profile test.lua --memory --iterations=100
  whisker profile story.lua --leak-check

OUTPUT:
  Shows which functions consume the most time and how often
  they are called. Use this to identify optimization targets.
]])

  return 0
end

--- Execute profile command
-- @param args table Command-line arguments
-- @param whisker table|nil Whisker instance (optional)
-- @return number Exit code
function ProfileCommand.execute(args, whisker)
  local parsed = parse_args(args)

  if parsed.help then
    return show_help()
  end

  -- Get script path
  local script_path = parsed.positional[1]
  if not script_path then
    print("Error: Script file required")
    print("Usage: whisker profile SCRIPT [OPTIONS]")
    print("Run 'whisker profile --help' for more information")
    return 1
  end

  -- Load script
  local script, err = loadfile(script_path)
  if not script then
    print("Error: Cannot load script: " .. tostring(err))
    return 1
  end

  -- Load profiling modules
  local Profiler = require("whisker.profiling.profiler")
  local MemoryProfiler = require("whisker.profiling.memory")
  local Report = require("whisker.profiling.report")

  local output_lines = {}

  print("Profiling: " .. script_path)

  if parsed.iterations > 1 then
    print("Iterations: " .. parsed.iterations)
  end

  print()

  -- Memory profiling if requested
  if parsed.memory then
    local mem_result = MemoryProfiler.profile_function(function()
      local ok, script_err = pcall(script)
      if not ok then
        print("Warning: Script error: " .. tostring(script_err))
      end
    end, parsed.iterations)

    local mem_report = Report.format_memory_report(mem_result)
    print(mem_report)
    table.insert(output_lines, mem_report)
  end

  -- Leak detection if requested
  if parsed.leak_check then
    print("Checking for memory leaks...")

    local leak_result = MemoryProfiler.detect_leak(function()
      local ok = pcall(script)
    end, parsed.iterations > 1 and parsed.iterations or 100)

    local leak_report = Report.format_leak_report(leak_result)
    print(leak_report)
    table.insert(output_lines, leak_report)
  end

  -- CPU profiling
  local profiler = Profiler.new()

  profiler:start()

  for i = 1, parsed.iterations do
    local ok, script_err = pcall(script)
    if not ok then
      profiler:stop()
      print("Error during execution: " .. tostring(script_err))
      return 1
    end
  end

  local report = profiler:stop()

  -- Display report
  local formatted = Report.format_profiler_report(report, { top_n = parsed.top_n })
  print(formatted)
  table.insert(output_lines, formatted)

  -- Save to file if requested
  if parsed.output then
    local content = table.concat(output_lines, "\n\n")
    if Report.save(content, parsed.output) then
      print()
      print("Report saved to: " .. parsed.output)
    else
      print("Error: Cannot write to file: " .. parsed.output)
      return 1
    end
  end

  return 0
end

--- Get command help text (for CLI integration)
-- @return string Help text
function ProfileCommand.help()
  return "Profile Lua script performance and memory usage"
end

--- Get command name
-- @return string Command name
function ProfileCommand.name()
  return "profile"
end

return ProfileCommand
