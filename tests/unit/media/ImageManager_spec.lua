-- Tests for ImageManager module
describe("ImageManager", function()
  local ImageManager, AssetManager

  before_each(function()
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil
    ImageManager = require("whisker.media.ImageManager")
    AssetManager = require("whisker.media.AssetManager")

    AssetManager:initialize()
    ImageManager:initialize({
      screenWidth = 800,
      screenHeight = 600
    })
  end)

  describe("initialize", function()
    it("creates default containers", function()
      assert.is_not_nil(ImageManager:getContainer("background"))
      assert.is_not_nil(ImageManager:getContainer("left"))
      assert.is_not_nil(ImageManager:getContainer("center"))
      assert.is_not_nil(ImageManager:getContainer("right"))
    end)
  end)

  describe("createContainer", function()
    it("creates a container with config", function()
      local container = ImageManager:createContainer("custom", {
        x = 100, y = 200,
        width = 300, height = 400,
        zIndex = 5
      })

      assert.equals("custom", container.id)
      assert.equals(100, container.x)
      assert.equals(200, container.y)
      assert.equals(300, container.width)
      assert.equals(400, container.height)
      assert.equals(5, container.zIndex)
    end)
  end)

  describe("getContainer", function()
    it("returns existing container", function()
      local container = ImageManager:getContainer("background")
      assert.is_not_nil(container)
    end)

    it("returns nil for missing container", function()
      assert.is_nil(ImageManager:getContainer("nonexistent"))
    end)
  end)

  describe("isDisplayed", function()
    it("returns false for non-displayed assets", function()
      assert.is_false(ImageManager:isDisplayed("test_image"))
    end)
  end)

  describe("getDisplayedImage", function()
    it("returns nil for empty container", function()
      assert.is_nil(ImageManager:getDisplayedImage("center"))
    end)
  end)

  describe("getAllDisplayedImages", function()
    it("returns empty table when nothing displayed", function()
      local images = ImageManager:getAllDisplayedImages()
      assert.is_table(images)
      local count = 0
      for _ in pairs(images) do count = count + 1 end
      assert.equals(0, count)
    end)
  end)

  describe("setOpacity", function()
    it("returns false for non-displayed container", function()
      assert.is_false(ImageManager:setOpacity("center", 0.5))
    end)
  end)

  describe("getOpacity", function()
    it("returns 0 for non-displayed container", function()
      assert.equals(0, ImageManager:getOpacity("center"))
    end)
  end)

  describe("setFitMode", function()
    it("returns false for non-displayed container", function()
      assert.is_false(ImageManager:setFitMode("center", "cover"))
    end)
  end)

  describe("setDevicePixelRatio", function()
    it("updates device pixel ratio", function()
      ImageManager:setDevicePixelRatio(2)
      assert.equals(2, ImageManager:getDevicePixelRatio())
    end)
  end)

  describe("calculateFitDimensions", function()
    it("calculates contain dimensions", function()
      local w, h, x, y = ImageManager:calculateFitDimensions(200, 100, 400, 400, "contain")

      assert.equals(400, w)
      assert.equals(200, h)
      assert.equals(0, x)
      assert.equals(100, y)
    end)

    it("calculates cover dimensions", function()
      local w, h, x, y = ImageManager:calculateFitDimensions(200, 100, 400, 400, "cover")

      assert.equals(800, w)
      assert.equals(400, h)
      assert.equals(-200, x)
      assert.equals(0, y)
    end)

    it("calculates fill dimensions", function()
      local w, h, x, y = ImageManager:calculateFitDimensions(200, 100, 400, 300, "fill")

      assert.equals(400, w)
      assert.equals(300, h)
      assert.equals(0, x)
      assert.equals(0, y)
    end)

    it("calculates none dimensions", function()
      local w, h, x, y = ImageManager:calculateFitDimensions(200, 100, 400, 400, "none")

      assert.equals(200, w)
      assert.equals(100, h)
      assert.equals(100, x)
      assert.equals(150, y)
    end)
  end)

  describe("hideAll", function()
    it("hides all displayed images", function()
      ImageManager:hideAll()
      local images = ImageManager:getAllDisplayedImages()
      local count = 0
      for _ in pairs(images) do count = count + 1 end
      assert.equals(0, count)
    end)
  end)

  describe("update", function()
    it("runs without error", function()
      assert.has_no.errors(function()
        ImageManager:update(0.016)
      end)
    end)
  end)

  describe("registerImage", function()
    it("registers image through AssetManager", function()
      local success = ImageManager:registerImage({
        id = "test_img",
        variants = {{density = "1x", path = "test.png"}}
      })

      assert.is_true(success)
      assert.is_not_nil(AssetManager:getConfig("test_img"))
    end)
  end)
end)
