--- Serialization Utilities
--- Handles conversion between Lua tables and JSON for cross-platform data persistence.
---
--- This module provides safe serialization that handles Lua-specific edge cases:
---   - Filters out non-serializable types (functions, userdata, threads)
---   - Detects and handles cyclic references
---   - Normalizes mixed-key tables
---   - Provides clear error messages
---
--- @module whisker.platform.serialization
--- @author Whisker Core Team
--- @license MIT

local Serialization = {}

--------------------------------------------------------------------------------
-- Dependencies (lazily loaded)
--------------------------------------------------------------------------------

local _json_codec = nil

local function get_json_codec()
  if not _json_codec then
    local ok, mod = pcall(require, "whisker.utils.json")
    if ok then _json_codec = mod end
  end
  return _json_codec
end

--- Set dependencies via DI (optional)
-- @param deps table {json_codec}
function Serialization.set_dependencies(deps)
  if deps.json_codec then _json_codec = deps.json_codec end
end

--------------------------------------------------------------------------------

--- Serialize Lua table to JSON string
--- Handles Lua-specific edge cases and ensures JSON compatibility.
---
--- @param data table Lua table to serialize
--- @return string|nil JSON string on success, nil on error
--- @return string|nil Error message if serialization failed
function Serialization.serialize(data)
  local json = get_json_codec()
  if not json then
    return nil, "JSON codec not available"
  end

  if type(data) ~= "table" then
    return nil, "Data must be a table, got " .. type(data)
  end

  -- Filter out non-serializable types
  local filtered, err = Serialization.filter_serializable(data)
  if not filtered then
    return nil, err
  end

  -- Encode to JSON
  local ok, result = pcall(json.encode, filtered)
  if not ok then
    return nil, "JSON encoding failed: " .. tostring(result)
  end

  return result, nil
end

--- Deserialize JSON string to Lua table
---
--- @param json_str string JSON string to parse
--- @return table|nil Parsed Lua table on success, nil on error
--- @return string|nil Error message if deserialization failed
function Serialization.deserialize(json_str)
  local json = get_json_codec()
  if not json then
    return nil, "JSON codec not available"
  end

  if type(json_str) ~= "string" then
    return nil, "Input must be a string, got " .. type(json_str)
  end

  if json_str == "" then
    return nil, "Empty JSON string"
  end

  -- Decode JSON
  local result, err = json.decode(json_str)
  if err then
    return nil, "JSON decoding failed: " .. tostring(err)
  end

  return result, nil
end

--- Filter table to remove non-serializable values
--- Recursively removes functions, userdata, threads, and handles cycles.
---
--- @param data table Input table
--- @param seen table|nil Cycle detection (internal use)
--- @param max_depth number|nil Maximum recursion depth (default 100)
--- @param current_depth number|nil Current depth (internal use)
--- @return table|nil Filtered table containing only serializable values
--- @return string|nil Error message if filtering failed
function Serialization.filter_serializable(data, seen, max_depth, current_depth)
  seen = seen or {}
  max_depth = max_depth or 100
  current_depth = current_depth or 0

  -- Detect cycles
  if seen[data] then
    return nil, "Cyclic reference detected"
  end

  -- Check depth limit
  if current_depth >= max_depth then
    return nil, "Maximum nesting depth exceeded"
  end

  seen[data] = true

  local filtered = {}
  local is_array = Serialization.is_array(data)

  for k, v in pairs(data) do
    local key_type = type(k)
    local val_type = type(v)

    -- Handle keys: JSON requires string keys (or numeric for arrays)
    local json_key = k
    if is_array and key_type == "number" then
      json_key = k  -- Keep numeric keys for arrays
    elseif key_type == "string" then
      json_key = k  -- Keep string keys
    elseif key_type == "number" then
      json_key = tostring(k)  -- Convert numeric keys to strings for objects
    else
      -- Skip non-serializable key types
      goto continue
    end

    -- Handle values: only serialize JSON-compatible types
    if val_type == "string" or val_type == "number" or val_type == "boolean" then
      filtered[json_key] = v
    elseif val_type == "table" then
      -- Recursively filter nested tables
      local nested, nested_err = Serialization.filter_serializable(v, seen, max_depth, current_depth + 1)
      if nested then
        filtered[json_key] = nested
      elseif nested_err then
        -- Propagate critical errors (cycles, depth limits)
        return nil, nested_err
      end
    elseif v == nil then
      -- Explicitly handle nil (though pairs() doesn't return nil values)
      -- JSON null is represented differently
    end
    -- Skip functions, userdata, threads, coroutines

    ::continue::
  end

  seen[data] = nil
  return filtered, nil
end

--- Check if a table is a JSON array (sequential numeric keys starting at 1)
--- @param t table Table to check
--- @return boolean True if table is an array
function Serialization.is_array(t)
  if type(t) ~= "table" then
    return false
  end

  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end

  if count == 0 then
    return true  -- Empty tables are considered arrays
  end

  -- Check if all keys are sequential integers starting at 1
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end

  return true
end

--- Check if a value is serializable to JSON
--- @param value any Value to check
--- @param seen table|nil Cycle detection (internal use)
--- @return boolean True if value can be serialized to JSON
function Serialization.is_serializable(value, seen)
  seen = seen or {}

  local t = type(value)

  if t == "string" or t == "number" or t == "boolean" or t == "nil" then
    return true
  elseif t == "table" then
    -- Detect cycles
    if seen[value] then
      return false
    end
    seen[value] = true

    -- Check if all contents are serializable
    for k, v in pairs(value) do
      local key_type = type(k)
      -- Keys must be strings or numbers
      if key_type ~= "string" and key_type ~= "number" then
        seen[value] = nil
        return false
      end
      if not Serialization.is_serializable(v, seen) then
        seen[value] = nil
        return false
      end
    end

    seen[value] = nil
    return true
  else
    return false  -- Functions, userdata, threads, etc.
  end
end

--- Estimate size of serialized data in bytes
--- Useful for checking against storage quotas before saving.
--- @param data table Table to estimate
--- @return number|nil Estimated size in bytes, nil on error
function Serialization.estimate_size(data)
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return nil
  end
  return #json_str
end

--- Deep copy a table
--- Creates a new table with copies of all values.
--- @param t table Table to copy
--- @param seen table|nil Cycle detection (internal use)
--- @return table Copy of the table
function Serialization.deep_copy(t, seen)
  if type(t) ~= "table" then
    return t
  end

  seen = seen or {}

  if seen[t] then
    return seen[t]  -- Handle cycles by returning the same reference
  end

  local copy = {}
  seen[t] = copy

  for k, v in pairs(t) do
    copy[Serialization.deep_copy(k, seen)] = Serialization.deep_copy(v, seen)
  end

  return setmetatable(copy, getmetatable(t))
end

return Serialization
