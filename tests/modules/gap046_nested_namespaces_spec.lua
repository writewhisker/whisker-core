-- tests/modules/gap046_nested_namespaces_spec.lua
-- Tests for GAP-046: Nested Namespaces Support

describe("GAP-046: Nested Namespaces", function()
    local ModulesRuntime
    local WSParser

    setup(function()
        ModulesRuntime = require("whisker.core.modules_runtime")
        WSParser = require("whisker.parser.ws_parser")
    end)

    describe("WSParser namespace block parsing", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        it("parses simple namespace block", function()
            parser.content = [[NAMESPACE MyModule
:: Start
Hello World
END NAMESPACE]]
            parser.position = 1

            local result = parser:parse_namespace_block()

            assert.is_not_nil(result)
            assert.are.equal("namespace_declaration", result.type)
            assert.are.equal("MyModule", result.name)
            assert.are.equal("MyModule", result.full_name)
            assert.is_not_nil(result.passages.Start)
        end)

        it("parses nested namespace blocks", function()
            parser.content = [[NAMESPACE Outer
NAMESPACE Inner
:: DeepPassage
Content here
END NAMESPACE
END NAMESPACE]]
            parser.position = 1

            local result = parser:parse_namespace_block()

            assert.is_not_nil(result)
            assert.are.equal("Outer", result.name)
            assert.is_not_nil(result.nested_namespaces.Inner)
            assert.are.equal("Outer.Inner", result.nested_namespaces.Inner.full_name)
        end)

        it("parses functions in namespace", function()
            parser.content = [[NAMESPACE Utils
FUNCTION greet(name)
return "Hello " .. name
END
END NAMESPACE]]
            parser.position = 1

            local result = parser:parse_namespace_block()

            assert.is_not_nil(result)
            assert.is_not_nil(result.functions.greet)
            assert.are.equal("Utils.greet", result.functions.greet.qualified_name)
        end)

        it("generates correct qualified names for nested content", function()
            parser.content = [[NAMESPACE A
NAMESPACE B
:: Passage
Content
FUNCTION func()
body
END
END NAMESPACE
END NAMESPACE]]
            parser.position = 1

            local result = parser:parse_namespace_block()

            local inner = result.nested_namespaces.B
            assert.is_not_nil(inner)

            assert.are.equal("A.B.Passage", inner.passages.Passage.qualified_name)
            assert.are.equal("A.B.func", inner.functions.func.qualified_name)
        end)
    end)

    describe("ModulesRuntime namespace registration", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("registers simple namespace tree", function()
            local namespace = {
                full_name = "MyModule",
                passages = {
                    Start = { name = "Start", content = "Hello" }
                },
                functions = {
                    helper = { name = "helper", params = {}, body = "return 1" }
                },
                nested_namespaces = {}
            }

            runtime:register_namespace_tree(namespace)

            assert.is_not_nil(runtime.namespaces["MyModule"])
            assert.is_not_nil(runtime.all_passages["MyModule.Start"])
            assert.is_true(runtime:has_function("MyModule.helper"))
        end)

        it("registers nested namespace tree", function()
            local namespace = {
                full_name = "Outer",
                passages = {},
                functions = {},
                nested_namespaces = {
                    Inner = {
                        full_name = "Outer.Inner",
                        passages = {
                            Deep = { name = "Deep", content = "Nested content" }
                        },
                        functions = {
                            deep_func = { name = "deep_func", params = {}, body = "" }
                        },
                        nested_namespaces = {}
                    }
                }
            }

            runtime:register_namespace_tree(namespace)

            assert.is_not_nil(runtime.namespaces["Outer"])
            assert.is_not_nil(runtime.namespaces["Outer.Inner"])
            assert.is_not_nil(runtime.all_passages["Outer.Inner.Deep"])
            assert.is_true(runtime:has_function("Outer.Inner.deep_func"))
        end)
    end)

    describe("namespace context resolution", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()

            -- Set up namespace hierarchy
            runtime:enter_namespace("Level1")
            runtime:define_function("func1", {}, "return 1")
            runtime:enter_namespace("Level2")
            runtime:define_function("func2", {}, "return 2")
            runtime:enter_namespace("Level3")
            runtime:define_function("func3", {}, "return 3")
            runtime:exit_namespace()
            runtime:exit_namespace()
            runtime:exit_namespace()
        end)

        it("resolves functions at each level", function()
            assert.is_true(runtime:has_function("Level1.func1"))
            assert.is_true(runtime:has_function("Level1.Level2.func2"))
            assert.is_true(runtime:has_function("Level1.Level2.Level3.func3"))
        end)

        it("resolves from deep context", function()
            runtime:enter_namespace("Level1")
            runtime:enter_namespace("Level2")
            runtime:enter_namespace("Level3")

            -- Should find func2 walking up
            local resolved = runtime:resolve_name("func2")
            assert.are.equal("Level1.Level2.func2", resolved)

            -- Should find func1 walking up further
            resolved = runtime:resolve_name("func1")
            assert.are.equal("Level1.func1", resolved)
        end)

        it("prefers closer scope", function()
            -- Define same name at different levels
            runtime:enter_namespace("Test")
            runtime:define_function("common", {}, "return 'level1'")
            runtime:enter_namespace("Sub")
            runtime:define_function("common", {}, "return 'level2'")

            -- From Sub, should find Sub.common first
            local resolved = runtime:resolve_name("common")
            assert.are.equal("Test.Sub.common", resolved)
        end)
    end)

    describe("current namespace tracking", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("tracks current namespace path", function()
            assert.are.equal("", runtime:current_namespace())

            runtime:enter_namespace("A")
            assert.are.equal("A", runtime:current_namespace())

            runtime:enter_namespace("B")
            assert.are.equal("A.B", runtime:current_namespace())

            runtime:enter_namespace("C")
            assert.are.equal("A.B.C", runtime:current_namespace())
        end)

        it("handles exit_namespace correctly", function()
            runtime:enter_namespace("A")
            runtime:enter_namespace("B")
            runtime:enter_namespace("C")

            assert.are.equal("C", runtime:exit_namespace())
            assert.are.equal("A.B", runtime:current_namespace())

            assert.are.equal("B", runtime:exit_namespace())
            assert.are.equal("A", runtime:current_namespace())

            assert.are.equal("A", runtime:exit_namespace())
            assert.are.equal("", runtime:current_namespace())
        end)

        it("returns nil when exiting at root", function()
            assert.is_nil(runtime:exit_namespace())
            assert.are.equal("", runtime:current_namespace())
        end)
    end)

    describe("reset", function()
        local runtime

        before_each(function()
            runtime = ModulesRuntime.new()
        end)

        it("clears namespace state on reset", function()
            runtime:enter_namespace("Test")
            runtime:define_function("func", {}, "")

            local namespace = {
                full_name = "Registered",
                passages = { P = { name = "P" } },
                functions = {},
                nested_namespaces = {}
            }
            runtime:register_namespace_tree(namespace)

            runtime:reset()

            assert.are.equal("", runtime:current_namespace())
            assert.is_false(runtime:has_function("Test.func"))
            assert.is_nil(runtime.namespaces["Registered"])
            assert.is_nil(runtime.all_passages["Registered.P"])
        end)
    end)
end)
