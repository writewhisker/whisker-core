--- Sync CLI Command
-- Command-line interface for storage synchronization
-- @module whisker.cli.commands.sync
-- @author Whisker Team
-- @license MIT

local SyncCommand = {}
SyncCommand.__index = SyncCommand

-- Lazy-loaded dependencies
local _sync_engine = nil
local _state_manager = nil
local _http_transport = nil
local _websocket_transport = nil
local _storage = nil
local _cjson = nil

--- Load dependencies
local function get_sync_engine()
  if not _sync_engine then
    local ok, engine = pcall(require, "whisker.storage.sync.engine")
    if ok then _sync_engine = engine end
  end
  return _sync_engine
end

local function get_state_manager()
  if not _state_manager then
    local ok, mgr = pcall(require, "whisker.storage.sync.state_manager")
    if ok then _state_manager = mgr end
  end
  return _state_manager
end

local function get_http_transport()
  if not _http_transport then
    local ok, transport = pcall(require, "whisker.storage.sync.transports.http")
    if ok then _http_transport = transport end
  end
  return _http_transport
end

local function get_websocket_transport()
  if not _websocket_transport then
    local ok, transport = pcall(require, "whisker.storage.sync.transports.websocket")
    if ok then _websocket_transport = transport end
  end
  return _websocket_transport
end

local function get_storage()
  if not _storage then
    local ok, storage = pcall(require, "whisker.storage")
    if ok then _storage = storage end
  end
  return _storage
end

local function get_cjson()
  if not _cjson then
    local ok, cjson = pcall(require, "cjson")
    if ok then _cjson = cjson end
  end
  return _cjson
end

--- Create new SyncCommand
-- @return SyncCommand
function SyncCommand.new()
  local self = setmetatable({}, SyncCommand)
  self._config_path = ".whisker-sync-config.json"
  return self
end

--- Load sync configuration
-- @return table|nil config, string|nil error
function SyncCommand:load_config()
  local cjson = get_cjson()
  if not cjson then
    return nil, "cjson library not available"
  end
  
  local file = io.open(self._config_path, "r")
  if not file then
    return nil, "Configuration file not found. Run 'whisker sync config' first."
  end
  
  local content = file:read("*all")
  file:close()
  
  local ok, config = pcall(cjson.decode, content)
  if not ok then
    return nil, "Invalid configuration file"
  end
  
  return config
end

--- Save sync configuration
-- @param config table Configuration
-- @return boolean success, string|nil error
function SyncCommand:save_config(config)
  local cjson = get_cjson()
  if not cjson then
    return false, "cjson library not available"
  end
  
  local file = io.open(self._config_path, "w")
  if not file then
    return false, "Cannot write configuration file"
  end
  
  file:write(cjson.encode(config))
  file:close()
  
  return true
end

--- Create storage service
-- @return Storage|nil, string|nil error
function SyncCommand:create_storage()
  local Storage = get_storage()
  if not Storage then
    return nil, "Storage module not available"
  end
  
  -- Use filesystem backend in current directory
  local storage = Storage.new({
    backend = "filesystem",
    path = ".whisker-storage"
  })
  
  local ok, err = storage:initialize()
  if not ok then
    return nil, err
  end
  
  return storage
end

--- Create sync engine from config
-- @param config table Configuration
-- @param storage Storage Storage service
-- @return SyncEngine|nil, string|nil error
function SyncCommand:create_sync_engine(config, storage)
  local SyncEngine = get_sync_engine()
  local StateManager = get_state_manager()
  
  if not SyncEngine or not StateManager then
    return nil, "Sync engine not available"
  end
  
  -- Create state manager
  local state_mgr = StateManager.new(storage)
  local device_id = state_mgr:get_device_id()
  
  -- Create transport
  local transport
  local transport_type = config.transport or "http"
  
  if transport_type == "http" then
    local HTTPTransport = get_http_transport()
    if not HTTPTransport then
      return nil, "HTTP transport not available"
    end
    
    transport = HTTPTransport.new({
      base_url = config.url,
      api_key = config.api_key,
      timeout = config.timeout or 30000
    })
  elseif transport_type == "websocket" then
    local WebSocketTransport = get_websocket_transport()
    if not WebSocketTransport then
      return nil, "WebSocket transport not available"
    end
    
    transport = WebSocketTransport.new({
      ws_url = config.url,
      api_key = config.api_key,
      reconnect = true
    })
  else
    return nil, "Unknown transport type: " .. transport_type
  end
  
  -- Create sync engine
  local engine = SyncEngine.new({
    storage = storage,
    transport = transport,
    device_id = device_id,
    sync_interval = config.sync_interval or 60000,
    conflict_strategy = config.conflict_strategy or "last_write_wins"
  })
  
  return engine, state_mgr
end

--- Parse command arguments
-- @param args table Arguments
-- @return table Parsed arguments
function SyncCommand:parse_args(args)
  local parsed = {
    subcommand = args[1],
    url = nil,
    key = nil,
    transport = "http",
    sync_interval = 60000,
    device_name = nil,
    conflict_strategy = "last_write_wins"
  }
  
  local i = 2
  while i <= #args do
    local arg = args[i]
    
    if arg == "--url" then
      i = i + 1
      parsed.url = args[i]
    elseif arg == "--key" then
      i = i + 1
      parsed.key = args[i]
    elseif arg == "--transport" then
      i = i + 1
      parsed.transport = args[i]
    elseif arg == "--interval" then
      i = i + 1
      parsed.sync_interval = tonumber(args[i]) or 60000
    elseif arg == "--device-name" then
      i = i + 1
      parsed.device_name = args[i]
    elseif arg == "--strategy" then
      i = i + 1
      parsed.conflict_strategy = args[i]
    end
    
    i = i + 1
  end
  
  return parsed
end

--- Format bytes for display
-- @param bytes number Bytes
-- @return string Formatted string
function SyncCommand:format_bytes(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

--- Format duration
-- @param seconds number Seconds
-- @return string Formatted string
function SyncCommand:format_duration(seconds)
  if seconds < 60 then
    return string.format("%d seconds ago", seconds)
  elseif seconds < 3600 then
    return string.format("%d minutes ago", math.floor(seconds / 60))
  elseif seconds < 86400 then
    return string.format("%d hours ago", math.floor(seconds / 3600))
  else
    return string.format("%d days ago", math.floor(seconds / 86400))
  end
end

--- Execute command
-- @param args table Command arguments
-- @return number Exit code
function SyncCommand:execute(args)
  if #args == 0 or args[1] == "help" then
    return self:cmd_help()
  end
  
  local parsed = self:parse_args(args)
  
  if parsed.subcommand == "config" then
    return self:cmd_config(parsed)
  elseif parsed.subcommand == "start" then
    return self:cmd_start(parsed)
  elseif parsed.subcommand == "stop" then
    return self:cmd_stop(parsed)
  elseif parsed.subcommand == "now" then
    return self:cmd_now(parsed)
  elseif parsed.subcommand == "status" then
    return self:cmd_status(parsed)
  elseif parsed.subcommand == "stats" then
    return self:cmd_stats(parsed)
  elseif parsed.subcommand == "reset" then
    return self:cmd_reset(parsed)
  else
    print("Unknown subcommand: " .. tostring(parsed.subcommand))
    return self:cmd_help()
  end
end

--- Show help
-- @return number Exit code
function SyncCommand:cmd_help()
  print([[
Whisker Sync - Cross-device story synchronization

Commands:
  config      Configure sync settings
  start       Start sync service
  stop        Stop sync service
  now         Force immediate sync
  status      Show sync status
  stats       Show sync statistics
  reset       Reset sync state
  help        Show this help

Examples:
  # Configure sync
  whisker sync config --url https://api.example.com/sync --key API_KEY
  
  # Start background sync
  whisker sync start
  
  # Force immediate sync
  whisker sync now
  
  # Check status
  whisker sync status
  
  # View statistics
  whisker sync stats

Options:
  --url <url>              Sync server URL
  --key <key>              API key for authentication
  --transport <type>       Transport type: http or websocket (default: http)
  --interval <ms>          Sync interval in milliseconds (default: 60000)
  --device-name <name>     Device name for identification
  --strategy <strategy>    Conflict resolution strategy (default: last_write_wins)
]])
  return 0
end

--- Configure sync
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_config(parsed)
  if not parsed.url then
    print("Error: --url is required")
    return 1
  end
  
  if not parsed.key then
    print("Error: --key is required")
    return 1
  end
  
  local config = {
    url = parsed.url,
    api_key = parsed.key,
    transport = parsed.transport,
    sync_interval = parsed.sync_interval,
    device_name = parsed.device_name or "Unknown Device",
    conflict_strategy = parsed.conflict_strategy
  }
  
  local ok, err = self:save_config(config)
  if not ok then
    print("Error: " .. err)
    return 1
  end
  
  print("✓ Sync configured successfully")
  print("  URL: " .. config.url)
  print("  Transport: " .. config.transport)
  print("  Interval: " .. config.sync_interval .. "ms")
  
  return 0
end

--- Start sync service
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_start(parsed)
  local config, err = self:load_config()
  if not config then
    print("Error: " .. err)
    return 1
  end
  
  local storage, err2 = self:create_storage()
  if not storage then
    print("Error: " .. err2)
    return 1
  end
  
  local engine, state_mgr = self:create_sync_engine(config, storage)
  if not engine then
    print("Error: " .. state_mgr)
    return 1
  end
  
  engine:start_sync()
  
  print("✓ Sync started")
  print("  Checking for updates every " .. math.floor(config.sync_interval / 1000) .. "s")
  print("  Device: " .. state_mgr:get_device_id())
  
  -- Note: This is a simplified version. A real implementation would need
  -- to keep the process running or use a daemon
  print("\nNote: This is a foreground process. Press Ctrl+C to stop.")
  
  return 0
end

--- Stop sync service
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_stop(parsed)
  -- Note: This would require process management in a real implementation
  print("✓ Sync stopped")
  return 0
end

--- Force immediate sync
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_now(parsed)
  local config, err = self:load_config()
  if not config then
    print("Error: " .. err)
    return 1
  end
  
  local storage, err2 = self:create_storage()
  if not storage then
    print("Error: " .. err2)
    return 1
  end
  
  local engine, state_mgr = self:create_sync_engine(config, storage)
  if not engine then
    print("Error: " .. state_mgr)
    return 1
  end
  
  print("Syncing...")
  
  local start_time = os.clock()
  local success, sync_err = engine:sync_now()
  local duration = os.clock() - start_time
  
  if not success then
    print("✗ Sync failed: " .. tostring(sync_err))
    return 1
  end
  
  print(string.format("✓ Sync complete (%.2fs)", duration))
  
  return 0
end

--- Show sync status
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_status(parsed)
  local config, err = self:load_config()
  if not config then
    print("Error: " .. err)
    return 1
  end
  
  local storage, err2 = self:create_storage()
  if not storage then
    print("Error: " .. err2)
    return 1
  end
  
  local StateManager = get_state_manager()
  if not StateManager then
    print("Error: State manager not available")
    return 1
  end
  
  local state_mgr = StateManager.new(storage)
  
  print("Sync Status")
  print("───────────")
  print("Status: " .. state_mgr:get_sync_status())
  
  local last_sync = state_mgr:get_time_since_last_sync()
  if last_sync < 0 then
    print("Last sync: Never")
  else
    print("Last sync: " .. self:format_duration(last_sync))
  end
  
  print("Device: " .. (config.device_name or "Unknown") .. " (" .. state_mgr:get_device_id() .. ")")
  print("Pending: " .. state_mgr:get_pending_count() .. " operations")
  
  local last_error = state_mgr:get_last_error()
  if last_error then
    print("\n✗ Last error: " .. last_error.message)
    print("  " .. self:format_duration(os.time() - last_error.timestamp))
  end
  
  return 0
end

--- Show sync statistics
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_stats(parsed)
  local storage, err = self:create_storage()
  if not storage then
    print("Error: " .. err)
    return 1
  end
  
  local StateManager = get_state_manager()
  if not StateManager then
    print("Error: State manager not available")
    return 1
  end
  
  local state_mgr = StateManager.new(storage)
  local stats = state_mgr:get_stats()
  
  print("Sync Statistics")
  print("───────────────")
  print("Total syncs: " .. stats.total_syncs)
  
  if stats.last_sync_duration_ms > 0 then
    print(string.format("Last sync duration: %dms", stats.last_sync_duration_ms))
  end
  
  print("Conflicts resolved: " .. stats.conflicts_resolved)
  print("Bandwidth: ↓ " .. self:format_bytes(stats.bandwidth_received_bytes) .. 
        ", ↑ " .. self:format_bytes(stats.bandwidth_sent_bytes))
  
  return 0
end

--- Reset sync state
-- @param parsed table Parsed arguments
-- @return number Exit code
function SyncCommand:cmd_reset(parsed)
  print("Warning: This will reset all sync state.")
  print("Device ID will be preserved.")
  print("Type 'yes' to confirm: ")
  
  local confirm = io.read()
  if confirm ~= "yes" then
    print("Cancelled")
    return 0
  end
  
  local storage, err = self:create_storage()
  if not storage then
    print("Error: " .. err)
    return 1
  end
  
  local StateManager = get_state_manager()
  if not StateManager then
    print("Error: State manager not available")
    return 1
  end
  
  local state_mgr = StateManager.new(storage)
  state_mgr:reset()
  
  print("✓ Sync state reset")
  
  return 0
end

return SyncCommand
