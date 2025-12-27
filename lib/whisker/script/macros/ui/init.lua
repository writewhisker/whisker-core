-- Whisker UI Macros
-- Implements UI interaction macros compatible with Twine formats
-- Supports Harlowe, SugarCube, and Chapbook-style dialogs and inputs
--
-- lib/whisker/script/macros/ui/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local UI = {}

--- Module version
UI.VERSION = "1.0.0"

-- ============================================================================
-- Dialog Macros
-- ============================================================================

--- dialog / popup macro - Show a dialog box
-- Harlowe: (dialog: 'title', 'content')
-- SugarCube: <<dialog 'title'>>content<</dialog>>
UI.dialog_macro = Macros.define_ui(
    function(ctx, args)
        local title = args[1]
        local content = args[2]
        local options = args[3] or {}

        if type(title) == "table" and title._is_expression then
            title = ctx:eval(title)
        end

        if type(content) == "function" then
            content = content(ctx)
        end

        local dialog_data = {
            _type = "dialog",
            title = tostring(title or ""),
            content = content,
            options = options,
        }

        -- Emit dialog event
        ctx:_emit_event("DIALOG_OPEN", dialog_data)

        return dialog_data
    end,
    {
        signature = Signature.builder()
            :required("title", "any", "Dialog title")
            :optional("content", "any", nil, "Dialog content")
            :optional("options", "table", nil, "Dialog options")
            :build(),
        description = "Show a dialog box",
        format = Macros.FORMAT.WHISKER,
        aliases = { "popup" },
        examples = {
            "(dialog: 'Warning', 'Are you sure?')",
            "<<dialog 'Info'>>Details here<</dialog>>",
        },
    }
)

--- alert macro - Show an alert dialog
-- Harlowe: (alert: 'message')
-- JavaScript-style alert
UI.alert_macro = Macros.define_ui(
    function(ctx, args)
        local message = args[1]

        if type(message) == "table" and message._is_expression then
            message = ctx:eval(message)
        end

        local alert_data = {
            _type = "alert",
            message = tostring(message or ""),
        }

        ctx:_emit_event("DIALOG_OPEN", {
            dialog_type = "alert",
            message = alert_data.message,
        })

        return alert_data
    end,
    {
        signature = Signature.builder()
            :required("message", "any", "Alert message")
            :build(),
        description = "Show an alert dialog",
        format = Macros.FORMAT.HARLOWE,
        examples = {
            "(alert: 'Game saved!')",
        },
    }
)

--- confirm macro - Show a confirmation dialog
-- Harlowe: (confirm: 'question')
-- Returns true/false based on user choice
UI.confirm_macro = Macros.define_ui(
    function(ctx, args)
        local message = args[1]
        local default = args[2]

        if type(message) == "table" and message._is_expression then
            message = ctx:eval(message)
        end

        local confirm_data = {
            _type = "confirm",
            message = tostring(message or ""),
            default = default,
            result = nil,  -- Will be set by client
        }

        ctx:_emit_event("INPUT_REQUESTED", {
            input_type = "confirm",
            message = confirm_data.message,
            default = default,
        })

        return confirm_data
    end,
    {
        signature = Signature.builder()
            :required("message", "any", "Confirmation message")
            :optional("default", "boolean", nil, "Default selection")
            :build(),
        description = "Show a confirmation dialog",
        format = Macros.FORMAT.HARLOWE,
        async = true,
        examples = {
            "(confirm: 'Are you sure you want to quit?')",
        },
    }
)

--- prompt macro - Show a text input dialog
-- Harlowe: (prompt: 'question', 'default')
-- Returns entered text
UI.prompt_macro = Macros.define_ui(
    function(ctx, args)
        local message = args[1]
        local default = args[2] or ""

        if type(message) == "table" and message._is_expression then
            message = ctx:eval(message)
        end

        local prompt_data = {
            _type = "prompt",
            message = tostring(message or ""),
            default = tostring(default),
            result = nil,  -- Will be set by client
        }

        ctx:_emit_event("INPUT_REQUESTED", {
            input_type = "prompt",
            message = prompt_data.message,
            default = prompt_data.default,
        })

        return prompt_data
    end,
    {
        signature = Signature.builder()
            :required("message", "any", "Prompt message")
            :optional("default", "string", "", "Default value")
            :build(),
        description = "Show a text input dialog",
        format = Macros.FORMAT.HARLOWE,
        async = true,
        examples = {
            "(prompt: 'Enter your name:', 'Player')",
        },
    }
)

-- ============================================================================
-- Input Macros
-- ============================================================================

--- textbox macro - Create a text input field
-- SugarCube: <<textbox '$var' 'default'>>
UI.textbox_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local default = args[2] or ""
        local options = args[3] or {}

        -- Normalize variable name
        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        -- Get current value or use default
        local current = ctx:get(variable)
        if current == nil then
            ctx:set(variable, default)
            current = default
        end

        local textbox_data = {
            _type = "textbox",
            variable = variable,
            value = tostring(current),
            placeholder = options.placeholder or "",
            maxlength = options.maxlength,
            readonly = options.readonly or false,
        }

        ctx:_emit_event("INPUT_CREATED", textbox_data)

        return textbox_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :optional("default", "string", "", "Default value")
            :optional("options", "table", nil, "Input options")
            :build(),
        description = "Create a text input field",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<textbox '$playerName' 'Anonymous'>>",
        },
    }
)

--- textarea macro - Create a multi-line text input
-- SugarCube: <<textarea '$var' 'default'>>
UI.textarea_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local default = args[2] or ""
        local options = args[3] or {}

        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        local current = ctx:get(variable)
        if current == nil then
            ctx:set(variable, default)
            current = default
        end

        local textarea_data = {
            _type = "textarea",
            variable = variable,
            value = tostring(current),
            rows = options.rows or 4,
            cols = options.cols or 40,
            placeholder = options.placeholder or "",
        }

        ctx:_emit_event("INPUT_CREATED", textarea_data)

        return textarea_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :optional("default", "string", "", "Default value")
            :optional("options", "table", nil, "Input options")
            :build(),
        description = "Create a multi-line text input",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<textarea '$notes' ''>>",
        },
    }
)

--- checkbox macro - Create a checkbox
-- SugarCube: <<checkbox '$var' false true>>
UI.checkbox_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local unchecked_val = args[2]
        local checked_val = args[3]
        local label = args[4]

        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        -- Set defaults
        if unchecked_val == nil then unchecked_val = false end
        if checked_val == nil then checked_val = true end

        local current = ctx:get(variable)
        if current == nil then
            ctx:set(variable, unchecked_val)
            current = unchecked_val
        end

        local checkbox_data = {
            _type = "checkbox",
            variable = variable,
            checked = current == checked_val,
            unchecked_value = unchecked_val,
            checked_value = checked_val,
            label = label or "",
        }

        ctx:_emit_event("INPUT_CREATED", checkbox_data)

        return checkbox_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :optional("unchecked", "any", false, "Value when unchecked")
            :optional("checked", "any", true, "Value when checked")
            :optional("label", "string", nil, "Checkbox label")
            :build(),
        description = "Create a checkbox",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<checkbox '$soundEnabled' false true 'Enable Sound'>>",
        },
    }
)

--- radiobutton macro - Create a radio button
-- SugarCube: <<radiobutton '$var' 'value'>>
UI.radiobutton_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local value = args[2]
        local label = args[3]

        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        local current = ctx:get(variable)

        local radio_data = {
            _type = "radiobutton",
            variable = variable,
            value = value,
            selected = current == value,
            label = label or tostring(value),
        }

        ctx:_emit_event("INPUT_CREATED", radio_data)

        return radio_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :required("value", "any", "Value when selected")
            :optional("label", "string", nil, "Radio button label")
            :build(),
        description = "Create a radio button",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<radiobutton '$difficulty' 'easy' 'Easy'>>",
        },
    }
)

--- listbox / select macro - Create a dropdown select
-- SugarCube: <<listbox '$var'>><<option 'value'>><</listbox>>
UI.listbox_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local options = args[2] or {}

        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        local current = ctx:get(variable)

        -- If options is an array, convert to option format
        local select_options = {}
        if type(options) == "table" then
            for i, opt in ipairs(options) do
                if type(opt) == "table" then
                    table.insert(select_options, {
                        value = opt.value or opt[1],
                        label = opt.label or opt[2] or tostring(opt.value or opt[1]),
                    })
                else
                    table.insert(select_options, {
                        value = opt,
                        label = tostring(opt),
                    })
                end
            end
        end

        local listbox_data = {
            _type = "listbox",
            variable = variable,
            selected = current,
            options = select_options,
        }

        ctx:_emit_event("INPUT_CREATED", listbox_data)

        return listbox_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :optional("options", "table", nil, "Array of options")
            :build(),
        description = "Create a dropdown select",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "select", "dropdown" },
        examples = {
            "<<listbox '$color'>><<option 'red'>><<option 'blue'>><</listbox>>",
        },
    }
)

--- numberbox macro - Create a number input
-- SugarCube: <<numberbox '$var' 0>>
UI.numberbox_macro = Macros.define_ui(
    function(ctx, args)
        local variable = args[1]
        local default = args[2] or 0
        local options = args[3] or {}

        if type(variable) == "string" then
            variable = variable:gsub("^%$", "")
        end

        local current = ctx:get(variable)
        if current == nil then
            ctx:set(variable, default)
            current = default
        end

        local numberbox_data = {
            _type = "numberbox",
            variable = variable,
            value = tonumber(current) or 0,
            min = options.min,
            max = options.max,
            step = options.step or 1,
        }

        ctx:_emit_event("INPUT_CREATED", numberbox_data)

        return numberbox_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "any", "Variable to bind")
            :optional("default", "number", 0, "Default value")
            :optional("options", "table", nil, "Input options (min, max, step)")
            :build(),
        description = "Create a number input field",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<numberbox '$age' 18>>",
        },
    }
)

--- button macro - Create a clickable button
-- SugarCube: <<button 'text'>>action<</button>>
UI.button_macro = Macros.define_ui(
    function(ctx, args)
        local text = args[1]
        local action = args[2]
        local options = args[3] or {}

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        local button_data = {
            _type = "button",
            text = tostring(text or ""),
            action = action,
            disabled = options.disabled or false,
            id = options.id,
        }

        ctx:_emit_event("INPUT_CREATED", button_data)

        return button_data
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Button text")
            :optional("action", "function", nil, "Action on click")
            :optional("options", "table", nil, "Button options")
            :build(),
        description = "Create a clickable button",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<button 'Submit'>><<goto 'Results'>><</button>>",
        },
    }
)

-- ============================================================================
-- Timing Macros
-- ============================================================================

--- timed macro - Execute after delay
-- SugarCube: <<timed 2s>>content<</timed>>
UI.timed_macro = Macros.define_ui(
    function(ctx, args)
        local delay = args[1]
        local content = args[2]
        local options = args[3] or {}

        -- Parse delay string (e.g., "2s", "500ms")
        local delay_ms = 0
        if type(delay) == "number" then
            delay_ms = delay
        elseif type(delay) == "string" then
            local num, unit = delay:match("^(%d+%.?%d*)(%a*)$")
            num = tonumber(num) or 0
            unit = unit:lower()
            if unit == "s" or unit == "sec" then
                delay_ms = num * 1000
            elseif unit == "ms" then
                delay_ms = num
            else
                delay_ms = num * 1000  -- Default to seconds
            end
        end

        local timed_data = {
            _type = "timed",
            delay_ms = delay_ms,
            content = content,
            transition = options.transition or "fade",
        }

        ctx:_emit_event("TIMER_CREATED", {
            delay = delay_ms,
            content = content,
        })

        return timed_data
    end,
    {
        signature = Signature.builder()
            :required("delay", "any", "Delay (number in ms or string like '2s')")
            :optional("content", "any", nil, "Content to show after delay")
            :optional("options", "table", nil, "Timing options")
            :build(),
        description = "Show content after a delay",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "after", "delay" },
        examples = {
            "<<timed 2s>>Two seconds have passed<</timed>>",
        },
    }
)

--- repeat macro - Execute repeatedly
-- SugarCube: <<repeat 1s>>content<</repeat>>
UI.repeat_macro = Macros.define_ui(
    function(ctx, args)
        local interval = args[1]
        local content = args[2]
        local options = args[3] or {}

        -- Parse interval string
        local interval_ms = 0
        if type(interval) == "number" then
            interval_ms = interval
        elseif type(interval) == "string" then
            local num, unit = interval:match("^(%d+%.?%d*)(%a*)$")
            num = tonumber(num) or 0
            unit = unit:lower()
            if unit == "s" or unit == "sec" then
                interval_ms = num * 1000
            elseif unit == "ms" then
                interval_ms = num
            else
                interval_ms = num * 1000
            end
        end

        local repeat_data = {
            _type = "repeat",
            interval_ms = interval_ms,
            content = content,
            max_count = options.max or nil,
            current_count = 0,
        }

        ctx:_emit_event("TIMER_CREATED", {
            type = "repeat",
            interval = interval_ms,
            content = content,
        })

        return repeat_data
    end,
    {
        signature = Signature.builder()
            :required("interval", "any", "Interval (number in ms or string like '1s')")
            :optional("content", "any", nil, "Content to repeat")
            :optional("options", "table", nil, "Options (max count, etc)")
            :build(),
        description = "Execute content repeatedly at interval",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "every", "interval" },
        examples = {
            "<<repeat 1s>>Tick<</repeat>>",
        },
    }
)

--- stop macro (for timers) - Stop all timed/repeat macros
UI.stop_timers_macro = Macros.define_ui(
    function(ctx, args)
        ctx:_emit_event("TIMER_CANCELLED", { all = true })
        return true
    end,
    {
        description = "Stop all active timers",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "stop-all" },
        examples = {
            "<<stop-all>>",
        },
    }
)

-- ============================================================================
-- Transition Macros
-- ============================================================================

--- transition macro - Apply visual transition
UI.transition_macro = Macros.define_ui(
    function(ctx, args)
        local transition_type = args[1] or "fade"
        local duration = args[2] or "500ms"
        local content = args[3]

        -- Parse duration
        local duration_ms = 0
        if type(duration) == "number" then
            duration_ms = duration
        elseif type(duration) == "string" then
            local num, unit = duration:match("^(%d+%.?%d*)(%a*)$")
            num = tonumber(num) or 0
            unit = unit:lower()
            if unit == "s" then
                duration_ms = num * 1000
            else
                duration_ms = num
            end
        end

        local transition_data = {
            _type = "transition",
            transition = transition_type,
            duration_ms = duration_ms,
            content = content,
        }

        ctx:_emit_event("EFFECT_START", {
            effect_type = "transition",
            transition = transition_type,
            duration = duration_ms,
        })

        return transition_data
    end,
    {
        signature = Signature.builder()
            :optional("type", "string", "fade", "Transition type")
            :optional("duration", "any", "500ms", "Duration")
            :optional("content", "any", nil, "Content to transition")
            :build(),
        description = "Apply visual transition effect",
        format = Macros.FORMAT.WHISKER,
        aliases = { "effect" },
        examples = {
            "(transition: 'fade', '1s')[Content]",
        },
    }
)

--- notify / toast macro - Show notification
UI.notify_macro = Macros.define_ui(
    function(ctx, args)
        local message = args[1]
        local options = args[2] or {}

        if type(message) == "table" and message._is_expression then
            message = ctx:eval(message)
        end

        local notify_data = {
            _type = "notification",
            message = tostring(message or ""),
            duration = options.duration or 3000,
            position = options.position or "top-right",
            style = options.style or "info",
        }

        ctx:_emit_event("DIALOG_OPEN", {
            dialog_type = "notification",
            data = notify_data,
        })

        return notify_data
    end,
    {
        signature = Signature.builder()
            :required("message", "any", "Notification message")
            :optional("options", "table", nil, "Notification options")
            :build(),
        description = "Show a notification/toast message",
        format = Macros.FORMAT.WHISKER,
        aliases = { "toast" },
        examples = {
            "(notify: 'Achievement unlocked!')",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all UI macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function UI.register_all(registry)
    local macros = {
        -- Dialogs
        ["dialog"] = UI.dialog_macro,
        ["alert"] = UI.alert_macro,
        ["confirm"] = UI.confirm_macro,
        ["prompt"] = UI.prompt_macro,

        -- Inputs
        ["textbox"] = UI.textbox_macro,
        ["textarea"] = UI.textarea_macro,
        ["checkbox"] = UI.checkbox_macro,
        ["radiobutton"] = UI.radiobutton_macro,
        ["listbox"] = UI.listbox_macro,
        ["numberbox"] = UI.numberbox_macro,
        ["button"] = UI.button_macro,

        -- Timing
        ["timed"] = UI.timed_macro,
        ["repeat"] = UI.repeat_macro,
        ["stop_timers"] = UI.stop_timers_macro,

        -- Transitions
        ["transition"] = UI.transition_macro,
        ["notify"] = UI.notify_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return UI
