-- Whisker Link & Navigation Macros
-- Implements link creation and navigation macros
-- Compatible with Twine link patterns (Harlowe, SugarCube)
--
-- lib/whisker/script/macros/link/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Link = {}

--- Module version
Link.VERSION = "1.0.0"

-- ============================================================================
-- Basic Link Macros
-- ============================================================================

--- link macro - Create a clickable link
-- Harlowe: (link:), SugarCube: <<link>>
Link.link_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local action = args[2]

        local link_data = {
            _type = "link",
            text = text,
            action = action,
        }

        ctx:_emit_event("LINK_CREATE", link_data)

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Link text to display")
            :optional("action", "any", nil, "Action when clicked")
            :build(),
        description = "Create a clickable link",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(link: 'Click me')[You clicked!]",
            "<<link 'Submit'>><<run $submitted = true>><</link>>",
        },
    }
)

--- linkgoto macro - Create a link that navigates to a passage
-- Harlowe: (link-goto:), SugarCube: <<link>>[[passage]]
Link.linkgoto_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local passage = args[2] or text
        local setter = args[3]

        local link_data = {
            _type = "link_goto",
            text = text,
            passage = passage,
            setter = setter,
        }

        ctx:_emit_event("LINK_CREATE", link_data)

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Link text to display")
            :optional("passage", "string", nil, "Target passage (defaults to text)")
            :optional("setter", "any", nil, "Code to run before navigation")
            :build(),
        description = "Create a link that navigates to a passage",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-goto" },
        examples = {
            "(link-goto: 'Go to Chapter 2', 'chapter2')",
            "<<link [[Next passage]]>>",
        },
    }
)

--- linkreveal macro - Create a link that reveals content once
-- Harlowe: (link-reveal:)
Link.linkreveal_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local content = args[2]

        local link_data = {
            _type = "link_reveal",
            text = text,
            content = content,
            revealed = false,
            once = true,
        }

        ctx:_emit_event("LINK_CREATE", link_data)

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Link text to display")
            :optional("content", "any", nil, "Content to reveal")
            :build(),
        description = "Create a link that reveals content once and disappears",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-reveal" },
        examples = {
            "(link-reveal: 'Show secret')[The secret is revealed!]",
        },
    }
)

--- linkrepeat macro - Create a link that can be clicked multiple times
-- Harlowe: (link-repeat:)
Link.linkrepeat_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local action = args[2]

        local link_data = {
            _type = "link_repeat",
            text = text,
            action = action,
            click_count = 0,
        }

        ctx:_emit_event("LINK_CREATE", link_data)

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Link text to display")
            :optional("action", "any", nil, "Action to execute on each click")
            :build(),
        description = "Create a link that can be clicked multiple times",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-repeat" },
        examples = {
            "(link-repeat: 'Click me')[(set: $clicks to it + 1)]",
        },
    }
)

--- linkreplace macro - Create a link that replaces itself with content
-- Harlowe: (link-replace:)
Link.linkreplace_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local content = args[2]

        local link_data = {
            _type = "link_replace",
            text = text,
            content = content,
        }

        ctx:_emit_event("LINK_CREATE", link_data)

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Link text to display")
            :optional("content", "any", nil, "Content to replace with")
            :build(),
        description = "Create a link that replaces itself when clicked",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-replace" },
        examples = {
            "(link-replace: 'Open the box')[Inside the box is a key!]",
        },
    }
)

-- ============================================================================
-- Navigation Macros
-- ============================================================================

--- goto macro - Navigate to a passage immediately
-- Harlowe: (goto:), SugarCube: <<goto>>
Link.goto_macro = Macros.define(
    function(ctx, args)
        local passage = args[1]

        if not passage then
            return nil, "Passage name required"
        end

        local goto_data = {
            _type = "goto",
            passage = passage,
        }

        ctx:_emit_event("NAVIGATE", goto_data)

        return goto_data
    end,
    {
        signature = Signature.builder()
            :required("passage", "string", "Target passage name")
            :build(),
        description = "Navigate to a passage immediately",
        format = Macros.FORMAT.HARLOWE,
        category = Macros.CATEGORY.LINK,
        async = true,
        examples = {
            "(goto: 'ending')",
            "<<goto 'next-chapter'>>",
        },
    }
)

--- back macro - Go back to previous passage
-- SugarCube: <<back>>, <<return>>
Link.back_macro = Macros.define(
    function(ctx, args)
        local steps = args[1] or 1

        local history = ctx:get("_passage_history") or {}
        local target_index = #history - steps

        local back_data = {
            _type = "back",
            steps = steps,
            target = target_index > 0 and history[target_index] or nil,
        }

        if back_data.target then
            ctx:_emit_event("NAVIGATE", {
                _type = "goto",
                passage = back_data.target,
                is_back = true,
            })
        end

        return back_data
    end,
    {
        signature = Signature.builder()
            :optional("steps", "number", 1, "Number of steps to go back")
            :build(),
        description = "Go back to a previous passage",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        async = true,
        examples = {
            "(back:)",
            "<<back 2>>",
        },
    }
)

--- return macro - Return to a specific passage in history
-- SugarCube: <<return>>
Link.return_macro = Macros.define(
    function(ctx, args)
        local passage = args[1]

        local return_data = {
            _type = "return",
            passage = passage,
        }

        if passage then
            ctx:_emit_event("NAVIGATE", {
                _type = "goto",
                passage = passage,
                is_return = true,
            })
        else
            -- Return to previous
            local history = ctx:get("_passage_history") or {}
            if #history >= 2 then
                return_data.passage = history[#history - 1]
                ctx:_emit_event("NAVIGATE", {
                    _type = "goto",
                    passage = return_data.passage,
                    is_return = true,
                })
            end
        end

        return return_data
    end,
    {
        signature = Signature.builder()
            :optional("passage", "string", nil, "Passage to return to")
            :build(),
        description = "Return to a specific passage or previous",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        async = true,
        examples = {
            "(return:)",
            "<<return 'hub'>>",
        },
    }
)

-- ============================================================================
-- Click Macros (SugarCube-style)
-- ============================================================================

--- click macro - Register click handler on element
-- SugarCube: <<click>>
Link.click_macro = Macros.define(
    function(ctx, args)
        local selector = args[1]
        local action = args[2]

        local click_data = {
            _type = "click_handler",
            selector = selector,
            action = action,
        }

        ctx:_emit_event("REGISTER_CLICK", click_data)

        return click_data
    end,
    {
        signature = Signature.builder()
            :required("selector", "string", "Element selector or hook name")
            :optional("action", "any", nil, "Action to execute on click")
            :build(),
        description = "Register a click handler on an element",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<click '#button'>><<run $clicked = true>><</click>>",
        },
    }
)

--- clickreplace macro - Replace element content on click
-- SugarCube: <<clickreplace>>
Link.clickreplace_macro = Macros.define(
    function(ctx, args)
        local selector = args[1]
        local content = args[2]

        local click_data = {
            _type = "click_replace",
            selector = selector,
            content = content,
        }

        ctx:_emit_event("REGISTER_CLICK", click_data)

        return click_data
    end,
    {
        signature = Signature.builder()
            :required("selector", "string", "Element selector")
            :optional("content", "any", nil, "Replacement content")
            :build(),
        description = "Replace element content when clicked",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<clickreplace '#target'>>New content<</clickreplace>>",
        },
    }
)

--- clickappend macro - Append content on click
-- SugarCube: <<clickappend>>
Link.clickappend_macro = Macros.define(
    function(ctx, args)
        local selector = args[1]
        local content = args[2]

        local click_data = {
            _type = "click_append",
            selector = selector,
            content = content,
        }

        ctx:_emit_event("REGISTER_CLICK", click_data)

        return click_data
    end,
    {
        signature = Signature.builder()
            :required("selector", "string", "Element selector")
            :optional("content", "any", nil, "Content to append")
            :build(),
        description = "Append content to element when clicked",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<clickappend '#log'>>A new line<</clickappend>>",
        },
    }
)

--- clickprepend macro - Prepend content on click
-- SugarCube: <<clickprepend>>
Link.clickprepend_macro = Macros.define(
    function(ctx, args)
        local selector = args[1]
        local content = args[2]

        local click_data = {
            _type = "click_prepend",
            selector = selector,
            content = content,
        }

        ctx:_emit_event("REGISTER_CLICK", click_data)

        return click_data
    end,
    {
        signature = Signature.builder()
            :required("selector", "string", "Element selector")
            :optional("content", "any", nil, "Content to prepend")
            :build(),
        description = "Prepend content to element when clicked",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<clickprepend '#messages'>>New message!<</clickprepend>>",
        },
    }
)

-- ============================================================================
-- Choice/Action Macros
-- ============================================================================

--- choice macro - Create a choice/option for player
-- Chapbook-style choice
Link.choice_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local target = args[2]
        local condition = args[3]

        local choice_data = {
            _type = "choice",
            text = text,
            target = target,
            condition = condition,
            enabled = true,
        }

        -- Evaluate condition if present
        if condition ~= nil then
            if type(condition) == "function" then
                choice_data.enabled = condition(ctx)
            elseif type(condition) == "boolean" then
                choice_data.enabled = condition
            end
        end

        ctx:_emit_event("CHOICE_CREATE", choice_data)

        return choice_data
    end,
    {
        signature = Signature.builder()
            :required("text", "string", "Choice text")
            :optional("target", "string", nil, "Target passage")
            :optional("condition", "any", nil, "Condition to show choice")
            :build(),
        description = "Create a choice option for the player",
        format = Macros.FORMAT.CHAPBOOK,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(choice: 'Fight the dragon', 'dragon-battle')",
            "(choice: 'Use potion', 'use-potion', $hasPotion)",
        },
    }
)

--- actions macro - Create a group of action choices
-- SugarCube: <<actions>>
Link.actions_macro = Macros.define(
    function(ctx, args)
        local choices = {}

        for i, arg in ipairs(args) do
            if type(arg) == "string" then
                table.insert(choices, {
                    text = arg,
                    target = arg,
                })
            elseif type(arg) == "table" then
                table.insert(choices, arg)
            end
        end

        local actions_data = {
            _type = "actions",
            choices = choices,
        }

        ctx:_emit_event("ACTIONS_CREATE", actions_data)

        return actions_data
    end,
    {
        signature = Signature.builder()
            :rest("choices", "any", "Choice options")
            :build(),
        description = "Create a group of action choices",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        examples = {
            "<<actions 'Go north' 'Go south' 'Go east'>>",
        },
    }
)

-- ============================================================================
-- URL/External Link Macros
-- ============================================================================

--- url macro - Create an external URL link
Link.url_macro = Macros.define(
    function(ctx, args)
        local url = args[1]
        local text = args[2] or url
        local options = args[3] or {}

        local url_data = {
            _type = "url",
            url = url,
            text = text,
            target = options.target or "_blank",
            rel = options.rel or "noopener noreferrer",
        }

        ctx:_emit_event("URL_CREATE", url_data)

        return url_data
    end,
    {
        signature = Signature.builder()
            :required("url", "string", "URL to link to")
            :optional("text", "string", nil, "Link text (defaults to URL)")
            :optional("options", "table", {}, "Link options")
            :build(),
        description = "Create an external URL link",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        aliases = { "extlink", "externallink" },
        examples = {
            "(url: 'https://example.com', 'Example Site')",
        },
    }
)

--- open macro - Open URL in new window/tab
Link.open_macro = Macros.define(
    function(ctx, args)
        local url = args[1]
        local options = args[2] or {}

        local open_data = {
            _type = "open",
            url = url,
            target = options.target or "_blank",
            features = options.features,
        }

        ctx:_emit_event("OPEN_URL", open_data)

        return open_data
    end,
    {
        signature = Signature.builder()
            :required("url", "string", "URL to open")
            :optional("options", "table", {}, "Window options")
            :build(),
        description = "Open URL in new window/tab",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(open: 'https://example.com')",
        },
    }
)

-- ============================================================================
-- Link State Macros
-- ============================================================================

--- linkshow macro - Create link that shows when condition is true
Link.linkshow_macro = Macros.define(
    function(ctx, args)
        local condition = args[1]
        local text = args[2]
        local action = args[3]

        local visible = false
        if type(condition) == "function" then
            visible = condition(ctx)
        elseif type(condition) == "boolean" then
            visible = condition
        else
            visible = condition ~= nil and condition ~= false
        end

        local link_data = {
            _type = "link_conditional",
            visible = visible,
            text = text,
            action = action,
        }

        if visible then
            ctx:_emit_event("LINK_CREATE", link_data)
        end

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("condition", "any", "Condition to show link")
            :required("text", "string", "Link text")
            :optional("action", "any", nil, "Action when clicked")
            :build(),
        description = "Create link that shows when condition is true",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(linkshow: $hasKey, 'Unlock door', (goto: 'unlocked'))",
        },
    }
)

--- linkonce macro - Create a link that can only be clicked once per game
Link.linkonce_macro = Macros.define(
    function(ctx, args)
        local id = args[1]
        local text = args[2]
        local action = args[3]

        local clicked_links = ctx:get("_clicked_links") or {}
        local already_clicked = clicked_links[id] == true

        local link_data = {
            _type = "link_once",
            id = id,
            text = text,
            action = action,
            clicked = already_clicked,
            enabled = not already_clicked,
        }

        if not already_clicked then
            ctx:_emit_event("LINK_CREATE", link_data)
        end

        return link_data
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Unique link identifier")
            :required("text", "string", "Link text")
            :optional("action", "any", nil, "Action when clicked")
            :build(),
        description = "Create a link that can only be clicked once per game",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(linkonce: 'secret-door', 'Open secret door', (goto: 'secret-room'))",
        },
    }
)

--- linkvisited macro - Check if a link was visited
Link.linkvisited_macro = Macros.define(
    function(ctx, args)
        local id = args[1]

        local clicked_links = ctx:get("_clicked_links") or {}
        return clicked_links[id] == true
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Link identifier")
            :build(),
        description = "Check if a link was clicked",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        pure = true,
        examples = {
            "(if: (linkvisited: 'secret-door'))[You found the secret!]",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all link macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Link.register_all(registry)
    local macros = {
        -- Basic links
        ["link"] = Link.link_macro,
        ["linkgoto"] = Link.linkgoto_macro,
        ["linkreveal"] = Link.linkreveal_macro,
        ["linkrepeat"] = Link.linkrepeat_macro,
        ["linkreplace"] = Link.linkreplace_macro,

        -- Navigation
        ["goto"] = Link.goto_macro,
        ["back"] = Link.back_macro,
        ["return"] = Link.return_macro,

        -- Click handlers
        ["click"] = Link.click_macro,
        ["clickreplace"] = Link.clickreplace_macro,
        ["clickappend"] = Link.clickappend_macro,
        ["clickprepend"] = Link.clickprepend_macro,

        -- Choices
        ["choice"] = Link.choice_macro,
        ["actions"] = Link.actions_macro,

        -- URLs
        ["url"] = Link.url_macro,
        ["open"] = Link.open_macro,

        -- Link state
        ["linkshow"] = Link.linkshow_macro,
        ["linkonce"] = Link.linkonce_macro,
        ["linkvisited"] = Link.linkvisited_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Link
