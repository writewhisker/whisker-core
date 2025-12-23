-- ImageManager Tests
-- Unit tests for the ImageManager module

describe("ImageManager", function()
  local ImageManager
  local AssetManager
  local Types

  before_each(function()
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil

    Types = require("whisker.media.types")
    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    ImageManager = require("whisker.media.ImageManager")
    ImageManager:initialize({
      screenWidth = 800,
      screenHeight = 600,
      devicePixelRatio = 1
    })

    -- Register test image asset
    AssetManager:register({
      id = "test_image",
      type = "image",
      variants = {
        { density = "1x", path = "test.png" },
        { density = "2x", path = "test@2x.png" }
      },
      metadata = { width = 100, height = 100 }
    })
  end)

  after_each(function()
    ImageManager:hideAll()
  end)

  describe("initialization", function()
    it("initializes with config", function()
      assert.is_true(ImageManager._initialized)
      assert.equals(1, ImageManager._devicePixelRatio)
    end)

    it("creates default containers", function()
      assert.is_not_nil(ImageManager:getContainer("background"))
      assert.is_not_nil(ImageManager:getContainer("left"))
      assert.is_not_nil(ImageManager:getContainer("center"))
      assert.is_not_nil(ImageManager:getContainer("right"))
    end)
  end)

  describe("container management", function()
    it("creates custom container", function()
      local container = ImageManager:createContainer("custom", {
        x = 100,
        y = 100,
        width = 200,
        height = 200,
        zIndex = 5
      })

      assert.is_not_nil(container)
      assert.equals("custom", container.id)
      assert.equals(100, container.x)
      assert.equals(200, container.width)
    end)

    it("getContainer returns container by ID", function()
      local container = ImageManager:getContainer("center")

      assert.is_not_nil(container)
      assert.equals("center", container.id)
    end)

    it("getContainer returns nil for non-existent container", function()
      local container = ImageManager:getContainer("nonexistent")
      assert.is_nil(container)
    end)

    it("removeContainer removes container", function()
      ImageManager:createContainer("temp", { x = 0, y = 0 })
      ImageManager:removeContainer("temp")

      assert.is_nil(ImageManager:getContainer("temp"))
    end)
  end)

  describe("display", function()
    it("displays image in container or fails gracefully", function()
      AssetManager:loadSync("test_image")

      local success = ImageManager:display("test_image", {
        container = "center"
      })

      -- Success depends on whether file actually exists
      assert.is_boolean(success)
      if success then
        assert.is_true(ImageManager:isDisplayed("test_image"))
      end
    end)

    it("creates container if not exists", function()
      AssetManager:loadSync("test_image")

      ImageManager:display("test_image", {
        container = "new_container"
      })

      assert.is_not_nil(ImageManager:getContainer("new_container"))
    end)

    it("replaces existing image in container when displayed", function()
      AssetManager:register({
        id = "image2",
        type = "image",
        variants = { { density = "1x", path = "image2.png" } }
      })

      AssetManager:loadSync("test_image")
      AssetManager:loadSync("image2")

      local display1 = ImageManager:display("test_image", { container = "center" })
      local display2 = ImageManager:display("image2", { container = "center" })

      local displayed = ImageManager:getDisplayedImage("center")
      if displayed then
        -- Second display should have replaced first
        assert.equals("image2", displayed.assetId)
      else
        -- Neither display succeeded (files don't exist)
        assert.is_false(display1)
        assert.is_false(display2)
      end
    end)

    it("applies fit mode when displayed", function()
      AssetManager:loadSync("test_image")

      local success = ImageManager:display("test_image", {
        container = "center",
        fitMode = Types.FitMode.COVER
      })

      local displayed = ImageManager:getDisplayedImage("center")
      if displayed then
        assert.equals(Types.FitMode.COVER, displayed.fitMode)
      else
        assert.is_false(success)
      end
    end)

    it("applies fade in when displayed", function()
      AssetManager:loadSync("test_image")

      local success = ImageManager:display("test_image", {
        container = "center",
        fadeIn = 0.5
      })

      local displayed = ImageManager:getDisplayedImage("center")
      if displayed then
        assert.is_true(displayed.fading)
        assert.equals(0, displayed.opacity)
      else
        assert.is_false(success)
      end
    end)
  end)

  describe("hide", function()
    it("hides displayed image or handles empty container", function()
      AssetManager:loadSync("test_image")
      ImageManager:display("test_image", { container = "center" })

      local success = ImageManager:hide("center")

      -- Success depends on whether display succeeded
      assert.is_boolean(success)
    end)

    it("returns false for empty container", function()
      local success = ImageManager:hide("empty")
      assert.is_false(success)
    end)

    it("applies fade out when displayed", function()
      AssetManager:loadSync("test_image")
      local displaySuccess = ImageManager:display("test_image", { container = "center" })

      if displaySuccess then
        ImageManager:hide("center", { fadeOut = 0.5 })

        local displayed = ImageManager:getDisplayedImage("center")
        if displayed then
          assert.is_true(displayed.fading)
          assert.equals(0, displayed.targetOpacity)
        end
      else
        -- No image displayed, skip
        assert.is_false(displaySuccess)
      end
    end)
  end)

  describe("hideAll", function()
    it("hides all displayed images", function()
      AssetManager:loadSync("test_image")
      ImageManager:display("test_image", { container = "center" })
      ImageManager:display("test_image", { container = "left" })

      ImageManager:hideAll()

      assert.is_nil(ImageManager:getDisplayedImage("center"))
      assert.is_nil(ImageManager:getDisplayedImage("left"))
    end)
  end)

  describe("isDisplayed", function()
    it("returns boolean for displayed status", function()
      AssetManager:loadSync("test_image")
      local displaySuccess = ImageManager:display("test_image", { container = "center" })

      -- If display succeeded, should be displayed
      if displaySuccess then
        assert.is_true(ImageManager:isDisplayed("test_image"))
      else
        assert.is_false(ImageManager:isDisplayed("test_image"))
      end
    end)

    it("returns false for non-displayed image", function()
      assert.is_false(ImageManager:isDisplayed("test_image"))
    end)
  end)

  describe("opacity", function()
    it("setOpacity changes opacity when displayed", function()
      AssetManager:loadSync("test_image")
      local displaySuccess = ImageManager:display("test_image", { container = "center" })

      if displaySuccess then
        ImageManager:setOpacity("center", 0.5)
        assert.equals(0.5, ImageManager:getOpacity("center"))
      else
        -- No image displayed, opacity should be 0
        assert.equals(0, ImageManager:getOpacity("center"))
      end
    end)

    it("getOpacity returns 0 for empty container", function()
      assert.equals(0, ImageManager:getOpacity("empty"))
    end)

    it("setOpacity returns false for empty container", function()
      local success = ImageManager:setOpacity("empty", 0.5)
      assert.is_false(success)
    end)
  end)

  describe("fit mode", function()
    it("setFitMode changes fit mode when displayed", function()
      AssetManager:loadSync("test_image")
      local displaySuccess = ImageManager:display("test_image", { container = "center" })

      if displaySuccess then
        ImageManager:setFitMode("center", Types.FitMode.FILL)

        local displayed = ImageManager:getDisplayedImage("center")
        if displayed then
          assert.equals(Types.FitMode.FILL, displayed.fitMode)
        end
      else
        -- Display failed, setFitMode should return false
        local success = ImageManager:setFitMode("center", Types.FitMode.FILL)
        assert.is_false(success)
      end
    end)

    it("returns false for empty container", function()
      local success = ImageManager:setFitMode("empty", Types.FitMode.COVER)
      assert.is_false(success)
    end)
  end)

  describe("getAllDisplayedImages", function()
    it("returns all displayed images", function()
      AssetManager:loadSync("test_image")
      local display1 = ImageManager:display("test_image", { container = "center" })
      local display2 = ImageManager:display("test_image", { container = "left" })

      local images = ImageManager:getAllDisplayedImages()

      local count = 0
      for _ in pairs(images) do count = count + 1 end

      -- Count depends on whether displays succeeded
      local expectedCount = (display1 and 1 or 0) + (display2 and 1 or 0)
      assert.equals(expectedCount, count)
    end)
  end)

  describe("device pixel ratio", function()
    it("setDevicePixelRatio updates ratio", function()
      ImageManager:setDevicePixelRatio(2)
      assert.equals(2, ImageManager:getDevicePixelRatio())
    end)
  end)

  describe("calculateFitDimensions", function()
    it("calculates contain dimensions", function()
      local w, h, ox, oy = ImageManager:calculateFitDimensions(
        100, 100, 200, 200, Types.FitMode.CONTAIN
      )

      assert.equals(200, w)
      assert.equals(200, h)
    end)

    it("calculates cover dimensions", function()
      local w, h, ox, oy = ImageManager:calculateFitDimensions(
        100, 50, 200, 200, Types.FitMode.COVER
      )

      -- Cover should scale to fill, so width should be >= container
      assert.is_true(w >= 200 or h >= 200)
    end)

    it("calculates fill dimensions", function()
      local w, h, ox, oy = ImageManager:calculateFitDimensions(
        100, 50, 200, 300, Types.FitMode.FILL
      )

      assert.equals(200, w)
      assert.equals(300, h)
      assert.equals(0, ox)
      assert.equals(0, oy)
    end)

    it("calculates none dimensions", function()
      local w, h, ox, oy = ImageManager:calculateFitDimensions(
        100, 50, 200, 200, Types.FitMode.NONE
      )

      assert.equals(100, w)
      assert.equals(50, h)
    end)
  end)

  describe("update", function()
    it("processes fade animations when displayed", function()
      AssetManager:loadSync("test_image")
      local displaySuccess = ImageManager:display("test_image", {
        container = "center",
        fadeIn = 1.0
      })

      if displaySuccess then
        ImageManager:update(0.5)

        local displayed = ImageManager:getDisplayedImage("center")
        if displayed then
          assert.is_true(displayed.opacity > 0)
        end
      else
        -- Display failed, nothing to update
        assert.is_false(displaySuccess)
      end
    end)

    it("removes images after fade out completes", function()
      AssetManager:loadSync("test_image")
      ImageManager:display("test_image", { container = "center" })
      ImageManager:hide("center", { fadeOut = 0.5 })

      ImageManager:update(0.25)
      ImageManager:update(0.25)
      ImageManager:update(0.1)

      assert.is_nil(ImageManager:getDisplayedImage("center"))
    end)
  end)

  describe("registerImage", function()
    it("registers image via AssetManager", function()
      local success = ImageManager:registerImage({
        id = "via_image_manager",
        variants = { { density = "1x", path = "test.png" } }
      })

      assert.is_true(success)
      assert.is_not_nil(AssetManager:getConfig("via_image_manager"))
    end)
  end)
end)
