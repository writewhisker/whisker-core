-- Whisker DOM & Display Macros
-- Implements DOM manipulation and display control macros
-- Compatible with Twine hook and element manipulation patterns
--
-- lib/whisker/script/macros/display/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Display = {}

--- Module version
Display.VERSION = "1.0.0"

-- ============================================================================
-- Hook Manipulation Macros
-- ============================================================================

--- append macro - Append content to a hook or element
-- Harlowe: (append:), SugarCube: <<append>>
Display.append_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local content = args[2]

        local append_data = {
            _type = "append",
            target = target,
            content = content,
        }

        -- If target is a hook name, also update context hook
        if type(target) == "string" and target:match("^%?") then
            local hook_name = target:sub(2)
            ctx:append_hook(hook_name, content)
        end

        ctx:_emit_event("DOM_APPEND", append_data)

        return append_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target hook or selector")
            :optional("content", "any", nil, "Content to append")
            :build(),
        description = "Append content to a hook or element",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(append: ?sidebar)[New item]",
            "<<append '#log'>>New line<</append>>",
        },
    }
)

--- prepend macro - Prepend content to a hook or element
-- Harlowe: (prepend:), SugarCube: <<prepend>>
Display.prepend_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local content = args[2]

        local prepend_data = {
            _type = "prepend",
            target = target,
            content = content,
        }

        ctx:_emit_event("DOM_PREPEND", prepend_data)

        return prepend_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target hook or selector")
            :optional("content", "any", nil, "Content to prepend")
            :build(),
        description = "Prepend content to a hook or element",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(prepend: ?header)[Notice: ]",
            "<<prepend '#messages'>>Latest: <</prepend>>",
        },
    }
)

--- replace macro - Replace content of a hook or element
-- Harlowe: (replace:), SugarCube: <<replace>>
Display.replace_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local content = args[2]

        local replace_data = {
            _type = "replace",
            target = target,
            content = content,
        }

        -- If target is a hook name, update context hook
        if type(target) == "string" and target:match("^%?") then
            local hook_name = target:sub(2)
            ctx:replace_hook(hook_name, content)
        end

        ctx:_emit_event("DOM_REPLACE", replace_data)

        return replace_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target hook or selector")
            :optional("content", "any", nil, "Replacement content")
            :build(),
        description = "Replace content of a hook or element",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(replace: ?status)[Updated status]",
            "<<replace '#target'>>New content<</replace>>",
        },
    }
)

--- remove macro - Remove a hook or element
-- Harlowe: (remove:), SugarCube: <<remove>>
Display.remove_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local remove_data = {
            _type = "remove",
            target = target,
        }

        -- If target is a hook name, clear it
        if type(target) == "string" and target:match("^%?") then
            local hook_name = target:sub(2)
            ctx:clear_hook(hook_name)
        end

        ctx:_emit_event("DOM_REMOVE", remove_data)

        return remove_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target hook or selector to remove")
            :build(),
        description = "Remove a hook or element",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(remove: ?hint)",
            "<<remove '#temporary'>>",
        },
    }
)

-- ============================================================================
-- Visibility Macros
-- ============================================================================

--- show macro - Show a hidden element
-- SugarCube: <<show>>
Display.show_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local show_data = {
            _type = "show",
            target = target,
        }

        ctx:_emit_event("DOM_SHOW", show_data)

        return show_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target to show")
            :build(),
        description = "Show a hidden element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<show '#secret'>>",
        },
    }
)

--- hide macro - Hide an element
-- SugarCube: <<hide>>
Display.hide_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local hide_data = {
            _type = "hide",
            target = target,
        }

        ctx:_emit_event("DOM_HIDE", hide_data)

        return hide_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target to hide")
            :build(),
        description = "Hide an element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<hide '#hint'>>",
        },
    }
)

--- toggle macro - Toggle element visibility
-- SugarCube: <<toggle>>
Display.toggle_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local toggle_data = {
            _type = "toggle",
            target = target,
        }

        ctx:_emit_event("DOM_TOGGLE", toggle_data)

        return toggle_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target to toggle")
            :build(),
        description = "Toggle element visibility",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<toggle '#panel'>>",
        },
    }
)

-- ============================================================================
-- CSS/Style Macros
-- ============================================================================

--- addclass macro - Add CSS class to element
-- SugarCube: <<addclass>>
Display.addclass_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local class_name = args[2]

        local class_data = {
            _type = "addclass",
            target = target,
            class = class_name,
        }

        ctx:_emit_event("DOM_ADDCLASS", class_data)

        return class_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("class", "string", "Class name to add")
            :build(),
        description = "Add CSS class to element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<addclass '#message' 'highlight'>>",
        },
    }
)

--- removeclass macro - Remove CSS class from element
-- SugarCube: <<removeclass>>
Display.removeclass_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local class_name = args[2]

        local class_data = {
            _type = "removeclass",
            target = target,
            class = class_name,
        }

        ctx:_emit_event("DOM_REMOVECLASS", class_data)

        return class_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("class", "string", "Class name to remove")
            :build(),
        description = "Remove CSS class from element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<removeclass '#message' 'highlight'>>",
        },
    }
)

--- toggleclass macro - Toggle CSS class on element
-- SugarCube: <<toggleclass>>
Display.toggleclass_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local class_name = args[2]

        local class_data = {
            _type = "toggleclass",
            target = target,
            class = class_name,
        }

        ctx:_emit_event("DOM_TOGGLECLASS", class_data)

        return class_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("class", "string", "Class name to toggle")
            :build(),
        description = "Toggle CSS class on element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.UI,
        examples = {
            "<<toggleclass '#panel' 'expanded'>>",
        },
    }
)

--- css macro - Apply inline CSS styles
Display.css_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local styles = args[2]

        local css_data = {
            _type = "css",
            target = target,
            styles = styles,
        }

        ctx:_emit_event("DOM_CSS", css_data)

        return css_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("styles", "any", "CSS styles (string or table)")
            :build(),
        description = "Apply inline CSS styles",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(css: '#box', 'color: red; font-size: 20px')",
            "(css: '#box', (dm: 'color', 'red', 'fontSize', '20px'))",
        },
    }
)

--- style macro - Apply text styling (changer)
-- Harlowe: (text-style:)
Display.style_macro = Macros.define(
    function(ctx, args)
        local style_name = args[1]

        local style_data = {
            _type = "style",
            style = style_name,
            _is_changer = true,
        }

        return style_data
    end,
    {
        signature = Signature.builder()
            :required("style", "string", "Style name")
            :build(),
        description = "Apply text styling",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        aliases = { "text-style" },
        pure = true,
        examples = {
            "(text-style: 'bold')[Important text]",
            "(text-style: 'italic')[Emphasized]",
        },
    }
)

-- ============================================================================
-- Color/Appearance Macros
-- ============================================================================

--- color macro - Set text color (changer)
-- Harlowe: (text-colour:), (colour:)
Display.color_macro = Macros.define(
    function(ctx, args)
        local color_value = args[1]

        local color_data = {
            _type = "color",
            color = color_value,
            _is_changer = true,
        }

        return color_data
    end,
    {
        signature = Signature.builder()
            :required("color", "string", "Color value")
            :build(),
        description = "Set text color",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        aliases = { "colour", "text-color", "text-colour" },
        pure = true,
        examples = {
            "(color: 'red')[Error message]",
            "(colour: '#FF5500')[Orange text]",
        },
    }
)

--- background macro - Set background color (changer)
-- Harlowe: (background:)
Display.background_macro = Macros.define(
    function(ctx, args)
        local color_value = args[1]

        local bg_data = {
            _type = "background",
            color = color_value,
            _is_changer = true,
        }

        return bg_data
    end,
    {
        signature = Signature.builder()
            :required("color", "string", "Background color")
            :build(),
        description = "Set background color",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        aliases = { "bg" },
        pure = true,
        examples = {
            "(background: 'yellow')[Highlighted text]",
        },
    }
)

-- ============================================================================
-- Text Alignment/Layout Macros
-- ============================================================================

--- align macro - Align text (changer)
-- Harlowe: (align:), Chapbook: [align]
Display.align_macro = Macros.define(
    function(ctx, args)
        local alignment = args[1] or "left"

        local align_data = {
            _type = "align",
            alignment = alignment,
            _is_changer = true,
        }

        return align_data
    end,
    {
        signature = Signature.builder()
            :required("alignment", "string", "Alignment: left, center, right, justify")
            :build(),
        description = "Align text",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(align: 'center')[Centered text]",
            "(align: 'right')[Right-aligned]",
        },
    }
)

--- box macro - Create a styled box/container
-- Harlowe: (box:)
Display.box_macro = Macros.define(
    function(ctx, args)
        local width = args[1] or "100%"
        local options = args[2] or {}

        local box_data = {
            _type = "box",
            width = width,
            padding = options.padding,
            border = options.border,
            margin = options.margin,
            _is_changer = true,
        }

        return box_data
    end,
    {
        signature = Signature.builder()
            :optional("width", "string", "100%", "Box width")
            :optional("options", "table", {}, "Additional options")
            :build(),
        description = "Create a styled box/container",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(box: '50%')[Half-width content]",
        },
    }
)

--- columns macro - Create column layout
Display.columns_macro = Macros.define(
    function(ctx, args)
        local count = args[1] or 2

        local columns_data = {
            _type = "columns",
            count = count,
            _is_changer = true,
        }

        return columns_data
    end,
    {
        signature = Signature.builder()
            :optional("count", "number", 2, "Number of columns")
            :build(),
        description = "Create column layout",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(columns: 3)[Three-column content]",
        },
    }
)

-- ============================================================================
-- Hook Creation Macros
-- ============================================================================

--- hook macro - Create a named hook
-- Harlowe: |hookname>[content]
Display.hook_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local content = args[2]

        -- Define the hook in context
        ctx:define_hook(name, content)

        local hook_data = {
            _type = "hook",
            name = name,
            content = content,
        }

        ctx:_emit_event("HOOK_CREATE", hook_data)

        return hook_data
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Hook name")
            :optional("content", "any", nil, "Initial content")
            :build(),
        description = "Create a named hook",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.TEXT,
        examples = {
            "(hook: 'status')[Ready]",
        },
    }
)

--- gethook macro - Get hook content
Display.gethook_macro = Macros.define(
    function(ctx, args)
        local name = args[1]

        return ctx:get_hook(name)
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Hook name")
            :build(),
        description = "Get hook content",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(print: (gethook: 'status'))",
        },
    }
)

--- hashook macro - Check if hook exists
Display.hashook_macro = Macros.define(
    function(ctx, args)
        local name = args[1]

        return ctx:has_hook(name)
    end,
    {
        signature = Signature.builder()
            :required("name", "string", "Hook name")
            :build(),
        description = "Check if hook exists",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.TEXT,
        pure = true,
        examples = {
            "(if: (hashook: 'status'))[Status: (gethook: 'status')]",
        },
    }
)

-- ============================================================================
-- Element Query Macros
-- ============================================================================

--- element macro - Get element data
Display.element_macro = Macros.define(
    function(ctx, args)
        local selector = args[1]

        local element_data = {
            _type = "element_query",
            selector = selector,
        }

        ctx:_emit_event("DOM_QUERY", element_data)

        return element_data
    end,
    {
        signature = Signature.builder()
            :required("selector", "string", "Element selector")
            :build(),
        description = "Get element data",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(element: '#main')",
        },
    }
)

--- attr macro - Set element attribute
Display.attr_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local attr_name = args[2]
        local attr_value = args[3]

        local attr_data = {
            _type = "attr",
            target = target,
            attribute = attr_name,
            value = attr_value,
        }

        ctx:_emit_event("DOM_ATTR", attr_data)

        return attr_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("attribute", "string", "Attribute name")
            :optional("value", "any", nil, "Attribute value")
            :build(),
        description = "Set element attribute",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(attr: '#input', 'disabled', true)",
        },
    }
)

--- data macro - Set element data attribute
Display.data_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local data_key = args[2]
        local data_value = args[3]

        local data_obj = {
            _type = "data_attr",
            target = target,
            key = data_key,
            value = data_value,
        }

        ctx:_emit_event("DOM_DATA", data_obj)

        return data_obj
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target element")
            :required("key", "string", "Data key")
            :optional("value", "any", nil, "Data value")
            :build(),
        description = "Set element data attribute",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(data: '#item', 'id', 123)",
        },
    }
)

-- ============================================================================
-- Focus/Scroll Macros
-- ============================================================================

--- focus macro - Focus an element
Display.focus_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local focus_data = {
            _type = "focus",
            target = target,
        }

        ctx:_emit_event("DOM_FOCUS", focus_data)

        return focus_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target to focus")
            :build(),
        description = "Focus an element",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(focus: '#input')",
        },
    }
)

--- scroll macro - Scroll to element or position
Display.scroll_macro = Macros.define(
    function(ctx, args)
        local target = args[1]
        local options = args[2] or {}

        local scroll_data = {
            _type = "scroll",
            target = target,
            behavior = options.behavior or "smooth",
            block = options.block or "start",
        }

        ctx:_emit_event("DOM_SCROLL", scroll_data)

        return scroll_data
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target to scroll to")
            :optional("options", "table", {}, "Scroll options")
            :build(),
        description = "Scroll to element or position",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(scroll: '#section-3')",
            "(scroll: 'top')",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all display macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Display.register_all(registry)
    local macros = {
        -- Hook manipulation
        ["append"] = Display.append_macro,
        ["prepend"] = Display.prepend_macro,
        ["replace"] = Display.replace_macro,
        ["remove"] = Display.remove_macro,

        -- Visibility
        ["show"] = Display.show_macro,
        ["hide"] = Display.hide_macro,
        ["toggle"] = Display.toggle_macro,

        -- CSS/Style
        ["addclass"] = Display.addclass_macro,
        ["removeclass"] = Display.removeclass_macro,
        ["toggleclass"] = Display.toggleclass_macro,
        ["css"] = Display.css_macro,
        ["style"] = Display.style_macro,

        -- Color/Appearance
        ["color"] = Display.color_macro,
        ["background"] = Display.background_macro,

        -- Alignment/Layout
        ["align"] = Display.align_macro,
        ["box"] = Display.box_macro,
        ["columns"] = Display.columns_macro,

        -- Hooks
        ["hook"] = Display.hook_macro,
        ["gethook"] = Display.gethook_macro,
        ["hashook"] = Display.hashook_macro,

        -- Element queries
        ["element"] = Display.element_macro,
        ["attr"] = Display.attr_macro,
        ["data"] = Display.data_macro,

        -- Focus/Scroll
        ["focus"] = Display.focus_macro,
        ["scroll"] = Display.scroll_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Display
