#!/usr/bin/env lua
-- whisker-lsp: Language Server Protocol implementation for whisker-core
--
-- Usage: whisker-lsp [options]
--
-- Options:
--   --stdio     Use stdin/stdout for communication (default)
--   --version   Show version information
--   --help      Show this help message

-- Add lib to path
local script_dir = debug.getinfo(1, "S").source:match("^@(.*/)")
if script_dir then
  package.path = script_dir .. "lib/?.lua;" .. script_dir .. "?.lua;" .. package.path
else
  package.path = "./tools/whisker-lsp/lib/?.lua;./tools/whisker-lsp/?.lua;" .. package.path
end

-- Also add whisker-core lib path
package.path = "./lib/?.lua;./lib/?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local VERSION = "0.1.0"

local function show_help()
  print([[
whisker-lsp - Language Server for whisker-core interactive fiction

Usage: whisker-lsp [options]

Options:
  --stdio     Use stdin/stdout for communication (default)
  --version   Show version information
  --help      Show this help message

Description:
  whisker-lsp provides IDE features for .ink, .wscript, and .twee files:
  - Auto-completion for passages, variables, and macros
  - Syntax error diagnostics
  - Hover documentation
  - Go-to-definition for passages
  - Document symbols for outline view

Supported Languages:
  - Ink (.ink)
  - WhiskerScript (.wscript)
  - Twee (.twee)

For more information, see: https://github.com/writewhisker/whisker-core
]])
end

local function show_version()
  print("whisker-lsp version " .. VERSION)
end

local function main(args)
  -- Parse arguments
  for _, arg in ipairs(args) do
    if arg == "--help" or arg == "-h" then
      show_help()
      os.exit(0)
    elseif arg == "--version" or arg == "-v" then
      show_version()
      os.exit(0)
    elseif arg == "--stdio" then
      -- Default behavior, continue
    else
      io.stderr:write("Unknown option: " .. arg .. "\n")
      io.stderr:write("Use --help for usage information\n")
      os.exit(1)
    end
  end

  -- Create and run server
  local LspServer = require("lib.lsp_server")
  local server = LspServer.new()

  -- Run main loop
  server:run()
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("whisker%-lsp%.lua$") then
  main(arg)
end

return {
  VERSION = VERSION,
  main = main
}
