--- HTTP Server for Development
-- Lightweight HTTP server for serving stories and assets during development.
-- @module whisker.dev.server
-- @author Whisker Development Team
-- @license MIT

local socket = require("socket")
local json = require("whisker.utils.json")
local lfs = require("lfs")

local Server = {}
Server.__index = Server

--- MIME type mappings
local MIME_TYPES = {
  html = "text/html; charset=utf-8",
  css = "text/css; charset=utf-8",
  js = "application/javascript; charset=utf-8",
  json = "application/json; charset=utf-8",
  png = "image/png",
  jpg = "image/jpeg",
  jpeg = "image/jpeg",
  gif = "image/gif",
  svg = "image/svg+xml",
  woff = "font/woff",
  woff2 = "font/woff2",
  ttf = "font/ttf",
  eot = "application/vnd.ms-fontobject",
  txt = "text/plain; charset=utf-8",
  xml = "application/xml; charset=utf-8"
}

--- HTTP status messages
local STATUS_MESSAGES = {
  [200] = "OK",
  [201] = "Created",
  [204] = "No Content",
  [400] = "Bad Request",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [500] = "Internal Server Error",
  [503] = "Service Unavailable"
}

--- Create a new HTTP server instance
-- @param config Configuration table
-- @param config.port Server port (default: 3000)
-- @param config.host Server host (default: "127.0.0.1")
-- @param config.root_dir Document root directory
-- @param config.routes Custom route handlers (optional)
-- @return Server instance
function Server.new(config)
  config = config or {}
  
  local self = setmetatable({}, Server)
  
  self.port = config.port or 3000
  self.host = config.host or "127.0.0.1"
  self.root_dir = config.root_dir or lfs.currentdir()
  self.routes = config.routes or {}
  self.running = false
  self.server_socket = nil
  self.sse_clients = {}
  
  return self
end

--- Start the HTTP server
-- @return boolean success, string? error
function Server:start()
  if self.running then
    return false, "Server already running"
  end
  
  -- Create server socket
  local sock, err = socket.tcp()
  if not sock then
    return false, "Failed to create socket: " .. (err or "unknown error")
  end
  
  self.server_socket = sock
  
  -- Set socket options
  self.server_socket:setoption("reuseaddr", true)
  self.server_socket:settimeout(0.1)  -- Non-blocking with timeout
  
  -- Bind to address
  local success, bind_err = self.server_socket:bind(self.host, self.port)
  if not success then
    return false, "Failed to bind to " .. self.host .. ":" .. self.port .. ": " .. (bind_err or "unknown error")
  end
  
  -- Start listening
  local ok, listen_err = self.server_socket:listen(32)
  if not ok then
    return false, "Failed to listen: " .. (listen_err or "unknown error")
  end
  
  self.running = true
  
  return true
end

--- Stop the HTTP server
function Server:stop()
  if not self.running then
    return
  end
  
  self.running = false
  
  -- Close all SSE connections
  for _, client in ipairs(self.sse_clients) do
    pcall(function() client:close() end)
  end
  self.sse_clients = {}
  
  -- Close server socket
  if self.server_socket then
    self.server_socket:close()
    self.server_socket = nil
  end
end

--- Check if server is running
-- @return boolean
function Server:is_running()
  return self.running
end

--- Process one iteration of the server loop
-- Call this repeatedly to handle requests
-- @return boolean continue (false if error or stopped)
function Server:tick()
  if not self.running then
    return false
  end
  
  -- Accept new connection
  local client_socket, err = self.server_socket:accept()
  
  if client_socket then
    client_socket:settimeout(5)  -- 5 second timeout for client
    
    -- Handle request in protected call
    local ok, handle_err = pcall(function()
      self:_handle_request(client_socket)
    end)
    
    if not ok then
      -- Log error but continue serving
      io.stderr:write("Error handling request: " .. tostring(handle_err) .. "\n")
    end
    
    -- Close client socket
    pcall(function() client_socket:close() end)
  elseif err ~= "timeout" then
    -- Real error (not just timeout from non-blocking accept)
    io.stderr:write("Server error: " .. tostring(err) .. "\n")
    return false
  end
  
  return true
end

--- Handle an HTTP request
-- @param client_socket Client socket
function Server:_handle_request(client_socket)
  -- Read request
  local request_line = client_socket:receive("*l")
  if not request_line then
    return
  end
  
  -- Parse request line
  local method, path, protocol = request_line:match("^(%w+)%s+([^%s]+)%s+HTTP/([%d%.]+)")
  if not method then
    self:_send_error(client_socket, 400, "Bad Request")
    return
  end
  
  -- Read headers
  local headers = {}
  while true do
    local line = client_socket:receive("*l")
    if not line or line == "" then
      break
    end
    
    local key, value = line:match("^([^:]+):%s*(.+)")
    if key then
      headers[key:lower()] = value
    end
  end
  
  -- Read body if present
  local body = nil
  if headers["content-length"] then
    local length = tonumber(headers["content-length"])
    if length and length > 0 then
      body = client_socket:receive(length)
    end
  end
  
  -- Build request table
  local request = {
    method = method,
    path = path,
    protocol = protocol,
    headers = headers,
    body = body
  }
  
  -- Route request
  self:_route_request(client_socket, request)
end

--- Route request to appropriate handler
-- @param client_socket Client socket
-- @param request Request table
function Server:_route_request(client_socket, request)
  -- Check custom routes
  for pattern, handler in pairs(self.routes) do
    if request.path:match(pattern) then
      local ok, response = pcall(handler, request)
      if ok and response then
        self:_send_response(client_socket, response)
        return
      end
    end
  end
  
  -- Built-in routes
  if request.method == "GET" then
    if request.path == "/" or request.path == "/index.html" then
      self:_serve_index(client_socket, request)
    elseif request.path == "/health" then
      self:_serve_health(client_socket, request)
    elseif request.path:match("^/api/") then
      self:_serve_api(client_socket, request)
    elseif request.path:match("^/assets/") or request.path:match("^/%.") then
      self:_serve_static(client_socket, request)
    else
      self:_send_error(client_socket, 404, "Not Found")
    end
  else
    self:_send_error(client_socket, 405, "Method Not Allowed")
  end
end

--- Serve index page
-- @param client_socket Client socket
-- @param request Request table
function Server:_serve_index(client_socket, request)
  local html = [[<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Whisker Dev Server</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 20px;
      line-height: 1.6;
      color: #333;
    }
    h1 { color: #2c3e50; }
    .status { color: #27ae60; font-weight: bold; }
    code {
      background: #f4f4f4;
      padding: 2px 6px;
      border-radius: 3px;
      font-family: Consolas, Monaco, monospace;
    }
    .endpoints {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 8px;
      margin: 20px 0;
    }
    .endpoint {
      margin: 10px 0;
    }
    .method {
      display: inline-block;
      padding: 2px 8px;
      background: #3498db;
      color: white;
      border-radius: 3px;
      font-size: 12px;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <h1>🐱 Whisker Development Server</h1>
  <p class="status">✓ Server is running</p>
  
  <div class="endpoints">
    <h2>Available Endpoints</h2>
    
    <div class="endpoint">
      <span class="method">GET</span>
      <code>/</code> - This page
    </div>
    
    <div class="endpoint">
      <span class="method">GET</span>
      <code>/health</code> - Server health check
    </div>
    
    <div class="endpoint">
      <span class="method">GET</span>
      <code>/api/story</code> - Story data (JSON)
    </div>
    
    <div class="endpoint">
      <span class="method">GET</span>
      <code>/assets/*</code> - Static assets
    </div>
  </div>
  
  <p>
    <strong>Server Info:</strong><br>
    Host: ]] .. self.host .. [[<br>
    Port: ]] .. self.port .. [[<br>
    Root: ]] .. self.root_dir .. [[
  </p>
</body>
</html>]]
  
  self:_send_response(client_socket, {
    status = 200,
    headers = {["Content-Type"] = "text/html; charset=utf-8"},
    body = html
  })
end

--- Serve health check
-- @param client_socket Client socket
-- @param request Request table
function Server:_serve_health(client_socket, request)
  self:_send_response(client_socket, {
    status = 200,
    headers = {["Content-Type"] = "application/json"},
    body = json.encode({status = "ok", uptime = os.clock()})
  })
end

--- Serve API endpoints
-- @param client_socket Client socket
-- @param request Request table
function Server:_serve_api(client_socket, request)
  if request.path == "/api/story" then
    -- Return minimal story data for now
    self:_send_response(client_socket, {
      status = 200,
      headers = {["Content-Type"] = "application/json"},
      body = json.encode({
        name = "Dev Story",
        version = "1.0.0",
        passages = {}
      })
    })
  else
    self:_send_error(client_socket, 404, "API endpoint not found")
  end
end

--- Serve static file
-- @param client_socket Client socket
-- @param request Request table
function Server:_serve_static(client_socket, request)
  -- Clean path (remove query string and leading slash)
  local clean_path = request.path:match("^([^?]+)") or request.path
  clean_path = clean_path:gsub("^/", "")
  
  -- Build file path
  local file_path = self.root_dir .. "/" .. clean_path
  
  -- Check if file exists
  local attr = lfs.attributes(file_path)
  if not attr or attr.mode ~= "file" then
    self:_send_error(client_socket, 404, "File not found")
    return
  end
  
  -- Read file
  local file, err = io.open(file_path, "rb")
  if not file then
    self:_send_error(client_socket, 500, "Failed to read file: " .. (err or "unknown error"))
    return
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Determine MIME type
  local ext = file_path:match("%.([^%.]+)$")
  local mime_type = MIME_TYPES[ext] or "application/octet-stream"
  
  -- Send response
  self:_send_response(client_socket, {
    status = 200,
    headers = {["Content-Type"] = mime_type},
    body = content
  })
end

--- Send HTTP response
-- @param client_socket Client socket
-- @param response Response table {status, headers, body}
function Server:_send_response(client_socket, response)
  local status = response.status or 200
  local status_text = STATUS_MESSAGES[status] or "Unknown"
  local headers = response.headers or {}
  local body = response.body or ""
  
  -- Build response
  local lines = {
    "HTTP/1.1 " .. status .. " " .. status_text
  }
  
  -- Add default headers
  if not headers["Content-Length"] then
    headers["Content-Length"] = #body
  end
  if not headers["Server"] then
    headers["Server"] = "Whisker Dev Server"
  end
  if not headers["Connection"] then
    headers["Connection"] = "close"
  end
  
  -- Add headers
  for key, value in pairs(headers) do
    table.insert(lines, key .. ": " .. value)
  end
  
  -- Empty line before body
  table.insert(lines, "")
  
  -- Send response
  client_socket:send(table.concat(lines, "\r\n") .. "\r\n")
  
  if body and #body > 0 then
    client_socket:send(body)
  end
end

--- Send error response
-- @param client_socket Client socket
-- @param status HTTP status code
-- @param message Error message
function Server:_send_error(client_socket, status, message)
  local body = json.encode({
    error = message,
    status = status
  })
  
  self:_send_response(client_socket, {
    status = status,
    headers = {["Content-Type"] = "application/json"},
    body = body
  })
end

--- Add a custom route
-- @param pattern URL pattern (Lua pattern)
-- @param handler Handler function(request) -> response
function Server:add_route(pattern, handler)
  self.routes[pattern] = handler
end

--- Remove a custom route
-- @param pattern URL pattern
function Server:remove_route(pattern)
  self.routes[pattern] = nil
end

--- Get server URL
-- @return string URL
function Server:get_url()
  return "http://" .. self.host .. ":" .. self.port
end

return Server
