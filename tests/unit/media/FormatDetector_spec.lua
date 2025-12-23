-- Tests for FormatDetector module
describe("FormatDetector", function()
  local FormatDetector

  before_each(function()
    package.loaded["whisker.media.FormatDetector"] = nil
    package.loaded["whisker.media.types"] = nil
    FormatDetector = require("whisker.media.FormatDetector")
    FormatDetector:reset()
  end)

  describe("detectPlatform", function()
    it("detects LUA platform when no frameworks present", function()
      local platform = FormatDetector:detectPlatform()
      assert.equals("lua", platform)
    end)

    it("caches platform detection", function()
      local platform1 = FormatDetector:detectPlatform()
      local platform2 = FormatDetector:detectPlatform()
      assert.equals(platform1, platform2)
    end)
  end)

  describe("detectFormats", function()
    it("returns audio and image format lists", function()
      local formats = FormatDetector:detectFormats()
      assert.is_table(formats.audio)
      assert.is_table(formats.image)
      assert.is_true(#formats.audio > 0)
      assert.is_true(#formats.image > 0)
    end)

    it("caches format detection", function()
      local formats1 = FormatDetector:detectFormats()
      local formats2 = FormatDetector:detectFormats()
      assert.equals(formats1, formats2)
    end)
  end)

  describe("isFormatSupported", function()
    it("reports common audio formats as supported", function()
      assert.is_true(FormatDetector:isFormatSupported("mp3", "audio"))
      assert.is_true(FormatDetector:isFormatSupported("ogg", "audio"))
      assert.is_true(FormatDetector:isFormatSupported("wav", "audio"))
    end)

    it("reports common image formats as supported", function()
      assert.is_true(FormatDetector:isFormatSupported("png", "image"))
      assert.is_true(FormatDetector:isFormatSupported("jpg", "image"))
    end)

    it("handles case insensitivity", function()
      assert.is_true(FormatDetector:isFormatSupported("MP3", "audio"))
      assert.is_true(FormatDetector:isFormatSupported("PNG", "image"))
    end)

    it("returns false for unsupported formats", function()
      assert.is_false(FormatDetector:isFormatSupported("xyz", "audio"))
    end)

    it("returns false for invalid asset types", function()
      assert.is_false(FormatDetector:isFormatSupported("mp3", "invalid"))
    end)
  end)

  describe("selectBestFormat", function()
    it("selects first supported format", function()
      local sources = {
        {format = "ogg", path = "test.ogg"},
        {format = "mp3", path = "test.mp3"}
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")
      assert.is_not_nil(selected)
      assert.is_true(selected.format == "ogg" or selected.format == "mp3")
    end)

    it("skips unsupported formats", function()
      local sources = {
        {format = "xyz", path = "test.xyz"},
        {format = "mp3", path = "test.mp3"}
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")
      assert.is_not_nil(selected)
      assert.equals("mp3", selected.format)
    end)

    it("returns nil when no formats supported", function()
      local sources = {
        {format = "xyz", path = "test.xyz"}
      }

      local selected = FormatDetector:selectBestFormat(sources, "audio")
      assert.is_nil(selected)
    end)

    it("returns nil for empty sources", function()
      local selected = FormatDetector:selectBestFormat({}, "audio")
      assert.is_nil(selected)
    end)

    it("returns nil for nil sources", function()
      local selected = FormatDetector:selectBestFormat(nil, "audio")
      assert.is_nil(selected)
    end)
  end)

  describe("getFormatFromPath", function()
    it("extracts format from file path", function()
      assert.equals("mp3", FormatDetector:getFormatFromPath("audio/music.mp3"))
      assert.equals("png", FormatDetector:getFormatFromPath("images/sprite.png"))
    end)

    it("handles paths with multiple dots", function()
      assert.equals("mp3", FormatDetector:getFormatFromPath("audio/my.music.file.mp3"))
    end)

    it("returns lowercase format", function()
      assert.equals("mp3", FormatDetector:getFormatFromPath("audio/MUSIC.MP3"))
    end)

    it("returns nil for paths without extension", function()
      assert.is_nil(FormatDetector:getFormatFromPath("audio/music"))
    end)
  end)

  describe("getAssetTypeFromFormat", function()
    it("identifies audio formats", function()
      assert.equals("audio", FormatDetector:getAssetTypeFromFormat("mp3"))
      assert.equals("audio", FormatDetector:getAssetTypeFromFormat("wav"))
    end)

    it("identifies image formats", function()
      assert.equals("image", FormatDetector:getAssetTypeFromFormat("png"))
      assert.equals("image", FormatDetector:getAssetTypeFromFormat("jpg"))
    end)

    it("identifies video formats", function()
      assert.equals("video", FormatDetector:getAssetTypeFromFormat("mp4"))
    end)
  end)

  describe("reset", function()
    it("clears cached detection", function()
      local formats1 = FormatDetector:detectFormats()
      FormatDetector:reset()
      FormatDetector._detected = {audio = {"custom"}, image = {}}
      local formats2 = FormatDetector:detectFormats()
      assert.equals("custom", formats2.audio[1])
    end)
  end)
end)
