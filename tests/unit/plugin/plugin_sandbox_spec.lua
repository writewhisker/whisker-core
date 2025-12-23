--- Plugin Sandbox Tests
-- @module tests.unit.plugin.plugin_sandbox_spec

describe("PluginSandbox", function()
  local PluginSandbox
  local sandbox

  before_each(function()
    package.loaded["whisker.plugin.plugin_sandbox"] = nil
    PluginSandbox = require("whisker.plugin.plugin_sandbox")
    sandbox = PluginSandbox.new()
  end)

  describe("new()", function()
    it("creates sandbox with default config", function()
      assert.is_not_nil(sandbox)
      local config = sandbox:get_config()
      assert.equal(PluginSandbox.DEFAULT_TIMEOUT_MS, config.timeout_ms)
    end)

    it("accepts custom config", function()
      local custom = PluginSandbox.new({
        timeout_ms = 500,
        allowed_modules = {"json"},
      })
      local config = custom:get_config()
      assert.equal(500, config.timeout_ms)
      assert.equal(1, #config.allowed_modules)
    end)
  end)

  describe("create_environment()", function()
    local mock_context

    before_each(function()
      mock_context = {
        name = "test-plugin",
        version = "1.0.0",
        log = {
          info = function() end,
          warn = function() end,
        },
        state = {},
        storage = {},
        plugins = {},
        hooks = {},
      }
    end)

    it("includes safe globals", function()
      local env = sandbox:create_environment(mock_context)

      -- Type checking
      assert.is_not_nil(env.type)
      assert.is_not_nil(env.tonumber)
      assert.is_not_nil(env.tostring)

      -- Error handling
      assert.is_not_nil(env["assert"])  -- 'assert' is also busted function
      assert.is_not_nil(env.error)
      assert.is_not_nil(env.pcall)

      -- Iteration
      assert.is_not_nil(env.pairs)
      assert.is_not_nil(env.ipairs)
      assert.is_not_nil(env.next)
    end)

    it("includes math library", function()
      local env = sandbox:create_environment(mock_context)
      assert.is_not_nil(env.math)
      assert.equal(math.sqrt, env.math.sqrt)
      assert.equal(math.floor, env.math.floor)
    end)

    it("includes string library", function()
      local env = sandbox:create_environment(mock_context)
      assert.is_not_nil(env.string)
      assert.equal(string.upper, env.string.upper)
      assert.equal(string.format, env.string.format)
    end)

    it("includes partial table library", function()
      local env = sandbox:create_environment(mock_context)
      assert.is_not_nil(env.table)
      assert.is_not_nil(env.table.insert)
      assert.is_not_nil(env.table.remove)
      assert.is_not_nil(env.table.concat)
    end)

    it("excludes dangerous globals", function()
      local env = sandbox:create_environment(mock_context)

      -- These should not be accessible (metatable will error)
      assert.is_nil(rawget(env, "io"))
      assert.is_nil(rawget(env, "os"))
      assert.is_nil(rawget(env, "debug"))
      assert.is_nil(rawget(env, "package"))
      assert.is_nil(rawget(env, "dofile"))
      assert.is_nil(rawget(env, "loadfile"))
      assert.is_nil(rawget(env, "require"))  -- Unless explicitly allowed
    end)

    it("errors on undefined global access", function()
      local env = sandbox:create_environment(mock_context)

      local success, err = pcall(function()
        local _ = env.io
      end)
      assert.is_false(success)
      assert.is_true(tostring(err):match("undefined global 'io'") ~= nil)
    end)

    it("errors on global creation", function()
      local env = sandbox:create_environment(mock_context)

      local success, err = pcall(function()
        env.myGlobal = "value"
      end)
      assert.is_false(success)
      assert.is_true(tostring(err):match("Attempt to create global 'myGlobal'") ~= nil)
    end)

    it("provides print function routed to logger", function()
      local logged_message
      mock_context.log.info = function(msg)
        logged_message = msg
      end

      local env = sandbox:create_environment(mock_context)
      env.print("test message")

      assert.equal("test message", logged_message)
    end)

    it("provides warn function routed to logger", function()
      local logged_message
      mock_context.log.warn = function(msg)
        logged_message = msg
      end

      local env = sandbox:create_environment(mock_context)
      env.warn("warning message")

      assert.equal("warning message", logged_message)
    end)

    it("provides whisker global with context", function()
      local env = sandbox:create_environment(mock_context)

      assert.is_not_nil(env.whisker)
      assert.equal("test-plugin", env.whisker.name)
      assert.equal("1.0.0", env.whisker.version)
      assert.is_not_nil(env.whisker.state)
      assert.is_not_nil(env.whisker.log)
    end)
  end)

  describe("safe require", function()
    it("blocks require when no modules allowed", function()
      local env = sandbox:create_environment({name = "test"})
      assert.is_nil(rawget(env, "require"))
    end)

    it("provides require when modules allowed", function()
      local sandbox_with_require = PluginSandbox.new({
        allowed_modules = {"string"},
      })
      local env = sandbox_with_require:create_environment({name = "test"})

      assert.is_not_nil(env.require)
      local str = env.require("string")
      assert.equal(string, str)
    end)

    it("blocks non-whitelisted modules", function()
      local sandbox_with_require = PluginSandbox.new({
        allowed_modules = {"string"},
      })
      local env = sandbox_with_require:create_environment({name = "test"})

      assert.has_error(function()
        env.require("io")
      end)
    end)
  end)

  describe("load_code()", function()
    it("compiles valid Lua code", function()
      local env = sandbox:create_environment({name = "test"})
      local code = "local x = 1 + 2; return x"

      local chunk, err = sandbox:load_code(code, "test", env)
      assert.is_not_nil(chunk)
      assert.is_nil(err)
    end)

    it("returns error for syntax errors", function()
      local env = sandbox:create_environment({name = "test"})
      local code = "local x = (("  -- Invalid syntax

      local chunk, err = sandbox:load_code(code, "test", env)
      assert.is_nil(chunk)
      assert.is_not_nil(err)
      assert.is_true(err:match("Compilation error") ~= nil)
    end)

    it("compiled code runs in sandbox environment", function()
      local env = sandbox:create_environment({name = "test"})
      local code = "return math.sqrt(16)"

      local chunk = sandbox:load_code(code, "test", env)
      local result = chunk()
      assert.equal(4, result)
    end)

    it("compiled code cannot access blocked globals", function()
      local env = sandbox:create_environment({name = "test"})
      local code = "return io.open('/etc/passwd')"

      local chunk = sandbox:load_code(code, "test", env)
      local success, err = pcall(chunk)
      assert.is_false(success)
      assert.is_true(err:match("undefined global 'io'") ~= nil)
    end)
  end)

  describe("execute_with_timeout()", function()
    it("executes function and returns result", function()
      local fn = function(a, b) return a + b end

      local success, result = sandbox:execute_with_timeout(fn, 100, 2, 3)
      assert.is_true(success)
      assert.equal(5, result)
    end)

    it("catches errors", function()
      local fn = function() error("test error") end

      local success, result = sandbox:execute_with_timeout(fn, 100)
      assert.is_false(success)
      assert.is_true(tostring(result):match("test error") ~= nil)
    end)

    it("times out on long-running code", function()
      local fn = function()
        local x = 0
        while true do
          x = x + 1
        end
      end

      local success, result = sandbox:execute_with_timeout(fn, 50)
      assert.is_false(success)
      assert.is_true(tostring(result):match("timeout") ~= nil or tostring(result):match("Timeout") ~= nil)
    end)

    it("respects timeout disabled setting", function()
      sandbox:set_timeout_enabled(false)

      local called = false
      local fn = function()
        called = true
        return "done"
      end

      local success, result = sandbox:execute_with_timeout(fn, 1)
      assert.is_true(success)
      assert.equal("done", result)
      assert.is_true(called)
    end)
  end)

  describe("load_plugin()", function()
    local mock_context

    before_each(function()
      mock_context = {
        name = "test-plugin",
        version = "1.0.0",
        log = {info = function() end, warn = function() end},
        state = {},
        storage = {},
        plugins = {},
        hooks = {},
      }
    end)

    it("loads valid plugin code", function()
      local code = [[
        return {
          name = "test",
          version = "1.0.0",
          api = {
            hello = function() return "world" end,
          },
        }
      ]]

      local result, err = sandbox:load_plugin(code, "test", mock_context, 100)
      assert.is_not_nil(result)
      assert.is_nil(err)
      assert.equal("test", result.name)
      assert.equal("1.0.0", result.version)
    end)

    it("returns error for invalid code", function()
      local code = "return ((("  -- Syntax error

      local result, err = sandbox:load_plugin(code, "test", mock_context, 100)
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it("returns error for non-table return", function()
      local code = "return 'not a table'"

      local result, err = sandbox:load_plugin(code, "test", mock_context, 100)
      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.is_true(err:match("must return table") ~= nil)
    end)

    it("plugin code can use safe libraries", function()
      local code = [[
        local result = math.sqrt(16)
        local text = string.upper("hello")
        local tbl = {1, 2, 3}
        table.insert(tbl, 4)

        return {
          name = "safe",
          version = "1.0.0",
          data = {result = result, text = text, tbl = tbl},
        }
      ]]

      local result = sandbox:load_plugin(code, "safe", mock_context, 100)
      assert.is_not_nil(result)
      assert.equal(4, result.data.result)
      assert.equal("HELLO", result.data.text)
      assert.equal(4, #result.data.tbl)
    end)

    it("plugin code cannot access io", function()
      local code = [[
        local file = io.open("/etc/passwd")
        return {name = "bad", version = "1.0.0"}
      ]]

      local result, err = sandbox:load_plugin(code, "bad", mock_context, 100)
      assert.is_nil(result)
      assert.is_true(err:match("undefined global 'io'") ~= nil)
    end)

    it("plugin code cannot access os", function()
      local code = [[
        os.execute("rm -rf /")
        return {name = "bad", version = "1.0.0"}
      ]]

      local result, err = sandbox:load_plugin(code, "bad", mock_context, 100)
      assert.is_nil(result)
      assert.is_true(err:match("undefined global 'os'") ~= nil)
    end)

    it("plugin code cannot access debug", function()
      local code = [[
        local info = debug.getinfo(1)
        return {name = "bad", version = "1.0.0"}
      ]]

      local result, err = sandbox:load_plugin(code, "bad", mock_context, 100)
      assert.is_nil(result)
      assert.is_true(err:match("undefined global 'debug'") ~= nil)
    end)

    it("plugin code cannot create globals", function()
      local code = [[
        myGlobal = "leaked"
        return {name = "bad", version = "1.0.0"}
      ]]

      local result, err = sandbox:load_plugin(code, "bad", mock_context, 100)
      assert.is_nil(result)
      assert.is_true(err:match("Attempt to create global") ~= nil)
    end)
  end)

  describe("is_trusted()", function()
    it("returns true for trusted plugins", function()
      local plugin = {name = "test", _trusted = true}
      assert.is_true(PluginSandbox.is_trusted(plugin))
    end)

    it("returns false for untrusted plugins", function()
      local plugin = {name = "test"}
      assert.is_false(PluginSandbox.is_trusted(plugin))
    end)

    it("returns false for explicitly untrusted", function()
      local plugin = {name = "test", _trusted = false}
      assert.is_false(PluginSandbox.is_trusted(plugin))
    end)
  end)

  describe("wrap_function()", function()
    it("wraps function with timeout", function()
      local fn = function(x) return x * 2 end
      local wrapped = sandbox:wrap_function(fn, 100)

      local result = wrapped(5)
      assert.equal(10, result)
    end)

    it("wrapped function throws on timeout", function()
      local fn = function()
        while true do end
      end
      local wrapped = sandbox:wrap_function(fn, 50)

      assert.has_error(function()
        wrapped()
      end)
    end)
  end)

  describe("configuration methods", function()
    it("set_timeout changes timeout", function()
      sandbox:set_timeout(200)
      assert.equal(200, sandbox:get_config().timeout_ms)
    end)

    it("set_timeout_enabled changes enabled state", function()
      sandbox:set_timeout_enabled(false)
      assert.is_false(sandbox:get_config().enable_timeout)
    end)

    it("allow_module adds module to whitelist", function()
      sandbox:allow_module("json")
      local config = sandbox:get_config()
      assert.equal(1, #config.allowed_modules)
      assert.equal("json", config.allowed_modules[1])
    end)
  end)
end)
