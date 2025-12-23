#!/usr/bin/env lua
-- whisker-debug: Debug Adapter for whisker-core interactive fiction
-- Debug Adapter Protocol (DAP) implementation

-- Add lib directory to package path
local script_dir = arg[0]:match("(.*/)")
if script_dir then
  package.path = script_dir .. "?.lua;" ..
                 script_dir .. "lib/?.lua;" ..
                 script_dir .. "../whisker-lsp/?.lua;" ..
                 package.path
end

local function print_help()
  print([[
whisker-debug - Debug Adapter for whisker-core

Usage: whisker-debug [options]

Options:
  -h, --help       Show this help message
  -v, --version    Show version information
  --stdio          Use stdin/stdout for communication (default)
  --port PORT      Listen on TCP port (not implemented)

The debug adapter implements the Debug Adapter Protocol (DAP)
and communicates via stdin/stdout by default.

Configuration in VSCode launch.json:
  {
    "type": "whisker",
    "request": "launch",
    "name": "Debug Story",
    "program": "${file}",
    "stopOnEntry": false
  }

Breakpoint Support:
  - Line breakpoints
  - Conditional breakpoints
  - Hit count breakpoints
  - Logpoints (log messages without stopping)

Step Commands:
  - Continue (F5)
  - Step Into (F11)
  - Step Over (F10)
  - Step Out (Shift+F11)

Variable Inspection:
  - View story state variables
  - Evaluate expressions in debug console
  - Nested table expansion
]])
end

local function print_version()
  print("whisker-debug 0.1.0")
  print("Debug Adapter Protocol implementation for whisker-core")
end

local function main()
  -- Parse arguments
  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == "-h" or a == "--help" then
      print_help()
      os.exit(0)
    elseif a == "-v" or a == "--version" then
      print_version()
      os.exit(0)
    elseif a == "--stdio" then
      -- Default mode, continue
    elseif a == "--port" then
      print("Error: TCP mode not implemented")
      os.exit(1)
    else
      print("Unknown option: " .. a)
      print("Use --help for usage information")
      os.exit(1)
    end
    i = i + 1
  end

  -- Load and run adapter
  local ok, DAPAdapter = pcall(require, "whisker-debug.lib.dap_adapter")
  if not ok then
    -- Try relative path
    ok, DAPAdapter = pcall(require, "lib.dap_adapter")
    if not ok then
      io.stderr:write("Failed to load DAP adapter: " .. tostring(DAPAdapter) .. "\n")
      os.exit(1)
    end
  end

  local adapter = DAPAdapter.new()
  adapter:run()
end

-- Run if executed directly
if arg[0]:match("whisker%-debug%.lua$") or arg[0]:match("whisker%-debug$") then
  main()
end

return {
  main = main
}
