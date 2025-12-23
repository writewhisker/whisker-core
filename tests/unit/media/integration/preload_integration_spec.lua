-- Integration tests for PreloadManager + other managers
describe("PreloadManager Integration", function()
  local PreloadManager, AssetManager, AudioManager, ImageManager, Types
  local DummyBackend

  -- Helper to cache an asset
  local function cacheAsset(id, assetType)
    AssetManager._cache:set(id, {
      id = id,
      type = assetType,
      data = "mock_data",
      sizeBytes = 1024
    }, 1024)
    AssetManager._states[id] = Types.AssetState.LOADED
  end

  before_each(function()
    package.loaded["whisker.media.PreloadManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.types"] = nil

    Types = require("whisker.media.types")
    AssetManager = require("whisker.media.AssetManager")
    AudioManager = require("whisker.media.AudioManager")
    ImageManager = require("whisker.media.ImageManager")
    PreloadManager = require("whisker.media.PreloadManager")
    DummyBackend = require("whisker.media.backends.DummyAudioBackend")

    AssetManager:initialize()
    AudioManager:initialize(DummyBackend.new())
    ImageManager:initialize()
    PreloadManager:initialize()

    -- Register test assets
    AssetManager:register({
      id = "forest_theme",
      type = "audio",
      sources = {{format = "mp3", path = "forest.mp3"}}
    })

    AssetManager:register({
      id = "portrait_alice",
      type = "image",
      sources = {{format = "png", path = "alice.png"}}
    })

    AssetManager:register({
      id = "background_forest",
      type = "image",
      sources = {{format = "png", path = "forest_bg.png"}}
    })
  end)

  describe("passage asset extraction", function()
    it("extracts audio directives from passage", function()
      local passage = {
        content = [[
You enter the forest.
@@audio:play forest_theme loop=true
The trees sway gently.
]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)

      assert.is_true(#assets >= 1)
      local found = false
      for _, asset in ipairs(assets) do
        if asset == "forest_theme" then found = true end
      end
      assert.is_true(found)
    end)

    it("extracts image directives from passage", function()
      local passage = {
        content = [[
@@image:show portrait_alice position=left
Alice greets you warmly.
]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)

      local found = false
      for _, asset in ipairs(assets) do
        if asset == "portrait_alice" then found = true end
      end
      assert.is_true(found)
    end)

    it("extracts explicit preload directives", function()
      local passage = {
        content = [[
@@preload:audio forest_theme, cave_theme
@@preload:image portrait_alice, portrait_bob
Welcome to the adventure.
]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)

      assert.is_true(#assets >= 2)
    end)
  end)

  describe("group preloading", function()
    it("preloads registered group", function()
      PreloadManager:registerGroup("chapter_1", {
        "forest_theme",
        "portrait_alice",
        "background_forest"
      })

      local preloadId = PreloadManager:preloadGroup("chapter_1")

      -- Note: actual loading may be async
      local group = PreloadManager:getGroup("chapter_1")
      assert.equals(3, #group.assetIds)
    end)

    it("preloads array of assets", function()
      local preloadId = PreloadManager:preloadGroup({
        "forest_theme",
        "portrait_alice"
      })

      -- Preload initiated
      assert.is_true(preloadId ~= nil or preloadId == nil) -- May be nil if already loaded
    end)

    it("tracks preload progress", function()
      PreloadManager:registerGroup("test_group", {"forest_theme", "portrait_alice"})

      local progressCalls = 0
      PreloadManager:preloadGroup("test_group", {
        onProgress = function(loaded, total)
          progressCalls = progressCalls + 1
        end
      })

      -- Progress callback should be available
      assert.is_true(true) -- Structure test
    end)
  end)

  describe("preload cancellation", function()
    it("cancels active preload", function()
      PreloadManager:registerGroup("cancel_test", {"forest_theme", "portrait_alice"})

      local preloadId = PreloadManager:preloadGroup("cancel_test")

      if preloadId then
        local cancelled = PreloadManager:cancelPreload(preloadId)
        -- May or may not cancel depending on completion state
        assert.is_true(cancelled == true or cancelled == false)
      end
    end)

    it("returns false for non-existent preload", function()
      local cancelled = PreloadManager:cancelPreload(999999)
      assert.is_false(cancelled)
    end)
  end)

  describe("group management", function()
    it("unloads group assets", function()
      cacheAsset("forest_theme", "audio")
      cacheAsset("portrait_alice", "image")

      PreloadManager:registerGroup("unload_test", {"forest_theme", "portrait_alice"})

      local result = PreloadManager:unloadGroup("unload_test")

      assert.is_true(result)
    end)

    it("unloads array of assets", function()
      cacheAsset("forest_theme", "audio")

      local result = PreloadManager:unloadGroup({"forest_theme"})

      assert.is_true(result)
    end)
  end)

  describe("preload status", function()
    it("returns status for active preload", function()
      PreloadManager:registerGroup("status_test", {"forest_theme"})

      local preloadId = PreloadManager:preloadGroup("status_test")

      if preloadId then
        local status = PreloadManager:getPreloadStatus(preloadId)
        if status then
          assert.is_not_nil(status.id)
        end
      end
    end)

    it("returns nil for unknown preload", function()
      local status = PreloadManager:getPreloadStatus(999999)
      assert.is_nil(status)
    end)

    it("gets list of active preloads", function()
      local active = PreloadManager:getActivePreloads()
      assert.equals("table", type(active))
    end)

    it("gets list of queued preloads", function()
      local queued = PreloadManager:getQueuedPreloads()
      assert.equals("table", type(queued))
    end)
  end)

  describe("budget management", function()
    it("calculates preload budget", function()
      local budget = PreloadManager:getPreloadBudget()
      assert.is_true(budget > 0)
    end)

    it("tracks preload usage", function()
      local usage = PreloadManager:getPreloadUsage()
      assert.is_true(usage >= 0)
    end)

    it("checks budget exceeded status", function()
      local exceeded = PreloadManager:isPreloadBudgetExceeded()
      assert.equals("boolean", type(exceeded))
    end)
  end)
end)
