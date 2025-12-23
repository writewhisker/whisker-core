-- Tests for BundlingStrategy
describe("BundlingStrategy", function()
  local BundlingStrategy

  before_each(function()
    package.loaded["whisker.media.bundlers.BundlingStrategy"] = nil
    BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")
  end)

  describe("isFormatSupported", function()
    it("returns true for supported formats", function()
      local strategy = BundlingStrategy.new()
      local supported = {"mp3", "ogg", "wav"}

      assert.is_true(strategy:isFormatSupported("mp3", supported))
      assert.is_true(strategy:isFormatSupported("ogg", supported))
    end)

    it("returns false for unsupported formats", function()
      local strategy = BundlingStrategy.new()
      local supported = {"mp3", "ogg"}

      assert.is_false(strategy:isFormatSupported("flac", supported))
    end)
  end)

  describe("selectSources", function()
    it("selects matching sources", function()
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

    it("selects from variants", function()
      local strategy = BundlingStrategy.new()

      local assetConfig = {
        id = "test",
        type = "image",
        variants = {
          {density = "1x", path = "test.png"},
          {density = "2x", path = "test@2x.png"},
          {density = "1x", path = "test.webp"}
        }
      }

      local selected = strategy:selectSources(assetConfig, {"png"})

      assert.equals(2, #selected)
    end)
  end)

  describe("getFileSize", function()
    it("returns 0 for missing files", function()
      local strategy = BundlingStrategy.new()
      local size = strategy:getFileSize("/nonexistent/file.txt")
      assert.equals(0, size)
    end)
  end)
end)
