--- Development Environment Manager
-- Integrates server, watcher, and hot reload for local development
-- @module whisker.dev
-- @author Whisker Development Team
-- @license MIT

local Server = require("whisker.dev.server")
local Watcher = require("whisker.dev.watcher")
local HotReload = require("whisker.dev.hot_reload")
local lfs = require("lfs")

local DevEnv = {}
DevEnv.__index = DevEnv

--- Create a new development environment
-- @param config Configuration table
-- @param config.port Server port (default: 3000)
-- @param config.host Server host (default: "127.0.0.1")
-- @param config.story_path Path to story file (optional)
-- @param config.root_dir Document root (default: current directory)
-- @param config.watch_paths Paths to watch (default: {root_dir})
-- @param config.hot_reload Enable hot reload (default: true)
-- @param config.open_browser Open browser automatically (default: false)
-- @return DevEnv instance
function DevEnv.new(config)
  config = config or {}
  
  local self = setmetatable({}, DevEnv)
  
  self.config = {
    port = config.port or 3000,
    host = config.host or "127.0.0.1",
    story_path = config.story_path,
    root_dir = config.root_dir or lfs.currentdir(),
    watch_paths = config.watch_paths or {config.root_dir or lfs.currentdir()},
    hot_reload = config.hot_reload ~= false,  -- default true
    open_browser = config.open_browser or false
  }
  
  -- Components
  self.server = nil
  self.watcher = nil
  self.hot_reload = nil
  self.running = false
  
  -- SSE clients for hot reload
  self.sse_clients = {}
  
  return self
end

--- Initialize all components
function DevEnv:init()
  -- Create HTTP server
  self.server = Server.new({
    port = self.config.port,
    host = self.config.host,
    root_dir = self.config.root_dir
  })
  
  -- Add dev routes
  self:_add_dev_routes()
  
  if self.config.hot_reload then
    -- Create file watcher
    self.watcher = Watcher.new({
      paths = self.config.watch_paths,
      debounce = 0.1
    })
    
    -- Create hot reload manager
    self.hot_reload = HotReload.new()
    
    -- Connect components
    self:_setup_event_handlers()
  end
end

--- Add development routes to server
function DevEnv:_add_dev_routes()
  -- Hot reload SSE endpoint
  self.server:add_route("^/hot%-reload$", function(request)
    return {
      status = 200,
      headers = {
        ["Content-Type"] = "text/event-stream",
        ["Cache-Control"] = "no-cache",
        ["Connection"] = "keep-alive"
      },
      body = "data: {\"type\":\"connected\"}\n\n"
    }
  end)
  
  -- Dev status endpoint
  self.server:add_route("^/api/dev/status$", function(request)
    local json = require("whisker.utils.json")
    return {
      status = 200,
      headers = {["Content-Type"] = "application/json"},
      body = json.encode({
        running = self.running,
        hot_reload = self.config.hot_reload,
        watching = self.watcher and self.watcher:is_watching() or false,
        files_watched = self.watcher and self.watcher:get_file_count() or 0
      })
    }
  end)
end

--- Setup event handlers between components
function DevEnv:_setup_event_handlers()
  if not self.watcher or not self.hot_reload then
    return
  end
  
  -- Connect hot reload to watcher
  self.hot_reload:connect_watcher(self.watcher)
  
  -- When modules reload, notify browser clients
  self.hot_reload:on("module_reloaded", function(data)
    self:_broadcast_reload("file_modified", data)
  end)
  
  -- When files change, notify browser
  self.watcher:on("file_modified", function(data)
    self:_broadcast_reload("file_modified", data)
  end)
  
  self.watcher:on("file_created", function(data)
    self:_broadcast_reload("file_created", data)
  end)
end

--- Broadcast reload event to connected clients
-- @param reload_type Type of reload
-- @param data Event data
function DevEnv:_broadcast_reload(reload_type, data)
  -- In a full implementation, this would send SSE events
  -- For now, we just track it
  if self.config.hot_reload then
    -- Event broadcast would happen here
    -- print("[DevEnv] Broadcasting reload:", reload_type, data.path or data.module)
  end
end

--- Start the development environment
-- @return boolean success, string? error
function DevEnv:start()
  if self.running then
    return false, "Already running"
  end
  
  -- Initialize if not done
  if not self.server then
    self:init()
  end
  
  -- Start server
  local ok, err = self.server:start()
  if not ok then
    return false, err
  end
  
  -- Start watcher
  if self.watcher then
    self.watcher:start()
  end
  
  self.running = true
  
  -- Open browser if requested
  if self.config.open_browser then
    self:_open_browser()
  end
  
  return true
end

--- Stop the development environment
function DevEnv:stop()
  if not self.running then
    return
  end
  
  -- Stop watcher
  if self.watcher then
    self.watcher:stop()
  end
  
  -- Stop server
  if self.server then
    self.server:stop()
  end
  
  self.running = false
end

--- Check if environment is running
-- @return boolean
function DevEnv:is_running()
  return self.running
end

--- Process one tick of the server loop
-- Call this repeatedly in a loop
-- @return boolean continue (false to stop)
function DevEnv:tick()
  if not self.running then
    return false
  end
  
  -- Tick server
  if self.server then
    if not self.server:tick() then
      return false
    end
  end
  
  -- Tick watcher
  if self.watcher then
    self.watcher:tick()
  end
  
  return true
end

--- Open browser to server URL
function DevEnv:_open_browser()
  local url = self.server:get_url()
  local os_name = package.config:sub(1,1) == '\\' and 'windows' or 'unix'
  
  if os_name == 'windows' then
    os.execute('start ' .. url)
  else
    -- Try common browsers on Unix/Mac
    os.execute('open ' .. url .. ' 2>/dev/null || xdg-open ' .. url .. ' 2>/dev/null &')
  end
end

--- Get server URL
-- @return string
function DevEnv:get_url()
  return self.server and self.server:get_url() or "http://localhost:3000"
end

--- Get development status
-- @return table Status information
function DevEnv:get_status()
  return {
    running = self.running,
    url = self:get_url(),
    port = self.config.port,
    hot_reload = self.config.hot_reload,
    watching = self.watcher and self.watcher:is_watching() or false,
    files_watched = self.watcher and self.watcher:get_file_count() or 0,
    modules_tracked = self.hot_reload and self.hot_reload:get_module_count() or 0
  }
end

return DevEnv
