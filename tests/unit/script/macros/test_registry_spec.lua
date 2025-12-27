--- MacroRegistry Unit Tests
-- Comprehensive unit tests for the MacroRegistry module
-- @module tests.unit.script.macros.test_registry_spec
-- @author Whisker Core Team

describe("MacroRegistry", function()
    local MacroRegistry, EventSystem

    setup(function()
        MacroRegistry = require("whisker.script.macros.registry")
        EventSystem = require("whisker.core.event_system")
    end)

    describe("initialization", function()
        it("creates instance without dependencies", function()
            local registry = MacroRegistry.new()

            assert.is_not_nil(registry)
            assert.equals(0, registry:count())
        end)

        it("creates instance with event_bus", function()
            local event_bus = EventSystem.new()
            local registry = MacroRegistry.new({ event_bus = event_bus })

            assert.is_not_nil(registry)
            assert.equals(event_bus, registry._event_bus)
        end)

        it("provides create factory for DI", function()
            assert.is_function(MacroRegistry.create)

            local registry = MacroRegistry.create({})
            assert.is_not_nil(registry)
        end)

        it("declares _dependencies for DI", function()
            assert.is_table(MacroRegistry._dependencies)
            assert.equals("event_bus", MacroRegistry._dependencies[1])
        end)

        it("exports CATEGORY constants", function()
            assert.equals("control", MacroRegistry.CATEGORY.CONTROL)
            assert.equals("data", MacroRegistry.CATEGORY.DATA)
            assert.equals("text", MacroRegistry.CATEGORY.TEXT)
            assert.equals("link", MacroRegistry.CATEGORY.LINK)
            assert.equals("ui", MacroRegistry.CATEGORY.UI)
            assert.equals("audio", MacroRegistry.CATEGORY.AUDIO)
            assert.equals("lifecycle", MacroRegistry.CATEGORY.LIFECYCLE)
            assert.equals("utility", MacroRegistry.CATEGORY.UTILITY)
            assert.equals("custom", MacroRegistry.CATEGORY.CUSTOM)
        end)

        it("exports FORMAT constants", function()
            assert.equals("harlowe", MacroRegistry.FORMAT.HARLOWE)
            assert.equals("sugarcube", MacroRegistry.FORMAT.SUGARCUBE)
            assert.equals("chapbook", MacroRegistry.FORMAT.CHAPBOOK)
            assert.equals("ink", MacroRegistry.FORMAT.INK)
            assert.equals("whisker", MacroRegistry.FORMAT.WHISKER)
        end)
    end)

    describe("macro registration", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
        end)

        it("registers a macro with handler", function()
            local handler = function() return "test" end
            local ok, err = registry:register("test", { handler = handler })

            assert.is_true(ok)
            assert.is_nil(err)
            assert.equals(1, registry:count())
        end)

        it("stores macro definition correctly", function()
            local handler = function() return "test" end
            registry:register("myMacro", {
                handler = handler,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.HARLOWE,
                description = "Test macro",
            })

            local macro = registry:get("myMacro")
            assert.equals("myMacro", macro.name)
            assert.equals(handler, macro.handler)
            assert.equals("data", macro.category)
            assert.equals("harlowe", macro.format)
            assert.equals("Test macro", macro.description)
        end)

        it("defaults category to custom", function()
            registry:register("test", { handler = function() end })
            local macro = registry:get("test")
            assert.equals("custom", macro.category)
        end)

        it("defaults format to whisker", function()
            registry:register("test", { handler = function() end })
            local macro = registry:get("test")
            assert.equals("whisker", macro.format)
        end)

        it("rejects duplicate registration", function()
            registry:register("test", { handler = function() end })
            local ok, err = registry:register("test", { handler = function() end })

            assert.is_false(ok)
            assert.matches("already registered", err)
        end)

        it("rejects empty name", function()
            local ok, err = registry:register("", { handler = function() end })

            assert.is_false(ok)
            assert.is_not_nil(err)
        end)

        it("rejects non-string name", function()
            local ok, err = registry:register(123, { handler = function() end })

            assert.is_false(ok)
        end)

        it("rejects definition without handler", function()
            local ok, err = registry:register("test", {})

            assert.is_false(ok)
            assert.matches("handler function", err)
        end)

        it("rejects non-function handler", function()
            local ok, err = registry:register("test", { handler = "not a function" })

            assert.is_false(ok)
            assert.matches("handler function", err)
        end)

        it("rejects invalid category", function()
            local ok, err = registry:register("test", {
                handler = function() end,
                category = "invalid_category",
            })

            assert.is_false(ok)
            assert.matches("Invalid category", err)
        end)

        it("rejects invalid format", function()
            local ok, err = registry:register("test", {
                handler = function() end,
                format = "invalid_format",
            })

            assert.is_false(ok)
            assert.matches("Invalid format", err)
        end)

        it("stores signature", function()
            local sig = { params = {} }
            registry:register("test", {
                handler = function() end,
                signature = sig,
            })

            local macro = registry:get("test")
            assert.same(sig, macro.signature)
        end)

        it("stores examples", function()
            local examples = { "(test: 1)", "(test: 'hello')" }
            registry:register("test", {
                handler = function() end,
                examples = examples,
            })

            local macro = registry:get("test")
            assert.same(examples, macro.examples)
        end)

        it("stores deprecated flag", function()
            registry:register("test", {
                handler = function() end,
                deprecated = true,
                replacement = "newTest",
            })

            local macro = registry:get("test")
            assert.is_true(macro.deprecated)
            assert.equals("newTest", macro.replacement)
        end)

        it("stores async flag", function()
            registry:register("test", {
                handler = function() end,
                async = true,
            })

            local macro = registry:get("test")
            assert.is_true(macro.async)
        end)

        it("stores pure flag", function()
            registry:register("test", {
                handler = function() end,
                pure = true,
            })

            local macro = registry:get("test")
            assert.is_true(macro.pure)
        end)

        it("emits MACRO_REGISTERED event", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            local event_received = nil

            event_bus:on("MACRO_REGISTERED", function(event)
                event_received = event.data
            end)

            registry:register("test", { handler = function() end })

            assert.is_not_nil(event_received)
            assert.equals("test", event_received.name)
        end)
    end)

    describe("register_all", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
        end)

        it("registers multiple macros", function()
            local count, errors = registry:register_all({
                macro1 = { handler = function() end },
                macro2 = { handler = function() end },
                macro3 = { handler = function() end },
            })

            assert.equals(3, count)
            assert.equals(0, #errors)
            assert.equals(3, registry:count())
        end)

        it("reports errors for invalid macros", function()
            local count, errors = registry:register_all({
                valid = { handler = function() end },
                invalid = { handler = "not a function" },
            })

            assert.equals(1, count)
            assert.equals(1, #errors)
            assert.equals("invalid", errors[1].name)
        end)
    end)

    describe("unregister", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("test", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.DATA,
            })
        end)

        it("removes macro from registry", function()
            local result = registry:unregister("test")

            assert.is_true(result)
            assert.is_nil(registry:get("test"))
            assert.equals(0, registry:count())
        end)

        it("removes macro from category index", function()
            local result = registry:unregister("test")

            assert.is_true(result)
            assert.equals(0, #registry:get_by_category(MacroRegistry.CATEGORY.DATA))
        end)

        it("returns false for non-existent macro", function()
            local result = registry:unregister("nonexistent")

            assert.is_false(result)
        end)

        it("emits MACRO_UNREGISTERED event", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            registry:register("test", { handler = function() end })
            local event_received = nil

            event_bus:on("MACRO_UNREGISTERED", function(event)
                event_received = event.data
            end)

            registry:unregister("test")

            assert.is_not_nil(event_received)
            assert.equals("test", event_received.name)
        end)
    end)

    describe("lookup", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("test1", {
                handler = function() return 1 end,
                category = MacroRegistry.CATEGORY.CONTROL,
                format = MacroRegistry.FORMAT.HARLOWE,
            })
            registry:register("test2", {
                handler = function() return 2 end,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.HARLOWE,
            })
            registry:register("test3", {
                handler = function() return 3 end,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.SUGARCUBE,
            })
        end)

        it("gets macro by name", function()
            local macro = registry:get("test1")

            assert.is_not_nil(macro)
            assert.equals("test1", macro.name)
        end)

        it("returns nil for non-existent macro", function()
            local macro = registry:get("nonexistent")

            assert.is_nil(macro)
        end)

        it("checks macro exists", function()
            assert.is_true(registry:exists("test1"))
            assert.is_false(registry:exists("nonexistent"))
        end)

        it("gets all macro names", function()
            local names = registry:get_all_names()

            assert.equals(3, #names)
            assert.is_true(names[1] == "test1" or names[2] == "test1" or names[3] == "test1")
        end)

        it("names are sorted", function()
            local names = registry:get_all_names()

            assert.equals("test1", names[1])
            assert.equals("test2", names[2])
            assert.equals("test3", names[3])
        end)

        it("gets macros by category", function()
            local data_macros = registry:get_by_category(MacroRegistry.CATEGORY.DATA)

            assert.equals(2, #data_macros)
        end)

        it("gets macros by format", function()
            local harlowe_macros = registry:get_by_format(MacroRegistry.FORMAT.HARLOWE)

            assert.equals(2, #harlowe_macros)
        end)

        it("returns empty for non-existent category", function()
            local macros = registry:get_by_category("nonexistent")

            assert.same({}, macros)
        end)

        it("gets handler directly", function()
            local handler = registry:get_handler("test1")

            assert.is_function(handler)
            assert.equals(1, handler())
        end)

        it("returns nil handler for non-existent macro", function()
            local handler = registry:get_handler("nonexistent")

            assert.is_nil(handler)
        end)

        it("gets signature", function()
            registry:register("withSig", {
                handler = function() end,
                signature = { min_args = 1 },
            })

            local sig = registry:get_signature("withSig")
            assert.same({ min_args = 1 }, sig)
        end)
    end)

    describe("aliases", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("set", {
                handler = function() return "set" end,
                aliases = { "put", "assign" },
            })
        end)

        it("registers aliases from definition", function()
            assert.equals("set", registry:resolve_alias("put"))
            assert.equals("set", registry:resolve_alias("assign"))
        end)

        it("gets macro via alias", function()
            local macro = registry:get("put")

            assert.is_not_nil(macro)
            assert.equals("set", macro.name)
        end)

        it("exists works with alias", function()
            assert.is_true(registry:exists("put"))
        end)

        it("adds alias after registration", function()
            local ok = registry:add_alias("store", "set")

            assert.is_true(ok)
            assert.equals("set", registry:resolve_alias("store"))
        end)

        it("rejects alias for non-existent target", function()
            local ok, err = registry:add_alias("bad", "nonexistent")

            assert.is_false(ok)
            assert.matches("does not exist", err)
        end)

        it("rejects duplicate alias", function()
            local ok, err = registry:add_alias("put", "set")

            assert.is_false(ok)
            assert.matches("already exists", err)
        end)

        it("rejects alias that conflicts with macro name", function()
            registry:register("other", { handler = function() end })
            local ok, err = registry:add_alias("other", "set")

            assert.is_false(ok)
            assert.matches("already exists", err)
        end)

        it("removes alias", function()
            local result = registry:remove_alias("put")

            assert.is_true(result)
            assert.is_nil(registry:get("put"))
        end)

        it("returns false when removing non-existent alias", function()
            local result = registry:remove_alias("nonexistent")

            assert.is_false(result)
        end)

        it("gets all aliases for macro", function()
            local aliases = registry:get_aliases("set")

            assert.equals(2, #aliases)
        end)

        it("resolves canonical name", function()
            assert.equals("set", registry:resolve_alias("set"))
            assert.equals("set", registry:resolve_alias("put"))
        end)
    end)

    describe("disable/enable", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("test", { handler = function() return "result" end })
        end)

        it("disables a macro", function()
            local result = registry:disable("test")

            assert.is_true(result)
            assert.is_true(registry:is_disabled("test"))
        end)

        it("returns false when disabling non-existent macro", function()
            local result = registry:disable("nonexistent")

            assert.is_false(result)
        end)

        it("enables a disabled macro", function()
            registry:disable("test")
            local result = registry:enable("test")

            assert.is_true(result)
            assert.is_false(registry:is_disabled("test"))
        end)

        it("disabled macro handler returns nil", function()
            registry:disable("test")
            local handler = registry:get_handler("test")

            assert.is_nil(handler)
        end)

        it("emits MACRO_DISABLED event", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            registry:register("test", { handler = function() end })
            local event_received = nil

            event_bus:on("MACRO_DISABLED", function(event)
                event_received = event.data
            end)

            registry:disable("test")

            assert.is_not_nil(event_received)
            assert.equals("test", event_received.name)
        end)

        it("emits MACRO_ENABLED event", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            registry:register("test", { handler = function() end })
            registry:disable("test")
            local event_received = nil

            event_bus:on("MACRO_ENABLED", function(event)
                event_received = event.data
            end)

            registry:enable("test")

            assert.is_not_nil(event_received)
            assert.equals("test", event_received.name)
        end)
    end)

    describe("deprecation", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("oldMacro", {
                handler = function() return "old" end,
                deprecated = true,
                replacement = "newMacro",
            })
            registry:register("newMacro", {
                handler = function() return "new" end,
            })
        end)

        it("identifies deprecated macros", function()
            local deprecated, replacement = registry:is_deprecated("oldMacro")

            assert.is_true(deprecated)
            assert.equals("newMacro", replacement)
        end)

        it("non-deprecated macros return false", function()
            local deprecated, replacement = registry:is_deprecated("newMacro")

            assert.is_false(deprecated)
            assert.is_nil(replacement)
        end)
    end)

    describe("execution", function()
        local registry, context

        before_each(function()
            registry = MacroRegistry.new()
            context = { variables = {} }
            registry:register("add", {
                handler = function(ctx, args)
                    return (args[1] or 0) + (args[2] or 0)
                end,
            })
            registry:register("greet", {
                handler = function(ctx, args)
                    return "Hello, " .. (args[1] or "World")
                end,
            })
        end)

        it("executes macro with arguments", function()
            local result, err = registry:execute("add", context, { 2, 3 })

            assert.is_nil(err)
            assert.equals(5, result)
        end)

        it("executes macro with context", function()
            registry:register("setVar", {
                handler = function(ctx, args)
                    ctx.variables[args[1]] = args[2]
                    return true
                end,
            })

            registry:execute("setVar", context, { "name", "Alice" })

            assert.equals("Alice", context.variables.name)
        end)

        it("returns error for unknown macro", function()
            local result, err = registry:execute("unknown", context, {})

            assert.is_nil(result)
            assert.matches("Unknown macro", err)
        end)

        it("returns error for disabled macro", function()
            registry:disable("add")
            local result, err = registry:execute("add", context, { 1, 2 })

            assert.is_nil(result)
            assert.matches("disabled", err)
        end)

        it("catches handler errors", function()
            registry:register("error", {
                handler = function()
                    error("intentional error")
                end,
            })

            local result, err = registry:execute("error", context, {})

            assert.is_nil(result)
            assert.matches("Macro error", err)
        end)

        it("emits MACRO_ERROR on handler failure", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            registry:register("error", {
                handler = function() error("fail") end,
            })
            local error_event = nil

            event_bus:on("MACRO_ERROR", function(event)
                error_event = event.data
            end)

            registry:execute("error", context, {})

            assert.is_not_nil(error_event)
            assert.equals("error", error_event.name)
        end)

        it("emits deprecation warning during execution", function()
            local event_bus = EventSystem.new()
            registry = MacroRegistry.new({ event_bus = event_bus })
            registry:register("old", {
                handler = function() return "result" end,
                deprecated = true,
                replacement = "new",
            })
            local warning = nil

            event_bus:on("MACRO_DEPRECATION_WARNING", function(event)
                warning = event.data
            end)

            registry:execute("old", context, {})

            assert.is_not_nil(warning)
            assert.equals("old", warning.name)
            assert.equals("new", warning.replacement)
        end)
    end)

    describe("hooks", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
        end)

        it("adds before_register hook", function()
            local hook_called = false
            registry:add_hook("before_register", function(name, def)
                hook_called = true
                return true
            end)

            registry:register("test", { handler = function() end })

            assert.is_true(hook_called)
        end)

        it("before_register hook can block registration", function()
            registry:add_hook("before_register", function(name, def)
                if name == "blocked" then
                    return false, "Registration blocked"
                end
                return true
            end)

            local ok, err = registry:register("blocked", { handler = function() end })

            assert.is_false(ok)
            assert.matches("blocked", err)
        end)

        it("adds after_register hook", function()
            local registered_name = nil
            registry:add_hook("after_register", function(name, macro)
                registered_name = name
            end)

            registry:register("test", { handler = function() end })

            assert.equals("test", registered_name)
        end)

        it("adds before_execute hook", function()
            local context = {}
            local hook_called = false
            registry:register("test", { handler = function() return "result" end })

            registry:add_hook("before_execute", function(name, ctx, args)
                hook_called = true
                return true
            end)

            registry:execute("test", context, {})

            assert.is_true(hook_called)
        end)

        it("before_execute hook can block execution", function()
            local context = {}
            registry:register("test", { handler = function() return "result" end })

            registry:add_hook("before_execute", function(name, ctx, args)
                return false, "Execution blocked"
            end)

            local result, err = registry:execute("test", context, {})

            assert.is_nil(result)
            assert.matches("blocked", err)
        end)

        it("adds after_execute hook", function()
            local context = {}
            local executed_result = nil
            registry:register("test", { handler = function() return "result" end })

            registry:add_hook("after_execute", function(name, ctx, args, result)
                executed_result = result
            end)

            registry:execute("test", context, {})

            assert.equals("result", executed_result)
        end)

        it("removes hook by id", function()
            local call_count = 0
            local hook_id = registry:add_hook("before_register", function()
                call_count = call_count + 1
                return true
            end)

            registry:register("test1", { handler = function() end })
            registry:remove_hook("before_register", hook_id)
            registry:register("test2", { handler = function() end })

            assert.equals(1, call_count)
        end)

        it("errors on invalid hook type", function()
            assert.has_error(function()
                registry:add_hook("invalid_hook", function() end)
            end)
        end)
    end)

    describe("statistics", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("macro1", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.CONTROL,
                format = MacroRegistry.FORMAT.HARLOWE,
                aliases = { "m1" },
            })
            registry:register("macro2", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.HARLOWE,
            })
            registry:register("macro3", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.SUGARCUBE,
            })
            registry:disable("macro3")
        end)

        it("counts total macros", function()
            assert.equals(3, registry:count())
        end)

        it("gets comprehensive stats", function()
            local stats = registry:get_stats()

            assert.equals(3, stats.total_macros)
            assert.equals(1, stats.categories.control)
            assert.equals(2, stats.categories.data)
            assert.equals(2, stats.formats.harlowe)
            assert.equals(1, stats.formats.sugarcube)
            assert.equals(1, stats.disabled)
            assert.equals(1, stats.aliases)
        end)
    end)

    describe("export", function()
        local registry

        before_each(function()
            registry = MacroRegistry.new()
            registry:register("test", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.DATA,
                format = MacroRegistry.FORMAT.HARLOWE,
                description = "Test macro",
                aliases = { "t" },
            })
            registry:add_alias("alias", "test")
        end)

        it("exports macro information", function()
            local exported = registry:export()

            assert.is_not_nil(exported.test)
            assert.equals("test", exported.test.name)
            assert.equals("data", exported.test.category)
            assert.equals("harlowe", exported.test.format)
            assert.equals("Test macro", exported.test.description)
        end)

        it("includes aliases in export", function()
            local exported = registry:export()

            assert.equals(2, #exported.test.aliases)
        end)

        it("includes disabled state in export", function()
            registry:disable("test")
            local exported = registry:export()

            assert.is_true(exported.test.disabled)
        end)
    end)

    describe("clear", function()
        it("removes all macros", function()
            local registry = MacroRegistry.new()
            registry:register("test1", { handler = function() end })
            registry:register("test2", { handler = function() end })

            registry:clear()

            assert.equals(0, registry:count())
        end)

        it("clears aliases", function()
            local registry = MacroRegistry.new()
            registry:register("test", {
                handler = function() end,
                aliases = { "t" },
            })

            registry:clear()

            assert.is_nil(registry:get("t"))
        end)

        it("clears categories", function()
            local registry = MacroRegistry.new()
            registry:register("test", {
                handler = function() end,
                category = MacroRegistry.CATEGORY.DATA,
            })

            registry:clear()

            assert.equals(0, #registry:get_by_category(MacroRegistry.CATEGORY.DATA))
        end)
    end)
end)
