-- Integration tests for asset bundling
describe("Asset Bundling Integration", function()
  local WebBundler, DesktopBundler, MobileBundler, BundlingStrategy

  before_each(function()
    package.loaded["whisker.media.bundlers.BundlingStrategy"] = nil
    package.loaded["whisker.media.bundlers.WebBundler"] = nil
    package.loaded["whisker.media.bundlers.DesktopBundler"] = nil
    package.loaded["whisker.media.bundlers.MobileBundler"] = nil

    BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")
    WebBundler = require("whisker.media.bundlers.WebBundler")
    DesktopBundler = require("whisker.media.bundlers.DesktopBundler")
    MobileBundler = require("whisker.media.bundlers.MobileBundler")
  end)

  describe("BundlingStrategy base", function()
    it("creates new strategy instance", function()
      local strategy = BundlingStrategy.new()
      assert.is_not_nil(strategy)
    end)

    it("checks format support", function()
      local strategy = BundlingStrategy.new()
      local supported = {"mp3", "ogg", "wav"}

      assert.is_true(strategy:isFormatSupported("mp3", supported))
      assert.is_false(strategy:isFormatSupported("flac", supported))
    end)

    it("selects sources by format", function()
      local strategy = BundlingStrategy.new()

      local assetConfig = {
        id = "test",
        type = "audio",
        sources = {
          {format = "mp3", path = "test.mp3"},
          {format = "ogg", path = "test.ogg"},
          {format = "flac", path = "test.flac"}
        }
      }

      local selected = strategy:selectSources(assetConfig, {"mp3", "ogg"})
      assert.equals(2, #selected)
    end)
  end)

  describe("WebBundler", function()
    it("creates new bundler instance", function()
      local bundler = WebBundler.new()
      assert.is_not_nil(bundler)
    end)

    it("inherits from BundlingStrategy", function()
      local bundler = WebBundler.new()
      -- Check inherited methods exist
      assert.is_not_nil(bundler.selectSources)
      assert.is_not_nil(bundler.isFormatSupported)
    end)

    it("generates manifest", function()
      local bundler = WebBundler.new()
      local manifest = bundler:generateManifest({
        {id = "test", type = "audio", path = "test.mp3"}
      })

      assert.is_not_nil(manifest)
      assert.equals("1.0", manifest.version)
      assert.equals(1, #manifest.assets)
    end)
  end)

  describe("DesktopBundler", function()
    it("creates new bundler instance", function()
      local bundler = DesktopBundler.new()
      assert.is_not_nil(bundler)
    end)

    it("generates manifest with platform info", function()
      local bundler = DesktopBundler.new()
      local manifest = bundler:generateManifest({
        {id = "test", type = "audio", path = "test.ogg"}
      })

      assert.equals("desktop", manifest.platform)
    end)
  end)

  describe("MobileBundler", function()
    it("creates new bundler instance", function()
      local bundler = MobileBundler.new()
      assert.is_not_nil(bundler)
    end)

    it("has iOS-specific formats", function()
      local bundler = MobileBundler.new()
      local formats = bundler:_getPlatformFormats("ios")

      assert.is_not_nil(formats.audio)
      -- iOS typically supports aac, mp3
    end)

    it("has Android-specific formats", function()
      local bundler = MobileBundler.new()
      local formats = bundler:_getPlatformFormats("android")

      assert.is_not_nil(formats.audio)
      assert.is_not_nil(formats.image)
    end)
  end)

  describe("cross-platform bundling", function()
    local testAssets = {
      {
        id = "music_track",
        type = "audio",
        sources = {
          {format = "mp3", path = "music.mp3"},
          {format = "ogg", path = "music.ogg"},
          {format = "aac", path = "music.aac"}
        }
      },
      {
        id = "background_image",
        type = "image",
        sources = {
          {format = "png", path = "bg.png"},
          {format = "jpg", path = "bg.jpg"},
          {format = "webp", path = "bg.webp"}
        }
      }
    }

    it("web bundler selects common web formats", function()
      local bundler = WebBundler.new()
      -- Common web audio formats
      local webAudioFormats = {"mp3", "ogg", "webm"}
      local webImageFormats = {"png", "jpg", "webp", "svg"}

      local audioAsset = testAssets[1]
      local selected = bundler:selectSources(audioAsset, webAudioFormats)
      assert.is_true(#selected >= 1)

      local imageAsset = testAssets[2]
      local imgSelected = bundler:selectSources(imageAsset, webImageFormats)
      assert.is_true(#imgSelected >= 1)
    end)

    it("desktop bundler selects desktop formats", function()
      local bundler = DesktopBundler.new()

      local assetConfig = testAssets[1]
      local selected = bundler:selectSources(assetConfig, {"ogg", "mp3"})

      assert.is_true(#selected >= 1)
    end)

    it("mobile bundler selects platform-specific formats", function()
      local bundler = MobileBundler.new()

      -- iOS
      local iosFormats = bundler:_getPlatformFormats("ios")
      local assetConfig = testAssets[1]
      local iosSelected = bundler:selectSources(assetConfig, iosFormats.audio or {})
      assert.is_true(#iosSelected >= 1)

      -- Android
      local androidFormats = bundler:_getPlatformFormats("android")
      local androidSelected = bundler:selectSources(assetConfig, androidFormats.audio or {})
      assert.is_true(#androidSelected >= 1)
    end)
  end)

  describe("manifest generation", function()
    it("all bundlers generate valid manifests", function()
      local bundlers = {
        WebBundler.new(),
        DesktopBundler.new(),
        MobileBundler.new()
      }

      local testAssets = {
        {id = "a", type = "audio", path = "a.mp3"},
        {id = "b", type = "image", path = "b.png"}
      }

      for _, bundler in ipairs(bundlers) do
        local manifest = bundler:generateManifest(testAssets)

        assert.is_not_nil(manifest)
        assert.is_not_nil(manifest.version)
        assert.is_not_nil(manifest.assets)
        assert.equals(2, #manifest.assets)
      end
    end)
  end)
end)
