--- Ink Engine Tests
-- Tests for InkEngine runtime execution
-- @module tests.unit.formats.ink.engine_spec

describe("InkEngine", function()
  local InkEngine
  local mock_deps
  local hello_world_json

  before_each(function()
    -- Clear module cache
    package.loaded["whisker.formats.ink.engine"] = nil

    InkEngine = require("whisker.formats.ink.engine")

    mock_deps = {
      events = {
        emit = spy.new(function() end),
        on = function() return function() end end,
      },
      state = {
        get = function() return nil end,
        set = function() end,
        has = function() return false end,
        delete = function() end,
        keys = function() return {} end,
      },
      logger = {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
      },
    }

    -- Simple hello world Ink JSON
    hello_world_json = [[{
      "inkVersion": 21,
      "root": [
        "^Hello, world!",
        "\n",
        "done",
        "TERM"
      ],
      "listDefs": {}
    }]]
  end)

  describe("new", function()
    it("creates engine with dependencies", function()
      local engine = InkEngine.new(mock_deps)

      assert.is_not_nil(engine)
      assert.equals(mock_deps.events, engine.events)
      assert.equals(mock_deps.state, engine.state)
    end)

    it("starts in unloaded state", function()
      local engine = InkEngine.new(mock_deps)

      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)
  end)

  describe("load", function()
    it("loads valid Ink JSON", function()
      local engine = InkEngine.new(mock_deps)

      local ok, err = engine:load(hello_world_json)

      assert.is_true(ok)
      assert.is_nil(err)
      assert.is_true(engine:is_loaded())
    end)

    it("emits ink:loaded event", function()
      local engine = InkEngine.new(mock_deps)

      engine:load(hello_world_json)

      assert.spy(mock_deps.events.emit).was_called_with(
        mock_deps.events,
        "ink:loaded",
        match._
      )
    end)

    it("fails on invalid JSON", function()
      local engine = InkEngine.new(mock_deps)

      local ok, err = engine:load("not valid json")

      assert.is_nil(ok)
      assert.is_string(err)
    end)

    it("fails when already loaded", function()
      local engine = InkEngine.new(mock_deps)

      engine:load(hello_world_json)
      local ok, err = engine:load(hello_world_json)

      assert.is_nil(ok)
      assert.is_string(err)
      assert.truthy(err:match("already loaded"))
    end)
  end)

  describe("start", function()
    it("starts loaded story", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)

      local ok = engine:start()

      assert.is_true(ok)
      assert.is_true(engine:is_started())
    end)

    it("fails when not loaded", function()
      local engine = InkEngine.new(mock_deps)

      local ok, err = engine:start()

      assert.is_false(ok)
      assert.is_string(err)
    end)

    it("fails when already started", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)
      engine:start()

      local ok, err = engine:start()

      assert.is_false(ok)
      assert.is_string(err)
    end)
  end)

  describe("can_continue", function()
    it("returns false when not loaded", function()
      local engine = InkEngine.new(mock_deps)

      assert.is_false(engine:can_continue())
    end)

    it("returns false when not started", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)

      assert.is_false(engine:can_continue())
    end)

    it("returns true when story can continue", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)
      engine:start()

      assert.is_true(engine:can_continue())
    end)
  end)

  describe("continue", function()
    it("returns text content", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)
      engine:start()

      local text, tags = engine:continue()

      assert.is_string(text)
      assert.truthy(text:match("Hello"))
    end)

    it("returns nil when cannot continue", function()
      local engine = InkEngine.new(mock_deps)

      local text = engine:continue()

      assert.is_nil(text)
    end)
  end)

  describe("get_choices", function()
    it("returns empty array when not loaded", function()
      local engine = InkEngine.new(mock_deps)

      local choices = engine:get_choices()

      assert.is_table(choices)
      assert.equals(0, #choices)
    end)
  end)

  describe("has_ended", function()
    it("returns false when not loaded", function()
      local engine = InkEngine.new(mock_deps)

      assert.is_false(engine:has_ended())
    end)

    it("returns true after story completes", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)
      engine:start()

      -- Continue until done
      while engine:can_continue() do
        engine:continue()
      end

      assert.is_true(engine:has_ended())
    end)
  end)

  describe("reset", function()
    it("resets engine state", function()
      local engine = InkEngine.new(mock_deps)
      engine:load(hello_world_json)
      engine:start()

      engine:reset()

      assert.is_false(engine:is_started())
    end)
  end)

  describe("DI pattern", function()
    it("declares _dependencies", function()
      assert.is_table(InkEngine._dependencies)
      assert.is_truthy(#InkEngine._dependencies > 0)
    end)

    it("includes ink_runtime in dependencies", function()
      local found = false
      for _, dep in ipairs(InkEngine._dependencies) do
        if dep == "ink_runtime" then
          found = true
          break
        end
      end
      assert.is_true(found, "ink_runtime not found in _dependencies")
    end)

    it("includes json_codec in dependencies", function()
      local found = false
      for _, dep in ipairs(InkEngine._dependencies) do
        if dep == "json_codec" then
          found = true
          break
        end
      end
      assert.is_true(found, "json_codec not found in _dependencies")
    end)

    it("accepts injected ink_runtime", function()
      local mock_story = {
        canContinue = function() return true end,
        Continue = function() return "Hello" end,
        currentText = function() return "Hello" end,
        currentTags = function() return {} end,
        currentChoices = function() return {} end,
        ChooseChoiceIndex = function() end,
        ChoosePathString = function() end,
        ResetState = function() end,
        BindExternalFunction = function() end,
        UnbindExternalFunction = function() end,
        ObserveVariable = function() end,
        RemoveVariableObserver = function() end,
        currentFlowName = function() return "DEFAULT" end,
        SwitchFlow = function() end,
        RemoveFlow = function() end,
        aliveFlowNames = function() return {} end,
        HasFunction = function() return false end,
        EvaluateFunction = function() return nil, "" end,
        get_ink_data = function() return { inkVersion = 21, root = {} } end,
        get_raw_story = function() return {} end,
        state = {
          save = function() return {} end,
          load = function() end,
          variablesState = {
            GetVariableWithName = function() return nil end,
            SetVariable = function() end,
          },
        },
      }

      local mock_runtime = {
        create_story = function(self, json_text)
          return mock_story
        end,
        get_runtime_name = function() return "mock" end,
        get_ink_version = function() return 21 end,
        supports = function() return true end,
      }

      local deps_with_runtime = {
        events = mock_deps.events,
        state = mock_deps.state,
        logger = mock_deps.logger,
        ink_runtime = mock_runtime,
      }

      local engine = InkEngine.new(deps_with_runtime)
      assert.equals(mock_runtime, engine._ink_runtime)
    end)

    it("accepts injected json_codec", function()
      local mock_codec = {
        encode = function() return "{}" end,
        decode = function() return {} end,
        get_library_name = function() return "mock" end,
        supports = function() return false end,
        null = function() return nil end,
      }

      local deps_with_codec = {
        events = mock_deps.events,
        state = mock_deps.state,
        logger = mock_deps.logger,
        json_codec = mock_codec,
      }

      local engine = InkEngine.new(deps_with_codec)
      assert.equals(mock_codec, engine._json_codec)
    end)

    it("has create factory method", function()
      assert.is_function(InkEngine.create)
    end)

    it("create method resolves from container", function()
      local mock_container = {
        has = function(self, name)
          return name == "events" or name == "logger"
        end,
        resolve = function(self, name)
          if name == "events" then
            return mock_deps.events
          elseif name == "logger" then
            return mock_deps.logger
          end
        end,
      }

      local engine = InkEngine.create(mock_container)
      assert.is_table(engine)
      assert.equals(mock_deps.events, engine.events)
    end)
  end)
end)
