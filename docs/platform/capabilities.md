# Platform Capabilities Reference

This document defines the standard capability names that platforms should recognize.

## Storage Capabilities

### `persistent_storage`

Can save data that persists across application restarts.

| Platform | Support | Implementation |
|----------|---------|----------------|
| Web | Yes | localStorage |
| iOS | Yes | UserDefaults, Keychain |
| Android | Yes | SharedPreferences |
| Electron | Yes | File system |

### `filesystem`

Has direct access to the file system for reading/writing arbitrary files.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Limited | File System Access API (Chrome 86+) |
| iOS | Yes | App sandbox only |
| Android | Yes | App internal storage |
| Electron | Yes | Full access |

## Network Capabilities

### `network`

Has network connectivity for HTTP requests, WebSockets, etc.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Subject to CORS |
| iOS | Yes | Requires network permission |
| Android | Yes | Requires INTERNET permission |
| Electron | Yes | Full access |

## Input Capabilities

### `touch`

Supports touch input (tap, swipe, pinch gestures).

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Varies | True on mobile browsers |
| iOS | Yes | Always |
| Android | Yes | Always |
| Electron | No | Unless touch display |

### `mouse`

Has mouse or trackpad input.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Varies | True on desktop browsers |
| iOS | Limited | iPad with trackpad (iPadOS 13.4+) |
| Android | No | Some Chromebooks |
| Electron | Yes | Always |

### `keyboard`

Has physical keyboard input (not on-screen).

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Desktop browsers |
| iOS | Varies | External keyboard only |
| Android | Varies | External keyboard only |
| Electron | Yes | Always |

### `gamepad`

Supports game controllers (Xbox, PlayStation, MFi).

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Gamepad API |
| iOS | Yes | MFi controllers, Xbox, PS |
| Android | Yes | Bluetooth controllers |
| Electron | Yes | OS-level support |

## System Capabilities

### `clipboard`

Can read from and write to system clipboard.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Clipboard API |
| iOS | Yes | UIPasteboard |
| Android | Yes | ClipboardManager |
| Electron | Yes | Node.js clipboard |

### `notifications`

Can show system notifications.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Notification API (requires permission) |
| iOS | Yes | UNUserNotificationCenter |
| Android | Yes | NotificationManager |
| Electron | Yes | Node.js notifications |

### `audio`

Can play audio files and sounds.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Web Audio API, HTMLAudioElement |
| iOS | Yes | AVFoundation |
| Android | Yes | MediaPlayer |
| Electron | Yes | HTMLAudioElement, native |

### `camera`

Has camera access for capturing photos/video.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | getUserMedia (requires permission) |
| iOS | Yes | AVCaptureDevice |
| Android | Yes | Camera2 API |
| Electron | Varies | Webcam if present |

### `geolocation`

Has access to device location.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Yes | Geolocation API (requires permission) |
| iOS | Yes | Core Location |
| Android | Yes | Location Services |
| Electron | No | Desktop typically lacks GPS |

### `vibration`

Can provide haptic feedback.

| Platform | Support | Notes |
|----------|---------|-------|
| Web | Varies | Vibration API (mobile only) |
| iOS | Yes | UIImpactFeedbackGenerator |
| Android | Yes | Vibrator |
| Electron | No | Desktop lacks vibration |

## Querying Capabilities

```lua
local platform = require("whisker.platform.factory").get()

-- Check specific capability
if platform:has_capability("touch") then
  -- Enable touch-specific UI
end

-- Check multiple capabilities
local caps = {"touch", "vibration", "gamepad"}
for _, cap in ipairs(caps) do
  print(cap .. ": " .. tostring(platform:has_capability(cap)))
end
```

## Capability-Based Feature Detection

```lua
local function get_input_mode(platform)
  if platform:has_capability("touch") then
    return "touch"
  elseif platform:has_capability("mouse") then
    return "mouse"
  elseif platform:has_capability("keyboard") then
    return "keyboard"
  else
    return "none"
  end
end

local function should_show_save_button(platform)
  return platform:has_capability("persistent_storage")
end

local function can_show_location_features(platform)
  return platform:has_capability("geolocation")
end
```

## Adding Custom Capabilities

Platform implementations can define custom capabilities:

```lua
-- In custom platform implementation
function MyPlatform:has_capability(cap)
  -- Standard capabilities
  if cap == "persistent_storage" then return true end
  if cap == "touch" then return true end

  -- Custom capabilities
  if cap == "my_custom_feature" then return true end
  if cap == "premium_features" then return self.is_premium end

  return false
end
```

Query custom capabilities:

```lua
if platform:has_capability("my_custom_feature") then
  -- Enable custom feature
end
```
