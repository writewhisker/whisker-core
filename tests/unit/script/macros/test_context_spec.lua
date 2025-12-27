--- MacroContext Unit Tests
-- Comprehensive unit tests for the MacroContext module
-- @module tests.unit.script.macros.test_context_spec
-- @author Whisker Core Team

describe("MacroContext", function()
    local MacroContext, EventSystem

    setup(function()
        MacroContext = require("whisker.script.macros.context")
        EventSystem = require("whisker.core.event_system")
    end)

    describe("initialization", function()
        it("creates instance without dependencies", function()
            local ctx = MacroContext.new()

            assert.is_not_nil(ctx)
            assert.equals(0, ctx:get_depth())
        end)

        it("creates instance with dependencies", function()
            local event_bus = EventSystem.new()
            local ctx = MacroContext.new({ event_bus = event_bus })

            assert.is_not_nil(ctx)
            assert.equals(event_bus, ctx._event_bus)
        end)

        it("provides create factory for DI", function()
            assert.is_function(MacroContext.create)

            local ctx = MacroContext.create({})
            assert.is_not_nil(ctx)
        end)

        it("declares _dependencies for DI", function()
            assert.is_table(MacroContext._dependencies)
        end)

        it("exports FLAG constants", function()
            assert.equals("rendering", MacroContext.FLAG.RENDERING)
            assert.equals("executing", MacroContext.FLAG.EXECUTING)
            assert.equals("evaluating", MacroContext.FLAG.EVALUATING)
            assert.equals("transitioning", MacroContext.FLAG.TRANSITIONING)
        end)
    end)

    describe("stack management", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("pushes execution frame", function()
            local ok = ctx:push("testMacro", { 1, 2 })

            assert.is_true(ok)
            assert.equals(1, ctx:get_depth())
        end)

        it("tracks nested depth", function()
            ctx:push("outer", {})
            ctx:push("middle", {})
            ctx:push("inner", {})

            assert.equals(3, ctx:get_depth())
        end)

        it("pops execution frame", function()
            ctx:push("macro", { "arg" })
            local frame = ctx:pop()

            assert.equals(0, ctx:get_depth())
            assert.equals("macro", frame.macro)
        end)

        it("returns nil when popping empty stack", function()
            local frame = ctx:pop()

            assert.is_nil(frame)
        end)

        it("enforces max depth limit", function()
            ctx:configure({ max_depth = 3 })

            ctx:push("level1", {})
            ctx:push("level2", {})
            ctx:push("level3", {})
            local ok, err = ctx:push("level4", {})

            assert.is_false(ok)
            assert.matches("depth exceeded", err)
            assert.equals(3, ctx:get_depth())
        end)

        it("gets call stack info", function()
            ctx:push("first", {})
            ctx:push("second", {})

            local stack = ctx:get_stack()

            assert.equals(2, #stack)
            assert.equals("first", stack[1].macro)
            assert.equals("second", stack[2].macro)
        end)

        it("emits MACRO_STARTED event on push", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            local event_received = nil

            event_bus:on("MACRO_STARTED", function(event)
                event_received = event.data
            end)

            ctx:push("testMacro", {})

            assert.is_not_nil(event_received)
            assert.equals("testMacro", event_received.name)
        end)

        it("emits MACRO_COMPLETED event on pop", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            ctx:push("testMacro", {})
            local event_received = nil

            event_bus:on("MACRO_COMPLETED", function(event)
                event_received = event.data
            end)

            ctx:pop()

            assert.is_not_nil(event_received)
            assert.equals("testMacro", event_received.name)
        end)
    end)

    describe("variable access", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("sets and gets variable", function()
            ctx:set("name", "Alice")

            assert.equals("Alice", ctx:get("name"))
        end)

        it("returns nil for undefined variable", function()
            assert.is_nil(ctx:get("undefined"))
        end)

        it("checks variable existence", function()
            ctx:set("exists", true)

            assert.is_true(ctx:has("exists"))
            assert.is_false(ctx:has("missing"))
        end)

        it("deletes variable", function()
            ctx:set("toDelete", "value")
            ctx:delete("toDelete")

            assert.is_false(ctx:has("toDelete"))
        end)

        it("gets all variable names", function()
            ctx:set("alpha", 1)
            ctx:set("beta", 2)
            ctx:set("gamma", 3)

            local names = ctx:get_variable_names()

            assert.equals(3, #names)
            assert.equals("alpha", names[1])
            assert.equals("beta", names[2])
            assert.equals("gamma", names[3])
        end)

        it("emits VARIABLE_CHANGED event", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            local event_received = nil

            event_bus:on("VARIABLE_CHANGED", function(event)
                event_received = event.data
            end)

            ctx:set("test", "value")

            assert.is_not_nil(event_received)
            assert.equals("test", event_received.name)
            assert.equals("value", event_received.new_value)
        end)
    end)

    describe("temporary variables", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("sets temp variable", function()
            ctx:set("temp", "value", { temp = true })

            assert.equals("value", ctx:get("temp"))
        end)

        it("temp variable shadows regular variable", function()
            ctx:set("name", "regular")
            ctx:set("name", "temporary", { temp = true })

            assert.equals("temporary", ctx:get("name"))
        end)

        it("temp variable is cleaned up on pop", function()
            ctx:push("macro", {})
            ctx:set("localVar", "local", { temp = true })
            ctx:pop()

            assert.is_nil(ctx:get("localVar"))
        end)

        it("nested temp variables have correct scope", function()
            ctx:push("outer", {})
            ctx:set("outerVar", "outer", { temp = true })

            ctx:push("inner", {})
            ctx:set("innerVar", "inner", { temp = true })

            assert.equals("outer", ctx:get("outerVar"))
            assert.equals("inner", ctx:get("innerVar"))

            ctx:pop()
            assert.equals("outer", ctx:get("outerVar"))
            assert.is_nil(ctx:get("innerVar"))

            ctx:pop()
            assert.is_nil(ctx:get("outerVar"))
        end)
    end)

    describe("output management", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("writes string output", function()
            ctx:write("Hello")
            ctx:write(" ")
            ctx:write("World")

            assert.equals("Hello World", ctx:get_output())
        end)

        it("writes line with newline", function()
            ctx:writeln("Line 1")
            ctx:writeln("Line 2")

            assert.equals("Line 1\nLine 2\n", ctx:get_output())
        end)

        it("handles nil write", function()
            ctx:write("before")
            ctx:write(nil)
            ctx:write("after")

            assert.equals("beforeafter", ctx:get_output())
        end)

        it("writes structured output", function()
            ctx:write({ type = "link", text = "Click" })

            local items = ctx:get_output_items()
            assert.equals(1, #items)
            assert.equals("link", items[1].type)
        end)

        it("clears output", function()
            ctx:write("content")
            ctx:clear_output()

            assert.equals("", ctx:get_output())
        end)

        it("gets output from current frame only", function()
            ctx:write("global")
            ctx:push("macro", {})
            ctx:write("frame")

            local frame_output = ctx:get_frame_output()

            assert.equals(1, #frame_output)
            assert.equals("frame", frame_output[1])
        end)

        it("emits OUTPUT_OVERFLOW when limit exceeded", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            ctx:configure({ max_output_size = 10 })
            local overflow_event = nil

            event_bus:on("OUTPUT_OVERFLOW", function(event)
                overflow_event = event.data
            end)

            ctx:write("12345678901234567890")

            assert.is_not_nil(overflow_event)
        end)
    end)

    describe("hooks (named content)", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("defines a hook", function()
            ctx:define_hook("sidebar", "Sidebar content")

            assert.equals("Sidebar content", ctx:get_hook("sidebar"))
        end)

        it("checks hook existence", function()
            ctx:define_hook("exists", "content")

            assert.is_true(ctx:has_hook("exists"))
            assert.is_false(ctx:has_hook("missing"))
        end)

        it("modifies hook with function", function()
            ctx:define_hook("text", "hello")
            ctx:modify_hook("text", function(content)
                return string.upper(content)
            end)

            assert.equals("HELLO", ctx:get_hook("text"))
        end)

        it("appends to string hook", function()
            ctx:define_hook("text", "Hello")
            ctx:append_hook("text", " World")

            assert.equals("Hello World", ctx:get_hook("text"))
        end)

        it("appends to table hook", function()
            ctx:define_hook("list", { "item1" })
            ctx:append_hook("list", "item2")

            local list = ctx:get_hook("list")
            assert.equals(2, #list)
        end)

        it("replaces hook content", function()
            ctx:define_hook("text", "original")
            ctx:replace_hook("text", "replaced")

            assert.equals("replaced", ctx:get_hook("text"))
        end)

        it("clears hook content", function()
            ctx:define_hook("text", "content")
            ctx:clear_hook("text")

            assert.equals("", ctx:get_hook("text"))
        end)

        it("gets all hook names", function()
            ctx:define_hook("hook1", "content1")
            ctx:define_hook("hook2", "content2")

            local names = ctx:get_hook_names()

            assert.equals(2, #names)
        end)

        it("returns nil for undefined hook", function()
            assert.is_nil(ctx:get_hook("undefined"))
        end)
    end)

    describe("flags", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("sets and gets flag", function()
            ctx:set_flag("custom_flag", true)

            assert.is_true(ctx:get_flag("custom_flag"))
        end)

        it("defaults to true when setting flag", function()
            ctx:set_flag("enabled")

            assert.is_true(ctx:get_flag("enabled"))
        end)

        it("clears flag", function()
            ctx:set_flag("flag", true)
            ctx:clear_flag("flag")

            assert.is_false(ctx:get_flag("flag"))
        end)

        it("is_in checks flag state", function()
            ctx:set_flag(MacroContext.FLAG.RENDERING, true)

            assert.is_true(ctx:is_in(MacroContext.FLAG.RENDERING))
            assert.is_false(ctx:is_in(MacroContext.FLAG.EXECUTING))
        end)
    end)

    describe("passage handling", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("sets and gets current passage", function()
            local passage = { name = "Start", content = "Welcome" }
            ctx:set_passage(passage)

            assert.same(passage, ctx:get_passage())
        end)

        it("emits PASSAGE_NAVIGATE on goto", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            ctx:set_passage({ name = "Current" })
            local nav_event = nil

            event_bus:on("PASSAGE_NAVIGATE", function(event)
                nav_event = event.data
            end)

            ctx:goto_passage("NextPassage")

            assert.is_not_nil(nav_event)
            assert.equals("NextPassage", nav_event.to)
        end)

        it("sets transitioning flag on goto", function()
            ctx:goto_passage("Target")

            assert.is_true(ctx:get_flag(MacroContext.FLAG.TRANSITIONING))
        end)
    end)

    describe("macro execution support", function()
        local ctx, registry

        before_each(function()
            local MacroRegistry = require("whisker.script.macros.registry")
            registry = MacroRegistry.new()
            registry:register("double", {
                handler = function(c, args)
                    return (args[1] or 0) * 2
                end,
            })
            ctx = MacroContext.new({ registry = registry })
        end)

        it("calls another macro", function()
            local result = ctx:call("double", { 5 })

            assert.equals(10, result)
        end)

        it("returns error for missing registry", function()
            local plain_ctx = MacroContext.new()
            local result, err = plain_ctx:call("test", {})

            assert.is_nil(result)
            assert.matches("No macro registry", err)
        end)
    end)

    describe("changer creation", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("creates a changer object", function()
            local changer = ctx:create_changer("bold", function(self, content)
                return "**" .. content .. "**"
            end)

            assert.is_true(changer._is_changer)
            assert.equals("bold", changer.name)
        end)

        it("changer applies transformation", function()
            local changer = ctx:create_changer("wrap", function(self, content)
                return "[" .. content .. "]"
            end)

            local result = changer:apply("text", ctx)

            assert.equals("[text]", result)
        end)

        it("changers can be combined", function()
            local bold = ctx:create_changer("bold", function(self, content)
                return "**" .. content .. "**"
            end)
            local italic = ctx:create_changer("italic", function(self, content)
                return "_" .. content .. "_"
            end)

            local combined = bold:combine(italic)
            local result = combined:apply("text", ctx)

            assert.equals("_**text**_", result)
        end)
    end)

    describe("configuration", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
        end)

        it("configures max_depth", function()
            ctx:configure({ max_depth = 50 })

            assert.equals(50, ctx:get_config("max_depth"))
        end)

        it("configures max_output_size", function()
            ctx:configure({ max_output_size = 500000 })

            assert.equals(500000, ctx:get_config("max_output_size"))
        end)

        it("enables strict mode", function()
            ctx:enable_strict_mode()

            assert.is_true(ctx:get_config("strict_mode"))
        end)

        it("emits UNDEFINED_VARIABLE in strict mode", function()
            local event_bus = EventSystem.new()
            ctx = MacroContext.new({ event_bus = event_bus })
            ctx:enable_strict_mode()
            local event_received = nil

            event_bus:on("UNDEFINED_VARIABLE", function(event)
                event_received = event.data
            end)

            ctx:get("undefined_var")

            assert.is_not_nil(event_received)
            assert.equals("undefined_var", event_received.name)
        end)
    end)

    describe("tracing", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
            ctx:enable_tracing()
        end)

        it("records push in trace", function()
            ctx:push("testMacro", {})

            local trace = ctx:get_trace()

            assert.equals(1, #trace)
            assert.equals("push", trace[1].type)
            assert.equals("testMacro", trace[1].macro)
        end)

        it("records pop in trace", function()
            ctx:push("testMacro", {})
            ctx:pop()

            local trace = ctx:get_trace()

            assert.equals(2, #trace)
            assert.equals("pop", trace[2].type)
        end)

        it("clears trace", function()
            ctx:push("macro", {})
            ctx:clear_trace()

            assert.equals(0, #ctx:get_trace())
        end)
    end)

    describe("child context", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
            ctx:set("parentVar", "parent")
            ctx:set_flag("parentFlag", true)
        end)

        it("creates child with inherited variables", function()
            local child = ctx:child()

            assert.equals("parent", child:get("parentVar"))
        end)

        it("creates child with inherited flags", function()
            local child = ctx:child()

            assert.is_true(child:get_flag("parentFlag"))
        end)

        it("child changes don't affect parent", function()
            local child = ctx:child()
            child:set("childVar", "child")

            assert.is_nil(ctx:get("childVar"))
        end)

        it("child inherits configuration", function()
            ctx:configure({ max_depth = 50 })
            local child = ctx:child()

            assert.equals(50, child:get_config("max_depth"))
        end)
    end)

    describe("reset", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
            ctx:set("var", "value")
            ctx:write("output")
            ctx:define_hook("hook", "content")
            ctx:set_flag("flag", true)
            ctx:push("macro", {})
        end)

        it("resets all state", function()
            ctx:reset({ all = true })

            assert.is_nil(ctx:get("var"))
            assert.equals("", ctx:get_output())
            assert.is_nil(ctx:get_hook("hook"))
            assert.is_false(ctx:get_flag("flag"))
            assert.equals(0, ctx:get_depth())
        end)

        it("resets only variables", function()
            ctx:reset({ variables = true })

            assert.is_nil(ctx:get("var"))
            assert.equals("output", ctx:get_output())
        end)

        it("resets only output", function()
            ctx:reset({ output = true })

            assert.equals("value", ctx:get("var"))
            assert.equals("", ctx:get_output())
        end)

        it("resets only hooks", function()
            ctx:reset({ hooks = true })

            assert.is_nil(ctx:get_hook("hook"))
            assert.equals("value", ctx:get("var"))
        end)

        it("resets only flags", function()
            ctx:reset({ flags = true })

            assert.is_false(ctx:get_flag("flag"))
            assert.equals("value", ctx:get("var"))
        end)

        it("resets only stack", function()
            ctx:reset({ stack = true })

            assert.equals(0, ctx:get_depth())
            assert.equals("value", ctx:get("var"))
        end)
    end)

    describe("expression evaluation", function()
        local ctx

        before_each(function()
            ctx = MacroContext.new()
            ctx:set("name", "Alice")
            ctx:set("count", 42)
        end)

        it("evaluates variable reference", function()
            local result = ctx:eval("name")

            assert.equals("Alice", result)
        end)

        it("evaluates $-prefixed variable", function()
            local result = ctx:eval("$count")

            assert.equals(42, result)
        end)

        it("returns non-string expression as-is", function()
            local result = ctx:eval({ value = 123 })

            assert.same({ value = 123 }, result)
        end)
    end)

    describe("game state integration", function()
        it("reads from game state", function()
            local game_state = {
                get = function(self, name)
                    if name == "score" then return 100 end
                    return nil
                end,
            }
            local ctx = MacroContext.new({ game_state = game_state })

            assert.equals(100, ctx:get("score"))
        end)

        it("writes to game state", function()
            local stored = {}
            local game_state = {
                get = function(self, name) return stored[name] end,
                set = function(self, name, value) stored[name] = value end,
            }
            local ctx = MacroContext.new({ game_state = game_state })

            ctx:set("score", 200)

            assert.equals(200, stored.score)
        end)

        it("checks game state for existence", function()
            local game_state = {
                has = function(self, name) return name == "exists" end,
            }
            local ctx = MacroContext.new({ game_state = game_state })

            assert.is_true(ctx:has("exists"))
            assert.is_false(ctx:has("missing"))
        end)
    end)
end)
