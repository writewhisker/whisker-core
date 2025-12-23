--- Web Platform Implementation
--- Browser-based platform adapter using localStorage and Web APIs.
---
--- This implementation uses JavaScript interop (via Fengari or similar Lua-to-JS bridge)
--- to access browser APIs. In environments where JS interop is not available,
--- it falls back to a mock implementation.
---
--- Storage: localStorage (5-10MB limit depending on browser)
--- Locale: navigator.language
--- Capabilities: Detected via browser feature detection
---
--- @module whisker.platform.web
--- @author Whisker Core Team
--- @license MIT

local IPlatform = require("whisker.platform.interface")
local Serialization = require("whisker.platform.serialization")

local WebPlatform = setmetatable({}, {__index = IPlatform})
WebPlatform.__index = WebPlatform

--- Create a new WebPlatform instance
--- @param config table|nil Configuration options
---   config.storage_prefix string: Prefix for localStorage keys (default: "whisker:")
---   config.fallback_locale string: Locale to use if detection fails (default: "en-US")
--- @return WebPlatform
function WebPlatform.new(config)
  local self = setmetatable({}, WebPlatform)

  config = config or {}

  self._name = IPlatform.PLATFORMS.WEB
  self._storage_prefix = config.storage_prefix or "whisker:"
  self._fallback_locale = config.fallback_locale or "en-US"

  -- Detect JavaScript bridge availability
  self._has_js = WebPlatform._detect_js_bridge()

  -- Cache locale (expensive to query repeatedly)
  self._cached_locale = nil

  -- Cache capabilities (also expensive to query)
  self._cached_capabilities = nil

  return self
end

--- Detect if JavaScript interop is available
--- @return boolean True if JS bridge is available
function WebPlatform._detect_js_bridge()
  -- Check for common Lua-to-JS bridges
  -- Fengari (Lua in browser via WASM)
  if js then
    return true
  end

  -- ljs (another Lua-JS bridge)
  if _G.ljs then
    return true
  end

  -- Browser-specific global that might be set
  if _G.window then
    return true
  end

  return false
end

--- Execute JavaScript code and return result
--- @param code string JavaScript code to execute
--- @return any Result from JavaScript
function WebPlatform:_exec_js(code)
  if not self._has_js then
    return nil
  end

  -- Fengari bridge
  if js then
    local ok, result = pcall(function()
      return js.global:eval(code)
    end)
    if ok then
      return result
    end
  end

  return nil
end

--- Get prefixed storage key
--- @param key string Base key
--- @return string Prefixed key
function WebPlatform:_get_storage_key(key)
  return self._storage_prefix .. key
end

--- Save data to localStorage
--- @param key string Storage key
--- @param data table Data to store
--- @return boolean Success
function WebPlatform:save(key, data)
  if type(key) ~= "string" or key == "" then
    return false
  end

  -- Serialize to JSON
  local json_str, err = Serialization.serialize(data)
  if not json_str then
    return false
  end

  if not self._has_js then
    -- Fallback: store in Lua global (for testing)
    _G.__whisker_storage = _G.__whisker_storage or {}
    _G.__whisker_storage[self:_get_storage_key(key)] = json_str
    return true
  end

  -- Use localStorage
  local storage_key = self:_get_storage_key(key):gsub("'", "\\'")
  local escaped_json = json_str:gsub("\\", "\\\\"):gsub("'", "\\'"):gsub("\n", "\\n")

  local code = string.format(
    "try { localStorage.setItem('%s', '%s'); true; } catch(e) { false; }",
    storage_key,
    escaped_json
  )

  local result = self:_exec_js(code)
  return result == true
end

--- Load data from localStorage
--- @param key string Storage key
--- @return table|nil Data if found
function WebPlatform:load(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  local json_str

  if not self._has_js then
    -- Fallback: load from Lua global
    _G.__whisker_storage = _G.__whisker_storage or {}
    json_str = _G.__whisker_storage[self:_get_storage_key(key)]
  else
    -- Use localStorage
    local storage_key = self:_get_storage_key(key):gsub("'", "\\'")
    local code = string.format("localStorage.getItem('%s')", storage_key)
    json_str = self:_exec_js(code)
  end

  if not json_str or json_str == "" then
    return nil
  end

  -- Deserialize from JSON
  local data, err = Serialization.deserialize(json_str)
  return data
end

--- Delete data from localStorage
--- @param key string Storage key
--- @return boolean Success
function WebPlatform:delete(key)
  if type(key) ~= "string" then
    return false
  end

  if not self._has_js then
    -- Fallback: delete from Lua global
    _G.__whisker_storage = _G.__whisker_storage or {}
    _G.__whisker_storage[self:_get_storage_key(key)] = nil
    return true
  end

  local storage_key = self:_get_storage_key(key):gsub("'", "\\'")
  local code = string.format("localStorage.removeItem('%s'); true", storage_key)
  self:_exec_js(code)
  return true
end

--- Get browser locale
--- @return string Locale string (e.g., "en-US")
function WebPlatform:get_locale()
  -- Return cached value if available
  if self._cached_locale then
    return self._cached_locale
  end

  if not self._has_js then
    self._cached_locale = self._fallback_locale
    return self._cached_locale
  end

  -- Try navigator.language first, then navigator.userLanguage (IE)
  local locale = self:_exec_js(
    "navigator.language || navigator.userLanguage || 'en-US'"
  )

  if locale and type(locale) == "string" and locale ~= "" then
    self._cached_locale = locale
  else
    self._cached_locale = self._fallback_locale
  end

  return self._cached_locale
end

--- Check browser capability
--- @param cap string Capability name
--- @return boolean True if supported
function WebPlatform:has_capability(cap)
  -- Build capability cache if needed
  if not self._cached_capabilities then
    self._cached_capabilities = self:_detect_capabilities()
  end

  return self._cached_capabilities[cap] == true
end

--- Detect browser capabilities
--- @return table Map of capability names to booleans
function WebPlatform:_detect_capabilities()
  local caps = {}

  -- Without JS, report minimal capabilities
  if not self._has_js then
    caps[IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true
    caps[IPlatform.CAPABILITIES.FILESYSTEM] = false
    caps[IPlatform.CAPABILITIES.NETWORK] = false
    caps[IPlatform.CAPABILITIES.TOUCH] = false
    caps[IPlatform.CAPABILITIES.MOUSE] = true
    caps[IPlatform.CAPABILITIES.KEYBOARD] = true
    caps[IPlatform.CAPABILITIES.GAMEPAD] = false
    caps[IPlatform.CAPABILITIES.CLIPBOARD] = false
    caps[IPlatform.CAPABILITIES.NOTIFICATIONS] = false
    caps[IPlatform.CAPABILITIES.AUDIO] = false
    caps[IPlatform.CAPABILITIES.CAMERA] = false
    caps[IPlatform.CAPABILITIES.GEOLOCATION] = false
    caps[IPlatform.CAPABILITIES.VIBRATION] = false
    return caps
  end

  -- localStorage is available (we use it)
  caps[IPlatform.CAPABILITIES.PERSISTENT_STORAGE] = true

  -- Filesystem API (limited in browsers)
  caps[IPlatform.CAPABILITIES.FILESYSTEM] = self:_exec_js(
    "'showOpenFilePicker' in window"
  ) == true

  -- Network (always true in browser)
  caps[IPlatform.CAPABILITIES.NETWORK] = true

  -- Touch support
  caps[IPlatform.CAPABILITIES.TOUCH] = self:_exec_js(
    "'ontouchstart' in window || navigator.maxTouchPoints > 0"
  ) == true

  -- Mouse (assume yes on desktop browsers)
  caps[IPlatform.CAPABILITIES.MOUSE] = self:_exec_js(
    "window.matchMedia('(pointer: fine)').matches"
  ) == true

  -- Keyboard (always true in browser)
  caps[IPlatform.CAPABILITIES.KEYBOARD] = true

  -- Gamepad API
  caps[IPlatform.CAPABILITIES.GAMEPAD] = self:_exec_js(
    "'getGamepads' in navigator"
  ) == true

  -- Clipboard API
  caps[IPlatform.CAPABILITIES.CLIPBOARD] = self:_exec_js(
    "'clipboard' in navigator"
  ) == true

  -- Notifications API
  caps[IPlatform.CAPABILITIES.NOTIFICATIONS] = self:_exec_js(
    "'Notification' in window"
  ) == true

  -- Audio (Web Audio API)
  caps[IPlatform.CAPABILITIES.AUDIO] = self:_exec_js(
    "'AudioContext' in window || 'webkitAudioContext' in window"
  ) == true

  -- Camera (getUserMedia)
  caps[IPlatform.CAPABILITIES.CAMERA] = self:_exec_js(
    "!!navigator.mediaDevices && 'getUserMedia' in navigator.mediaDevices"
  ) == true

  -- Geolocation
  caps[IPlatform.CAPABILITIES.GEOLOCATION] = self:_exec_js(
    "'geolocation' in navigator"
  ) == true

  -- Vibration
  caps[IPlatform.CAPABILITIES.VIBRATION] = self:_exec_js(
    "'vibrate' in navigator"
  ) == true

  return caps
end

--- Get platform name
--- @return string "web"
function WebPlatform:get_name()
  return self._name
end

--- Clear cached values (for testing)
function WebPlatform:clear_cache()
  self._cached_locale = nil
  self._cached_capabilities = nil
end

return WebPlatform
