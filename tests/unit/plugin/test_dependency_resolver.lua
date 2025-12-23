--- Dependency Resolver Tests
-- @module tests.unit.plugin.dependency_resolver_spec

describe("DependencyResolver", function()
  local DependencyResolver

  before_each(function()
    package.loaded["whisker.plugin.dependency_resolver"] = nil
    DependencyResolver = require("whisker.plugin.dependency_resolver")
  end)

  describe("Version parsing", function()
    it("should parse valid semantic versions", function()
      local v = DependencyResolver.parse_version("1.2.3")
      assert.is_table(v)
      assert.equals(1, v.major)
      assert.equals(2, v.minor)
      assert.equals(3, v.patch)
    end)

    it("should parse versions with leading zeros", function()
      local v = DependencyResolver.parse_version("0.1.0")
      assert.equals(0, v.major)
      assert.equals(1, v.minor)
      assert.equals(0, v.patch)
    end)

    it("should return nil for invalid versions", function()
      assert.is_nil(DependencyResolver.parse_version("1.2"))
      assert.is_nil(DependencyResolver.parse_version("invalid"))
      assert.is_nil(DependencyResolver.parse_version(nil))
    end)
  end)

  describe("Version comparison", function()
    it("should compare major versions", function()
      local v1 = {major = 2, minor = 0, patch = 0}
      local v2 = {major = 1, minor = 0, patch = 0}
      assert.equals(1, DependencyResolver.compare_versions(v1, v2))
      assert.equals(-1, DependencyResolver.compare_versions(v2, v1))
    end)

    it("should compare minor versions", function()
      local v1 = {major = 1, minor = 2, patch = 0}
      local v2 = {major = 1, minor = 1, patch = 0}
      assert.equals(1, DependencyResolver.compare_versions(v1, v2))
    end)

    it("should compare patch versions", function()
      local v1 = {major = 1, minor = 1, patch = 2}
      local v2 = {major = 1, minor = 1, patch = 1}
      assert.equals(1, DependencyResolver.compare_versions(v1, v2))
    end)

    it("should return 0 for equal versions", function()
      local v1 = {major = 1, minor = 2, patch = 3}
      local v2 = {major = 1, minor = 2, patch = 3}
      assert.equals(0, DependencyResolver.compare_versions(v1, v2))
    end)
  end)

  describe("Version constraint satisfaction", function()
    it("should satisfy exact version match", function()
      assert.is_true(DependencyResolver.satisfies("1.2.3", "1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.4", "1.2.3"))
    end)

    it("should satisfy wildcard constraint", function()
      assert.is_true(DependencyResolver.satisfies("1.0.0", "*"))
      assert.is_true(DependencyResolver.satisfies("99.99.99", "*"))
    end)

    it("should satisfy caret constraint", function()
      -- ^1.2.3 means >=1.2.3 <2.0.0
      assert.is_true(DependencyResolver.satisfies("1.2.3", "^1.2.3"))
      assert.is_true(DependencyResolver.satisfies("1.5.0", "^1.2.3"))
      assert.is_true(DependencyResolver.satisfies("1.99.99", "^1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.2", "^1.2.3"))
      assert.is_false(DependencyResolver.satisfies("2.0.0", "^1.2.3"))
    end)

    it("should satisfy tilde constraint", function()
      -- ~1.2.3 means >=1.2.3 <1.3.0
      assert.is_true(DependencyResolver.satisfies("1.2.3", "~1.2.3"))
      assert.is_true(DependencyResolver.satisfies("1.2.9", "~1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.2", "~1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.3.0", "~1.2.3"))
    end)

    it("should satisfy >= constraint", function()
      assert.is_true(DependencyResolver.satisfies("1.2.3", ">=1.2.3"))
      assert.is_true(DependencyResolver.satisfies("2.0.0", ">=1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.2", ">=1.2.3"))
    end)

    it("should satisfy > constraint", function()
      assert.is_true(DependencyResolver.satisfies("1.2.4", ">1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.3", ">1.2.3"))
    end)

    it("should satisfy <= constraint", function()
      assert.is_true(DependencyResolver.satisfies("1.2.3", "<=1.2.3"))
      assert.is_true(DependencyResolver.satisfies("1.0.0", "<=1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.4", "<=1.2.3"))
    end)

    it("should satisfy < constraint", function()
      assert.is_true(DependencyResolver.satisfies("1.2.2", "<1.2.3"))
      assert.is_false(DependencyResolver.satisfies("1.2.3", "<1.2.3"))
    end)
  end)

  describe("Dependency resolution", function()
    it("should resolve empty plugin list", function()
      local result, err = DependencyResolver.resolve({})
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("should resolve single plugin without dependencies", function()
      local plugins = {
        {name = "plugin-a", version = "1.0.0", definition = {}},
      }
      local result, err = DependencyResolver.resolve(plugins)
      assert.is_table(result)
      assert.equals(1, #result)
      assert.equals("plugin-a", result[1].name)
    end)

    it("should order plugins by dependencies", function()
      local plugins = {
        {
          name = "plugin-a",
          version = "1.0.0",
          definition = {dependencies = {["plugin-b"] = "^1.0.0"}},
        },
        {
          name = "plugin-b",
          version = "1.0.0",
          definition = {},
        },
      }

      local result, err = DependencyResolver.resolve(plugins)
      assert.is_table(result)
      assert.equals(2, #result)
      -- plugin-b should come first (no deps), then plugin-a
      assert.equals("plugin-b", result[1].name)
      assert.equals("plugin-a", result[2].name)
    end)

    it("should detect missing dependencies", function()
      local plugins = {
        {
          name = "plugin-a",
          version = "1.0.0",
          definition = {dependencies = {["missing-plugin"] = "^1.0.0"}},
        },
      }

      local result, err = DependencyResolver.resolve(plugins)
      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("missing plugin"))
    end)

    it("should detect circular dependencies", function()
      local plugins = {
        {
          name = "plugin-a",
          version = "1.0.0",
          definition = {dependencies = {["plugin-b"] = "^1.0.0"}},
        },
        {
          name = "plugin-b",
          version = "1.0.0",
          definition = {dependencies = {["plugin-a"] = "^1.0.0"}},
        },
      }

      local result, err = DependencyResolver.resolve(plugins)
      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("Circular dependency"))
    end)

    it("should detect version constraint violations", function()
      local plugins = {
        {
          name = "plugin-a",
          version = "1.0.0",
          definition = {dependencies = {["plugin-b"] = "^2.0.0"}},
        },
        {
          name = "plugin-b",
          version = "1.0.0",
          definition = {},
        },
      }

      local result, err = DependencyResolver.resolve(plugins)
      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("requires"))
    end)

    it("should resolve complex dependency graph", function()
      local plugins = {
        {
          name = "plugin-a",
          version = "1.0.0",
          definition = {dependencies = {["plugin-b"] = "^1.0.0", ["plugin-c"] = "^1.0.0"}},
        },
        {
          name = "plugin-b",
          version = "1.0.0",
          definition = {dependencies = {["plugin-d"] = "^1.0.0"}},
        },
        {
          name = "plugin-c",
          version = "1.0.0",
          definition = {dependencies = {["plugin-d"] = "^1.0.0"}},
        },
        {
          name = "plugin-d",
          version = "1.0.0",
          definition = {},
        },
      }

      local result, err = DependencyResolver.resolve(plugins)
      assert.is_table(result)
      assert.equals(4, #result)
      -- plugin-d must come first, then b and c, then a
      assert.equals("plugin-d", result[1].name)
      assert.equals("plugin-a", result[4].name)
    end)
  end)

  describe("Helper functions", function()
    it("should reverse order for destruction", function()
      local plugins = {
        {name = "a"},
        {name = "b"},
        {name = "c"},
      }
      local reversed = DependencyResolver.reverse_order(plugins)
      assert.equals("c", reversed[1].name)
      assert.equals("b", reversed[2].name)
      assert.equals("a", reversed[3].name)
    end)

    it("should find dependents of a plugin", function()
      local plugins = {
        {
          name = "plugin-a",
          definition = {dependencies = {["plugin-c"] = "^1.0.0"}},
        },
        {
          name = "plugin-b",
          definition = {dependencies = {["plugin-c"] = "^1.0.0"}},
        },
        {
          name = "plugin-c",
          definition = {},
        },
      }

      local dependents = DependencyResolver.get_dependents(plugins, "plugin-c")
      assert.equals(2, #dependents)
    end)

    it("should get all transitive dependencies", function()
      local plugins = {
        {
          name = "plugin-a",
          definition = {dependencies = {["plugin-b"] = "^1.0.0"}},
        },
        {
          name = "plugin-b",
          definition = {dependencies = {["plugin-c"] = "^1.0.0"}},
        },
        {
          name = "plugin-c",
          definition = {},
        },
      }

      local all_deps = DependencyResolver.get_all_dependencies(plugins, "plugin-a")
      assert.equals(2, #all_deps)
    end)
  end)

  describe("Cycle detection", function()
    it("should detect simple cycle", function()
      local graph = {
        a = {b = "1.0.0"},
        b = {a = "1.0.0"},
      }
      local has_cycle, cycle = DependencyResolver.detect_cycle(graph)
      assert.is_true(has_cycle)
      assert.is_table(cycle)
    end)

    it("should detect transitive cycle", function()
      local graph = {
        a = {b = "1.0.0"},
        b = {c = "1.0.0"},
        c = {a = "1.0.0"},
      }
      local has_cycle, cycle = DependencyResolver.detect_cycle(graph)
      assert.is_true(has_cycle)
    end)

    it("should not detect cycle in acyclic graph", function()
      local graph = {
        a = {b = "1.0.0"},
        b = {c = "1.0.0"},
        c = {},
      }
      local has_cycle, cycle = DependencyResolver.detect_cycle(graph)
      assert.is_false(has_cycle)
    end)
  end)
end)
