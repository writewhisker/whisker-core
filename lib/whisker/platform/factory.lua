--- Platform Factory
--- Creates platform-specific implementations based on environment detection.
---
--- The factory automatically detects the current environment and returns
--- the appropriate IPlatform implementation. It can also be configured
--- to use a specific platform for testing.
---
--- Usage:
---   local factory = require("whisker.platform.factory")
---   local platform = factory.create()  -- Auto-detect environment
---   local platform = factory.create("mock")  -- Force specific platform
---
--- @module whisker.platform.factory
--- @author Whisker Core Team
--- @license MIT

local PlatformFactory = {}

-- Platform registry for lazy loading
local platform_registry = {
  web = "whisker.platform.web",
  electron = "whisker.platform.electron",
  ios = "whisker.platform.ios",
  android = "whisker.platform.android",
  mock = "whisker.platform.mock",
  test = "whisker.platform.mock",
}

-- Custom platform overrides
local custom_platforms = {}

--- Detect current execution environment
--- @return string Platform name ("web", "ios", "android", "electron", "mock")
function PlatformFactory.detect()
  -- Check for explicit environment variable
  if WHISKER_PLATFORM then
    return WHISKER_PLATFORM
  end

  -- Check global environment flag (set by host application)
  if ENVIRONMENT then
    local env = ENVIRONMENT:lower()
    if platform_registry[env] then
      return env
    end
  end

  -- Check for iOS-specific globals (set by iOS bridge)
  if ios_platform_save then
    return "ios"
  end

  -- Check for Android-specific globals (set by JNI bridge)
  if android_platform_save then
    return "android"
  end

  -- Check for Electron-specific globals
  if electron_save or (type(require) == "function" and pcall(function() require("electron") end)) then
    return "electron"
  end

  -- Check for web-specific globals (browser environment)
  -- Note: In actual Lua running in browser (via Fengari or similar),
  -- these checks would need to be adapted
  if js then
    return "web"
  end

  -- Default to mock for pure Lua environment (development/testing)
  return "mock"
end

--- Create a platform instance
--- @param platform_name string|nil Platform name (nil = auto-detect)
--- @param config table|nil Platform-specific configuration
--- @return IPlatform Platform implementation instance
function PlatformFactory.create(platform_name, config)
  platform_name = platform_name or PlatformFactory.detect()
  config = config or {}

  -- Check for custom registered platforms first
  if custom_platforms[platform_name] then
    return custom_platforms[platform_name].new(config)
  end

  -- Get platform module path from registry
  local module_path = platform_registry[platform_name]
  if not module_path then
    error("Unknown platform: " .. tostring(platform_name))
  end

  -- Load and instantiate platform
  local ok, platform_module = pcall(require, module_path)
  if not ok then
    error("Failed to load platform '" .. platform_name .. "': " .. tostring(platform_module))
  end

  return platform_module.new(config)
end

--- Register a custom platform implementation
--- Allows plugins and applications to provide custom platform adapters.
---
--- @param name string Platform name
--- @param module table Platform module with new() constructor
function PlatformFactory.register(name, module)
  if type(name) ~= "string" or name == "" then
    error("Platform name must be a non-empty string")
  end

  if type(module) ~= "table" or type(module.new) ~= "function" then
    error("Platform module must have a new() constructor")
  end

  custom_platforms[name] = module
end

--- Unregister a custom platform
--- @param name string Platform name to remove
function PlatformFactory.unregister(name)
  custom_platforms[name] = nil
end

--- List all available platforms
--- @return table Array of platform names
function PlatformFactory.list()
  local platforms = {}

  -- Add registered platforms
  for name in pairs(platform_registry) do
    table.insert(platforms, name)
  end

  -- Add custom platforms
  for name in pairs(custom_platforms) do
    if not platform_registry[name] then
      table.insert(platforms, name)
    end
  end

  table.sort(platforms)
  return platforms
end

--- Check if a platform is available (module can be loaded)
--- @param name string Platform name
--- @return boolean True if platform can be created
function PlatformFactory.is_available(name)
  -- Check custom platforms first
  if custom_platforms[name] then
    return true
  end

  local module_path = platform_registry[name]
  if not module_path then
    return false
  end

  -- Try to load the module
  local ok = pcall(require, module_path)
  return ok
end

--- Get the singleton platform instance (lazy-initialized)
--- This is the recommended way to access the platform for most use cases.
---
--- @param force_new boolean|nil If true, create new instance instead of cached one
--- @return IPlatform The platform singleton
function PlatformFactory.get(force_new)
  if force_new or not PlatformFactory._instance then
    PlatformFactory._instance = PlatformFactory.create()
  end
  return PlatformFactory._instance
end

--- Reset the platform singleton (for testing)
function PlatformFactory.reset()
  PlatformFactory._instance = nil
end

--- Set a specific platform instance (for testing/mocking)
--- @param platform IPlatform Platform instance to use as singleton
function PlatformFactory.set(platform)
  PlatformFactory._instance = platform
end

return PlatformFactory
