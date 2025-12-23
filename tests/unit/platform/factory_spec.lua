--- PlatformFactory Tests
--- Tests for the platform factory.

describe("PlatformFactory", function()
  local PlatformFactory
  local IPlatform

  before_each(function()
    package.loaded["whisker.platform.factory"] = nil
    package.loaded["whisker.platform.mock"] = nil
    package.loaded["whisker.platform.interface"] = nil
    PlatformFactory = require("whisker.platform.factory")
    IPlatform = require("whisker.platform.interface")

    -- Reset singleton
    PlatformFactory.reset()

    -- Clear any environment variables
    _G.WHISKER_PLATFORM = nil
    _G.ENVIRONMENT = nil
    _G.ios_platform_save = nil
    _G.android_platform_save = nil
    _G.electron_save = nil
    _G.js = nil
  end)

  describe("detect", function()
    it("defaults to mock when no platform detected", function()
      local detected = PlatformFactory.detect()
      assert.equals("mock", detected)
    end)

    it("uses WHISKER_PLATFORM if set", function()
      _G.WHISKER_PLATFORM = "test"
      local detected = PlatformFactory.detect()
      assert.equals("test", detected)
    end)

    it("uses ENVIRONMENT if set", function()
      _G.ENVIRONMENT = "ios"
      local detected = PlatformFactory.detect()
      assert.equals("ios", detected)
    end)

    it("detects iOS by bridge function", function()
      _G.ios_platform_save = function() end
      local detected = PlatformFactory.detect()
      assert.equals("ios", detected)
    end)

    it("detects Android by bridge function", function()
      _G.android_platform_save = function() end
      local detected = PlatformFactory.detect()
      assert.equals("android", detected)
    end)

    it("detects web by js global", function()
      _G.js = {}
      local detected = PlatformFactory.detect()
      assert.equals("web", detected)
    end)
  end)

  describe("create", function()
    it("creates mock platform by default", function()
      local platform = PlatformFactory.create("mock")
      assert.is_not_nil(platform)
      assert.equals("mock", platform:get_name())
    end)

    it("creates platform from auto-detection", function()
      local platform = PlatformFactory.create()
      assert.is_not_nil(platform)
      -- In test environment, should default to mock
      assert.equals("mock", platform:get_name())
    end)

    it("passes config to platform constructor", function()
      local platform = PlatformFactory.create("mock", {locale = "fr-FR"})
      assert.equals("fr-FR", platform:get_locale())
    end)

    it("raises error for unknown platform", function()
      assert.has_error(function()
        PlatformFactory.create("nonexistent_platform")
      end)
    end)
  end)

  describe("register/unregister", function()
    it("registers custom platform", function()
      local CustomPlatform = {
        new = function()
          return {
            get_name = function() return "custom" end,
            save = function() return true end,
            load = function() return nil end,
            get_locale = function() return "en-US" end,
            has_capability = function() return true end,
          }
        end
      }

      PlatformFactory.register("custom", CustomPlatform)
      local platform = PlatformFactory.create("custom")
      assert.equals("custom", platform:get_name())
    end)

    it("unregisters custom platform", function()
      local CustomPlatform = {
        new = function()
          return {get_name = function() return "temp" end}
        end
      }

      PlatformFactory.register("temp", CustomPlatform)
      assert.is_true(PlatformFactory.is_available("temp"))

      PlatformFactory.unregister("temp")
      assert.is_false(PlatformFactory.is_available("temp"))
    end)

    it("rejects invalid platform name", function()
      assert.has_error(function()
        PlatformFactory.register("", {new = function() end})
      end)
    end)

    it("rejects module without new function", function()
      assert.has_error(function()
        PlatformFactory.register("bad", {})
      end)
    end)
  end)

  describe("list", function()
    it("returns list of available platforms", function()
      local platforms = PlatformFactory.list()
      assert.is_table(platforms)
      assert.is_true(#platforms > 0)

      -- Should include mock/test
      local has_mock = false
      for _, name in ipairs(platforms) do
        if name == "mock" then has_mock = true end
      end
      assert.is_true(has_mock)
    end)

    it("includes custom platforms", function()
      PlatformFactory.register("my_platform", {
        new = function() return {} end
      })

      local platforms = PlatformFactory.list()
      local found = false
      for _, name in ipairs(platforms) do
        if name == "my_platform" then found = true end
      end
      assert.is_true(found)

      PlatformFactory.unregister("my_platform")
    end)
  end)

  describe("is_available", function()
    it("returns true for mock platform", function()
      assert.is_true(PlatformFactory.is_available("mock"))
    end)

    it("returns false for unknown platform", function()
      assert.is_false(PlatformFactory.is_available("nonexistent"))
    end)

    it("returns true for registered custom platform", function()
      PlatformFactory.register("available", {new = function() return {} end})
      assert.is_true(PlatformFactory.is_available("available"))
      PlatformFactory.unregister("available")
    end)
  end)

  describe("get (singleton)", function()
    it("returns singleton instance", function()
      local p1 = PlatformFactory.get()
      local p2 = PlatformFactory.get()
      assert.equals(p1, p2)
    end)

    it("creates new instance when forced", function()
      local p1 = PlatformFactory.get()
      local p2 = PlatformFactory.get(true)  -- force new
      assert.is_not_nil(p2)
      -- p1 and p2 are now both set to the new instance
    end)
  end)

  describe("set", function()
    it("allows setting custom singleton", function()
      local custom = {
        get_name = function() return "injected" end,
      }

      PlatformFactory.set(custom)
      local platform = PlatformFactory.get()
      assert.equals("injected", platform:get_name())
    end)
  end)

  describe("reset", function()
    it("clears singleton", function()
      local p1 = PlatformFactory.get()
      PlatformFactory.reset()
      local p2 = PlatformFactory.get()

      -- After reset, a new instance is created
      -- They might be equal in value but are different instances
      assert.is_not_nil(p1)
      assert.is_not_nil(p2)
    end)
  end)
end)
