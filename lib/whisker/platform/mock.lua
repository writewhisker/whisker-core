--- Mock Platform Implementation
--- In-memory platform adapter for testing and development.
---
--- This implementation stores data in Lua tables and provides a fully
--- functional IPlatform interface without any external dependencies.
--- Ideal for unit tests and development in pure Lua environments.
---
--- @module whisker.platform.mock
--- @author Whisker Core Team
--- @license MIT

local IPlatform = require("whisker.platform.interface")
local Serialization = require("whisker.platform.serialization")

local MockPlatform = setmetatable({}, {__index = IPlatform})
MockPlatform._dependencies = {}
MockPlatform.__index = MockPlatform

--- Create a new MockPlatform instance
--- @param config table|nil Configuration options
---   config.locale string: Default locale (default: "en-US")
---   config.capabilities table: Map of capability name to boolean
---   config.storage table: Pre-populated storage data
---   config.fail_saves boolean: Force all saves to fail (for testing)
---   config.fail_loads boolean: Force all loads to fail (for testing)
--- @return MockPlatform
function MockPlatform.new(config, deps)
  deps = deps or {}
  local self = setmetatable({}, MockPlatform)

  config = config or {}

  self._name = IPlatform.PLATFORMS.MOCK
  self._storage = config.storage or {}
  self._locale = config.locale or "en-US"
  self._fail_saves = config.fail_saves or false
  self._fail_loads = config.fail_loads or false

  -- Default capabilities (all true for mock - simulates full-featured platform)
  self._capabilities = {
    [IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true,
    [IPlatform.CAPABILITIES.FILESYSTEM] = true,
    [IPlatform.CAPABILITIES.NETWORK] = true,
    [IPlatform.CAPABILITIES.TOUCH] = true,
    [IPlatform.CAPABILITIES.MOUSE] = true,
    [IPlatform.CAPABILITIES.KEYBOARD] = true,
    [IPlatform.CAPABILITIES.GAMEPAD] = false,
    [IPlatform.CAPABILITIES.CLIPBOARD] = true,
    [IPlatform.CAPABILITIES.NOTIFICATIONS] = true,
    [IPlatform.CAPABILITIES.AUDIO] = true,
    [IPlatform.CAPABILITIES.CAMERA] = false,
    [IPlatform.CAPABILITIES.GEOLOCATION] = false,
    [IPlatform.CAPABILITIES.VIBRATION] = false,
  }

  -- Override with config capabilities
  if config.capabilities then
    for cap, value in pairs(config.capabilities) do
      self._capabilities[cap] = value
    end
  end

  -- Stats for testing
  self._stats = {
    save_count = 0,
    load_count = 0,
    delete_count = 0,
    locale_checks = 0,
    capability_checks = 0,
  }

  return self
end

--- Save data to in-memory storage
--- @param key string Storage key
--- @param data table Data to store
--- @return boolean Success
function MockPlatform:save(key, data)
  self._stats.save_count = self._stats.save_count + 1

  -- Simulate save failures if configured
  if self._fail_saves then
    return false
  end

  if type(key) ~= "string" or key == "" then
    return false
  end

  -- Serialize to JSON (ensures data is serializable)
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return false
  end

  -- Store the JSON string
  self._storage[key] = json_str
  return true
end

--- Load data from in-memory storage
--- @param key string Storage key
--- @return table|nil Data if found
function MockPlatform:load(key)
  self._stats.load_count = self._stats.load_count + 1

  -- Simulate load failures if configured
  if self._fail_loads then
    return nil
  end

  if type(key) ~= "string" or key == "" then
    return nil
  end

  local json_str = self._storage[key]
  if not json_str then
    return nil
  end

  -- Deserialize from JSON
  local data, err = Serialization.deserialize(json_str)
  return data
end

--- Delete data from storage
--- @param key string Storage key
--- @return boolean Success (true even if key didn't exist)
function MockPlatform:delete(key)
  self._stats.delete_count = self._stats.delete_count + 1

  if type(key) ~= "string" then
    return false
  end

  self._storage[key] = nil
  return true
end

--- Get locale
--- @return string Locale string (e.g., "en-US")
function MockPlatform:get_locale()
  self._stats.locale_checks = self._stats.locale_checks + 1
  return self._locale
end

--- Check capability
--- @param cap string Capability name
--- @return boolean True if supported
function MockPlatform:has_capability(cap)
  self._stats.capability_checks = self._stats.capability_checks + 1
  return self._capabilities[cap] == true
end

--- Get platform name
--- @return string "mock"
function MockPlatform:get_name()
  return self._name
end

-- ============================================================
-- Test Helper Methods (not part of IPlatform interface)
-- ============================================================

--- Set the locale (for testing different locales)
--- @param locale string New locale
function MockPlatform:set_locale(locale)
  self._locale = locale
end

--- Set a capability (for testing different platform capabilities)
--- @param cap string Capability name
--- @param value boolean Whether capability is supported
function MockPlatform:set_capability(cap, value)
  self._capabilities[cap] = value
end

--- Configure save/load failures (for error testing)
--- @param fail_saves boolean Force saves to fail
--- @param fail_loads boolean Force loads to fail
function MockPlatform:set_failures(fail_saves, fail_loads)
  self._fail_saves = fail_saves or false
  self._fail_loads = fail_loads or false
end

--- Get usage statistics (for testing)
--- @return table Stats table
function MockPlatform:get_stats()
  return Serialization.deep_copy(self._stats)
end

--- Reset statistics
function MockPlatform:reset_stats()
  self._stats = {
    save_count = 0,
    load_count = 0,
    delete_count = 0,
    locale_checks = 0,
    capability_checks = 0,
  }
end

--- Clear all stored data
function MockPlatform:clear_storage()
  self._storage = {}
end

--- Get all stored keys (for debugging)
--- @return table Array of key names
function MockPlatform:get_keys()
  local keys = {}
  for key in pairs(self._storage) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

--- Check if a key exists in storage
--- @param key string Storage key
--- @return boolean True if key exists
function MockPlatform:has_key(key)
  return self._storage[key] ~= nil
end

--- Get raw storage contents (for debugging)
--- @return table Direct reference to storage table
function MockPlatform:get_raw_storage()
  return self._storage
end

return MockPlatform
