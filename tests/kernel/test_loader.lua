-- tests/kernel/test_loader.lua
-- Tests for Module Loader

describe("Loader", function()
  local Loader

  before_each(function()
    package.loaded["whisker.kernel.loader"] = nil
    Loader = require("whisker.kernel.loader")
  end)

  describe("new", function()
    it("should create a new loader", function()
      local loader = Loader.new()
      assert.is_not_nil(loader)
    end)

    it("should accept options", function()
      local container = { has = function() end, register = function() end }
      local capabilities = { register = function() end }
      local loader = Loader.new({
        container = container,
        capabilities = capabilities,
        base_path = "myapp"
      })
      assert.is_not_nil(loader)
    end)
  end)

  describe("load", function()
    it("should load a module by full path", function()
      local loader = Loader.new()
      local module = loader:load("whisker.kernel.errors")
      assert.is_not_nil(module)
      assert.is_not_nil(module.codes)
    end)

    it("should load a module with base path prefix", function()
      local loader = Loader.new({ base_path = "whisker" })
      local module = loader:load("kernel.errors")
      assert.is_not_nil(module)
    end)

    it("should cache loaded modules", function()
      local loader = Loader.new()
      local module1 = loader:load("whisker.kernel.errors")
      local module2 = loader:load("whisker.kernel.errors")
      assert.are.equal(module1, module2)
    end)

    it("should error for invalid path", function()
      local loader = Loader.new()
      assert.has_error(function()
        loader:load("")
      end)
    end)

    it("should error for non-existent module", function()
      local loader = Loader.new()
      assert.has_error(function()
        loader:load("whisker.nonexistent.module")
      end)
    end)
  end)

  describe("lazy", function()
    it("should return a proxy table", function()
      local loader = Loader.new()
      local proxy = loader:lazy("whisker.kernel.errors")
      assert.is_table(proxy)
    end)

    it("should load module on first access", function()
      local loader = Loader.new()
      local proxy = loader:lazy("whisker.kernel.errors")

      -- Module not yet in loaded list
      local loaded_before = loader:list_loaded()
      assert.are.equal(0, #loaded_before)

      -- Access triggers load
      local _ = proxy.codes
      local loaded_after = loader:list_loaded()
      assert.are.equal(1, #loaded_after)
    end)

    it("should return same proxy for same path", function()
      local loader = Loader.new()
      local proxy1 = loader:lazy("whisker.kernel.errors")
      local proxy2 = loader:lazy("whisker.kernel.errors")
      assert.are.equal(proxy1, proxy2)
    end)

    it("should allow calling proxy as function if module is callable", function()
      local loader = Loader.new()
      -- Container.new is a constructor
      local proxy = loader:lazy("whisker.kernel.container")
      local instance = proxy.new()
      assert.is_not_nil(instance)
    end)
  end)

  describe("exists", function()
    it("should return true for existing module", function()
      local loader = Loader.new()
      assert.is_true(loader:exists("whisker.kernel.errors"))
    end)

    it("should return true for loaded module", function()
      local loader = Loader.new()
      loader:load("whisker.kernel.errors")
      assert.is_true(loader:exists("whisker.kernel.errors"))
    end)

    it("should return false for non-existent module", function()
      local loader = Loader.new()
      assert.is_false(loader:exists("whisker.nonexistent.module"))
    end)

    it("should handle base path prefix", function()
      local loader = Loader.new({ base_path = "whisker" })
      assert.is_true(loader:exists("kernel.errors"))
    end)
  end)

  describe("list_loaded", function()
    it("should return empty list initially", function()
      local loader = Loader.new()
      assert.are.same({}, loader:list_loaded())
    end)

    it("should return sorted list of loaded modules", function()
      local loader = Loader.new()
      loader:load("whisker.kernel.registry")
      loader:load("whisker.kernel.errors")
      loader:load("whisker.kernel.capabilities")

      local list = loader:list_loaded()
      assert.are.equal(3, #list)
      assert.are.equal("whisker.kernel.capabilities", list[1])
      assert.are.equal("whisker.kernel.errors", list[2])
      assert.are.equal("whisker.kernel.registry", list[3])
    end)
  end)

  describe("unload", function()
    it("should remove module from cache", function()
      local loader = Loader.new()
      loader:load("whisker.kernel.errors")
      assert.are.equal(1, #loader:list_loaded())

      local result = loader:unload("whisker.kernel.errors")
      assert.is_true(result)
      assert.are.equal(0, #loader:list_loaded())
    end)

    it("should return false for non-loaded module", function()
      local loader = Loader.new()
      local result = loader:unload("whisker.nonexistent")
      assert.is_false(result)
    end)

    it("should handle base path prefix", function()
      local loader = Loader.new({ base_path = "whisker" })
      loader:load("kernel.errors")
      local result = loader:unload("kernel.errors")
      assert.is_true(result)
    end)
  end)

  describe("auto-registration", function()
    it("should register capability when module has _whisker.capability", function()
      local registered_capabilities = {}
      local mock_capabilities = {
        register = function(_, name, enabled)
          registered_capabilities[name] = enabled
        end
      }

      local loader = Loader.new({ capabilities = mock_capabilities })

      -- Create a test module with metadata
      local test_module = {
        _whisker = {
          capability = "test_capability"
        }
      }
      package.preload["whisker.test.auto_cap"] = function() return test_module end

      loader:load("whisker.test.auto_cap")
      assert.is_true(registered_capabilities.test_capability)

      -- Cleanup
      package.preload["whisker.test.auto_cap"] = nil
      package.loaded["whisker.test.auto_cap"] = nil
    end)

    it("should register with container when module has _whisker.name", function()
      local registered = {}
      local mock_container = {
        has = function() return false end,
        register = function(_, name, module, options)
          registered[name] = { module = module, options = options }
        end
      }

      local loader = Loader.new({ container = mock_container })

      -- Create a test module with metadata
      local test_module = {
        _whisker = {
          name = "test_service",
          singleton = true,
          implements = "ITest"
        }
      }
      package.preload["whisker.test.auto_reg"] = function() return test_module end

      loader:load("whisker.test.auto_reg")

      assert.is_not_nil(registered.test_service)
      assert.is_true(registered.test_service.options.singleton)
      assert.are.equal("ITest", registered.test_service.options.implements)

      -- Cleanup
      package.preload["whisker.test.auto_reg"] = nil
      package.loaded["whisker.test.auto_reg"] = nil
    end)

    it("should not re-register if already in container", function()
      local register_count = 0
      local mock_container = {
        has = function() return true end,  -- Already registered
        register = function()
          register_count = register_count + 1
        end
      }

      local loader = Loader.new({ container = mock_container })

      local test_module = {
        _whisker = { name = "existing" }
      }
      package.preload["whisker.test.existing"] = function() return test_module end

      loader:load("whisker.test.existing")
      assert.are.equal(0, register_count)

      -- Cleanup
      package.preload["whisker.test.existing"] = nil
      package.loaded["whisker.test.existing"] = nil
    end)
  end)

  describe("clear", function()
    it("should remove all loaded modules", function()
      local loader = Loader.new()
      loader:load("whisker.kernel.errors")
      loader:load("whisker.kernel.registry")

      loader:clear()

      assert.are.same({}, loader:list_loaded())
    end)

    it("should clear lazy proxies", function()
      local loader = Loader.new()
      local proxy1 = loader:lazy("whisker.kernel.errors")

      loader:clear()

      -- New proxy should be different
      local proxy2 = loader:lazy("whisker.kernel.errors")
      assert.are_not.equal(proxy1, proxy2)
    end)
  end)
end)
