-- lib/whisker/i18n/formats/json.lua
-- JSON format handler for translation files
-- Stage 3: Translation File Format Support

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- JSON parsing state
local parseState = {}

--- Strip UTF-8 BOM from content
-- @param content string Content to process
-- @return string Content without BOM
local function stripBOM(content)
  if content:sub(1, 3) == "\xEF\xBB\xBF" then
    return content:sub(4)
  end
  return content
end

--- Skip whitespace
-- @param str string String to parse
-- @param pos number Current position
-- @return number New position after whitespace
local function skipWhitespace(str, pos)
  while pos <= #str do
    local c = str:sub(pos, pos)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      pos = pos + 1
    else
      break
    end
  end
  return pos
end

--- Parse a JSON string
-- @param str string Full JSON string
-- @param pos number Current position
-- @return string, number Parsed string and new position
local function parseString(str, pos)
  if str:sub(pos, pos) ~= '"' then
    error("Expected string at position " .. pos)
  end

  pos = pos + 1
  local result = {}
  local escape = false

  while pos <= #str do
    local c = str:sub(pos, pos)

    if escape then
      if c == "n" then
        table.insert(result, "\n")
      elseif c == "r" then
        table.insert(result, "\r")
      elseif c == "t" then
        table.insert(result, "\t")
      elseif c == "\\" then
        table.insert(result, "\\")
      elseif c == '"' then
        table.insert(result, '"')
      elseif c == "/" then
        table.insert(result, "/")
      elseif c == "b" then
        table.insert(result, "\b")
      elseif c == "f" then
        table.insert(result, "\f")
      elseif c == "u" then
        -- Unicode escape \uXXXX
        local hex = str:sub(pos + 1, pos + 4)
        if #hex == 4 and hex:match("^%x%x%x%x$") then
          local codepoint = tonumber(hex, 16)
          if codepoint < 128 then
            table.insert(result, string.char(codepoint))
          elseif codepoint < 2048 then
            table.insert(result, string.char(
              192 + math.floor(codepoint / 64),
              128 + (codepoint % 64)
            ))
          else
            table.insert(result, string.char(
              224 + math.floor(codepoint / 4096),
              128 + math.floor((codepoint % 4096) / 64),
              128 + (codepoint % 64)
            ))
          end
          pos = pos + 4
        else
          error("Invalid unicode escape at position " .. pos)
        end
      else
        table.insert(result, c)
      end
      escape = false
    elseif c == "\\" then
      escape = true
    elseif c == '"' then
      return table.concat(result), pos + 1
    else
      table.insert(result, c)
    end

    pos = pos + 1
  end

  error("Unterminated string starting at position " .. (pos - #result - 1))
end

--- Parse a JSON number
-- @param str string Full JSON string
-- @param pos number Current position
-- @return number, number Parsed number and new position
local function parseNumber(str, pos)
  local startPos = pos
  local c = str:sub(pos, pos)

  -- Optional negative sign
  if c == "-" then
    pos = pos + 1
  end

  -- Integer part
  c = str:sub(pos, pos)
  if c == "0" then
    pos = pos + 1
  elseif c >= "1" and c <= "9" then
    while pos <= #str and str:sub(pos, pos) >= "0" and str:sub(pos, pos) <= "9" do
      pos = pos + 1
    end
  else
    error("Invalid number at position " .. startPos)
  end

  -- Decimal part
  if pos <= #str and str:sub(pos, pos) == "." then
    pos = pos + 1
    while pos <= #str and str:sub(pos, pos) >= "0" and str:sub(pos, pos) <= "9" do
      pos = pos + 1
    end
  end

  -- Exponent
  c = str:sub(pos, pos)
  if c == "e" or c == "E" then
    pos = pos + 1
    c = str:sub(pos, pos)
    if c == "+" or c == "-" then
      pos = pos + 1
    end
    while pos <= #str and str:sub(pos, pos) >= "0" and str:sub(pos, pos) <= "9" do
      pos = pos + 1
    end
  end

  local numStr = str:sub(startPos, pos - 1)
  local num = tonumber(numStr)
  if not num then
    error("Invalid number '" .. numStr .. "' at position " .. startPos)
  end

  return num, pos
end

-- Forward declaration for recursive parsing
local parseValue

--- Parse a JSON array
-- @param str string Full JSON string
-- @param pos number Current position
-- @return table, number Parsed array and new position
local function parseArray(str, pos)
  if str:sub(pos, pos) ~= "[" then
    error("Expected array at position " .. pos)
  end

  pos = pos + 1
  local result = {}

  pos = skipWhitespace(str, pos)

  -- Empty array
  if str:sub(pos, pos) == "]" then
    return result, pos + 1
  end

  while true do
    pos = skipWhitespace(str, pos)
    local value
    value, pos = parseValue(str, pos)
    table.insert(result, value)

    pos = skipWhitespace(str, pos)
    local c = str:sub(pos, pos)

    if c == "]" then
      return result, pos + 1
    elseif c == "," then
      pos = pos + 1
    else
      error("Expected ',' or ']' at position " .. pos)
    end
  end
end

--- Parse a JSON object
-- @param str string Full JSON string
-- @param pos number Current position
-- @return table, number Parsed object and new position
local function parseObject(str, pos)
  if str:sub(pos, pos) ~= "{" then
    error("Expected object at position " .. pos)
  end

  pos = pos + 1
  local result = {}

  pos = skipWhitespace(str, pos)

  -- Empty object
  if str:sub(pos, pos) == "}" then
    return result, pos + 1
  end

  while true do
    pos = skipWhitespace(str, pos)

    -- Parse key
    if str:sub(pos, pos) ~= '"' then
      error("Expected string key at position " .. pos)
    end

    local key
    key, pos = parseString(str, pos)

    pos = skipWhitespace(str, pos)

    if str:sub(pos, pos) ~= ":" then
      error("Expected ':' at position " .. pos)
    end
    pos = pos + 1

    pos = skipWhitespace(str, pos)

    -- Parse value
    local value
    value, pos = parseValue(str, pos)

    result[key] = value

    pos = skipWhitespace(str, pos)
    local c = str:sub(pos, pos)

    if c == "}" then
      return result, pos + 1
    elseif c == "," then
      pos = pos + 1
    else
      error("Expected ',' or '}' at position " .. pos)
    end
  end
end

--- Parse any JSON value
-- @param str string Full JSON string
-- @param pos number Current position
-- @return any, number Parsed value and new position
parseValue = function(str, pos)
  pos = skipWhitespace(str, pos)

  local c = str:sub(pos, pos)

  if c == '"' then
    return parseString(str, pos)
  elseif c == "{" then
    return parseObject(str, pos)
  elseif c == "[" then
    return parseArray(str, pos)
  elseif c == "t" then
    if str:sub(pos, pos + 3) == "true" then
      return true, pos + 4
    else
      error("Invalid value at position " .. pos)
    end
  elseif c == "f" then
    if str:sub(pos, pos + 4) == "false" then
      return false, pos + 5
    else
      error("Invalid value at position " .. pos)
    end
  elseif c == "n" then
    if str:sub(pos, pos + 3) == "null" then
      return nil, pos + 4
    else
      error("Invalid value at position " .. pos)
    end
  elseif c == "-" or (c >= "0" and c <= "9") then
    return parseNumber(str, pos)
  else
    error("Unexpected character '" .. c .. "' at position " .. pos)
  end
end

--- Parse JSON string
-- @param content string JSON content
-- @return table Parsed data
function M.parse(content)
  content = stripBOM(content)

  if content == "" or content:match("^%s*$") then
    error("Empty JSON content")
  end

  local pos = 1
  local value, endPos = parseValue(content, pos)

  -- Check for trailing content
  endPos = skipWhitespace(content, endPos)
  if endPos <= #content then
    error("Unexpected content after JSON at position " .. endPos)
  end

  return value
end

--- Validate JSON structure for translation files
-- @param data any Parsed JSON data
-- @param filepath string|nil Source file for error messages
function M.validate(data, filepath)
  filepath = filepath or "unknown"

  if type(data) ~= "table" then
    error(filepath .. ": Root element must be an object, got " .. type(data))
  end

  -- Check for array at root (common mistake)
  if data[1] ~= nil and #data > 0 then
    local isArray = true
    for k, _ in pairs(data) do
      if type(k) ~= "number" then
        isArray = false
        break
      end
    end
    if isArray then
      error(filepath .. ": Root must be object ({}), not array ([])")
    end
  end

  -- Recursively validate
  local function check(tbl, path)
    for key, value in pairs(tbl) do
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        error(filepath .. ": Invalid key type at " .. path)
      end

      if type(value) == "table" then
        check(value, path .. "." .. tostring(key))
      end
    end
  end

  check(data, "root")
end

--- Load JSON file
-- @param filepath string Path to JSON file
-- @return table Parsed data
function M.load(filepath)
  local file, err = io.open(filepath, "r")
  if not file then
    error("Cannot open file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  local content = file:read("*all")
  file:close()

  local ok, data = pcall(M.parse, content)
  if not ok then
    error("JSON parse error in " .. filepath .. ": " .. tostring(data))
  end

  M.validate(data, filepath)

  return data
end

--- Load JSON from string
-- @param content string JSON content
-- @return table Parsed data
function M.loadString(content)
  local data = M.parse(content)
  M.validate(data, "string input")
  return data
end

--- Encode value to JSON string
-- @param value any Value to encode
-- @param pretty boolean|nil Pretty print with indentation
-- @param indent number|nil Current indent level
-- @return string JSON string
function M.encode(value, pretty, indent)
  indent = indent or 0
  local indentStr = pretty and string.rep("  ", indent) or ""
  local newline = pretty and "\n" or ""
  local space = pretty and " " or ""

  local valueType = type(value)

  if value == nil then
    return "null"
  elseif valueType == "boolean" then
    return value and "true" or "false"
  elseif valueType == "number" then
    if value ~= value then  -- NaN
      return "null"
    elseif value >= math.huge then
      return "null"
    elseif value <= -math.huge then
      return "null"
    else
      return tostring(value)
    end
  elseif valueType == "string" then
    -- Escape special characters
    local escaped = value:gsub('\\', '\\\\')
                         :gsub('"', '\\"')
                         :gsub('\n', '\\n')
                         :gsub('\r', '\\r')
                         :gsub('\t', '\\t')
    return '"' .. escaped .. '"'
  elseif valueType == "table" then
    -- Check if array
    local isArray = true
    local maxIndex = 0
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        isArray = false
        break
      end
      if k > maxIndex then
        maxIndex = k
      end
    end
    if isArray and maxIndex ~= #value then
      isArray = false
    end

    local parts = {}

    if isArray then
      for i, v in ipairs(value) do
        local encoded = M.encode(v, pretty, indent + 1)
        if pretty then
          table.insert(parts, indentStr .. "  " .. encoded)
        else
          table.insert(parts, encoded)
        end
      end
      if pretty then
        return "[" .. newline .. table.concat(parts, "," .. newline) .. newline .. indentStr .. "]"
      else
        return "[" .. table.concat(parts, ",") .. "]"
      end
    else
      -- Sort keys for consistent output
      local keys = {}
      for k, _ in pairs(value) do
        table.insert(keys, k)
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)

      for _, k in ipairs(keys) do
        local v = value[k]
        local keyStr = M.encode(tostring(k), false)
        local valStr = M.encode(v, pretty, indent + 1)
        if pretty then
          table.insert(parts, indentStr .. "  " .. keyStr .. ":" .. space .. valStr)
        else
          table.insert(parts, keyStr .. ":" .. valStr)
        end
      end
      if pretty then
        return "{" .. newline .. table.concat(parts, "," .. newline) .. newline .. indentStr .. "}"
      else
        return "{" .. table.concat(parts, ",") .. "}"
      end
    end
  else
    error("Cannot encode type: " .. valueType)
  end
end

--- Save JSON file
-- @param filepath string Destination path
-- @param data table Data to save
-- @param options table|nil Options {pretty: boolean}
function M.save(filepath, data, options)
  options = options or {}

  local file, err = io.open(filepath, "w")
  if not file then
    error("Cannot write file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  local jsonStr = M.encode(data, options.pretty)
  file:write(jsonStr)
  file:close()
end

return M
