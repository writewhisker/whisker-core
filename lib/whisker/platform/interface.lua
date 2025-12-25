--- IPlatform Interface
--- Defines the contract for platform-specific implementations.
--- All platform adapters (web, iOS, Android, Electron) must implement this interface.
---
--- Usage:
---   local platform = PlatformFactory.create()
---   platform:save("game_state", {chapter = 3})
---   local state = platform:load("game_state")
---   local locale = platform:get_locale()
---   if platform:has_capability("touch") then ... end
---
--- @module whisker.platform.interface
--- @author Whisker Core Team
--- @license MIT

local IPlatform = {}
IPlatform._dependencies = {}
IPlatform.__index = IPlatform

--- Create a new IPlatform instance (abstract base class)
--- This should not be instantiated directly; use concrete platform implementations.
--- @return IPlatform
function IPlatform.new(deps)
  deps = deps or {}
  local self = setmetatable({}, IPlatform)
  return self
end

--- Save data to persistent storage
--- Serializes the provided Lua table to JSON and stores it under the given key.
--- Platform implementations should use appropriate storage mechanisms:
---   - Web: localStorage or IndexedDB
---   - iOS: UserDefaults or file system
---   - Android: SharedPreferences or file system
---   - Electron: electron-store or fs module
---
--- @param key string Unique identifier for this data (e.g., "save_slot_1", "preferences")
--- @param data table Lua table to serialize and store (must be JSON-serializable)
--- @return boolean True if save succeeded, false if failed (quota exceeded, no permission, etc)
function IPlatform:save(key, data)
  error("IPlatform:save() must be implemented by platform adapter")
end

--- Load data from persistent storage
--- Retrieves and deserializes data previously saved under the given key.
--- Returns nil if the key doesn't exist or if deserialization fails.
---
--- @param key string Unique identifier for the data
--- @return table|nil Deserialized Lua table if found, nil if not found or error
function IPlatform:load(key)
  error("IPlatform:load() must be implemented by platform adapter")
end

--- Delete data from persistent storage
--- Removes data stored under the given key.
---
--- @param key string Unique identifier for the data to delete
--- @return boolean True if deletion succeeded or key didn't exist
function IPlatform:delete(key)
  error("IPlatform:delete() must be implemented by platform adapter")
end

--- Get the current platform locale
--- Returns the user's preferred language/locale as a BCP 47 language tag.
--- Used by i18n system to select appropriate translations.
---
--- @return string BCP 47 language tag (e.g., "en-US", "fr-FR", "ja-JP", "zh-CN")
function IPlatform:get_locale()
  error("IPlatform:get_locale() must be implemented by platform adapter")
end

--- Check if platform supports a capability
--- Enables runtime feature detection for optional platform features.
--- See docs/platform-capabilities.md for standard capability names.
---
--- @param cap string Capability name (e.g., "filesystem", "touch", "gamepad")
--- @return boolean True if platform supports this capability
function IPlatform:has_capability(cap)
  error("IPlatform:has_capability() must be implemented by platform adapter")
end

--- Get platform name
--- Returns a string identifying the current platform.
---
--- @return string Platform identifier (e.g., "web", "ios", "android", "electron", "mock")
function IPlatform:get_name()
  error("IPlatform:get_name() must be implemented by platform adapter")
end

--- Standard capability names that platforms should recognize:
IPlatform.CAPABILITIES = {
  -- Core capabilities
  PERSISTENT_STORAGE = "persistent_storage",  -- Can save data across app restarts
  FILESYSTEM = "filesystem",                   -- Has direct file system access
  NETWORK = "network",                         -- Has network connectivity

  -- Input capabilities
  TOUCH = "touch",                             -- Supports touch input
  MOUSE = "mouse",                             -- Has mouse/trackpad
  KEYBOARD = "keyboard",                       -- Has physical keyboard
  GAMEPAD = "gamepad",                         -- Supports game controllers

  -- System capabilities
  CLIPBOARD = "clipboard",                     -- Can access system clipboard
  NOTIFICATIONS = "notifications",             -- Can show system notifications
  AUDIO = "audio",                             -- Can play audio
  CAMERA = "camera",                           -- Has camera access
  GEOLOCATION = "geolocation",                 -- Has location services
  VIBRATION = "vibration",                     -- Can provide haptic feedback
}

--- Standard platform names
IPlatform.PLATFORMS = {
  WEB = "web",
  IOS = "ios",
  ANDROID = "android",
  ELECTRON = "electron",
  MOCK = "mock",
  TEST = "test",
}

--- Validate that an object implements the IPlatform interface
--- Used for testing and debugging to ensure platform adapters conform.
--- @param obj any Object to validate
--- @return boolean True if object implements IPlatform correctly
--- @return string|nil Error message if validation failed
function IPlatform.validate(obj)
  if type(obj) ~= "table" then
    return false, "Platform must be a table"
  end

  -- Check required methods exist and are functions
  local required_methods = {"save", "load", "get_locale", "has_capability"}
  for _, method in ipairs(required_methods) do
    if type(obj[method]) ~= "function" then
      return false, string.format("Platform missing required method: %s", method)
    end
  end

  return true, nil
end

--- Test interface conformance by calling all required methods
--- @param obj any Object to test
--- @return boolean True if all methods work correctly
--- @return table Array of test results
function IPlatform.test_conformance(obj)
  local results = {}
  local all_passed = true

  -- Test save
  local save_ok, save_err = pcall(function()
    obj:save("__test_key__", {test = "data"})
  end)
  table.insert(results, {method = "save", passed = save_ok, error = save_err})
  if not save_ok then all_passed = false end

  -- Test load
  local load_ok, load_err = pcall(function()
    obj:load("__test_key__")
  end)
  table.insert(results, {method = "load", passed = load_ok, error = load_err})
  if not load_ok then all_passed = false end

  -- Test get_locale
  local locale_ok, locale_result = pcall(function()
    return obj:get_locale()
  end)
  local locale_valid = locale_ok and type(locale_result) == "string"
  table.insert(results, {method = "get_locale", passed = locale_valid, error = not locale_ok and locale_result or nil})
  if not locale_valid then all_passed = false end

  -- Test has_capability
  local cap_ok, cap_result = pcall(function()
    return obj:has_capability("persistent_storage")
  end)
  local cap_valid = cap_ok and type(cap_result) == "boolean"
  table.insert(results, {method = "has_capability", passed = cap_valid, error = not cap_ok and cap_result or nil})
  if not cap_valid then all_passed = false end

  -- Cleanup test key
  pcall(function()
    if obj.delete then
      obj:delete("__test_key__")
    end
  end)

  return all_passed, results
end

return IPlatform
