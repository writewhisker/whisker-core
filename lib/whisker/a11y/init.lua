--- Whisker Accessibility Module
-- Provides accessibility features for interactive fiction
-- @module whisker.a11y
-- @author Whisker Core Team
-- @license MIT

return {
  -- Core components
  ScreenReaderAdapter = require("whisker.a11y.screen_reader_adapter"),
  FocusManager = require("whisker.a11y.focus_manager"),
  KeyboardNavigator = require("whisker.a11y.keyboard_navigator"),
  AriaManager = require("whisker.a11y.aria_manager"),

  -- Utilities
  utils = require("whisker.a11y.utils"),

  -- Preferences
  MotionPreference = require("whisker.a11y.motion_preference"),
  ContrastChecker = require("whisker.a11y.contrast_checker"),
}
