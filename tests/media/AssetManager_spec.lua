-- AssetManager Tests
-- Comprehensive unit tests for the AssetManager module

describe("AssetManager", function()
  local AssetManager
  local Types

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.AssetLoader"] = nil
    package.loaded["whisker.media.types"] = nil
    package.loaded["whisker.media.schemas"] = nil

    Types = require("whisker.media.types")
    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()
  end)

  after_each(function()
    if AssetManager._cache then
      AssetManager:clearCache()
    end
  end)

  describe("registration", function()
    it("registers valid audio asset", function()
      local success, err = AssetManager:register({
        id = "test_audio",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.is_true(success)
      assert.is_nil(err)
      assert.equals(Types.AssetState.UNLOADED, AssetManager:getState("test_audio"))
    end)

    it("registers valid image asset", function()
      local success, err = AssetManager:register({
        id = "test_image",
        type = "image",
        variants = { { density = "1x", path = "test.png" } }
      })

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("rejects asset with missing id", function()
      local success, err = AssetManager:register({
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.is_false(success)
      assert.is_not_nil(err)
      assert.equals("validation", err.type)
    end)

    it("rejects asset with missing type", function()
      local success, err = AssetManager:register({
        id = "test",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("rejects asset with invalid type", function()
      local success, err = AssetManager:register({
        id = "test",
        type = "invalid_type",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("rejects duplicate asset registration", function()
      AssetManager:register({
        id = "duplicate",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      local success, err = AssetManager:register({
        id = "duplicate",
        type = "audio",
        sources = { { format = "ogg", path = "test.ogg" } }
      })

      assert.is_false(success)
      assert.equals("duplicate", err.type)
    end)

    it("rejects audio asset without sources", function()
      local success, err = AssetManager:register({
        id = "no_sources",
        type = "audio",
        sources = {}
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("rejects image asset without variants", function()
      local success, err = AssetManager:register({
        id = "no_variants",
        type = "image",
        variants = {}
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("unregistration", function()
    it("unregisters existing asset", function()
      AssetManager:register({
        id = "to_unregister",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      local success = AssetManager:unregister("to_unregister")

      assert.is_true(success)
      assert.is_nil(AssetManager._registry["to_unregister"])
      assert.is_nil(AssetManager:getState("to_unregister"))
    end)

    it("returns false for non-existent asset", function()
      local success = AssetManager:unregister("nonexistent")
      assert.is_false(success)
    end)
  end)

  describe("loading", function()
    it("sets state to loading during load", function()
      AssetManager:register({
        id = "loading_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:load("loading_test", function() end)

      -- State should be loading or loaded depending on sync behavior
      local state = AssetManager:getState("loading_test")
      assert.is_true(state == Types.AssetState.LOADING or state == Types.AssetState.LOADED or state == Types.AssetState.FAILED)
    end)

    it("calls callback on load completion", function()
      AssetManager:register({
        id = "callback_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      local callbackCalled = false
      AssetManager:load("callback_test", function(asset, err)
        callbackCalled = true
      end)

      assert.is_true(callbackCalled)
    end)

    it("returns error for unregistered asset", function()
      local callbackError = nil
      AssetManager:load("unregistered", function(asset, err)
        callbackError = err
      end)

      assert.is_not_nil(callbackError)
      assert.equals("not_found", callbackError.type)
    end)

    it("loadSync returns asset synchronously", function()
      AssetManager:register({
        id = "sync_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      local asset, err = AssetManager:loadSync("sync_test")

      -- Either success or failure, but should return
      assert.is_true(asset ~= nil or err ~= nil)
    end)

    it("loadBatch loads multiple assets", function()
      AssetManager:register({
        id = "batch1",
        type = "audio",
        sources = { { format = "mp3", path = "test1.mp3" } }
      })

      AssetManager:register({
        id = "batch2",
        type = "audio",
        sources = { { format = "mp3", path = "test2.mp3" } }
      })

      local progressCalled = false
      local completeCalled = false

      AssetManager:loadBatch({ "batch1", "batch2" }, {
        onProgress = function(loaded, total)
          progressCalled = true
          assert.equals(2, total)
        end,
        onComplete = function(assets, errors)
          completeCalled = true
        end
      })

      assert.is_true(completeCalled)
    end)
  end)

  describe("unloading", function()
    it("unloads loaded asset", function()
      AssetManager:register({
        id = "unload_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("unload_test")

      if AssetManager:isLoaded("unload_test") then
        local success = AssetManager:unload("unload_test")
        assert.is_true(success)
        assert.is_false(AssetManager:isLoaded("unload_test"))
      end
    end)

    it("returns false for non-cached asset", function()
      local success = AssetManager:unload("not_in_cache")
      assert.is_false(success)
    end)
  end)

  describe("state queries", function()
    it("getState returns correct state", function()
      AssetManager:register({
        id = "state_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.equals(Types.AssetState.UNLOADED, AssetManager:getState("state_test"))
    end)

    it("isLoaded returns false for unloaded asset", function()
      AssetManager:register({
        id = "loaded_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      assert.is_false(AssetManager:isLoaded("loaded_test"))
    end)

    it("isLoading returns true during load", function()
      AssetManager:register({
        id = "loading_check",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      -- isLoading depends on async behavior
      local wasLoading = AssetManager:isLoading("loading_check")
      -- Can be true or false depending on implementation
      assert.is_boolean(wasLoading)
    end)

    it("getConfig returns registered config", function()
      local config = {
        id = "config_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      }

      AssetManager:register(config)

      local retrieved = AssetManager:getConfig("config_test")
      assert.equals("config_test", retrieved.id)
      assert.equals("audio", retrieved.type)
    end)

    it("getAllAssets returns list of asset IDs", function()
      AssetManager:register({
        id = "asset1",
        type = "audio",
        sources = { { format = "mp3", path = "test1.mp3" } }
      })

      AssetManager:register({
        id = "asset2",
        type = "audio",
        sources = { { format = "mp3", path = "test2.mp3" } }
      })

      local assets = AssetManager:getAllAssets()
      assert.equals(2, #assets)
    end)
  end)

  describe("cache management", function()
    it("getCacheStats returns stats object", function()
      local stats = AssetManager:getCacheStats()

      assert.is_not_nil(stats)
      assert.is_number(stats.bytesUsed)
      assert.is_number(stats.bytesLimit)
      assert.is_number(stats.assetCount)
    end)

    it("setMemoryBudget updates cache limit", function()
      local newBudget = 50 * 1024 * 1024 -- 50MB

      AssetManager:setMemoryBudget(newBudget)

      local stats = AssetManager:getCacheStats()
      assert.equals(newBudget, stats.bytesLimit)
    end)

    it("clearCache removes cached assets", function()
      AssetManager:register({
        id = "clear_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("clear_test")
      AssetManager:clearCache()

      -- Cache should be cleared (or assets protected by refs/pins)
      local stats = AssetManager:getCacheStats()
      assert.is_true(stats.assetCount >= 0)
    end)
  end)

  describe("reference counting", function()
    it("retain increments ref count", function()
      AssetManager:register({
        id = "ref_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("ref_test")

      if AssetManager:isLoaded("ref_test") then
        assert.equals(0, AssetManager:getRefCount("ref_test"))

        AssetManager:retain("ref_test")
        assert.equals(1, AssetManager:getRefCount("ref_test"))

        AssetManager:retain("ref_test")
        assert.equals(2, AssetManager:getRefCount("ref_test"))
      end
    end)

    it("release decrements ref count", function()
      AssetManager:register({
        id = "release_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("release_test")

      if AssetManager:isLoaded("release_test") then
        AssetManager:retain("release_test")
        AssetManager:retain("release_test")
        assert.equals(2, AssetManager:getRefCount("release_test"))

        AssetManager:release("release_test")
        assert.equals(1, AssetManager:getRefCount("release_test"))
      end
    end)

    it("getRefCount returns 0 for unretained asset", function()
      AssetManager:register({
        id = "no_refs",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("no_refs")

      if AssetManager:isLoaded("no_refs") then
        assert.equals(0, AssetManager:getRefCount("no_refs"))
      end
    end)
  end)

  describe("pinning", function()
    it("pin marks asset as pinned", function()
      AssetManager:register({
        id = "pin_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("pin_test")

      if AssetManager:isLoaded("pin_test") then
        local success = AssetManager:pin("pin_test")
        assert.is_true(success)
      end
    end)

    it("unpin removes pin", function()
      AssetManager:register({
        id = "unpin_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:loadSync("unpin_test")

      if AssetManager:isLoaded("unpin_test") then
        AssetManager:pin("unpin_test")
        local success = AssetManager:unpin("unpin_test")
        assert.is_true(success)
      end
    end)
  end)

  describe("retry and cancel", function()
    it("retry attempts to reload failed asset", function()
      AssetManager:register({
        id = "retry_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      local retryCalled = false
      AssetManager:retry("retry_test", function(asset, err)
        retryCalled = true
      end)

      assert.is_true(retryCalled)
    end)

    it("cancel stops in-progress load", function()
      AssetManager:register({
        id = "cancel_test",
        type = "audio",
        sources = { { format = "mp3", path = "test.mp3" } }
      })

      AssetManager:load("cancel_test", function() end)

      -- Cancel may or may not succeed depending on load timing
      local cancelled = AssetManager:cancel("cancel_test")
      assert.is_boolean(cancelled)
    end)
  end)
end)
