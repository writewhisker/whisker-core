-- tests/modules/gap045_qualified_names_spec.lua
-- Tests for GAP-045: Qualified Names Support

describe("GAP-045: Qualified Names", function()
    local ModulesRuntime
    local WSParser

    setup(function()
        ModulesRuntime = require("whisker.core.modules_runtime")
        WSParser = require("whisker.parser.ws_parser")
    end)

    describe("ModulesRuntime qualified name parsing", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("parses simple qualified name", function()
            local parsed = runtime:parse_qualified_name("Namespace.Function")

            assert.is_not_nil(parsed)
            assert.are.equal("Namespace.Function", parsed.full_name)
            assert.are.equal("Namespace", parsed.namespace)
            assert.are.equal("Function", parsed.name)
            assert.are.same({"Namespace", "Function"}, parsed.parts)
        end)

        it("parses deeply nested qualified name", function()
            local parsed = runtime:parse_qualified_name("A.B.C.D.E")

            assert.is_not_nil(parsed)
            assert.are.equal("A.B.C.D.E", parsed.full_name)
            assert.are.equal("A.B.C.D", parsed.namespace)
            assert.are.equal("E", parsed.name)
            assert.are.same({"A", "B", "C", "D", "E"}, parsed.parts)
        end)

        it("parses simple name with empty namespace", function()
            local parsed = runtime:parse_qualified_name("SimpleName")

            assert.is_not_nil(parsed)
            assert.are.equal("SimpleName", parsed.full_name)
            assert.are.equal("", parsed.namespace)
            assert.are.equal("SimpleName", parsed.name)
            assert.are.same({"SimpleName"}, parsed.parts)
        end)

        it("returns nil for empty string", function()
            local parsed = runtime:parse_qualified_name("")
            assert.is_nil(parsed)
        end)

        it("handles names with underscores", function()
            local parsed = runtime:parse_qualified_name("My_Namespace.my_function")

            assert.is_not_nil(parsed)
            assert.are.equal("My_Namespace", parsed.namespace)
            assert.are.equal("my_function", parsed.name)
        end)
    end)

    describe("WSParser qualified name parsing", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        it("parses qualified name in content", function()
            parser.content = "Namespace.Function more text"
            parser.position = 1

            local result = parser:parse_qualified_name()

            assert.is_not_nil(result)
            assert.are.equal("qualified_name", result.type)
            assert.are.equal("Namespace.Function", result.full_name)
            assert.are.equal("Namespace", result.namespace)
            assert.are.equal("Function", result.name)
        end)

        it("advances position correctly", function()
            parser.content = "A.B.C rest"
            parser.position = 1

            parser:parse_qualified_name()

            assert.are.equal(6, parser.position) -- After "A.B.C"
        end)

        it("returns nil when no qualified name present", function()
            parser.content = "simple_name"
            parser.position = 1

            local result = parser:parse_qualified_name()
            assert.is_nil(result)
        end)
    end)

    describe("qualified name resolution", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()

            -- Set up some namespaces and functions
            runtime:enter_namespace("Utils")
            runtime:define_function("helper", {}, "return 1")
            runtime:enter_namespace("Strings")
            runtime:define_function("format", {}, "return 2")
            runtime:exit_namespace()
            runtime:exit_namespace()

            runtime:define_function("global_func", {}, "return 0")
        end)

        it("resolves fully qualified function name", function()
            assert.is_true(runtime:has_function("Utils.helper"))
            assert.is_true(runtime:has_function("Utils.Strings.format"))
        end)

        it("resolves in current namespace context", function()
            runtime:enter_namespace("Utils")
            local resolved = runtime:resolve_name("helper")
            assert.are.equal("Utils.helper", resolved)
        end)

        it("walks up namespace hierarchy", function()
            runtime:enter_namespace("Utils")
            runtime:enter_namespace("Strings")

            -- Should find Utils.helper from Utils.Strings context
            local resolved = runtime:resolve_name("helper")
            assert.are.equal("Utils.helper", resolved)
        end)

        it("falls back to global scope", function()
            runtime:enter_namespace("Utils")
            local resolved = runtime:resolve_name("global_func")
            assert.are.equal("global_func", resolved)
        end)
    end)

    describe("resolve_qualified_name", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()

            -- Register a namespace tree
            local namespace = {
                full_name = "MyModule",
                passages = {
                    Start = { name = "Start", content = "Hello" }
                },
                functions = {
                    helper = { name = "helper", body = "return 1" }
                },
                nested_namespaces = {}
            }

            runtime:register_namespace_tree(namespace)
        end)

        it("resolves passage by qualified name", function()
            local passage = runtime:resolve_qualified_name("MyModule.Start", "passage")
            assert.is_not_nil(passage)
            assert.are.equal("Start", passage.name)
        end)

        it("resolves function by qualified name", function()
            local func = runtime:resolve_qualified_name("MyModule.helper", "function")
            assert.is_not_nil(func)
            assert.are.equal("helper", func.name)
        end)

        it("returns nil for non-existent name", function()
            local result = runtime:resolve_qualified_name("NonExistent.Thing")
            assert.is_nil(result)
        end)
    end)
end)
