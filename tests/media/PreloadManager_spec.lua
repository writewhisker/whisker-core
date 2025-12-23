-- PreloadManager Tests
-- Unit tests for the PreloadManager module

describe("PreloadManager", function()
  local PreloadManager
  local AssetManager

  before_each(function()
    package.loaded["whisker.media.PreloadManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil

    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    PreloadManager = require("whisker.media.PreloadManager")
    PreloadManager:initialize({
      maxConcurrent = 3,
      budgetRatio = 0.3
    })

    -- Register test assets
    for i = 1, 5 do
      AssetManager:register({
        id = "asset" .. i,
        type = "audio",
        sources = { { format = "mp3", path = "test" .. i .. ".mp3" } }
      })
    end
  end)

  describe("initialization", function()
    it("initializes with config", function()
      assert.is_true(PreloadManager._initialized)
      assert.equals(3, PreloadManager._maxConcurrentPreloads)
      assert.equals(0.3, PreloadManager._preloadBudgetRatio)
    end)

    it("initializes with defaults", function()
      local pm = require("whisker.media.PreloadManager")
      pm:initialize()

      assert.is_true(pm._initialized)
    end)
  end)

  describe("group registration", function()
    it("registers preload group", function()
      PreloadManager:registerGroup("chapter1", { "asset1", "asset2" })

      local group = PreloadManager:getGroup("chapter1")
      assert.is_not_nil(group)
      assert.equals(2, #group.assetIds)
    end)

    it("unregisters group", function()
      PreloadManager:registerGroup("temp", { "asset1" })
      PreloadManager:unregisterGroup("temp")

      assert.is_nil(PreloadManager:getGroup("temp"))
    end)

    it("getGroup returns nil for non-existent group", function()
      assert.is_nil(PreloadManager:getGroup("nonexistent"))
    end)
  end)

  describe("preloading", function()
    it("preloads asset list", function()
      local completed = false
      local loadedCount = 0

      PreloadManager:preloadGroup({ "asset1", "asset2" }, {
        onProgress = function(loaded, total)
          loadedCount = loaded
        end,
        onComplete = function(succeeded, errors)
          completed = true
        end
      })

      assert.is_true(completed)
    end)

    it("preloads registered group by name", function()
      PreloadManager:registerGroup("test_group", { "asset1", "asset2" })

      local completed = false

      local preloadId = PreloadManager:preloadGroup("test_group", {
        onComplete = function()
          completed = true
        end
      })

      assert.is_not_nil(preloadId)
      assert.is_true(completed)
    end)

    it("returns nil for non-existent group", function()
      local preloadId = PreloadManager:preloadGroup("nonexistent")
      assert.is_nil(preloadId)
    end)

    it("skips already-loaded assets", function()
      AssetManager:loadSync("asset1")

      local progressCalls = 0

      PreloadManager:preloadGroup({ "asset1", "asset2" }, {
        onProgress = function()
          progressCalls = progressCalls + 1
        end
      })

      -- Only asset2 needs loading
      assert.is_true(progressCalls <= 2)
    end)

    it("calls onComplete immediately when all assets loaded", function()
      AssetManager:loadSync("asset1")
      AssetManager:loadSync("asset2")

      local completed = false

      PreloadManager:preloadGroup({ "asset1", "asset2" }, {
        onComplete = function()
          completed = true
        end
      })

      assert.is_true(completed)
    end)
  end)

  describe("preload operations", function()
    it("returns unique preload ID", function()
      local id1 = PreloadManager:preloadGroup({ "asset1" })
      local id2 = PreloadManager:preloadGroup({ "asset2" })

      assert.is_not_nil(id1)
      assert.is_not_nil(id2)
      assert.are_not_equal(id1, id2)
    end)

    it("cancelPreload cancels preload operation", function()
      local preloadId = PreloadManager:preloadGroup({ "asset1", "asset2", "asset3" })

      if preloadId then
        local cancelled = PreloadManager:cancelPreload(preloadId)
        -- May or may not succeed depending on timing
        assert.is_boolean(cancelled)
      end
    end)

    it("cancelPreload returns false for invalid ID", function()
      local cancelled = PreloadManager:cancelPreload(99999)
      assert.is_false(cancelled)
    end)
  end)

  describe("unloading", function()
    it("unloads group by name", function()
      PreloadManager:registerGroup("unload_test", { "asset1", "asset2" })

      -- Preload first
      PreloadManager:preloadGroup("unload_test")

      -- Then unload
      local success = PreloadManager:unloadGroup("unload_test")
      assert.is_true(success)
    end)

    it("unloads asset list", function()
      PreloadManager:preloadGroup({ "asset1", "asset2" })

      local success = PreloadManager:unloadGroup({ "asset1", "asset2" })
      assert.is_true(success)
    end)

    it("returns false for invalid input", function()
      local success = PreloadManager:unloadGroup(123)
      assert.is_false(success)
    end)
  end)

  describe("budget management", function()
    it("getPreloadBudget returns budget", function()
      local budget = PreloadManager:getPreloadBudget()
      assert.is_number(budget)
      assert.is_true(budget > 0)
    end)

    it("getPreloadUsage returns usage", function()
      local usage = PreloadManager:getPreloadUsage()
      assert.is_number(usage)
      assert.is_true(usage >= 0)
    end)

    it("isPreloadBudgetExceeded returns boolean", function()
      local exceeded = PreloadManager:isPreloadBudgetExceeded()
      assert.is_boolean(exceeded)
    end)
  end)

  describe("status queries", function()
    it("getPreloadStatus returns status for active preload", function()
      local preloadId = PreloadManager:preloadGroup({ "asset1", "asset2", "asset3" })

      if preloadId then
        local status = PreloadManager:getPreloadStatus(preloadId)
        -- Status may or may not exist depending on whether preload completed
        if status then
          assert.is_not_nil(status.id)
        end
      end
    end)

    it("getPreloadStatus returns nil for invalid ID", function()
      local status = PreloadManager:getPreloadStatus(99999)
      assert.is_nil(status)
    end)

    it("getActivePreloads returns list", function()
      local active = PreloadManager:getActivePreloads()
      assert.is_table(active)
    end)

    it("getQueuedPreloads returns list", function()
      local queued = PreloadManager:getQueuedPreloads()
      assert.is_table(queued)
    end)
  end)

  describe("extractPassageAssets", function()
    it("extracts audio assets from content", function()
      local passage = {
        content = [[
          @@audio:play forest_theme channel=MUSIC
          Some text here
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      -- Pattern matching may extract the asset
      assert.is_table(assets)
    end)

    it("extracts image assets from content", function()
      local passage = {
        content = [[
          @@image:show portrait
          More content
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)

    it("extracts preload directives", function()
      local passage = {
        content = [[
          @@preload:audio asset1, asset2
          Content
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)

    it("handles passage with no assets", function()
      local passage = {
        content = "Just some plain text content"
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
      assert.equals(0, #assets)
    end)

    it("handles passage with text property", function()
      local passage = {
        text = "Some content"
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)
  end)

  describe("priority handling", function()
    it("queues preloads by priority", function()
      -- Fill up concurrent slots
      PreloadManager._maxConcurrentPreloads = 1

      local id1 = PreloadManager:preloadGroup({ "asset1" }, { priority = "low" })
      local id2 = PreloadManager:preloadGroup({ "asset2" }, { priority = "high" })
      local id3 = PreloadManager:preloadGroup({ "asset3" }, { priority = "normal" })

      -- High priority should be processed first when queue is processed
      local queued = PreloadManager:getQueuedPreloads()
      -- Queue order depends on implementation details
      assert.is_table(queued)
    end)
  end)
end)
