--- Built-in Loader Tests
-- @module tests.unit.plugin.builtin_loader_spec

describe("BuiltinLoader", function()
  local BuiltinLoader
  local loader
  local test_builtin_path

  before_each(function()
    package.loaded["whisker.plugin.builtin_loader"] = nil
    BuiltinLoader = require("whisker.plugin.builtin_loader")
    loader = BuiltinLoader.new()

    -- Use actual builtin path
    test_builtin_path = "plugins/builtin"
  end)

  describe("new()", function()
    it("creates loader with defaults", function()
      assert.is_not_nil(loader)
    end)

    it("accepts configuration", function()
      local custom = BuiltinLoader.new({
        enabled_plugins = {core = true, inventory = false},
      })
      assert.is_true(custom:is_plugin_enabled("core"))
      assert.is_false(custom:is_plugin_enabled("inventory"))
    end)
  end)

  describe("is_plugin_enabled()", function()
    it("returns true by default", function()
      assert.is_true(loader:is_plugin_enabled("unknown"))
    end)

    it("respects enabled setting", function()
      loader:set_enabled_plugins({core = true})
      assert.is_true(loader:is_plugin_enabled("core"))
    end)

    it("respects disabled setting", function()
      loader:set_enabled_plugins({inventory = false})
      assert.is_false(loader:is_plugin_enabled("inventory"))
    end)
  end)

  describe("is_builtin_path()", function()
    it("returns true for builtin paths", function()
      assert.is_true(BuiltinLoader.is_builtin_path("plugins/builtin"))
      assert.is_true(BuiltinLoader.is_builtin_path("/path/to/builtin/plugins"))
    end)

    it("returns false for non-builtin paths", function()
      assert.is_false(BuiltinLoader.is_builtin_path("plugins/community"))
      assert.is_false(BuiltinLoader.is_builtin_path("/path/to/plugins"))
    end)
  end)

  describe("find_builtin_path()", function()
    it("finds builtin path in array", function()
      local paths = {"plugins/community", "plugins/builtin", "plugins/custom"}
      local found = loader:find_builtin_path(paths)
      assert.equal("plugins/builtin", found)
    end)

    it("returns nil when no builtin path", function()
      local paths = {"plugins/community", "plugins/custom"}
      local found = loader:find_builtin_path(paths)
      assert.is_nil(found)
    end)
  end)

  describe("discover_plugins()", function()
    it("discovers core plugin", function()
      local plugins = loader:discover_plugins(test_builtin_path)

      -- Should find at least core
      assert.is_true(#plugins >= 1)

      local found_core = false
      for _, p in ipairs(plugins) do
        if p.name == "core" then
          found_core = true
          assert.is_true(p.init_file:match("init.lua$") ~= nil)
        end
      end
      assert.is_true(found_core)
    end)

    it("returns sorted array", function()
      local plugins = loader:discover_plugins(test_builtin_path)

      for i = 2, #plugins do
        assert.is_true(plugins[i-1].name <= plugins[i].name)
      end
    end)

    it("handles missing directory gracefully", function()
      local plugins = loader:discover_plugins("nonexistent/path")
      assert.same({}, plugins)
    end)
  end)

  describe("load_plugin()", function()
    it("loads core plugin successfully", function()
      local metadata = {
        name = "core",
        path = test_builtin_path .. "/core",
        init_file = test_builtin_path .. "/core/init.lua",
      }

      local plugin, err = loader:load_plugin(metadata)
      assert.is_not_nil(plugin)
      assert.is_nil(err)
      assert.equal("core", plugin.name)
      assert.equal("1.0.0", plugin.version)
      assert.is_true(plugin._trusted)
    end)

    it("returns disabled for disabled plugins", function()
      loader:set_enabled_plugins({core = false})

      local metadata = {
        name = "core",
        path = test_builtin_path .. "/core",
        init_file = test_builtin_path .. "/core/init.lua",
      }

      local plugin, err = loader:load_plugin(metadata)
      assert.is_nil(plugin)
      assert.equal("disabled", err)
    end)

    it("adds metadata to loaded plugin", function()
      local metadata = {
        name = "core",
        path = test_builtin_path .. "/core",
        init_file = test_builtin_path .. "/core/init.lua",
      }

      local plugin = loader:load_plugin(metadata)
      assert.is_not_nil(plugin._metadata)
      assert.equal(metadata.path, plugin._metadata.path)
    end)
  end)

  describe("load_all()", function()
    it("loads all discovered plugins", function()
      local results = loader:load_all(test_builtin_path)

      assert.is_table(results.loaded)
      assert.is_table(results.skipped)
      assert.is_table(results.failed)

      -- Should have loaded core at minimum
      assert.is_true(#results.loaded >= 1)
    end)

    it("skips disabled plugins", function()
      loader:set_enabled_plugins({core = false})

      local results = loader:load_all(test_builtin_path)

      -- Core should be in skipped
      local core_skipped = false
      for _, name in ipairs(results.skipped) do
        if name == "core" then
          core_skipped = true
        end
      end
      assert.is_true(core_skipped)
    end)
  end)

  describe("validate()", function()
    it("validates correct plugin", function()
      local plugin = {
        name = "test",
        version = "1.0.0",
        _trusted = true,
      }

      local valid, err = BuiltinLoader.validate(plugin)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects nil plugin", function()
      local valid, err = BuiltinLoader.validate(nil)
      assert.is_false(valid)
      assert.is_not_nil(err)
    end)

    it("rejects missing name", function()
      local plugin = {version = "1.0.0", _trusted = true}
      local valid, err = BuiltinLoader.validate(plugin)
      assert.is_false(valid)
      assert.is_true(err:match("name") ~= nil)
    end)

    it("rejects missing version", function()
      local plugin = {name = "test", _trusted = true}
      local valid, err = BuiltinLoader.validate(plugin)
      assert.is_false(valid)
      assert.is_true(err:match("version") ~= nil)
    end)

    it("rejects missing trusted flag", function()
      local plugin = {name = "test", version = "1.0.0"}
      local valid, err = BuiltinLoader.validate(plugin)
      assert.is_false(valid)
      assert.is_true(err:match("_trusted") ~= nil)
    end)

    it("validates hooks are functions", function()
      local plugin = {
        name = "test",
        version = "1.0.0",
        _trusted = true,
        on_init = "not a function",
      }

      local valid, err = BuiltinLoader.validate(plugin)
      assert.is_false(valid)
      assert.is_true(err:match("on_init") ~= nil)
    end)
  end)

  describe("get_metadata()", function()
    it("extracts metadata from plugin", function()
      local plugin = {
        name = "test",
        version = "1.0.0",
        author = "test-author",
        description = "Test plugin",
        dependencies = {core = "^1.0.0"},
        api = {test = function() end},
      }

      local meta = BuiltinLoader.get_metadata(plugin)

      assert.equal("test", meta.name)
      assert.equal("1.0.0", meta.version)
      assert.equal("test-author", meta.author)
      assert.is_true(meta.has_api)
    end)

    it("provides defaults for missing fields", function()
      local plugin = {name = "test", version = "1.0.0"}

      local meta = BuiltinLoader.get_metadata(plugin)

      assert.equal("whisker-core", meta.author)
      assert.equal("", meta.description)
      assert.equal("MIT", meta.license)
    end)
  end)
end)

describe("Core Plugin", function()
  local core_plugin

  before_each(function()
    -- Load core plugin directly
    local chunk = loadfile("plugins/builtin/core/init.lua")
    core_plugin = chunk()
  end)

  describe("metadata", function()
    it("has required fields", function()
      assert.equal("core", core_plugin.name)
      assert.equal("1.0.0", core_plugin.version)
      assert.is_true(core_plugin._trusted)
    end)

    it("has no dependencies", function()
      assert.same({}, core_plugin.dependencies)
    end)
  end)

  describe("api.deep_copy()", function()
    it("copies simple table", function()
      local original = {a = 1, b = 2}
      local copy = core_plugin.api.deep_copy(original)

      assert.same(original, copy)
      assert.are_not.equal(original, copy)
    end)

    it("copies nested tables", function()
      local original = {a = {b = {c = 3}}}
      local copy = core_plugin.api.deep_copy(original)

      assert.equal(3, copy.a.b.c)
      assert.are_not.equal(original.a, copy.a)
      assert.are_not.equal(original.a.b, copy.a.b)
    end)

    it("returns non-tables as-is", function()
      assert.equal(42, core_plugin.api.deep_copy(42))
      assert.equal("test", core_plugin.api.deep_copy("test"))
    end)
  end)

  describe("api.merge()", function()
    it("merges source into target", function()
      local target = {a = 1}
      local source = {b = 2}
      local result = core_plugin.api.merge(target, source)

      assert.equal(1, result.a)
      assert.equal(2, result.b)
      assert.equal(target, result)  -- Same table
    end)

    it("overwrites existing keys", function()
      local target = {a = 1}
      local source = {a = 2}
      local result = core_plugin.api.merge(target, source)

      assert.equal(2, result.a)
    end)
  end)

  describe("api.contains()", function()
    it("finds value in array", function()
      local tbl = {"a", "b", "c"}
      assert.is_true(core_plugin.api.contains(tbl, "b"))
    end)

    it("returns false for missing value", function()
      local tbl = {"a", "b", "c"}
      assert.is_false(core_plugin.api.contains(tbl, "x"))
    end)
  end)

  describe("api.map()", function()
    it("applies function to each element", function()
      local tbl = {1, 2, 3}
      local result = core_plugin.api.map(tbl, function(v) return v * 2 end)

      assert.same({2, 4, 6}, result)
    end)
  end)

  describe("api.filter()", function()
    it("filters by predicate", function()
      local tbl = {1, 2, 3, 4, 5}
      local result = core_plugin.api.filter(tbl, function(v) return v > 2 end)

      assert.same({3, 4, 5}, result)
    end)
  end)

  describe("api.reduce()", function()
    it("reduces to single value", function()
      local tbl = {1, 2, 3, 4}
      local result = core_plugin.api.reduce(tbl, function(acc, v)
        return acc + v
      end, 0)

      assert.equal(10, result)
    end)
  end)

  describe("api.keys()", function()
    it("returns array of keys", function()
      local tbl = {a = 1, b = 2}
      local keys = core_plugin.api.keys(tbl)

      assert.equal(2, #keys)
      assert.is_true(core_plugin.api.contains(keys, "a"))
      assert.is_true(core_plugin.api.contains(keys, "b"))
    end)
  end)

  describe("api.values()", function()
    it("returns array of values", function()
      local tbl = {a = 1, b = 2}
      local values = core_plugin.api.values(tbl)

      assert.equal(2, #values)
      assert.is_true(core_plugin.api.contains(values, 1))
      assert.is_true(core_plugin.api.contains(values, 2))
    end)
  end)

  describe("api.clamp()", function()
    it("clamps to min", function()
      assert.equal(0, core_plugin.api.clamp(-5, 0, 10))
    end)

    it("clamps to max", function()
      assert.equal(10, core_plugin.api.clamp(15, 0, 10))
    end)

    it("returns value in range", function()
      assert.equal(5, core_plugin.api.clamp(5, 0, 10))
    end)
  end)

  describe("api.format()", function()
    it("replaces placeholders", function()
      local result = core_plugin.api.format("Hello {name}!", {name = "World"})
      assert.equal("Hello World!", result)
    end)

    it("handles multiple placeholders", function()
      local result = core_plugin.api.format("{a} + {b} = {c}", {a = 1, b = 2, c = 3})
      assert.equal("1 + 2 = 3", result)
    end)
  end)

  describe("api.create_emitter()", function()
    it("emits events to listeners", function()
      local emitter = core_plugin.api.create_emitter()
      local received = nil

      emitter.on("test", function(value)
        received = value
      end)

      emitter.emit("test", "hello")
      assert.equal("hello", received)
    end)

    it("supports multiple listeners", function()
      local emitter = core_plugin.api.create_emitter()
      local count = 0

      emitter.on("test", function() count = count + 1 end)
      emitter.on("test", function() count = count + 1 end)

      emitter.emit("test")
      assert.equal(2, count)
    end)

    it("removes listeners with off()", function()
      local emitter = core_plugin.api.create_emitter()
      local count = 0

      local callback = function() count = count + 1 end
      emitter.on("test", callback)
      emitter.off("test", callback)

      emitter.emit("test")
      assert.equal(0, count)
    end)
  end)
end)
