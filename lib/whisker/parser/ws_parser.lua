-- lib/whisker/parser/ws_parser.lua
-- WLS 1.0 .ws format parser

local WSParser = {}
WSParser.__index = WSParser
WSParser._dependencies = {}

-- Lazy load dependencies
local function get_lexer()
    return require("whisker.parser.ws_lexer")
end

local function get_choice()
    return require("whisker.core.choice")
end

local function get_passage()
    return require("whisker.core.passage")
end

local function get_story()
    return require("whisker.core.story")
end

function WSParser.new(deps)
    deps = deps or {}
    local instance = {
        tokens = {},
        current = 1,
        errors = {},
        warnings = {},
        story_data = {
            metadata = {},
            variables = {},
            passages = {},
            start_passage = nil
        },
        referenced_passages = {}
    }
    setmetatable(instance, WSParser)
    return instance
end

-- Main parse entry point
function WSParser:parse(input)
    -- Tokenize
    local WSLexer = get_lexer()
    local lexer = WSLexer.new()
    local lexer_result = lexer:tokenize(input)

    if not lexer_result.success then
        return {
            success = false,
            story = nil,
            errors = lexer_result.errors,
            warnings = {}
        }
    end

    self.tokens = lexer_result.tokens
    self.current = 1
    self.errors = {}
    self.warnings = {}
    self.story_data = {
        metadata = {},
        variables = {},
        lists = {},       -- WLS 1.0 Gap 3: LIST declarations
        arrays = {},      -- WLS 1.0 Gap 3: ARRAY declarations
        maps = {},        -- WLS 1.0 Gap 3: MAP declarations
        includes = {},    -- WLS 1.0 Gap 4: INCLUDE declarations
        functions = {},   -- WLS 1.0 Gap 4: FUNCTION definitions
        namespaces = {},  -- WLS 1.0 Gap 4: NAMESPACE names seen
        theme = nil,      -- WLS 1.0 Gap 5: Theme name
        styles = {},      -- WLS 1.0 Gap 5: Custom CSS properties
        passages = {},
        start_passage = nil,
        duplicate_passages = {}  -- Track duplicate passage names
    }
    self.passage_counter = 0  -- Counter for generating unique passage IDs
    self.referenced_passages = {}
    self.namespace_stack = {}  -- WLS 1.0 Gap 4: Current namespace context

    -- Parse header directives
    self:parse_header()

    -- Parse @vars block if present
    self:parse_vars_block()

    -- Parse collection declarations at header level (LIST, ARRAY, MAP)
    self:parse_collection_declarations()

    -- Parse presentation directives (THEME, STYLE) - WLS 1.0 Gap 5
    self:parse_presentation_directives()

    -- Parse passages
    while not self:is_at_end() do
        self:skip_newlines()
        if self:is_at_end() then break end

        if self:check("PASSAGE_MARKER") then
            self:parse_passage()
        else
            -- Skip unknown tokens at top level
            self:advance()
        end
    end

    -- Validate passage references
    self:validate_references()

    -- Resolve start passage name to ID
    -- If @start was used, start_passage contains a name that needs to be resolved
    -- If not, look for a passage named "Start"
    local start_name = self.story_data.start_passage or "Start"
    self.story_data.start_passage = nil  -- Reset to find the actual ID
    self.story_data.start_passage_name = start_name  -- Preserve the name for backwards compatibility

    -- Build name-to-ID lookup and find start passage
    self.story_data.passage_by_name = {}
    for passage_id, passage in pairs(self.story_data.passages) do
        if passage.name == start_name then
            self.story_data.start_passage = passage_id
        end
        -- Store first occurrence of each name for backward compatibility
        if not self.story_data.passage_by_name[passage.name] then
            self.story_data.passage_by_name[passage.name] = passage
        end
    end

    return {
        success = #self.errors == 0,
        story = self.story_data,
        errors = self.errors,
        warnings = self.warnings
    }
end

-- Parse header directives (@title:, @author:, etc.)
function WSParser:parse_header()
    while not self:is_at_end() do
        self:skip_newlines()

        if self:check("DIRECTIVE") then
            local token = self:advance()
            local name = token.value.name
            local value = token.value.value

            -- Map directive names to metadata fields
            if name == "title" then
                self.story_data.metadata.title = value
            elseif name == "author" then
                self.story_data.metadata.author = value
            elseif name == "version" then
                self.story_data.metadata.version = value
            elseif name == "ifid" then
                self.story_data.metadata.ifid = value
            elseif name == "start" then
                self.story_data.start_passage = value
            elseif name == "description" then
                self.story_data.metadata.description = value
            elseif name == "created" then
                self.story_data.metadata.created = value
            elseif name == "modified" then
                self.story_data.metadata.modified = value
            elseif name == "var" then
                -- Parse single-line variable definition: @var: name = value
                -- First try to match valid variable name
                local var_name, var_value = value:match("^%s*([a-zA-Z_][a-zA-Z0-9_]*)%s*=%s*(.+)%s*$")
                if var_name then
                    -- Parse the value
                    local parsed_value = var_value
                    -- Try to parse as number
                    local num = tonumber(var_value)
                    if num then
                        parsed_value = num
                    elseif var_value == "true" then
                        parsed_value = true
                    elseif var_value == "false" then
                        parsed_value = false
                    elseif var_value:match('^".-"$') or var_value:match("^'.-'$") then
                        -- String literal
                        parsed_value = var_value:sub(2, -2)
                    end
                    self.story_data.variables[var_name] = {
                        name = var_name,
                        value = parsed_value,
                        type = type(parsed_value)
                    }
                else
                    -- Try to match invalid variable name (starts with number, etc.)
                    local invalid_name, invalid_value = value:match("^%s*(%S+)%s*=%s*(.+)%s*$")
                    if invalid_name then
                        -- Store with special marker for validator
                        self.story_data.variables[invalid_name] = {
                            name = invalid_name,
                            value = invalid_value,
                            type = "invalid",
                            invalid = true
                        }
                    end
                end
            else
                -- Store unknown directives
                self.story_data.metadata[name] = value
            end
        elseif self:check("VARS_START") or self:check("PASSAGE_MARKER") then
            -- End of header
            break
        else
            -- Unexpected token in header
            break
        end
    end
end

-- Parse @vars block
function WSParser:parse_vars_block()
    if not self:check("VARS_START") then
        return
    end

    self:advance() -- consume @vars

    -- Skip only newlines after @vars (not indents)
    while self:check("NEWLINE") do
        self:advance()
    end

    -- Parse indented variable declarations
    while not self:is_at_end() do
        if not self:check("INDENT") then
            break
        end

        self:advance() -- consume indent

        -- Expect varName: value (may be TEXT with colon, or TEXT + COLON + value)
        if self:check("TEXT") then
            local text = self:advance().value
            -- Check for name: pattern (value may be in next token for strings)
            local name, value_str = text:match("^([%a_][%w_]*):%s*(.*)$")
            if name then
                local value
                -- If value_str is empty, check for STRING token (quoted string)
                if value_str == "" and self:check("STRING") then
                    value = self:advance().value
                else
                    value = self:parse_literal_value(value_str)
                end
                self.story_data.variables[name] = {
                    type = type(value),
                    value = value
                }
            else
                -- New tokenization: TEXT (name) + COLON + value tokens
                -- The text is just the variable name without colon
                local var_name = text:match("^([%a_][%w_]*)%s*$")
                if var_name and self:check("COLON") then
                    self:advance() -- consume COLON
                    local value
                    if self:check("STRING") then
                        value = self:advance().value
                    elseif self:check("NUMBER") then
                        value = tonumber(self:advance().value)
                    elseif self:check("TEXT") then
                        local val_text = self:advance().value:match("^%s*(.-)%s*$")
                        value = self:parse_literal_value(val_text)
                    end
                    if var_name and value ~= nil then
                        self.story_data.variables[var_name] = {
                            type = type(value),
                            value = value
                        }
                    end
                end
            end
        end

        -- Skip only newlines (not indents) to allow next variable
        while self:check("NEWLINE") do
            self:advance()
        end
    end
end

-- Parse header-level declarations (collections and modules)
-- WLS 1.0 Gap 3: Data Structures (LIST, ARRAY, MAP)
-- WLS 1.0 Gap 4: Modules (INCLUDE, FUNCTION, NAMESPACE)
function WSParser:parse_collection_declarations()
    while not self:is_at_end() do
        self:skip_newlines()
        if self:is_at_end() then break end

        -- WLS 1.0 Gap 3: Collections
        if self:check("LIST") then
            self:parse_list_declaration()
        elseif self:check("ARRAY") then
            self:parse_array_declaration()
        elseif self:check("MAP") then
            self:parse_map_declaration()
        -- WLS 1.0 Gap 4: Modules
        elseif self:check("INCLUDE") then
            self:parse_include_declaration()
        elseif self:check("FUNCTION") then
            self:parse_function_declaration()
        elseif self:check("NAMESPACE") then
            self:parse_namespace_block()
        elseif self:check("END") then
            -- END NAMESPACE
            self:parse_end_namespace()
        elseif self:check("PASSAGE_MARKER") then
            -- End of header, start of passages
            break
        else
            -- Unknown token, stop
            break
        end
    end
end

-- Parse presentation directives (THEME, STYLE)
-- WLS 1.0 Gap 5: Presentation Layer
function WSParser:parse_presentation_directives()
    while not self:is_at_end() do
        self:skip_newlines()
        if self:is_at_end() then break end

        if self:check("THEME") then
            self:parse_theme_directive()
        elseif self:check("STYLE") then
            self:parse_style_block()
        elseif self:check("PASSAGE_MARKER") then
            -- End of header, start of passages
            break
        else
            -- Unknown token, stop
            break
        end
    end
end

-- Parse THEME directive: THEME "theme-name"
-- WLS 1.0 Gap 5: Presentation Layer
function WSParser:parse_theme_directive()
    self:advance() -- consume THEME

    -- Get the theme name
    local theme_name = nil
    if self:check("STRING") then
        theme_name = self:advance().value
    elseif self:check("TEXT") then
        local text = self:advance().value:match("^%s*(.-)%s*$")
        if text:match('^".-"$') or text:match("^'.-'$") then
            theme_name = text:sub(2, -2)
        else
            theme_name = text
        end
    end

    if not theme_name or theme_name == "" then
        self:add_error("Expected theme name after THEME keyword", {
            code = "WLS-PRS-004",
            suggestion = 'Use: THEME "dark" or THEME "default"'
        })
        self:skip_to_next_line()
        return
    end

    self.story_data.theme = theme_name
    self:skip_to_next_line()
end

-- Parse STYLE block: STYLE { --property: value; ... }
-- WLS 1.0 Gap 5: Presentation Layer
function WSParser:parse_style_block()
    self:advance() -- consume STYLE

    -- Skip whitespace/newlines
    self:skip_newlines()

    -- Expect opening brace
    if not self:check("LBRACE") then
        self:add_error("Expected '{' after STYLE keyword", {
            code = "WLS-PRS-007",
            suggestion = 'Use: STYLE { --bg-color: #000; }'
        })
        self:skip_to_next_line()
        return
    end
    self:advance() -- consume {

    -- Parse CSS properties until closing brace
    local properties = {}
    local depth = 1

    while not self:is_at_end() and depth > 0 do
        self:skip_newlines()

        if self:check("RBRACE") then
            depth = depth - 1
            self:advance()
        elseif self:check("LBRACE") then
            depth = depth + 1
            self:advance()
        elseif self:check("TEXT") then
            -- Parse CSS property: --name: value;
            local text = self:advance().value
            -- Match CSS custom property pattern
            for prop, value in text:gmatch("%-%-([%w%-]+)%s*:%s*([^;]+)") do
                properties["--" .. prop] = value:match("^%s*(.-)%s*$")
            end
            -- Also match standard properties like passage-font, choice-style
            for prop, value in text:gmatch("([%w%-]+)%s*:%s*([^;]+)") do
                if not prop:match("^%-%-") then
                    properties[prop] = value:match("^%s*(.-)%s*$")
                end
            end
        else
            self:advance() -- skip unknown tokens
        end
    end

    self.story_data.styles = properties
end

-- Parse INCLUDE declaration: INCLUDE "path/to/file.ws"
-- WLS 1.0 Gap 4: Modules
function WSParser:parse_include_declaration()
    self:advance() -- consume INCLUDE

    -- Get the path string
    local path = nil
    if self:check("STRING") then
        path = self:advance().value
    elseif self:check("TEXT") then
        -- Path might be in TEXT token if quotes weren't recognized
        local text = self:advance().value:match("^%s*(.-)%s*$")
        if text:match('^".-"$') or text:match("^'.-'$") then
            path = text:sub(2, -2)
        else
            path = text
        end
    end

    if not path or path == "" then
        self:add_error("Expected path string after INCLUDE keyword", {
            code = "WLS-MOD-001",
            suggestion = 'Use: INCLUDE "path/to/file.ws"'
        })
        self:skip_to_next_line()
        return
    end

    -- Store include declaration
    table.insert(self.story_data.includes, {
        path = path,
        resolved = false  -- Will be resolved by loader
    })

    self:skip_to_next_line()
end

-- Parse FUNCTION declaration: FUNCTION name(param1, param2) ... END
-- WLS 1.0 Gap 4: Modules
function WSParser:parse_function_declaration()
    local start_token = self:peek()
    self:advance() -- consume FUNCTION

    -- Get function name
    local func_name = nil
    if self:check("TEXT") then
        func_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    end

    if not func_name then
        self:add_error("Expected function name after FUNCTION keyword", {
            code = "WLS-MOD-006",
            suggestion = "Use: FUNCTION myFunction(param1, param2)"
        })
        self:skip_to_next_line()
        return
    end

    -- Parse parameters (optional)
    local params = {}
    if self:check("LPAREN") then
        self:advance() -- consume (
        while not self:is_at_end() and not self:check("RPAREN") do
            if self:check("TEXT") then
                local param = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
                if param then
                    table.insert(params, param)
                end
            end
            if self:check("COMMA") then
                self:advance()
            elseif not self:check("RPAREN") and not self:check("TEXT") then
                break
            end
        end
        if self:check("RPAREN") then
            self:advance() -- consume )
        end
    end

    self:skip_newlines()

    -- Parse function body until END
    local body_lines = {}
    local depth = 1
    while not self:is_at_end() and depth > 0 do
        if self:check("FUNCTION") or self:check("NAMESPACE") then
            depth = depth + 1
        elseif self:check("END") then
            depth = depth - 1
            if depth == 0 then
                self:advance() -- consume END
                break
            end
        end

        -- Collect token for body
        local token = self:advance()
        if token.type ~= "NEWLINE" then
            table.insert(body_lines, token.value)
        else
            table.insert(body_lines, "\n")
        end
    end

    -- Store function declaration
    self.story_data.functions[func_name] = {
        name = func_name,
        params = params,
        body = table.concat(body_lines, " "),
        type = "function"
    }

    self:skip_newlines()
end

-- Parse NAMESPACE block: NAMESPACE Name ... END NAMESPACE
-- WLS 1.0 Gap 4: Modules
function WSParser:parse_namespace_block()
    self:advance() -- consume NAMESPACE

    -- Get namespace name
    local ns_name = nil
    if self:check("TEXT") then
        ns_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    end

    if not ns_name then
        self:add_error("Expected namespace name after NAMESPACE keyword", {
            code = "WLS-MOD-007",
            suggestion = "Use: NAMESPACE MyNamespace"
        })
        self:skip_to_next_line()
        return
    end

    -- Push namespace onto stack
    table.insert(self.namespace_stack, ns_name)

    -- Record namespace
    table.insert(self.story_data.namespaces, ns_name)

    self:skip_to_next_line()
end

-- Parse END NAMESPACE
-- WLS 1.0 Gap 4: Modules
function WSParser:parse_end_namespace()
    self:advance() -- consume END

    -- Check for NAMESPACE keyword after END
    self:skip_newlines()
    if self:check("NAMESPACE") then
        self:advance() -- consume NAMESPACE
    end

    -- Pop namespace from stack
    if #self.namespace_stack > 0 then
        table.remove(self.namespace_stack)
    else
        self:add_error("END NAMESPACE without matching NAMESPACE", {
            code = "WLS-MOD-008"
        })
    end

    self:skip_to_next_line()
end

-- Get current fully qualified namespace prefix
-- WLS 1.0 Gap 4: Modules
function WSParser:get_namespace_prefix()
    if #self.namespace_stack == 0 then
        return ""
    end
    return table.concat(self.namespace_stack, "::") .. "::"
end

-- Parse LIST declaration: LIST name = value1, (value2), value3
function WSParser:parse_list_declaration()
    self:advance() -- consume LIST

    -- Get list name
    local list_name = nil
    if self:check("TEXT") then
        list_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    end

    if not list_name then
        self:add_error("Expected list name after LIST keyword", {
            code = "WLS-SYN-010",
            suggestion = "Add a list name: LIST moods = happy, sad"
        })
        self:skip_to_next_line()
        return
    end

    -- Expect = sign
    local has_equals = false
    if self:check("TEXT") then
        local text = self:peek().value
        if text:match("^%s*=%s*") then
            self:advance()
            has_equals = true
        end
    end

    if not has_equals then
        self:add_error("Expected '=' after list name", {
            code = "WLS-SYN-011",
            suggestion = "Use: LIST " .. list_name .. " = value1, value2"
        })
        self:skip_to_next_line()
        return
    end

    -- Parse list values (comma-separated, with optional parentheses for active values)
    local values = {}
    local active = {}

    while not self:is_at_end() and not self:check("NEWLINE") do
        local is_active = false

        -- Check for opening paren (active marker)
        if self:check("LPAREN") then
            self:advance()
            is_active = true
        end

        -- Get value name
        local value_name = nil
        if self:check("TEXT") then
            value_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
        end

        if value_name then
            table.insert(values, value_name)
            if is_active then
                active[value_name] = true
            end
        end

        -- Check for closing paren
        if is_active and self:check("RPAREN") then
            self:advance()
        end

        -- Check for comma (more values)
        if self:check("COMMA") then
            self:advance()
        elseif self:check("TEXT") then
            -- Could be comma in text
            local text = self:peek().value
            if text:match("^%s*,%s*") then
                self:advance()
            else
                break
            end
        else
            break
        end
    end

    -- Store list declaration
    self.story_data.lists[list_name] = {
        name = list_name,
        values = values,
        active = active,
        type = "list"
    }

    -- Also create a variable for the list
    self.story_data.variables[list_name] = {
        name = list_name,
        value = active,
        type = "list",
        list_values = values
    }

    self:skip_to_next_line()
end

-- Parse ARRAY declaration: ARRAY name = [value1, value2, value3]
function WSParser:parse_array_declaration()
    self:advance() -- consume ARRAY

    -- Get array name
    local array_name = nil
    if self:check("TEXT") then
        array_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    end

    if not array_name then
        self:add_error("Expected array name after ARRAY keyword", {
            code = "WLS-SYN-012",
            suggestion = "Add an array name: ARRAY items = [1, 2, 3]"
        })
        self:skip_to_next_line()
        return
    end

    -- Expect = sign
    local has_equals = false
    if self:check("TEXT") then
        local text = self:peek().value
        if text:match("^%s*=%s*") then
            self:advance()
            has_equals = true
        end
    end

    if not has_equals then
        self:add_error("Expected '=' after array name", {
            code = "WLS-SYN-013",
            suggestion = "Use: ARRAY " .. array_name .. " = [value1, value2]"
        })
        self:skip_to_next_line()
        return
    end

    -- Expect opening bracket [
    if not self:check("LBRACKET") then
        self:add_error("Expected '[' for array literal", {
            code = "WLS-SYN-014",
            suggestion = "Use square brackets: ARRAY " .. array_name .. " = [1, 2, 3]"
        })
        self:skip_to_next_line()
        return
    end
    self:advance() -- consume [

    -- Parse array elements
    local elements = {}

    while not self:is_at_end() and not self:check("RBRACKET") and not self:check("NEWLINE") do
        local element = self:parse_array_element()
        if element ~= nil then
            table.insert(elements, element)
        end

        -- Check for comma (more elements)
        if self:check("COMMA") then
            self:advance()
        elseif self:check("TEXT") then
            local text = self:peek().value
            if text:match("^%s*,%s*") then
                self:advance()
            elseif not self:check("RBRACKET") then
                break
            end
        elseif not self:check("RBRACKET") then
            break
        end
    end

    -- Expect closing bracket ]
    if self:check("RBRACKET") then
        self:advance()
    else
        self:add_error("Expected ']' to close array literal", {
            code = "WLS-SYN-015"
        })
    end

    -- Store array declaration
    self.story_data.arrays[array_name] = {
        name = array_name,
        elements = elements,
        type = "array"
    }

    -- Also create a variable for the array
    self.story_data.variables[array_name] = {
        name = array_name,
        value = elements,
        type = "array"
    }

    self:skip_to_next_line()
end

-- Parse a single array element
function WSParser:parse_array_element()
    if self:check("NUMBER") then
        return tonumber(self:advance().value)
    elseif self:check("STRING") then
        return self:advance().value
    elseif self:check("TEXT") then
        local text = self:advance().value:match("^%s*(.-)%s*$")
        -- Try to parse as number or boolean
        local num = tonumber(text)
        if num then return num end
        if text == "true" then return true end
        if text == "false" then return false end
        if text == "nil" then return nil end
        return text
    end
    return nil
end

-- Parse MAP declaration: MAP name = { key: value, key2: value2 }
function WSParser:parse_map_declaration()
    self:advance() -- consume MAP

    -- Get map name
    local map_name = nil
    if self:check("TEXT") then
        map_name = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    end

    if not map_name then
        self:add_error("Expected map name after MAP keyword", {
            code = "WLS-SYN-016",
            suggestion = "Add a map name: MAP player = { name: \"Hero\" }"
        })
        self:skip_to_next_line()
        return
    end

    -- Expect = sign
    local has_equals = false
    if self:check("TEXT") then
        local text = self:peek().value
        if text:match("^%s*=%s*") then
            self:advance()
            has_equals = true
        end
    end

    if not has_equals then
        self:add_error("Expected '=' after map name", {
            code = "WLS-SYN-017",
            suggestion = "Use: MAP " .. map_name .. " = { key: value }"
        })
        self:skip_to_next_line()
        return
    end

    -- Expect opening brace {
    if not self:check("BLOCK_START") then
        self:add_error("Expected '{' for map literal", {
            code = "WLS-SYN-018",
            suggestion = "Use curly braces: MAP " .. map_name .. " = { key: value }"
        })
        self:skip_to_next_line()
        return
    end
    self:advance() -- consume {

    -- Parse map key-value pairs
    local entries = {}

    while not self:is_at_end() and not self:check("BLOCK_END") and not self:check("NEWLINE") do
        local key, value = self:parse_map_entry()
        if key ~= nil then
            entries[key] = value
        end

        -- Check for comma (more entries)
        if self:check("COMMA") then
            self:advance()
        elseif self:check("TEXT") then
            local text = self:peek().value
            if text:match("^%s*,%s*") then
                self:advance()
            elseif not self:check("BLOCK_END") then
                break
            end
        elseif not self:check("BLOCK_END") then
            break
        end
    end

    -- Expect closing brace }
    if self:check("BLOCK_END") then
        self:advance()
    else
        self:add_error("Expected '}' to close map literal", {
            code = "WLS-SYN-019"
        })
    end

    -- Store map declaration
    self.story_data.maps[map_name] = {
        name = map_name,
        entries = entries,
        type = "map"
    }

    -- Also create a variable for the map
    self.story_data.variables[map_name] = {
        name = map_name,
        value = entries,
        type = "map"
    }

    self:skip_to_next_line()
end

-- Parse a single map key:value entry
function WSParser:parse_map_entry()
    local key = nil

    -- Get key (identifier or string)
    if self:check("TEXT") then
        key = self:advance().value:match("^%s*([%a_][%w_]*)%s*$")
    elseif self:check("STRING") then
        key = self:advance().value
    end

    if not key then
        return nil, nil
    end

    -- Expect colon
    if self:check("COLON") then
        self:advance()
    elseif self:check("TEXT") then
        local text = self:peek().value
        if text:match("^%s*:%s*") then
            self:advance()
        else
            return key, nil
        end
    else
        return key, nil
    end

    -- Get value
    local value = nil
    if self:check("NUMBER") then
        value = tonumber(self:advance().value)
    elseif self:check("STRING") then
        value = self:advance().value
    elseif self:check("TEXT") then
        local text = self:advance().value:match("^%s*(.-)%s*$")
        local num = tonumber(text)
        if num then
            value = num
        elseif text == "true" then
            value = true
        elseif text == "false" then
            value = false
        elseif text == "nil" then
            value = nil
        else
            value = text
        end
    elseif self:check("LBRACKET") then
        -- Nested array
        self:advance()
        value = {}
        while not self:is_at_end() and not self:check("RBRACKET") do
            local elem = self:parse_array_element()
            if elem ~= nil then
                table.insert(value, elem)
            end
            if self:check("COMMA") then
                self:advance()
            else
                break
            end
        end
        if self:check("RBRACKET") then
            self:advance()
        end
    end

    return key, value
end

-- Parse a single passage
function WSParser:parse_passage()
    -- Capture start location before consuming ::
    local start_token = self:peek()
    local start_location = start_token.location and start_token.location.start or {
        line = start_token.line,
        column = start_token.column,
        offset = start_token.position - 1
    }

    self:advance() -- consume ::

    -- Get passage name
    local passage_name = ""
    while not self:is_at_end() and not self:check("NEWLINE") do
        local token = self:advance()
        if token.type == "TEXT" then
            passage_name = passage_name .. token.value
        elseif token.type == "VAR_INTERP" then
            passage_name = passage_name .. "$" .. token.value
        end
    end

    passage_name = passage_name:match("^%s*(.-)%s*$") -- Trim

    if passage_name == "" then
        self:add_error("Expected passage name after '::'", {
            code = WSParser.ERROR_CODES.EXPECTED_PASSAGE_NAME,
            suggestion = "Add a passage name like: :: MyPassage"
        })
        self:skip_to_next_line()
        return
    end

    -- WLS 1.0 Gap 4: Handle namespace prefixing
    -- If the passage name starts with ::, it's a global reference (no prefix)
    -- Otherwise, apply current namespace prefix
    local qualified_name = passage_name
    if passage_name:sub(1, 2) == "::" then
        -- Global namespace - strip the :: prefix
        qualified_name = passage_name:sub(3)
    elseif #self.namespace_stack > 0 then
        -- Apply namespace prefix
        qualified_name = self:get_namespace_prefix() .. passage_name
    end

    -- Store both original and qualified name
    local original_name = passage_name

    -- Generate unique ID for this passage
    local passage_id = string.format("passage_%d_%s", self.passage_counter, qualified_name)
    self.passage_counter = self.passage_counter + 1

    -- Check for duplicate name (different from ID) - use qualified name
    local has_duplicate = false
    for _, existing in pairs(self.story_data.passages) do
        if existing.name == qualified_name then
            has_duplicate = true
            break
        end
    end

    if has_duplicate then
        self:add_warning("Duplicate passage name: '" .. qualified_name .. "'", {
            code = WSParser.ERROR_CODES.DUPLICATE_PASSAGE,
            suggestion = "Rename one of the passages with the same name"
        })
        -- Track duplicate for validator
        if not self.story_data.duplicate_passages[qualified_name] then
            self.story_data.duplicate_passages[qualified_name] = 2  -- First + current
        else
            self.story_data.duplicate_passages[qualified_name] = self.story_data.duplicate_passages[qualified_name] + 1
        end
    end

    self:skip_newlines()

    local passage_data = {
        id = passage_id,
        name = qualified_name,            -- WLS 1.0 Gap 4: Fully qualified name
        original_name = original_name,    -- WLS 1.0 Gap 4: Name as written in source
        namespace = #self.namespace_stack > 0 and table.concat(self.namespace_stack, "::") or nil,
        title = qualified_name,  -- For compatibility with validators
        content = "",
        choices = {},
        gathers = {},          -- WLS 1.0: Gather points for flow reconvergence
        tunnel_calls = {},     -- WLS 1.0: Tunnel calls within passage
        has_tunnel_return = false,  -- WLS 1.0: Whether passage ends with <-
        tags = {},
        metadata = {},
        on_enter_script = nil,
        on_exit_script = nil
    }

    -- Parse passage directives
    while self:check("DIRECTIVE") do
        local token = self:advance()
        local name = token.value.name
        local value = token.value.value

        if name == "tags" then
            -- Parse comma-separated tags
            for tag in value:gmatch("[^,%s]+") do
                table.insert(passage_data.tags, tag)
            end
        elseif name == "color" then
            passage_data.metadata.color = value
        elseif name == "position" then
            local x, y = value:match("(%d+),%s*(%d+)")
            if x and y then
                passage_data.metadata.position = { tonumber(x), tonumber(y) }
            end
        elseif name == "notes" then
            passage_data.metadata.notes = value
        elseif name == "onEnter" then
            passage_data.on_enter_script = value
        elseif name == "onExit" then
            passage_data.on_exit_script = value
        elseif name == "fallback" then
            passage_data.metadata.fallback = value
        else
            passage_data.metadata[name] = value
        end

        self:skip_newlines()
    end

    -- Parse passage content and choices
    local content_parts = {}
    local current_choice_depth = 0  -- Track nesting depth for gather points

    while not self:is_at_end() do
        -- Check for next passage
        if self:check("PASSAGE_MARKER") then
            break
        end

        -- Parse choice (increases nesting depth)
        if self:check("CHOICE_ONCE") or self:check("CHOICE_STICKY") then
            local choice = self:parse_choice()
            if choice then
                table.insert(passage_data.choices, choice)
                current_choice_depth = math.max(current_choice_depth, 1)
            end
        -- Parse gather point (WLS 1.0)
        elseif self:check("GATHER") then
            local gather_depth = 0
            local gather_start = self:peek()
            -- Count gather depth (number of consecutive - tokens)
            while self:check("GATHER") do
                gather_depth = gather_depth + 1
                self:advance()
            end
            -- Collect gather content until next choice, gather, or passage
            local gather_content_parts = {}
            while not self:is_at_end() and
                  not self:check("PASSAGE_MARKER") and
                  not self:check("CHOICE_ONCE") and
                  not self:check("CHOICE_STICKY") and
                  not self:check("GATHER") do
                if self:check("TEXT") then
                    table.insert(gather_content_parts, self:advance().value)
                elseif self:check("VAR_INTERP") then
                    table.insert(gather_content_parts, "$" .. self:advance().value)
                elseif self:check("NEWLINE") then
                    table.insert(gather_content_parts, "\n")
                    self:advance()
                    break  -- Stop at end of line for gather
                else
                    break
                end
            end
            table.insert(passage_data.gathers, {
                depth = gather_depth,
                content = table.concat(gather_content_parts):match("^%s*(.-)%s*$") or "",
                location = gather_start.location
            })
            -- Add gather marker to content for runtime processing
            table.insert(content_parts, string.rep("-", gather_depth) .. " ")
            table.insert(content_parts, table.concat(gather_content_parts))
        -- Parse tunnel return <- (WLS 1.0)
        elseif self:check("TUNNEL_RETURN") then
            self:advance()
            passage_data.has_tunnel_return = true
            table.insert(content_parts, "<-")
        -- Parse arrow -> which might be a tunnel call -> Name ->
        elseif self:check("ARROW") then
            self:advance()
            -- Look ahead for tunnel call pattern: -> Name ->
            local target_parts = {}
            while not self:is_at_end() and
                  not self:check("NEWLINE") and
                  not self:check("ARROW") and
                  not self:check("PASSAGE_MARKER") do
                local token = self:advance()
                if token.type == "TEXT" then
                    table.insert(target_parts, token.value)
                end
            end
            local target = table.concat(target_parts):match("^%s*(.-)%s*$")

            if self:check("ARROW") then
                -- This is a tunnel call: -> Target ->
                self:advance()  -- consume second ->
                table.insert(passage_data.tunnel_calls, {
                    target = target,
                    position = #content_parts + 1
                })
                -- Track reference
                if target ~= "" then
                    if not self.referenced_passages[target] then
                        self.referenced_passages[target] = {}
                    end
                    table.insert(self.referenced_passages[target], {
                        line = self:peek().line,
                        column = self:peek().column
                    })
                end
                table.insert(content_parts, "-> " .. target .. " ->")
            else
                -- Regular navigation: -> Target (no choices context here)
                table.insert(content_parts, "-> " .. target)
                -- Track reference
                if target ~= "" and target ~= "END" and target ~= "BACK" and target ~= "RESTART" then
                    if not self.referenced_passages[target] then
                        self.referenced_passages[target] = {}
                    end
                    table.insert(self.referenced_passages[target], {
                        line = self:peek().line,
                        column = self:peek().column
                    })
                end
            end
        -- Parse content
        elseif self:check("TEXT") then
            table.insert(content_parts, self:advance().value)
        elseif self:check("VAR_INTERP") then
            table.insert(content_parts, "$" .. self:advance().value)
        elseif self:check("TEMP_VAR_INTERP") then
            table.insert(content_parts, "$" .. self:advance().value)
        elseif self:check("EXPR_INTERP") then
            table.insert(content_parts, "${" .. self:advance().value .. "}")
        elseif self:check("BLOCK_START") then
            table.insert(content_parts, self:parse_block())
        elseif self:check("BLOCK_END") then
            table.insert(content_parts, "}")
            self:advance()
        elseif self:check("BLOCK_CLOSE") then
            table.insert(content_parts, "{/}")
            self:advance()
        elseif self:check("ELSE") then
            table.insert(content_parts, "{else}")
            self:advance()
        elseif self:check("ELIF") then
            table.insert(content_parts, "{elif " .. self:advance().value .. "}")
        elseif self:check("PIPE") then
            table.insert(content_parts, "|")
            self:advance()
        elseif self:check("NEWLINE") then
            table.insert(content_parts, "\n")
            self:advance()
        elseif self:check("INDENT") then
            table.insert(content_parts, self:advance().value)
        else
            -- Skip unknown tokens
            self:advance()
        end
    end

    passage_data.content = table.concat(content_parts)

    -- Capture end location
    local end_token = self.tokens[self.current - 1] or self:peek()
    local end_location = end_token.location and end_token.location["end"] or {
        line = end_token.line,
        column = end_token.column,
        offset = end_token.position - 1
    }

    -- Store location span
    passage_data.location = {
        start = start_location,
        ["end"] = end_location
    }

    -- Store passage using unique ID
    self.story_data.passages[passage_id] = passage_data
end

-- Parse a choice
function WSParser:parse_choice()
    local Choice = get_choice()
    local choice_type = Choice.TYPE_ONCE

    -- Capture start location
    local start_token = self:peek()
    local choice_start_location = start_token.location and start_token.location.start or {
        line = start_token.line,
        column = start_token.column,
        offset = start_token.position - 1
    }

    if self:check("CHOICE_STICKY") then
        choice_type = Choice.TYPE_STICKY
    end

    self:advance() -- consume + or *

    local choice_data = {
        text = "",
        target = nil,
        condition = nil,
        action = nil,
        choice_type = choice_type
    }

    -- Parse optional condition { cond }
    if self:check("BLOCK_START") then
        self:advance()
        local condition_parts = {}
        while not self:is_at_end() and not self:check("BLOCK_END") do
            local token = self:advance()
            if token.type == "TEXT" then
                table.insert(condition_parts, token.value)
            elseif token.type == "VAR_INTERP" then
                table.insert(condition_parts, token.value)
            end
        end
        if self:check("BLOCK_END") then
            self:advance()
        end
        choice_data.condition = table.concat(condition_parts)
    end

    -- Parse choice text [text] - collect all tokens until ARROW
    local text_parts = {}
    while not self:is_at_end() and not self:check("ARROW") and not self:check("NEWLINE") do
        if self:check("TEXT") then
            table.insert(text_parts, self:advance().value)
        elseif self:check("VAR_INTERP") then
            table.insert(text_parts, "$" .. self:advance().value)
        elseif self:check("TEMP_VAR_INTERP") then
            table.insert(text_parts, "$" .. self:advance().value)
        elseif self:check("EXPR_INTERP") then
            table.insert(text_parts, "${" .. self:advance().value .. "}")
        elseif self:check("BLOCK_START") then
            -- This might be an inline action before arrow, stop here
            break
        else
            -- Skip other tokens
            self:advance()
        end
    end

    local full_text = table.concat(text_parts)
    -- Extract text from [brackets] if present
    local bracket_text = full_text:match("%[(.-)%]")
    if bracket_text then
        choice_data.text = bracket_text
        -- Check for condition/action in remaining text {if condition} or {do action}
        local after = full_text:match("%](.*)")
        if after then
            local block_content = after:match("{(.-)}")
            if block_content then
                -- Check if it's a condition ({if ...}) or action ({do ...})
                local condition = block_content:match("^%s*if%s+(.+)$")
                local action = block_content:match("^%s*do%s+(.+)$")
                if condition then
                    choice_data.condition = condition
                elseif action then
                    choice_data.action = action
                else
                    -- Default to action for backwards compatibility
                    choice_data.action = block_content
                end
            end
        end
    else
        choice_data.text = full_text:match("^%s*(.-)%s*$") or ""
    end

    -- Parse optional block BEFORE arrow {if condition} or {do action}
    if self:check("BLOCK_START") then
        self:advance()
        local block_parts = {}
        while not self:is_at_end() and not self:check("BLOCK_END") do
            local token = self:advance()
            if token.type == "TEXT" then
                table.insert(block_parts, token.value)
            elseif token.type == "VAR_INTERP" then
                table.insert(block_parts, "$" .. token.value)
            elseif token.type == "TEMP_VAR_INTERP" then
                table.insert(block_parts, "$" .. token.value)
            end
        end
        if self:check("BLOCK_END") then
            self:advance()
        end
        local block_content = table.concat(block_parts)
        -- Check if it's a condition ({if ...}) or action ({do ...})
        local condition = block_content:match("^%s*if%s+(.+)$")
        local action = block_content:match("^%s*do%s+(.+)$")
        if condition then
            choice_data.condition = condition
        elseif action then
            choice_data.action = action
        else
            -- Default to action for backwards compatibility
            choice_data.action = block_content
        end
    end

    -- Parse arrow and target
    if self:check("ARROW") then
        self:advance()
        -- Get target
        local target_parts = {}
        while not self:is_at_end() and not self:check("NEWLINE") and not self:check("BLOCK_START") do
            local token = self:advance()
            if token.type == "TEXT" then
                table.insert(target_parts, token.value)
            end
        end
        local target = table.concat(target_parts):match("^%s*(.-)%s*$")
        choice_data.target = target

        -- Track reference (unless special target)
        if target ~= "END" and target ~= "BACK" and target ~= "RESTART" then
            local token = self:peek()
            if not self.referenced_passages[target] then
                self.referenced_passages[target] = {}
            end
            table.insert(self.referenced_passages[target], {
                line = token.line,
                column = token.column
            })
        end
    end

    -- Parse optional action block after target {do action}
    if self:check("BLOCK_START") then
        self:advance()
        local action_parts = {}
        while not self:is_at_end() and not self:check("BLOCK_END") do
            local token = self:advance()
            if token.type == "TEXT" then
                table.insert(action_parts, token.value)
            elseif token.type == "VAR_INTERP" then
                table.insert(action_parts, "$" .. token.value)
            end
        end
        if self:check("BLOCK_END") then
            self:advance()
        end
        local action_content = table.concat(action_parts)
        -- Strip 'do ' prefix if present
        local action = action_content:match("^%s*do%s+(.+)$")
        if action then
            choice_data.action = action
        else
            choice_data.action = action_content
        end
    end

    -- Skip to end of line
    while not self:is_at_end() and not self:check("NEWLINE") do
        self:advance()
    end

    -- Allow empty targets - validator will catch WLS-LNK-005
    if not choice_data.target then
        choice_data.target = ""
    end

    -- Capture end location
    local end_token = self.tokens[self.current - 1] or self:peek()
    local choice_end_location = end_token.location and end_token.location["end"] or {
        line = end_token.line,
        column = end_token.column,
        offset = end_token.position - 1
    }

    -- Store location span
    choice_data.location = {
        start = choice_start_location,
        ["end"] = choice_end_location
    }

    return choice_data
end

-- Parse a block { ... }
function WSParser:parse_block()
    local block_parts = {}
    table.insert(block_parts, "{")
    self:advance() -- consume {

    local depth = 1
    while not self:is_at_end() and depth > 0 do
        if self:check("BLOCK_START") then
            depth = depth + 1
            table.insert(block_parts, "{")
            self:advance()
        elseif self:check("BLOCK_END") then
            depth = depth - 1
            if depth > 0 then
                table.insert(block_parts, "}")
            end
            self:advance()
        elseif self:check("BLOCK_CLOSE") then
            table.insert(block_parts, "{/}")
            self:advance()
            depth = 0
        elseif self:check("ELSE") then
            table.insert(block_parts, "{else}")
            self:advance()
        elseif self:check("ELIF") then
            table.insert(block_parts, "{elif " .. self:advance().value .. "}")
        elseif self:check("PIPE") then
            table.insert(block_parts, "|")
            self:advance()
        elseif self:check("TEXT") then
            table.insert(block_parts, self:advance().value)
        elseif self:check("VAR_INTERP") then
            table.insert(block_parts, "$" .. self:advance().value)
        elseif self:check("EXPR_INTERP") then
            table.insert(block_parts, "${" .. self:advance().value .. "}")
        elseif self:check("NEWLINE") then
            table.insert(block_parts, "\n")
            self:advance()
        elseif self:check("INDENT") then
            table.insert(block_parts, self:advance().value)
        else
            self:advance()
        end
    end

    table.insert(block_parts, "}")

    return table.concat(block_parts)
end

-- Parse a literal value (for @vars)
function WSParser:parse_literal_value(str)
    str = str:match("^%s*(.-)%s*$") -- Trim

    -- Boolean
    if str == "true" then return true end
    if str == "false" then return false end

    -- String (quoted)
    local quoted = str:match('^"(.*)"$')
    if quoted then return quoted end

    -- Number
    local num = tonumber(str)
    if num then return num end

    -- Default to string
    return str
end

-- Validate passage references
function WSParser:validate_references()
    -- Build name-to-ID mapping
    local name_to_id = {}
    for passage_id, passage in pairs(self.story_data.passages) do
        if not name_to_id[passage.name] then
            name_to_id[passage.name] = passage_id
        end
    end

    -- Validate referenced passage names exist
    for passage_name, locations in pairs(self.referenced_passages) do
        if not name_to_id[passage_name] then
            -- Get a sample location for the warning
            local sample_location = locations[1] or {}
            self:add_warning("Referenced passage '" .. passage_name .. "' does not exist", {
                code = WSParser.ERROR_CODES.UNDEFINED_PASSAGE,
                suggestion = "Create a passage named '" .. passage_name .. "' or fix the link",
                token = {
                    line = sample_location.line or 1,
                    column = sample_location.column or 1
                }
            })
        end
    end
end

-- Token navigation helpers
function WSParser:peek()
    if self.current <= #self.tokens then
        return self.tokens[self.current]
    end
    return self.tokens[#self.tokens]
end

function WSParser:advance()
    if not self:is_at_end() then
        self.current = self.current + 1
    end
    return self.tokens[self.current - 1]
end

function WSParser:check(token_type)
    if self:is_at_end() then return false end
    return self:peek().type == token_type
end

function WSParser:is_at_end()
    return self:peek().type == "EOF"
end

function WSParser:skip_newlines()
    while self:check("NEWLINE") or self:check("INDENT") do
        self:advance()
    end
end

-- Error codes for parser errors
WSParser.ERROR_CODES = {
    -- Syntax errors (SYN)
    EXPECTED_PASSAGE_NAME = "WLS-SYN-001",
    EXPECTED_PASSAGE_MARKER = "WLS-SYN-002",
    EXPECTED_CHOICE_TARGET = "WLS-SYN-003",
    EXPECTED_EXPRESSION = "WLS-SYN-004",
    EXPECTED_CLOSING_BRACE = "WLS-SYN-005",
    UNEXPECTED_TOKEN = "WLS-SYN-006",
    -- Reference errors (REF)
    UNDEFINED_PASSAGE = "WLS-REF-001",
    -- Structure errors (STR)
    DUPLICATE_PASSAGE = "WLS-STR-001"
}

function WSParser:add_error(message, opts)
    opts = opts or {}
    local token = opts.token or self:peek()
    table.insert(self.errors, {
        message = message,
        code = opts.code,
        line = token.line,
        column = token.column,
        suggestion = opts.suggestion,
        severity = "error"
    })
end

function WSParser:add_warning(message, opts)
    opts = opts or {}
    local token = opts.token or self:peek()
    table.insert(self.warnings, {
        message = message,
        code = opts.code,
        line = token.line,
        column = token.column,
        suggestion = opts.suggestion,
        severity = "warning"
    })
end

-- Error recovery: skip to the next synchronization point (passage or end)
function WSParser:synchronize()
    -- Skip until we find a passage marker or EOF
    while not self:is_at_end() do
        -- If previous token was a newline and current is passage marker, we're synchronized
        local prev = self.tokens[self.current - 1]
        if prev and prev.type == "NEWLINE" and self:check("PASSAGE_MARKER") then
            return
        end
        self:advance()
    end
end

-- Skip to end of current line for minor error recovery
function WSParser:skip_to_next_line()
    while not self:is_at_end() and not self:check("NEWLINE") do
        self:advance()
    end
    if self:check("NEWLINE") then
        self:advance()
    end
end

-- Build Story object from parsed data
function WSParser:build_story()
    local Story = get_story()
    local Passage = get_passage()
    local Choice = get_choice()

    local story = Story.new()

    -- Set metadata
    story.metadata = self.story_data.metadata

    -- Set variables
    story.variables = {}
    for name, var_data in pairs(self.story_data.variables) do
        story.variables[name] = var_data.value
    end

    -- Add passages
    for _, passage_data in pairs(self.story_data.passages) do
        local passage = Passage.new({
            id = passage_data.id,
            name = passage_data.name,
            content = passage_data.content,
            tags = passage_data.tags,
            metadata = passage_data.metadata
        })

        if passage_data.on_enter_script then
            passage.on_enter_script = passage_data.on_enter_script
        end
        if passage_data.on_exit_script then
            passage.on_exit_script = passage_data.on_exit_script
        end

        -- Add choices
        for _, choice_data in ipairs(passage_data.choices) do
            local choice = Choice.new({
                text = choice_data.text,
                target = choice_data.target,
                condition = choice_data.condition,
                action = choice_data.action,
                choice_type = choice_data.choice_type
            })
            passage:add_choice(choice)
        end

        story:add_passage(passage)
    end

    -- Set start passage
    if self.story_data.start_passage then
        story:set_start_passage(self.story_data.start_passage)
    end

    return story
end

-- Static method to parse .ws file content and return Story object
function WSParser.parse_ws(input)
    local parser = WSParser.new()
    local result = parser:parse(input)

    if not result.success then
        return nil, result.errors
    end

    return parser:build_story(), result.warnings
end

return WSParser
