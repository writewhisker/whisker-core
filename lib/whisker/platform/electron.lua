--- Electron Platform Implementation
--- Desktop platform adapter using Electron/Node.js bridge functions.
---
--- This implementation calls Node.js functions that are registered by the Electron main process.
--- The Electron host app must register these global Lua functions:
---   - electron_save(key, json_data) -> boolean
---   - electron_load(key) -> string|nil
---   - electron_delete(key) -> boolean
---   - electron_get_locale() -> string
---   - electron_has_capability(cap) -> boolean
---
--- @module whisker.platform.electron
--- @author Whisker Core Team
--- @license MIT

local IPlatform = require("whisker.platform.interface")
local Serialization = require("whisker.platform.serialization")

local ElectronPlatform = setmetatable({}, {__index = IPlatform})
ElectronPlatform.__index = ElectronPlatform

--- Create a new ElectronPlatform instance
--- @param config table|nil Configuration options
---   config.fallback_locale string: Locale if detection fails (default: "en-US")
--- @return ElectronPlatform
function ElectronPlatform.new(config)
  local self = setmetatable({}, ElectronPlatform)

  config = config or {}

  self._name = IPlatform.PLATFORMS.ELECTRON
  self._fallback_locale = config.fallback_locale or "en-US"

  -- Verify bridge functions are available
  if not electron_save then
    error("Electron platform bridge not available (electron_save not found). " ..
          "Ensure the Electron host app has registered the bridge functions.")
  end

  return self
end

--- Save data via Electron bridge
--- @param key string Storage key
--- @param data table Data to store
--- @return boolean Success
function ElectronPlatform:save(key, data)
  if type(key) ~= "string" or key == "" then
    return false
  end

  -- Serialize to JSON
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return false
  end

  -- Call Electron bridge function
  local ok, result = pcall(electron_save, key, json_str)
  if not ok then
    return false
  end

  return result == true
end

--- Load data via Electron bridge
--- @param key string Storage key
--- @return table|nil Data if found
function ElectronPlatform:load(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  -- Call Electron bridge function
  local ok, json_str = pcall(electron_load, key)
  if not ok or not json_str or json_str == "" then
    return nil
  end

  -- Deserialize from JSON
  local data, err = Serialization.deserialize(json_str)
  return data
end

--- Delete data via Electron bridge
--- @param key string Storage key
--- @return boolean Success
function ElectronPlatform:delete(key)
  if type(key) ~= "string" then
    return false
  end

  if electron_delete then
    local ok, result = pcall(electron_delete, key)
    if ok then
      return result == true
    end
  end

  return true
end

--- Get Electron/system locale via bridge
--- @return string Locale string (e.g., "en-US")
function ElectronPlatform:get_locale()
  local ok, locale = pcall(electron_get_locale)

  if ok and locale and type(locale) == "string" and locale ~= "" then
    return locale
  end

  return self._fallback_locale
end

--- Check Electron capability via bridge
--- @param cap string Capability name
--- @return boolean True if supported
function ElectronPlatform:has_capability(cap)
  if electron_has_capability then
    local ok, result = pcall(electron_has_capability, cap)
    if ok then
      return result == true
    end
  end

  -- Default capabilities for Electron (desktop)
  return ElectronPlatform._get_default_capability(cap)
end

--- Get default Electron capabilities (when bridge doesn't provide check)
--- @param cap string Capability name
--- @return boolean Default value
function ElectronPlatform._get_default_capability(cap)
  local defaults = {
    [IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true,
    [IPlatform.CAPABILITIES.FILESYSTEM] = true,  -- Full filesystem access
    [IPlatform.CAPABILITIES.NETWORK] = true,
    [IPlatform.CAPABILITIES.TOUCH] = false,       -- Most desktops don't have touch
    [IPlatform.CAPABILITIES.MOUSE] = true,
    [IPlatform.CAPABILITIES.KEYBOARD] = true,
    [IPlatform.CAPABILITIES.GAMEPAD] = true,
    [IPlatform.CAPABILITIES.CLIPBOARD] = true,
    [IPlatform.CAPABILITIES.NOTIFICATIONS] = true,
    [IPlatform.CAPABILITIES.AUDIO] = true,
    [IPlatform.CAPABILITIES.CAMERA] = true,
    [IPlatform.CAPABILITIES.GEOLOCATION] = false, -- Typically not available on desktop
    [IPlatform.CAPABILITIES.VIBRATION] = false,
  }

  return defaults[cap] == true
end

--- Get platform name
--- @return string "electron"
function ElectronPlatform:get_name()
  return self._name
end

return ElectronPlatform
