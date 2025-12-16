-- spec/kernel/registry_spec.lua
-- Tests for whisker kernel module registry

describe("Registry", function()
  local Registry, Errors, registry

  before_each(function()
    package.loaded["whisker.kernel.registry"] = nil
    package.loaded["whisker.kernel.errors"] = nil
    Errors = require("whisker.kernel.errors")
    Registry = require("whisker.kernel.registry")
    registry = Registry.new(Errors)
  end)

  describe("register", function()
    it("should register a module", function()
      local mod = { name = "test" }
      assert.is_true(registry:register("test", mod))
      assert.are.equal(mod, registry:get("test"))
    end)

    it("should support namespaced names", function()
      local mod = { name = "json" }
      assert.is_true(registry:register("format.json", mod))
      assert.are.equal(mod, registry:get("format.json"))
    end)

    it("should reject empty name", function()
      assert.has_error(function()
        registry:register("", {})
      end)
    end)

    it("should reject nil name", function()
      assert.has_error(function()
        registry:register(nil, {})
      end)
    end)

    it("should reject nil module", function()
      assert.has_error(function()
        registry:register("test", nil)
      end)
    end)

    it("should reject duplicate registration", function()
      registry:register("test", {})
      assert.has_error(function()
        registry:register("test", {})
      end)
    end)
  end)

  describe("unregister", function()
    it("should unregister a module", function()
      registry:register("test", {})
      assert.is_true(registry:unregister("test"))
      assert.is_nil(registry:get("test"))
    end)

    it("should return false for non-existent module", function()
      assert.is_false(registry:unregister("nonexistent"))
    end)
  end)

  describe("get", function()
    it("should return registered module", function()
      local mod = { name = "test" }
      registry:register("test", mod)
      assert.are.equal(mod, registry:get("test"))
    end)

    it("should return nil for non-existent module", function()
      assert.is_nil(registry:get("nonexistent"))
    end)
  end)

  describe("has", function()
    it("should return true for registered module", function()
      registry:register("test", {})
      assert.is_true(registry:has("test"))
    end)

    it("should return false for non-existent module", function()
      assert.is_false(registry:has("nonexistent"))
    end)
  end)

  describe("list", function()
    it("should return empty list when no modules", function()
      assert.are.same({}, registry:list())
    end)

    it("should return sorted list of module names", function()
      registry:register("zebra", {})
      registry:register("alpha", {})
      registry:register("middle", {})
      assert.are.same({"alpha", "middle", "zebra"}, registry:list())
    end)
  end)

  describe("count", function()
    it("should return 0 when empty", function()
      assert.are.equal(0, registry:count())
    end)

    it("should return correct count", function()
      registry:register("a", {})
      registry:register("b", {})
      registry:register("c", {})
      assert.are.equal(3, registry:count())
    end)
  end)

  describe("clear", function()
    it("should remove all modules", function()
      registry:register("a", {})
      registry:register("b", {})
      registry:clear()
      assert.are.equal(0, registry:count())
    end)
  end)
end)

describe("Capabilities", function()
  local Capabilities, caps

  before_each(function()
    package.loaded["whisker.kernel.capabilities"] = nil
    Capabilities = require("whisker.kernel.capabilities")
    caps = Capabilities.new()
  end)

  describe("register", function()
    it("should register capability as enabled by default", function()
      caps:register("test")
      assert.is_true(caps:has("test"))
    end)

    it("should register capability with explicit state", function()
      caps:register("disabled", false)
      assert.is_false(caps:has("disabled"))
    end)
  end)

  describe("has", function()
    it("should return false for unregistered capability", function()
      assert.is_false(caps:has("nonexistent"))
    end)

    it("should return true for enabled capability", function()
      caps:register("test", true)
      assert.is_true(caps:has("test"))
    end)

    it("should return false for disabled capability", function()
      caps:register("test", false)
      assert.is_false(caps:has("test"))
    end)
  end)

  describe("enable/disable", function()
    it("should enable a disabled capability", function()
      caps:register("test", false)
      caps:enable("test")
      assert.is_true(caps:has("test"))
    end)

    it("should disable an enabled capability", function()
      caps:register("test", true)
      caps:disable("test")
      assert.is_false(caps:has("test"))
    end)

    it("should return false for non-existent capability", function()
      assert.is_false(caps:enable("nonexistent"))
      assert.is_false(caps:disable("nonexistent"))
    end)
  end)

  describe("list", function()
    it("should return all capabilities with state", function()
      caps:register("a", true)
      caps:register("b", false)
      local list = caps:list()
      assert.are.equal(2, #list)
      assert.are.equal("a", list[1].name)
      assert.is_true(list[1].enabled)
      assert.are.equal("b", list[2].name)
      assert.is_false(list[2].enabled)
    end)
  end)

  describe("list_enabled", function()
    it("should return only enabled capabilities", function()
      caps:register("enabled1", true)
      caps:register("disabled", false)
      caps:register("enabled2", true)
      local enabled = caps:list_enabled()
      assert.are.same({"enabled1", "enabled2"}, enabled)
    end)
  end)
end)
