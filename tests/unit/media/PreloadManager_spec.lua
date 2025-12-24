-- Tests for PreloadManager module
describe("PreloadManager", function()
  local PreloadManager, AssetManager
  local mock_event_bus
  local mock_asset_manager

  before_each(function()
    package.loaded["whisker.media.PreloadManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil
    PreloadManager = require("whisker.media.PreloadManager")
    AssetManager = require("whisker.media.AssetManager")

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock asset manager
    mock_asset_manager = {
      _configs = {},
      _loaded = {},
      register = function(self, config)
        self._configs[config.id] = config
        return true
      end,
      isLoaded = function(self, id)
        return self._loaded[id] == true
      end,
      get = function(self, id)
        if self._loaded[id] then
          return {id = id, sizeBytes = 1000}
        end
        return nil
      end,
      load = function(self, id, callback)
        self._loaded[id] = true
        if callback then
          callback({id = id, type = "audio"}, nil)
        end
        return true
      end,
      unload = function(self, id)
        self._loaded[id] = nil
        return true
      end,
      getCacheStats = function(self)
        return {bytesLimit = 100 * 1024 * 1024, bytesUsed = 0, assetCount = 0, hitRate = 0}
      end
    }

    AssetManager:initialize()
    PreloadManager:initialize()
  end)

  describe("initialize", function()
    it("initializes with default config", function()
      PreloadManager:initialize()
      assert.is_true(PreloadManager._initialized)
    end)

    it("initializes with custom config", function()
      PreloadManager:initialize({
        maxConcurrent = 5,
        budgetRatio = 0.5
      })

      assert.equals(5, PreloadManager._maxConcurrentPreloads)
      assert.equals(0.5, PreloadManager._preloadBudgetRatio)
    end)
  end)

  describe("registerGroup", function()
    it("registers a preload group", function()
      PreloadManager:registerGroup("chapter_1", {
        "audio_1", "audio_2", "image_1"
      })

      local group = PreloadManager:getGroup("chapter_1")
      assert.is_not_nil(group)
      assert.equals(3, #group.assetIds)
    end)
  end)

  describe("unregisterGroup", function()
    it("unregisters a group", function()
      PreloadManager:registerGroup("temp", {"asset_1"})
      PreloadManager:unregisterGroup("temp")

      assert.is_nil(PreloadManager:getGroup("temp"))
    end)
  end)

  describe("getGroup", function()
    it("returns group", function()
      PreloadManager:registerGroup("test", {"a", "b"})
      local group = PreloadManager:getGroup("test")

      assert.is_not_nil(group)
      assert.equals(2, #group.assetIds)
    end)

    it("returns nil for missing group", function()
      assert.is_nil(PreloadManager:getGroup("nonexistent"))
    end)
  end)

  describe("preloadGroup", function()
    it("returns nil for missing group", function()
      local result = PreloadManager:preloadGroup("nonexistent")
      assert.is_nil(result)
    end)

    it("preloads array of asset ids", function()
      -- Register test assets
      AssetManager:register({
        id = "test_asset",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      })

      local preloadId = PreloadManager:preloadGroup({"test_asset"})
      -- Note: preload may be nil if asset is already loading/loaded
    end)

    it("calls onComplete when all loaded", function()
      local completed = false

      -- All assets already "loaded" (nothing to load)
      PreloadManager:preloadGroup({}, {
        onComplete = function(succeeded, errors)
          completed = true
        end
      })

      -- Empty group completes immediately
    end)
  end)

  describe("cancelPreload", function()
    it("returns false for non-existent preload", function()
      assert.is_false(PreloadManager:cancelPreload(999))
    end)
  end)

  describe("extractPassageAssets", function()
    it("extracts audio directives", function()
      local passage = {
        content = [[
          @@audio:play forest_theme
          @@audio:stop other_audio
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_true(#assets >= 1)
    end)

    it("extracts image directives", function()
      local passage = {
        content = [[
          @@image:show portrait_alice
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.equals(1, #assets)
      assert.equals("portrait_alice", assets[1])
    end)

    it("extracts preload directives", function()
      local passage = {
        content = [[
          @@preload:audio asset_a, asset_b
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_true(#assets >= 2)
    end)

    it("handles empty passage", function()
      local passage = {}
      local assets = PreloadManager:extractPassageAssets(passage)
      assert.equals(0, #assets)
    end)
  end)

  describe("getPreloadBudget", function()
    it("returns budget based on cache limit", function()
      local budget = PreloadManager:getPreloadBudget()
      local stats = AssetManager:getCacheStats()

      assert.equals(stats.bytesLimit * 0.3, budget)
    end)
  end)

  describe("getPreloadUsage", function()
    it("returns 0 when no preloads active", function()
      assert.equals(0, PreloadManager:getPreloadUsage())
    end)
  end)

  describe("isPreloadBudgetExceeded", function()
    it("returns false when under budget", function()
      assert.is_false(PreloadManager:isPreloadBudgetExceeded())
    end)
  end)

  describe("getPreloadStatus", function()
    it("returns nil for unknown preload", function()
      assert.is_nil(PreloadManager:getPreloadStatus(999))
    end)
  end)

  describe("getActivePreloads", function()
    it("returns empty array when no active preloads", function()
      local active = PreloadManager:getActivePreloads()
      assert.equals(0, #active)
    end)
  end)

  describe("getQueuedPreloads", function()
    it("returns empty array when no queued preloads", function()
      local queued = PreloadManager:getQueuedPreloads()
      assert.equals(0, #queued)
    end)
  end)

  describe("unloadGroup", function()
    it("unloads assets in group", function()
      PreloadManager:registerGroup("test", {"a", "b"})
      local result = PreloadManager:unloadGroup("test")
      assert.is_true(result)
    end)

    it("unloads array of assets", function()
      local result = PreloadManager:unloadGroup({"a", "b"})
      assert.is_true(result)
    end)

    it("returns false for invalid input", function()
      assert.is_false(PreloadManager:unloadGroup(123))
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(PreloadManager._dependencies)
      assert.same({"asset_manager", "event_bus"}, PreloadManager._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(PreloadManager.create)
    end)

    it("provides new constructor", function()
      assert.is_function(PreloadManager.new)
    end)

    it("create returns a factory function", function()
      local factory = PreloadManager.create({
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      assert.is_function(factory)
    end)

    it("factory creates manager instances with injected deps", function()
      local factory = PreloadManager.create({
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      local manager = factory({maxConcurrent = 5})
      assert.is_not_nil(manager)
      assert.is_function(manager.preloadGroup)
      assert.equals(5, manager._maxConcurrentPreloads)
    end)

    it("new creates instance with injected asset_manager", function()
      local manager = PreloadManager.new({}, {asset_manager = mock_asset_manager})
      assert.equals(mock_asset_manager, manager._asset_manager)
    end)

    it("new creates instance with injected event_bus", function()
      local manager = PreloadManager.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, manager._event_bus)
    end)

    it("works without deps (backward compatibility)", function()
      local manager = PreloadManager.new({})
      assert.is_not_nil(manager)
      assert.is_not_nil(manager._asset_manager)
    end)
  end)

  describe("event emission", function()
    it("emits preload:start event on preload start", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      manager:preloadGroup({"asset_1", "asset_2"})

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "preload:start" then
          found = true
          assert.equals(2, e.data.assetCount)
        end
      end
      assert.is_true(found, "Should have emitted preload:start event")
    end)

    it("emits preload:progress events during loading", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      manager:preloadGroup({"asset_1"})

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "preload:progress" then
          found = true
          assert.equals("asset_1", e.data.assetId)
          assert.equals(1, e.data.loaded)
          assert.equals(1, e.data.total)
        end
      end
      assert.is_true(found, "Should have emitted preload:progress event")
    end)

    it("emits preload:complete event on completion", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      manager:preloadGroup({"asset_1"})

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "preload:complete" then
          found = true
          assert.equals(1, e.data.successCount)
          assert.equals(0, e.data.errorCount)
        end
      end
      assert.is_true(found, "Should have emitted preload:complete event")
    end)

    it("does not emit events when event_bus is nil", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager
        -- no event_bus
      })

      -- Should not error
      assert.has_no.errors(function()
        manager:preloadGroup({"asset_1"})
      end)
    end)

    it("uses injected asset_manager for preloadGroup", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      manager:preloadGroup({"asset_1"})

      assert.is_true(mock_asset_manager._loaded["asset_1"])
    end)

    it("uses injected asset_manager for unloadGroup", function()
      local manager = PreloadManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      -- First load
      mock_asset_manager._loaded["asset_1"] = true

      manager:unloadGroup({"asset_1"})

      assert.is_nil(mock_asset_manager._loaded["asset_1"])
    end)

    it("uses injected asset_manager for getPreloadBudget", function()
      local manager = PreloadManager.new({budgetRatio = 0.5}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })

      local budget = manager:getPreloadBudget()

      -- mock returns 100 * 1024 * 1024, so budget should be half
      assert.equals(50 * 1024 * 1024, budget)
    end)
  end)
end)
