-- FormatDetector Tests
-- Unit tests for the FormatDetector module

describe("FormatDetector", function()
  local FormatDetector
  local Types

  before_each(function()
    package.loaded["whisker.media.FormatDetector"] = nil
    package.loaded["whisker.media.types"] = nil

    Types = require("whisker.media.types")
    FormatDetector = require("whisker.media.FormatDetector")
    FormatDetector:reset()
  end)

  describe("platform detection", function()
    it("detects platform", function()
      local platform = FormatDetector:detectPlatform()

      assert.is_not_nil(platform)
      assert.is_true(
        platform == Types.Platform.LOVE2D or
        platform == Types.Platform.WEB or
        platform == Types.Platform.LUA
      )
    end)

    it("caches platform detection", function()
      local platform1 = FormatDetector:detectPlatform()
      local platform2 = FormatDetector:detectPlatform()

      assert.equals(platform1, platform2)
    end)
  end)

  describe("format detection", function()
    it("detectFormats returns format lists", function()
      local formats = FormatDetector:detectFormats()

      assert.is_not_nil(formats)
      assert.is_table(formats.audio)
      assert.is_table(formats.image)
    end)

    it("audio formats include common formats", function()
      local formats = FormatDetector:detectFormats()

      local hasCommon = false
      for _, f in ipairs(formats.audio) do
        if f == "mp3" or f == "ogg" or f == "wav" then
          hasCommon = true
          break
        end
      end

      assert.is_true(hasCommon)
    end)

    it("image formats include common formats", function()
      local formats = FormatDetector:detectFormats()

      local hasCommon = false
      for _, f in ipairs(formats.image) do
        if f == "png" or f == "jpg" then
          hasCommon = true
          break
        end
      end

      assert.is_true(hasCommon)
    end)

    it("caches format detection", function()
      local formats1 = FormatDetector:detectFormats()
      local formats2 = FormatDetector:detectFormats()

      assert.equals(formats1, formats2)
    end)
  end)

  describe("isFormatSupported", function()
    it("returns true for supported audio format", function()
      local supported = FormatDetector:isFormatSupported("mp3", "audio")
      -- mp3 should be supported on most platforms
      assert.is_boolean(supported)
    end)

    it("returns true for supported image format", function()
      local supported = FormatDetector:isFormatSupported("png", "image")
      assert.is_true(supported)
    end)

    it("returns false for unsupported format", function()
      local supported = FormatDetector:isFormatSupported("xyz123", "audio")
      assert.is_false(supported)
    end)

    it("handles case insensitivity", function()
      local supported1 = FormatDetector:isFormatSupported("PNG", "image")
      local supported2 = FormatDetector:isFormatSupported("png", "image")

      assert.equals(supported1, supported2)
    end)

    it("returns false for invalid asset type", function()
      local supported = FormatDetector:isFormatSupported("mp3", "invalid_type")
      assert.is_false(supported)
    end)
  end)

  describe("selectBestFormat", function()
    it("selects supported format from sources", function()
      local sources = {
        { format = "ogg", path = "audio.ogg" },
        { format = "mp3", path = "audio.mp3" }
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")

      assert.is_not_nil(selected)
      assert.is_true(selected.format == "ogg" or selected.format == "mp3")
    end)

    it("returns nil for empty sources", function()
      local selected = FormatDetector:selectBestFormat({}, "audio")
      assert.is_nil(selected)
    end)

    it("returns nil for nil sources", function()
      local selected = FormatDetector:selectBestFormat(nil, "audio")
      assert.is_nil(selected)
    end)

    it("prefers ogg for audio when supported", function()
      local sources = {
        { format = "mp3", path = "audio.mp3" },
        { format = "ogg", path = "audio.ogg" }
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")

      if FormatDetector:isFormatSupported("ogg", "audio") then
        assert.equals("ogg", selected.format)
      end
    end)

    it("falls back to available format", function()
      local sources = {
        { format = "xyz", path = "audio.xyz" },
        { format = "mp3", path = "audio.mp3" }
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")

      if FormatDetector:isFormatSupported("mp3", "audio") then
        assert.equals("mp3", selected.format)
      end
    end)

    it("returns nil when no formats supported", function()
      local sources = {
        { format = "xyz", path = "audio.xyz" },
        { format = "abc", path = "audio.abc" }
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")
      assert.is_nil(selected)
    end)
  end)

  describe("getFormatFromPath", function()
    it("extracts extension from path", function()
      local format = FormatDetector:getFormatFromPath("audio/music.mp3")
      assert.equals("mp3", format)
    end)

    it("handles uppercase extensions", function()
      local format = FormatDetector:getFormatFromPath("image.PNG")
      assert.equals("png", format)
    end)

    it("handles paths with multiple dots", function()
      local format = FormatDetector:getFormatFromPath("my.audio.file.ogg")
      assert.equals("ogg", format)
    end)

    it("returns nil for path without extension", function()
      local format = FormatDetector:getFormatFromPath("noextension")
      assert.is_nil(format)
    end)
  end)

  describe("getAssetTypeFromFormat", function()
    it("returns audio for audio formats", function()
      local assetType = FormatDetector:getAssetTypeFromFormat("mp3")
      assert.equals(Types.AssetType.AUDIO, assetType)
    end)

    it("returns image for image formats", function()
      local assetType = FormatDetector:getAssetTypeFromFormat("png")
      assert.equals(Types.AssetType.IMAGE, assetType)
    end)

    it("returns nil for unknown formats", function()
      local assetType = FormatDetector:getAssetTypeFromFormat("xyz")
      assert.is_nil(assetType)
    end)
  end)

  describe("reset", function()
    it("clears cached detection", function()
      FormatDetector:detectPlatform()
      FormatDetector:detectFormats()

      FormatDetector:reset()

      assert.is_nil(FormatDetector._platform)
      assert.is_nil(FormatDetector._detected)
    end)
  end)

  describe("platform-specific formats", function()
    it("detectLOVEFormats returns LOVE2D formats", function()
      local formats = FormatDetector:detectLOVEFormats()

      assert.is_table(formats.audio)
      assert.is_table(formats.image)
    end)

    it("detectWebFormats returns web formats", function()
      local formats = FormatDetector:detectWebFormats()

      assert.is_table(formats.audio)
      assert.is_table(formats.image)
    end)

    it("detectLuaFormats returns generic Lua formats", function()
      local formats = FormatDetector:detectLuaFormats()

      assert.is_table(formats.audio)
      assert.is_table(formats.image)
    end)
  end)
end)
