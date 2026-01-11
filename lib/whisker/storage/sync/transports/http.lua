--- HTTP Transport Adapter for Sync Engine
-- Provides HTTP/HTTPS transport for cross-device synchronization
--
-- @module whisker.storage.sync.transports.http
-- @author Whisker Team
-- @license MIT
-- @usage
-- local HTTPTransport = require("whisker.storage.sync.transports.http")
-- local transport = HTTPTransport.new({
--   base_url = "https://api.example.com/sync",
--   api_key = "your-api-key",
--   timeout = 30
-- })
-- local result = transport:fetch_operations("device-123", 5)

local json = require("cjson")
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Try to load ssl support (optional)
local https_available, https = pcall(require, "ssl.https")

local HTTPTransport = {}
HTTPTransport.__index = HTTPTransport

--- Create a new HTTP transport
-- @param config Configuration table with the following fields:
--   - base_url (string): API endpoint (e.g., "https://api.example.com/sync")
--   - api_key (string): Authentication token
--   - timeout (number): Request timeout in seconds (default: 30)
--   - user_agent (string): User agent string (default: "Whisker-Sync/1.0")
--   - max_retries (number): Maximum retry attempts (default: 3)
--   - retry_delay (number): Initial retry delay in seconds (default: 1)
-- @return HTTPTransport instance
function HTTPTransport.new(config)
  local self = setmetatable({}, HTTPTransport)
  
  self.base_url = config.base_url or error("base_url is required")
  self.api_key = config.api_key or error("api_key is required")
  self.timeout = config.timeout or 30
  self.user_agent = config.user_agent or "Whisker-Sync/1.0"
  self.max_retries = config.max_retries or 3
  self.retry_delay = config.retry_delay or 1
  
  -- Check if URL uses HTTPS
  self.is_https = self.base_url:match("^https://") ~= nil
  
  if self.is_https and not https_available then
    error("HTTPS requested but luasec (ssl.https) is not available")
  end
  
  return self
end

--- Serialize data to JSON
-- @param data Lua table to serialize
-- @return JSON string
function HTTPTransport:_serialize(data)
  local success, result = pcall(json.encode, data)
  if not success then
    return nil, "Failed to serialize JSON: " .. tostring(result)
  end
  return result
end

--- Deserialize JSON to Lua table
-- @param json_string JSON string to deserialize
-- @return Lua table or nil, error
function HTTPTransport:_deserialize(json_string)
  if not json_string or json_string == "" then
    return nil, "Empty response body"
  end
  
  local success, result = pcall(json.decode, json_string)
  if not success then
    return nil, "Failed to deserialize JSON: " .. tostring(result)
  end
  return result
end

--- Build HTTP request headers
-- @param method HTTP method (GET, POST, etc.)
-- @param content_length Content length for POST requests
-- @return Headers table
function HTTPTransport:_build_headers(method, content_length)
  local headers = {
    ["User-Agent"] = self.user_agent,
    ["Authorization"] = "Bearer " .. self.api_key,
    ["Accept"] = "application/json"
  }
  
  if method == "POST" and content_length then
    headers["Content-Type"] = "application/json"
    headers["Content-Length"] = tostring(content_length)
  end
  
  return headers
end

--- Make HTTP request with retry logic
-- @param method HTTP method (GET, POST)
-- @param path URL path (relative to base_url)
-- @param body Request body (for POST)
-- @return Response table {status, body} or nil, error
function HTTPTransport:_request(method, path, body)
  local url = self.base_url .. path
  local attempt = 0
  local last_error
  
  while attempt <= self.max_retries do
    attempt = attempt + 1
    
    local response_body = {}
    local headers = self._build_headers(self, method, body and #body or nil)
    
    local request_params = {
      url = url,
      method = method,
      headers = headers,
      sink = ltn12.sink.table(response_body),
      timeout = self.timeout
    }
    
    if body then
      request_params.source = ltn12.source.string(body)
    end
    
    -- Choose HTTP or HTTPS
    local http_client = self.is_https and https or http
    
    -- Make request
    local response, status_code, response_headers, status_line = http_client.request(request_params)
    
    -- Handle response
    if response == 1 then
      -- Success
      local body_str = table.concat(response_body)
      return {
        status = status_code,
        headers = response_headers,
        body = body_str
      }
    else
      -- Error
      last_error = status_code or "Unknown error"
      
      -- Don't retry on client errors (4xx)
      if type(status_code) == "number" and status_code >= 400 and status_code < 500 then
        return nil, "HTTP error " .. status_code .. ": " .. (status_line or "")
      end
      
      -- Retry on network errors and 5xx errors
      if attempt <= self.max_retries then
        local delay = self.retry_delay * (2 ^ (attempt - 1))  -- Exponential backoff
        socket.sleep(delay)
      end
    end
  end
  
  return nil, "Request failed after " .. self.max_retries .. " retries: " .. tostring(last_error)
end

--- Fetch operations from server
-- @param device_id Unique device identifier
-- @param since_version Version to fetch operations since
-- @return Table {operations = [], version = number, has_more = boolean} or nil, error
function HTTPTransport:fetch_operations(device_id, since_version)
  if not device_id then
    return nil, "device_id is required"
  end
  
  since_version = since_version or 0
  
  local path = string.format("/operations?device=%s&since=%d", 
    self:_url_encode(device_id), 
    since_version)
  
  local response, err = self:_request("GET", path)
  if not response then
    return nil, err
  end
  
  if response.status ~= 200 then
    return nil, "Server returned status " .. response.status
  end
  
  local data, parse_err = self:_deserialize(response.body)
  if not data then
    return nil, parse_err
  end
  
  -- Validate response structure
  if type(data.operations) ~= "table" then
    return nil, "Invalid response: missing operations array"
  end
  
  if type(data.version) ~= "number" then
    return nil, "Invalid response: missing version number"
  end
  
  return {
    operations = data.operations,
    version = data.version,
    has_more = data.has_more or false
  }
end

--- Push operations to server
-- @param device_id Unique device identifier
-- @param operations Array of operations to push
-- @return Table {success = boolean, conflicts = [], version = number} or nil, error
function HTTPTransport:push_operations(device_id, operations)
  if not device_id then
    return nil, "device_id is required"
  end
  
  if type(operations) ~= "table" then
    return nil, "operations must be a table"
  end
  
  local payload = {
    device_id = device_id,
    operations = operations
  }
  
  local body, serialize_err = self:_serialize(payload)
  if not body then
    return nil, serialize_err
  end
  
  local response, err = self:_request("POST", "/operations", body)
  if not response then
    return nil, err
  end
  
  if response.status ~= 200 and response.status ~= 201 then
    return nil, "Server returned status " .. response.status
  end
  
  local data, parse_err = self:_deserialize(response.body)
  if not data then
    return nil, parse_err
  end
  
  return {
    success = data.success or false,
    conflicts = data.conflicts or {},
    version = data.version or 0
  }
end

--- Get current server version
-- @param device_id Unique device identifier
-- @return Table {version = number} or nil, error
function HTTPTransport:get_server_version(device_id)
  if not device_id then
    return nil, "device_id is required"
  end
  
  local path = string.format("/version?device=%s", self:_url_encode(device_id))
  
  local response, err = self:_request("GET", path)
  if not response then
    return nil, err
  end
  
  if response.status ~= 200 then
    return nil, "Server returned status " .. response.status
  end
  
  local data, parse_err = self:_deserialize(response.body)
  if not data then
    return nil, parse_err
  end
  
  if type(data.version) ~= "number" then
    return nil, "Invalid response: missing version number"
  end
  
  return {
    version = data.version
  }
end

--- URL encode a string
-- @param str String to encode
-- @return Encoded string
function HTTPTransport:_url_encode(str)
  if not str then return "" end
  
  str = string.gsub(str, "\n", "\r\n")
  -- Encode all except alphanumeric, hyphen, underscore, period, and tilde
  str = string.gsub(str, "([^%w%-_%.~])",
    function(c)
      if c == " " then
        return "+"
      else
        return string.format("%%%02X", string.byte(c))
      end
    end)
  
  return str
end

--- Check if transport is available
-- @return boolean
function HTTPTransport:is_available()
  -- Check if required modules are loaded
  if not socket or not http or not json then
    return false
  end
  
  -- If HTTPS is required, check if it's available
  if self.is_https and not https_available then
    return false
  end
  
  return true
end

--- Get transport info
-- @return Table with transport information
function HTTPTransport:get_info()
  return {
    type = "http",
    base_url = self.base_url,
    is_https = self.is_https,
    timeout = self.timeout,
    max_retries = self.max_retries,
    https_available = https_available
  }
end

return HTTPTransport
