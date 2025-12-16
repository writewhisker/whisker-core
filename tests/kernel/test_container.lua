-- tests/kernel/test_container.lua
-- Tests for DI Container

describe("Container", function()
  local Container

  before_each(function()
    package.loaded["whisker.kernel.container"] = nil
    Container = require("whisker.kernel.container")
  end)

  describe("new", function()
    it("should create a new container", function()
      local container = Container.new()
      assert.is_not_nil(container)
    end)

    it("should accept options", function()
      local interfaces = { get = function() end, validate = function() end }
      local capabilities = { register = function() end }
      local container = Container.new({
        interfaces = interfaces,
        capabilities = capabilities
      })
      assert.is_not_nil(container)
    end)
  end)

  describe("register", function()
    it("should register a factory function", function()
      local container = Container.new()
      container:register("test", function() return { name = "test" } end)
      assert.is_true(container:has("test"))
    end)

    it("should register a module table directly", function()
      local container = Container.new()
      local module = { name = "direct" }
      container:register("direct", module)
      assert.is_true(container:has("direct"))
    end)

    it("should reject duplicate registration", function()
      local container = Container.new()
      container:register("test", function() end)
      assert.has_error(function()
        container:register("test", function() end)
      end)
    end)

    it("should reject nil factory", function()
      local container = Container.new()
      assert.has_error(function()
        container:register("test", nil)
      end)
    end)

    it("should allow chaining", function()
      local container = Container.new()
      local result = container:register("a", function() end)
      assert.are.equal(container, result)
    end)
  end)

  describe("resolve", function()
    it("should resolve a registered component", function()
      local container = Container.new()
      container:register("test", function() return { value = 42 } end)
      local instance = container:resolve("test")
      assert.are.equal(42, instance.value)
    end)

    it("should resolve a module table directly", function()
      local container = Container.new()
      local module = { value = 99 }
      container:register("module", module)
      local instance = container:resolve("module")
      assert.are.equal(99, instance.value)
    end)

    it("should error for unknown component", function()
      local container = Container.new()
      assert.has_error(function()
        container:resolve("unknown")
      end)
    end)

    it("should pass args to factory", function()
      local container = Container.new()
      container:register("test", function(deps, args)
        return { value = args.value }
      end)
      local instance = container:resolve("test", { value = 123 })
      assert.are.equal(123, instance.value)
    end)
  end)

  describe("singleton", function()
    it("should return same instance for singleton", function()
      local container = Container.new()
      local call_count = 0
      container:register("singleton", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true })

      local a = container:resolve("singleton")
      local b = container:resolve("singleton")
      assert.are.equal(a, b)
      assert.are.equal(1, call_count)
    end)

    it("should return new instance for transient", function()
      local container = Container.new()
      local call_count = 0
      container:register("transient", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = false })

      local a = container:resolve("transient")
      local b = container:resolve("transient")
      assert.are_not.equal(a, b)
      assert.are.equal(2, call_count)
    end)
  end)

  describe("dependencies", function()
    it("should inject dependencies", function()
      local container = Container.new()
      container:register("dep1", function() return { name = "dep1" } end)
      container:register("dep2", function() return { name = "dep2" } end)
      container:register("main", function(deps)
        return {
          d1 = deps.dep1,
          d2 = deps.dep2
        }
      end, { depends = {"dep1", "dep2"} })

      local instance = container:resolve("main")
      assert.are.equal("dep1", instance.d1.name)
      assert.are.equal("dep2", instance.d2.name)
    end)

    it("should resolve nested dependencies", function()
      local container = Container.new()
      container:register("level1", function() return { level = 1 } end)
      container:register("level2", function(deps)
        return { level = 2, child = deps.level1 }
      end, { depends = {"level1"} })
      container:register("level3", function(deps)
        return { level = 3, child = deps.level2 }
      end, { depends = {"level2"} })

      local instance = container:resolve("level3")
      assert.are.equal(3, instance.level)
      assert.are.equal(2, instance.child.level)
      assert.are.equal(1, instance.child.child.level)
    end)

    it("should detect circular dependencies", function()
      local container = Container.new()
      container:register("a", function(deps) return deps end, { depends = {"b"} })
      container:register("b", function(deps) return deps end, { depends = {"a"} })

      assert.has_error(function()
        container:resolve("a")
      end)
    end)

    it("should detect self-referential dependency", function()
      local container = Container.new()
      container:register("self", function(deps) return deps end, { depends = {"self"} })

      assert.has_error(function()
        container:resolve("self")
      end)
    end)
  end)

  describe("interface validation", function()
    it("should validate against interface on resolution", function()
      local mock_interfaces = {
        get = function(name)
          if name == "ITest" then
            return { _name = "ITest", _required = {"method1"} }
          end
        end,
        validate = function(obj, interface)
          if obj.method1 then return true, {} end
          return false, {"Missing method1"}
        end
      }

      local container = Container.new({ interfaces = mock_interfaces })
      container:register("good", function()
        return { method1 = function() end }
      end, { implements = "ITest" })
      container:register("bad", function()
        return {}
      end, { implements = "ITest" })

      -- Good should resolve
      assert.is_not_nil(container:resolve("good"))

      -- Bad should fail validation
      assert.has_error(function()
        container:resolve("bad")
      end)
    end)
  end)

  describe("capability registration", function()
    it("should register capability on resolution", function()
      local registered = {}
      local mock_capabilities = {
        register = function(self, name, enabled)
          registered[name] = enabled
        end
      }

      local container = Container.new({ capabilities = mock_capabilities })
      container:register("feature", function() return {} end, {
        singleton = true,
        capability = "my_feature"
      })

      container:resolve("feature")
      assert.is_true(registered.my_feature)
    end)
  end)

  describe("lifecycle", function()
    it("should call init method after creation", function()
      local container = Container.new()
      local init_called = false
      container:register("service", function()
        return {
          startup = function(self, c)
            init_called = true
            assert.are.equal(container, c)
          end
        }
      end, { init = "startup" })

      container:resolve("service")
      assert.is_true(init_called)
    end)

    it("should call destroy method on container destroy", function()
      local container = Container.new()
      local destroy_called = false
      container:register("service", function()
        return {
          cleanup = function(self)
            destroy_called = true
          end
        }
      end, { singleton = true, destroy = "cleanup" })

      container:resolve("service")
      assert.is_false(destroy_called)

      container:destroy()
      assert.is_true(destroy_called)
    end)

    it("should only destroy resolved singletons", function()
      local container = Container.new()
      local destroy_count = 0
      container:register("a", function()
        return { cleanup = function() destroy_count = destroy_count + 1 end }
      end, { singleton = true, destroy = "cleanup" })
      container:register("b", function()
        return { cleanup = function() destroy_count = destroy_count + 1 end }
      end, { singleton = true, destroy = "cleanup" })

      container:resolve("a")
      container:destroy()
      assert.are.equal(1, destroy_count)  -- Only "a" was resolved
    end)
  end)

  describe("resolve_interface", function()
    it("should resolve first component implementing interface", function()
      local container = Container.new()
      container:register("impl1", function()
        return { name = "first" }
      end, { implements = "IService" })

      local instance = container:resolve_interface("IService")
      assert.are.equal("first", instance.name)
    end)

    it("should error if no implementation found", function()
      local container = Container.new()
      assert.has_error(function()
        container:resolve_interface("IUnknown")
      end)
    end)
  end)

  describe("resolve_all", function()
    it("should resolve all implementations of interface", function()
      local container = Container.new()
      container:register("impl1", function() return { id = 1 } end, { implements = "IPlugin" })
      container:register("impl2", function() return { id = 2 } end, { implements = "IPlugin" })
      container:register("other", function() return { id = 3 } end, { implements = "IOther" })

      local plugins = container:resolve_all("IPlugin")
      assert.are.equal(2, #plugins)
    end)

    it("should return empty table if no implementations", function()
      local container = Container.new()
      local results = container:resolve_all("INothing")
      assert.are.same({}, results)
    end)
  end)

  describe("list", function()
    it("should return sorted list of component names", function()
      local container = Container.new()
      container:register("zebra", function() end)
      container:register("alpha", function() end)
      container:register("beta", function() end)

      local names = container:list()
      assert.are.same({"alpha", "beta", "zebra"}, names)
    end)
  end)

  describe("clear", function()
    it("should remove all registrations", function()
      local container = Container.new()
      container:register("test", function() return {} end)
      assert.is_true(container:has("test"))

      container:clear()
      assert.is_false(container:has("test"))
    end)

    it("should call destroy before clearing", function()
      local container = Container.new()
      local destroyed = false
      container:register("test", function()
        return { cleanup = function() destroyed = true end }
      end, { singleton = true, destroy = "cleanup" })

      container:resolve("test")
      container:clear()
      assert.is_true(destroyed)
    end)
  end)

  describe("get_registration", function()
    it("should return registration info", function()
      local container = Container.new()
      container:register("test", function() end, {
        singleton = true,
        implements = "ITest",
        depends = {"dep1"}
      })

      local reg = container:get_registration("test")
      assert.is_true(reg.singleton)
      assert.are.equal("ITest", reg.implements)
      assert.are.same({"dep1"}, reg.depends)
    end)

    it("should return nil for unknown component", function()
      local container = Container.new()
      assert.is_nil(container:get_registration("unknown"))
    end)
  end)
end)
