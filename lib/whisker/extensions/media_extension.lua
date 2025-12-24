--- Media Extension
-- Registers media-related factories with the container
-- @module whisker.extensions.media_extension
-- @author Whisker Core Team
-- @license MIT

local MediaExtension = {}

--- Register media factories with the container
-- @param container Container The DI container
-- @param events EventBus The event bus instance
function MediaExtension.register(container, events)
  -- Register asset_cache (leaf - no dependencies beyond event_bus)
  container:register("asset_cache", function(c)
    local AssetCache = require("whisker.media.AssetCache")
    return AssetCache.new({}, {
      event_bus = c:resolve("events"),
      logger = c:resolve("logger")
    })
  end, {
    singleton = true,
    implements = "IAssetCache",
    depends = {"events", "logger"}
  })

  -- Register asset_loader (depends on event_bus)
  container:register("asset_loader", function(c)
    local AssetLoader = require("whisker.media.AssetLoader")
    return AssetLoader.new({}, {
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IAssetLoader",
    depends = {"events"}
  })

  -- Register asset_manager (depends on cache and loader)
  container:register("asset_manager", function(c)
    local AssetManager = require("whisker.media.AssetManager")
    return AssetManager.new({}, {
      asset_cache = c:resolve("asset_cache"),
      asset_loader = c:resolve("asset_loader"),
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IAssetManager",
    depends = {"asset_cache", "asset_loader", "events"}
  })

  -- Register audio_manager (depends on asset_manager)
  container:register("audio_manager", function(c)
    local AudioManager = require("whisker.media.AudioManager")
    return AudioManager.new({}, {
      asset_manager = c:resolve("asset_manager"),
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IAudioManager",
    depends = {"asset_manager", "events"}
  })

  -- Register image_manager (depends on asset_manager)
  container:register("image_manager", function(c)
    local ImageManager = require("whisker.media.ImageManager")
    return ImageManager.new({}, {
      asset_manager = c:resolve("asset_manager"),
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IImageManager",
    depends = {"asset_manager", "events"}
  })

  -- Register preload_manager (depends on asset_manager)
  container:register("preload_manager", function(c)
    local PreloadManager = require("whisker.media.PreloadManager")
    return PreloadManager.new({}, {
      asset_manager = c:resolve("asset_manager"),
      event_bus = c:resolve("events")
    })
  end, {
    singleton = true,
    implements = "IPreloadManager",
    depends = {"asset_manager", "events"}
  })

  -- Register bundlers (lazy loaded - typically only needed for export)
  container:register_lazy("web_bundler", "whisker.media.bundlers.WebBundler", {
    singleton = false,
    implements = "IBundler"
  })

  container:register_lazy("desktop_bundler", "whisker.media.bundlers.DesktopBundler", {
    singleton = false,
    implements = "IBundler"
  })

  container:register_lazy("mobile_bundler", "whisker.media.bundlers.MobileBundler", {
    singleton = false,
    implements = "IBundler"
  })

  -- Register media_directive_parser (depends on all managers)
  container:register("media_directive_parser", function(c)
    local MediaDirectiveParser = require("whisker.media.MediaDirectiveParser")
    return MediaDirectiveParser.new({}, {
      audio_manager = c:resolve("audio_manager"),
      image_manager = c:resolve("image_manager"),
      preload_manager = c:resolve("preload_manager")
    })
  end, {
    singleton = true,
    depends = {"audio_manager", "image_manager", "preload_manager"}
  })
end

return MediaExtension
