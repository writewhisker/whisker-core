--- Whisker Interfaces
-- Central export for all interface definitions
-- @module whisker.interfaces
-- @author Whisker Core Team
-- @license MIT

local Factories = require("whisker.interfaces.factories")
local Media = require("whisker.interfaces.media")
local Service = require("whisker.interfaces.service")

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
  -- Factory interfaces (DI pattern)
  IChoiceFactory = Factories.IChoiceFactory,
  IPassageFactory = Factories.IPassageFactory,
  IStoryFactory = Factories.IStoryFactory,
  IGameStateFactory = Factories.IGameStateFactory,
  ILuaInterpreterFactory = Factories.ILuaInterpreterFactory,
  IEngineFactory = Factories.IEngineFactory,
  Factories = Factories,
  -- Media interfaces (DI pattern)
  IAssetCache = Media.IAssetCache,
  IAssetLoader = Media.IAssetLoader,
  IAssetManager = Media.IAssetManager,
  IAudioManager = Media.IAudioManager,
  IImageManager = Media.IImageManager,
  IPreloadManager = Media.IPreloadManager,
  IBundler = Media.IBundler,
  Media = Media,
  -- Service interfaces (DI pattern)
  IService = Service.IService,
  IServiceRegistry = Service.IServiceRegistry,
  IServiceLifecycle = Service.IServiceLifecycle,
  ServiceStatus = Service.ServiceStatus,
  ServicePriority = Service.ServicePriority,
  Service = Service,
}
