-- spec/wls2/external_functions_spec.lua
-- Tests for WLS 2.0 External Functions

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("ExternalFunctions", function()
    local ExternalFunctions

    before_each(function()
        ExternalFunctions = require("whisker.wls2.external_functions")
    end)

    describe("parseDeclaration", function()
        it("parses simple declaration", function()
            local decl = ExternalFunctions.parseDeclaration("playSound(id: string): void")
            assert.equals("playSound", decl.name)
            assert.equals(1, #decl.params)
            assert.equals("id", decl.params[1].name)
            assert.equals("string", decl.params[1].type)
            assert.equals("void", decl.returnType)
        end)

        it("parses declaration without return type", function()
            local decl = ExternalFunctions.parseDeclaration("doSomething()")
            assert.equals("doSomething", decl.name)
            assert.equals(0, #decl.params)
            assert.equals("void", decl.returnType)
        end)

        it("parses multiple parameters", function()
            local decl = ExternalFunctions.parseDeclaration("setVolume(channel: string, volume: number): void")
            assert.equals("setVolume", decl.name)
            assert.equals(2, #decl.params)
            assert.equals("channel", decl.params[1].name)
            assert.equals("string", decl.params[1].type)
            assert.equals("volume", decl.params[2].name)
            assert.equals("number", decl.params[2].type)
        end)

        it("parses optional parameters", function()
            local decl = ExternalFunctions.parseDeclaration("log(message: string, level?: string): void")
            assert.equals(2, #decl.params)
            assert.is_false(decl.params[1].optional)
            assert.is_true(decl.params[2].optional)
        end)

        it("throws for empty declaration", function()
            assert.has_error(function()
                ExternalFunctions.parseDeclaration("")
            end)
        end)

        it("throws for invalid format", function()
            assert.has_error(function()
                ExternalFunctions.parseDeclaration("invalid")
            end)
        end)
    end)

    describe("registry", function()
        local registry

        before_each(function()
            registry = ExternalFunctions.new()
        end)

        it("creates a new registry", function()
            assert.is_not_nil(registry)
        end)

        it("registers a function", function()
            registry:register("test", function() return "hello" end)
            assert.is_true(registry:has("test"))
        end)

        it("calls a registered function", function()
            registry:register("add", function(a, b)
                return a + b
            end)

            local result = registry:call("add", {2, 3})
            assert.equals(5, result)
        end)

        it("throws for unregistered function", function()
            assert.has_error(function()
                registry:call("nonexistent", {})
            end)
        end)

        it("throws for invalid function name", function()
            assert.has_error(function()
                registry:register("", function() end)
            end)
        end)

        it("throws for non-function handler", function()
            assert.has_error(function()
                registry:register("test", "not a function")
            end)
        end)

        it("validates arguments against declaration", function()
            registry:register("greet", function(name)
                return "Hello, " .. name
            end)
            registry:declare("greet(name: string): string")

            -- Should work with string
            local result = registry:call("greet", {"World"})
            assert.equals("Hello, World", result)

            -- Should fail with wrong type
            assert.has_error(function()
                registry:call("greet", {123})
            end)
        end)

        it("validates argument count", function()
            registry:register("add", function(a, b) return a + b end)
            registry:declare("add(a: number, b: number): number")

            -- Too few arguments
            assert.has_error(function()
                registry:call("add", {1})
            end)

            -- Too many arguments
            assert.has_error(function()
                registry:call("add", {1, 2, 3})
            end)
        end)

        it("allows optional parameters", function()
            registry:register("log", function(msg, level)
                return (level or "info") .. ": " .. msg
            end)
            registry:declare("log(message: string, level?: string): string")

            -- Without optional
            local r1 = registry:call("log", {"test"})
            assert.equals("info: test", r1)

            -- With optional
            local r2 = registry:call("log", {"test", "warn"})
            assert.equals("warn: test", r2)
        end)

        it("returns registered function names", function()
            registry:register("a", function() end)
            registry:register("b", function() end)
            registry:register("c", function() end)

            local names = registry:getRegisteredNames()
            assert.equals(3, #names)
            assert.equals("a", names[1])
            assert.equals("b", names[2])
            assert.equals("c", names[3])
        end)

        it("clears all functions", function()
            registry:register("test", function() end)
            assert.is_true(registry:has("test"))

            registry:clear()
            assert.is_false(registry:has("test"))
        end)
    end)
end)
