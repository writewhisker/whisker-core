--- Tests for WebSocket Transport Adapter
-- @module tests.storage.sync.transports.websocket_spec

local WebSocketTransport = require("whisker.storage.sync.transports.websocket")
local json = require("cjson")

-- Mock WebSocket Client
local MockWebSocket = {}
MockWebSocket.__index = MockWebSocket

function MockWebSocket.new()
  local self = setmetatable({}, MockWebSocket)
  self.connected = false
  self.sent_messages = {}
  self.receive_queue = {}
  self.url = nil
  return self
end

function MockWebSocket:connect(url)
  self.url = url
  self.connected = true
end

function MockWebSocket:send(message)
  table.insert(self.sent_messages, message)
end

function MockWebSocket:receive()
  if #self.receive_queue > 0 then
    return table.remove(self.receive_queue, 1)
  end
  return nil
end

function MockWebSocket:close()
  self.connected = false
end

-- Helper to queue responses
function MockWebSocket:queue_response(response_data)
  local json_str = json.encode(response_data)
  table.insert(self.receive_queue, json_str)
end

-- Helper to get last sent message
function MockWebSocket:get_last_sent()
  if #self.sent_messages > 0 then
    local message = self.sent_messages[#self.sent_messages]
    return json.decode(message)
  end
  return nil
end

describe("WebSocketTransport", function()
  local transport
  local mock_ws
  local mock_config
  
  before_each(function()
    mock_ws = MockWebSocket.new()
    
    mock_config = {
      ws_url = "wss://api.example.com/sync",
      api_key = "test-api-key-12345",
      reconnect = false,  -- Disable for testing
      ping_interval = 30,
      response_timeout = 2,
      websocket_client = mock_ws
    }
  end)
  
  describe("new", function()
    it("should create new WebSocket transport with valid config", function()
      transport = WebSocketTransport.new(mock_config)
      
      assert.is_not_nil(transport)
      assert.equals("wss://api.example.com/sync", transport.ws_url)
      assert.equals("test-api-key-12345", transport.api_key)
      assert.is_false(transport.reconnect)
      assert.equals(30, transport.ping_interval)
      assert.equals(2, transport.response_timeout)
    end)
    
    it("should use default values", function()
      local minimal_config = {
        ws_url = "ws://test.com",
        api_key = "key123",
        websocket_client = mock_ws
      }
      
      transport = WebSocketTransport.new(minimal_config)
      
      assert.is_true(transport.reconnect)
      assert.equals(30, transport.ping_interval)
      assert.equals(5, transport.response_timeout)
      assert.equals(30, transport.max_reconnect_delay)
    end)
    
    it("should require ws_url", function()
      assert.has_error(function()
        WebSocketTransport.new({ api_key = "key", websocket_client = mock_ws })
      end, "ws_url is required")
    end)
    
    it("should require api_key", function()
      assert.has_error(function()
        WebSocketTransport.new({ ws_url = "ws://test.com", websocket_client = mock_ws })
      end, "api_key is required")
    end)
  end)
  
  describe("connect", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
    end)
    
    it("should connect and authenticate successfully", function()
      -- Queue AUTH_OK response
      mock_ws:queue_response({ type = "auth_ok" })
      
      local success, err = transport:connect()
      
      assert.is_true(success)
      assert.is_nil(err)
      assert.is_true(transport.connected)
      assert.is_true(transport.authenticated)
      assert.is_true(mock_ws.connected)
    end)
    
    it("should send authentication message", function()
      mock_ws:queue_response({ type = "auth_ok" })
      
      transport:connect()
      
      local auth_msg = mock_ws:get_last_sent()
      assert.equals("auth", auth_msg.type)
      assert.equals("test-api-key-12345", auth_msg.api_key)
    end)
    
    it("should handle authentication failure", function()
      mock_ws:queue_response({ type = "auth_failed", reason = "Invalid API key" })
      
      local success, err = transport:connect()
      
      assert.is_nil(success)
      assert.is_not_nil(err)
      assert.is_not_nil(err:match("Authentication failed"))
      assert.is_false(transport.connected)
      assert.is_false(transport.authenticated)
    end)
    
    it("should return error if already connected", function()
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      
      local success, msg = transport:connect()
      
      assert.is_true(success)
      assert.equals("Already connected", msg)
    end)
  end)
  
  describe("disconnect", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
    end)
    
    it("should disconnect from server", function()
      transport:disconnect()
      
      assert.is_false(transport.connected)
      assert.is_false(transport.authenticated)
      assert.is_false(mock_ws.connected)
    end)
    
    it("should emit disconnected event", function()
      local disconnected_called = false
      
      transport:on("disconnected", function(data)
        disconnected_called = true
        assert.equals("Manual disconnect", data.reason)
      end)
      
      transport:disconnect()
      
      assert.is_true(disconnected_called)
    end)
  end)
  
  describe("event handling", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
    end)
    
    it("should register and call event handlers", function()
      local called = false
      local event_data = nil
      
      transport:on("connected", function(data)
        called = true
        event_data = data
      end)
      
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      
      assert.is_true(called)
      assert.is_not_nil(event_data)
      assert.equals("wss://api.example.com/sync", event_data.ws_url)
    end)
    
    it("should support multiple handlers for same event", function()
      local count = 0
      
      transport:on("connected", function() count = count + 1 end)
      transport:on("connected", function() count = count + 1 end)
      
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      
      assert.equals(2, count)
    end)
  end)
  
  describe("_serialize and _deserialize", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
    end)
    
    it("should serialize Lua table to JSON", function()
      local data = {
        type = "sync_request",
        device_id = "device-123",
        since_version = 5
      }
      
      local json_str = transport:_serialize(data)
      
      assert.is_string(json_str)
      assert.is_not_nil(json_str:match('"type"'))
      assert.is_not_nil(json_str:match('"sync_request"'))
    end)
    
    it("should deserialize JSON to Lua table", function()
      local json_str = '{"type":"sync_response","version":10,"operations":[]}'
      
      local data, err = transport:_deserialize(json_str)
      
      assert.is_nil(err)
      assert.is_table(data)
      assert.equals("sync_response", data.type)
      assert.equals(10, data.version)
    end)
    
    it("should handle deserialization errors", function()
      local data, err = transport:_deserialize("{invalid json")
      
      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_not_nil(err:match("Failed to deserialize"))
    end)
  end)
  
  describe("fetch_operations", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
    end)
    
    it("should fetch operations successfully", function()
      -- Queue sync response
      mock_ws:queue_response({
        type = "sync_response",
        operations = {
          { type = "create", id = "story-1" }
        },
        version = 10,
        has_more = false
      })
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals(10, result.version)
      assert.is_table(result.operations)
      assert.equals(1, #result.operations)
      assert.is_false(result.has_more)
    end)
    
    it("should send sync request message", function()
      mock_ws:queue_response({
        type = "sync_response",
        operations = {},
        version = 0
      })
      
      transport:fetch_operations("device-123", 5)
      
      local sent_msg = mock_ws:get_last_sent()
      assert.equals("sync_request", sent_msg.type)
      assert.equals("device-123", sent_msg.device_id)
      assert.equals(5, sent_msg.since_version)
      assert.is_number(sent_msg.request_id)
    end)
    
    it("should use default since_version of 0", function()
      mock_ws:queue_response({
        type = "sync_response",
        operations = {},
        version = 0
      })
      
      transport:fetch_operations("device-123")
      
      local sent_msg = mock_ws:get_last_sent()
      assert.equals(0, sent_msg.since_version)
    end)
    
    it("should require device_id", function()
      local result, err = transport:fetch_operations(nil, 5)
      
      assert.is_nil(result)
      assert.equals("device_id is required", err)
    end)
    
    it("should handle timeout", function()
      -- Don't queue any response
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(result)
      assert.is_not_nil(err:match("timeout"))
    end)
    
    it("should validate response structure", function()
      mock_ws:queue_response({
        type = "sync_response",
        invalid = "response"
      })
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(result)
      assert.is_not_nil(err:match("missing operations"))
    end)
  end)
  
  describe("push_operations", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
    end)
    
    it("should push operations successfully", function()
      local operations = {
        { type = "create", id = "story-1", data = { title = "Test" } }
      }
      
      mock_ws:queue_response({
        type = "push_response",
        success = true,
        conflicts = {},
        version = 11
      })
      
      local result, err = transport:push_operations("device-123", operations)
      
      assert.is_nil(err)
      assert.is_true(result.success)
      assert.equals(11, result.version)
      assert.equals(0, #result.conflicts)
    end)
    
    it("should send push_operations message", function()
      mock_ws:queue_response({
        type = "push_response",
        success = true,
        conflicts = {},
        version = 11
      })
      
      local operations = {
        { type = "create", id = "story-1" }
      }
      
      transport:push_operations("device-123", operations)
      
      local sent_msg = mock_ws:get_last_sent()
      assert.equals("push_operations", sent_msg.type)
      assert.equals("device-123", sent_msg.device_id)
      assert.is_table(sent_msg.operations)
      assert.equals(1, #sent_msg.operations)
    end)
    
    it("should require device_id", function()
      local result, err = transport:push_operations(nil, {})
      
      assert.is_nil(result)
      assert.equals("device_id is required", err)
    end)
    
    it("should require operations to be a table", function()
      local result, err = transport:push_operations("device-123", "invalid")
      
      assert.is_nil(result)
      assert.equals("operations must be a table", err)
    end)
    
    it("should handle conflicts", function()
      mock_ws:queue_response({
        type = "push_response",
        success = false,
        conflicts = {
          { id = "story-1", type = "concurrent_modification" }
        },
        version = 11
      })
      
      local result, err = transport:push_operations("device-123", {})
      
      assert.is_nil(err)
      assert.is_false(result.success)
      assert.equals(1, #result.conflicts)
    end)
  end)
  
  describe("remote change notifications", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
    end)
    
    it("should emit remote_change event", function()
      local change_received = false
      local operation = nil
      
      transport:on("remote_change", function(data)
        change_received = true
        operation = data.operation
      end)
      
      -- Queue remote change followed by sync response (to exit wait loop)
      mock_ws:queue_response({
        type = "remote_change",
        operation = { type = "update", id = "story-1" }
      })
      mock_ws:queue_response({
        type = "sync_response",
        operations = {},
        version = 5
      })
      
      transport:fetch_operations("device-123", 0)
      
      assert.is_true(change_received)
      assert.is_table(operation)
      assert.equals("update", operation.type)
    end)
  end)
  
  describe("is_connected", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
    end)
    
    it("should return false when not connected", function()
      assert.is_false(transport:is_connected())
    end)
    
    it("should return true when connected and authenticated", function()
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      
      assert.is_true(transport:is_connected())
    end)
    
    it("should return false after disconnect", function()
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      transport:disconnect()
      
      assert.is_false(transport:is_connected())
    end)
  end)
  
  describe("is_available", function()
    it("should return true when websocket client is provided", function()
      transport = WebSocketTransport.new(mock_config)
      assert.is_true(transport:is_available())
    end)
  end)
  
  describe("get_info", function()
    before_each(function()
      transport = WebSocketTransport.new(mock_config)
    end)
    
    it("should return transport information", function()
      local info = transport:get_info()
      
      assert.equals("websocket", info.type)
      assert.equals("wss://api.example.com/sync", info.ws_url)
      assert.is_false(info.connected)
      assert.is_false(info.authenticated)
      assert.is_false(info.reconnect)
      assert.equals(30, info.ping_interval)
      assert.is_true(info.websocket_available)
    end)
    
    it("should reflect connected state", function()
      mock_ws:queue_response({ type = "auth_ok" })
      transport:connect()
      
      local info = transport:get_info()
      
      assert.is_true(info.connected)
      assert.is_true(info.authenticated)
    end)
  end)
end)
