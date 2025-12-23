--- MockPlatform Tests
--- Tests for the mock/test platform implementation.

describe("MockPlatform", function()
  local MockPlatform
  local IPlatform

  before_each(function()
    package.loaded["whisker.platform.mock"] = nil
    package.loaded["whisker.platform.interface"] = nil
    package.loaded["whisker.platform.serialization"] = nil
    MockPlatform = require("whisker.platform.mock")
    IPlatform = require("whisker.platform.interface")
  end)

  describe("new", function()
    it("creates an instance with default configuration", function()
      local platform = MockPlatform.new()
      assert.is_not_nil(platform)
      assert.equals("mock", platform:get_name())
    end)

    it("accepts custom locale", function()
      local platform = MockPlatform.new({locale = "fr-FR"})
      assert.equals("fr-FR", platform:get_locale())
    end)

    it("accepts pre-populated storage", function()
      local platform = MockPlatform.new({
        storage = {
          test_key = '{"value":123}'
        }
      })
      local data = platform:load("test_key")
      assert.is_not_nil(data)
      assert.equals(123, data.value)
    end)

    it("accepts custom capabilities", function()
      local platform = MockPlatform.new({
        capabilities = {
          custom_cap = true,
          touch = false,
        }
      })
      assert.is_true(platform:has_capability("custom_cap"))
      assert.is_false(platform:has_capability("touch"))
    end)
  end)

  describe("IPlatform conformance", function()
    it("passes interface validation", function()
      local platform = MockPlatform.new()
      local valid, err = IPlatform.validate(platform)
      assert.is_true(valid)
    end)

    it("passes conformance testing", function()
      local platform = MockPlatform.new()
      local passed, results = IPlatform.test_conformance(platform)
      assert.is_true(passed)
    end)
  end)

  describe("save", function()
    it("saves data successfully", function()
      local platform = MockPlatform.new()
      local result = platform:save("test", {foo = "bar"})
      assert.is_true(result)
    end)

    it("rejects empty key", function()
      local platform = MockPlatform.new()
      local result = platform:save("", {foo = "bar"})
      assert.is_false(result)
    end)

    it("rejects non-string key", function()
      local platform = MockPlatform.new()
      local result = platform:save(123, {foo = "bar"})
      assert.is_false(result)
    end)

    it("rejects non-serializable data", function()
      local platform = MockPlatform.new()
      -- Functions can't be serialized
      local result = platform:save("test", {fn = function() end})
      -- Should still succeed after filtering
      assert.is_true(result)
    end)

    it("can be configured to fail", function()
      local platform = MockPlatform.new()
      platform:set_failures(true, false)
      local result = platform:save("test", {foo = "bar"})
      assert.is_false(result)
    end)

    it("increments save count", function()
      local platform = MockPlatform.new()
      platform:save("key1", {})
      platform:save("key2", {})
      local stats = platform:get_stats()
      assert.equals(2, stats.save_count)
    end)
  end)

  describe("load", function()
    it("loads previously saved data", function()
      local platform = MockPlatform.new()
      platform:save("test", {foo = "bar", num = 42})
      local data = platform:load("test")
      assert.is_not_nil(data)
      assert.equals("bar", data.foo)
      assert.equals(42, data.num)
    end)

    it("returns nil for non-existent key", function()
      local platform = MockPlatform.new()
      local data = platform:load("nonexistent")
      assert.is_nil(data)
    end)

    it("returns nil for empty key", function()
      local platform = MockPlatform.new()
      local data = platform:load("")
      assert.is_nil(data)
    end)

    it("can be configured to fail", function()
      local platform = MockPlatform.new()
      platform:save("test", {foo = "bar"})
      platform:set_failures(false, true)
      local data = platform:load("test")
      assert.is_nil(data)
    end)

    it("increments load count", function()
      local platform = MockPlatform.new()
      platform:load("key1")
      platform:load("key2")
      local stats = platform:get_stats()
      assert.equals(2, stats.load_count)
    end)
  end)

  describe("delete", function()
    it("deletes existing data", function()
      local platform = MockPlatform.new()
      platform:save("test", {foo = "bar"})
      assert.is_true(platform:has_key("test"))

      local result = platform:delete("test")
      assert.is_true(result)
      assert.is_false(platform:has_key("test"))
    end)

    it("succeeds for non-existent key", function()
      local platform = MockPlatform.new()
      local result = platform:delete("nonexistent")
      assert.is_true(result)
    end)

    it("increments delete count", function()
      local platform = MockPlatform.new()
      platform:delete("key1")
      platform:delete("key2")
      local stats = platform:get_stats()
      assert.equals(2, stats.delete_count)
    end)
  end)

  describe("get_locale", function()
    it("returns default locale", function()
      local platform = MockPlatform.new()
      local locale = platform:get_locale()
      assert.equals("en-US", locale)
    end)

    it("returns configured locale", function()
      local platform = MockPlatform.new({locale = "ja-JP"})
      local locale = platform:get_locale()
      assert.equals("ja-JP", locale)
    end)

    it("can be changed at runtime", function()
      local platform = MockPlatform.new()
      platform:set_locale("de-DE")
      assert.equals("de-DE", platform:get_locale())
    end)

    it("increments locale check count", function()
      local platform = MockPlatform.new()
      platform:get_locale()
      platform:get_locale()
      local stats = platform:get_stats()
      assert.equals(2, stats.locale_checks)
    end)
  end)

  describe("has_capability", function()
    it("returns true for default capabilities", function()
      local platform = MockPlatform.new()
      assert.is_true(platform:has_capability(IPlatform.CAPABILITIES.PERSISTENT_STORAGE))
      assert.is_true(platform:has_capability(IPlatform.CAPABILITIES.TOUCH))
      assert.is_true(platform:has_capability(IPlatform.CAPABILITIES.KEYBOARD))
    end)

    it("returns false for unsupported capabilities", function()
      local platform = MockPlatform.new()
      assert.is_false(platform:has_capability(IPlatform.CAPABILITIES.GAMEPAD))
      assert.is_false(platform:has_capability(IPlatform.CAPABILITIES.CAMERA))
    end)

    it("returns false for unknown capabilities", function()
      local platform = MockPlatform.new()
      assert.is_false(platform:has_capability("unknown_cap"))
    end)

    it("can be changed at runtime", function()
      local platform = MockPlatform.new()
      assert.is_true(platform:has_capability("touch"))

      platform:set_capability("touch", false)
      assert.is_false(platform:has_capability("touch"))
    end)

    it("increments capability check count", function()
      local platform = MockPlatform.new()
      platform:has_capability("touch")
      platform:has_capability("keyboard")
      local stats = platform:get_stats()
      assert.equals(2, stats.capability_checks)
    end)
  end)

  describe("get_name", function()
    it("returns 'mock'", function()
      local platform = MockPlatform.new()
      assert.equals("mock", platform:get_name())
    end)
  end)

  describe("test helpers", function()
    it("clears storage", function()
      local platform = MockPlatform.new()
      platform:save("key1", {})
      platform:save("key2", {})
      assert.equals(2, #platform:get_keys())

      platform:clear_storage()
      assert.equals(0, #platform:get_keys())
    end)

    it("resets stats", function()
      local platform = MockPlatform.new()
      platform:save("key", {})
      platform:load("key")

      platform:reset_stats()
      local stats = platform:get_stats()
      assert.equals(0, stats.save_count)
      assert.equals(0, stats.load_count)
    end)

    it("lists all keys", function()
      local platform = MockPlatform.new()
      platform:save("alpha", {})
      platform:save("beta", {})
      platform:save("gamma", {})

      local keys = platform:get_keys()
      assert.equals(3, #keys)
      -- Keys are sorted
      assert.equals("alpha", keys[1])
      assert.equals("beta", keys[2])
      assert.equals("gamma", keys[3])
    end)
  end)

  describe("complex data", function()
    it("handles nested tables", function()
      local platform = MockPlatform.new()
      local data = {
        level1 = {
          level2 = {
            level3 = "deep value"
          }
        }
      }
      platform:save("nested", data)
      local loaded = platform:load("nested")
      assert.equals("deep value", loaded.level1.level2.level3)
    end)

    it("handles arrays", function()
      local platform = MockPlatform.new()
      local data = {
        items = {1, 2, 3, 4, 5}
      }
      platform:save("array", data)
      local loaded = platform:load("array")
      assert.equals(5, #loaded.items)
      assert.equals(3, loaded.items[3])
    end)

    it("handles mixed types", function()
      local platform = MockPlatform.new()
      local data = {
        str = "hello",
        num = 42,
        float = 3.14,
        bool = true,
        arr = {1, 2, 3},
        obj = {nested = true}
      }
      platform:save("mixed", data)
      local loaded = platform:load("mixed")
      assert.equals("hello", loaded.str)
      assert.equals(42, loaded.num)
      assert.equals(3.14, loaded.float)
      assert.is_true(loaded.bool)
      assert.equals(3, #loaded.arr)
      assert.is_true(loaded.obj.nested)
    end)
  end)
end)
