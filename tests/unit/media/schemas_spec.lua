-- Tests for media schemas module
describe("Media Schemas", function()
  local Schemas

  before_each(function()
    package.loaded["whisker.media.schemas"] = nil
    package.loaded["whisker.media.types"] = nil
    Schemas = require("whisker.media.schemas")
  end)

  describe("validateAudioAsset", function()
    it("validates a valid audio asset", function()
      local config = {
        id = "test_audio",
        type = "audio",
        sources = {
          {format = "mp3", path = "audio/test.mp3"},
          {format = "ogg", path = "audio/test.ogg"}
        }
      }

      local errors = Schemas.validateAudioAsset(config)
      assert.equals(0, #errors)
    end)

    it("rejects missing id", function()
      local config = {
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      }

      local errors = Schemas.validateAudioAsset(config)
      assert.is_true(#errors > 0)

      local hasIdError = false
      for _, err in ipairs(errors) do
        if err.path == "id" then hasIdError = true end
      end
      assert.is_true(hasIdError)
    end)

    it("rejects empty sources", function()
      local config = {
        id = "test",
        type = "audio",
        sources = {}
      }

      local errors = Schemas.validateAudioAsset(config)
      assert.is_true(#errors > 0)
    end)

    it("validates metadata", function()
      local config = {
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}},
        metadata = {
          duration = 120,
          loop = true,
          tags = {"music", "ambient"}
        }
      }

      local errors = Schemas.validateAudioAsset(config)
      assert.equals(0, #errors)
    end)

    it("rejects negative duration", function()
      local config = {
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}},
        metadata = {duration = -5}
      }

      local errors = Schemas.validateAudioAsset(config)
      assert.is_true(#errors > 0)
    end)
  end)

  describe("validateImageAsset", function()
    it("validates a valid image asset", function()
      local config = {
        id = "test_image",
        type = "image",
        variants = {
          {density = "1x", path = "images/test.png"},
          {density = "2x", path = "images/test@2x.png"}
        }
      }

      local errors = Schemas.validateImageAsset(config)
      assert.equals(0, #errors)
    end)

    it("rejects missing variants", function()
      local config = {
        id = "test",
        type = "image"
      }

      local errors = Schemas.validateImageAsset(config)
      assert.is_true(#errors > 0)
    end)

    it("validates alt text in metadata", function()
      local config = {
        id = "test",
        type = "image",
        variants = {{density = "1x", path = "test.png"}},
        metadata = {
          alt = "A test image",
          width = 100,
          height = 100
        }
      }

      local errors = Schemas.validateImageAsset(config)
      assert.equals(0, #errors)
    end)
  end)

  describe("validateAsset", function()
    it("routes audio assets correctly", function()
      local config = {
        id = "test",
        type = "audio",
        sources = {{format = "mp3", path = "test.mp3"}}
      }

      local errors = Schemas.validateAsset(config)
      assert.equals(0, #errors)
    end)

    it("routes image assets correctly", function()
      local config = {
        id = "test",
        type = "image",
        variants = {{density = "1x", path = "test.png"}}
      }

      local errors = Schemas.validateAsset(config)
      assert.equals(0, #errors)
    end)

    it("rejects unknown asset types", function()
      local config = {
        id = "test",
        type = "unknown"
      }

      local errors = Schemas.validateAsset(config)
      assert.is_true(#errors > 0)
    end)

    it("rejects nil config", function()
      local errors = Schemas.validateAsset(nil)
      assert.is_true(#errors > 0)
    end)
  end)
end)
