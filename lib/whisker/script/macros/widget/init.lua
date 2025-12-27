-- Whisker Widget & Custom Macros
-- Implements widget definition, output control, and content embedding macros
-- Compatible with Twine custom widget and content manipulation patterns
--
-- lib/whisker/script/macros/widget/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Widget = {}

--- Module version
Widget.VERSION = "1.0.0"

-- ============================================================================
-- Widget Definition Macros
-- ============================================================================

--- widget macro - Define a custom widget/macro
-- SugarCube: <<widget>>, Chapbook: [define widget]
Widget.widget_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local body = args[2]
        local options = args[3] or {}

        if not name then
            return nil, "Widget name is required"
        end

        local widget_data = {
            _type = "widget",
            name = name,
            body = body,
            container = options.container or false,
            params = options.params or {},
        }

        -- Register the widget in context
        local widgets = ctx:get("_widgets") or {}
        widgets[name] = widget_data
        ctx:set("_widgets", widgets)

        ctx:_emit_event("WIDGET_DEFINE", widget_data)

        return widget_data
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Widget name")
            :optional("body", "any", nil, "Widget body/template")
            :optional("options", "table", {}, "Widget options")
            :build(),
        description = "Define a custom widget",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<widget 'greet'>>Hello, $name!<</widget>>",
            "(define: 'fancy-link')[A styled link]",
        },
    }
)

--- done macro - End widget/passage execution early
-- SugarCube: <<done>>, used to exit widget early
Widget.done_macro = Macros.define(
    function(ctx, args)
        local done_data = {
            _type = "done",
            _stops_execution = true,
        }

        ctx:set("_execution_halted", true)
        ctx:_emit_event("WIDGET_DONE", done_data)

        return done_data
    end,
    {
        signature = Signature.builder()
            :build(),
        description = "End widget execution early",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<if $error>><<done>><</if>>",
        },
    }
)

--- call macro - Call a defined widget
-- SugarCube: <<widgetname>>, Harlowe: (widgetname:)
Widget.call_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local call_args = args[2] or {}

        if not name then
            return nil, "Widget name is required"
        end

        local widgets = ctx:get("_widgets") or {}
        local widget_def = widgets[name]

        local call_data = {
            _type = "widget_call",
            name = name,
            args = call_args,
            exists = widget_def ~= nil,
            definition = widget_def,
        }

        ctx:_emit_event("WIDGET_CALL", call_data)

        return call_data
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Widget name to call")
            :optional("args", "table", {}, "Arguments to pass")
            :build(),
        description = "Call a defined widget",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<greet 'Player'>>",
            "(greet: 'Player')",
        },
    }
)

-- ============================================================================
-- Output Control Macros
-- ============================================================================

--- capture macro - Capture output into a variable
-- SugarCube: <<capture>>
Widget.capture_macro = Macros.define(
    function(ctx, args)
        local var_name = args[1]
        local content = args[2]

        if not var_name then
            return nil, "Variable name is required"
        end

        local capture_data = {
            _type = "capture",
            variable = var_name,
            content = content,
        }

        -- Store captured content
        if content then
            ctx:set(var_name, content)
        end

        ctx:_emit_event("CAPTURE", capture_data)

        return capture_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "string", "Variable to capture into")
            :optional("content", "any", nil, "Content to capture")
            :build(),
        description = "Capture output into a variable",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<capture '$result'>>Some text<</capture>>",
        },
    }
)

--- silently macro - Execute without producing output
-- SugarCube: <<silently>>, Harlowe: (verbatim:) variation
Widget.silently_macro = Macros.define(
    function(ctx, args)
        local content = args[1]

        local silent_data = {
            _type = "silent",
            content = content,
            _suppress_output = true,
        }

        ctx:_emit_event("SILENT_EXECUTE", silent_data)

        return silent_data
    end,
    {
        signature = Signature.builder()
            :optional("content", "any", nil, "Content to execute silently")
            :build(),
        description = "Execute code without output",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<silently>><<set $x to 5>><</silently>>",
        },
    }
)

--- nobr macro - Remove line breaks from output
-- SugarCube: <<nobr>>, Harlowe: (verbatim:)
Widget.nobr_macro = Macros.define(
    function(ctx, args)
        local content = args[1]

        local nobr_data = {
            _type = "nobr",
            content = content,
            _is_changer = true,
        }

        return nobr_data
    end,
    {
        signature = Signature.builder()
            :optional("content", "any", nil, "Content to strip line breaks from")
            :build(),
        description = "Remove line breaks from output",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "<<nobr>>Multi\nline\ntext<</nobr>>",
        },
    }
)

-- ============================================================================
-- Content Embedding Macros
-- ============================================================================

--- include macro - Include another passage's content
-- SugarCube: <<include>>, Harlowe: (display:)
Widget.include_macro = Macros.define(
    function(ctx, args)
        local passage_name = args[1]
        local options = args[2] or {}

        if not passage_name then
            return nil, "Passage name is required"
        end

        local include_data = {
            _type = "include",
            passage = passage_name,
            inherit_context = options.inherit_context ~= false,
            element = options.element,
        }

        ctx:_emit_event("INCLUDE", include_data)

        return include_data
    end,
    {
        signature = Signature.builder()
            :required("passage", "string", "Passage name to include")
            :optional("options", "table", {}, "Include options")
            :build(),
        description = "Include another passage's content",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        async = true,
        examples = {
            "<<include 'common-header'>>",
            "(display: 'sidebar-content')",
        },
    }
)

--- embed macro - Embed content inline
-- Chapbook: {embed passage: 'name'}
Widget.embed_macro = Macros.define(
    function(ctx, args)
        local source = args[1]
        local options = args[2] or {}

        if not source then
            return nil, "Source is required"
        end

        local embed_data = {
            _type = "embed",
            source = source,
            source_type = options.type or "passage",
            inline = options.inline ~= false,
        }

        ctx:_emit_event("EMBED", embed_data)

        return embed_data
    end,
    {
        signature = Signature.builder()
            :required("source", "string", "Source to embed")
            :optional("options", "table", {}, "Embed options")
            :build(),
        description = "Embed content inline",
        format = Macros.FORMAT.CHAPBOOK,
        category = Macros.CATEGORY.CUSTOM,
        async = true,
        examples = {
            "{embed passage: 'stats-display'}",
        },
    }
)

--- display macro - Display passage content
-- Harlowe: (display:), SugarCube: <<print>>
Widget.display_macro = Macros.define(
    function(ctx, args)
        local passage_name = args[1]

        if not passage_name then
            return nil, "Passage name is required"
        end

        local display_data = {
            _type = "display",
            passage = passage_name,
        }

        ctx:_emit_event("DISPLAY_PASSAGE", display_data)

        return display_data
    end,
    {
        signature = Signature.builder()
            :required("passage", "string", "Passage to display")
            :build(),
        description = "Display passage content",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        async = true,
        examples = {
            "(display: 'Chapter 1')",
            "<<display 'introduction'>>",
        },
    }
)

-- ============================================================================
-- Text Effect Macros
-- ============================================================================

--- type macro - Typewriter text effect
-- SugarCube: <<type>>, creates typing animation
Widget.type_macro = Macros.define(
    function(ctx, args)
        local content = args[1]
        local options = args[2] or {}

        local type_data = {
            _type = "type_effect",
            content = content,
            speed = options.speed or 40,
            start_delay = options.start or 0,
            cursor = options.cursor ~= false,
            skip_key = options.skipKey or "Escape",
            _is_changer = true,
        }

        ctx:_emit_event("TYPE_EFFECT", type_data)

        return type_data
    end,
    {
        signature = Signature.builder()
            :optional("content", "any", nil, "Content to type")
            :optional("options", "table", {}, "Typing options")
            :build(),
        description = "Create typewriter text effect",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<type 40ms>>Hello, world!</<type>>",
        },
    }
)

--- print macro - Print text or expression result
-- SugarCube: <<print>>, Harlowe: (print:)
Widget.print_macro = Macros.define(
    function(ctx, args)
        local value = args[1]

        local print_data = {
            _type = "print",
            value = value,
            rendered = tostring(value or ""),
        }

        ctx:_emit_event("PRINT", print_data)

        return print_data
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to print")
            :build(),
        description = "Print text or expression result",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "<<print $playerName>>",
            "(print: $score)",
        },
    }
)

--- verbatim macro - Output text without processing
-- Harlowe: (verbatim:), SugarCube: <<=>>=
Widget.verbatim_macro = Macros.define(
    function(ctx, args)
        local content = args[1]

        local verbatim_data = {
            _type = "verbatim",
            content = content,
            _is_changer = true,
            _raw_output = true,
        }

        return verbatim_data
    end,
    {
        signature = Signature.builder()
            :required("content", "string", "Content to output verbatim")
            :build(),
        description = "Output text without processing",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(verbatim:)[<<this is not a macro>>]",
        },
    }
)

-- ============================================================================
-- Cycling/Sequence Macros
-- ============================================================================

--- cycling macro - Create cycling link
-- SugarCube: <<cycle>>, clicking cycles through options
Widget.cycling_macro = Macros.define(
    function(ctx, args)
        local var_name = args[1]
        local options = {}
        for i = 2, #args do
            table.insert(options, args[i])
        end

        if not var_name then
            return nil, "Variable name is required"
        end

        if #options == 0 then
            return nil, "At least one option is required"
        end

        -- Get current index or start at 1
        local current_idx = ctx:get(var_name .. "_idx") or 1
        if current_idx > #options then
            current_idx = 1
        end

        local cycling_data = {
            _type = "cycling",
            variable = var_name,
            options = options,
            current_index = current_idx,
            current_value = options[current_idx],
        }

        -- Set initial value
        ctx:set(var_name, options[current_idx])

        ctx:_emit_event("CYCLING_CREATE", cycling_data)

        return cycling_data
    end,
    {
        signature = Signature.builder()
            :required("variable", "string", "Variable to store selection")
            :rest("options", "any", "Options to cycle through")
            :build(),
        description = "Create cycling link",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<cycle '$weapon' 'sword' 'axe' 'bow'>>",
        },
    }
)

--- sequence macro - Step through sequence on each visit
-- Harlowe: (sequence:), advances each passage visit
Widget.sequence_macro = Macros.define(
    function(ctx, args)
        local seq_id = args[1]
        local steps = {}
        for i = 2, #args do
            table.insert(steps, args[i])
        end

        if not seq_id then
            return nil, "Sequence ID is required"
        end

        if #steps == 0 then
            return nil, "At least one step is required"
        end

        -- Get current step
        local seq_key = "_sequence_" .. seq_id
        local current_step = ctx:get(seq_key) or 1

        -- Get value for current step (stay at last if exceeded)
        local step_idx = math.min(current_step, #steps)
        local current_value = steps[step_idx]

        local sequence_data = {
            _type = "sequence",
            id = seq_id,
            steps = steps,
            current_step = current_step,
            current_value = current_value,
            completed = current_step > #steps,
        }

        -- Advance for next visit
        ctx:set(seq_key, current_step + 1)

        ctx:_emit_event("SEQUENCE_STEP", sequence_data)

        return sequence_data
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Sequence identifier")
            :rest("steps", "any", "Sequence steps")
            :build(),
        description = "Step through sequence on each visit",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(sequence: 'greet', 'Hello!', 'Hi again.', 'Welcome back.')",
        },
    }
)

--- stop macro - Stop sequence at final value
-- Harlowe: (stop:), stays at last value
Widget.stop_macro = Macros.define(
    function(ctx, args)
        local values = args

        if #values == 0 then
            return nil, "At least one value is required"
        end

        -- Get current position based on visits
        local stop_key = "_stop_" .. table.concat(values, "_"):sub(1, 32)
        local current_pos = ctx:get(stop_key) or 1

        -- Stay at last value if exceeded
        local pos_idx = math.min(current_pos, #values)
        local current_value = values[pos_idx]

        local stop_data = {
            _type = "stop",
            values = values,
            current_position = current_pos,
            current_value = current_value,
            stopped = current_pos >= #values,
        }

        -- Advance for next time
        ctx:set(stop_key, current_pos + 1)

        return stop_data
    end,
    {
        signature = Signature.builder()
            :rest("values", "any", "Values to step through")
            :build(),
        description = "Step through values, stopping at last",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(stop: 'First visit', 'Second visit', 'You keep coming back')",
        },
    }
)

--- shuffle macro - Random selection without repeat until exhausted
-- Harlowe: (shuffled:), randomized cycling
Widget.shuffle_macro = Macros.define(
    function(ctx, args)
        local shuffle_id = args[1]
        local items = {}
        for i = 2, #args do
            table.insert(items, args[i])
        end

        if not shuffle_id then
            return nil, "Shuffle ID is required"
        end

        if #items == 0 then
            return nil, "At least one item is required"
        end

        -- Get or create remaining items
        local remaining_key = "_shuffle_remaining_" .. shuffle_id
        local remaining = ctx:get(remaining_key)

        if not remaining or #remaining == 0 then
            -- Reshuffle: copy all items
            remaining = {}
            for i, item in ipairs(items) do
                remaining[i] = item
            end
        end

        -- Pick random item from remaining
        local idx = math.random(1, #remaining)
        local selected = remaining[idx]

        -- Remove selected from remaining
        table.remove(remaining, idx)
        ctx:set(remaining_key, remaining)

        local shuffle_data = {
            _type = "shuffle",
            id = shuffle_id,
            items = items,
            selected = selected,
            remaining_count = #remaining,
        }

        ctx:_emit_event("SHUFFLE_PICK", shuffle_data)

        return shuffle_data
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Shuffle identifier")
            :rest("items", "any", "Items to shuffle through")
            :build(),
        description = "Random selection without immediate repeat",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(shuffled: 'greet', 'Hello!', 'Hi!', 'Greetings!')",
        },
    }
)

-- ============================================================================
-- Script Macros
-- ============================================================================

--- script macro - Execute JavaScript code
-- SugarCube: <<script>>
Widget.script_macro = Macros.define(
    function(ctx, args)
        local code = args[1]
        local options = args[2] or {}

        local script_data = {
            _type = "script",
            code = code,
            language = options.language or "javascript",
            defer = options.defer or false,
        }

        ctx:_emit_event("SCRIPT_EXECUTE", script_data)

        return script_data
    end,
    {
        signature = Signature.builder()
            :required("code", "string", "Script code to execute")
            :optional("options", "table", {}, "Script options")
            :build(),
        description = "Execute script code",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<script>>console.log('Hello');<</script>>",
        },
    }
)

--- run macro - Run code and return result
-- Harlowe: (macro:) body
Widget.run_macro = Macros.define(
    function(ctx, args)
        local code = args[1]

        local run_data = {
            _type = "run",
            code = code,
            result = nil, -- Would be populated by executor
        }

        ctx:_emit_event("RUN_CODE", run_data)

        return run_data
    end,
    {
        signature = Signature.builder()
            :required("code", "any", "Code to run")
            :build(),
        description = "Run code and return result",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "(run: some_function())",
        },
    }
)

-- ============================================================================
-- Parameter Macros
-- ============================================================================

--- params macro - Access widget parameters
-- SugarCube: _args, Harlowe: $params
Widget.params_macro = Macros.define(
    function(ctx, args)
        local index = args[1]

        local widget_args = ctx:get("_widget_args") or {}

        if index then
            return widget_args[index]
        else
            return {
                _type = "params",
                values = widget_args,
                count = #widget_args,
            }
        end
    end,
    {
        signature = Signature.builder()
            :optional("index", "number", nil, "Parameter index (1-based)")
            :build(),
        description = "Access widget parameters",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "<<print _args[0]>>",
            "(params:)",
        },
    }
)

--- contents macro - Access widget slot content
-- SugarCube: _contents
Widget.contents_macro = Macros.define(
    function(ctx, args)
        local slot_name = args[1] or "default"

        local slots = ctx:get("_widget_slots") or {}
        local content = slots[slot_name]

        local contents_data = {
            _type = "contents",
            slot = slot_name,
            content = content,
            has_content = content ~= nil,
        }

        return contents_data
    end,
    {
        signature = Signature.builder()
            :optional("slot", "string", "default", "Slot name")
            :build(),
        description = "Access widget slot content",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "<<print _contents>>",
        },
    }
)

-- ============================================================================
-- Custom Macro Definition
-- ============================================================================

--- macro macro - Define custom macro programmatically
-- Harlowe: (macro:)
Widget.macro_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local params = args[2] or {}
        local body = args[3]

        if not name then
            return nil, "Macro name is required"
        end

        local macro_def = {
            _type = "macro_definition",
            name = name,
            params = params,
            body = body,
            created_at = os.time(),
        }

        -- Register in context
        local custom_macros = ctx:get("_custom_macros") or {}
        custom_macros[name] = macro_def
        ctx:set("_custom_macros", custom_macros)

        ctx:_emit_event("MACRO_DEFINE", macro_def)

        return macro_def
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Macro name")
            :optional("params", "table", {}, "Parameter definitions")
            :optional("body", "any", nil, "Macro body")
            :build(),
        description = "Define a custom macro",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "(macro: 'greet', [(name)], 'Hello, ' + name)",
        },
    }
)

--- output macro - Define macro output type
-- Harlowe: (output:)
Widget.output_macro = Macros.define(
    function(ctx, args)
        local value = args[1]

        local output_data = {
            _type = "output",
            value = value,
            _is_macro_output = true,
        }

        return output_data
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to output")
            :build(),
        description = "Define macro output value",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.CUSTOM,
        pure = true,
        examples = {
            "(output: 'result')",
        },
    }
)

-- ============================================================================
-- Template Macros
-- ============================================================================

--- template macro - Define reusable template
-- Custom: template with named slots
Widget.template_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local body = args[2]
        local slots = args[3] or {}

        if not name then
            return nil, "Template name is required"
        end

        local template_data = {
            _type = "template",
            name = name,
            body = body,
            slots = slots,
        }

        -- Register template
        local templates = ctx:get("_templates") or {}
        templates[name] = template_data
        ctx:set("_templates", templates)

        ctx:_emit_event("TEMPLATE_DEFINE", template_data)

        return template_data
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Template name")
            :optional("body", "any", nil, "Template body")
            :optional("slots", "table", {}, "Template slots")
            :build(),
        description = "Define a reusable template",
        format = Macros.FORMAT.CUSTOM,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<template 'card'>><<slot 'title'>><</template>>",
        },
    }
)

--- render macro - Render a template
-- Custom: render template with slot content
Widget.render_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local slot_content = args[2] or {}

        if not name then
            return nil, "Template name is required"
        end

        local templates = ctx:get("_templates") or {}
        local template = templates[name]

        local render_data = {
            _type = "render",
            template = name,
            slots = slot_content,
            exists = template ~= nil,
            definition = template,
        }

        ctx:_emit_event("TEMPLATE_RENDER", render_data)

        return render_data
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Template name to render")
            :optional("slots", "table", {}, "Slot content")
            :build(),
        description = "Render a template",
        format = Macros.FORMAT.CUSTOM,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<render 'card' title='My Card'>>",
        },
    }
)

--- slot macro - Define template slot
-- Custom: named slot placeholder
Widget.slot_macro = Macros.define(
    function(ctx, args)
        local name = args[1] or "default"
        local default_content = args[2]

        -- Check if slot content was provided
        local slots = ctx:get("_current_slots") or {}
        local content = slots[name] or default_content

        local slot_data = {
            _type = "slot",
            name = name,
            content = content,
            has_content = slots[name] ~= nil,
            default = default_content,
        }

        return slot_data
    end,
    {
        signature = Signature.builder()
            :optional("name", "string", "default", "Slot name")
            :optional("default", "any", nil, "Default content")
            :build(),
        description = "Define template slot",
        format = Macros.FORMAT.CUSTOM,
        category = Macros.CATEGORY.CUSTOM,
        examples = {
            "<<slot 'header'>>Default Header<</slot>>",
        },
    }
)

-- ============================================================================
-- Registration
-- ============================================================================

--- Register all widget macros with a registry
-- @param registry MacroRegistry instance
-- @return number of macros registered
function Widget.register_all(registry)
    local count = 0

    -- Widget definition
    registry:register("widget", Widget.widget_macro)
    registry:register("done", Widget.done_macro)
    registry:register("call", Widget.call_macro)
    count = count + 3

    -- Output control
    registry:register("capture", Widget.capture_macro)
    registry:register("silently", Widget.silently_macro)
    registry:register("nobr", Widget.nobr_macro)
    count = count + 3

    -- Content embedding
    registry:register("include", Widget.include_macro)
    registry:register("embed", Widget.embed_macro)
    registry:register("display", Widget.display_macro)
    count = count + 3

    -- Text effects
    registry:register("type", Widget.type_macro)
    registry:register("print", Widget.print_macro)
    registry:register("verbatim", Widget.verbatim_macro)
    count = count + 3

    -- Cycling/sequence
    registry:register("cycling", Widget.cycling_macro)
    registry:register("sequence", Widget.sequence_macro)
    registry:register("stop", Widget.stop_macro)
    registry:register("shuffle", Widget.shuffle_macro)
    count = count + 4

    -- Script
    registry:register("script", Widget.script_macro)
    registry:register("run", Widget.run_macro)
    count = count + 2

    -- Parameters
    registry:register("params", Widget.params_macro)
    registry:register("contents", Widget.contents_macro)
    count = count + 2

    -- Custom macro
    registry:register("macro", Widget.macro_macro)
    registry:register("output", Widget.output_macro)
    count = count + 2

    -- Template
    registry:register("template", Widget.template_macro)
    registry:register("render", Widget.render_macro)
    registry:register("slot", Widget.slot_macro)
    count = count + 3

    return count
end

return Widget
