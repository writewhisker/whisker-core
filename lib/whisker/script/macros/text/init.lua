-- Whisker Text Macros
-- Implements text formatting and display macros compatible with Twine formats
-- Supports Harlowe, SugarCube, and Chapbook-style text operations
--
-- lib/whisker/script/macros/text/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Text = {}

--- Module version
Text.VERSION = "1.0.0"

-- ============================================================================
-- Text Output Macros
-- ============================================================================

--- print macro - Output text
-- Harlowe: (print: value)
-- SugarCube: <<print value>>
Text.print_macro = Macros.define_text(
    function(ctx, args)
        local value = args[1]

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        elseif type(value) == "string" and value:match("^%$[%w_]+$") then
            value = ctx:eval(value)
        end

        local output = tostring(value or "")
        ctx:write(output)
        return output
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to print")
            :build(),
        description = "Output a value as text",
        format = Macros.FORMAT.WHISKER,
        aliases = { "=" },  -- SugarCube shorthand
        examples = {
            "(print: $playerName)",
            "<<print $score>>",
            "<<= $score>>",
        },
    }
)

--- text / display macro - Display passage content
-- Harlowe: (display: 'PassageName')
-- SugarCube: <<include 'PassageName'>>
Text.display_macro = Macros.define_text(
    function(ctx, args)
        local passage_name = args[1]

        if type(passage_name) == "table" and passage_name._is_expression then
            passage_name = ctx:eval(passage_name)
        end

        if type(passage_name) ~= "string" then
            return nil, "Passage name must be a string"
        end

        -- Get the passage content from story
        local story = ctx:get_story()
        if not story then
            return nil, "No story available"
        end

        local passage = story:get_passage(passage_name)
        if not passage then
            return nil, "Passage not found: " .. passage_name
        end

        local content
        if type(passage.get_content) == "function" then
            content = passage:get_content()
        else
            content = passage.content
        end

        ctx:write(content or "")
        return content
    end,
    {
        signature = Signature.builder()
            :required("passage", "string", "Name of passage to display")
            :build(),
        description = "Include and display another passage's content",
        format = Macros.FORMAT.HARLOWE,
        aliases = { "include" },  -- SugarCube alias
        examples = {
            "(display: 'Inventory')",
            "<<include 'Header'>>",
        },
    }
)

--- nobr macro - Suppress line breaks
-- SugarCube: <<nobr>>content<</nobr>>
-- Removes line breaks from content
Text.nobr_macro = Macros.define_text(
    function(ctx, args)
        local content = args[1]

        if type(content) == "function" then
            content = content(ctx)
        end

        if type(content) == "string" then
            -- Remove line breaks and collapse whitespace
            content = content:gsub("\n", " ")
            content = content:gsub("%s+", " ")
            content = content:gsub("^%s+", "")
            content = content:gsub("%s+$", "")
        end

        if content and content ~= "" then
            ctx:write(content)
        end

        return content
    end,
    {
        signature = Signature.builder()
            :optional("content", "any", nil, "Content to process")
            :build(),
        description = "Remove line breaks from content",
        format = Macros.FORMAT.SUGARCUBE,
        examples = {
            "<<nobr>>line 1\nline 2<</nobr>>",
        },
    }
)

--- silently / capture macro - Execute without output
-- SugarCube: <<silently>>code<</silently>>
-- Harlowe: { code }
Text.silently_macro = Macros.define_text(
    function(ctx, args)
        local content = args[1]

        -- Execute content but don't output
        if type(content) == "function" then
            content(ctx)
        end

        -- Return nil to suppress output
        return nil
    end,
    {
        signature = Signature.builder()
            :optional("content", "any", nil, "Content to execute silently")
            :build(),
        description = "Execute code without producing output",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "capture", "silent" },
        examples = {
            "<<silently>><<set $x to 1>><</silently>>",
        },
    }
)

--- verbatim / v macro - Output without processing
-- Outputs text exactly as-is, without macro processing
Text.verbatim_macro = Macros.define_text(
    function(ctx, args)
        local content = args[1]

        if type(content) == "string" then
            ctx:write(content)
            return content
        end

        return nil
    end,
    {
        signature = Signature.builder()
            :required("content", "string", "Content to output verbatim")
            :build(),
        description = "Output text without processing",
        format = Macros.FORMAT.WHISKER,
        aliases = { "v", "raw" },
        pure = true,
        examples = {
            "(verbatim: '<<not a macro>>')",
        },
    }
)

-- ============================================================================
-- Text Formatting Macros
-- ============================================================================

--- uppercase macro - Convert to uppercase
Text.uppercase_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            text = tostring(text or "")
        end

        return text:upper()
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to convert")
            :build(),
        description = "Convert text to uppercase",
        format = Macros.FORMAT.WHISKER,
        aliases = { "upper", "toupper" },
        pure = true,
        examples = {
            "(uppercase: 'hello')",
        },
    }
)

--- lowercase macro - Convert to lowercase
Text.lowercase_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            text = tostring(text or "")
        end

        return text:lower()
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to convert")
            :build(),
        description = "Convert text to lowercase",
        format = Macros.FORMAT.WHISKER,
        aliases = { "lower", "tolower" },
        pure = true,
        examples = {
            "(lowercase: 'HELLO')",
        },
    }
)

--- upperfirst macro - Capitalize first character
Text.upperfirst_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            text = tostring(text or "")
        end

        if #text == 0 then
            return ""
        end

        return text:sub(1, 1):upper() .. text:sub(2)
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to capitalize")
            :build(),
        description = "Capitalize first character",
        format = Macros.FORMAT.WHISKER,
        aliases = { "capitalize", "ucfirst" },
        pure = true,
        examples = {
            "(upperfirst: 'hello')",
        },
    }
)

--- lowerfirst macro - Lowercase first character
Text.lowerfirst_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            text = tostring(text or "")
        end

        if #text == 0 then
            return ""
        end

        return text:sub(1, 1):lower() .. text:sub(2)
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to modify")
            :build(),
        description = "Lowercase first character",
        format = Macros.FORMAT.WHISKER,
        aliases = { "lcfirst" },
        pure = true,
        examples = {
            "(lowerfirst: 'Hello')",
        },
    }
)

--- trim macro - Remove leading/trailing whitespace
Text.trim_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            text = tostring(text or "")
        end

        return text:match("^%s*(.-)%s*$")
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to trim")
            :build(),
        description = "Remove leading and trailing whitespace",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(trim: '  hello  ')",
        },
    }
)

--- wordcount macro - Count words in text
Text.wordcount_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            return 0
        end

        local count = 0
        for _ in text:gmatch("%S+") do
            count = count + 1
        end

        return count
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to count words in")
            :build(),
        description = "Count words in text",
        format = Macros.FORMAT.WHISKER,
        aliases = { "wc" },
        pure = true,
        examples = {
            "(wordcount: 'hello world')",
        },
    }
)

--- substring macro - Extract part of text
Text.substring_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]
        local start_idx = args[2] or 1
        local end_idx = args[3]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            return ""
        end

        end_idx = end_idx or #text
        return text:sub(start_idx, end_idx)
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to extract from")
            :optional("start", "number", 1, "Start position")
            :optional("end_pos", "number", nil, "End position (inclusive)")
            :build(),
        description = "Extract a substring",
        format = Macros.FORMAT.WHISKER,
        aliases = { "substr", "slice" },
        pure = true,
        examples = {
            "(substring: 'hello', 2, 4)",
        },
    }
)

--- replace macro - Replace text
Text.replace_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]
        local pattern = args[2]
        local replacement = args[3] or ""

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            return tostring(text or "")
        end

        -- Use plain string replacement (escape pattern characters)
        local result = text:gsub(pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), replacement)
        return result
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to modify")
            :required("pattern", "string", "Pattern to find")
            :optional("replacement", "string", "", "Replacement text")
            :build(),
        description = "Replace occurrences in text",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(replace: 'hello world', 'world', 'there')",
        },
    }
)

--- split macro - Split text into array
Text.split_macro = Macros.define_text(
    function(ctx, args)
        local text = args[1]
        local delimiter = args[2] or " "

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        if type(text) ~= "string" then
            return {}
        end

        local result = {}
        local escaped_delim = delimiter:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

        for part in (text .. delimiter):gmatch("(.-)" .. escaped_delim) do
            table.insert(result, part)
        end

        return result
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Text to split")
            :optional("delimiter", "string", " ", "Delimiter")
            :build(),
        description = "Split text into array by delimiter",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(split: 'a,b,c', ',')",
        },
    }
)

--- join macro - Join array into text
Text.join_macro = Macros.define_text(
    function(ctx, args)
        local arr = args[1]
        local delimiter = args[2] or ""

        if type(arr) == "string" then
            arr = ctx:get(arr:gsub("^%$", ""))
        end

        if type(arr) ~= "table" then
            return tostring(arr or "")
        end

        local result = {}
        for _, v in ipairs(arr) do
            table.insert(result, tostring(v))
        end

        return table.concat(result, delimiter)
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array to join")
            :optional("delimiter", "string", "", "Delimiter")
            :build(),
        description = "Join array elements into text",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(join: (a: 'a', 'b', 'c'), ', ')",
        },
    }
)

--- pluralize macro - Simple pluralization
Text.pluralize_macro = Macros.define_text(
    function(ctx, args)
        local count = args[1]
        local singular = args[2]
        local plural = args[3]

        if type(count) == "table" and count._is_expression then
            count = ctx:eval(count)
        end

        count = tonumber(count) or 0

        -- If no plural provided, add 's' to singular
        plural = plural or (singular .. "s")

        if count == 1 then
            return singular
        else
            return plural
        end
    end,
    {
        signature = Signature.builder()
            :required("count", "any", "Count to check")
            :required("singular", "string", "Singular form")
            :optional("plural", "string", nil, "Plural form (defaults to singular + 's')")
            :build(),
        description = "Choose singular or plural form based on count",
        format = Macros.FORMAT.WHISKER,
        aliases = { "plural" },
        pure = true,
        examples = {
            "(pluralize: 1, 'apple', 'apples')",
            "(pluralize: $count, 'item')",
        },
    }
)

-- ============================================================================
-- Link Macros
-- ============================================================================

--- link macro - Create a passage link
-- Harlowe: (link: 'text')[action]
-- SugarCube: <<link 'text' 'passage'>>
Text.link_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local target = args[2]
        local action = args[3]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        -- Build link data
        local link_data = {
            _type = "link",
            text = tostring(text or ""),
            target = target,
            action = action,
        }

        -- Emit link event
        ctx:_emit_event("LINK_CREATED", link_data)

        -- Return the link data (client will render appropriately)
        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Link text")
            :optional("target", "string", nil, "Target passage")
            :optional("action", "function", nil, "Action to execute")
            :build(),
        description = "Create a clickable link",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(link: 'Go north')[(goto: 'North')]",
            "<<link 'Open door' 'DoorOpened'>>",
        },
    }
)

--- link_goto macro - Link that navigates to passage
-- SugarCube: <<link-goto 'text' 'passage'>>
Text.link_goto_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local target = args[2]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        local link_data = {
            _type = "link_goto",
            text = tostring(text or ""),
            target = target or text,  -- Default target to text
        }

        ctx:_emit_event("LINK_CREATED", link_data)
        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Link text")
            :optional("target", "string", nil, "Target passage (defaults to text)")
            :build(),
        description = "Create a link that goes to a passage",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-goto" },
        examples = {
            "<<link-goto 'North' 'NorthRoom'>>",
        },
    }
)

--- link_reveal macro - Link that reveals content
-- SugarCube: <<link-reveal 'text'>>content<</link-reveal>>
Text.link_reveal_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local content = args[2]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        local link_data = {
            _type = "link_reveal",
            text = tostring(text or ""),
            content = content,
            revealed = false,
        }

        ctx:_emit_event("LINK_CREATED", link_data)
        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Link text")
            :optional("content", "any", nil, "Content to reveal")
            :build(),
        description = "Create a link that reveals content when clicked",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-reveal" },
        examples = {
            "<<link-reveal 'Click me'>>Hidden content<</link-reveal>>",
        },
    }
)

--- link_repeat macro - Link that can be clicked multiple times
-- SugarCube: <<link-repeat 'text'>>action<</link-repeat>>
Text.link_repeat_macro = Macros.define(
    function(ctx, args)
        local text = args[1]
        local action = args[2]

        if type(text) == "table" and text._is_expression then
            text = ctx:eval(text)
        end

        local link_data = {
            _type = "link_repeat",
            text = tostring(text or ""),
            action = action,
            click_count = 0,
        }

        ctx:_emit_event("LINK_CREATED", link_data)
        return link_data
    end,
    {
        signature = Signature.builder()
            :required("text", "any", "Link text")
            :optional("action", "function", nil, "Action to execute on each click")
            :build(),
        description = "Create a link that can be clicked multiple times",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.LINK,
        aliases = { "link-repeat" },
        examples = {
            "<<link-repeat 'Click'>><<set $count += 1>><</link-repeat>>",
        },
    }
)

--- goto macro - Navigate to passage
-- Harlowe: (goto: 'PassageName')
-- SugarCube: <<goto 'PassageName'>>
Text.goto_macro = Macros.define(
    function(ctx, args)
        local passage_name = args[1]

        if type(passage_name) == "table" and passage_name._is_expression then
            passage_name = ctx:eval(passage_name)
        end

        if type(passage_name) ~= "string" then
            return nil, "Passage name must be a string"
        end

        -- Emit navigation event
        ctx:_emit_event("NAVIGATION_REQUESTED", {
            target = passage_name,
        })

        -- Set transition flag
        ctx:set_flag("navigation_target", passage_name)

        return passage_name
    end,
    {
        signature = Signature.builder()
            :required("passage", "string", "Name of passage to go to")
            :build(),
        description = "Navigate to a passage",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.LINK,
        examples = {
            "(goto: 'NextPassage')",
            "<<goto 'GameOver'>>",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all text macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Text.register_all(registry)
    local macros = {
        -- Text output
        ["print"] = Text.print_macro,
        ["display"] = Text.display_macro,
        ["nobr"] = Text.nobr_macro,
        ["silently"] = Text.silently_macro,
        ["verbatim"] = Text.verbatim_macro,

        -- Text formatting
        ["uppercase"] = Text.uppercase_macro,
        ["lowercase"] = Text.lowercase_macro,
        ["upperfirst"] = Text.upperfirst_macro,
        ["lowerfirst"] = Text.lowerfirst_macro,
        ["trim"] = Text.trim_macro,
        ["wordcount"] = Text.wordcount_macro,
        ["substring"] = Text.substring_macro,
        ["replace"] = Text.replace_macro,
        ["split"] = Text.split_macro,
        ["join"] = Text.join_macro,
        ["pluralize"] = Text.pluralize_macro,

        -- Links
        ["link"] = Text.link_macro,
        ["link_goto"] = Text.link_goto_macro,
        ["link_reveal"] = Text.link_reveal_macro,
        ["link_repeat"] = Text.link_repeat_macro,
        ["goto"] = Text.goto_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Text
