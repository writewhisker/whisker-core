-- tests/core/modules_runtime_spec.lua
-- Tests for WLS 1.0 Modules Runtime: FUNCTION and NAMESPACE support

describe("ModulesRuntime", function()
    local ModulesRuntime

    setup(function()
        ModulesRuntime = require("whisker.core.modules_runtime")
    end)

    describe("new()", function()
        it("creates a new instance", function()
            local runtime = ModulesRuntime.new()
            assert.is_not_nil(runtime)
            assert.are.equal("", runtime:current_namespace())
        end)

        it("accepts a game_state parameter", function()
            local mock_game_state = { get_variable = function() end }
            local runtime = ModulesRuntime.new(mock_game_state)
            assert.are.equal(mock_game_state, runtime.game_state)
        end)
    end)

    describe("namespace management", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("starts at root namespace", function()
            assert.are.equal("", runtime:current_namespace())
        end)

        it("enters a namespace", function()
            runtime:enter_namespace("MyModule")
            assert.are.equal("MyModule", runtime:current_namespace())
        end)

        it("supports nested namespaces", function()
            runtime:enter_namespace("MyModule")
            runtime:enter_namespace("SubModule")
            assert.are.equal("MyModule.SubModule", runtime:current_namespace())
        end)

        it("exits a namespace", function()
            runtime:enter_namespace("MyModule")
            runtime:enter_namespace("SubModule")
            local exited = runtime:exit_namespace()
            assert.are.equal("SubModule", exited)
            assert.are.equal("MyModule", runtime:current_namespace())
        end)

        it("returns nil when exiting root namespace", function()
            local exited = runtime:exit_namespace()
            assert.is_nil(exited)
            assert.are.equal("", runtime:current_namespace())
        end)

        it("throws error on empty namespace name", function()
            assert.has_error(function()
                runtime:enter_namespace("")
            end, "Namespace name cannot be empty")
        end)
    end)

    describe("function definition", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("defines a function at root", function()
            local name = runtime:define_function("greet", {"name"}, "return 'Hello ' .. name")
            assert.are.equal("greet", name)
            assert.is_true(runtime:has_function("greet"))
        end)

        it("qualifies function name with namespace", function()
            runtime:enter_namespace("Utils")
            local name = runtime:define_function("greet", {"name"}, "return 'Hello ' .. name")
            assert.are.equal("Utils.greet", name)
            assert.is_true(runtime:has_function("Utils.greet"))
        end)

        it("qualifies with nested namespace", function()
            runtime:enter_namespace("Utils")
            runtime:enter_namespace("Strings")
            local name = runtime:define_function("format", {}, "return 'formatted'")
            assert.are.equal("Utils.Strings.format", name)
            assert.is_true(runtime:has_function("Utils.Strings.format"))
        end)

        it("throws error on empty function name", function()
            assert.has_error(function()
                runtime:define_function("", {}, "return 1")
            end, "Function name cannot be empty")
        end)
    end)

    describe("function lookup", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
            -- Define some functions
            runtime:define_function("globalFunc", {}, "return 'global'")
            runtime:enter_namespace("MyModule")
            runtime:define_function("moduleFunc", {}, "return 'module'")
            runtime:exit_namespace()
        end)

        it("finds global function by name", function()
            assert.is_true(runtime:has_function("globalFunc"))
        end)

        it("finds namespaced function by qualified name", function()
            assert.is_true(runtime:has_function("MyModule.moduleFunc"))
        end)

        it("resolves function from within namespace", function()
            runtime:enter_namespace("MyModule")
            -- Should find moduleFunc without qualification
            local resolved = runtime:resolve_name("moduleFunc")
            assert.are.equal("MyModule.moduleFunc", resolved)
        end)

        it("walks up to global when not found in namespace", function()
            runtime:enter_namespace("MyModule")
            local resolved = runtime:resolve_name("globalFunc")
            assert.are.equal("globalFunc", resolved)
        end)

        it("returns original name when not found", function()
            local resolved = runtime:resolve_name("nonexistent")
            assert.are.equal("nonexistent", resolved)
        end)
    end)

    describe("function calling", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("executes a simple Lua function", function()
            runtime:define_function("add", {"a", "b"}, "return a + b")
            -- Note: Without game_state, parameters won't be passed correctly
            -- This tests the basic execution path
            runtime.game_state = {
                variables = {},
                get_variable = function(self, name)
                    return self.variables[name]
                end,
                set_variable = function(self, name, value)
                    self.variables[name] = value
                end
            }
            local result = runtime:call_function("add", {5, 3})
            assert.are.equal(8, result)
        end)

        it("throws error for undefined function", function()
            assert.has_error(function()
                runtime:call_function("nonexistent", {})
            end, "Undefined function: nonexistent")
        end)

        it("restores variable values after call", function()
            runtime.game_state = {
                variables = { x = 100 },
                get_variable = function(self, name)
                    return self.variables[name]
                end,
                set_variable = function(self, name, value)
                    self.variables[name] = value
                end
            }

            runtime:define_function("setX", {"x"}, "return x * 2")
            runtime:call_function("setX", {5})

            -- x should be restored to original value
            assert.are.equal(100, runtime.game_state.variables.x)
        end)
    end)

    describe("list_functions()", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
            runtime:define_function("globalA", {}, "")
            runtime:define_function("globalB", {}, "")
            runtime:enter_namespace("NS")
            runtime:define_function("nsFunc", {}, "")
            runtime:exit_namespace()
        end)

        it("lists all functions", function()
            local funcs = runtime:list_functions()
            assert.are.equal(3, #funcs)
        end)

        it("filters by namespace", function()
            local funcs = runtime:list_functions("NS")
            assert.are.equal(1, #funcs)
            assert.are.equal("NS.nsFunc", funcs[1])
        end)

        it("returns sorted list", function()
            local funcs = runtime:list_functions()
            assert.are.equal("NS.nsFunc", funcs[1])
            assert.are.equal("globalA", funcs[2])
            assert.are.equal("globalB", funcs[3])
        end)
    end)

    describe("remove_function()", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
            runtime:define_function("myFunc", {}, "")
        end)

        it("removes an existing function", function()
            local removed = runtime:remove_function("myFunc")
            assert.is_true(removed)
            assert.is_false(runtime:has_function("myFunc"))
        end)

        it("returns false for non-existent function", function()
            local removed = runtime:remove_function("nonexistent")
            assert.is_false(removed)
        end)
    end)

    describe("include tracking", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("marks file as included", function()
            local ok = runtime:mark_included("utils.wls")
            assert.is_true(ok)
            assert.is_true(runtime:is_included("utils.wls"))
        end)

        it("returns false for already included file", function()
            runtime:mark_included("utils.wls")
            local ok = runtime:mark_included("utils.wls")
            assert.is_false(ok)
        end)

        it("tracks multiple files", function()
            runtime:mark_included("a.wls")
            runtime:mark_included("b.wls")
            assert.is_true(runtime:is_included("a.wls"))
            assert.is_true(runtime:is_included("b.wls"))
            assert.is_false(runtime:is_included("c.wls"))
        end)
    end)

    describe("reset()", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
            runtime:define_function("func", {}, "")
            runtime:enter_namespace("NS")
            runtime:mark_included("file.wls")
        end)

        it("clears all state", function()
            runtime:reset()
            assert.are.equal("", runtime:current_namespace())
            assert.is_false(runtime:has_function("func"))
            assert.is_false(runtime:is_included("file.wls"))
        end)
    end)

    describe("load_from_story()", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("loads functions from story", function()
            local story = {
                functions = {
                    greet = {
                        name = "greet",
                        params = {"name"},
                        body = "return 'Hello'"
                    }
                }
            }
            runtime:load_from_story(story)
            assert.is_true(runtime:has_function("greet"))
        end)

        it("handles nil story", function()
            assert.has_no.errors(function()
                runtime:load_from_story(nil)
            end)
        end)

        it("handles story without functions", function()
            local story = {}
            assert.has_no.errors(function()
                runtime:load_from_story(story)
            end)
        end)
    end)
end)
