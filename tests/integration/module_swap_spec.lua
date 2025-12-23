--- Module Swap Integration Tests
-- Tests for verifying module swapping and DI capabilities
-- @module tests.integration.module_swap_spec
-- @author Whisker Core Team

describe("Module Swapping", function()
  local Container, EventBus
  local MockFactory

  setup(function()
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
    MockFactory = require("tests.mocks.mock_factory")
  end)

  describe("Service implementation swapping", function()
    it("swaps state service with alternative implementation", function()
      -- Create alternative state implementation
      local AltState = {}
      function AltState.new()
        return {
          _data = {},
          _log = {},
          get = function(self, key)
            table.insert(self._log, { op = "get", key = key })
            return self._data[key]
          end,
          set = function(self, key, value)
            table.insert(self._log, { op = "set", key = key, value = value })
            self._data[key] = value
          end,
          has = function(self, key) return self._data[key] ~= nil end,
          delete = function(self, key) self._data[key] = nil end,
          clear = function(self) self._data = {} end,
          get_log = function(self) return self._log end,
        }
      end

      -- Register alternative
      local container = Container.new()
      container:register("state", AltState, { singleton = true })

      -- Use alternative
      local state = container:resolve("state")
      state:set("key", "value")
      local _ = state:get("key")

      -- Verify it's the alternative implementation
      assert.equals(2, #state:get_log())
      assert.equals("set", state:get_log()[1].op)
      assert.equals("get", state:get_log()[2].op)
    end)

    it("swaps event bus with custom implementation", function()
      -- Custom event bus with filtering
      local FilteredEventBus = {}
      function FilteredEventBus.new()
        return {
          _handlers = {},
          _filter = nil,
          set_filter = function(self, fn)
            self._filter = fn
          end,
          on = function(self, event, handler)
            self._handlers[event] = self._handlers[event] or {}
            table.insert(self._handlers[event], handler)
          end,
          emit = function(self, event, data)
            if self._filter and not self._filter(event, data) then
              return { filtered = true }
            end
            local handlers = self._handlers[event] or {}
            for _, handler in ipairs(handlers) do
              handler(data)
            end
            return { filtered = false }
          end,
        }
      end

      -- Use custom event bus
      local container = Container.new()
      container:register("events", FilteredEventBus, { singleton = true })

      local events = container:resolve("events")
      local received = {}

      events:on("test", function(data)
        table.insert(received, data)
      end)

      -- Set filter to block events with blocked=true
      events:set_filter(function(_, data)
        return not data.blocked
      end)

      events:emit("test", { value = 1 })
      events:emit("test", { value = 2, blocked = true })
      events:emit("test", { value = 3 })

      assert.equals(2, #received)
      assert.equals(1, received[1].value)
      assert.equals(3, received[2].value)
    end)

    it("swaps logger with tracking implementation", function()
      local TrackingLogger = {}
      function TrackingLogger.new()
        return {
          _logs = {},
          _counts = { info = 0, warn = 0, error = 0, debug = 0 },
          log = function(self, level, msg)
            self._counts[level] = (self._counts[level] or 0) + 1
            table.insert(self._logs, { level = level, message = msg })
          end,
          info = function(self, msg) self:log("info", msg) end,
          warn = function(self, msg) self:log("warn", msg) end,
          error = function(self, msg) self:log("error", msg) end,
          debug = function(self, msg) self:log("debug", msg) end,
          get_counts = function(self) return self._counts end,
          get_logs = function(self) return self._logs end,
        }
      end

      local container = Container.new()
      container:register("logger", TrackingLogger, { singleton = true })

      local logger = container:resolve("logger")

      logger:info("Info 1")
      logger:info("Info 2")
      logger:warn("Warning")
      logger:error("Error")

      local counts = logger:get_counts()
      assert.equals(2, counts.info)
      assert.equals(1, counts.warn)
      assert.equals(1, counts.error)
      assert.equals(0, counts.debug)
    end)
  end)

  describe("Container isolation", function()
    it("creates isolated containers", function()
      local container1 = Container.new()
      local container2 = Container.new()

      container1:register("events", EventBus, { singleton = true })
      container2:register("events", EventBus, { singleton = true })

      local events1 = container1:resolve("events")
      local events2 = container2:resolve("events")

      -- Should be different instances
      assert.not_equals(events1, events2)

      -- Changes in one don't affect the other
      local received1 = 0
      local received2 = 0

      events1:on("test", function() received1 = received1 + 1 end)
      events2:on("test", function() received2 = received2 + 1 end)

      events1:emit("test", {})

      assert.equals(1, received1)
      assert.equals(0, received2)
    end)

    it("allows service override", function()
      local container = Container.new()

      -- Original service
      local Original = {}
      function Original.new()
        return { name = "original" }
      end

      -- Replacement service
      local Replacement = {}
      function Replacement.new()
        return { name = "replacement" }
      end

      container:register("service", Original, { singleton = true })

      local first = container:resolve("service")
      assert.equals("original", first.name)

      -- Override
      container:register("service", Replacement, { singleton = true, override = true })

      local second = container:resolve("service")
      assert.equals("replacement", second.name)
    end)
  end)

  describe("Mock service usage", function()
    it("uses mock factory in integration scenarios", function()
      local container = Container.new()

      -- Register mock services
      container:register("events", EventBus, { singleton = true })

      local events = container:resolve("events")
      local state = MockFactory.create_state()
      local vars = MockFactory.create_variables(events)
      local history = MockFactory.create_history()

      -- Simulate story playthrough
      vars:set("player_name", "Test Player")
      vars:set("score", 0)

      history:push({ passage_id = "start" })
      state:set("current_passage", "start")

      -- Make choice
      vars:set("score", vars:get("score") + 10)
      history:push({ passage_id = "middle" })
      state:set("current_passage", "middle")

      -- Verify state
      assert.equals(10, vars:get("score"))
      assert.equals(2, history:depth())
      assert.equals("middle", state:get("current_passage"))

      -- Go back
      local prev = history:go_back()
      assert.equals("start", prev.passage_id)
    end)
  end)

  describe("Interface compliance", function()
    it("mock state implements IState interface", function()
      local state = MockFactory.create_state()

      -- All required methods should exist
      assert.is_function(state.get)
      assert.is_function(state.set)
      assert.is_function(state.has)
      assert.is_function(state.delete)
      assert.is_function(state.clear)
    end)

    it("mock engine implements IEngine interface", function()
      local engine = MockFactory.create_engine()

      -- All required methods should exist
      assert.is_function(engine.load)
      assert.is_function(engine.start)
      assert.is_function(engine.get_current_passage)
      assert.is_function(engine.get_available_choices)
      assert.is_function(engine.make_choice)
      assert.is_function(engine.has_ended)
      assert.is_function(engine.reset)
    end)

    it("mock plugin implements IPlugin interface", function()
      local plugin = MockFactory.create_plugin()

      -- All required methods should exist
      assert.is_function(plugin.get_name)
      assert.is_function(plugin.get_version)
      assert.is_function(plugin.init)
      assert.is_function(plugin.destroy)
      assert.is_function(plugin.get_hooks)
      assert.is_function(plugin.is_enabled)
    end)
  end)
end)
