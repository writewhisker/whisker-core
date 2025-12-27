-- Whisker Control Flow Macros
-- Implements control flow macros compatible with Twine formats
-- Supports Harlowe, SugarCube, and Chapbook-style conditionals
--
-- lib/whisker/script/macros/control/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Control = {}

--- Module version
Control.VERSION = "1.0.0"

-- ============================================================================
-- Conditional Macros (if/else-if/else)
-- ============================================================================

--- if macro - Conditional execution
-- Harlowe: (if: condition)[content]
-- SugarCube: <<if condition>>content<</if>>
-- Chapbook: [if condition]
Control.if_macro = Macros.define_control(
    function(ctx, args)
        local condition = args[1]
        local body = args[2]

        -- Evaluate condition if it's an expression
        if type(condition) == "table" and condition._is_expression then
            condition = ctx:eval(condition)
        end

        -- Handle variable references
        if type(condition) == "string" and condition:match("^%$?[%w_]+$") then
            condition = ctx:eval(condition)
        end

        -- Coerce to boolean
        local result = condition and true or false

        if result and body then
            if type(body) == "function" then
                return body(ctx)
            elseif type(body) == "string" then
                ctx:write(body)
                return body
            end
            return body
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "The condition to evaluate")
            :optional("body", "any", nil, "Content to execute if true")
            :build(),
        description = "Conditionally execute content",
        format = Macros.FORMAT.WHISKER,
        aliases = { "when" },
        examples = {
            "(if: $score > 10)[You win!]",
            "<<if $visited>>Welcome back<<else>>Hello<</if>>",
        },
    }
)

--- else macro - Alternative branch
-- Harlowe: (else:)[content]
-- SugarCube: <<else>>
-- Chapbook: [else]
Control.else_macro = Macros.define_control(
    function(ctx, args)
        local body = args[1]

        -- else always executes when reached (if was false)
        if body then
            if type(body) == "function" then
                return body(ctx)
            elseif type(body) == "string" then
                ctx:write(body)
                return body
            end
            return body
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :optional("body", "any", nil, "Content to execute")
            :build(),
        description = "Alternative branch when condition is false",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(else:)[Better luck next time]",
        },
    }
)

--- elseif / else-if macro
-- Harlowe: (else-if: condition)[content]
-- SugarCube: <<elseif condition>>
-- Chapbook: [else if condition]
Control.elseif_macro = Macros.define_control(
    function(ctx, args)
        local condition = args[1]
        local body = args[2]

        -- Evaluate condition
        if type(condition) == "table" and condition._is_expression then
            condition = ctx:eval(condition)
        end

        if type(condition) == "string" and condition:match("^%$?[%w_]+$") then
            condition = ctx:eval(condition)
        end

        local result = condition and true or false

        if result and body then
            if type(body) == "function" then
                return body(ctx)
            elseif type(body) == "string" then
                ctx:write(body)
                return body
            end
            return body
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "The condition to evaluate")
            :optional("body", "any", nil, "Content to execute if true")
            :build(),
        description = "Alternative conditional branch",
        format = Macros.FORMAT.WHISKER,
        aliases = { "else-if", "elif" },
        examples = {
            "(else-if: $score > 5)[Not bad!]",
        },
    }
)

--- unless macro - Negated conditional
-- Harlowe: (unless: condition)[content]
-- Chapbook: [unless condition]
Control.unless_macro = Macros.define_control(
    function(ctx, args)
        local condition = args[1]
        local body = args[2]

        -- Evaluate condition
        if type(condition) == "table" and condition._is_expression then
            condition = ctx:eval(condition)
        end

        if type(condition) == "string" and condition:match("^%$?[%w_]+$") then
            condition = ctx:eval(condition)
        end

        -- unless is inverted: execute when condition is false
        local result = not (condition and true or false)

        if result and body then
            if type(body) == "function" then
                return body(ctx)
            elseif type(body) == "string" then
                ctx:write(body)
                return body
            end
            return body
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "The condition to evaluate")
            :optional("body", "any", nil, "Content to execute if false")
            :build(),
        description = "Execute content when condition is false",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(unless: $hasKey)[The door is locked.]",
        },
    }
)

-- ============================================================================
-- Loop Macros (for, while)
-- ============================================================================

--- for macro - Iteration
-- Harlowe: (for: each _item, ...$array)[content]
-- SugarCube: <<for _i to $end>>
Control.for_macro = Macros.define_control(
    function(ctx, args)
        local iterator = args[1]  -- The iterable
        local body = args[2]      -- Body to execute

        if not iterator then
            return nil
        end

        local results = {}

        -- Handle different iterator types
        if type(iterator) == "table" then
            -- Array iteration
            for index, value in ipairs(iterator) do
                ctx:set("_i", index, { temp = true })
                ctx:set("_it", value, { temp = true })

                if type(body) == "function" then
                    local result = body(ctx)
                    if result then
                        table.insert(results, result)
                    end
                elseif type(body) == "string" then
                    table.insert(results, body)
                end
            end
        elseif type(iterator) == "number" then
            -- Numeric iteration: for(10) -> 1 to 10
            for i = 1, iterator do
                ctx:set("_i", i, { temp = true })

                if type(body) == "function" then
                    local result = body(ctx)
                    if result then
                        table.insert(results, result)
                    end
                elseif type(body) == "string" then
                    table.insert(results, body)
                end
            end
        end

        local output = table.concat(results, "")
        if output ~= "" then
            ctx:write(output)
        end

        return results
    end,
    {
        signature = Signature.builder()
            :required("iterator", "any", "Value(s) to iterate over")
            :optional("body", "any", nil, "Content to execute for each item")
            :build(),
        description = "Iterate over values",
        format = Macros.FORMAT.WHISKER,
        aliases = { "each", "foreach" },
        examples = {
            "(for: each _item, ...$inventory)[_item<br>]",
            "<<for _i to 5>>Counting: _i<</for>>",
        },
    }
)

--- range macro - Create a range for iteration
-- Creates a sequence of numbers for use with for
Control.range_macro = Macros.define_control(
    function(ctx, args)
        local start_val = args[1]
        local end_val = args[2]
        local step = args[3] or 1

        -- If only one argument, range is 1 to that number
        if end_val == nil then
            end_val = start_val
            start_val = 1
        end

        local result = {}
        if step > 0 then
            for i = start_val, end_val, step do
                table.insert(result, i)
            end
        elseif step < 0 then
            for i = start_val, end_val, step do
                table.insert(result, i)
            end
        end

        return result
    end,
    {
        signature = Signature.builder()
            :required("start", "number", "Start value (or end if only one arg)")
            :optional("end_val", "number", nil, "End value")
            :optional("step", "number", 1, "Step value")
            :build(),
        description = "Create a range of numbers",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(for: each _n, ...(range: 1, 10))[_n ]",
            "(range: 5) -> [1, 2, 3, 4, 5]",
        },
    }
)

--- while macro - Conditional loop
-- SugarCube: <<while condition>>
Control.while_macro = Macros.define_control(
    function(ctx, args)
        local condition_fn = args[1]
        local body = args[2]
        local max_iterations = args.max or 1000  -- Safety limit

        local results = {}
        local iterations = 0

        while iterations < max_iterations do
            iterations = iterations + 1

            -- Evaluate condition
            local condition
            if type(condition_fn) == "function" then
                condition = condition_fn(ctx)
            else
                condition = ctx:eval(condition_fn)
            end

            if not (condition and true or false) then
                break
            end

            -- Execute body
            if type(body) == "function" then
                local result = body(ctx)
                if result then
                    table.insert(results, result)
                end
            elseif type(body) == "string" then
                table.insert(results, body)
            end
        end

        if iterations >= max_iterations then
            ctx:_emit_event("LOOP_LIMIT_REACHED", {
                macro = "while",
                iterations = iterations,
                limit = max_iterations,
            })
        end

        local output = table.concat(results, "")
        if output ~= "" then
            ctx:write(output)
        end

        return results
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "Condition to check each iteration")
            :optional("body", "any", nil, "Content to execute while true")
            :build(),
        description = "Loop while condition is true",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "<<while $count > 0>>Count: $count<<set $count to $count - 1>><</while>>",
        },
    }
)

--- break macro - Exit from loop
Control.break_macro = Macros.define_control(
    function(ctx, args)
        ctx:set_flag("break_loop", true)
        return nil
    end,
    {
        description = "Exit from current loop",
        format = Macros.FORMAT.WHISKER,
        aliases = { "stop" },
    }
)

--- continue macro - Skip to next iteration
Control.continue_macro = Macros.define_control(
    function(ctx, args)
        ctx:set_flag("continue_loop", true)
        return nil
    end,
    {
        description = "Skip to next loop iteration",
        format = Macros.FORMAT.WHISKER,
        aliases = { "next" },
    }
)

-- ============================================================================
-- Switch/Case Macros
-- ============================================================================

--- switch macro - Multi-way branch
-- SugarCube: <<switch $var>><<case 1>>...<</switch>>
Control.switch_macro = Macros.define_control(
    function(ctx, args)
        local value = args[1]
        local cases = args[2]  -- Table of {value, body} pairs

        -- Evaluate the switch value
        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        elseif type(value) == "string" and value:match("^%$?[%w_]+$") then
            value = ctx:eval(value)
        end

        if not cases or type(cases) ~= "table" then
            return nil
        end

        -- Find matching case
        for _, case_item in ipairs(cases) do
            local case_value = case_item.value
            local case_body = case_item.body

            -- Handle default case
            if case_value == "_default" then
                if type(case_body) == "function" then
                    return case_body(ctx)
                else
                    ctx:write(tostring(case_body))
                    return case_body
                end
            end

            -- Check if values match
            if value == case_value then
                if type(case_body) == "function" then
                    return case_body(ctx)
                else
                    ctx:write(tostring(case_body))
                    return case_body
                end
            end
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to switch on")
            :required("cases", "table", "Case definitions")
            :build(),
        description = "Multi-way branch based on value",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "<<switch $season>><<case 'spring'>>Flowers<<case 'summer'>>Sun<</switch>>",
        },
    }
)

--- cond macro - Harlowe-style conditional chain
-- (cond: value, (is: a)[result a], (is: b)[result b])
Control.cond_macro = Macros.define_control(
    function(ctx, args)
        -- Iterate through pairs of condition and result
        for i = 1, #args, 2 do
            local condition = args[i]
            local result = args[i + 1]

            -- Evaluate condition
            if type(condition) == "table" and condition._is_expression then
                condition = ctx:eval(condition)
            end

            if condition then
                if type(result) == "function" then
                    return result(ctx)
                else
                    ctx:write(tostring(result))
                    return result
                end
            end
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :rest("pairs", "any", "Condition-result pairs")
            :build(),
        description = "Evaluate conditions in order, return first match",
        format = Macros.FORMAT.HARLOWE,
        examples = {
            "(cond: $x > 10, 'big', $x > 5, 'medium', true, 'small')",
        },
    }
)

-- ============================================================================
-- Flow Control Macros
-- ============================================================================

--- stop macro - Stop execution of current passage
Control.stop_macro = Macros.define_control(
    function(ctx, args)
        ctx:set_flag("stop_execution", true)
        return nil
    end,
    {
        description = "Stop executing current passage",
        format = Macros.FORMAT.WHISKER,
    }
)

--- return macro - Return a value
Control.return_macro = Macros.define_control(
    function(ctx, args)
        local value = args[1]

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        ctx:set_flag("return_value", value or true)
        ctx:set_flag("stop_execution", true)

        return value
    end,
    {
        signature = Signature.builder()
            :optional("value", "any", nil, "Value to return")
            :build(),
        description = "Return a value and stop execution",
        format = Macros.FORMAT.WHISKER,
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all control macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Control.register_all(registry)
    local macros = {
        ["if"] = Control.if_macro,
        ["else"] = Control.else_macro,
        ["elseif"] = Control.elseif_macro,
        ["unless"] = Control.unless_macro,
        ["for"] = Control.for_macro,
        ["range"] = Control.range_macro,
        ["while"] = Control.while_macro,
        ["break"] = Control.break_macro,
        ["continue"] = Control.continue_macro,
        ["switch"] = Control.switch_macro,
        ["cond"] = Control.cond_macro,
        ["stop"] = Control.stop_macro,
        ["return"] = Control.return_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Control
