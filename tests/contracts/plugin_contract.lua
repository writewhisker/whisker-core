--- Plugin Contract Tests
-- Contract tests for IPlugin implementations
-- @module tests.contracts.plugin_contract
-- @author Whisker Core Team

local function run_plugin_contract_tests(plugin_factory, test_data)
  describe("IPlugin Contract", function()
    local plugin

    before_each(function()
      plugin = plugin_factory()
    end)

    describe("Metadata", function()
      it("should return valid name", function()
        local name = plugin:get_name()
        assert.is_string(name)
        assert.matches("^[%w_]+$", name)
      end)

      it("should return semantic version", function()
        local version = plugin:get_version()
        assert.is_string(version)
        assert.matches("^%d+%.%d+%.%d+", version)
      end)

      it("should return dependencies array", function()
        local deps = plugin:get_dependencies()
        assert.is_table(deps)

        for _, dep in ipairs(deps) do
          assert.is_string(dep.name)
          assert.is_true(dep.version == nil or type(dep.version) == "string")
        end
      end)
    end)

    describe("Lifecycle", function()
      it("should initialize with engine and context", function()
        local success, err = plugin:init(test_data.engine, test_data.context)
        assert.is_true(success)
        assert.is_nil(err)
      end)

      it("should handle init failure gracefully", function()
        local success, err = plugin:init(nil, nil)
        assert.is_false(success)
        assert.is_string(err)
      end)

      it("should destroy without error", function()
        plugin:init(test_data.engine, test_data.context)

        assert.has_no_error(function()
          plugin:destroy()
        end)
      end)

      it("should be idempotent for destroy", function()
        plugin:init(test_data.engine, test_data.context)
        plugin:destroy()

        assert.has_no_error(function()
          plugin:destroy()
        end)
      end)
    end)

    describe("API Exposure", function()
      it("should return nil or table from get_api", function()
        local api = plugin:get_api()
        assert.is_true(api == nil or type(api) == "table")
      end)

      it("should return consistent API object", function()
        local api1 = plugin:get_api()
        local api2 = plugin:get_api()

        if api1 then
          assert.equals(api1, api2)
        end
      end)
    end)

    describe("Hook Registration", function()
      it("should return hooks table", function()
        local hooks = plugin:get_hooks()
        assert.is_table(hooks)
      end)

      it("should map hook names to functions", function()
        local hooks = plugin:get_hooks()

        for hook_name, handler in pairs(hooks) do
          assert.is_string(hook_name)
          assert.is_function(handler)
        end
      end)

      it("should use standard hook names", function()
        local valid_hooks = {
          before_choice = true,
          after_choice = true,
          passage_enter = true,
          passage_exit = true,
          state_change = true,
          story_load = true,
          story_start = true,
          story_end = true,
        }

        local hooks = plugin:get_hooks()
        for hook_name in pairs(hooks) do
          assert.is_true(valid_hooks[hook_name],
            "Unknown hook: " .. hook_name)
        end
      end)
    end)
  end)
end

return {
  run_contract_tests = run_plugin_contract_tests,
  required_test_data = {
    "engine",
    "context",
  }
}
