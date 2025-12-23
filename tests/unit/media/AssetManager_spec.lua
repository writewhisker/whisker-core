-- Tests for AssetManager module
describe("AssetManager", function()
  local AssetManager

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.AssetLoader"] = nil
    package.loaded["whisker.media.types"] = nil
    package.loaded["whisker.media.schemas"] = nil
    package.loaded["whisker.media.FormatDetector"] = nil
    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()
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
end)
