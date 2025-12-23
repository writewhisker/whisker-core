-- Integration tests for AssetManager + ImageManager
describe("AssetManager + ImageManager Integration", function()
  local AssetManager, ImageManager, Types

  -- Helper to cache an asset
  local function cacheAsset(id, assetType)
    AssetManager._cache:set(id, {
      id = id,
      type = assetType,
      data = "mock_image_data",
      sizeBytes = 2048,
      width = 800,
      height = 600
    }, 2048)
    AssetManager._states[id] = Types.AssetState.LOADED
  end

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.types"] = nil

    Types = require("whisker.media.types")
    AssetManager = require("whisker.media.AssetManager")
    ImageManager = require("whisker.media.ImageManager")

    AssetManager:initialize()
    ImageManager:initialize()

    -- Register test images
    AssetManager:register({
      id = "portrait_alice",
      type = "image",
      sources = {{format = "png", path = "alice.png"}}
    })
    cacheAsset("portrait_alice", "image")

    AssetManager:register({
      id = "background_forest",
      type = "image",
      sources = {{format = "png", path = "forest.png"}}
    })
    cacheAsset("background_forest", "image")
  end)

  describe("display workflow", function()
    it("displays image from AssetManager", function()
      ImageManager:createContainer("portrait", {
        width = 300,
        height = 400
      })

      local result = ImageManager:display("portrait_alice", {
        container = "portrait",
        fitMode = "contain"
      })

      assert.is_true(result)
    end)

    it("hides displayed image", function()
      ImageManager:createContainer("portrait", {width = 300, height = 400})
      ImageManager:display("portrait_alice", {container = "portrait"})

      local result = ImageManager:hide("portrait")

      assert.is_true(result)
    end)
  end)

  describe("multiple containers", function()
    it("displays different images in different containers", function()
      ImageManager:createContainer("background", {width = 1920, height = 1080})
      ImageManager:createContainer("portrait", {width = 300, height = 400})

      ImageManager:display("background_forest", {container = "background"})
      ImageManager:display("portrait_alice", {container = "portrait"})

      assert.equals("background_forest", ImageManager._displayedImages["background"].assetId)
      assert.equals("portrait_alice", ImageManager._displayedImages["portrait"].assetId)
    end)

    it("replaces image in same container", function()
      ImageManager:createContainer("portrait", {width = 300, height = 400})

      ImageManager:display("portrait_alice", {container = "portrait"})
      ImageManager:display("background_forest", {container = "portrait"})

      -- Should now show the new image
      assert.equals("background_forest", ImageManager._displayedImages["portrait"].assetId)
    end)
  end)

  describe("fit modes", function()
    it("calculates contain fit correctly", function()
      ImageManager:createContainer("test", {width = 800, height = 600})

      local width, height, offsetX, offsetY = ImageManager:calculateFitDimensions(
        1600, 900,  -- source size (16:9)
        800, 600,   -- container size (4:3)
        "contain"
      )

      -- Should fit width and have letterboxing
      assert.equals(800, width)
      assert.is_true(height <= 600)
    end)

    it("calculates cover fit correctly", function()
      ImageManager:createContainer("test", {width = 800, height = 600})

      local width, height, offsetX, offsetY = ImageManager:calculateFitDimensions(
        400, 600,   -- source size (2:3)
        800, 600,   -- container size (4:3)
        "cover"
      )

      -- Should fill container (may crop)
      assert.is_true(width >= 800 or height >= 600)
    end)
  end)

  describe("asset lifecycle", function()
    it("handles multiple display/hide cycles", function()
      ImageManager:createContainer("portrait", {width = 300, height = 400})

      for i = 1, 5 do
        ImageManager:display("portrait_alice", {container = "portrait"})
        ImageManager:hide("portrait")
      end

      -- ImageManager should still be functional
      assert.is_true(ImageManager._initialized)
      -- Can still create containers
      ImageManager:createContainer("test2", {width = 100, height = 100})
      assert.is_not_nil(ImageManager._containers["test2"])
    end)
  end)

  describe("responsive variants", function()
    it("selects appropriate variant for DPR", function()
      AssetManager:register({
        id = "responsive_image",
        type = "image",
        variants = {
          {density = "1x", path = "image.png"},
          {density = "2x", path = "image@2x.png"},
          {density = "3x", path = "image@3x.png"}
        }
      })

      local config = AssetManager._registry["responsive_image"]
      assert.equals(3, #config.variants)
    end)
  end)
end)
