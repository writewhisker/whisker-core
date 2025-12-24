-- Tests for ImageManager module
describe("ImageManager", function()
  local ImageManager, AssetManager
  local mock_event_bus
  local mock_asset_manager

  before_each(function()
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.types"] = nil
    ImageManager = require("whisker.media.ImageManager")
    AssetManager = require("whisker.media.AssetManager")

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock asset manager
    mock_asset_manager = {
      _configs = {},
      _assets = {},
      _refs = {},
      register = function(self, config)
        self._configs[config.id] = config
        return true
      end,
      get = function(self, id)
        return self._assets[id]
      end,
      getConfig = function(self, id)
        return self._configs[id]
      end,
      loadSync = function(self, id)
        local config = self._configs[id]
        if config then
          local asset = {id = id, type = config.type, data = "mock"}
          self._assets[id] = asset
          return asset
        end
        return nil, {message = "Not found"}
      end,
      retain = function(self, id)
        self._refs[id] = (self._refs[id] or 0) + 1
        return true
      end,
      release = function(self, id)
        if self._refs[id] and self._refs[id] > 0 then
          self._refs[id] = self._refs[id] - 1
          return true
        end
        return false
      end
    }

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

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(ImageManager._dependencies)
      assert.same({"asset_manager", "event_bus"}, ImageManager._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(ImageManager.create)
    end)

    it("provides new constructor", function()
      assert.is_function(ImageManager.new)
    end)

    it("create returns a factory function", function()
      local factory = ImageManager.create({
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      assert.is_function(factory)
    end)

    it("factory creates manager instances with injected deps", function()
      local factory = ImageManager.create({
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      local manager = factory({
        screenWidth = 800,
        screenHeight = 600
      })
      assert.is_not_nil(manager)
      assert.is_function(manager.display)
      assert.is_function(manager.hide)
    end)

    it("new creates instance with injected asset_manager", function()
      local manager = ImageManager.new({}, {asset_manager = mock_asset_manager})
      assert.equals(mock_asset_manager, manager._asset_manager)
    end)

    it("new creates instance with injected event_bus", function()
      local manager = ImageManager.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, manager._event_bus)
    end)

    it("works without deps (backward compatibility)", function()
      local manager = ImageManager.new({})
      assert.is_not_nil(manager)
      assert.is_not_nil(manager._asset_manager)
    end)
  end)

  describe("event emission", function()
    it("emits image:display event on display", function()
      -- Register an image in the mock asset manager
      mock_asset_manager:register({
        id = "test_image",
        type = "image",
        variants = {{density = "1x", path = "test.png"}}
      })

      local manager = ImageManager.new({
        screenWidth = 800,
        screenHeight = 600
      }, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      manager:initialize({
        screenWidth = 800,
        screenHeight = 600
      })

      -- Display the image
      manager:display("test_image", {container = "center"})

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "image:display" then
          found = true
          assert.equals("test_image", e.data.assetId)
          assert.equals("center", e.data.containerId)
        end
      end
      assert.is_true(found, "Should have emitted image:display event")
    end)

    it("emits image:hide event on hide", function()
      -- Register an image in the mock asset manager
      mock_asset_manager:register({
        id = "test_image",
        type = "image",
        variants = {{density = "1x", path = "test.png"}}
      })

      local manager = ImageManager.new({
        screenWidth = 800,
        screenHeight = 600
      }, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      manager:initialize({
        screenWidth = 800,
        screenHeight = 600
      })

      -- Display then hide
      manager:display("test_image", {container = "center"})
      mock_event_bus.events = {} -- Clear events
      manager:hide("center")

      local found = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "image:hide" then
          found = true
          assert.equals("test_image", e.data.assetId)
          assert.equals("center", e.data.containerId)
        end
      end
      assert.is_true(found, "Should have emitted image:hide event")
    end)

    it("does not emit events when event_bus is nil", function()
      mock_asset_manager:register({
        id = "test_image",
        type = "image",
        variants = {{density = "1x", path = "test.png"}}
      })

      local manager = ImageManager.new({
        screenWidth = 800,
        screenHeight = 600
      }, {
        asset_manager = mock_asset_manager
        -- no event_bus
      })
      manager:initialize({
        screenWidth = 800,
        screenHeight = 600
      })

      -- Should not error
      assert.has_no.errors(function()
        manager:display("test_image", {container = "center"})
        manager:hide("center")
      end)
    end)

    it("uses injected asset_manager for registerImage", function()
      local manager = ImageManager.new({}, {
        asset_manager = mock_asset_manager,
        event_bus = mock_event_bus
      })
      manager:initialize({
        screenWidth = 800,
        screenHeight = 600
      })

      manager:registerImage({
        id = "registered_img",
        variants = {{density = "1x", path = "test.png"}}
      })

      assert.is_not_nil(mock_asset_manager._configs["registered_img"])
      assert.equals("image", mock_asset_manager._configs["registered_img"].type)
    end)
  end)
end)
