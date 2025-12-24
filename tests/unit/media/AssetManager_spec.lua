-- Tests for AssetManager module
describe("AssetManager", function()
  local AssetManager
  local mock_event_bus
  local mock_cache
  local mock_loader

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.AssetLoader"] = nil
    package.loaded["whisker.media.types"] = nil
    package.loaded["whisker.media.schemas"] = nil
    package.loaded["whisker.media.FormatDetector"] = nil
    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock cache
    mock_cache = {
      _data = {},
      get = function(self, id)
        return self._data[id]
      end,
      set = function(self, id, data, size)
        self._data[id] = data
        return true
      end,
      has = function(self, id)
        return self._data[id] ~= nil
      end,
      remove = function(self, id)
        if self._data[id] then
          self._data[id] = nil
          return true
        end
        return false
      end,
      pin = function() return true end,
      unpin = function() return true end,
      retain = function() return true end,
      release = function() return true end,
      getRefCount = function() return 0 end,
      getStats = function()
        return {bytesUsed = 0, bytesLimit = 100, assetCount = 0, hitRate = 0}
      end,
      setMemoryBudget = function() end,
      clear = function(self) self._data = {} end
    }

    -- Create mock loader
    mock_loader = {
      load = function(self, config, callback)
        if callback then
          callback({
            id = config.id,
            type = config.type,
            data = "mock data",
            sizeBytes = 100
          }, nil)
        end
        return true
      end,
      cancel = function() return true end
    }
  end)

  describe("initialize", function()
    it("initializes with default config", function()
      local stats = AssetManager:getCacheStats()
      assert.is_not_nil(stats)
      assert.equals(0, stats.assetCount)
    end)

    it("initializes with custom memory budget", function()
      AssetManager:initialize({memoryBudget = 50 * 1024 * 1024})
      local stats = AssetManager:getCacheStats()
      assert.equals(50 * 1024 * 1024, stats.bytesLimit)
    end)
  end)

  describe("register", function()
    it("registers valid audio asset", function()
      local success, err = AssetManager:register({
        id = "test_audio",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("registers valid image asset", function()
      local success, err = AssetManager:register({
        id = "test_image",
        type = "image",
        variants = {{density = "1x", path = "test.png"}}
      })

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("rejects invalid asset config", function()
      local success, err = AssetManager:register({
        type = "audio"
        -- missing id
      })

      assert.is_false(success)
      assert.is_not_nil(err)
      assert.equals("validation", err.type)
    end)

    it("rejects duplicate asset id", function()
      AssetManager:register({
        id = "duplicate",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      local success, err = AssetManager:register({
        id = "duplicate",
        type = "audio",
        sources = {{format = "ogg", path = "test.ogg"}}
      })

      assert.is_false(success)
      assert.equals("duplicate", err.type)
    end)
  end)

  describe("unregister", function()
    it("unregisters asset", function()
      AssetManager:register({
        id = "temp",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      local result = AssetManager:unregister("temp")
      assert.is_true(result)
      assert.is_nil(AssetManager:getConfig("temp"))
    end)

    it("returns false for unregistered asset", function()
      local result = AssetManager:unregister("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("getState", function()
    it("returns unloaded for new assets", function()
      AssetManager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      assert.equals("unloaded", AssetManager:getState("test"))
    end)
  end)

  describe("isLoaded", function()
    it("returns false for unloaded assets", function()
      AssetManager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      assert.is_false(AssetManager:isLoaded("test"))
    end)
  end)

  describe("getAllAssets", function()
    it("returns all registered asset ids", function()
      AssetManager:register({
        id = "audio1",
        type = "audio",
        sources = {{format = "mp3", path = "a.mp3"}}
      })

      AssetManager:register({
        id = "image1",
        type = "image",
        variants = {{density = "1x", path = "i.png"}}
      })

      local assets = AssetManager:getAllAssets()
      assert.equals(2, #assets)
    end)
  end)

  describe("pin and unpin", function()
    it("delegates to cache", function()
      AssetManager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      -- Pin before load won't work, but shouldn't error
      local result = AssetManager:pin("test")
      assert.is_false(result)
    end)
  end)

  describe("retain and release", function()
    it("tracks reference counts", function()
      AssetManager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      assert.equals(0, AssetManager:getRefCount("test"))
    end)
  end)

  describe("getCacheStats", function()
    it("returns cache statistics", function()
      local stats = AssetManager:getCacheStats()

      assert.is_number(stats.bytesUsed)
      assert.is_number(stats.bytesLimit)
      assert.is_number(stats.assetCount)
      assert.is_number(stats.hitRate)
    end)
  end)

  describe("setMemoryBudget", function()
    it("updates cache memory limit", function()
      AssetManager:setMemoryBudget(25 * 1024 * 1024)
      local stats = AssetManager:getCacheStats()
      assert.equals(25 * 1024 * 1024, stats.bytesLimit)
    end)
  end)

  describe("clearCache", function()
    it("clears cache without error", function()
      assert.has_no.errors(function()
        AssetManager:clearCache()
      end)
    end)
  end)

  describe("getConfig", function()
    it("returns registered config", function()
      local config = {
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}},
        metadata = {duration = 60}
      }

      AssetManager:register(config)
      local retrieved = AssetManager:getConfig("test")

      assert.equals("test", retrieved.id)
      assert.equals(60, retrieved.metadata.duration)
    end)

    it("returns nil for unregistered asset", function()
      assert.is_nil(AssetManager:getConfig("nonexistent"))
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(AssetManager._dependencies)
      assert.same({"asset_cache", "asset_loader", "event_bus"}, AssetManager._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(AssetManager.create)
    end)

    it("provides new constructor", function()
      assert.is_function(AssetManager.new)
    end)

    it("create returns a factory function", function()
      local factory = AssetManager.create({
        asset_cache = mock_cache,
        asset_loader = mock_loader,
        event_bus = mock_event_bus
      })
      assert.is_function(factory)
    end)

    it("factory creates manager instances with injected deps", function()
      local factory = AssetManager.create({
        asset_cache = mock_cache,
        asset_loader = mock_loader,
        event_bus = mock_event_bus
      })
      local manager = factory({})
      assert.is_not_nil(manager)
      assert.is_function(manager.register)
      assert.is_function(manager.load)
    end)

    it("new creates instance with injected cache", function()
      local manager = AssetManager.new({}, {asset_cache = mock_cache})
      assert.equals(mock_cache, manager._cache)
    end)

    it("new creates instance with injected loader", function()
      local manager = AssetManager.new({}, {asset_loader = mock_loader})
      assert.equals(mock_loader, manager._loader)
    end)

    it("new creates instance with injected event_bus", function()
      local manager = AssetManager.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, manager._event_bus)
    end)

    it("works without deps (backward compatibility)", function()
      local manager = AssetManager.new({})
      assert.is_not_nil(manager)
      assert.is_not_nil(manager._cache)
      assert.is_not_nil(manager._loader)
    end)
  end)

  describe("isRegistered", function()
    it("returns true for registered assets", function()
      local manager = AssetManager.new({})
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })
      assert.is_true(manager:isRegistered("test"))
    end)

    it("returns false for unregistered assets", function()
      local manager = AssetManager.new({})
      assert.is_false(manager:isRegistered("nonexistent"))
    end)
  end)

  describe("getAllIds", function()
    it("is alias for getAllAssets", function()
      assert.equals(AssetManager.getAllAssets, AssetManager.getAllIds)
    end)
  end)

  describe("event emission", function()
    it("emits asset:registered event on register", function()
      local manager = AssetManager.new({}, {event_bus = mock_event_bus})
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "asset:registered" then
          found = true
          assert.equals("test", e.data.assetId)
          assert.equals("audio", e.data.assetType)
        end
      end
      assert.is_true(found, "Should have emitted asset:registered event")
    end)

    it("emits asset:unregistered event on unregister", function()
      local manager = AssetManager.new({}, {
        event_bus = mock_event_bus,
        asset_cache = mock_cache
      })
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })
      mock_event_bus.events = {} -- Clear previous events
      manager:unregister("test")

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "asset:unregistered" then
          found = true
          assert.equals("test", e.data.assetId)
        end
      end
      assert.is_true(found, "Should have emitted asset:unregistered event")
    end)

    it("emits asset:loading event on load", function()
      local manager = AssetManager.new({}, {
        event_bus = mock_event_bus,
        asset_cache = mock_cache,
        asset_loader = mock_loader
      })
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })
      mock_event_bus.events = {} -- Clear previous events
      manager:load("test")

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "asset:loading" then
          found = true
          assert.equals("test", e.data.assetId)
        end
      end
      assert.is_true(found, "Should have emitted asset:loading event")
    end)

    it("emits asset:loaded event on successful load", function()
      local manager = AssetManager.new({}, {
        event_bus = mock_event_bus,
        asset_cache = mock_cache,
        asset_loader = mock_loader
      })
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })
      mock_event_bus.events = {} -- Clear previous events
      manager:load("test")

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "asset:loaded" then
          found = true
          assert.equals("test", e.data.assetId)
        end
      end
      assert.is_true(found, "Should have emitted asset:loaded event")
    end)

    it("does not emit events when event_bus is nil", function()
      local manager = AssetManager.new({}, {
        asset_cache = mock_cache,
        asset_loader = mock_loader
      })
      -- Should not error
      manager:register({
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })
      manager:load("test")
      manager:unregister("test")
    end)
  end)
end)
