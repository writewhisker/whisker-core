-- whisker-lsp/lib/json.lua
-- Minimal JSON encoder/decoder for LSP messages
-- Uses whisker's json utils if available, otherwise provides a basic implementation

local M = {}

-- Try to use existing whisker json utils
local ok, whisker_json = pcall(require, "whisker.utils.json")
if ok and whisker_json then
  M.encode = whisker_json.encode
  M.decode = whisker_json.decode
  return M
end

-- Fallback: Basic JSON implementation
local function encode_value(val, buffer)
  local t = type(val)

  if val == nil then
    buffer[#buffer + 1] = "null"
  elseif t == "boolean" then
    buffer[#buffer + 1] = val and "true" or "false"
  elseif t == "number" then
    if val ~= val then
      buffer[#buffer + 1] = "null"  -- NaN
    elseif val == math.huge then
      buffer[#buffer + 1] = "null"  -- Infinity
    elseif val == -math.huge then
      buffer[#buffer + 1] = "null"  -- -Infinity
    else
      buffer[#buffer + 1] = tostring(val)
    end
  elseif t == "string" then
    buffer[#buffer + 1] = '"'
    local escaped = val:gsub('[\\"\n\r\t]', {
      ['\\'] = '\\\\',
      ['"'] = '\\"',
      ['\n'] = '\\n',
      ['\r'] = '\\r',
      ['\t'] = '\\t'
    })
    buffer[#buffer + 1] = escaped
    buffer[#buffer + 1] = '"'
  elseif t == "table" then
    -- Check if it's an array
    local is_array = true
    local n = 0
    for k, _ in pairs(val) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        is_array = false
        break
      end
      n = math.max(n, k)
    end

    if is_array and n == #val then
      buffer[#buffer + 1] = "["
      for i = 1, n do
        if i > 1 then
          buffer[#buffer + 1] = ","
        end
        encode_value(val[i], buffer)
      end
      buffer[#buffer + 1] = "]"
    else
      buffer[#buffer + 1] = "{"
      local first = true
      for k, v in pairs(val) do
        if not first then
          buffer[#buffer + 1] = ","
        end
        first = false
        buffer[#buffer + 1] = '"'
        buffer[#buffer + 1] = tostring(k)
        buffer[#buffer + 1] = '":'
        encode_value(v, buffer)
      end
      buffer[#buffer + 1] = "}"
    end
  else
    buffer[#buffer + 1] = "null"
  end
end

function M.encode(val)
  local buffer = {}
  encode_value(val, buffer)
  return table.concat(buffer)
end

-- JSON decoder
local function skip_whitespace(str, pos)
  while pos <= #str do
    local c = str:sub(pos, pos)
    if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
      pos = pos + 1
    else
      break
    end
  end
  return pos
end

local function decode_value(str, pos)
  pos = skip_whitespace(str, pos)
  local c = str:sub(pos, pos)

  if c == '"' then
    -- String
    local start = pos + 1
    pos = start
    local buffer = {}
    while pos <= #str do
      c = str:sub(pos, pos)
      if c == '"' then
        return table.concat(buffer), pos + 1
      elseif c == '\\' then
        pos = pos + 1
        local escape = str:sub(pos, pos)
        if escape == 'n' then
          buffer[#buffer + 1] = '\n'
        elseif escape == 'r' then
          buffer[#buffer + 1] = '\r'
        elseif escape == 't' then
          buffer[#buffer + 1] = '\t'
        elseif escape == '"' then
          buffer[#buffer + 1] = '"'
        elseif escape == '\\' then
          buffer[#buffer + 1] = '\\'
        elseif escape == 'u' then
          -- Unicode escape (basic handling)
          local hex = str:sub(pos + 1, pos + 4)
          local code = tonumber(hex, 16)
          if code then
            if code < 128 then
              buffer[#buffer + 1] = string.char(code)
            else
              buffer[#buffer + 1] = '?'  -- Simplified: just use ?
            end
          end
          pos = pos + 4
        else
          buffer[#buffer + 1] = escape
        end
      else
        buffer[#buffer + 1] = c
      end
      pos = pos + 1
    end
    error("Unterminated string")
  elseif c == 't' then
    if str:sub(pos, pos + 3) == "true" then
      return true, pos + 4
    end
    error("Invalid token at position " .. pos)
  elseif c == 'f' then
    if str:sub(pos, pos + 4) == "false" then
      return false, pos + 5
    end
    error("Invalid token at position " .. pos)
  elseif c == 'n' then
    if str:sub(pos, pos + 3) == "null" then
      return nil, pos + 4
    end
    error("Invalid token at position " .. pos)
  elseif c == '[' then
    -- Array
    local arr = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if str:sub(pos, pos) == ']' then
      return arr, pos + 1
    end
    while true do
      local val
      val, pos = decode_value(str, pos)
      arr[#arr + 1] = val
      pos = skip_whitespace(str, pos)
      c = str:sub(pos, pos)
      if c == ']' then
        return arr, pos + 1
      elseif c == ',' then
        pos = pos + 1
      else
        error("Expected ',' or ']' at position " .. pos)
      end
    end
  elseif c == '{' then
    -- Object
    local obj = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if str:sub(pos, pos) == '}' then
      return obj, pos + 1
    end
    while true do
      pos = skip_whitespace(str, pos)
      local key
      key, pos = decode_value(str, pos)
      pos = skip_whitespace(str, pos)
      if str:sub(pos, pos) ~= ':' then
        error("Expected ':' at position " .. pos)
      end
      pos = pos + 1
      local val
      val, pos = decode_value(str, pos)
      obj[key] = val
      pos = skip_whitespace(str, pos)
      c = str:sub(pos, pos)
      if c == '}' then
        return obj, pos + 1
      elseif c == ',' then
        pos = pos + 1
      else
        error("Expected ',' or '}' at position " .. pos)
      end
    end
  elseif c == '-' or (c >= '0' and c <= '9') then
    -- Number
    local start = pos
    if c == '-' then
      pos = pos + 1
    end
    while str:sub(pos, pos):match('[0-9]') do
      pos = pos + 1
    end
    if str:sub(pos, pos) == '.' then
      pos = pos + 1
      while str:sub(pos, pos):match('[0-9]') do
        pos = pos + 1
      end
    end
    if str:sub(pos, pos):lower() == 'e' then
      pos = pos + 1
      if str:sub(pos, pos):match('[+-]') then
        pos = pos + 1
      end
      while str:sub(pos, pos):match('[0-9]') do
        pos = pos + 1
      end
    end
    return tonumber(str:sub(start, pos - 1)), pos
  else
    error("Unexpected character '" .. c .. "' at position " .. pos)
  end
end

function M.decode(str)
  if not str or str == "" then
    return nil
  end
  local val, _ = decode_value(str, 1)
  return val
end

return M
