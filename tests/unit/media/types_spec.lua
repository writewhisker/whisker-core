-- Tests for media types module
describe("Media Types", function()
  local Types

  before_each(function()
    package.loaded["whisker.media.types"] = nil
    Types = require("whisker.media.types")
  end)

  describe("AssetType", function()
    it("defines audio type", function()
      assert.equals("audio", Types.AssetType.AUDIO)
    end)

    it("defines image type", function()
      assert.equals("image", Types.AssetType.IMAGE)
    end)

    it("defines video type", function()
      assert.equals("video", Types.AssetType.VIDEO)
    end)
  end)

  describe("AssetState", function()
    it("defines unloaded state", function()
      assert.equals("unloaded", Types.AssetState.UNLOADED)
    end)

    it("defines loading state", function()
      assert.equals("loading", Types.AssetState.LOADING)
    end)

    it("defines loaded state", function()
      assert.equals("loaded", Types.AssetState.LOADED)
    end)

    it("defines failed state", function()
      assert.equals("failed", Types.AssetState.FAILED)
    end)
  end)

  describe("DefaultChannels", function()
    it("defines MUSIC channel", function()
      assert.is_not_nil(Types.DefaultChannels.MUSIC)
      assert.equals("MUSIC", Types.DefaultChannels.MUSIC.name)
      assert.equals(1, Types.DefaultChannels.MUSIC.maxConcurrent)
    end)

    it("defines VOICE channel with ducking", function()
      assert.is_not_nil(Types.DefaultChannels.VOICE)
      assert.equals(0.3, Types.DefaultChannels.VOICE.ducking.MUSIC)
    end)
  end)

  describe("isValidAssetType", function()
    it("returns true for valid types", function()
      assert.is_true(Types.isValidAssetType("audio"))
      assert.is_true(Types.isValidAssetType("image"))
      assert.is_true(Types.isValidAssetType("video"))
    end)

    it("returns false for invalid types", function()
      assert.is_false(Types.isValidAssetType("invalid"))
      assert.is_false(Types.isValidAssetType(""))
      assert.is_false(Types.isValidAssetType(nil))
    end)
  end)

  describe("getFormatCategory", function()
    it("detects audio formats", function()
      assert.equals("audio", Types.getFormatCategory("mp3"))
      assert.equals("audio", Types.getFormatCategory("wav"))
      assert.equals("audio", Types.getFormatCategory("flac"))
    end)

    it("detects image formats", function()
      assert.equals("image", Types.getFormatCategory("png"))
      assert.equals("image", Types.getFormatCategory("jpg"))
      assert.equals("image", Types.getFormatCategory("webp"))
    end)

    it("detects video formats", function()
      assert.equals("video", Types.getFormatCategory("mp4"))
      assert.equals("video", Types.getFormatCategory("webm"))
    end)

    it("handles case insensitivity", function()
      assert.equals("audio", Types.getFormatCategory("MP3"))
      assert.equals("image", Types.getFormatCategory("PNG"))
    end)

    it("returns nil for unknown formats", function()
      assert.is_nil(Types.getFormatCategory("xyz"))
    end)
  end)
end)
