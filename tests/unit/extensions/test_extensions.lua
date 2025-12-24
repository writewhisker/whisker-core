--- Extensions Unit Tests
-- Tests for the extension modules
-- @module tests.unit.extensions.test_extensions
-- @author Whisker Core Team

describe("Extensions", function()
  local Extensions
  local Container
  local EventBus

  before_each(function()
    -- Clear packages
    for k in pairs(package.loaded) do
      if k:match("^whisker%.extensions") or k:match("^whisker%.kernel") then
        package.loaded[k] = nil
      end
    end
    Extensions = require("whisker.extensions")
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
  end)

  describe("load_all()", function()
    it("should load all extensions without error", function()
      local container = Container.new()
      local events = EventBus.new()

      assert.has_no_errors(function()
        Extensions.load_all(container, events)
      end)
    end)

    it("should emit extensions:loaded event", function()
      local container = Container.new()
      local events = EventBus.new()
      local event_fired = false

      events:on("extensions:loaded", function()
        event_fired = true
      end)

      Extensions.load_all(container, events)

      assert.is_true(event_fired)
    end)

    it("should accept options parameter", function()
      local container = Container.new()
      local events = EventBus.new()

      assert.has_no_errors(function()
        Extensions.load_all(container, events, { debug = true })
      end)
    end)
  end)
end)

describe("ServiceExtension", function()
  local ServiceExtension
  local Container
  local EventBus

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.extensions") or k:match("^whisker%.kernel") then
        package.loaded[k] = nil
      end
    end
    ServiceExtension = require("whisker.extensions.service_extension")
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
  end)

  describe("register()", function()
    it("should register logger service", function()
      local container = Container.new()
      local events = EventBus.new()

      ServiceExtension.register(container, events)

      assert.is_true(container:has("logger"))
    end)

    it("should create logger with expected methods", function()
      local container = Container.new()
      local events = EventBus.new()

      ServiceExtension.register(container, events)
      local logger = container:resolve("logger")

      assert.is_function(logger.info)
      assert.is_function(logger.warn)
      assert.is_function(logger.error)
      assert.is_function(logger.debug)
    end)

    it("should respect log_level option", function()
      local container = Container.new()
      local events = EventBus.new()

      ServiceExtension.register(container, events, { log_level = "debug" })
      local logger = container:resolve("logger")

      assert.equals("debug", logger.level)
    end)

    it("should not override existing logger", function()
      local container = Container.new()
      local events = EventBus.new()
      local custom_logger = { custom = true }

      container:register("logger", custom_logger, { singleton = true })
      ServiceExtension.register(container, events)

      local logger = container:resolve("logger")
      assert.is_true(logger.custom)
    end)
  end)
end)

describe("CoreExtension", function()
  local CoreExtension
  local Container
  local EventBus

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker") then
        package.loaded[k] = nil
      end
    end
    require("whisker.kernel.init")
    CoreExtension = require("whisker.extensions.core_extension")
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
  end)

  describe("register()", function()
    local container, events

    before_each(function()
      container = Container.new()
      events = EventBus.new()
      container:register("events", events, { singleton = true })

      -- Register logger first (dependency)
      container:register("logger", function()
        return { info = function() end, warn = function() end, error = function() end, debug = function() end }
      end, { singleton = true })

      CoreExtension.register(container, events)
    end)

    it("should register choice_factory", function()
      assert.is_true(container:has("choice_factory"))
    end)

    it("should register passage_factory", function()
      assert.is_true(container:has("passage_factory"))
    end)

    it("should register story_factory", function()
      assert.is_true(container:has("story_factory"))
    end)

    it("should register game_state_factory", function()
      assert.is_true(container:has("game_state_factory"))
    end)

    it("should register lua_interpreter_factory", function()
      assert.is_true(container:has("lua_interpreter_factory"))
    end)

    it("should register engine_factory", function()
      assert.is_true(container:has("engine_factory"))
    end)

    it("should resolve choice_factory with create method", function()
      local factory = container:resolve("choice_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("should resolve passage_factory with create method", function()
      local factory = container:resolve("passage_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("should resolve story_factory with create method", function()
      local factory = container:resolve("story_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("should resolve engine_factory with create method", function()
      local factory = container:resolve("engine_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)
  end)
end)

describe("MediaExtension", function()
  local MediaExtension
  local Container
  local EventBus

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker") then
        package.loaded[k] = nil
      end
    end
    require("whisker.kernel.init")
    MediaExtension = require("whisker.extensions.media_extension")
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
  end)

  describe("register()", function()
    local container, events

    before_each(function()
      container = Container.new()
      events = EventBus.new()
      container:register("events", events, { singleton = true })

      -- Register logger first (dependency)
      container:register("logger", function()
        return { info = function() end, warn = function() end, error = function() end, debug = function() end }
      end, { singleton = true })

      MediaExtension.register(container, events)
    end)

    it("should register asset_cache", function()
      assert.is_true(container:has("asset_cache"))
    end)

    it("should register asset_loader", function()
      assert.is_true(container:has("asset_loader"))
    end)

    it("should register asset_manager", function()
      assert.is_true(container:has("asset_manager"))
    end)

    it("should register audio_manager", function()
      assert.is_true(container:has("audio_manager"))
    end)

    it("should register image_manager", function()
      assert.is_true(container:has("image_manager"))
    end)

    it("should register preload_manager", function()
      assert.is_true(container:has("preload_manager"))
    end)

    it("should register web_bundler", function()
      assert.is_true(container:has("web_bundler"))
    end)

    it("should register desktop_bundler", function()
      assert.is_true(container:has("desktop_bundler"))
    end)

    it("should register mobile_bundler", function()
      assert.is_true(container:has("mobile_bundler"))
    end)

    it("should register media_directive_parser", function()
      assert.is_true(container:has("media_directive_parser"))
    end)

    it("should resolve asset_cache with expected methods", function()
      local cache = container:resolve("asset_cache")

      assert.is_not_nil(cache)
      assert.is_function(cache.get)
      assert.is_function(cache.set)
    end)

    it("should resolve asset_manager with expected methods", function()
      local manager = container:resolve("asset_manager")

      assert.is_not_nil(manager)
      assert.is_function(manager.register)
      assert.is_function(manager.load)
    end)

    it("should resolve audio_manager with expected methods", function()
      local manager = container:resolve("audio_manager")

      assert.is_not_nil(manager)
      assert.is_function(manager.play)
    end)

    it("should resolve image_manager with expected methods", function()
      local manager = container:resolve("image_manager")

      assert.is_not_nil(manager)
      assert.is_function(manager.display)
    end)
  end)
end)
