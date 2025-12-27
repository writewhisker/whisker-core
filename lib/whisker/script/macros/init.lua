-- Whisker Macro System
-- Entry point for macro infrastructure
-- Provides registry, signature validation, and execution context
--
-- lib/whisker/script/macros/init.lua

local MacroRegistry = require("whisker.script.macros.registry")
local MacroSignature = require("whisker.script.macros.signature")
local MacroContext = require("whisker.script.macros.context")

local Macros = {}

--- Module version
Macros.VERSION = "1.0.0"

--- Module dependencies for DI container
Macros._dependencies = { "event_bus", "game_state" }

-- ============================================================================
-- Exports
-- ============================================================================

-- Core components
Macros.Registry = MacroRegistry
Macros.Signature = MacroSignature
Macros.Context = MacroContext

-- Convenience exports for types
Macros.TYPE = MacroSignature.TYPE
Macros.CATEGORY = MacroRegistry.CATEGORY
Macros.FORMAT = MacroRegistry.FORMAT
Macros.FLAG = MacroContext.FLAG

-- ============================================================================
-- Factory Functions
-- ============================================================================

--- Create a macro system with all components
-- @param deps table Dependencies (event_bus, game_state, story)
-- @return table System with registry, context
function Macros.create_system(deps)
    deps = deps or {}

    local registry = MacroRegistry.new({ event_bus = deps.event_bus })

    local context = MacroContext.new({
        event_bus = deps.event_bus,
        game_state = deps.game_state,
        story = deps.story,
        registry = registry,
        interpreter = deps.interpreter,
    })

    return {
        registry = registry,
        context = context,

        -- Convenience method to register and get handler
        register = function(self, name, definition)
            return self.registry:register(name, definition)
        end,

        -- Convenience method to execute macro
        execute = function(self, name, args)
            return self.registry:execute(name, self.context, args)
        end,

        -- Reset system state
        reset = function(self)
            self.context:reset({ all = true })
        end,
    }
end

--- Create a new registry
-- @param deps table Optional dependencies
-- @return MacroRegistry
function Macros.create_registry(deps)
    return MacroRegistry.new(deps)
end

--- Create a new signature
-- @param params table Parameter definitions
-- @return MacroSignature
function Macros.create_signature(params)
    return MacroSignature.new(params)
end

--- Create a signature from string
-- @param definition string The signature string
-- @return MacroSignature
function Macros.signature_from_string(definition)
    return MacroSignature.from_string(definition)
end

--- Get a signature builder
-- @return SignatureBuilder
function Macros.signature_builder()
    return MacroSignature.builder()
end

--- Create a new context
-- @param deps table Dependencies
-- @return MacroContext
function Macros.create_context(deps)
    return MacroContext.new(deps)
end

-- ============================================================================
-- Macro Definition Helpers
-- ============================================================================

--- Create a simple macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define(handler, options)
    options = options or {}
    return {
        handler = handler,
        signature = options.signature,
        category = options.category or MacroRegistry.CATEGORY.CUSTOM,
        format = options.format or MacroRegistry.FORMAT.WHISKER,
        description = options.description or "",
        examples = options.examples or {},
        aliases = options.aliases,
        deprecated = options.deprecated,
        replacement = options.replacement,
        async = options.async or false,
        pure = options.pure or false,
    }
end

--- Create a control flow macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_control(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.CONTROL
    return Macros.define(handler, options)
end

--- Create a data macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_data(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.DATA
    return Macros.define(handler, options)
end

--- Create a text macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_text(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.TEXT
    return Macros.define(handler, options)
end

--- Create a link macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_link(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.LINK
    return Macros.define(handler, options)
end

--- Create a UI macro definition
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_ui(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.UI
    return Macros.define(handler, options)
end

--- Create a utility macro definition (pure function)
-- @param handler function The handler function
-- @param options table Optional settings
-- @return table Macro definition
function Macros.define_utility(handler, options)
    options = options or {}
    options.category = MacroRegistry.CATEGORY.UTILITY
    options.pure = true
    return Macros.define(handler, options)
end

-- ============================================================================
-- Validation Helpers
-- ============================================================================

--- Validate macro arguments against signature
-- @param signature MacroSignature The signature
-- @param args table The arguments
-- @return boolean, table Success and errors
function Macros.validate_args(signature, args)
    if type(signature) == "string" then
        signature = MacroSignature.from_string(signature)
    end
    return signature:validate(args)
end

--- Process arguments (apply defaults, transforms)
-- @param signature MacroSignature The signature
-- @param args table The arguments
-- @return table Processed arguments
function Macros.process_args(signature, args)
    if type(signature) == "string" then
        signature = MacroSignature.from_string(signature)
    end
    return signature:process(args)
end

-- ============================================================================
-- Error Helpers
-- ============================================================================

--- Create a macro error
-- @param message string The error message
-- @param details table Optional details
-- @return table Error object
function Macros.error(message, details)
    return {
        type = "MACRO_ERROR",
        message = message,
        details = details or {},
        timestamp = os.time(),
    }
end

--- Create an argument error
-- @param param_name string The parameter name
-- @param expected string Expected type/value
-- @param actual string Actual type/value
-- @return table Error object
function Macros.arg_error(param_name, expected, actual)
    return Macros.error(
        string.format("Invalid argument '%s': expected %s, got %s",
            param_name, expected, tostring(actual)),
        {
            param = param_name,
            expected = expected,
            actual = actual,
        }
    )
end

--- Create a type error
-- @param value any The value
-- @param expected_type string The expected type
-- @return table Error object
function Macros.type_error(value, expected_type)
    return Macros.error(
        string.format("Type error: expected %s, got %s",
            expected_type, type(value)),
        {
            expected = expected_type,
            actual = type(value),
        }
    )
end

-- ============================================================================
-- Result Helpers
-- ============================================================================

--- Create a successful result
-- @param value any The result value
-- @return table Result object
function Macros.ok(value)
    return {
        ok = true,
        value = value,
    }
end

--- Create a failure result
-- @param error_obj any The error
-- @return table Result object
function Macros.fail(error_obj)
    return {
        ok = false,
        error = error_obj,
    }
end

--- Check if result is ok
-- @param result table The result
-- @return boolean
function Macros.is_ok(result)
    return result and result.ok == true
end

--- Unwrap result value or error
-- @param result table The result
-- @return any, any Value and error
function Macros.unwrap(result)
    if result and result.ok then
        return result.value, nil
    else
        return nil, result and result.error
    end
end

return Macros
