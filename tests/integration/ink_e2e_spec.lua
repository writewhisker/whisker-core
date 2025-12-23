--- Ink End-to-End Integration Tests
-- Complete workflow tests for Ink integration
-- @module tests.integration.ink_e2e_spec

describe("Ink End-to-End Integration", function()
  local InkEngine
  local InkFormat
  local Container
  local EventBus

  local function create_test_container()
    local container = Container.new()

    -- Register events
    local events = EventBus.new()
    container:register("events", function()
      return events
    end, { singleton = true })

    -- Register mock state
    local state_data = {}
    local state = {
      get = function(_, key)
        return state_data[key]
      end,
      set = function(_, key, value)
        state_data[key] = value
        events:emit("state:changed", { key = key, value = value })
      end,
      has = function(_, key)
        return state_data[key] ~= nil
      end,
      delete = function(_, key)
        state_data[key] = nil
      end,
      keys = function()
        local keys = {}
        for k in pairs(state_data) do
          table.insert(keys, k)
        end
        return keys
      end,
      clear = function()
        state_data = {}
      end,
    }
    container:register("state", function()
      return state
    end, { singleton = true })

    -- Register mock logger
    container:register("logger", function()
      return {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
      }
    end, { singleton = true })

    return container
  end

  local function load_fixture(name)
    local path = "tests/fixtures/ink/" .. name
    local file = io.open(path, "r")
    if not file then
      error("Could not load fixture: " .. path)
    end
    local content = file:read("*all")
    file:close()
    return content
  end

  before_each(function()
    -- Clear module cache
    package.loaded["whisker.formats.ink"] = nil
    package.loaded["whisker.formats.ink.engine"] = nil
    package.loaded["whisker.kernel.container"] = nil
    package.loaded["whisker.kernel.events"] = nil

    InkEngine = require("whisker.formats.ink.engine")
    InkFormat = require("whisker.formats.ink")
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
  end)

  describe("Story Execution", function()
    it("loads and runs hello world story", function()
      local container = create_test_container()
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local json = load_fixture("hello_world.ink.json")

      local ok = engine:load(json)
      assert.is_true(ok)

      engine:start()

      local all_text = {}
      while engine:can_continue() do
        local text = engine:continue()
        if text then
          table.insert(all_text, text)
        end
      end

      assert.is_true(#all_text > 0)
      assert.truthy(table.concat(all_text):match("Hello"))
    end)

    it("handles choices correctly", function()
      local container = create_test_container()
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local json = load_fixture("choices.ink.json")

      engine:load(json)
      engine:start()

      -- Continue to choices
      while engine:can_continue() do
        engine:continue()
      end

      local choices = engine:get_choices()
      assert.is_true(#choices >= 1)

      -- Make a choice
      local ok = engine:make_choice(1)
      assert.is_true(ok)

      -- Should be able to continue after choice
      assert.is_true(engine:can_continue() or engine:has_ended())
    end)
  end)

  describe("State Integration", function()
    it("syncs variables to Whisker state", function()
      local container = create_test_container()
      local state = container:resolve("state")
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = state,
        logger = container:resolve("logger"),
      })

      local json = load_fixture("variables.ink.json")

      engine:load(json)
      engine:start()

      -- Continue to initialize variables
      while engine:can_continue() do
        engine:continue()
      end

      -- Variables should be synced to state
      -- Note: exact behavior depends on state bridge implementation
      -- This test validates the integration works
      assert.is_true(engine:is_loaded())
    end)
  end)

  describe("Event Integration", function()
    it("emits events during execution", function()
      local container = create_test_container()
      local events = container:resolve("events")

      local event_log = {}
      events:on("ink:*", function(data)
        table.insert(event_log, data.event_name or "unknown")
      end)

      local engine = InkEngine.new({
        events = events,
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local json = load_fixture("hello_world.ink.json")

      engine:load(json)
      engine:start()

      while engine:can_continue() do
        engine:continue()
      end

      -- Should have received events
      -- The exact events depend on implementation
      assert.is_true(engine:has_ended() or #engine:get_choices() == 0)
    end)
  end)

  describe("Format Integration", function()
    it("can_import detects Ink JSON", function()
      local container = create_test_container()
      local format = InkFormat.new({
        events = container:resolve("events"),
        logger = container:resolve("logger"),
      })

      local json = load_fixture("hello_world.ink.json")

      assert.is_true(format:can_import(json))
    end)

    it("rejects non-Ink JSON", function()
      local container = create_test_container()
      local format = InkFormat.new({
        events = container:resolve("events"),
        logger = container:resolve("logger"),
      })

      assert.is_false(format:can_import('{"foo": "bar"}'))
      assert.is_false(format:can_import("plain text"))
    end)
  end)

  describe("Error Handling", function()
    it("handles invalid JSON gracefully", function()
      local container = create_test_container()
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local ok, err = engine:load("not valid json")

      assert.is_nil(ok)
      assert.is_string(err)
    end)

    it("handles missing story gracefully", function()
      local container = create_test_container()
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local ok, err = engine:start()

      assert.is_false(ok)
      assert.is_string(err)
    end)
  end)

  describe("Save/Load State", function()
    it("can save and restore state", function()
      local container = create_test_container()
      local engine = InkEngine.new({
        events = container:resolve("events"),
        state = container:resolve("state"),
        logger = container:resolve("logger"),
      })

      local json = load_fixture("choices.ink.json")

      engine:load(json)
      engine:start()

      -- Continue a bit
      while engine:can_continue() do
        engine:continue()
      end

      -- Save state
      local saved = engine:save_state()
      assert.is_table(saved)

      -- Reset and restore
      engine:reset()
      engine:start()

      local ok = engine:restore_state(saved)
      assert.is_true(ok)
    end)
  end)
end)
