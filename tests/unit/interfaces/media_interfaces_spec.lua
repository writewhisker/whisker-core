--- Media Interfaces Unit Tests
-- Tests for the media interface definitions
-- @module tests.unit.interfaces.media_interfaces_spec

describe("Media Interfaces", function()
  local Interfaces
  local Media

  before_each(function()
    package.loaded["whisker.interfaces"] = nil
    package.loaded["whisker.interfaces.media"] = nil
    Interfaces = require("whisker.interfaces")
    Media = require("whisker.interfaces.media")
  end)

  describe("IAssetCache", function()
    it("should be defined", function()
      assert.is_table(Media.IAssetCache)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IAssetCache)
    end)

    it("should define required methods", function()
      local cache = Media.IAssetCache
      assert.is_function(cache.get)
      assert.is_function(cache.put)
      assert.is_function(cache.remove)
      assert.is_function(cache.has)
      assert.is_function(cache.clear)
      assert.is_function(cache.getStats)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IAssetCache:get("test")
      end, "IAssetCache:get must be implemented")

      assert.has_error(function()
        Media.IAssetCache:put("id", {})
      end, "IAssetCache:put must be implemented")
    end)
  end)

  describe("IAssetLoader", function()
    it("should be defined", function()
      assert.is_table(Media.IAssetLoader)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IAssetLoader)
    end)

    it("should define required methods", function()
      local loader = Media.IAssetLoader
      assert.is_function(loader.load)
      assert.is_function(loader.loadAsync)
      assert.is_function(loader.exists)
      assert.is_function(loader.detectType)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IAssetLoader:load("/path")
      end, "IAssetLoader:load must be implemented")
    end)
  end)

  describe("IAssetManager", function()
    it("should be defined", function()
      assert.is_table(Media.IAssetManager)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IAssetManager)
    end)

    it("should define required methods", function()
      local manager = Media.IAssetManager
      assert.is_function(manager.register)
      assert.is_function(manager.unregister)
      assert.is_function(manager.get)
      assert.is_function(manager.load)
      assert.is_function(manager.unload)
      assert.is_function(manager.isRegistered)
      assert.is_function(manager.isLoaded)
      assert.is_function(manager.getState)
      assert.is_function(manager.getAllIds)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IAssetManager:register("id", {})
      end, "IAssetManager:register must be implemented")
    end)
  end)

  describe("IAudioManager", function()
    it("should be defined", function()
      assert.is_table(Media.IAudioManager)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IAudioManager)
    end)

    it("should define required methods", function()
      local audio = Media.IAudioManager
      assert.is_function(audio.play)
      assert.is_function(audio.stop)
      assert.is_function(audio.pause)
      assert.is_function(audio.resume)
      assert.is_function(audio.setVolume)
      assert.is_function(audio.getVolume)
      assert.is_function(audio.setMasterVolume)
      assert.is_function(audio.getMasterVolume)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IAudioManager:play("id")
      end, "IAudioManager:play must be implemented")
    end)
  end)

  describe("IImageManager", function()
    it("should be defined", function()
      assert.is_table(Media.IImageManager)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IImageManager)
    end)

    it("should define required methods", function()
      local image = Media.IImageManager
      assert.is_function(image.get)
      assert.is_function(image.load)
      assert.is_function(image.unload)
      assert.is_function(image.getDimensions)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IImageManager:get("id")
      end, "IImageManager:get must be implemented")
    end)
  end)

  describe("IPreloadManager", function()
    it("should be defined", function()
      assert.is_table(Media.IPreloadManager)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IPreloadManager)
    end)

    it("should define required methods", function()
      local preload = Media.IPreloadManager
      assert.is_function(preload.preload)
      assert.is_function(preload.cancel)
      assert.is_function(preload.getProgress)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IPreloadManager:preload({})
      end, "IPreloadManager:preload must be implemented")
    end)
  end)

  describe("IBundler", function()
    it("should be defined", function()
      assert.is_table(Media.IBundler)
    end)

    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.IBundler)
    end)

    it("should define required methods", function()
      local bundler = Media.IBundler
      assert.is_function(bundler.bundle)
      assert.is_function(bundler.extract)
      assert.is_function(bundler.getInfo)
    end)

    it("should error when interface methods are called directly", function()
      assert.has_error(function()
        Media.IBundler:bundle({}, {})
      end, "IBundler:bundle must be implemented")
    end)
  end)

  describe("Media namespace", function()
    it("should be exported from main interfaces", function()
      assert.is_table(Interfaces.Media)
    end)

    it("should contain all media interfaces", function()
      assert.is_table(Interfaces.Media.IAssetCache)
      assert.is_table(Interfaces.Media.IAssetLoader)
      assert.is_table(Interfaces.Media.IAssetManager)
      assert.is_table(Interfaces.Media.IAudioManager)
      assert.is_table(Interfaces.Media.IImageManager)
      assert.is_table(Interfaces.Media.IPreloadManager)
      assert.is_table(Interfaces.Media.IBundler)
    end)
  end)
end)
