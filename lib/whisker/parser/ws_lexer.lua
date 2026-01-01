-- lib/whisker/parser/ws_lexer.lua
-- WLS 1.0 .ws format tokenizer

local WSLexer = {}
WSLexer.__index = WSLexer
WSLexer._dependencies = {}

-- Token types for WLS 1.0 format
WSLexer.TOKEN = {
    -- Structure
    PASSAGE_MARKER = "PASSAGE_MARKER",  -- ::
    DIRECTIVE = "DIRECTIVE",             -- @title:, @author:, etc.
    VARS_START = "VARS_START",           -- @vars

    -- Choices (WLS 1.0)
    CHOICE_ONCE = "CHOICE_ONCE",         -- +
    CHOICE_STICKY = "CHOICE_STICKY",     -- *
    ARROW = "ARROW",                     -- ->

    -- Control flow
    BLOCK_START = "BLOCK_START",         -- {
    BLOCK_END = "BLOCK_END",             -- }
    BLOCK_CLOSE = "BLOCK_CLOSE",         -- {/}
    ELSE = "ELSE",                       -- {else}
    ELIF = "ELIF",                       -- {elif ...}
    PIPE = "PIPE",                       -- |

    -- Interpolation
    VAR_INTERP = "VAR_INTERP",           -- $varName
    EXPR_INTERP = "EXPR_INTERP",         -- ${expr}
    TEMP_VAR_INTERP = "TEMP_VAR_INTERP", -- $_varName

    -- Literals
    TEXT = "TEXT",                       -- Plain text
    STRING = "STRING",                   -- "quoted string"
    NUMBER = "NUMBER",                   -- 123, 3.14
    BOOLEAN = "BOOLEAN",                 -- true, false

    -- Comments
    LINE_COMMENT = "LINE_COMMENT",       -- //
    BLOCK_COMMENT = "BLOCK_COMMENT",     -- /* ... */

    -- Whitespace
    NEWLINE = "NEWLINE",
    INDENT = "INDENT",

    -- Special
    EOF = "EOF"
}

function WSLexer.new(deps)
    deps = deps or {}
    local instance = {
        input = "",
        position = 1,
        line = 1,
        column = 1,
        tokens = {},
        errors = {}
    }
    setmetatable(instance, WSLexer)
    return instance
end

function WSLexer:tokenize(input)
    self.input = input or ""
    self.position = 1
    self.line = 1
    self.column = 1
    self.tokens = {}
    self.errors = {}

    if self.input == "" then
        self:add_token(WSLexer.TOKEN.EOF, "")
        return {
            success = true,
            tokens = self.tokens,
            errors = {}
        }
    end

    while self.position <= #self.input do
        self:scan_token()
    end

    self:add_token(WSLexer.TOKEN.EOF, "")

    return {
        success = #self.errors == 0,
        tokens = self.tokens,
        errors = self.errors
    }
end

function WSLexer:scan_token()
    local char = self:peek()
    local remaining = self.input:sub(self.position)

    -- Passage marker ::
    if remaining:match("^::") then
        self:advance(2)
        self:add_token(WSLexer.TOKEN.PASSAGE_MARKER, "::")
        return
    end

    -- Line comment //
    if remaining:match("^//") then
        local comment = remaining:match("^//[^\r\n]*")
        self:advance(#comment)
        -- Skip comments (don't add token)
        return
    end

    -- Block comment /* ... */
    if remaining:match("^/%*") then
        local comment = remaining:match("^/%*.-%*/")
        if comment then
            -- Count newlines in comment
            for _ in comment:gmatch("\n") do
                self.line = self.line + 1
            end
            self:advance(#comment)
            -- Skip comments
            return
        else
            self:add_error("Unterminated block comment")
            self:advance(2)
            return
        end
    end

    -- Arrow ->
    if remaining:match("^%->") then
        self:advance(2)
        self:add_token(WSLexer.TOKEN.ARROW, "->")
        return
    end

    -- Directives starting with @
    if char == "@" then
        self:scan_directive()
        return
    end

    -- Block close {/}
    if remaining:match("^{/}") then
        self:advance(3)
        self:add_token(WSLexer.TOKEN.BLOCK_CLOSE, "{/}")
        return
    end

    -- Else block {else}
    if remaining:match("^{else}") then
        self:advance(6)
        self:add_token(WSLexer.TOKEN.ELSE, "{else}")
        return
    end

    -- Elif block {elif ...}
    local elif_match = remaining:match("^{elif%s+([^}]+)}")
    if elif_match then
        local full = remaining:match("^{elif%s+[^}]+}")
        self:advance(#full)
        self:add_token(WSLexer.TOKEN.ELIF, elif_match)
        return
    end

    -- Expression interpolation ${expr}
    if remaining:match("^%${") then
        local expr = remaining:match("^%${([^}]+)}")
        if expr then
            self:advance(#expr + 3) -- ${ + expr + }
            self:add_token(WSLexer.TOKEN.EXPR_INTERP, expr)
            return
        end
    end

    -- Temp variable interpolation $_varName
    if remaining:match("^%$_[%a_][%w_]*") then
        local var = remaining:match("^%$(_[%a_][%w_]*)")
        self:advance(#var + 1) -- $ + varName
        self:add_token(WSLexer.TOKEN.TEMP_VAR_INTERP, var)
        return
    end

    -- Variable interpolation $varName
    if remaining:match("^%$[%a_][%w_]*") then
        local var = remaining:match("^%$([%a_][%w_]*)")
        self:advance(#var + 1) -- $ + varName
        self:add_token(WSLexer.TOKEN.VAR_INTERP, var)
        return
    end

    -- Unmatched $ (e.g., $1invalid, standalone $) - treat as text
    if char == "$" then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.TEXT, "$")
        return
    end

    -- Choice markers at start of line (after optional whitespace)
    if char == "+" and self:is_choice_context() then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.CHOICE_ONCE, "+")
        return
    end

    if char == "*" and self:is_choice_context() then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.CHOICE_STICKY, "*")
        return
    end

    -- Block delimiters
    if char == "{" then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.BLOCK_START, "{")
        return
    end

    if char == "}" then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.BLOCK_END, "}")
        return
    end

    if char == "|" then
        self:advance(1)
        self:add_token(WSLexer.TOKEN.PIPE, "|")
        return
    end

    -- Newline
    if char == "\n" then
        self:advance(1)
        self.line = self.line + 1
        self.column = 1
        self:add_token(WSLexer.TOKEN.NEWLINE, "\n")
        return
    end

    if char == "\r" then
        self:advance(1)
        if self:peek() == "\n" then
            self:advance(1)
        end
        self.line = self.line + 1
        self.column = 1
        self:add_token(WSLexer.TOKEN.NEWLINE, "\n")
        return
    end

    -- Whitespace/indent at start of line
    if (char == " " or char == "\t") and self.column == 1 then
        local indent = remaining:match("^[ \t]+")
        self:advance(#indent)
        self:add_token(WSLexer.TOKEN.INDENT, indent)
        return
    end

    -- Quoted string
    if char == '"' then
        self:scan_string()
        return
    end

    -- Number
    if char:match("%d") then
        local num = remaining:match("^%d+%.?%d*")
        self:advance(#num)
        self:add_token(WSLexer.TOKEN.NUMBER, num)
        return
    end

    -- Text (everything else until a special character)
    self:scan_text()
end

function WSLexer:scan_directive()
    local remaining = self.input:sub(self.position)

    -- Check for @vars block
    if remaining:match("^@vars%s*[\r\n]") then
        self:advance(5) -- @vars
        self:add_token(WSLexer.TOKEN.VARS_START, "@vars")
        return
    end

    -- Regular directive @name: value
    local directive = remaining:match("^@([%a_][%w_]*):%s*([^\r\n]*)")
    if directive then
        local name = remaining:match("^@([%a_][%w_]*):")
        local full_match = remaining:match("^@[%a_][%w_]*:%s*[^\r\n]*")
        local value = remaining:match("^@[%a_][%w_]*:%s*([^\r\n]*)")
        self:advance(#full_match)
        self:add_token(WSLexer.TOKEN.DIRECTIVE, { name = name, value = value:match("^(.-)%s*$") })
        return
    end

    -- Unknown directive - treat as text
    self:advance(1)
    self:add_token(WSLexer.TOKEN.TEXT, "@")
end

function WSLexer:scan_string()
    self:advance(1) -- Skip opening quote
    local str = ""

    while self.position <= #self.input and self:peek() ~= '"' do
        local char = self:peek()
        if char == "\\" then
            self:advance(1)
            local escape = self:peek()
            if escape == "n" then
                str = str .. "\n"
            elseif escape == "t" then
                str = str .. "\t"
            elseif escape == '"' then
                str = str .. '"'
            elseif escape == "\\" then
                str = str .. "\\"
            else
                str = str .. escape
            end
            self:advance(1)
        elseif char == "\n" then
            self:add_error("Unterminated string")
            break
        else
            str = str .. char
            self:advance(1)
        end
    end

    if self:peek() == '"' then
        self:advance(1) -- Skip closing quote
    end

    self:add_token(WSLexer.TOKEN.STRING, str)
end

function WSLexer:scan_text()
    local text = ""
    local stop_chars = "{}|$@\r\n\""

    while self.position <= #self.input do
        local char = self:peek()
        local remaining = self.input:sub(self.position)

        -- Stop at special sequences
        if remaining:match("^::") or
           remaining:match("^%->") or
           remaining:match("^//") or
           remaining:match("^/%*") then
            break
        end

        -- Stop at special chars
        if stop_chars:find(char, 1, true) then
            break
        end

        -- Stop at choice markers if at line start context
        if (char == "+" or char == "*") and self:is_choice_context() then
            break
        end

        text = text .. char
        self:advance(1)
    end

    -- Only create TEXT token if it contains non-whitespace
    -- This prevents spaces between structural tokens from becoming separate TEXT tokens
    -- while still preserving spaces within prose content
    if #text > 0 and text:match("%S") then
        self:add_token(WSLexer.TOKEN.TEXT, text)
    end
end

function WSLexer:is_choice_context()
    -- Check if we're at the start of a line (after optional whitespace)
    -- by looking at the previous token
    if #self.tokens == 0 then
        return true
    end

    local prev = self.tokens[#self.tokens]
    return prev.type == WSLexer.TOKEN.NEWLINE or
           prev.type == WSLexer.TOKEN.INDENT or
           prev.type == WSLexer.TOKEN.BLOCK_END or
           prev.type == WSLexer.TOKEN.BLOCK_CLOSE or
           prev.type == WSLexer.TOKEN.ELSE
end

function WSLexer:peek(offset)
    offset = offset or 0
    local pos = self.position + offset
    if pos <= #self.input then
        return self.input:sub(pos, pos)
    end
    return ""
end

function WSLexer:advance(count)
    count = count or 1
    for _ = 1, count do
        if self.position <= #self.input then
            self.column = self.column + 1
            self.position = self.position + 1
        end
    end
end

function WSLexer:add_token(token_type, value)
    table.insert(self.tokens, {
        type = token_type,
        value = value,
        line = self.line,
        column = self.column,
        position = self.position
    })
end

function WSLexer:add_error(message)
    table.insert(self.errors, {
        message = message,
        line = self.line,
        column = self.column,
        position = self.position
    })
end

return WSLexer
