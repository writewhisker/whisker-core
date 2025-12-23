# whisker-core Platform Integration

This documentation covers the platform abstraction layer that enables whisker-core to run across multiple platforms: web browsers, iOS, Android, desktop (Electron), and React Native.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        whisker-core Engine                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │  Parser  │  │  Engine  │  │   Save   │  │   i18n   │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       └─────────────┼─────────────┼─────────────┘                   │
│                     │             │                                  │
│              ┌──────▼─────────────▼──────┐                          │
│              │     Platform Factory      │                          │
│              │   (Auto-detection/Config) │                          │
│              └───────────┬───────────────┘                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ IPlatform   │   │ IPlatform   │   │ IPlatform   │
│ (Web)       │   │ (iOS)       │   │ (Android)   │
└─────────────┘   └─────────────┘   └─────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ localStorage│   │ UserDefaults│   │ SharedPrefs │
│ navigator   │   │ Swift Bridge│   │ JNI Bridge  │
│ Web APIs    │   │ iOS APIs    │   │ Android APIs│
└─────────────┘   └─────────────┘   └─────────────┘
```

## Quick Start

### Basic Usage

```lua
local PlatformFactory = require("whisker.platform.factory")

-- Auto-detect platform
local platform = PlatformFactory.create()

-- Or specify explicitly
local platform = PlatformFactory.create("web")

-- Use platform services
platform:save("game_state", {chapter = 3, score = 100})
local state = platform:load("game_state")
local locale = platform:get_locale()

if platform:has_capability("touch") then
  -- Enable touch controls
end
```

### Platform Detection

The factory automatically detects the current platform:

```lua
local platform_name = PlatformFactory.detect()
-- Returns: "web", "ios", "android", "electron", or "mock"
```

Detection order:
1. `WHISKER_PLATFORM` global variable (explicit override)
2. `ENVIRONMENT` global variable (set by host app)
3. Bridge function detection (`ios_platform_save`, `android_platform_save`, etc.)
4. JavaScript bridge detection (`js` global for web)
5. Default: `mock` (for development/testing)

## IPlatform Interface

All platforms implement this interface:

```lua
-- Save data to persistent storage
-- @param key string Unique identifier
-- @param data table Lua table to store
-- @return boolean Success
platform:save(key, data)

-- Load data from persistent storage
-- @param key string Unique identifier
-- @return table|nil Loaded data or nil if not found
platform:load(key)

-- Delete data from storage
-- @param key string Unique identifier
-- @return boolean Success
platform:delete(key)

-- Get user's locale
-- @return string BCP 47 language tag (e.g., "en-US")
platform:get_locale()

-- Check platform capability
-- @param cap string Capability name
-- @return boolean Whether capability is supported
platform:has_capability(cap)

-- Get platform name
-- @return string Platform identifier
platform:get_name()
```

## Standard Capabilities

| Capability | Description |
|------------|-------------|
| `persistent_storage` | Can save data across restarts |
| `filesystem` | Direct file system access |
| `network` | Network connectivity |
| `touch` | Touch input support |
| `mouse` | Mouse/trackpad input |
| `keyboard` | Physical keyboard |
| `gamepad` | Game controller support |
| `clipboard` | System clipboard access |
| `notifications` | System notifications |
| `audio` | Audio playback |
| `camera` | Camera access |
| `geolocation` | Location services |
| `vibration` | Haptic feedback |

## Platform Implementations

### Web Platform

Uses browser APIs:
- **Storage**: localStorage (5-10MB limit)
- **Locale**: navigator.language
- **Capabilities**: Feature detection via JavaScript

```lua
local platform = require("whisker.platform.web").new({
  storage_prefix = "myapp:",  -- Key prefix for localStorage
  fallback_locale = "en-US",
})
```

### iOS Platform

Uses Swift bridge functions:
- **Storage**: UserDefaults or file system
- **Locale**: Locale.current
- **Capabilities**: UIDevice feature detection

Required Swift bridge functions:
- `ios_platform_save(key, json)`
- `ios_platform_load(key)`
- `ios_platform_get_locale()`
- `ios_platform_has_capability(cap)`

See `platform-native/ios/README.md` for integration guide.

### Android Platform

Uses Kotlin/JNI bridge:
- **Storage**: SharedPreferences or file system
- **Locale**: Locale.getDefault()
- **Capabilities**: PackageManager feature queries

Required JNI functions:
- `android_platform_save(key, json)`
- `android_platform_load(key)`
- `android_platform_get_locale()`
- `android_platform_has_capability(cap)`

See `platform-native/android/README.md` for integration guide.

### Electron Platform

Uses Node.js via preload script:
- **Storage**: File system (userData directory)
- **Locale**: app.getLocale()
- **Capabilities**: Desktop-oriented defaults

Required bridge functions:
- `electron_save(key, json)`
- `electron_load(key)`
- `electron_get_locale()`
- `electron_has_capability(cap)`

See `platform-native/electron/README.md` for template.

### Mock Platform

In-memory implementation for testing:

```lua
local MockPlatform = require("whisker.platform.mock")

local platform = MockPlatform.new({
  locale = "fr-FR",
  capabilities = {touch = true, gamepad = false},
  storage = {existing_key = '{"data":1}'},
})

-- Test helper methods
platform:set_locale("de-DE")
platform:set_capability("touch", false)
platform:set_failures(true, false)  -- Force save to fail
platform:get_stats()  -- Get usage statistics
platform:clear_storage()
```

## Input Handling

### Touch Handler

Recognizes gestures from raw touch events:

```lua
local TouchHandler = require("whisker.platform.input.touch_handler")

local handler = TouchHandler.new({
  on_gesture = function(type, data)
    if type == "tap" then
      print("Tapped at", data.x, data.y)
    elseif type == "swipe" then
      print("Swiped", data.direction)
    elseif type == "long_press" then
      print("Long press at", data.x, data.y)
    end
  end,
  long_press_duration = 500,  -- ms
  swipe_threshold = 50,       -- pixels
})

-- Platform code calls these:
handler:on_touch_start(x, y, timestamp)
handler:on_touch_move(x, y, timestamp)
handler:on_touch_end(x, y, timestamp)
```

### Input Normalizer

Unifies input from all sources into semantic events:

```lua
local InputNormalizer = require("whisker.platform.input.input_normalizer")

local normalizer = InputNormalizer.new()

-- Subscribe to semantic events
normalizer:on("select", function(data)
  print("Selection from", data.source)  -- "mouse", "touch", "keyboard", "gamepad"
end)

normalizer:on("navigate", function(data)
  print("Navigate", data.direction)  -- "up", "down", "left", "right"
end)

-- Platform code calls these:
normalizer:on_mouse_click(x, y, "left")
normalizer:on_touch_tap(x, y)
normalizer:on_key_press("Enter")
normalizer:on_gamepad_button("A")
```

## Serialization

Platform data is serialized to JSON:

```lua
local Serialization = require("whisker.platform.serialization")

-- Serialize Lua table to JSON
local json, err = Serialization.serialize({name = "test", value = 42})

-- Deserialize JSON to Lua table
local data, err = Serialization.deserialize(json)

-- Check if data is serializable
local can_serialize = Serialization.is_serializable(data)

-- Estimate storage size
local bytes = Serialization.estimate_size(data)
```

Non-serializable values (functions, userdata) are automatically filtered.

## Testing

### Mock Platform for Unit Tests

```lua
describe("Save system", function()
  local MockPlatform = require("whisker.platform.mock")

  it("saves and loads game state", function()
    local platform = MockPlatform.new()
    local SaveSystem = require("whisker.infrastructure.save_system")
    local save = SaveSystem.new(platform)

    save:save_game("slot1", {chapter = 3})
    local loaded = save:load_game("slot1")

    assert.equals(3, loaded.chapter)
  end)
end)
```

### Interface Conformance Testing

```lua
local IPlatform = require("whisker.platform.interface")

-- Validate implementation
local valid, err = IPlatform.validate(my_platform)

-- Run conformance tests
local passed, results = IPlatform.test_conformance(my_platform)
```

## Extending Platforms

Register custom platform implementations:

```lua
local PlatformFactory = require("whisker.platform.factory")

local MyPlatform = {
  new = function(config)
    return {
      save = function(self, key, data) ... end,
      load = function(self, key) ... end,
      get_locale = function(self) return "en-US" end,
      has_capability = function(self, cap) return true end,
      get_name = function(self) return "my_platform" end,
    }
  end
}

PlatformFactory.register("my_platform", MyPlatform)
local platform = PlatformFactory.create("my_platform")
```

## Files

```
lib/whisker/platform/
├── interface.lua       # IPlatform interface definition
├── factory.lua         # Platform factory with auto-detection
├── serialization.lua   # JSON serialization utilities
├── mock.lua            # Mock implementation for testing
├── web.lua             # Web/browser implementation
├── ios.lua             # iOS implementation
├── android.lua         # Android implementation
├── electron.lua        # Electron/desktop implementation
└── input/
    ├── touch_handler.lua    # Touch gesture recognition
    ├── input_normalizer.lua # Unified input handling
    └── gesture_config.lua   # Gesture configuration

platform-native/
├── ios/README.md       # iOS integration guide
├── android/README.md   # Android integration guide
├── react-native/README.md # React Native wrapper
└── electron/README.md  # Electron template

tests/unit/platform/
├── interface_spec.lua
├── factory_spec.lua
├── mock_spec.lua
├── serialization_spec.lua
└── input/
    ├── touch_handler_spec.lua
    └── input_normalizer_spec.lua
```
