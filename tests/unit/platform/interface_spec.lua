--- IPlatform Interface Tests
--- Tests for the platform interface contract and validation.

describe("IPlatform Interface", function()
  local IPlatform

  before_each(function()
    package.loaded["whisker.platform.interface"] = nil
    IPlatform = require("whisker.platform.interface")
  end)

  describe("CAPABILITIES", function()
    it("defines standard capability constants", function()
      assert.is_string(IPlatform.CAPABILITIES.PERSISTENT_STORAGE)
      assert.is_string(IPlatform.CAPABILITIES.FILESYSTEM)
      assert.is_string(IPlatform.CAPABILITIES.NETWORK)
      assert.is_string(IPlatform.CAPABILITIES.TOUCH)
      assert.is_string(IPlatform.CAPABILITIES.MOUSE)
      assert.is_string(IPlatform.CAPABILITIES.KEYBOARD)
      assert.is_string(IPlatform.CAPABILITIES.GAMEPAD)
      assert.is_string(IPlatform.CAPABILITIES.CLIPBOARD)
      assert.is_string(IPlatform.CAPABILITIES.NOTIFICATIONS)
      assert.is_string(IPlatform.CAPABILITIES.AUDIO)
      assert.is_string(IPlatform.CAPABILITIES.CAMERA)
      assert.is_string(IPlatform.CAPABILITIES.GEOLOCATION)
      assert.is_string(IPlatform.CAPABILITIES.VIBRATION)
    end)
  end)

  describe("PLATFORMS", function()
    it("defines standard platform constants", function()
      assert.equals("web", IPlatform.PLATFORMS.WEB)
      assert.equals("ios", IPlatform.PLATFORMS.IOS)
      assert.equals("android", IPlatform.PLATFORMS.ANDROID)
      assert.equals("electron", IPlatform.PLATFORMS.ELECTRON)
      assert.equals("mock", IPlatform.PLATFORMS.MOCK)
      assert.equals("test", IPlatform.PLATFORMS.TEST)
    end)
  end)

  describe("validate", function()
    it("rejects non-table objects", function()
      local valid, err = IPlatform.validate(nil)
      assert.is_false(valid)
      assert.is_string(err)

      valid, err = IPlatform.validate("string")
      assert.is_false(valid)

      valid, err = IPlatform.validate(123)
      assert.is_false(valid)
    end)

    it("rejects objects missing required methods", function()
      local valid, err = IPlatform.validate({})
      assert.is_false(valid)
      assert.matches("save", err)
    end)

    it("rejects objects with non-function methods", function()
      local obj = {
        save = "not a function",
        load = function() end,
        get_locale = function() end,
        has_capability = function() end,
      }
      local valid, err = IPlatform.validate(obj)
      assert.is_false(valid)
    end)

    it("accepts objects with all required methods", function()
      local obj = {
        save = function() return true end,
        load = function() return {} end,
        get_locale = function() return "en-US" end,
        has_capability = function() return true end,
      }
      local valid, err = IPlatform.validate(obj)
      assert.is_true(valid)
      assert.is_nil(err)
    end)
  end)

  describe("test_conformance", function()
    it("tests all interface methods", function()
      local obj = {
        save = function() return true end,
        load = function() return nil end,
        get_locale = function() return "en-US" end,
        has_capability = function() return true end,
        delete = function() return true end,
      }

      local passed, results = IPlatform.test_conformance(obj)
      assert.is_true(passed)
      assert.is_table(results)
      assert.equals(4, #results) -- save, load, get_locale, has_capability
    end)

    it("reports failures for broken implementations", function()
      local obj = {
        save = function() error("intentional error") end,
        load = function() return nil end,
        get_locale = function() return "en-US" end,
        has_capability = function() return true end,
      }

      local passed, results = IPlatform.test_conformance(obj)
      assert.is_false(passed)

      -- Find the save result
      local save_result
      for _, result in ipairs(results) do
        if result.method == "save" then
          save_result = result
          break
        end
      end
      assert.is_not_nil(save_result)
      assert.is_false(save_result.passed)
    end)

    it("validates get_locale returns a string", function()
      local obj = {
        save = function() return true end,
        load = function() return nil end,
        get_locale = function() return 123 end, -- Wrong type
        has_capability = function() return true end,
      }

      local passed, results = IPlatform.test_conformance(obj)
      assert.is_false(passed)
    end)

    it("validates has_capability returns a boolean", function()
      local obj = {
        save = function() return true end,
        load = function() return nil end,
        get_locale = function() return "en-US" end,
        has_capability = function() return "yes" end, -- Wrong type
      }

      local passed, results = IPlatform.test_conformance(obj)
      assert.is_false(passed)
    end)
  end)

  describe("abstract methods", function()
    it("raises error when calling abstract methods", function()
      local platform = IPlatform.new()

      assert.has_error(function()
        platform:save("key", {})
      end)

      assert.has_error(function()
        platform:load("key")
      end)

      assert.has_error(function()
        platform:get_locale()
      end)

      assert.has_error(function()
        platform:has_capability("touch")
      end)

      assert.has_error(function()
        platform:delete("key")
      end)

      assert.has_error(function()
        platform:get_name()
      end)
    end)
  end)
end)
