-- spec/kernel/init_spec.lua
-- Tests for whisker kernel bootstrap and core functionality

describe("Kernel", function()
  local Kernel

  before_each(function()
    -- Fresh kernel for each test
    package.loaded["whisker.kernel"] = nil
    package.loaded["whisker.kernel.init"] = nil
    package.loaded["whisker.kernel.registry"] = nil
    package.loaded["whisker.kernel.capabilities"] = nil
    package.loaded["whisker.kernel.errors"] = nil
    Kernel = require("whisker.kernel.init")
    Kernel.reset()
  end)

  describe("bootstrap", function()
    it("should initialize the kernel", function()
      assert.is_false(Kernel.is_bootstrapped())
      Kernel.bootstrap()
      assert.is_true(Kernel.is_bootstrapped())
    end)

    it("should be idempotent", function()
      Kernel.bootstrap()
      local registry1 = Kernel.registry
      Kernel.bootstrap()
      assert.are.equal(registry1, Kernel.registry)
    end)

    it("should create registry subsystem", function()
      Kernel.bootstrap()
      assert.is_not_nil(Kernel.registry)
    end)

    it("should create capabilities subsystem", function()
      Kernel.bootstrap()
      assert.is_not_nil(Kernel.capabilities)
    end)

    it("should register kernel capability", function()
      Kernel.bootstrap()
      assert.is_true(Kernel.capabilities:has("kernel"))
    end)
  end)

  describe("version", function()
    it("should return version string", function()
      assert.is_string(Kernel.version())
      assert.matches("^%d+%.%d+%.%d+", Kernel.version())
    end)
  end)

  describe("reset", function()
    it("should reset kernel to initial state", function()
      Kernel.bootstrap()
      assert.is_true(Kernel.is_bootstrapped())
      Kernel.reset()
      assert.is_false(Kernel.is_bootstrapped())
      assert.is_nil(Kernel.registry)
    end)
  end)

  describe("convenience functions", function()
    it("should auto-bootstrap on register", function()
      assert.is_false(Kernel.is_bootstrapped())
      Kernel.register("test", {})
      assert.is_true(Kernel.is_bootstrapped())
    end)

    it("should register and get modules", function()
      local mod = { name = "test" }
      Kernel.register("test", mod)
      assert.are.equal(mod, Kernel.get("test"))
    end)

    it("should check module existence", function()
      assert.is_false(Kernel.has("test"))
      Kernel.register("test", {})
      assert.is_true(Kernel.has("test"))
    end)

    it("should return nil for non-existent module when not bootstrapped", function()
      assert.is_nil(Kernel.get("test"))
    end)

    it("should check capabilities", function()
      Kernel.bootstrap()
      assert.is_true(Kernel.has_capability("kernel"))
      assert.is_false(Kernel.has_capability("nonexistent"))
    end)

    it("should return false for capability check when not bootstrapped", function()
      assert.is_false(Kernel.has_capability("kernel"))
    end)
  end)
end)
