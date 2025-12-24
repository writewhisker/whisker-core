--- JSON Codec
-- Abstraction layer over JSON encoding/decoding libraries
-- Implements IJsonCodec interface for dependency injection
-- @module whisker.vendor.codecs.json_codec
-- @author Whisker Core Team
-- @license MIT

local JsonCodec = {}
JsonCodec.__index = JsonCodec

--- Dependencies injected via container
JsonCodec._dependencies = { "logger" }

--- Internal: Detect and load available JSON library
-- @return table|nil Library module
-- @return string Library name
local function detect_json_library()
  -- Try cjson first (fastest, most common)
  local ok, lib = pcall(require, "cjson")
  if ok then
    return lib, "cjson"
  end

  -- Try cjson.safe (doesn't throw on errors)
  ok, lib = pcall(require, "cjson.safe")
  if ok then
    return lib, "cjson.safe"
  end

  -- Try dkjson (pure Lua, good compatibility)
  ok, lib = pcall(require, "dkjson")
  if ok then
    return lib, "dkjson"
  end

  -- Try json.lua (another pure Lua option)
  ok, lib = pcall(require, "json")
  if ok then
    return lib, "json"
  end

  return nil, "none"
end

--- Create a new JsonCodec instance
-- @param deps table|nil Dependencies from container
-- @return JsonCodec
function JsonCodec.new(deps)
  local self = setmetatable({}, JsonCodec)

  deps = deps or {}
  self.log = deps.logger

  -- Detect and store the JSON library
  self._library, self._library_name = detect_json_library()

  if not self._library then
    error("No JSON library available. Install cjson or dkjson.")
  end

  -- Configure library-specific settings
  self:_configure_library()

  return self
end

--- Create a JsonCodec via container pattern
-- @param container table DI container
-- @return JsonCodec
function JsonCodec.create(container)
  local deps = {}
  if container and container.has and container:has("logger") then
    deps.logger = container:resolve("logger")
  end
  return JsonCodec.new(deps)
end

--- Configure library-specific settings
-- @private
function JsonCodec:_configure_library()
  if self._library_name == "cjson" or self._library_name == "cjson.safe" then
    -- cjson-specific configuration
    -- Encode sparse arrays as objects
    if self._library.encode_sparse_array then
      self._library.encode_sparse_array(true)
    end
  elseif self._library_name == "dkjson" then
    -- dkjson uses different API
    self._use_dkjson_api = true
  end
end

--- Encode a Lua value to JSON string
-- @param value any The Lua value to encode
-- @param options table|nil Encoding options
-- @return string|nil The JSON string
-- @return string|nil Error message if encoding failed
function JsonCodec:encode(value, options)
  options = options or {}

  local ok, result

  if self._use_dkjson_api then
    -- dkjson uses a different API
    local state = nil
    if options.pretty then
      state = { indent = true }
    end
    ok, result = pcall(self._library.encode, value, state)
  else
    -- cjson-style API
    ok, result = pcall(self._library.encode, value)
  end

  if not ok then
    return nil, "JSON encode error: " .. tostring(result)
  end

  return result
end

--- Decode a JSON string to a Lua value
-- @param json_string string The JSON string to decode
-- @param options table|nil Decoding options
-- @return any The decoded Lua value
-- @return string|nil Error message if decoding failed
function JsonCodec:decode(json_string, options)
  if type(json_string) ~= "string" then
    return nil, "Expected string, got " .. type(json_string)
  end

  local ok, result

  if self._use_dkjson_api then
    result, _, ok = self._library.decode(json_string)
    if ok then
      return nil, "JSON decode error at position " .. tostring(ok)
    end
    return result
  else
    ok, result = pcall(self._library.decode, json_string)
  end

  if not ok then
    return nil, "JSON decode error: " .. tostring(result)
  end

  return result
end

--- Get the name of the underlying JSON library
-- @return string Library name
function JsonCodec:get_library_name()
  return self._library_name
end

--- Check if this codec supports a feature
-- @param feature string Feature name
-- @return boolean True if the feature is supported
function JsonCodec:supports(feature)
  if feature == "pretty" then
    return self._library_name == "dkjson"
  elseif feature == "null_handling" then
    return true
  elseif feature == "sparse_arrays" then
    return self._library_name == "cjson" or self._library_name == "cjson.safe"
  end
  return false
end

--- Create a JSON null value
-- @return any The null value appropriate for this codec
function JsonCodec:null()
  if self._library_name == "cjson" or self._library_name == "cjson.safe" then
    return self._library.null
  elseif self._use_dkjson_api then
    return self._library.null
  end
  -- Default: use nil (may cause issues with some libraries)
  return nil
end

--- Get the raw library for advanced usage
-- @return table The underlying JSON library
function JsonCodec:get_raw_library()
  return self._library
end

return JsonCodec
