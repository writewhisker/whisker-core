-- Whisker Lifecycle & System Macros
-- Implements timing, events, and system utility macros
-- Compatible with Twine lifecycle patterns
--
-- lib/whisker/script/macros/lifecycle/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Lifecycle = {}

--- Module version
Lifecycle.VERSION = "1.0.0"

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Parse time duration string to milliseconds
-- @param value string|number Time value (e.g., "2s", "500ms", 2000)
-- @return number Milliseconds
local function parse_duration(value)
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "string" then
        return 0
    end

    -- Try to parse as number first
    local num = tonumber(value)
    if num then
        return num
    end

    -- Parse duration with unit
    local amount, unit = value:match("^(%d+%.?%d*)%s*(%a+)$")
    if amount then
        amount = tonumber(amount)
        unit = unit:lower()

        if unit == "s" or unit == "sec" or unit == "second" or unit == "seconds" then
            return amount * 1000
        elseif unit == "ms" or unit == "millisecond" or unit == "milliseconds" then
            return amount
        elseif unit == "m" or unit == "min" or unit == "minute" or unit == "minutes" then
            return amount * 60000
        end
    end

    return 0
end

-- ============================================================================
-- Timing/Event Macros
-- ============================================================================

--- live macro - Continuously update content
-- Harlowe: (live:)
Lifecycle.live_macro = Macros.define(
    function(ctx, args)
        local interval = args[1] or "1s"
        local content = args[2]

        local interval_ms = parse_duration(interval)

        local live_data = {
            _type = "live",
            interval_ms = interval_ms,
            content = content,
            active = true,
        }

        ctx:_emit_event("LIVE_START", live_data)

        return live_data
    end,
    {
        signature = Signature.builder()
            :optional("interval", "any", "1s", "Update interval")
            :optional("content", "any", nil, "Content to update")
            :build(),
        description = "Continuously update content at interval",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(live: 2s)[Current time: $time]",
        },
    }
)

--- stop macro - Stop live/repeating macros
-- Harlowe: (stop:)
Lifecycle.stop_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local stop_data = {
            _type = "stop",
            target = target,
        }

        ctx:_emit_event("LIVE_STOP", stop_data)

        return stop_data
    end,
    {
        signature = Signature.builder()
            :optional("target", "any", nil, "Specific target to stop")
            :build(),
        description = "Stop live/repeating content",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(stop:)",
        },
    }
)

--- after macro - Execute after delay
-- Chapbook: [after time]
Lifecycle.after_macro = Macros.define(
    function(ctx, args)
        local delay = args[1] or "1s"
        local content = args[2]

        local delay_ms = parse_duration(delay)

        local after_data = {
            _type = "after",
            delay_ms = delay_ms,
            content = content,
        }

        ctx:_emit_event("AFTER", after_data)

        return after_data
    end,
    {
        signature = Signature.builder()
            :required("delay", "any", "Delay before execution")
            :optional("content", "any", nil, "Content to show")
            :build(),
        description = "Execute content after delay",
        format = Macros.FORMAT.CHAPBOOK,
        category = Macros.CATEGORY.LIFECYCLE,
        async = true,
        examples = {
            "(after: 2s)[This appears after 2 seconds]",
        },
    }
)

--- event macro - Handle events
-- Harlowe: (event:)
Lifecycle.event_macro = Macros.define(
    function(ctx, args)
        local event_name = args[1]
        local handler = args[2]
        local options = args[3] or {}

        local event_data = {
            _type = "event_handler",
            event = event_name,
            handler = handler,
            once = options.once or false,
        }

        ctx:_emit_event("REGISTER_EVENT", event_data)

        return event_data
    end,
    {
        signature = Signature.builder()
            :required("event", "string", "Event name to handle")
            :optional("handler", "any", nil, "Handler function or content")
            :optional("options", "table", {}, "Event options")
            :build(),
        description = "Register an event handler",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(event: 'click')[Handle click]",
        },
    }
)

--- timeout macro - Execute after timeout (one-shot)
Lifecycle.timeout_macro = Macros.define(
    function(ctx, args)
        local delay = args[1]
        local action = args[2]

        local delay_ms = parse_duration(delay)

        local timeout_data = {
            _type = "timeout",
            delay_ms = delay_ms,
            action = action,
            id = tostring(os.time()) .. "_" .. math.random(1000),
        }

        ctx:_emit_event("TIMEOUT", timeout_data)

        return timeout_data
    end,
    {
        signature = Signature.builder()
            :required("delay", "any", "Delay before execution")
            :optional("action", "any", nil, "Action to execute")
            :build(),
        description = "Execute action after timeout",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        async = true,
        examples = {
            "(timeout: 5s, (goto: 'timeout-passage'))",
        },
    }
)

--- interval macro - Execute repeatedly at interval
Lifecycle.interval_macro = Macros.define(
    function(ctx, args)
        local period = args[1]
        local action = args[2]
        local options = args[3] or {}

        local period_ms = parse_duration(period)

        local interval_data = {
            _type = "interval",
            period_ms = period_ms,
            action = action,
            max_count = options.max or nil,
            current_count = 0,
            id = tostring(os.time()) .. "_" .. math.random(1000),
        }

        ctx:_emit_event("INTERVAL_START", interval_data)

        return interval_data
    end,
    {
        signature = Signature.builder()
            :required("period", "any", "Interval period")
            :optional("action", "any", nil, "Action to execute")
            :optional("options", "table", {}, "Interval options")
            :build(),
        description = "Execute action repeatedly at interval",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(interval: 1s, (increment: $timer))",
        },
    }
)

--- clearinterval macro - Clear an interval
Lifecycle.clearinterval_macro = Macros.define(
    function(ctx, args)
        local id = args[1]

        local clear_data = {
            _type = "clear_interval",
            id = id,
        }

        ctx:_emit_event("INTERVAL_STOP", clear_data)

        return clear_data
    end,
    {
        signature = Signature.builder()
            :required("id", "any", "Interval ID to clear")
            :build(),
        description = "Clear an interval",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(clearinterval: $timerId)",
        },
    }
)

-- ============================================================================
-- Passage Lifecycle Macros
-- ============================================================================

--- passagestart macro - Register handler for passage start
Lifecycle.passagestart_macro = Macros.define(
    function(ctx, args)
        local handler = args[1]

        local event_data = {
            _type = "lifecycle_handler",
            lifecycle = "passage_start",
            handler = handler,
        }

        ctx:_emit_event("REGISTER_LIFECYCLE", event_data)

        return event_data
    end,
    {
        signature = Signature.builder()
            :required("handler", "any", "Handler to execute")
            :build(),
        description = "Execute when passage starts rendering",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(passagestart: (print: 'Loading...'))",
        },
    }
)

--- passageend macro - Register handler for passage end
Lifecycle.passageend_macro = Macros.define(
    function(ctx, args)
        local handler = args[1]

        local event_data = {
            _type = "lifecycle_handler",
            lifecycle = "passage_end",
            handler = handler,
        }

        ctx:_emit_event("REGISTER_LIFECYCLE", event_data)

        return event_data
    end,
    {
        signature = Signature.builder()
            :required("handler", "any", "Handler to execute")
            :build(),
        description = "Execute when passage finishes rendering",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(passageend: (autosave:))",
        },
    }
)

--- storyready macro - Register handler for story ready
Lifecycle.storyready_macro = Macros.define(
    function(ctx, args)
        local handler = args[1]

        local event_data = {
            _type = "lifecycle_handler",
            lifecycle = "story_ready",
            handler = handler,
        }

        ctx:_emit_event("REGISTER_LIFECYCLE", event_data)

        return event_data
    end,
    {
        signature = Signature.builder()
            :required("handler", "any", "Handler to execute")
            :build(),
        description = "Execute when story is ready",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(storyready: (set: $initialized to true))",
        },
    }
)

-- ============================================================================
-- System Utility Macros
-- ============================================================================

--- random macro - Generate random number
-- Harlowe: (random: min, max)
Lifecycle.random_macro = Macros.define(
    function(ctx, args)
        local min_val = args[1]
        local max_val = args[2]

        -- Handle single argument (0 to n)
        if max_val == nil then
            max_val = min_val
            min_val = 0
        end

        -- Ensure integers
        min_val = math.floor(min_val)
        max_val = math.floor(max_val)

        -- Swap if needed
        if min_val > max_val then
            min_val, max_val = max_val, min_val
        end

        return math.random(min_val, max_val)
    end,
    {
        signature = Signature.builder()
            :required("min_or_max", "number", "Minimum value (or max if single arg)")
            :optional("max", "number", nil, "Maximum value")
            :build(),
        description = "Generate random integer between min and max",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(random: 1, 6)",
            "(random: 10)",
        },
    }
)

--- either macro - Random choice from options
-- Harlowe: (either: a, b, c)
Lifecycle.either_macro = Macros.define(
    function(ctx, args)
        if #args == 0 then
            return nil
        end

        local index = math.random(1, #args)
        return args[index]
    end,
    {
        signature = Signature.builder()
            :rest("options", "any", "Options to choose from")
            :build(),
        description = "Randomly choose one of the options",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(either: 'rock', 'paper', 'scissors')",
        },
    }
)

--- time macro - Get current time
Lifecycle.time_macro = Macros.define(
    function(ctx, args)
        local format_str = args[1] or "%H:%M:%S"

        return os.date(format_str)
    end,
    {
        signature = Signature.builder()
            :optional("format", "string", "%H:%M:%S", "Time format string")
            :build(),
        description = "Get current time",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(time:)",
            "(time: '%I:%M %p')",
        },
    }
)

--- date macro - Get current date
Lifecycle.date_macro = Macros.define(
    function(ctx, args)
        local format_str = args[1] or "%Y-%m-%d"

        return os.date(format_str)
    end,
    {
        signature = Signature.builder()
            :optional("format", "string", "%Y-%m-%d", "Date format string")
            :build(),
        description = "Get current date",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(date:)",
            "(date: '%B %d, %Y')",
        },
    }
)

--- now macro - Get current timestamp
Lifecycle.now_macro = Macros.define(
    function(ctx, args)
        return os.time()
    end,
    {
        signature = Signature.builder():build(),
        description = "Get current Unix timestamp",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(now:)",
        },
    }
)

--- visited macro - Check if passage was visited
-- Harlowe: (visited:), SugarCube: visited()
Lifecycle.visited_macro = Macros.define(
    function(ctx, args)
        local passage_name = args[1]

        -- If no argument, return count for current passage
        if passage_name == nil then
            passage_name = ctx:get("_current_passage")
        end

        local visits = ctx:get("_visits") or {}
        return visits[passage_name] or 0
    end,
    {
        signature = Signature.builder()
            :optional("passage", "string", nil, "Passage name to check")
            :build(),
        description = "Get visit count for a passage",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(if: (visited: 'intro') > 0)[You've been here before]",
        },
    }
)

--- visitedtag macro - Check if any passage with tag was visited
Lifecycle.visitedtag_macro = Macros.define(
    function(ctx, args)
        local tag = args[1]

        local tag_visits = ctx:get("_tag_visits") or {}
        return tag_visits[tag] or 0
    end,
    {
        signature = Signature.builder()
            :required("tag", "string", "Tag to check")
            :build(),
        description = "Get visit count for passages with tag",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(if: (visitedtag: 'combat') > 0)[You've fought before]",
        },
    }
)

--- turns macro - Get number of turns/moves
-- SugarCube: turns()
Lifecycle.turns_macro = Macros.define(
    function(ctx, args)
        return ctx:get("_turns") or 0
    end,
    {
        signature = Signature.builder():build(),
        description = "Get number of turns/passage changes",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(print: (turns:))",
        },
    }
)

-- ============================================================================
-- Script/Code Execution Macros
-- ============================================================================

--- script macro - Execute script code
-- SugarCube: <<script>>
Lifecycle.script_macro = Macros.define(
    function(ctx, args)
        local code = args[1]

        local script_data = {
            _type = "script",
            code = code,
        }

        ctx:_emit_event("EXECUTE_SCRIPT", script_data)

        return script_data
    end,
    {
        signature = Signature.builder()
            :required("code", "any", "Script code to execute")
            :build(),
        description = "Execute script code",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(script: 'console.log(\"Hello\")')",
        },
    }
)

--- run macro - Run code silently (no output)
-- SugarCube: <<run>>
Lifecycle.run_macro = Macros.define(
    function(ctx, args)
        local code = args[1]

        local run_data = {
            _type = "run",
            code = code,
            silent = true,
        }

        ctx:_emit_event("EXECUTE_SCRIPT", run_data)

        return nil  -- Silent, no output
    end,
    {
        signature = Signature.builder()
            :required("code", "any", "Code to run silently")
            :build(),
        description = "Run code silently without output",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(run: (set: $initialized to true))",
        },
    }
)

--- do macro - Execute an action
-- Harlowe: (do:)
Lifecycle.do_macro = Macros.define(
    function(ctx, args)
        local action = args[1]

        -- If action is a function, execute it
        if type(action) == "function" then
            return action(ctx)
        end

        -- If action is a table with handler, execute that
        if type(action) == "table" and action.handler then
            return action.handler(ctx, action.args or {})
        end

        -- Otherwise just return the action
        return action
    end,
    {
        signature = Signature.builder()
            :required("action", "any", "Action to execute")
            :build(),
        description = "Execute an action",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LIFECYCLE,
        examples = {
            "(do: (set: $x to 1))",
        },
    }
)

-- ============================================================================
-- Story Navigation Macros
-- ============================================================================

--- previous macro - Get previous passage name
-- SugarCube: previous()
Lifecycle.previous_macro = Macros.define(
    function(ctx, args)
        local history = ctx:get("_passage_history") or {}
        if #history < 2 then
            return nil
        end
        return history[#history - 1]
    end,
    {
        signature = Signature.builder():build(),
        description = "Get the previous passage name",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(link: 'Go back')[(goto: (previous:))]",
        },
    }
)

--- passage macro - Get current passage name or info
-- SugarCube: passage()
Lifecycle.passage_macro = Macros.define(
    function(ctx, args)
        local current = ctx:get("_current_passage")
        return current
    end,
    {
        signature = Signature.builder():build(),
        description = "Get current passage name",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(print: (passage:))",
        },
    }
)

--- tags macro - Get current passage tags
-- SugarCube: tags()
Lifecycle.tags_macro = Macros.define(
    function(ctx, args)
        local passage_name = args[1] or ctx:get("_current_passage")

        local passage_tags = ctx:get("_passage_tags") or {}
        return passage_tags[passage_name] or {}
    end,
    {
        signature = Signature.builder()
            :optional("passage", "string", nil, "Passage name (default: current)")
            :build(),
        description = "Get passage tags",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(tags:)",
            "(tags: 'intro')",
        },
    }
)

--- hastag macro - Check if passage has tag
Lifecycle.hastag_macro = Macros.define(
    function(ctx, args)
        local tag = args[1]
        local passage_name = args[2] or ctx:get("_current_passage")

        local passage_tags = ctx:get("_passage_tags") or {}
        local tags = passage_tags[passage_name] or {}

        for _, t in ipairs(tags) do
            if t == tag then
                return true
            end
        end
        return false
    end,
    {
        signature = Signature.builder()
            :required("tag", "string", "Tag to check for")
            :optional("passage", "string", nil, "Passage name (default: current)")
            :build(),
        description = "Check if passage has a specific tag",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(if: (hastag: 'combat'))[Combat music plays]",
        },
    }
)

--- passages macro - Get list of all passages
Lifecycle.passages_macro = Macros.define(
    function(ctx, args)
        local filter_tag = args[1]

        local all_passages = ctx:get("_all_passages") or {}

        if filter_tag == nil then
            return all_passages
        end

        -- Filter by tag
        local passage_tags = ctx:get("_passage_tags") or {}
        local filtered = {}

        for _, name in ipairs(all_passages) do
            local tags = passage_tags[name] or {}
            for _, t in ipairs(tags) do
                if t == filter_tag then
                    table.insert(filtered, name)
                    break
                end
            end
        end

        return filtered
    end,
    {
        signature = Signature.builder()
            :optional("tag", "string", nil, "Filter by tag")
            :build(),
        description = "Get list of all passages",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        pure = true,
        examples = {
            "(passages:)",
            "(passages: 'ending')",
        },
    }
)

-- ============================================================================
-- Console/Logging Macros
-- ============================================================================

--- log macro - Log message to console
Lifecycle.log_macro = Macros.define(
    function(ctx, args)
        local message = args[1]
        local level = args[2] or "info"

        local log_data = {
            _type = "log",
            message = message,
            level = level,
            timestamp = os.time(),
        }

        ctx:_emit_event("LOG", log_data)

        return log_data
    end,
    {
        signature = Signature.builder()
            :required("message", "any", "Message to log")
            :optional("level", "string", "info", "Log level: debug, info, warn, error")
            :build(),
        description = "Log message to console",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        examples = {
            "(log: 'Debug info')",
            "(log: 'Error occurred', 'error')",
        },
    }
)

--- assert macro - Assert condition is true
Lifecycle.assert_macro = Macros.define(
    function(ctx, args)
        local condition = args[1]
        local message = args[2] or "Assertion failed"

        if not condition then
            local assert_data = {
                _type = "assertion_failed",
                message = message,
            }
            ctx:_emit_event("ASSERTION_FAILED", assert_data)
            return nil, message
        end

        return true
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "Condition to assert")
            :optional("message", "string", "Assertion failed", "Error message")
            :build(),
        description = "Assert condition is true",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UTILITY,
        examples = {
            "(assert: $health > 0, 'Player must be alive')",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all lifecycle macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Lifecycle.register_all(registry)
    local macros = {
        -- Timing/events
        ["live"] = Lifecycle.live_macro,
        ["stop"] = Lifecycle.stop_macro,
        ["after"] = Lifecycle.after_macro,
        ["event"] = Lifecycle.event_macro,
        ["timeout"] = Lifecycle.timeout_macro,
        ["interval"] = Lifecycle.interval_macro,
        ["clearinterval"] = Lifecycle.clearinterval_macro,

        -- Passage lifecycle
        ["passagestart"] = Lifecycle.passagestart_macro,
        ["passageend"] = Lifecycle.passageend_macro,
        ["storyready"] = Lifecycle.storyready_macro,

        -- System utilities
        ["random"] = Lifecycle.random_macro,
        ["either"] = Lifecycle.either_macro,
        ["time"] = Lifecycle.time_macro,
        ["date"] = Lifecycle.date_macro,
        ["now"] = Lifecycle.now_macro,
        ["visited"] = Lifecycle.visited_macro,
        ["visitedtag"] = Lifecycle.visitedtag_macro,
        ["turns"] = Lifecycle.turns_macro,

        -- Script/code
        ["script"] = Lifecycle.script_macro,
        ["run"] = Lifecycle.run_macro,
        ["do"] = Lifecycle.do_macro,

        -- Navigation
        ["previous"] = Lifecycle.previous_macro,
        ["passage"] = Lifecycle.passage_macro,
        ["tags"] = Lifecycle.tags_macro,
        ["hastag"] = Lifecycle.hastag_macro,
        ["passages"] = Lifecycle.passages_macro,

        -- Logging
        ["log"] = Lifecycle.log_macro,
        ["assert"] = Lifecycle.assert_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Lifecycle
