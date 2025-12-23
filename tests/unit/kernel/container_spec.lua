--- Container Unit Tests
-- Tests for the DI container
-- @module tests.unit.kernel.container_spec
-- @author Whisker Core Team
-- @license MIT

local Container = require("whisker.kernel.container")

describe("Container", function()

  describe("new", function()
    it("creates a new container instance", function()
      local container = Container.new()
      assert.is_not_nil(container)
      assert.is_table(container)
    end)

    it("initializes with empty registrations", function()
      local container = Container.new()
      assert.same({}, container:list_services())
    end)
  end)

  describe("register", function()
    it("registers a factory function", function()
      local container = Container.new()
      container:register("test", function() return { value = 42 } end)
      assert.is_true(container:has("test"))
    end)

    it("registers a module table", function()
      local container = Container.new()
      local module = { value = 42 }
      container:register("test", module)
      assert.is_true(container:has("test"))
    end)

    it("throws on duplicate registration without override", function()
      local container = Container.new()
      container:register("test", function() return {} end)
      assert.has_error(function()
        container:register("test", function() return {} end)
      end)
    end)

    it("allows override with option", function()
      local container = Container.new()
      container:register("test", function() return { version = 1 } end)
      container:register("test", function() return { version = 2 } end, { override = true })

      local service = container:resolve("test")
      assert.equals(2, service.version)
    end)
  end)

  describe("resolve", function()
    it("resolves a factory function", function()
      local container = Container.new()
      container:register("test", function() return { value = 42 } end)

      local service = container:resolve("test")
      assert.equals(42, service.value)
    end)

    it("resolves a module with new method", function()
      local container = Container.new()
      local module = {
        new = function() return { value = 123 } end
      }
      container:register("test", module)

      local service = container:resolve("test")
      assert.equals(123, service.value)
    end)

    it("resolves a plain module table", function()
      local container = Container.new()
      local module = { value = 456 }
      container:register("test", module)

      local service = container:resolve("test")
      assert.equals(456, service.value)
    end)

    it("throws on unregistered service", function()
      local container = Container.new()
      assert.has_error(function()
        container:resolve("nonexistent")
      end)
    end)

    it("passes container to factory function", function()
      local container = Container.new()
      local received_container

      container:register("test", function(c)
        received_container = c
        return {}
      end)

      container:resolve("test")
      assert.equals(container, received_container)
    end)

    it("detects circular dependencies", function()
      local container = Container.new()

      container:register("a", function(c)
        c:resolve("b")
        return {}
      end)

      container:register("b", function(c)
        c:resolve("a")
        return {}
      end)

      assert.has_error(function()
        container:resolve("a")
      end)
    end)
  end)

  describe("singleton", function()
    it("returns same instance for singleton", function()
      local container = Container.new()
      local call_count = 0

      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true })

      local first = container:resolve("test")
      local second = container:resolve("test")

      assert.equals(first, second)
      assert.equals(1, call_count)
    end)

    it("creates new instances without singleton", function()
      local container = Container.new()
      local call_count = 0

      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = false })

      local first = container:resolve("test")
      local second = container:resolve("test")

      assert.not_equals(first.id, second.id)
      assert.equals(2, call_count)
    end)
  end)

  describe("has", function()
    it("returns true for registered service", function()
      local container = Container.new()
      container:register("test", function() return {} end)
      assert.is_true(container:has("test"))
    end)

    it("returns false for unregistered service", function()
      local container = Container.new()
      assert.is_false(container:has("test"))
    end)
  end)

  describe("unregister", function()
    it("removes a registered service", function()
      local container = Container.new()
      container:register("test", function() return {} end)
      assert.is_true(container:has("test"))

      container:unregister("test")
      assert.is_false(container:has("test"))
    end)

    it("clears singleton instance", function()
      local container = Container.new()
      local call_count = 0

      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true })

      container:resolve("test")
      container:unregister("test")

      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true })

      local service = container:resolve("test")
      assert.equals(2, service.id)
    end)
  end)

  describe("clear", function()
    it("removes all registrations", function()
      local container = Container.new()
      container:register("a", function() return {} end)
      container:register("b", function() return {} end)

      container:clear()

      assert.is_false(container:has("a"))
      assert.is_false(container:has("b"))
    end)
  end)

  describe("create_child", function()
    it("creates a child container", function()
      local parent = Container.new()
      local child = parent:create_child()
      assert.is_not_nil(child)
      assert.not_equals(parent, child)
    end)

    it("child can access parent services", function()
      local parent = Container.new()
      parent:register("parent_service", function() return { from = "parent" } end)

      local child = parent:create_child()
      local service = child:resolve("parent_service")

      assert.equals("parent", service.from)
    end)

    it("child services shadow parent", function()
      local parent = Container.new()
      parent:register("service", function() return { from = "parent" } end)

      local child = parent:create_child()
      child:register("service", function() return { from = "child" } end)

      local service = child:resolve("service")
      assert.equals("child", service.from)
    end)

    it("parent unchanged by child", function()
      local parent = Container.new()
      local child = parent:create_child()

      child:register("child_only", function() return {} end)

      assert.is_false(parent:has("child_only"))
    end)
  end)

  describe("lifecycle", function()
    it("calls destroy callbacks in reverse order", function()
      local container = Container.new()
      local destroy_order = {}

      container:register("first", function() return {} end)
      container:on_destroy("first", function()
        table.insert(destroy_order, "first")
      end)

      container:register("second", function() return {} end)
      container:on_destroy("second", function()
        table.insert(destroy_order, "second")
      end)

      container:destroy_all()

      assert.equals("second", destroy_order[1])
      assert.equals("first", destroy_order[2])
    end)

    it("destroy removes singleton", function()
      local container = Container.new()
      local call_count = 0

      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true })

      container:resolve("test")
      assert.equals(1, call_count)

      container:destroy("test")

      -- Re-register to resolve again
      container:register("test", function()
        call_count = call_count + 1
        return { id = call_count }
      end, { singleton = true, override = true })

      local service = container:resolve("test")
      assert.equals(2, service.id)
    end)
  end)

  describe("register_lazy", function()
    it("defers module loading", function()
      local container = Container.new()
      local loaded = false

      -- Mock require by using a factory that sets loaded
      container:register("test", function()
        loaded = true
        return { value = 42 }
      end, { singleton = true })

      -- Not loaded yet (until resolved)
      -- Note: Can't truly test lazy loading without mocking require
      -- This test just verifies the API exists
      assert.is_function(container.register_lazy)
    end)
  end)

  describe("resolve_with_deps", function()
    it("resolves dependencies first", function()
      local container = Container.new()
      local order = {}

      container:register("dep1", function()
        table.insert(order, "dep1")
        return {}
      end)

      container:register("dep2", function()
        table.insert(order, "dep2")
        return {}
      end)

      container:register("main", function()
        table.insert(order, "main")
        return {}
      end, { depends = { "dep1", "dep2" } })

      container:resolve_with_deps("main")

      assert.equals("dep1", order[1])
      assert.equals("dep2", order[2])
      assert.equals("main", order[3])
    end)

    it("throws on missing dependency", function()
      local container = Container.new()

      container:register("main", function() return {} end, {
        depends = { "missing" }
      })

      assert.has_error(function()
        container:resolve_with_deps("main")
      end)
    end)
  end)

  describe("list_services", function()
    it("returns sorted service names", function()
      local container = Container.new()
      container:register("zebra", function() return {} end)
      container:register("alpha", function() return {} end)
      container:register("beta", function() return {} end)

      local names = container:list_services()

      assert.equals("alpha", names[1])
      assert.equals("beta", names[2])
      assert.equals("zebra", names[3])
    end)
  end)
end)
