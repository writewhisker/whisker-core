--- Minimal JSON Encoder/Decoder
-- Pure Lua fallback when no JSON library is available
-- @module whisker.formats.json.minimal
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

-- Encode a Lua value to JSON string
local function encode_value(val, indent, depth)
  local t = type(val)

  if val == nil then
    return "null"

  elseif t == "boolean" then
    return val and "true" or "false"

  elseif t == "number" then
    -- Handle special float values
    if val ~= val then
      return "null"  -- NaN
    elseif val == math.huge then
      return "1e309"
    elseif val == -math.huge then
      return "-1e309"
    else
      return tostring(val)
    end

  elseif t == "string" then
    -- Escape special characters
    local escaped = val:gsub('\\', '\\\\')
                       :gsub('"', '\\"')
                       :gsub('\n', '\\n')
                       :gsub('\r', '\\r')
                       :gsub('\t', '\\t')
    return '"' .. escaped .. '"'

  elseif t == "table" then
    depth = depth or 0
    local next_depth = depth + 1
    local prefix = indent and string.rep("  ", next_depth) or ""
    local sep = indent and ",\n" or ","

    -- Check if array (sequential integer keys starting at 1)
    local is_array = true
    local max_idx = 0
    for k, v in pairs(val) do
      if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
        is_array = false
        break
      end
      max_idx = math.max(max_idx, k)
    end
    if is_array and max_idx ~= #val then
      is_array = false
    end

    if is_array then
      local parts = {}
      for i = 1, #val do
        parts[i] = prefix .. encode_value(val[i], indent, next_depth)
      end
      if #parts == 0 then
        return "[]"
      end
      if indent then
        return "[\n" .. table.concat(parts, sep) .. "\n" .. string.rep("  ", depth) .. "]"
      else
        return "[" .. table.concat(parts, sep) .. "]"
      end
    else
      local parts = {}
      local sorted_keys = {}
      for k in pairs(val) do
        if type(k) == "string" then
          table.insert(sorted_keys, k)
        end
      end
      table.sort(sorted_keys)

      for _, k in ipairs(sorted_keys) do
        local encoded_key = encode_value(k, nil, next_depth)
        local encoded_val = encode_value(val[k], indent, next_depth)
        table.insert(parts, prefix .. encoded_key .. ":" .. (indent and " " or "") .. encoded_val)
      end
      if #parts == 0 then
        return "{}"
      end
      if indent then
        return "{\n" .. table.concat(parts, sep) .. "\n" .. string.rep("  ", depth) .. "}"
      else
        return "{" .. table.concat(parts, sep) .. "}"
      end
    end
  else
    error("Cannot encode type: " .. t)
  end
end

--- Encode a Lua value to JSON string
-- @param value any The value to encode
-- @return string The JSON string
function M.encode(value)
  return encode_value(value, false)
end

--- Encode a Lua value to pretty-printed JSON
-- @param value any The value to encode
-- @return string The formatted JSON string
function M.encode_pretty(value)
  return encode_value(value, true, 0)
end

-- Decode helper: parse string
local function decode_string(str, pos)
  pos = pos + 1  -- Skip opening quote
  local start = pos
  local chunks = {}

  while pos <= #str do
    local char = str:sub(pos, pos)

    if char == '"' then
      table.insert(chunks, str:sub(start, pos - 1))
      return table.concat(chunks), pos + 1
    elseif char == '\\' then
      table.insert(chunks, str:sub(start, pos - 1))
      pos = pos + 1
      local escape = str:sub(pos, pos)

      if escape == 'n' then
        table.insert(chunks, '\n')
      elseif escape == 'r' then
        table.insert(chunks, '\r')
      elseif escape == 't' then
        table.insert(chunks, '\t')
      elseif escape == '"' then
        table.insert(chunks, '"')
      elseif escape == '\\' then
        table.insert(chunks, '\\')
      elseif escape == '/' then
        table.insert(chunks, '/')
      elseif escape == 'u' then
        -- Unicode escape (basic handling)
        local hex = str:sub(pos + 1, pos + 4)
        local code = tonumber(hex, 16)
        if code then
          if code < 128 then
            table.insert(chunks, string.char(code))
          else
            -- UTF-8 encoding for higher code points
            if code < 0x800 then
              table.insert(chunks, string.char(
                0xC0 + math.floor(code / 64),
                0x80 + (code % 64)
              ))
            else
              table.insert(chunks, string.char(
                0xE0 + math.floor(code / 4096),
                0x80 + (math.floor(code / 64) % 64),
                0x80 + (code % 64)
              ))
            end
          end
          pos = pos + 4
        end
      end
      pos = pos + 1
      start = pos
    else
      pos = pos + 1
    end
  end

  error("Unterminated string")
end

-- Decode helper: parse number
local function decode_number(str, pos)
  local start = pos

  -- Handle negative
  if str:sub(pos, pos) == '-' then
    pos = pos + 1
  end

  -- Integer part
  while pos <= #str and str:sub(pos, pos):match("[0-9]") do
    pos = pos + 1
  end

  -- Decimal part
  if str:sub(pos, pos) == '.' then
    pos = pos + 1
    while pos <= #str and str:sub(pos, pos):match("[0-9]") do
      pos = pos + 1
    end
  end

  -- Exponent part
  if str:sub(pos, pos):lower() == 'e' then
    pos = pos + 1
    if str:sub(pos, pos):match("[+-]") then
      pos = pos + 1
    end
    while pos <= #str and str:sub(pos, pos):match("[0-9]") do
      pos = pos + 1
    end
  end

  local num = tonumber(str:sub(start, pos - 1))
  if not num then
    error("Invalid number at position " .. start)
  end

  return num, pos
end

-- Decode helper: skip whitespace
local function skip_whitespace(str, pos)
  while pos <= #str and str:sub(pos, pos):match("[ \t\n\r]") do
    pos = pos + 1
  end
  return pos
end

-- Forward declaration
local decode_value

-- Decode helper: parse array
local function decode_array(str, pos)
  local arr = {}
  pos = pos + 1  -- Skip [
  pos = skip_whitespace(str, pos)

  if str:sub(pos, pos) == ']' then
    return arr, pos + 1
  end

  while true do
    local val
    val, pos = decode_value(str, pos)
    table.insert(arr, val)

    pos = skip_whitespace(str, pos)
    local char = str:sub(pos, pos)

    if char == ']' then
      return arr, pos + 1
    elseif char == ',' then
      pos = pos + 1
      pos = skip_whitespace(str, pos)
    else
      error("Expected ',' or ']' at position " .. pos)
    end
  end
end

-- Decode helper: parse object
local function decode_object(str, pos)
  local obj = {}
  pos = pos + 1  -- Skip {
  pos = skip_whitespace(str, pos)

  if str:sub(pos, pos) == '}' then
    return obj, pos + 1
  end

  while true do
    -- Parse key
    if str:sub(pos, pos) ~= '"' then
      error("Expected string key at position " .. pos)
    end
    local key
    key, pos = decode_string(str, pos)

    pos = skip_whitespace(str, pos)
    if str:sub(pos, pos) ~= ':' then
      error("Expected ':' at position " .. pos)
    end
    pos = pos + 1
    pos = skip_whitespace(str, pos)

    -- Parse value
    local val
    val, pos = decode_value(str, pos)
    obj[key] = val

    pos = skip_whitespace(str, pos)
    local char = str:sub(pos, pos)

    if char == '}' then
      return obj, pos + 1
    elseif char == ',' then
      pos = pos + 1
      pos = skip_whitespace(str, pos)
    else
      error("Expected ',' or '}' at position " .. pos)
    end
  end
end

-- Main decode function
decode_value = function(str, pos)
  pos = skip_whitespace(str, pos)

  local char = str:sub(pos, pos)

  if char == '"' then
    return decode_string(str, pos)
  elseif char == '[' then
    return decode_array(str, pos)
  elseif char == '{' then
    return decode_object(str, pos)
  elseif char == '-' or char:match("[0-9]") then
    return decode_number(str, pos)
  elseif str:sub(pos, pos + 3) == 'true' then
    return true, pos + 4
  elseif str:sub(pos, pos + 4) == 'false' then
    return false, pos + 5
  elseif str:sub(pos, pos + 3) == 'null' then
    return nil, pos + 4
  else
    error("Unexpected character '" .. char .. "' at position " .. pos)
  end
end

--- Decode a JSON string to a Lua value
-- @param str string The JSON string
-- @return any The decoded value
function M.decode(str)
  if type(str) ~= "string" then
    error("Expected string, got " .. type(str))
  end

  if str == "" then
    error("Empty JSON string")
  end

  local value, pos = decode_value(str, 1)
  pos = skip_whitespace(str, pos)

  if pos <= #str then
    error("Unexpected content after JSON value at position " .. pos)
  end

  return value
end

return M
