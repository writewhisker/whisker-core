-- lib/whisker/i18n/formats/lua.lua
-- Lua table format handler for translation files
-- Stage 3: Translation File Format Support

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Load Lua table file
-- @param filepath string Path to Lua file
-- @return table Loaded data
function M.load(filepath)
  -- Use loadfile to load the file
  local chunk, err = loadfile(filepath)
  if not chunk then
    error("Cannot load Lua file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  -- Create restricted environment (no access to dangerous functions)
  local env = {
    -- Allow only safe operations
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    tostring = tostring,
    tonumber = tonumber,
    type = type,
    table = {
      insert = table.insert,
      concat = table.concat,
      remove = table.remove
    },
    string = {
      format = string.format,
      sub = string.sub,
      len = string.len,
      gsub = string.gsub,
      match = string.match,
      lower = string.lower,
      upper = string.upper
    },
    math = {
      floor = math.floor,
      ceil = math.ceil,
      abs = math.abs,
      min = math.min,
      max = math.max
    }
  }

  -- Set environment (compatible with Lua 5.1 through 5.4)
  if setfenv then
    -- Lua 5.1
    setfenv(chunk, env)
  elseif debug and debug.setupvalue then
    -- Lua 5.2+
    -- Find the _ENV upvalue
    local i = 1
    while true do
      local name = debug.getupvalue(chunk, i)
      if name == "_ENV" then
        debug.setupvalue(chunk, i, env)
        break
      elseif not name then
        break
      end
      i = i + 1
    end
  end

  -- Execute chunk
  local ok, data = pcall(chunk)
  if not ok then
    error("Error executing Lua file: " .. filepath .. " (" .. tostring(data) .. ")")
  end

  -- Validate result
  if type(data) ~= "table" then
    error(filepath .. ": Lua file must return a table, got " .. type(data))
  end

  M.validate(data, filepath)

  return data
end

--- Load Lua table from string
-- @param content string Lua code
-- @return table Loaded data
function M.loadString(content)
  -- Use load to parse the string
  local chunk, err
  if loadstring then
    -- Lua 5.1
    chunk, err = loadstring(content)
  else
    -- Lua 5.2+
    chunk, err = load(content)
  end

  if not chunk then
    error("Cannot parse Lua string: " .. (err or "unknown error"))
  end

  -- Create restricted environment
  local env = {
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    tostring = tostring,
    tonumber = tonumber,
    type = type,
    table = {
      insert = table.insert,
      concat = table.concat
    },
    string = {
      format = string.format,
      sub = string.sub
    }
  }

  if setfenv then
    setfenv(chunk, env)
  elseif debug and debug.setupvalue then
    local i = 1
    while true do
      local name = debug.getupvalue(chunk, i)
      if name == "_ENV" then
        debug.setupvalue(chunk, i, env)
        break
      elseif not name then
        break
      end
      i = i + 1
    end
  end

  local ok, data = pcall(chunk)
  if not ok then
    error("Error executing Lua string: " .. tostring(data))
  end

  if type(data) ~= "table" then
    error("Lua code must return a table, got " .. type(data))
  end

  M.validate(data, "string input")

  return data
end

--- Validate Lua table structure
-- @param data table Loaded data
-- @param filepath string|nil Source file for error messages
function M.validate(data, filepath)
  filepath = filepath or "unknown"

  local function check(tbl, path, visited)
    visited = visited or {}

    -- Check for circular references
    if visited[tbl] then
      error(filepath .. ": Circular reference detected at " .. path)
    end
    visited[tbl] = true

    for key, value in pairs(tbl) do
      if type(key) ~= "string" and type(key) ~= "number" then
        error(filepath .. ": Invalid key type at " .. path .. ": " .. type(key))
      end

      if type(value) == "table" then
        check(value, path .. "." .. tostring(key), visited)
      elseif type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" and value ~= nil then
        error(filepath .. ": Invalid value type at " .. path .. "." .. tostring(key) .. ": " .. type(value))
      end
    end
  end

  check(data, "root")
end

--- Serialize table to Lua code
-- @param data table Data to serialize
-- @param options table|nil Options {pretty: boolean}
-- @return string Lua code
function M.serialize(data, options)
  options = options or { pretty = false }

  local function serializeValue(value, indent)
    indent = indent or 0
    local indentStr = options.pretty and string.rep("  ", indent) or ""
    local childIndent = options.pretty and string.rep("  ", indent + 1) or ""
    local newline = options.pretty and "\n" or ""
    local sep = options.pretty and ", " or ","

    local valueType = type(value)

    if value == nil then
      return "nil"
    elseif valueType == "boolean" then
      return value and "true" or "false"
    elseif valueType == "number" then
      if value ~= value then  -- NaN
        return "0/0"
      elseif value == math.huge then
        return "math.huge"
      elseif value == -math.huge then
        return "-math.huge"
      else
        return tostring(value)
      end
    elseif valueType == "string" then
      -- Escape special characters and use long strings for multiline
      if value:match("\n") then
        -- Use long string notation for multiline
        local level = 0
        while value:match("%]" .. string.rep("=", level) .. "%]") do
          level = level + 1
        end
        local eq = string.rep("=", level)
        return "[" .. eq .. "[" .. value .. "]" .. eq .. "]"
      else
        -- Use quoted string
        return string.format("%q", value)
      end
    elseif valueType == "table" then
      local parts = {}

      -- Sort keys for consistent output
      local keys = {}
      for k, _ in pairs(value) do
        table.insert(keys, k)
      end
      table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
          return ta < tb
        end
        return tostring(a) < tostring(b)
      end)

      for _, k in ipairs(keys) do
        local v = value[k]
        local keyStr
        if type(k) == "string" then
          -- Check if key is valid identifier
          if k:match("^[%a_][%w_]*$") then
            keyStr = k
          else
            keyStr = "[" .. string.format("%q", k) .. "]"
          end
        else
          keyStr = "[" .. tostring(k) .. "]"
        end

        local valueStr = serializeValue(v, indent + 1)

        if options.pretty then
          table.insert(parts, childIndent .. keyStr .. " = " .. valueStr)
        else
          table.insert(parts, keyStr .. "=" .. valueStr)
        end
      end

      if options.pretty then
        if #parts == 0 then
          return "{}"
        else
          return "{" .. newline .. table.concat(parts, "," .. newline) .. newline .. indentStr .. "}"
        end
      else
        return "{" .. table.concat(parts, ",") .. "}"
      end
    else
      error("Cannot serialize type: " .. valueType)
    end
  end

  return "return " .. serializeValue(data)
end

--- Save Lua table file
-- @param filepath string Destination path
-- @param data table Data to save
-- @param options table|nil Options {pretty: boolean}
function M.save(filepath, data, options)
  options = options or { pretty = false }

  local file, err = io.open(filepath, "w")
  if not file then
    error("Cannot write file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  local luaStr = M.serialize(data, options)
  file:write(luaStr)
  file:write("\n")
  file:close()
end

--- Encode value to Lua code (alias for serialize)
-- @param data table Data to serialize
-- @param options table|nil Options
-- @return string Lua code
function M.encode(data, options)
  return M.serialize(data, options)
end

return M
