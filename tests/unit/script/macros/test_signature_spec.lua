--- MacroSignature Unit Tests
-- Comprehensive unit tests for the MacroSignature module
-- @module tests.unit.script.macros.test_signature_spec
-- @author Whisker Core Team

describe("MacroSignature", function()
    local MacroSignature

    setup(function()
        MacroSignature = require("whisker.script.macros.signature")
    end)

    describe("initialization", function()
        it("creates empty signature", function()
            local sig = MacroSignature.new()

            assert.is_not_nil(sig)
            assert.equals(0, sig:get_min_args())
            assert.equals(0, sig:get_max_args())
        end)

        it("creates signature with params", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string" },
                { name = "count", type = "number" },
            })

            assert.equals(2, sig:get_min_args())
            assert.equals(2, sig:get_max_args())
        end)

        it("exports TYPE constants", function()
            assert.equals("any", MacroSignature.TYPE.ANY)
            assert.equals("string", MacroSignature.TYPE.STRING)
            assert.equals("number", MacroSignature.TYPE.NUMBER)
            assert.equals("boolean", MacroSignature.TYPE.BOOLEAN)
            assert.equals("table", MacroSignature.TYPE.TABLE)
            assert.equals("function", MacroSignature.TYPE.FUNCTION)
            assert.equals("nil", MacroSignature.TYPE.NIL)
            assert.equals("array", MacroSignature.TYPE.ARRAY)
            assert.equals("datamap", MacroSignature.TYPE.DATAMAP)
        end)

        it("exports MODIFIER constants", function()
            assert.equals("optional", MacroSignature.MODIFIER.OPTIONAL)
            assert.equals("rest", MacroSignature.MODIFIER.REST)
            assert.equals("spread", MacroSignature.MODIFIER.SPREAD)
            assert.equals("named", MacroSignature.MODIFIER.NAMED)
        end)
    end)

    describe("from_string", function()
        it("parses empty string", function()
            local sig = MacroSignature.from_string("")

            assert.equals(0, sig:get_min_args())
        end)

        it("parses single parameter", function()
            local sig = MacroSignature.from_string("value:string")

            assert.equals(1, sig:get_min_args())
            local param = sig:get_param(1)
            assert.equals("value", param.name)
            assert.equals("string", param.type)
        end)

        it("parses multiple parameters", function()
            local sig = MacroSignature.from_string("name:string, age:number, active:boolean")

            assert.equals(3, sig:get_min_args())
        end)

        it("parses optional parameter with ?", function()
            local sig = MacroSignature.from_string("required:string, optional?:number")

            assert.equals(1, sig:get_min_args())
            assert.equals(2, sig:get_max_args())
        end)

        it("parses optional on type", function()
            local sig = MacroSignature.from_string("value:string?")

            assert.equals(0, sig:get_min_args())
            local param = sig:get_param(1)
            assert.is_true(param.optional)
        end)

        it("parses rest parameter", function()
            local sig = MacroSignature.from_string("first:string, ...rest:any")

            assert.equals(1, sig:get_min_args())
            assert.equals(math.huge, sig:get_max_args())
            assert.is_true(sig:has_rest())
        end)

        it("defaults type to any", function()
            local sig = MacroSignature.from_string("value")

            local param = sig:get_param(1)
            assert.equals("any", param.type)
        end)
    end)

    describe("builder", function()
        it("creates empty signature", function()
            local sig = MacroSignature.builder():build()

            assert.equals(0, sig:get_min_args())
        end)

        it("adds required parameters", function()
            local sig = MacroSignature.builder()
                :required("name", "string", "The name")
                :required("value", "number", "The value")
                :build()

            assert.equals(2, sig:get_min_args())
        end)

        it("adds optional parameters", function()
            local sig = MacroSignature.builder()
                :required("name", "string")
                :optional("count", "number", 1, "Default is 1")
                :build()

            assert.equals(1, sig:get_min_args())
            assert.equals(2, sig:get_max_args())
        end)

        it("adds rest parameter", function()
            local sig = MacroSignature.builder()
                :required("first", "string")
                :rest("others", "any")
                :build()

            assert.is_true(sig:has_rest())
        end)

        it("adds named parameters", function()
            local sig = MacroSignature.builder()
                :required("value", "any")
                :named("via", "string", { optional = true })
                :build()

            local named = sig:get_named_params()
            assert.is_not_nil(named.via)
        end)

        it("supports chaining", function()
            local sig = MacroSignature.builder()
                :param("a", "string")
                :param("b", "number")
                :param("c", "boolean")
                :build()

            assert.equals(3, sig:get_min_args())
        end)
    end)

    describe("add_param", function()
        it("adds parameter to signature", function()
            local sig = MacroSignature.new()
            sig:add_param({ name = "value", type = "string" })

            assert.equals(1, sig:get_min_args())
        end)

        it("defaults name to arg1, arg2, etc", function()
            local sig = MacroSignature.new()
            sig:add_param({ type = "string" })
            sig:add_param({ type = "number" })

            assert.equals("arg1", sig:get_param(1).name)
            assert.equals("arg2", sig:get_param(2).name)
        end)

        it("supports chaining", function()
            local sig = MacroSignature.new()
            sig:add_param({ name = "a" })
               :add_param({ name = "b" })

            assert.equals(2, sig:get_min_args())
        end)

        it("only allows one rest parameter", function()
            local sig = MacroSignature.new()
            sig:add_param({ name = "rest1", rest = true })

            assert.has_error(function()
                sig:add_param({ name = "rest2", rest = true })
            end)
        end)

        it("adds named parameter to separate collection", function()
            local sig = MacroSignature.new()
            sig:add_param({ name = "positional", type = "string" })
            sig:add_param({ name = "named", type = "number", named = true })

            assert.equals(1, sig:get_min_args()) -- Named doesn't affect min
            local named = sig:get_named_params()
            assert.is_not_nil(named.named)
        end)
    end)

    describe("get_param", function()
        local sig

        before_each(function()
            sig = MacroSignature.new({
                { name = "first", type = "string" },
                { name = "second", type = "number" },
            })
        end)

        it("gets param by index", function()
            local param = sig:get_param(1)

            assert.equals("first", param.name)
            assert.equals("string", param.type)
        end)

        it("returns nil for invalid index", function()
            local param = sig:get_param(99)

            assert.is_nil(param)
        end)

        it("gets param by name", function()
            local param = sig:get_param_by_name("second")

            assert.equals("second", param.name)
            assert.equals("number", param.type)
        end)

        it("returns nil for invalid name", function()
            local param = sig:get_param_by_name("nonexistent")

            assert.is_nil(param)
        end)

        it("gets named param by name", function()
            sig:add_param({ name = "namedParam", type = "boolean", named = true })

            local param = sig:get_param_by_name("namedParam")
            assert.equals("namedParam", param.name)
        end)
    end)

    describe("validation", function()
        describe("argument count", function()
            it("validates minimum arguments", function()
                local sig = MacroSignature.new({
                    { name = "a", type = "any" },
                    { name = "b", type = "any" },
                })

                local valid, result = sig:validate({ "only one" })

                assert.is_false(valid)
                -- Both argument count error and missing param error
                assert.is_true(#result.errors >= 1)
                -- Check that at least one is MISSING_ARGUMENT
                local found_missing = false
                for _, err in ipairs(result.errors) do
                    if err.type == "MISSING_ARGUMENT" then
                        found_missing = true
                        break
                    end
                end
                assert.is_true(found_missing)
            end)

            it("validates maximum arguments", function()
                local sig = MacroSignature.new({
                    { name = "a", type = "any" },
                })

                local valid, result = sig:validate({ "one", "two", "three" })

                assert.is_false(valid)
                assert.equals("TOO_MANY_ARGUMENTS", result.errors[1].type)
            end)

            it("allows unlimited with rest parameter", function()
                local sig = MacroSignature.from_string("first:any, ...rest:any")

                local valid = sig:validate({ "a", "b", "c", "d", "e" })

                assert.is_true(valid)
            end)
        end)

        describe("type checking", function()
            it("validates string type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "string" },
                })

                assert.is_true(sig:validate({ "hello" }))
                local valid, result = sig:validate({ 123 })
                assert.is_false(valid)
                assert.equals("TYPE_MISMATCH", result.errors[1].type)
            end)

            it("validates number type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "number" },
                })

                assert.is_true(sig:validate({ 42 }))
                assert.is_true(sig:validate({ 3.14 }))
                local valid = sig:validate({ "not a number" })
                assert.is_false(valid)
            end)

            it("validates boolean type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "boolean" },
                })

                assert.is_true(sig:validate({ true }))
                assert.is_true(sig:validate({ false }))
                local valid = sig:validate({ "true" })
                assert.is_false(valid)
            end)

            it("validates table type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "table" },
                })

                assert.is_true(sig:validate({ {} }))
                assert.is_true(sig:validate({ { 1, 2, 3 } }))
                local valid = sig:validate({ "not a table" })
                assert.is_false(valid)
            end)

            it("validates function type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "function" },
                })

                assert.is_true(sig:validate({ function() end }))
                local valid = sig:validate({ "not a function" })
                assert.is_false(valid)
            end)

            it("validates any type accepts all", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "any" },
                })

                assert.is_true(sig:validate({ "string" }))
                assert.is_true(sig:validate({ 123 }))
                assert.is_true(sig:validate({ true }))
                assert.is_true(sig:validate({ {} }))
                assert.is_true(sig:validate({ function() end }))
            end)

            it("validates array type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "array" },
                })

                assert.is_true(sig:validate({ { 1, 2, 3 } }))
                local valid = sig:validate({ { key = "value" } })
                assert.is_false(valid)
            end)

            it("validates datamap type", function()
                local sig = MacroSignature.new({
                    { name = "value", type = "datamap" },
                })

                assert.is_true(sig:validate({ { key = "value" } }))
                local valid = sig:validate({ { 1, 2, 3 } })
                assert.is_false(valid)
            end)
        end)

        describe("multiple types", function()
            it("accepts value matching any allowed type", function()
                local sig = MacroSignature.new({
                    { name = "value", types = { "string", "number" } },
                })

                assert.is_true(sig:validate({ "hello" }))
                assert.is_true(sig:validate({ 42 }))
                local valid = sig:validate({ true })
                assert.is_false(valid)
            end)
        end)

        describe("optional parameters", function()
            it("allows missing optional argument", function()
                local sig = MacroSignature.new({
                    { name = "required", type = "string" },
                    { name = "optional", type = "number", optional = true },
                })

                local valid = sig:validate({ "hello" })

                assert.is_true(valid)
            end)

            it("validates type when optional is provided", function()
                local sig = MacroSignature.new({
                    { name = "required", type = "string" },
                    { name = "optional", type = "number", optional = true },
                })

                local valid = sig:validate({ "hello", "not a number" })

                assert.is_false(valid)
            end)
        end)

        describe("named parameters", function()
            local sig

            before_each(function()
                sig = MacroSignature.new({
                    { name = "value", type = "string" },
                })
                sig:add_param({
                    name = "via",
                    type = "string",
                    named = true,
                    optional = true,
                })
            end)

            it("validates named parameter type", function()
                local valid = sig:validate({ "hello", via = "path" })
                assert.is_true(valid)

                valid = sig:validate({ "hello", via = 123 })
                assert.is_false(valid)
            end)

            it("warns on unknown named parameter", function()
                local valid, result = sig:validate({ "hello", unknown = "value" })

                assert.is_true(valid)
                assert.equals(1, #result.warnings)
                assert.equals("UNKNOWN_PARAMETER", result.warnings[1].type)
            end)

            it("allows extra named with option", function()
                local valid, result = sig:validate(
                    { "hello", unknown = "value" },
                    { allow_extra_named = true }
                )

                assert.is_true(valid)
                assert.equals(0, #result.warnings)
            end)

            it("errors on missing required named", function()
                sig:add_param({
                    name = "required_named",
                    type = "string",
                    named = true,
                    optional = false,
                })

                local valid, result = sig:validate({ "hello" })

                assert.is_false(valid)
                assert.equals("MISSING_NAMED_ARGUMENT", result.errors[1].type)
            end)
        end)

        describe("custom validator", function()
            it("runs custom validation function", function()
                local sig = MacroSignature.new({
                    {
                        name = "even",
                        type = "number",
                        validator = function(value)
                            return value % 2 == 0, "Must be even"
                        end,
                    },
                })

                assert.is_true(sig:validate({ 4 }))
                local valid, result = sig:validate({ 5 })
                assert.is_false(valid)
                assert.equals("VALIDATION_FAILED", result.errors[1].type)
            end)
        end)
    end)

    describe("process", function()
        it("returns values by index", function()
            local sig = MacroSignature.new({
                { name = "a", type = "any" },
                { name = "b", type = "any" },
            })

            local result = sig:process({ "first", "second" })

            assert.equals("first", result[1])
            assert.equals("second", result[2])
        end)

        it("returns values by name", function()
            local sig = MacroSignature.new({
                { name = "name", type = "string" },
                { name = "value", type = "number" },
            })

            local result = sig:process({ "test", 42 })

            assert.equals("test", result.name)
            assert.equals(42, result.value)
        end)

        it("applies default values", function()
            local sig = MacroSignature.new({
                { name = "required", type = "string" },
                { name = "optional", type = "number", optional = true, default = 10 },
            })

            local result = sig:process({ "hello" })

            assert.equals("hello", result.required)
            assert.equals(10, result.optional)
        end)

        it("applies transform function", function()
            local sig = MacroSignature.new({
                {
                    name = "value",
                    type = "string",
                    transform = function(v) return string.upper(v) end,
                },
            })

            local result = sig:process({ "hello" })

            assert.equals("HELLO", result.value)
        end)

        it("collects rest arguments", function()
            local sig = MacroSignature.from_string("first:string, ...rest:any")

            local result = sig:process({ "one", "two", "three", "four" })

            assert.equals("one", result.first)
            assert.equals(3, #result.rest)
            assert.equals("two", result.rest[1])
        end)

        it("processes named parameters", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string" },
            })
            sig:add_param({
                name = "via",
                type = "string",
                named = true,
                optional = true,
                default = "default",
            })

            local result = sig:process({ "test", via = "custom" })

            assert.equals("test", result.value)
            assert.equals("custom", result.via)
        end)

        it("applies named param defaults", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string" },
            })
            sig:add_param({
                name = "via",
                type = "string",
                named = true,
                optional = true,
                default = "default",
            })

            local result = sig:process({ "test" })

            assert.equals("default", result.via)
        end)
    end)

    describe("to_string", function()
        it("converts signature to string", function()
            local sig = MacroSignature.new({
                { name = "name", type = "string" },
                { name = "count", type = "number", optional = true },
            })

            local str = sig:to_string()

            assert.matches("name:string", str)
            assert.matches("count:number%?", str)
        end)

        it("includes rest parameter", function()
            local sig = MacroSignature.from_string("first:string, ...rest:any")

            local str = sig:to_string()

            assert.matches("%.%.%.rest:any", str)
        end)

        it("includes named parameters", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string" },
            })
            sig:add_param({ name = "via", type = "string", named = true })

            local str = sig:to_string()

            assert.matches("%[via:string%]", str)
        end)
    end)

    describe("export", function()
        it("exports signature info", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string", description = "The value" },
                { name = "count", type = "number", optional = true, default = 1 },
            })

            local exported = sig:export()

            assert.equals(2, #exported.params)
            assert.equals("value", exported.params[1].name)
            assert.equals("string", exported.params[1].type)
            assert.equals("The value", exported.params[1].description)
            assert.is_true(exported.params[2].optional)
            assert.equals(1, exported.params[2].default)
            assert.equals(1, exported.min_args)
            assert.equals(2, exported.max_args)
        end)

        it("exports named params", function()
            local sig = MacroSignature.new({
                { name = "value", type = "string" },
            })
            sig:add_param({
                name = "via",
                type = "string",
                named = true,
                optional = true,
            })

            local exported = sig:export()

            assert.is_not_nil(exported.named.via)
            assert.equals("string", exported.named.via.type)
        end)

        it("exports has_rest flag", function()
            local sig = MacroSignature.from_string("...values:any")

            local exported = sig:export()

            assert.is_true(exported.has_rest)
        end)
    end)

    describe("special types", function()
        it("validates changer type with _is_changer flag", function()
            local sig = MacroSignature.new({
                { name = "value", type = "changer" },
            })

            local changer = { _is_changer = true }
            assert.is_true(sig:validate({ changer }))
        end)

        it("validates changer type with function", function()
            local sig = MacroSignature.new({
                { name = "value", type = "changer" },
            })

            assert.is_true(sig:validate({ function() end }))
        end)

        it("validates hook type", function()
            local sig = MacroSignature.new({
                { name = "value", type = "hook" },
            })

            local hook = { _is_hook = true }
            assert.is_true(sig:validate({ hook }))
        end)

        it("validates passage type with string", function()
            local sig = MacroSignature.new({
                { name = "value", type = "passage" },
            })

            assert.is_true(sig:validate({ "PassageName" }))
        end)

        it("validates passage type with object", function()
            local sig = MacroSignature.new({
                { name = "value", type = "passage" },
            })

            local passage = { _is_passage = true }
            assert.is_true(sig:validate({ passage }))
        end)

        it("validates variable type", function()
            local sig = MacroSignature.new({
                { name = "value", type = "variable" },
            })

            local variable = { _is_variable = true }
            assert.is_true(sig:validate({ variable }))
        end)

        it("validates expression type", function()
            local sig = MacroSignature.new({
                { name = "value", type = "expression" },
            })

            local expr = { _is_expression = true }
            assert.is_true(sig:validate({ expr }))
        end)
    end)

    describe("array detection", function()
        local sig

        before_each(function()
            sig = MacroSignature.new()
        end)

        it("detects sequential array", function()
            assert.is_true(sig:_is_array({ 1, 2, 3 }))
        end)

        it("detects empty array", function()
            assert.is_true(sig:_is_array({}))
        end)

        it("rejects table with gaps", function()
            local t = { [1] = "a", [3] = "c" }
            assert.is_false(sig:_is_array(t))
        end)

        it("rejects table with string keys", function()
            assert.is_false(sig:_is_array({ key = "value" }))
        end)

        it("rejects mixed table", function()
            assert.is_false(sig:_is_array({ 1, 2, key = "value" }))
        end)
    end)
end)
