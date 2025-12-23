--- Kernel Bootstrap Unit Tests
-- Tests for the microkernel bootstrap
-- @module tests.unit.kernel.init_spec
-- @author Whisker Core Team
-- @license MIT

describe("Kernel Bootstrap", function()
  local original_whisker
  local original_loaded

  before_each(function()
    -- Save original state
    original_whisker = _G.whisker
    original_loaded = package.loaded["whisker.kernel.init"]

    -- Reset global state
    _G.whisker = nil
    package.loaded["whisker.kernel.init"] = nil
  end)

  after_each(function()
    -- Restore original state
    _G.whisker = original_whisker
    package.loaded["whisker.kernel.init"] = original_loaded
  end)

  describe("initialization", function()
    it("creates whisker global table", function()
      require("whisker.kernel.init")
      assert.is_table(_G.whisker)
    end)

    it("sets version number", function()
      require("whisker.kernel.init")
      assert.equals("2.1.0", whisker.version)
    end)

    it("initializes exactly once", function()
      local kernel = require("whisker.kernel.init")

      local first_caps = whisker._capabilities
      kernel.init() -- Call again

      -- Capabilities table should be same object (not recreated)
      assert.equals(first_caps, whisker._capabilities)
    end)

    it("does not load any other whisker modules", function()
      local before = {}
      for k in pairs(package.loaded) do
        if k:match("^whisker%.") and k ~= "whisker.kernel.init" then
          before[k] = true
        end
      end

      require("whisker.kernel.init")

      local after = {}
      for k in pairs(package.loaded) do
        if k:match("^whisker%.") and k ~= "whisker.kernel.init" then
          after[k] = true
        end
      end

      -- No new whisker modules loaded
      assert.same(before, after)
    end)
  end)

  describe("capability detection", function()
    it("detects Lua version", function()
      require("whisker.kernel.init")
      assert.is_string(whisker._capabilities.lua_version)
      assert.is_not_nil(whisker._capabilities.lua_version:match("Lua"))
    end)

    it("detects standard libraries", function()
      require("whisker.kernel.init")

      -- These should always be true in standard Lua
      assert.is_boolean(whisker._capabilities.io)
      assert.is_boolean(whisker._capabilities.os)
      assert.is_boolean(whisker._capabilities.package)
    end)

    it("detects LuaJIT", function()
      require("whisker.kernel.init")
      assert.is_boolean(whisker._capabilities.luajit)

      -- Verify accuracy
      if jit then
        assert.is_true(whisker._capabilities.luajit)
      else
        assert.is_false(whisker._capabilities.luajit)
      end
    end)

    it("detects JSON library availability", function()
      require("whisker.kernel.init")
      assert.is_boolean(whisker._capabilities.json)
    end)

    it("detects debug library", function()
      require("whisker.kernel.init")
      assert.is_boolean(whisker._capabilities.debug)
    end)
  end)

  describe("has_capability", function()
    it("returns true for detected capabilities", function()
      local kernel = require("whisker.kernel.init")
      -- lua_version is a string, not true, so has_capability returns false
      -- Test with io which should be true
      assert.is_true(kernel.has_capability("io"))
    end)

    it("returns false for missing capabilities", function()
      local kernel = require("whisker.kernel.init")
      assert.is_false(kernel.has_capability("nonexistent_feature"))
    end)

    it("returns false for nil capability name", function()
      local kernel = require("whisker.kernel.init")
      assert.is_false(kernel.has_capability(nil))
    end)

    it("returns false for string capabilities like lua_version", function()
      local kernel = require("whisker.kernel.init")
      -- lua_version is a string, not true, so should return false
      assert.is_false(kernel.has_capability("lua_version"))
    end)
  end)

  describe("get_capabilities", function()
    it("returns table of all capabilities", function()
      local kernel = require("whisker.kernel.init")
      local caps = kernel.get_capabilities()

      assert.is_table(caps)
      assert.is_not_nil(caps.lua_version)
      assert.is_not_nil(caps.io)
    end)

    it("returns copy not reference", function()
      local kernel = require("whisker.kernel.init")
      local caps1 = kernel.get_capabilities()
      local caps2 = kernel.get_capabilities()

      -- Should be different table objects
      assert.is_not_equal(caps1, caps2)

      -- But same contents
      assert.same(caps1, caps2)
    end)

    it("modifications to copy do not affect original", function()
      local kernel = require("whisker.kernel.init")
      local caps = kernel.get_capabilities()

      caps.custom = "test"

      -- Original should not have custom
      assert.is_nil(whisker._capabilities.custom)
    end)
  end)

  describe("infrastructure hooks", function()
    it("provides container hook (initially nil)", function()
      require("whisker.kernel.init")
      assert.is_nil(whisker.container)
    end)

    it("provides events hook (initially nil)", function()
      require("whisker.kernel.init")
      assert.is_nil(whisker.events)
    end)

    it("provides loader hook (initially nil)", function()
      require("whisker.kernel.init")
      assert.is_nil(whisker.loader)
    end)

    it("allows systems to be attached", function()
      require("whisker.kernel.init")

      local mock_container = { resolve = function() end }
      whisker.container = mock_container

      assert.equals(mock_container, whisker.container)
    end)
  end)

  describe("global namespace", function()
    it("only creates whisker global", function()
      -- Capture globals before
      local before_globals = {}
      for k in pairs(_G) do
        before_globals[k] = true
      end

      require("whisker.kernel.init")

      -- Check for new globals
      local new_globals = {}
      for k in pairs(_G) do
        if not before_globals[k] then
          new_globals[k] = true
        end
      end

      -- Should only have whisker as new global
      assert.is_true(new_globals.whisker)
      new_globals.whisker = nil
      assert.same({}, new_globals)
    end)

    it("preserves existing whisker data on reload", function()
      -- Set up initial state
      _G.whisker = { custom_data = "preserved" }

      require("whisker.kernel.init")

      -- Custom data should still be there
      assert.equals("preserved", whisker.custom_data)
    end)
  end)
end)

describe("Line Count Limits", function()
  it("kernel/init.lua is under 50 lines", function()
    -- Find the file
    local path = package.searchpath("whisker.kernel.init", package.path)
    assert.is_not_nil(path, "Could not find whisker.kernel.init")

    local file = io.open(path, "r")
    assert.is_not_nil(file, "Could not open " .. path)

    local content = file:read("*all")
    file:close()

    local lines = 0
    for _ in content:gmatch("[^\n]*\n?") do
      lines = lines + 1
    end
    -- Subtract 1 for potential trailing match
    if content:sub(-1) ~= "\n" then
      lines = lines - 1
    end

    assert.is_true(
      lines <= 50,
      string.format("kernel/init.lua is %d lines (limit: 50)", lines)
    )
  end)
end)
