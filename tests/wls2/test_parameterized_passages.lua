-- spec/wls2/parameterized_passages_spec.lua
-- Tests for WLS 2.0 Parameterized Passages

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("ParameterizedPassages", function()
    local ParameterizedPassages

    before_each(function()
        ParameterizedPassages = require("whisker.wls2.parameterized_passages")
    end)

    describe("parsePassageHeader", function()
        it("parses simple passage name", function()
            local header = ParameterizedPassages.parsePassageHeader("Start")
            assert.equals("Start", header.name)
            assert.equals(0, #header.params)
        end)

        it("parses passage with single parameter", function()
            local header = ParameterizedPassages.parsePassageHeader("Greet(name)")
            assert.equals("Greet", header.name)
            assert.equals(1, #header.params)
            assert.equals("name", header.params[1].name)
            assert.is_nil(header.params[1].default)
        end)

        it("parses passage with multiple parameters", function()
            local header = ParameterizedPassages.parsePassageHeader("ShowItem(name, price, quality)")
            assert.equals("ShowItem", header.name)
            assert.equals(3, #header.params)
            assert.equals("name", header.params[1].name)
            assert.equals("price", header.params[2].name)
            assert.equals("quality", header.params[3].name)
        end)

        it("parses parameter with string default", function()
            local header = ParameterizedPassages.parsePassageHeader('Greet(name, title = "friend")')
            assert.equals(2, #header.params)
            assert.equals("name", header.params[1].name)
            assert.is_nil(header.params[1].default)
            assert.equals("title", header.params[2].name)
            assert.equals("friend", header.params[2].default)
        end)

        it("parses parameter with number default", function()
            local header = ParameterizedPassages.parsePassageHeader("Config(count = 10)")
            assert.equals(1, #header.params)
            assert.equals("count", header.params[1].name)
            assert.equals(10, header.params[1].default)
        end)

        it("parses parameter with boolean default", function()
            local header = ParameterizedPassages.parsePassageHeader("Check(flag = true)")
            assert.equals(1, #header.params)
            assert.equals("flag", header.params[1].name)
            assert.is_true(header.params[1].default)
        end)

        it("throws for empty header", function()
            assert.has_error(function()
                ParameterizedPassages.parsePassageHeader("")
            end)
        end)

        it("throws for invalid header", function()
            assert.has_error(function()
                ParameterizedPassages.parsePassageHeader("invalid-name")  -- hyphens not allowed
            end)
        end)
    end)

    describe("parsePassageCall", function()
        it("parses simple call", function()
            local call = ParameterizedPassages.parsePassageCall("Start")
            assert.equals("Start", call.target)
            assert.equals(0, #call.args)
        end)

        it("parses call with string argument", function()
            local call = ParameterizedPassages.parsePassageCall('Greet("Alice")')
            assert.equals("Greet", call.target)
            assert.equals(1, #call.args)
            assert.equals("Alice", call.args[1])
        end)

        it("parses call with multiple arguments", function()
            local call = ParameterizedPassages.parsePassageCall('ShowItem("sword", 100, "excellent")')
            assert.equals("ShowItem", call.target)
            assert.equals(3, #call.args)
            assert.equals("sword", call.args[1])
            assert.equals(100, call.args[2])
            assert.equals("excellent", call.args[3])
        end)

        it("parses call with boolean arguments", function()
            local call = ParameterizedPassages.parsePassageCall("Check(true, false)")
            assert.equals(2, #call.args)
            assert.is_true(call.args[1])
            assert.is_false(call.args[2])
        end)

        it("parses call with variable reference", function()
            local call = ParameterizedPassages.parsePassageCall("Greet($playerName)")
            assert.equals(1, #call.args)
            assert.equals("variable_ref", call.args[1]._type)
            assert.equals("playerName", call.args[1].name)
        end)

        it("throws for empty call", function()
            assert.has_error(function()
                ParameterizedPassages.parsePassageCall("")
            end)
        end)
    end)

    describe("manager", function()
        local manager

        before_each(function()
            manager = ParameterizedPassages.new()
        end)

        it("creates a new manager", function()
            assert.is_not_nil(manager)
        end)

        it("registers a passage", function()
            manager:registerPassage("Greet", {
                { name = "name" }
            })
            assert.is_true(manager:hasPassage("Greet"))
        end)

        it("gets passage params", function()
            manager:registerPassage("Greet", {
                { name = "name" },
                { name = "title", default = "friend" }
            })

            local params = manager:getPassageParams("Greet")
            assert.equals(2, #params)
            assert.equals("name", params[1].name)
            assert.equals("title", params[2].name)
        end)

        it("binds arguments to parameters", function()
            manager:registerPassage("Greet", {
                { name = "name" },
                { name = "title", default = "friend" }
            })

            local result = manager:bindArguments("Greet", {"Alice"})
            assert.equals("Greet", result.passageName)
            assert.equals("Alice", result.bindings.name)
            assert.equals("friend", result.bindings.title)  -- Uses default
        end)

        it("overrides default with provided argument", function()
            manager:registerPassage("Greet", {
                { name = "name" },
                { name = "title", default = "friend" }
            })

            local result = manager:bindArguments("Greet", {"Bob", "Sir"})
            assert.equals("Bob", result.bindings.name)
            assert.equals("Sir", result.bindings.title)  -- Overridden
        end)

        it("throws for missing required argument", function()
            manager:registerPassage("Greet", {
                { name = "name" },
                { name = "title" }  -- No default = required
            })

            assert.has_error(function()
                manager:bindArguments("Greet", {"Alice"})  -- Missing title
            end)
        end)

        it("throws for too many arguments", function()
            manager:registerPassage("Greet", {
                { name = "name" }
            })

            assert.has_error(function()
                manager:bindArguments("Greet", {"Alice", "extra"})
            end)
        end)

        it("creates variable scope from bindings", function()
            local bindings = {
                name = "Alice",
                count = 42,
                active = true
            }

            local scope = manager:createVariableScope(bindings)
            assert.equals("Alice", scope.name)
            assert.equals(42, scope.count)
            assert.is_true(scope.active)
        end)

        it("resolves variable references", function()
            local variables = {
                playerName = "Alice",
                health = 100
            }

            local args = {
                { _type = "variable_ref", name = "playerName" },
                "literal",
                { _type = "variable_ref", name = "health" }
            }

            local resolved = manager:resolveVariables(args, variables)
            assert.equals("Alice", resolved[1])
            assert.equals("literal", resolved[2])
            assert.equals(100, resolved[3])
        end)

        it("returns registered passage names", function()
            manager:registerPassage("A", {})
            manager:registerPassage("B", {})
            manager:registerPassage("C", {})

            local names = manager:getRegisteredNames()
            assert.equals(3, #names)
            assert.equals("A", names[1])
            assert.equals("B", names[2])
            assert.equals("C", names[3])
        end)

        it("clears all passages", function()
            manager:registerPassage("Test", {})
            assert.is_true(manager:hasPassage("Test"))

            manager:clear()
            assert.is_false(manager:hasPassage("Test"))
        end)
    end)
end)
