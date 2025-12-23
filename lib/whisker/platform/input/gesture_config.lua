--- Gesture Configuration
--- Customizable settings for touch gesture recognition.
---
--- These defaults can be overridden by platform-specific configurations
--- or user preferences. All time values are in milliseconds, distances
--- are in logical pixels (may need to be scaled for device pixel ratio).
---
--- @module whisker.platform.input.gesture_config
--- @author Whisker Core Team
--- @license MIT

local GestureConfig = {}

--- Default gesture configuration
GestureConfig.defaults = {
  -- Long-press gesture
  long_press = {
    duration = 500,         -- Time to hold before triggering (ms)
    movement_tolerance = 10, -- Max movement during hold (pixels)
  },

  -- Tap gesture
  tap = {
    max_duration = 300,     -- Max time between down and up (ms)
    max_movement = 10,      -- Max movement during tap (pixels)
    double_tap_delay = 300, -- Max time between taps for double-tap (ms)
  },

  -- Swipe gesture
  swipe = {
    min_distance = 50,      -- Minimum swipe distance (pixels)
    min_velocity = 0.5,     -- Minimum velocity (pixels/ms)
    max_off_path = 100,     -- Max perpendicular deviation (pixels)
  },

  -- Pinch/zoom gesture
  pinch = {
    enabled = false,        -- Whether pinch zoom is enabled
    min_scale_change = 0.1, -- Minimum scale change to trigger
  },

  -- Scroll gesture
  scroll = {
    inertia = true,         -- Enable momentum scrolling
    deceleration = 0.95,    -- Deceleration factor for momentum
    min_velocity = 0.1,     -- Min velocity to start momentum
  },

  -- Prevention of default browser behaviors
  prevent_defaults = {
    touch_scroll = true,    -- Prevent pull-to-refresh on mobile
    pinch_zoom = true,      -- Prevent browser pinch-to-zoom
    double_tap_zoom = true, -- Prevent browser double-tap zoom
    context_menu = true,    -- Prevent long-press context menu
    text_selection = false, -- Whether to prevent text selection
  },

  -- Haptic feedback settings
  haptic = {
    enabled = true,         -- Enable haptic feedback on supported devices
    tap_style = "light",    -- Style for tap: "light", "medium", "heavy"
    long_press_style = "medium",
    swipe_style = "light",
    selection_style = "selection",
  },
}

--- Platform-specific overrides
GestureConfig.platforms = {
  -- iOS defaults (higher precision touchscreen)
  ios = {
    long_press = {
      duration = 500,
    },
    swipe = {
      min_distance = 40,
    },
    haptic = {
      enabled = true,
    },
  },

  -- Android defaults
  android = {
    long_press = {
      duration = 500,
    },
    swipe = {
      min_distance = 48,  -- Material Design touch target
    },
    haptic = {
      enabled = true,
    },
  },

  -- Web defaults (mouse-optimized)
  web = {
    long_press = {
      duration = 600,     -- Longer for accidental prevention
    },
    swipe = {
      min_distance = 60,
    },
    haptic = {
      enabled = false,    -- Not widely supported
    },
  },

  -- Electron/desktop defaults
  electron = {
    long_press = {
      duration = 700,
    },
    tap = {
      max_duration = 200, -- Faster clicks on desktop
    },
    swipe = {
      min_distance = 80,  -- Trackpad swipes need more distance
    },
    haptic = {
      enabled = false,
    },
  },
}

--- Get configuration for a specific platform
--- Merges platform-specific overrides with defaults.
--- @param platform_name string Platform name ("ios", "android", "web", "electron")
--- @return table Merged configuration
function GestureConfig.get(platform_name)
  local config = GestureConfig._deep_copy(GestureConfig.defaults)

  local platform_overrides = GestureConfig.platforms[platform_name]
  if platform_overrides then
    config = GestureConfig._merge(config, platform_overrides)
  end

  return config
end

--- Deep copy a table
--- @param t table Table to copy
--- @return table Copy
function GestureConfig._deep_copy(t)
  if type(t) ~= "table" then
    return t
  end

  local copy = {}
  for k, v in pairs(t) do
    copy[k] = GestureConfig._deep_copy(v)
  end
  return copy
end

--- Deep merge two tables
--- @param base table Base table
--- @param override table Override table
--- @return table Merged table
function GestureConfig._merge(base, override)
  if type(base) ~= "table" or type(override) ~= "table" then
    return override
  end

  local result = GestureConfig._deep_copy(base)
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = GestureConfig._merge(result[k], v)
    else
      result[k] = GestureConfig._deep_copy(v)
    end
  end
  return result
end

--- Create a custom configuration
--- @param overrides table Custom overrides
--- @param platform_name string|nil Base platform (optional)
--- @return table Custom configuration
function GestureConfig.create(overrides, platform_name)
  local base = platform_name and GestureConfig.get(platform_name) or GestureConfig.defaults
  return GestureConfig._merge(base, overrides or {})
end

--- Validate a configuration
--- @param config table Configuration to validate
--- @return boolean True if valid
--- @return string|nil Error message if invalid
function GestureConfig.validate(config)
  if type(config) ~= "table" then
    return false, "Configuration must be a table"
  end

  -- Check long_press
  if config.long_press then
    if config.long_press.duration and config.long_press.duration < 0 then
      return false, "long_press.duration must be positive"
    end
  end

  -- Check tap
  if config.tap then
    if config.tap.max_duration and config.tap.max_duration < 0 then
      return false, "tap.max_duration must be positive"
    end
  end

  -- Check swipe
  if config.swipe then
    if config.swipe.min_distance and config.swipe.min_distance < 0 then
      return false, "swipe.min_distance must be positive"
    end
  end

  return true, nil
end

return GestureConfig
