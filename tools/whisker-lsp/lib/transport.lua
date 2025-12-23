-- whisker-lsp/lib/transport.lua
-- LSP JSON-RPC transport layer

local json = require("lib.json")

local Transport = {}
Transport.__index = Transport

--- Create a new transport instance
--- @param input file? Input file handle (default stdin)
--- @param output file? Output file handle (default stdout)
--- @return table Transport instance
function Transport.new(input, output)
  local self = setmetatable({}, Transport)
  self.input = input or io.stdin
  self.output = output or io.stdout
  self.closed = false
  self.buffer = ""
  return self
end

--- Read a single LSP message from input
--- @return table|nil Message table or nil on EOF/error
function Transport:read_message()
  if self.closed then
    return nil
  end

  -- Read headers
  local headers = {}
  while true do
    local line = self.input:read("*l")
    if not line then
      self.closed = true
      return nil
    end

    -- Empty line marks end of headers
    if line == "" or line == "\r" then
      break
    end

    -- Remove trailing \r if present
    line = line:gsub("\r$", "")

    -- Parse header
    local key, value = line:match("^([^:]+):%s*(.+)$")
    if key then
      headers[key:lower()] = value
    end
  end

  -- Get content length
  local length = tonumber(headers["content-length"])
  if not length then
    return nil, "Missing Content-Length header"
  end

  -- Read body
  local body = self.input:read(length)
  if not body or #body ~= length then
    self.closed = true
    return nil, "Failed to read message body"
  end

  -- Parse JSON
  local ok, msg = pcall(json.decode, body)
  if not ok then
    return nil, "JSON parse error: " .. tostring(msg)
  end

  return msg
end

--- Write an LSP message to output
--- @param msg table Message table to send
--- @return boolean Success
function Transport:write_message(msg)
  if self.closed then
    return false
  end

  local body = json.encode(msg)
  local header = string.format("Content-Length: %d\r\n\r\n", #body)

  self.output:write(header)
  self.output:write(body)
  self.output:flush()

  return true
end

--- Close the transport
function Transport:close()
  self.closed = true
end

--- Check if transport is closed
--- @return boolean
function Transport:is_closed()
  return self.closed
end

return Transport
