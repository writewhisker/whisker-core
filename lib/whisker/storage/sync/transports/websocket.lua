--- WebSocket Transport Adapter for Sync Engine
-- Provides WebSocket transport for real-time cross-device synchronization
--
-- @module whisker.storage.sync.transports.websocket
-- @author Whisker Team
-- @license MIT
-- @usage
-- local WebSocketTransport = require("whisker.storage.sync.transports.websocket")
-- local transport = WebSocketTransport.new({
--   ws_url = "wss://api.example.com/sync",
--   api_key = "your-api-key",
--   reconnect = true,
--   ping_interval = 30
-- })
-- transport:connect()
-- local result = transport:fetch_operations("device-123", 5)

local json = require("cjson")
local socket = require("socket")

-- Try to load WebSocket library (optional - can be injected for testing)
local websocket_available, websocket = pcall(require, "websocket")

local WebSocketTransport = {}
WebSocketTransport.__index = WebSocketTransport

--- Message types
WebSocketTransport.MessageType = {
  SYNC_REQUEST = "sync_request",
  SYNC_RESPONSE = "sync_response",
  PUSH_OPERATIONS = "push_operations",
  PUSH_RESPONSE = "push_response",
  REMOTE_CHANGE = "remote_change",
  PING = "ping",
  PONG = "pong",
  AUTH = "auth",
  AUTH_OK = "auth_ok",
  AUTH_FAILED = "auth_failed",
  ERROR = "error"
}

--- Create a new WebSocket transport
-- @param config Configuration table with the following fields:
--   - ws_url (string): WebSocket endpoint (e.g., "wss://api.example.com/sync")
--   - api_key (string): Authentication token
--   - reconnect (boolean): Auto-reconnect on disconnect (default: true)
--   - ping_interval (number): Keep-alive ping interval in seconds (default: 30)
--   - response_timeout (number): Timeout for responses in seconds (default: 5)
--   - max_reconnect_delay (number): Maximum reconnect delay in seconds (default: 30)
--   - websocket_client (table): Optional WebSocket client (for testing)
-- @return WebSocketTransport instance
function WebSocketTransport.new(config)
  local self = setmetatable({}, WebSocketTransport)
  
  self.ws_url = config.ws_url or error("ws_url is required")
  self.api_key = config.api_key or error("api_key is required")
  self.reconnect = config.reconnect ~= false  -- default true
  self.ping_interval = config.ping_interval or 30
  self.response_timeout = config.response_timeout or 5
  self.max_reconnect_delay = config.max_reconnect_delay or 30
  
  -- WebSocket client (can be injected for testing)
  self.websocket_client = config.websocket_client
  
  -- Connection state
  self.ws = nil
  self.connected = false
  self.authenticated = false
  self.reconnect_attempt = 0
  self.last_pong = nil
  self.ping_timer = nil
  
  -- Response handling
  self.pending_responses = {}  -- {request_id -> {callback, timeout}}
  self.next_request_id = 1
  
  -- Event handlers
  self.event_handlers = {}
  
  return self
end

--- Register event handler
-- @param event Event name
-- @param handler Handler function
function WebSocketTransport:on(event, handler)
  if not self.event_handlers[event] then
    self.event_handlers[event] = {}
  end
  table.insert(self.event_handlers[event], handler)
end

--- Emit event
-- @param event Event name
-- @param data Event data
function WebSocketTransport:_emit(event, data)
  local handlers = self.event_handlers[event]
  if handlers then
    for _, handler in ipairs(handlers) do
      pcall(handler, data)
    end
  end
end

--- Serialize data to JSON
-- @param data Lua table to serialize
-- @return JSON string or nil, error
function WebSocketTransport:_serialize(data)
  local success, result = pcall(json.encode, data)
  if not success then
    return nil, "Failed to serialize JSON: " .. tostring(result)
  end
  return result
end

--- Deserialize JSON to Lua table
-- @param json_string JSON string to deserialize
-- @return Lua table or nil, error
function WebSocketTransport:_deserialize(json_string)
  if not json_string or json_string == "" then
    return nil, "Empty message"
  end
  
  local success, result = pcall(json.decode, json_string)
  if not success then
    return nil, "Failed to deserialize JSON: " .. tostring(result)
  end
  return result
end

--- Connect to WebSocket server
-- @return boolean success, string error
function WebSocketTransport:connect()
  if self.connected then
    return true, "Already connected"
  end
  
  -- Create WebSocket client
  if not self.websocket_client then
    if not websocket_available then
      return nil, "WebSocket library not available"
    end
    
    -- Use real WebSocket library
    local ws, err = websocket.client.sync()
    if not ws then
      return nil, "Failed to create WebSocket client: " .. tostring(err)
    end
    self.ws = ws
  else
    -- Use injected client (for testing)
    self.ws = self.websocket_client
  end
  
  -- Connect
  local success, err = pcall(function()
    self.ws:connect(self.ws_url)
  end)
  
  if not success then
    self.reconnect_attempt = self.reconnect_attempt + 1
    if self.reconnect then
      self:_schedule_reconnect()
    end
    return nil, "Connection failed: " .. tostring(err)
  end
  
  self.connected = true
  self.reconnect_attempt = 0
  self:_emit("connected", { ws_url = self.ws_url })
  
  -- Authenticate
  local auth_success, auth_err = self:_authenticate()
  if not auth_success then
    self:disconnect()
    return nil, auth_err
  end
  
  -- Start keep-alive
  self:_start_keepalive()
  
  -- Start message loop (non-blocking)
  self:_start_message_loop()
  
  return true
end

--- Authenticate with server
-- @return boolean success, string error
function WebSocketTransport:_authenticate()
  local auth_message = {
    type = WebSocketTransport.MessageType.AUTH,
    api_key = self.api_key
  }
  
  local json_str, err = self:_serialize(auth_message)
  if not json_str then
    return nil, err
  end
  
  self.ws:send(json_str)
  
  -- Wait for AUTH_OK or AUTH_FAILED
  local start_time = os.time()
  while os.time() - start_time < self.response_timeout do
    local message = self.ws:receive()
    if message then
      local data, parse_err = self:_deserialize(message)
      if data then
        if data.type == WebSocketTransport.MessageType.AUTH_OK then
          self.authenticated = true
          return true
        elseif data.type == WebSocketTransport.MessageType.AUTH_FAILED then
          return nil, "Authentication failed: " .. (data.reason or "Unknown")
        end
      end
    end
    socket.sleep(0.1)
  end
  
  return nil, "Authentication timeout"
end

--- Disconnect from WebSocket server
function WebSocketTransport:disconnect()
  if not self.connected then
    return
  end
  
  self:_stop_keepalive()
  
  if self.ws then
    pcall(function() self.ws:close() end)
    self.ws = nil
  end
  
  self.connected = false
  self.authenticated = false
  self:_emit("disconnected", { reason = "Manual disconnect" })
end

--- Schedule reconnection
function WebSocketTransport:_schedule_reconnect()
  local delay = math.min(2 ^ (self.reconnect_attempt - 1), self.max_reconnect_delay)
  
  self:_emit("reconnecting", {
    attempt = self.reconnect_attempt,
    delay = delay
  })
  
  -- Schedule reconnect (simplified - in production, use proper timer)
  socket.sleep(delay)
  self:connect()
end

--- Start keep-alive ping/pong
function WebSocketTransport:_start_keepalive()
  self.last_pong = os.time()
  
  -- In a real implementation, this would use a proper timer
  -- For now, we'll check in the message loop
end

--- Stop keep-alive
function WebSocketTransport:_stop_keepalive()
  self.last_pong = nil
end

--- Start message loop (non-blocking)
function WebSocketTransport:_start_message_loop()
  -- In a real implementation, this would run in a coroutine or thread
  -- For now, messages are processed synchronously in wait_for_response
end

--- Send ping
function WebSocketTransport:_send_ping()
  if not self.connected then
    return
  end
  
  local ping_message = {
    type = WebSocketTransport.MessageType.PING
  }
  
  local json_str = self:_serialize(ping_message)
  if json_str then
    self.ws:send(json_str)
  end
end

--- Check if keep-alive timeout
-- @return boolean
function WebSocketTransport:_is_keepalive_timeout()
  if not self.last_pong then
    return false
  end
  
  return (os.time() - self.last_pong) > (self.ping_interval * 2)
end

--- Send message
-- @param message_type Message type
-- @param data Message data
-- @param request_id Optional request ID
-- @return boolean success, string error
function WebSocketTransport:_send(message_type, data, request_id)
  if not self.connected or not self.authenticated then
    return nil, "Not connected or not authenticated"
  end
  
  local message = {
    type = message_type
  }
  
  if request_id then
    message.request_id = request_id
  end
  
  -- Merge data into message
  for k, v in pairs(data or {}) do
    message[k] = v
  end
  
  local json_str, err = self:_serialize(message)
  if not json_str then
    return nil, err
  end
  
  local success, send_err = pcall(function()
    self.ws:send(json_str)
  end)
  
  if not success then
    return nil, "Send failed: " .. tostring(send_err)
  end
  
  return true
end

--- Wait for response
-- @param expected_type Expected message type
-- @param timeout Timeout in seconds
-- @return table response or nil, string error
function WebSocketTransport:_wait_for_response(expected_type, timeout)
  local start_time = os.time()
  
  while os.time() - start_time < timeout do
    -- Check keep-alive
    if (os.time() - (self.last_pong or os.time())) > self.ping_interval then
      self:_send_ping()
    end
    
    -- Receive message
    local message = self.ws:receive()
    if message then
      local data, err = self:_deserialize(message)
      if data then
        self:_emit("message_received", { type = data.type, data = data })
        
        -- Handle pong
        if data.type == WebSocketTransport.MessageType.PONG then
          self.last_pong = os.time()
        
        -- Handle remote change
        elseif data.type == WebSocketTransport.MessageType.REMOTE_CHANGE then
          self:_emit("remote_change", { operation = data.operation })
        
        -- Handle error
        elseif data.type == WebSocketTransport.MessageType.ERROR then
          return nil, data.error or "Unknown error"
        
        -- Handle expected response
        elseif data.type == expected_type then
          return data
        end
      end
    end
    
    socket.sleep(0.1)
  end
  
  return nil, "Response timeout"
end

--- Fetch operations from server
-- @param device_id Unique device identifier
-- @param since_version Version to fetch operations since
-- @return Table {operations = [], version = number, has_more = boolean} or nil, error
function WebSocketTransport:fetch_operations(device_id, since_version)
  if not device_id then
    return nil, "device_id is required"
  end
  
  since_version = since_version or 0
  
  local request_id = self.next_request_id
  self.next_request_id = self.next_request_id + 1
  
  local success, err = self:_send(
    WebSocketTransport.MessageType.SYNC_REQUEST,
    {
      device_id = device_id,
      since_version = since_version
    },
    request_id
  )
  
  if not success then
    return nil, err
  end
  
  local response, wait_err = self:_wait_for_response(
    WebSocketTransport.MessageType.SYNC_RESPONSE,
    self.response_timeout
  )
  
  if not response then
    return nil, wait_err
  end
  
  -- Validate response
  if type(response.operations) ~= "table" then
    return nil, "Invalid response: missing operations array"
  end
  
  if type(response.version) ~= "number" then
    return nil, "Invalid response: missing version number"
  end
  
  return {
    operations = response.operations,
    version = response.version,
    has_more = response.has_more or false
  }
end

--- Push operations to server
-- @param device_id Unique device identifier
-- @param operations Array of operations to push
-- @return Table {success = boolean, conflicts = [], version = number} or nil, error
function WebSocketTransport:push_operations(device_id, operations)
  if not device_id then
    return nil, "device_id is required"
  end
  
  if type(operations) ~= "table" then
    return nil, "operations must be a table"
  end
  
  local request_id = self.next_request_id
  self.next_request_id = self.next_request_id + 1
  
  local success, err = self:_send(
    WebSocketTransport.MessageType.PUSH_OPERATIONS,
    {
      device_id = device_id,
      operations = operations
    },
    request_id
  )
  
  if not success then
    return nil, err
  end
  
  local response, wait_err = self:_wait_for_response(
    WebSocketTransport.MessageType.PUSH_RESPONSE,
    self.response_timeout
  )
  
  if not response then
    return nil, wait_err
  end
  
  return {
    success = response.success or false,
    conflicts = response.conflicts or {},
    version = response.version or 0
  }
end

--- Get current server version
-- @param device_id Unique device identifier
-- @return Table {version = number} or nil, error
function WebSocketTransport:get_server_version(device_id)
  -- WebSocket uses real-time sync, version is tracked automatically
  -- For compatibility, we can fetch it via sync request with no operations
  return self:fetch_operations(device_id, 0)
end

--- Check if connection is active
-- @return boolean
function WebSocketTransport:is_connected()
  return self.connected and self.authenticated
end

--- Check if transport is available
-- @return boolean
function WebSocketTransport:is_available()
  return websocket_available or self.websocket_client ~= nil
end

--- Get transport info
-- @return Table with transport information
function WebSocketTransport:get_info()
  return {
    type = "websocket",
    ws_url = self.ws_url,
    connected = self.connected,
    authenticated = self.authenticated,
    reconnect = self.reconnect,
    ping_interval = self.ping_interval,
    websocket_available = websocket_available or self.websocket_client ~= nil
  }
end

return WebSocketTransport
