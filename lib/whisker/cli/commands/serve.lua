--- Serve Command - Development Server CLI
-- @module whisker.cli.commands.serve
-- @author Whisker Development Team
-- @license MIT

local DevEnv = require("whisker.dev")

local ServeCommand = {}

--- Parse command line arguments
-- @param args Array of arguments
-- @return table Configuration
function ServeCommand._parse_args(args)
  local config = {
    story_path = nil,
    port = 3000,
    host = "127.0.0.1",
    watch_paths = nil,
    hot_reload = true,
    open_browser = false,
    verbose = false
  }
  
  local i = 1
  while i <= #args do
    local arg = args[i]
    
    if arg == "--port" or arg == "-p" then
      i = i + 1
      config.port = tonumber(args[i])
    elseif arg == "--host" or arg == "-h" then
      i = i + 1
      config.host = args[i]
    elseif arg == "--watch" or arg == "-w" then
      i = i + 1
      if not config.watch_paths then
        config.watch_paths = {}
      end
      table.insert(config.watch_paths, args[i])
    elseif arg == "--no-reload" then
      config.hot_reload = false
    elseif arg == "--open" or arg == "-o" then
      config.open_browser = true
    elseif arg == "--verbose" or arg == "-v" then
      config.verbose = true
    elseif not arg:match("^%-") then
      -- Positional argument - story path
      config.story_path = arg
    end
    
    i = i + 1
  end
  
  return config
end

--- Print server information
-- @param dev_env DevEnv instance
function ServeCommand._print_info(dev_env)
  print([[
╭─────────────────────────────────────╮
│  🐱 Whisker Development Server     │
╰─────────────────────────────────────╯
]])
  
  local status = dev_env:get_status()
  
  print("  URL:         " .. status.url)
  if dev_env.config.story_path then
    print("  Story:       " .. dev_env.config.story_path)
  end
  print("  Hot Reload:  " .. (status.hot_reload and "✓ enabled" or "✗ disabled"))
  if status.watching then
    print("  Watching:    " .. status.files_watched .. " files")
  end
  print("")
  print("  Press Ctrl+C to stop")
  print("")
end

--- Setup signal handlers for graceful shutdown
-- @param dev_env DevEnv instance
function ServeCommand._setup_signal_handlers(dev_env)
  -- Note: Lua doesn't have built-in signal handling
  -- This would typically use a C extension or os-specific code
  -- For now, we rely on the user pressing Ctrl+C and cleaning up in finally blocks
end

--- Run the serve command
-- @param args Command line arguments
-- @return number Exit code
function ServeCommand.run(args)
  -- Parse arguments
  local config = ServeCommand._parse_args(args)
  
  -- Create development environment
  local dev_env = DevEnv.new(config)
  
  -- Start server
  local ok, err = dev_env:start()
  if not ok then
    io.stderr:write("Error starting server: " .. err .. "\n")
    
    -- Provide helpful hints for common errors
    if err:match("address already in use") or err:match("bind") then
      io.stderr:write("\nPort " .. config.port .. " is already in use.\n")
      io.stderr:write("Try a different port with --port <number>\n")
    elseif err:match("permission denied") then
      io.stderr:write("\nPermission denied. Try using a port > 1024\n")
    end
    
    return 1
  end
  
  -- Print info
  ServeCommand._print_info(dev_env)
  
  -- Main server loop
  local success = pcall(function()
    while dev_env:is_running() do
      if not dev_env:tick() then
        break
      end
      
      -- Small delay to prevent CPU spinning
      -- In production, this would use a proper event loop
      os.execute("sleep 0.01")
    end
  end)
  
  -- Cleanup
  dev_env:stop()
  
  if not success then
    io.stderr:write("\nServer stopped due to error\n")
    return 1
  end
  
  print("\nServer stopped")
  return 0
end

--- Show help for serve command
function ServeCommand.help()
  print([[
Usage: whisker serve [story_path] [options]

Start a development server for local story testing with hot reload.

Options:
  --port, -p <number>     Server port (default: 3000)
  --host, -h <address>    Server host (default: 127.0.0.1)
  --watch, -w <path>      Add path to watch (can specify multiple)
  --no-reload             Disable hot reload
  --open, -o              Open browser automatically
  --verbose, -v           Verbose logging

Examples:
  whisker serve                    # Serve current directory
  whisker serve story.json         # Serve specific story
  whisker serve -p 8080 --open     # Custom port and auto-open
  whisker serve -w lib -w stories  # Watch multiple directories

The dev server provides:
  - Static file serving
  - Hot reload for Lua modules
  - Live CSS updates
  - File watching
  - Development tools
]])
end

return ServeCommand
