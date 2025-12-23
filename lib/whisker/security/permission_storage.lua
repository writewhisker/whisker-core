--- Permission Storage
-- Persistent storage for user permission decisions
-- @module whisker.security.permission_storage
-- @author Whisker Core Team
-- @license MIT

local PermissionStorage = {}

--- Default storage file path
PermissionStorage.DEFAULT_PATH = ".whisker/permissions.json"

--- Internal state
local _storage_path = nil
local _permissions = {}
local _dirty = false

--- Simple JSON encoder (basic implementation)
local function json_encode(data, indent)
  indent = indent or 0
  local padding = string.rep("  ", indent)

  if type(data) == "nil" then
    return "null"
  elseif type(data) == "boolean" then
    return tostring(data)
  elseif type(data) == "number" then
    return tostring(data)
  elseif type(data) == "string" then
    return '"' .. data:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
  elseif type(data) == "table" then
    -- Check if array or object
    local is_array = true
    local max_index = 0
    for k, _ in pairs(data) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        is_array = false
        break
      end
      if k > max_index then
        max_index = k
      end
    end
    -- Check for holes
    if is_array then
      for i = 1, max_index do
        if data[i] == nil then
          is_array = false
          break
        end
      end
    end

    local parts = {}
    if is_array and max_index > 0 then
      for i = 1, max_index do
        table.insert(parts, json_encode(data[i], indent + 1))
      end
      return "[\n" .. padding .. "  " .. table.concat(parts, ",\n" .. padding .. "  ") .. "\n" .. padding .. "]"
    else
      -- Object
      local keys = {}
      for k in pairs(data) do
        table.insert(keys, k)
      end
      table.sort(keys)

      for _, k in ipairs(keys) do
        table.insert(parts, json_encode(tostring(k)) .. ": " .. json_encode(data[k], indent + 1))
      end

      if #parts == 0 then
        return "{}"
      end
      return "{\n" .. padding .. "  " .. table.concat(parts, ",\n" .. padding .. "  ") .. "\n" .. padding .. "}"
    end
  end

  return "null"
end

--- Simple JSON decoder (basic implementation)
local function json_decode(str)
  -- Remove whitespace
  str = str:gsub("^%s+", ""):gsub("%s+$", "")

  -- Parse based on first character
  local first = str:sub(1, 1)

  if first == "n" and str:sub(1, 4) == "null" then
    return nil, 4
  elseif first == "t" and str:sub(1, 4) == "true" then
    return true, 4
  elseif first == "f" and str:sub(1, 5) == "false" then
    return false, 5
  elseif first == '"' then
    -- String
    local i = 2
    local result = {}
    while i <= #str do
      local c = str:sub(i, i)
      if c == '"' then
        return table.concat(result), i
      elseif c == '\\' then
        i = i + 1
        local next_c = str:sub(i, i)
        if next_c == 'n' then
          table.insert(result, '\n')
        elseif next_c == 'r' then
          table.insert(result, '\r')
        elseif next_c == 't' then
          table.insert(result, '\t')
        elseif next_c == '"' then
          table.insert(result, '"')
        elseif next_c == '\\' then
          table.insert(result, '\\')
        else
          table.insert(result, next_c)
        end
      else
        table.insert(result, c)
      end
      i = i + 1
    end
    error("Unterminated string")
  elseif first == '-' or first:match("%d") then
    -- Number
    local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*")
    return tonumber(num_str), #num_str
  elseif first == '[' then
    -- Array
    local arr = {}
    local i = 2
    while i <= #str do
      -- Skip whitespace
      while str:sub(i, i):match("%s") do
        i = i + 1
      end

      if str:sub(i, i) == ']' then
        return arr, i
      end

      if #arr > 0 then
        if str:sub(i, i) ~= ',' then
          error("Expected comma in array at position " .. i)
        end
        i = i + 1
        while str:sub(i, i):match("%s") do
          i = i + 1
        end
      end

      local value, consumed = json_decode(str:sub(i))
      table.insert(arr, value)
      i = i + consumed
    end
    error("Unterminated array")
  elseif first == '{' then
    -- Object
    local obj = {}
    local i = 2
    while i <= #str do
      -- Skip whitespace
      while str:sub(i, i):match("%s") do
        i = i + 1
      end

      if str:sub(i, i) == '}' then
        return obj, i
      end

      if next(obj) ~= nil then
        if str:sub(i, i) ~= ',' then
          error("Expected comma in object at position " .. i)
        end
        i = i + 1
        while str:sub(i, i):match("%s") do
          i = i + 1
        end
      end

      -- Parse key
      local key, key_consumed = json_decode(str:sub(i))
      i = i + key_consumed

      -- Skip whitespace and colon
      while str:sub(i, i):match("%s") do
        i = i + 1
      end
      if str:sub(i, i) ~= ':' then
        error("Expected colon in object at position " .. i)
      end
      i = i + 1
      while str:sub(i, i):match("%s") do
        i = i + 1
      end

      -- Parse value
      local value, value_consumed = json_decode(str:sub(i))
      obj[key] = value
      i = i + value_consumed
    end
    error("Unterminated object")
  end

  error("Invalid JSON: " .. str:sub(1, 20))
end

--- Initialize permission storage
-- @param path string|nil Storage file path
function PermissionStorage.init(path)
  _storage_path = path or PermissionStorage.DEFAULT_PATH
  _permissions = {}
  _dirty = false

  -- Try to load existing permissions
  PermissionStorage.load()
end

--- Load permissions from storage
-- @return boolean success
function PermissionStorage.load()
  if not _storage_path then
    return false
  end

  local file = io.open(_storage_path, "r")
  if not file then
    -- No existing file, start fresh
    return true
  end

  local content = file:read("*all")
  file:close()

  if content and #content > 0 then
    local ok, data = pcall(json_decode, content)
    if ok and type(data) == "table" then
      _permissions = data
    end
  end

  _dirty = false
  return true
end

--- Save permissions to storage
-- @return boolean success
-- @return string|nil error Error message if failed
function PermissionStorage.save()
  if not _storage_path then
    return false, "Storage not initialized"
  end

  if not _dirty then
    return true -- Nothing to save
  end

  -- Ensure directory exists
  local dir = _storage_path:match("(.*/)")
  if dir then
    os.execute('mkdir -p "' .. dir .. '"')
  end

  local file, err = io.open(_storage_path, "w")
  if not file then
    return false, "Failed to open file: " .. tostring(err)
  end

  local json = json_encode(_permissions)
  file:write(json)
  file:close()

  _dirty = false
  return true
end

--- Get permission state
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return string|nil Permission state: "granted", "denied", "revoked", or nil
function PermissionStorage.get(plugin_id, capability_id)
  if not _permissions[plugin_id] then
    return nil
  end

  local cap_data = _permissions[plugin_id][capability_id]
  if not cap_data then
    return nil
  end

  return cap_data.state
end

--- Set permission state
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @param state string Permission state
-- @param metadata table|nil Additional metadata
function PermissionStorage.set(plugin_id, capability_id, state, metadata)
  if not _permissions[plugin_id] then
    _permissions[plugin_id] = {}
  end

  _permissions[plugin_id][capability_id] = {
    state = state,
    timestamp = os.time(),
    metadata = metadata,
  }

  _dirty = true
end

--- Remove permission
-- @param plugin_id string Plugin ID
-- @param capability_id string|nil Capability ID (nil = all for plugin)
function PermissionStorage.remove(plugin_id, capability_id)
  if not _permissions[plugin_id] then
    return
  end

  if capability_id then
    _permissions[plugin_id][capability_id] = nil
  else
    _permissions[plugin_id] = nil
  end

  _dirty = true
end

--- Get all permissions for a plugin
-- @param plugin_id string Plugin ID
-- @return table Map of capability_id -> permission data
function PermissionStorage.get_plugin_permissions(plugin_id)
  return _permissions[plugin_id] or {}
end

--- Get all stored permissions
-- @return table Full permissions data
function PermissionStorage.get_all()
  return _permissions
end

--- Clear all permissions
function PermissionStorage.clear()
  _permissions = {}
  _dirty = true
end

--- Check if storage has unsaved changes
-- @return boolean
function PermissionStorage.is_dirty()
  return _dirty
end

--- Get storage path
-- @return string|nil
function PermissionStorage.get_path()
  return _storage_path
end

--- Export permissions for backup
-- @return string JSON string
function PermissionStorage.export()
  return json_encode(_permissions)
end

--- Import permissions from backup
-- @param json_str string JSON string
-- @return boolean success
-- @return string|nil error
function PermissionStorage.import(json_str)
  local ok, data = pcall(json_decode, json_str)
  if not ok then
    return false, "Invalid JSON: " .. tostring(data)
  end

  if type(data) ~= "table" then
    return false, "Expected object"
  end

  _permissions = data
  _dirty = true
  return true
end

return PermissionStorage
