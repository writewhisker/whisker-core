--- Android Platform Implementation
--- Android platform adapter using JNI bridge functions.
---
--- This implementation calls Kotlin/Java functions that are registered via JNI.
--- The Android host app must register these global Lua functions:
---   - android_platform_save(key, json_data) -> boolean
---   - android_platform_load(key) -> string|nil
---   - android_platform_delete(key) -> boolean
---   - android_platform_get_locale() -> string
---   - android_platform_has_capability(cap) -> boolean
---
--- @module whisker.platform.android
--- @author Whisker Core Team
--- @license MIT

local IPlatform = require("whisker.platform.interface")
local Serialization = require("whisker.platform.serialization")

local AndroidPlatform = setmetatable({}, {__index = IPlatform})
AndroidPlatform.__index = AndroidPlatform

--- Create a new AndroidPlatform instance
--- @param config table|nil Configuration options
---   config.fallback_locale string: Locale if detection fails (default: "en-US")
--- @return AndroidPlatform
function AndroidPlatform.new(config)
  local self = setmetatable({}, AndroidPlatform)

  config = config or {}

  self._name = IPlatform.PLATFORMS.ANDROID
  self._fallback_locale = config.fallback_locale or "en-US"

  -- Verify bridge functions are available
  if not android_platform_save then
    error("Android platform bridge not available (android_platform_save not found). " ..
          "Ensure the Android host app has registered the JNI bridge functions.")
  end

  return self
end

--- Save data via Android JNI bridge
--- @param key string Storage key
--- @param data table Data to store
--- @return boolean Success
function AndroidPlatform:save(key, data)
  if type(key) ~= "string" or key == "" then
    return false
  end

  -- Serialize to JSON
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return false
  end

  -- Call Android bridge function
  local ok, result = pcall(android_platform_save, key, json_str)
  if not ok then
    return false
  end

  return result == true
end

--- Load data via Android JNI bridge
--- @param key string Storage key
--- @return table|nil Data if found
function AndroidPlatform:load(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  -- Call Android bridge function
  local ok, json_str = pcall(android_platform_load, key)
  if not ok or not json_str or json_str == "" then
    return nil
  end

  -- Deserialize from JSON
  local data, err = Serialization.deserialize(json_str)
  return data
end

--- Delete data via Android JNI bridge
--- @param key string Storage key
--- @return boolean Success
function AndroidPlatform:delete(key)
  if type(key) ~= "string" then
    return false
  end

  -- Check if bridge provides delete function
  if android_platform_delete then
    local ok, result = pcall(android_platform_delete, key)
    if ok then
      return result == true
    end
  end

  return true
end

--- Get Android locale via JNI bridge
--- @return string Locale string (e.g., "en-US")
function AndroidPlatform:get_locale()
  local ok, locale = pcall(android_platform_get_locale)

  if ok and locale and type(locale) == "string" and locale ~= "" then
    return locale
  end

  return self._fallback_locale
end

--- Check Android capability via JNI bridge
--- @param cap string Capability name
--- @return boolean True if supported
function AndroidPlatform:has_capability(cap)
  -- Check if bridge provides capability function
  if android_platform_has_capability then
    local ok, result = pcall(android_platform_has_capability, cap)
    if ok then
      return result == true
    end
  end

  -- Default capabilities for Android
  return AndroidPlatform._get_default_capability(cap)
end

--- Get default Android capabilities (when bridge doesn't provide check)
--- @param cap string Capability name
--- @return boolean Default value
function AndroidPlatform._get_default_capability(cap)
  local defaults = {
    [IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true,
    [IPlatform.CAPABILITIES.FILESYSTEM] = true,
    [IPlatform.CAPABILITIES.NETWORK] = true,
    [IPlatform.CAPABILITIES.TOUCH] = true,
    [IPlatform.CAPABILITIES.MOUSE] = false,  -- Most Android devices don't have mouse
    [IPlatform.CAPABILITIES.KEYBOARD] = true, -- On-screen keyboard
    [IPlatform.CAPABILITIES.GAMEPAD] = true,  -- Bluetooth controllers supported
    [IPlatform.CAPABILITIES.CLIPBOARD] = true,
    [IPlatform.CAPABILITIES.NOTIFICATIONS] = true,
    [IPlatform.CAPABILITIES.AUDIO] = true,
    [IPlatform.CAPABILITIES.CAMERA] = true,
    [IPlatform.CAPABILITIES.GEOLOCATION] = true,
    [IPlatform.CAPABILITIES.VIBRATION] = true,
  }

  return defaults[cap] == true
end

--- Get platform name
--- @return string "android"
function AndroidPlatform:get_name()
  return self._name
end

return AndroidPlatform
