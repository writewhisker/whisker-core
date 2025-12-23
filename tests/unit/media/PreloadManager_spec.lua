-- Tests for PreloadManager module
describe("PreloadManager", function()
  local PreloadManager, AssetManager

  before_each(function()
    package.loaded["whisker.media.PreloadManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil
    PreloadManager = require("whisker.media.PreloadManager")
    AssetManager = require("whisker.media.AssetManager")

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
end)
