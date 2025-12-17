-- spec/formats/ink/externals_spec.lua
-- Tests for InkExternals manager

describe("InkExternals", function()
  local InkExternals
  local InkEngine
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.vendor%.tinta") then
        package.loaded[k] = nil
      end
    end
    -- Clear tinta globals
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    InkExternals = require("whisker.formats.ink.externals")
    InkEngine = require("whisker.formats.ink.engine")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkExternals._whisker)
      assert.are.equal("InkExternals", InkExternals._whisker.name)
    end)

    it("should have version", function()
      assert.is_string(InkExternals._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.externals", InkExternals._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)
      assert.is_table(externals)
    end)

    it("should store engine reference", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)
      assert.are.equal(engine, externals:get_engine())
    end)
  end)

  describe("bind (before story starts)", function()
    it("should store binding for later", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      local called = false
      local fn = function() called = true end

      local result = externals:bind("test_func", fn)
      assert.is_true(result)
      assert.is_true(externals:is_bound("test_func"))
    end)

    it("should error on invalid name", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      assert.has_error(function()
        externals:bind("", function() end)
      end)

      assert.has_error(function()
        externals:bind(nil, function() end)
      end)
    end)

    it("should error on invalid function", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      assert.has_error(function()
        externals:bind("test_func", "not a function")
      end)

      assert.has_error(function()
        externals:bind("test_func", nil)
      end)
    end)
  end)

  describe("unbind", function()
    it("should remove binding", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      externals:bind("test_func", function() end)
      assert.is_true(externals:is_bound("test_func"))

      local result = externals:unbind("test_func")
      assert.is_true(result)
      assert.is_false(externals:is_bound("test_func"))
    end)

    it("should return false for non-existent binding", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      local result = externals:unbind("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("is_bound", function()
    it("should return true for bound functions", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      externals:bind("test_func", function() end)
      assert.is_true(externals:is_bound("test_func"))
    end)

    it("should return false for unbound functions", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      assert.is_false(externals:is_bound("test_func"))
    end)
  end)

  describe("get_bound_names", function()
    it("should return empty array when no bindings", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      local names = externals:get_bound_names()
      assert.are.same({}, names)
    end)

    it("should return sorted array of names", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      externals:bind("zebra", function() end)
      externals:bind("alpha", function() end)
      externals:bind("middle", function() end)

      local names = externals:get_bound_names()
      assert.are.same({"alpha", "middle", "zebra"}, names)
    end)
  end)

  describe("clear", function()
    it("should remove all bindings", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      externals:bind("func1", function() end)
      externals:bind("func2", function() end)
      externals:bind("func3", function() end)

      externals:clear()

      assert.are.same({}, externals:get_bound_names())
    end)
  end)

  describe("set_event_emitter", function()
    it("should set event emitter", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)
      local emitter = { emit = function() end }

      externals:set_event_emitter(emitter)
      -- Should not error
    end)
  end)

  describe("engine integration", function()
    it("should get externals from engine", function()
      local engine = InkEngine.new()
      local externals = engine:get_externals()
      assert.is_table(externals)
      assert.are.equal(engine, externals:get_engine())
    end)

    it("should return same externals instance", function()
      local engine = InkEngine.new()
      local ext1 = engine:get_externals()
      local ext2 = engine:get_externals()
      assert.are.equal(ext1, ext2)
    end)

    it("should propagate event emitter", function()
      local emitted = false
      local emitter = {
        emit = function(self, event, data)
          if event == "ink.external.called" then
            emitted = true
          end
        end
      }

      local engine = InkEngine.new({ event_emitter = emitter })
      local externals = engine:get_externals()
      -- Emitter should be set
    end)
  end)

  describe("engine convenience methods", function()
    it("should bind via engine", function()
      local engine = InkEngine.new()

      engine:bind_external("my_func", function() return 42 end)

      local externals = engine:get_externals()
      assert.is_true(externals:is_bound("my_func"))
    end)

    it("should unbind via engine", function()
      local engine = InkEngine.new()

      engine:bind_external("my_func", function() return 42 end)
      assert.is_true(engine:get_externals():is_bound("my_func"))

      engine:unbind_external("my_func")
      assert.is_false(engine:get_externals():is_bound("my_func"))
    end)
  end)

  describe("validate", function()
    it("should return true when no story loaded", function()
      local engine = InkEngine.new()
      local externals = InkExternals.new(engine)

      local ok, missing = externals:validate()
      assert.is_true(ok)
      assert.are.same({}, missing)
    end)
  end)

  describe("with started engine", function()
    local engine
    local externals

    before_each(function()
      engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      externals = engine:get_externals()
    end)

    it("should get externals after load", function()
      assert.is_table(externals)
    end)

    it("should bind function after start", function()
      engine:start()

      -- Bind function - should work after start
      local result = externals:bind("test_external", function() return 99 end)
      assert.is_true(result)
    end)
  end)
end)
