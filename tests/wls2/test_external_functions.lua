--- Tests for WLS 2.0 External Functions Manager
-- @module tests.wls2.test_external_functions

describe("WLS 2.0 External Functions Manager", function()
  local external_functions

  setup(function()
    external_functions = require("whisker.wls2.external_functions")
  end)

  describe("creation", function()
    it("creates a new manager", function()
      local manager = external_functions.new()
      assert.is_not_nil(manager)
    end)
  end)

  describe("function registration", function()
    local manager

    before_each(function()
      manager = external_functions.new()
    end)

    it("registers a function", function()
      manager:register("greet", function() return "hello" end)
      assert.is_true(manager:has("greet"))
    end)

    it("registers with metadata", function()
      manager:register("greet", function() return "hello" end, {
        description = "Returns a greeting",
        params = { "name" },
      })
      local meta = manager:get_metadata("greet")
      assert.equals("Returns a greeting", meta.description)
    end)

    it("rejects non-function registrations", function()
      assert.has_error(function()
        manager:register("not_a_function", "string value")
      end)
    end)

    it("registers multiple functions at once", function()
      manager:register_all({
        greet = function() return "hello" end,
        farewell = function() return "goodbye" end,
      })
      assert.is_true(manager:has("greet"))
      assert.is_true(manager:has("farewell"))
    end)

    it("registers with fn and metadata in table", function()
      manager:register_all({
        greet = {
          fn = function() return "hello" end,
          metadata = { description = "test" },
        },
      })
      assert.is_true(manager:has("greet"))
      assert.equals("test", manager:get_metadata("greet").description)
    end)

    it("tracks namespaced functions", function()
      manager:register("audio.play", function() end)
      manager:register("audio.stop", function() end)

      local namespaces = manager:get_namespaces()
      assert.equals(1, #namespaces)
      assert.equals("audio", namespaces[1])
    end)

    it("registers a namespace of functions", function()
      manager:register_namespace("math", {
        add = function(a, b) return a + b end,
        multiply = function(a, b) return a * b end,
      })

      assert.is_true(manager:has("math.add"))
      assert.is_true(manager:has("math.multiply"))
    end)
  end)

  describe("function unregistration", function()
    local manager

    before_each(function()
      manager = external_functions.new()
      manager:register("greet", function() return "hello" end)
    end)

    it("unregisters a function", function()
      manager:unregister("greet")
      assert.is_false(manager:has("greet"))
    end)

    it("handles unregistering non-existent function", function()
      assert.has_no.errors(function()
        manager:unregister("nonexistent")
      end)
    end)

    it("unregisters all functions in namespace", function()
      manager:register("audio.play", function() end)
      manager:register("audio.stop", function() end)
      manager:unregister_namespace("audio")

      assert.is_false(manager:has("audio.play"))
      assert.is_false(manager:has("audio.stop"))
    end)
  end)

  describe("function calling", function()
    local manager

    before_each(function()
      manager = external_functions.new()
    end)

    it("calls a registered function", function()
      manager:register("add", function(a, b) return a + b end)
      local result = manager:call("add", 2, 3)
      assert.equals(5, result)
    end)

    it("passes multiple arguments", function()
      manager:register("concat", function(a, b, c)
        return a .. b .. c
      end)
      local result = manager:call("concat", "foo", "bar", "baz")
      assert.equals("foobarbaz", result)
    end)

    it("errors on non-existent function", function()
      assert.has_error(function()
        manager:call("nonexistent")
      end, "External function not found: nonexistent")
    end)

    it("propagates function errors", function()
      manager:register("throws", function()
        error("intentional error")
      end)
      assert.has_error(function()
        manager:call("throws")
      end)
    end)

    it("increments call count", function()
      manager:register("counter", function() end)
      manager:call("counter")
      manager:call("counter")
      manager:call("counter")

      local stats = manager:get_stats()
      assert.equals(3, stats.total_calls)
    end)
  end)

  describe("try_call (safe calling)", function()
    local manager

    before_each(function()
      manager = external_functions.new()
    end)

    it("returns result on success", function()
      manager:register("add", function(a, b) return a + b end)
      local result, err = manager:try_call("add", 2, 3)
      assert.equals(5, result)
      assert.is_nil(err)
    end)

    it("returns nil and error for non-existent function", function()
      local result, err = manager:try_call("nonexistent")
      assert.is_nil(result)
      assert.matches("not found", err)
    end)

    it("returns nil and error on function error", function()
      manager:register("throws", function()
        error("intentional error")
      end)
      local result, err = manager:try_call("throws")
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("function queries", function()
    local manager

    before_each(function()
      manager = external_functions.new()
      manager:register("alpha", function() end)
      manager:register("beta", function() end)
      manager:register("audio.play", function() end)
      manager:register("audio.stop", function() end)
    end)

    it("checks if function exists", function()
      assert.is_true(manager:has("alpha"))
      assert.is_false(manager:has("gamma"))
    end)

    it("gets all function names sorted", function()
      local names = manager:get_all_names()
      assert.equals(4, #names)
      assert.equals("alpha", names[1])
      assert.equals("audio.play", names[2])
    end)

    it("gets functions in namespace", function()
      local audio_funcs = manager:get_namespace_functions("audio")
      assert.equals(2, #audio_funcs)
    end)

    it("gets all namespaces", function()
      local namespaces = manager:get_namespaces()
      assert.equals(1, #namespaces)
      assert.equals("audio", namespaces[1])
    end)

    it("returns empty for non-existent namespace", function()
      local funcs = manager:get_namespace_functions("video")
      assert.equals(0, #funcs)
    end)
  end)

  describe("call history", function()
    local manager

    before_each(function()
      manager = external_functions.new()
      manager:register("fn1", function() return "one" end)
      manager:register("fn2", function() return "two" end)
    end)

    it("records call history", function()
      manager:call("fn1")
      manager:call("fn2", "arg1", "arg2")

      local history = manager:get_history()
      assert.equals(2, #history)
      assert.equals("fn1", history[1].name)
      assert.equals("fn2", history[2].name)
    end)

    it("records arguments in history", function()
      manager:call("fn2", "arg1", "arg2")

      local history = manager:get_history()
      assert.equals(2, #history[1].args)
      assert.equals("arg1", history[1].args[1])
    end)

    it("limits history with get_history parameter", function()
      manager:call("fn1")
      manager:call("fn1")
      manager:call("fn1")

      local history = manager:get_history(2)
      assert.equals(2, #history)
    end)

    it("clears history", function()
      manager:call("fn1")
      manager:call("fn2")
      manager:clear_history()

      local history = manager:get_history()
      assert.equals(0, #history)
    end)

    it("limits history size to max_history", function()
      manager.max_history = 3
      for i = 1, 5 do
        manager:call("fn1")
      end

      local history = manager:get_history()
      assert.equals(3, #history)
    end)
  end)

  describe("statistics", function()
    local manager

    before_each(function()
      manager = external_functions.new()
      manager:register("fn1", function() end)
      manager:register("audio.play", function() end)
    end)

    it("returns function count", function()
      local stats = manager:get_stats()
      assert.equals(2, stats.function_count)
    end)

    it("returns namespace count", function()
      local stats = manager:get_stats()
      assert.equals(1, stats.namespace_count)
    end)

    it("tracks total calls", function()
      manager:call("fn1")
      manager:call("fn1")
      manager:call("audio.play")

      local stats = manager:get_stats()
      assert.equals(3, stats.total_calls)
    end)

    it("tracks history size", function()
      manager:call("fn1")
      manager:call("fn1")

      local stats = manager:get_stats()
      assert.equals(2, stats.history_size)
    end)
  end)

  describe("proxy access", function()
    local manager

    before_each(function()
      manager = external_functions.new()
      manager:register("greet", function(name)
        return "Hello, " .. name
      end)
      manager:register("math.add", function(a, b)
        return a + b
      end)
    end)

    it("creates a proxy table", function()
      local proxy = manager:create_proxy()
      assert.is_table(proxy)
    end)

    it("allows calling direct functions through proxy", function()
      local proxy = manager:create_proxy()
      local result = proxy.greet("World")
      assert.equals("Hello, World", result)
    end)

    it("allows calling namespaced functions through proxy", function()
      local proxy = manager:create_proxy()
      local result = proxy.math.add(2, 3)
      assert.equals(5, result)
    end)

    it("returns nil for non-existent functions", function()
      local proxy = manager:create_proxy()
      assert.is_nil(proxy.nonexistent)
    end)
  end)

  describe("events", function()
    local manager
    local events

    before_each(function()
      manager = external_functions.new()
      events = {}
      manager:on(function(event, data)
        table.insert(events, { event = event, data = data })
      end)
    end)

    it("emits REGISTERED event on register", function()
      manager:register("greet", function() end)
      assert.equals(1, #events)
      assert.equals(external_functions.EVENTS.REGISTERED, events[1].event)
      assert.equals("greet", events[1].data.name)
    end)

    it("emits UNREGISTERED event on unregister", function()
      manager:register("greet", function() end)
      manager:unregister("greet")
      assert.equals(2, #events)
      assert.equals(external_functions.EVENTS.UNREGISTERED, events[2].event)
    end)

    it("emits CALLED event on successful call", function()
      manager:register("greet", function() return "hi" end)
      manager:call("greet")
      assert.equals(2, #events)  -- REGISTERED + CALLED
      assert.equals(external_functions.EVENTS.CALLED, events[2].event)
    end)

    it("emits ERROR event on call failure", function()
      manager:register("throws", function() error("oops") end)
      pcall(function() manager:call("throws") end)

      local has_error = false
      for _, e in ipairs(events) do
        if e.event == external_functions.EVENTS.ERROR then
          has_error = true
          break
        end
      end
      assert.is_true(has_error)
    end)

    it("removes listeners with off()", function()
      local callback = function() end
      manager:on(callback)
      manager:off(callback)
      -- Verify no errors
    end)
  end)

  describe("reset", function()
    it("clears all functions and history", function()
      local manager = external_functions.new()
      manager:register("greet", function() return "hello" end)
      manager:call("greet")

      manager:reset()

      assert.is_false(manager:has("greet"))
      assert.equals(0, #manager:get_history())
    end)
  end)
end)
