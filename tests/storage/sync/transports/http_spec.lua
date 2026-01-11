--- Tests for HTTP Transport Adapter
-- @module tests.storage.sync.transports.http_spec

local HTTPTransport = require("whisker.storage.sync.transports.http")

describe("HTTPTransport", function()
  local transport
  local mock_config
  
  before_each(function()
    mock_config = {
      base_url = "http://localhost:8080/api/sync",
      api_key = "test-api-key-12345",
      timeout = 10,
      max_retries = 2,
      retry_delay = 0.1
    }
  end)
  
  describe("new", function()
    it("should create new HTTP transport with valid config", function()
      transport = HTTPTransport.new(mock_config)
      
      assert.is_not_nil(transport)
      assert.equals("http://localhost:8080/api/sync", transport.base_url)
      assert.equals("test-api-key-12345", transport.api_key)
      assert.equals(10, transport.timeout)
      assert.equals(2, transport.max_retries)
      assert.is_false(transport.is_https)
    end)
    
    it("should detect HTTPS URLs", function()
      mock_config.base_url = "https://api.example.com/sync"
      
      -- Skip this test if luasec is not available
      local https_available = pcall(require, "ssl.https")
      if not https_available then
        pending("luasec not available")
        return
      end
      
      transport = HTTPTransport.new(mock_config)
      assert.is_true(transport.is_https)
    end)
    
    it("should use default values", function()
      local minimal_config = {
        base_url = "http://api.test.com",
        api_key = "key123"
      }
      
      transport = HTTPTransport.new(minimal_config)
      
      assert.equals(30, transport.timeout)
      assert.equals(3, transport.max_retries)
      assert.equals(1, transport.retry_delay)
      assert.equals("Whisker-Sync/1.0", transport.user_agent)
    end)
    
    it("should require base_url", function()
      assert.has_error(function()
        HTTPTransport.new({ api_key = "key" })
      end, "base_url is required")
    end)
    
    it("should require api_key", function()
      assert.has_error(function()
        HTTPTransport.new({ base_url = "http://test.com" })
      end, "api_key is required")
    end)
  end)
  
  describe("_serialize", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should serialize Lua table to JSON", function()
      local data = {
        device_id = "device-123",
        operations = {
          { type = "create", id = "story-1" }
        }
      }
      
      local json_str = transport:_serialize(data)
      
      assert.is_string(json_str)
      assert.is_not_nil(json_str:match('"device_id"'))
      assert.is_not_nil(json_str:match('"device%-123"'))
    end)
    
    it("should handle empty table", function()
      local json_str = transport:_serialize({})
      assert.equals("{}", json_str)
    end)
    
    it("should handle nested tables", function()
      local data = {
        level1 = {
          level2 = {
            value = 42
          }
        }
      }
      
      local json_str = transport:_serialize(data)
      assert.is_string(json_str)
    end)
  end)
  
  describe("_deserialize", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should deserialize JSON to Lua table", function()
      local json_str = '{"version":5,"operations":[]}'
      
      local data, err = transport:_deserialize(json_str)
      
      assert.is_nil(err)
      assert.is_table(data)
      assert.equals(5, data.version)
      assert.is_table(data.operations)
    end)
    
    it("should handle empty JSON object", function()
      local data, err = transport:_deserialize("{}")
      
      assert.is_nil(err)
      assert.is_table(data)
    end)
    
    it("should return error on invalid JSON", function()
      local data, err = transport:_deserialize("{invalid json")
      
      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.is_not_nil(err:match("Failed to deserialize"))
    end)
    
    it("should return error on empty string", function()
      local data, err = transport:_deserialize("")
      
      assert.is_nil(data)
      assert.is_not_nil(err)
      assert.equals("Empty response body", err)
    end)
    
    it("should return error on nil", function()
      local data, err = transport:_deserialize(nil)
      
      assert.is_nil(data)
      assert.equals("Empty response body", err)
    end)
  end)
  
  describe("_build_headers", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should build GET headers", function()
      local headers = transport:_build_headers("GET")
      
      assert.equals("Whisker-Sync/1.0", headers["User-Agent"])
      assert.equals("Bearer test-api-key-12345", headers["Authorization"])
      assert.equals("application/json", headers["Accept"])
      assert.is_nil(headers["Content-Type"])
    end)
    
    it("should build POST headers with content length", function()
      local headers = transport:_build_headers("POST", 123)
      
      assert.equals("application/json", headers["Content-Type"])
      assert.equals("123", headers["Content-Length"])
      assert.equals("Bearer test-api-key-12345", headers["Authorization"])
    end)
    
    it("should use custom user agent", function()
      mock_config.user_agent = "CustomAgent/2.0"
      transport = HTTPTransport.new(mock_config)
      
      local headers = transport:_build_headers("GET")
      assert.equals("CustomAgent/2.0", headers["User-Agent"])
    end)
  end)
  
  describe("_url_encode", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should encode special characters", function()
      assert.equals("device-123", transport:_url_encode("device-123"))  -- hyphen is allowed
      assert.equals("hello+world", transport:_url_encode("hello world"))
      assert.equals("test%40example.com", transport:_url_encode("test@example.com"))  -- period is allowed
    end)
    
    it("should handle empty string", function()
      assert.equals("", transport:_url_encode(""))
    end)
    
    it("should handle nil", function()
      assert.equals("", transport:_url_encode(nil))
    end)
    
    it("should preserve alphanumeric characters", function()
      assert.equals("abc123", transport:_url_encode("abc123"))
    end)
  end)
  
  describe("fetch_operations", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
      
      -- Mock the _request method
      transport._request_original = transport._request
    end)
    
    after_each(function()
      if transport._request_original then
        transport._request = transport._request_original
      end
    end)
    
    it("should fetch operations successfully", function()
      -- Mock successful response
      transport._request = function(self, method, path, body)
        assert.equals("GET", method)
        assert.is_not_nil(path:match("/operations%?"))
        
        return {
          status = 200,
          body = '{"operations":[{"type":"create","id":"story-1"}],"version":10,"has_more":false}'
        }
      end
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals(10, result.version)
      assert.is_table(result.operations)
      assert.equals(1, #result.operations)
      assert.equals("create", result.operations[1].type)
      assert.is_false(result.has_more)
    end)
    
    it("should use default since_version of 0", function()
      transport._request = function(self, method, path, body)
        assert.is_not_nil(path:match("since=0"))
        return {
          status = 200,
          body = '{"operations":[],"version":0}'
        }
      end
      
      local result, err = transport:fetch_operations("device-123")
      assert.is_nil(err)
    end)
    
    it("should require device_id", function()
      local result, err = transport:fetch_operations(nil, 5)
      
      assert.is_nil(result)
      assert.equals("device_id is required", err)
    end)
    
    it("should handle network errors", function()
      transport._request = function(self, method, path, body)
        return nil, "Connection timeout"
      end
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(result)
      assert.equals("Connection timeout", err)
    end)
    
    it("should handle HTTP errors", function()
      transport._request = function(self, method, path, body)
        return {
          status = 500,
          body = '{"error":"Internal server error"}'
        }
      end
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(result)
      assert.is_not_nil(err:match("500"))
    end)
    
    it("should validate response structure", function()
      transport._request = function(self, method, path, body)
        return {
          status = 200,
          body = '{"invalid":"response"}'
        }
      end
      
      local result, err = transport:fetch_operations("device-123", 5)
      
      assert.is_nil(result)
      assert.is_not_nil(err:match("missing operations"))
    end)
  end)
  
  describe("push_operations", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
      transport._request_original = transport._request
    end)
    
    after_each(function()
      if transport._request_original then
        transport._request = transport._request_original
      end
    end)
    
    it("should push operations successfully", function()
      local operations = {
        { type = "create", id = "story-1", data = { title = "Test" } },
        { type = "update", id = "story-2", data = { title = "Updated" } }
      }
      
      transport._request = function(self, method, path, body)
        assert.equals("POST", method)
        assert.equals("/operations", path)
        assert.is_string(body)
        
        return {
          status = 200,
          body = '{"success":true,"conflicts":[],"version":11}'
        }
      end
      
      local result, err = transport:push_operations("device-123", operations)
      
      assert.is_nil(err)
      assert.is_true(result.success)
      assert.equals(11, result.version)
      assert.is_table(result.conflicts)
      assert.equals(0, #result.conflicts)
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
      transport._request = function(self, method, path, body)
        return {
          status = 200,
          body = '{"success":false,"conflicts":[{"id":"story-1","type":"concurrent_modification"}],"version":11}'
        }
      end
      
      local result, err = transport:push_operations("device-123", {})
      
      assert.is_nil(err)
      assert.is_false(result.success)
      assert.equals(1, #result.conflicts)
    end)
    
    it("should accept 201 status", function()
      transport._request = function(self, method, path, body)
        return {
          status = 201,
          body = '{"success":true,"conflicts":[],"version":12}'
        }
      end
      
      local result, err = transport:push_operations("device-123", {})
      
      assert.is_nil(err)
      assert.is_true(result.success)
    end)
  end)
  
  describe("get_server_version", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
      transport._request_original = transport._request
    end)
    
    after_each(function()
      if transport._request_original then
        transport._request = transport._request_original
      end
    end)
    
    it("should get server version successfully", function()
      transport._request = function(self, method, path, body)
        assert.equals("GET", method)
        assert.is_not_nil(path:match("/version%?"))
        
        return {
          status = 200,
          body = '{"version":42}'
        }
      end
      
      local result, err = transport:get_server_version("device-123")
      
      assert.is_nil(err)
      assert.equals(42, result.version)
    end)
    
    it("should require device_id", function()
      local result, err = transport:get_server_version(nil)
      
      assert.is_nil(result)
      assert.equals("device_id is required", err)
    end)
    
    it("should validate response structure", function()
      transport._request = function(self, method, path, body)
        return {
          status = 200,
          body = '{"invalid":"response"}'
        }
      end
      
      local result, err = transport:get_server_version("device-123")
      
      assert.is_nil(result)
      assert.is_not_nil(err:match("missing version"))
    end)
  end)
  
  describe("is_available", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should return true when modules are available", function()
      assert.is_true(transport:is_available())
    end)
  end)
  
  describe("get_info", function()
    before_each(function()
      transport = HTTPTransport.new(mock_config)
    end)
    
    it("should return transport information", function()
      local info = transport:get_info()
      
      assert.equals("http", info.type)
      assert.equals("http://localhost:8080/api/sync", info.base_url)
      assert.is_false(info.is_https)
      assert.equals(10, info.timeout)
      assert.equals(2, info.max_retries)
      assert.is_boolean(info.https_available)
    end)
  end)
end)
