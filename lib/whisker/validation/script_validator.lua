--- Script Validator - Static analysis of Lua script blocks
-- WLS 1.0 Gap 26: Script Errors (SCR)
-- @module whisker.validation.script_validator

local ScriptValidator = {}
ScriptValidator.__index = ScriptValidator

local compat = require("whisker.vendor.compat")

--- Forbidden functions (security/safety)
ScriptValidator.FORBIDDEN_FUNCTIONS = {
    -- File system
    "io.open", "io.popen", "io.input", "io.output",
    "os.execute", "os.remove", "os.rename", "os.exit",
    -- Module loading
    "dofile", "loadfile", "require", "module",
    -- Dangerous
    "rawset", "rawget", "rawequal",
    "setfenv", "getfenv",
    "setmetatable",  -- Can be allowed in some contexts
    "collectgarbage",
    "newproxy",
}

--- Potentially problematic patterns
ScriptValidator.RISKY_PATTERNS = {
    { pattern = "while%s+true", message = "Infinite loop risk" },
    { pattern = "for%s+[^,]+%s*=%s*1%s*,%s*math%.huge", message = "Infinite loop risk" },
    { pattern = "repeat%s+until%s+false", message = "Infinite loop risk" },
}

--- Error codes
ScriptValidator.ERROR_CODES = {
    SYNTAX_ERROR = "WLS-SCR-001",
    UNDEFINED_VAR = "WLS-SCR-002",
    FORBIDDEN_CALL = "WLS-SCR-003",
    TIMEOUT_RISK = "WLS-SCR-004",
}

--- Create new script validator
---@param config table Configuration options
---@return table ScriptValidator instance
function ScriptValidator.new(config)
    local self = setmetatable({}, ScriptValidator)
    config = config or {}
    self.config = config
    self.allowed_functions = config.allowed_functions or {}
    return self
end

--- Validate a script block
---@param script string Script content
---@param location table|nil Source location
---@return table diagnostics
function ScriptValidator:validate(script, location)
    local diagnostics = {}

    if not script or script == "" then
        return diagnostics
    end

    -- Check syntax
    local syntax_err = self:check_syntax(script)
    if syntax_err then
        table.insert(diagnostics, {
            code = self.ERROR_CODES.SYNTAX_ERROR,
            message = "Lua syntax error: " .. syntax_err,
            severity = "error",
            location = location
        })
        return diagnostics  -- Don't continue if syntax is invalid
    end

    -- Check for forbidden functions
    local forbidden = self:find_forbidden_calls(script)
    for _, call in ipairs(forbidden) do
        table.insert(diagnostics, {
            code = self.ERROR_CODES.FORBIDDEN_CALL,
            message = string.format('Forbidden function call: %s', call),
            severity = "error",
            location = location,
            suggestion = "This function is not allowed in story scripts"
        })
    end

    -- Check for risky patterns
    local risks = self:find_risky_patterns(script)
    for _, risk in ipairs(risks) do
        table.insert(diagnostics, {
            code = self.ERROR_CODES.TIMEOUT_RISK,
            message = risk.message,
            severity = "warning",
            location = location,
            suggestion = "Consider adding a termination condition"
        })
    end

    -- Check for undefined variables (best-effort)
    local undefined = self:find_undefined_variables(script)
    for _, var in ipairs(undefined) do
        table.insert(diagnostics, {
            code = self.ERROR_CODES.UNDEFINED_VAR,
            message = string.format('Possibly undefined variable: %s', var),
            severity = "warning",
            location = location
        })
    end

    return diagnostics
end

--- Check Lua syntax
---@param script string
---@return string|nil error message
function ScriptValidator:check_syntax(script)
    -- Try to compile the script
    local chunk, err = compat.loadstring(script, "script")
    if not chunk then
        -- Extract meaningful error message
        local msg = err:gsub("^%[string \"script\"%]:%d+:", "")
        return msg:match("^%s*(.-)%s*$")  -- trim
    end
    return nil
end

--- Find forbidden function calls
---@param script string
---@return table function names
function ScriptValidator:find_forbidden_calls(script)
    local found = {}

    for _, func in ipairs(self.FORBIDDEN_FUNCTIONS) do
        -- Check if function is explicitly allowed
        if not self.allowed_functions[func] then
            -- Look for function call pattern
            local pattern = func:gsub("%.", "%%.")
            if script:match(pattern .. "%s*%(") or
               script:match(pattern .. "%s*{") then
                table.insert(found, func)
            end
        end
    end

    return found
end

--- Find risky patterns
---@param script string
---@return table risks
function ScriptValidator:find_risky_patterns(script)
    local found = {}

    for _, risk in ipairs(self.RISKY_PATTERNS) do
        if script:match(risk.pattern) then
            table.insert(found, risk)
        end
    end

    return found
end

--- Find potentially undefined variables (heuristic)
---@param script string
---@return table variable names
function ScriptValidator:find_undefined_variables(script)
    local found = {}
    local defined = {}

    -- Track local definitions
    for var in script:gmatch("local%s+([%a_][%w_]*)") do
        defined[var] = true
    end

    -- Track function parameters (simple pattern)
    for params in script:gmatch("function%s*%b()") do
        for param in params:gmatch("([%a_][%w_]*)") do
            defined[param] = true
        end
    end

    -- Track for loop variables
    for var in script:gmatch("for%s+([%a_][%w_]*)%s*=") do
        defined[var] = true
    end
    for var in script:gmatch("for%s+([%a_][%w_]*)%s*,?[^i]*in") do
        defined[var] = true
    end

    -- Well-known globals
    local globals = {
        "whisker", "print", "tostring", "tonumber", "type",
        "pairs", "ipairs", "next", "select", "unpack",
        "math", "string", "table", "os", "io",
        "true", "false", "nil",
        "visited", "pick", "random",
        "error", "assert", "pcall", "xpcall",
        "coroutine", "debug", "package",
        "_G", "_VERSION",
    }
    for _, g in ipairs(globals) do
        defined[g] = true
    end

    -- Keywords to skip
    local keywords = {
        "if", "then", "else", "elseif", "end",
        "for", "while", "do", "repeat", "until",
        "function", "return", "local", "and", "or", "not",
        "break", "goto", "in",
    }
    for _, k in ipairs(keywords) do
        defined[k] = true
    end

    -- Note: This is a simplified heuristic and won't catch everything
    -- We skip undefined variable detection in this version to avoid false positives

    return found
end

return ScriptValidator
