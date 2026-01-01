-- lib/whisker/core/control_flow.lua
-- WLS 1.0 Control Flow Processing
-- Handles block conditionals, inline conditionals, and text alternatives

local ControlFlow = {}
ControlFlow.__index = ControlFlow
ControlFlow._dependencies = {}

--- Create a new ControlFlow processor
---@param interpreter table The Lua interpreter for expression evaluation
---@param game_state table The game state for variable access
---@param context table Optional context with story/engine references
---@return ControlFlow
function ControlFlow.new(interpreter, game_state, context)
    local self = setmetatable({}, ControlFlow)
    self.interpreter = interpreter
    self.game_state = game_state
    self.context = context or {}
    return self
end

--- Process all WLS 1.0 control flow in content
---@param content string The content to process
---@return string Processed content
function ControlFlow:process(content)
    -- 1. Process block conditionals { condition }...{elif}...{else}...{/}
    content = self:process_block_conditionals(content)

    -- 2. Process inline conditionals {condition: trueText | falseText}
    content = self:process_inline_conditionals(content)

    -- 3. Process text alternatives {| a | b | c } and variants
    content = self:process_alternatives(content)

    return content
end

--- Process block conditionals: { condition }...{else}...{elif}...{/}
---@param content string
---@return string
function ControlFlow:process_block_conditionals(content)
    local max_iterations = 100
    local iteration = 0

    -- Process from innermost to outermost
    while iteration < max_iterations do
        iteration = iteration + 1
        local processed = false

        -- Find blocks that don't contain nested blocks (innermost first)
        -- Pattern: { condition } ... {/} where ... contains no { ... }
        local block_start, block_end, condition, block_content = self:find_innermost_block(content)

        if block_start then
            local replacement = self:evaluate_block(condition, block_content)
            content = content:sub(1, block_start - 1) .. replacement .. content:sub(block_end + 1)
            processed = true
        end

        if not processed then
            break
        end
    end

    return content
end

--- Find the innermost conditional block
---@param content string
---@return number|nil start position
---@return number|nil end position
---@return string|nil condition
---@return string|nil block content
function ControlFlow:find_innermost_block(content)
    -- Find all opening braces that look like conditionals { condition }
    -- But NOT: ${, {|, {&|, {~|, {!|, {else}, {elif, {/}
    local search_pos = 1
    local best_match = nil

    while search_pos <= #content do
        -- Find next potential opening brace
        local open_start = content:find("{", search_pos, true)
        if not open_start then
            break
        end

        -- Check if this is a conditional block opener
        local before_brace = open_start > 1 and content:sub(open_start - 1, open_start - 1) or ""
        local after_brace = content:sub(open_start + 1, open_start + 10)

        -- Skip special constructs (note: { $var } is valid, but ${expr} is not a block)
        if before_brace == "$" or               -- ${expr} - expression interpolation
           after_brace:match("^|") or           -- {| alternatives
           after_brace:match("^&|") or          -- {&| cycle
           after_brace:match("^~|") or          -- {~| shuffle
           after_brace:match("^!|") or          -- {!| once
           after_brace:match("^else") or        -- {else}
           after_brace:match("^elif") or        -- {elif condition}
           after_brace:match("^/") then         -- {/}
            search_pos = open_start + 1
        else
            -- This looks like a conditional opener { condition }
            -- Find the closing } of the condition
            local cond_end = content:find("}", open_start + 1, true)
            if cond_end then
                local condition = content:sub(open_start + 1, cond_end - 1)
                condition = condition:match("^%s*(.-)%s*$")  -- trim

                -- Skip if condition is empty or just whitespace
                if condition ~= "" then
                    -- Now find the matching {/}
                    local close_start, close_end = self:find_matching_close(content, cond_end + 1)

                    if close_start then
                        local block_content = content:sub(cond_end + 1, close_start - 1)

                        -- Check if this block contains no nested blocks
                        -- (i.e., no other { condition } patterns)
                        if not self:contains_nested_block(block_content) then
                            -- This is an innermost block
                            if not best_match or open_start < best_match.start then
                                best_match = {
                                    start = open_start,
                                    close_end = close_end,
                                    condition = condition,
                                    content = block_content
                                }
                            end
                        end
                    end
                end
            end
            search_pos = open_start + 1
        end
    end

    if best_match then
        return best_match.start, best_match.close_end, best_match.condition, best_match.content
    end

    return nil
end

--- Find the matching {/} for a block
---@param content string
---@param start_pos number Position after the opening condition
---@return number|nil start of {/}
---@return number|nil end of {/}
function ControlFlow:find_matching_close(content, start_pos)
    local pos = start_pos
    local depth = 1

    while pos <= #content do
        -- Find next brace
        local next_brace = content:find("{", pos, true)
        if not next_brace then
            break
        end

        local after_brace = content:sub(next_brace + 1, next_brace + 10)

        -- Check what type of brace this is
        if after_brace:match("^/}") then
            -- Closing {/}
            depth = depth - 1
            if depth == 0 then
                return next_brace, next_brace + 2
            end
            pos = next_brace + 3
        elseif after_brace:match("^%$") or
               after_brace:match("^|") or
               after_brace:match("^&|") or
               after_brace:match("^~|") or
               after_brace:match("^!|") or
               after_brace:match("^else") or
               after_brace:match("^elif") then
            -- Skip these - they don't change depth
            pos = next_brace + 1
        else
            -- Another conditional block opener - check if it has condition
            local cond_end = content:find("}", next_brace + 1, true)
            if cond_end then
                local potential_cond = content:sub(next_brace + 1, cond_end - 1)
                potential_cond = potential_cond:match("^%s*(.-)%s*$")
                if potential_cond ~= "" and not potential_cond:match("^[|&~!]") then
                    depth = depth + 1
                end
            end
            pos = next_brace + 1
        end
    end

    return nil
end

--- Check if content contains nested conditional blocks
---@param content string
---@return boolean
function ControlFlow:contains_nested_block(content)
    local pos = 1
    while pos <= #content do
        local brace = content:find("{", pos, true)
        if not brace then
            break
        end

        local after = content:sub(brace + 1, brace + 10)

        -- Skip special constructs
        if after:match("^%$") or
           after:match("^|") or
           after:match("^&|") or
           after:match("^~|") or
           after:match("^!|") or
           after:match("^else") or
           after:match("^elif") or
           after:match("^/") then
            pos = brace + 1
        else
            -- Check if this is a real conditional (has closing } before {/)
            local cond_end = content:find("}", brace + 1, true)
            if cond_end then
                local potential = content:sub(brace + 1, cond_end - 1)
                potential = potential:match("^%s*(.-)%s*$")
                if potential ~= "" then
                    return true  -- Found nested block
                end
            end
            pos = brace + 1
        end
    end
    return false
end

--- Transform $var syntax to Lua code for condition evaluation
---@param condition string The condition with possible $var syntax
---@return string Transformed condition as valid Lua
function ControlFlow:transform_condition(condition)
    -- Transform $var to direct variable access (variables are in sandbox)
    -- But we need to be careful not to transform ${ which is expression syntax
    local result = condition:gsub("%$([%a_][%w_]*)", function(var_name)
        return var_name  -- Just use the variable name directly (it's in sandbox env)
    end)
    return result
end

--- Evaluate a conditional block with its content
---@param condition string The condition expression
---@param block_content string Content including {else} and {elif} sections
---@return string The selected content
function ControlFlow:evaluate_block(condition, block_content)
    -- Parse the block into sections
    local sections = self:parse_block_sections(condition, block_content)

    -- Evaluate sections in order
    for _, section in ipairs(sections) do
        if section.condition == nil then
            -- This is the {else} section - always matches
            return self:trim_content(section.content)
        else
            -- Transform $var syntax and evaluate the condition
            local transformed = self:transform_condition(section.condition)
            local success, result = self.interpreter:evaluate_condition(
                transformed,
                self.game_state,
                self.context
            )
            if success and result then
                return self:trim_content(section.content)
            end
        end
    end

    -- No section matched
    return ""
end

--- Parse block content into sections (if, elif, else)
---@param initial_condition string
---@param content string
---@return table[] Array of {condition, content} pairs
function ControlFlow:parse_block_sections(initial_condition, content)
    local sections = {}

    -- Add initial if section
    table.insert(sections, {
        condition = initial_condition,
        content = ""
    })

    -- Find {elif condition} and {else} markers
    local markers = {}
    local pos = 1

    while pos <= #content do
        -- Find {elif condition}
        local elif_start, elif_end, elif_cond = content:find("{elif%s+([^}]+)}", pos)

        -- Find {else}
        local else_start, else_end = content:find("{else}", pos)

        -- Determine which comes first
        if elif_start and (not else_start or elif_start < else_start) then
            table.insert(markers, {
                start_pos = elif_start,
                end_pos = elif_end,
                condition = elif_cond:match("^%s*(.-)%s*$")
            })
            pos = elif_end + 1
        elseif else_start then
            table.insert(markers, {
                start_pos = else_start,
                end_pos = else_end,
                condition = nil  -- nil means else
            })
            pos = else_end + 1
        else
            break
        end
    end

    -- Extract content for each section
    local current_pos = 1

    for _, marker in ipairs(markers) do
        -- Current section content ends where this marker starts
        sections[#sections].content = content:sub(current_pos, marker.start_pos - 1)

        -- Add new section
        table.insert(sections, {
            condition = marker.condition,
            content = ""
        })

        current_pos = marker.end_pos + 1
    end

    -- Last section gets remaining content
    sections[#sections].content = content:sub(current_pos)

    return sections
end

--- Process inline conditionals: {condition: trueText | falseText}
---@param content string
---@return string
function ControlFlow:process_inline_conditionals(content)
    -- Pattern: {condition: trueText | falseText}
    -- Note: Must handle escaped \| and \: within text
    return content:gsub("{([^|{}:]+):%s*([^|{}]-)%s*|%s*([^{}]-)}", function(condition, true_text, false_text)
        condition = condition:match("^%s*(.-)%s*$")
        true_text = true_text:match("^%s*(.-)%s*$")
        false_text = false_text:match("^%s*(.-)%s*$")

        -- Unescape \| and \:
        true_text = true_text:gsub("\\|", "|"):gsub("\\:", ":")
        false_text = false_text:gsub("\\|", "|"):gsub("\\:", ":")

        -- Transform $var syntax
        local transformed = self:transform_condition(condition)

        local success, result = self.interpreter:evaluate_condition(
            transformed,
            self.game_state,
            self.context
        )

        if success and result then
            return true_text
        else
            return false_text
        end
    end)
end

--- Process text alternatives: {| a | b }, {&| }, {~| }, {!| }
---@param content string
---@return string
function ControlFlow:process_alternatives(content)
    -- Get or create alternatives state for this passage
    local passage_id = self.context.passage_id or "unknown"
    local alt_state = self:get_alternatives_state(passage_id)

    local alt_index = 0

    -- Process each alternative
    content = content:gsub("{([&~!]?)|(.-)}",  function(prefix, options_str)
        alt_index = alt_index + 1
        local alt_key = passage_id .. "_alt_" .. alt_index

        -- Parse options (split by |, handling whitespace)
        local options = {}
        for opt in (options_str .. "|"):gmatch("%s*(.-)%s*|") do
            table.insert(options, opt)
        end

        if #options == 0 then
            return ""
        end

        -- Get visit count for this alternative (0-indexed, incremented AFTER use)
        local visit_count = alt_state[alt_key] or 0

        -- Select based on prefix type
        local selected

        if prefix == "" then
            -- Sequence: show in order, stick at last
            local index = math.min(visit_count + 1, #options)
            selected = options[index]
        elseif prefix == "&" then
            -- Cycle: loop forever
            local index = ((visit_count) % #options) + 1
            selected = options[index]
        elseif prefix == "~" then
            -- Shuffle: random each time
            local index = math.random(1, #options)
            selected = options[index]
        elseif prefix == "!" then
            -- Once-only: each shown once, then empty
            local index = visit_count + 1
            if index <= #options then
                selected = options[index]
            else
                selected = ""
            end
        end

        -- Increment after selection (so next render gets next item)
        alt_state[alt_key] = visit_count + 1

        return selected or ""
    end)

    -- Save alternatives state back
    self:save_alternatives_state(passage_id, alt_state)

    return content
end

--- Get alternatives state for a passage
---@param passage_id string
---@return table
function ControlFlow:get_alternatives_state(passage_id)
    if self.game_state and self.game_state.get then
        local state = self.game_state:get("_alternatives") or {}
        return state[passage_id] or {}
    end
    return {}
end

--- Save alternatives state for a passage
---@param passage_id string
---@param state table
function ControlFlow:save_alternatives_state(passage_id, state)
    if self.game_state and self.game_state.set then
        local all_state = self.game_state:get("_alternatives") or {}
        all_state[passage_id] = state
        self.game_state:set("_alternatives", all_state)
    end
end

--- Trim leading/trailing whitespace and normalize blank lines
---@param content string
---@return string
function ControlFlow:trim_content(content)
    -- Remove leading and trailing newlines but preserve internal structure
    content = content:gsub("^[\n\r]+", "")
    content = content:gsub("[\n\r]+$", "")
    return content
end

return ControlFlow
