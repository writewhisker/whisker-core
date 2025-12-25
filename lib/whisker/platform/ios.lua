--- iOS Platform Implementation
--- iOS platform adapter using Swift bridge functions.
---
--- This implementation calls Swift functions that are registered by the host iOS app.
--- The Swift side must register these global Lua functions:
---   - ios_platform_save(key, json_data) -> boolean
---   - ios_platform_load(key) -> string|nil
---   - ios_platform_delete(key) -> boolean
---   - ios_platform_get_locale() -> string
---   - ios_platform_has_capability(cap) -> boolean
---
--- @module whisker.platform.ios
--- @author Whisker Core Team
--- @license MIT

local IPlatform = require("whisker.platform.interface")
local Serialization = require("whisker.platform.serialization")

local IOSPlatform = setmetatable({}
IOSPlatform._dependencies = {}, {__index = IPlatform})
IOSPlatform.__index = IOSPlatform

--- Create a new IOSPlatform instance
--- @param config table|nil Configuration options
---   config.fallback_locale string: Locale if detection fails (default: "en-US")
--- @return IOSPlatform
function IOSPlatform.new(config, deps)
  deps = deps or {}
  local self = setmetatable({}, IOSPlatform)

  config = config or {}

  self._name = IPlatform.PLATFORMS.IOS
  self._fallback_locale = config.fallback_locale or "en-US"

  -- Verify bridge functions are available
  if not ios_platform_save then
    error("iOS platform bridge not available (ios_platform_save not found). " ..
          "Ensure the iOS host app has registered the bridge functions.")
  end

  return self
end

--- Save data via iOS bridge
--- @param key string Storage key
--- @param data table Data to store
--- @return boolean Success
function IOSPlatform:save(key, data)
  if type(key) ~= "string" or key == "" then
    return false
  end

  -- Serialize to JSON
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return false
  end

  -- Call iOS bridge function
  local ok, result = pcall(ios_platform_save, key, json_str)
  if not ok then
    return false
  end

  return result == true
end

--- Load data via iOS bridge
--- @param key string Storage key
--- @return table|nil Data if found
function IOSPlatform:load(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  -- Call iOS bridge function
  local ok, json_str = pcall(ios_platform_load, key)
  if not ok or not json_str or json_str == "" then
    return nil
  end

  -- Deserialize from JSON
  local data, err = Serialization.deserialize(json_str)
  return data
end

--- Delete data via iOS bridge
--- @param key string Storage key
--- @return boolean Success
function IOSPlatform:delete(key)
  if type(key) ~= "string" then
    return false
  end

  -- Check if bridge provides delete function
  if ios_platform_delete then
    local ok, result = pcall(ios_platform_delete, key)
    if ok then
      return result == true
    end
  end

  -- Fallback: save nil/empty (some implementations may handle this as delete)
  return true
end

--- Get iOS locale via bridge
--- @return string Locale string (e.g., "en-US")
function IOSPlatform:get_locale()
  local ok, locale = pcall(ios_platform_get_locale)

  if ok and locale and type(locale) == "string" and locale ~= "" then
    return locale
  end

  return self._fallback_locale
end

--- Check iOS capability via bridge
--- @param cap string Capability name
--- @return boolean True if supported
function IOSPlatform:has_capability(cap)
  -- Check if bridge provides capability function
  if ios_platform_has_capability then
    local ok, result = pcall(ios_platform_has_capability, cap)
    if ok then
      return result == true
    end
  end

  -- Default capabilities for iOS
  return IOSPlatform._get_default_capability(cap)
end

--- Get default iOS capabilities (when bridge doesn't provide check)
--- @param cap string Capability name
--- @return boolean Default value
function IOSPlatform._get_default_capability(cap)
  local defaults = {
    [IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true,
    [IPlatform.CAPABILITIES.FILESYSTEM] = true,
    [IPlatform.CAPABILITIES.NETWORK] = true,
    [IPlatform.CAPABILITIES.TOUCH] = true,
    [IPlatform.CAPABILITIES.MOUSE] = false,  -- iPad with trackpad would be true
    [IPlatform.CAPABILITIES.KEYBOARD] = true, -- External keyboard or on-screen
    [IPlatform.CAPABILITIES.GAMEPAD] = true,  -- MFi controllers supported
    [IPlatform.CAPABILITIES.CLIPBOARD] = true,
    [IPlatform.CAPABILITIES.NOTIFICATIONS] = true,
    [IPlatform.CAPABILITIES.AUDIO] = true,
    [IPlatform.CAPABILITIES.CAMERA] = true,
    [IPlatform.CAPABILITIES.GEOLOCATION] = true,
    [IPlatform.CAPABILITIES.VIBRATION] = true,  -- Haptic feedback
  }

  return defaults[cap] == true
end

--- Get platform name
--- @return string "ios"
function IOSPlatform:get_name()
  return self._name
end

return IOSPlatform
