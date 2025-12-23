--- Whisker Interfaces
-- Central export for all interface definitions
-- @module whisker.interfaces
-- @author Whisker Core Team
-- @license MIT

return {
  IFormat = require("whisker.interfaces.format"),
  IState = require("whisker.interfaces.state"),
  ISerializer = require("whisker.interfaces.serializer"),
  IConditionEvaluator = require("whisker.interfaces.condition"),
  IEngine = require("whisker.interfaces.engine"),
  IPlugin = require("whisker.interfaces.plugin"),
  PluginHooks = require("whisker.interfaces.plugin_hooks"),
  -- Accessibility interfaces
  IAccessible = require("whisker.interfaces.accessible"),
  IKeyboardHandler = require("whisker.interfaces.keyboard_handler"),
  IScreenReaderAdapter = require("whisker.interfaces.screen_reader"),
  IFocusManager = require("whisker.interfaces.focus_manager"),
}
