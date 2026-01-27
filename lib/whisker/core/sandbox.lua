-- lib/whisker/core/sandbox.lua
-- Complete sandboxing for Lua script execution
-- WLS 1.0 GAP-074: Complete sandboxing for safe script execution

local Sandbox = {}
Sandbox.__index = Sandbox

-- Default resource limits
Sandbox.DEFAULT_LIMITS = {
    max_instructions = 1000000,      -- 1M instructions
    max_memory_kb = 10240,           -- 10MB
    max_string_length = 1000000,     -- 1MB string
    max_table_size = 100000,         -- 100K entries
    max_call_depth = 100,            -- 100 nested calls
    timeout_seconds = 5              -- 5 second timeout
}

--- Create a new Sandbox instance
---@param options table|nil Options to override default limits
---@return Sandbox
function Sandbox.new(options)
    local self = setmetatable({}, Sandbox)
    self.limits = {}
    for k, v in pairs(Sandbox.DEFAULT_LIMITS) do
        self.limits[k] = (options and options[k]) or v
    end
    self.instruction_count = 0
    self.start_time = nil
    self.call_depth = 0
    self.hooks_installed = false
    return self
end

--- Create a safe execution environment
---@return table Safe environment
function Sandbox:create_safe_environment()
    local env = {}
    local limits = self.limits

    -- Safe globals
    env._VERSION = _VERSION
    env.type = type
    env.tostring = tostring
    env.tonumber = tonumber
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.select = select
    env.unpack = unpack or table.unpack
    env.pcall = pcall
    env.xpcall = xpcall
    env.error = error
    env.assert = assert
    env.rawequal = rawequal
    env.rawget = rawget
    env.rawset = rawset
    env.print = print  -- Allow print for debugging

    -- Helper to create blocked function stub
    local function blocked_stub(name)
        return function()
            error("Function '" .. name .. "' is not available in Whisker scripts for security reasons", 2)
        end
    end

    -- Blocked functions with helpful error messages
    env.loadstring = blocked_stub("loadstring")
    env.loadfile = blocked_stub("loadfile")
    env.dofile = blocked_stub("dofile")
    env.load = blocked_stub("load")
    env.require = blocked_stub("require")
    env.collectgarbage = blocked_stub("collectgarbage")
    env.module = blocked_stub("module")

    -- Safe getmetatable (returns nil for non-tables)
    env.getmetatable = function(obj)
        if type(obj) == "table" then
            return getmetatable(obj)
        end
        return nil
    end

    -- Safe setmetatable (only works on tables)
    env.setmetatable = function(t, mt)
        if type(t) ~= "table" then
            error("setmetatable can only be used on tables", 2)
        end
        return setmetatable(t, mt)
    end

    -- Blocked modules with metatables for helpful errors
    env.io = setmetatable({}, {
        __index = function(_, key)
            error("Module 'io' is not available in Whisker scripts for security reasons", 2)
        end
    })
    env.debug = setmetatable({}, {
        __index = function(_, key)
            error("Module 'debug' is not available in Whisker scripts for security reasons", 2)
        end
    })
    env.package = setmetatable({}, {
        __index = function(_, key)
            error("Module 'package' is not available in Whisker scripts for security reasons", 2)
        end
    })

    -- NOT allowed: rawlen (not always available anyway)

    -- Safe math library
    env.math = {
        abs = math.abs,
        acos = math.acos,
        asin = math.asin,
        atan = math.atan,
        atan2 = math.atan2,
        ceil = math.ceil,
        cos = math.cos,
        deg = math.deg,
        exp = math.exp,
        floor = math.floor,
        fmod = math.fmod,
        huge = math.huge,
        log = math.log,
        log10 = math.log10,
        max = math.max,
        min = math.min,
        modf = math.modf,
        pi = math.pi,
        pow = math.pow,
        rad = math.rad,
        random = math.random,
        sin = math.sin,
        sqrt = math.sqrt,
        tan = math.tan
        -- NOT allowed: randomseed (don't allow seeding for reproducibility)
    }

    -- Safe string library with limits
    local max_string = limits.max_string_length
    env.string = {
        byte = string.byte,
        char = string.char,
        find = string.find,
        gmatch = string.gmatch,
        gsub = function(s, pattern, repl, n)
            if type(s) ~= "string" then
                error("bad argument #1 to 'gsub' (string expected)", 2)
            end
            if #s > max_string then
                error("String too long for gsub operation", 2)
            end
            return string.gsub(s, pattern, repl, n)
        end,
        len = string.len,
        lower = string.lower,
        match = string.match,
        rep = function(s, n)
            if type(s) ~= "string" then
                error("bad argument #1 to 'rep' (string expected)", 2)
            end
            if type(n) ~= "number" then
                error("bad argument #2 to 'rep' (number expected)", 2)
            end
            if #s * n > max_string then
                error("Result string would be too long", 2)
            end
            return string.rep(s, n)
        end,
        reverse = string.reverse,
        sub = string.sub,
        upper = string.upper,
        format = function(formatstring, ...)
            -- Limited format to prevent format string attacks
            if type(formatstring) ~= "string" then
                error("bad argument #1 to 'format' (string expected)", 2)
            end
            -- Disallow %s with very large strings
            local result = string.format(formatstring, ...)
            if #result > max_string then
                error("Formatted string too long", 2)
            end
            return result
        end
        -- NOT allowed: dump (can dump functions)
    }

    -- Safe table library
    local max_table = limits.max_table_size
    env.table = {
        concat = table.concat,
        insert = function(t, ...)
            local args = {...}
            local size = 0
            for _ in pairs(t) do
                size = size + 1
            end
            if size >= max_table then
                error("Table size limit exceeded", 2)
            end
            return table.insert(t, ...)
        end,
        remove = table.remove,
        sort = table.sort,
        unpack = table.unpack
        -- NOT allowed: move, pack (not always available and can be abused)
    }

    -- Limited os library (time functions only)
    env.os = {
        time = os.time,
        date = os.date,
        difftime = os.difftime,
        clock = os.clock,
        -- Blocked os functions with helpful errors
        execute = blocked_stub("os.execute"),
        exit = blocked_stub("os.exit"),
        getenv = blocked_stub("os.getenv"),
        remove = blocked_stub("os.remove"),
        rename = blocked_stub("os.rename"),
        setlocale = blocked_stub("os.setlocale"),
        tmpname = blocked_stub("os.tmpname")
    }

    -- NOT allowed: io (no file access)
    -- NOT allowed: package, require (no module loading)
    -- NOT allowed: debug (no debugging/introspection)
    -- NOT allowed: coroutine (complex to sandbox properly)

    return env
end

--- Install debug hooks for resource limiting
---@param env table Execution environment
function Sandbox:install_hooks(env)
    local sandbox = self
    local limits = self.limits

    -- Instruction count hook
    local function instruction_hook()
        sandbox.instruction_count = sandbox.instruction_count + 1

        if sandbox.instruction_count > limits.max_instructions then
            error("Instruction limit exceeded (" .. limits.max_instructions .. " instructions)", 2)
        end

        -- Check timeout
        if sandbox.start_time then
            local elapsed = os.clock() - sandbox.start_time
            if elapsed > limits.timeout_seconds then
                error("Execution timeout (" .. limits.timeout_seconds .. " seconds)", 2)
            end
        end
    end

    -- Install debug hook for instruction counting
    -- Note: This requires debug library access in the host
    if debug and debug.sethook then
        -- Hook every N instructions to reduce overhead
        local hook_interval = math.floor(limits.max_instructions / 100)
        if hook_interval < 1 then hook_interval = 1 end
        debug.sethook(instruction_hook, "", hook_interval)
        self.hooks_installed = true
    end
end

--- Clear installed hooks
function Sandbox:clear_hooks()
    if self.hooks_installed and debug and debug.sethook then
        debug.sethook()
        self.hooks_installed = false
    end
end

--- Execute code in sandbox
---@param code string Lua code to execute
---@param env table|nil Additional environment entries to merge
---@return any|nil result
---@return string|nil error
function Sandbox:execute(code, env)
    -- Reset counters
    self.instruction_count = 0
    self.start_time = os.clock()
    self.call_depth = 0

    -- Create safe environment
    local safe_env = self:create_safe_environment()

    -- Merge with user-provided environment
    if env then
        for k, v in pairs(env) do
            safe_env[k] = v
        end
    end

    -- Compile code
    local func, compile_err = load(code, "sandbox", "t", safe_env)
    if not func then
        return nil, "Compilation error: " .. tostring(compile_err)
    end

    -- Install hooks
    self:install_hooks(safe_env)

    -- Execute
    local success, result = pcall(func)

    -- Clear hooks
    self:clear_hooks()

    if not success then
        return nil, "Runtime error: " .. tostring(result)
    end

    return result
end

--- Evaluate an expression in sandbox
---@param expression string Expression to evaluate
---@param env table|nil Additional environment entries
---@return any|nil result
---@return string|nil error
function Sandbox:eval(expression, env)
    return self:execute("return " .. expression, env)
end

--- Check if code is safe to execute (basic static analysis)
---@param code string Code to check
---@return boolean is_safe
---@return table|nil issues Array of potential issues
function Sandbox:analyze(code)
    local issues = {}

    -- Check for dangerous patterns
    local dangerous_patterns = {
        { pattern = "loadstring", message = "Use of loadstring is not allowed" },
        { pattern = "loadfile", message = "Use of loadfile is not allowed" },
        { pattern = "dofile", message = "Use of dofile is not allowed" },
        { pattern = "io%.", message = "Use of io library is not allowed" },
        { pattern = "os%.execute", message = "Use of os.execute is not allowed" },
        { pattern = "os%.remove", message = "Use of os.remove is not allowed" },
        { pattern = "os%.rename", message = "Use of os.rename is not allowed" },
        { pattern = "debug%.", message = "Use of debug library is not allowed" },
        { pattern = "package%.", message = "Use of package library is not allowed" },
        { pattern = "require%s*%(", message = "Use of require is not allowed" },
        { pattern = "setmetatable", message = "Use of setmetatable is not allowed" },
        { pattern = "getmetatable", message = "Use of getmetatable is not allowed" },
        { pattern = "rawset", message = "Use of rawset may be restricted" },
        { pattern = "collectgarbage", message = "Use of collectgarbage is not allowed" },
    }

    for _, pattern_info in ipairs(dangerous_patterns) do
        if code:match(pattern_info.pattern) then
            table.insert(issues, {
                pattern = pattern_info.pattern,
                message = pattern_info.message
            })
        end
    end

    return #issues == 0, issues
end

--- Get current resource usage
---@return table Usage statistics
function Sandbox:get_usage()
    return {
        instructions = self.instruction_count,
        max_instructions = self.limits.max_instructions,
        elapsed_time = self.start_time and (os.clock() - self.start_time) or 0,
        timeout = self.limits.timeout_seconds
    }
end

--- Update limits
---@param new_limits table New limit values
function Sandbox:set_limits(new_limits)
    for k, v in pairs(new_limits) do
        if self.limits[k] ~= nil then
            self.limits[k] = v
        end
    end
end

--- Get current limits
---@return table Current limits
function Sandbox:get_limits()
    local copy = {}
    for k, v in pairs(self.limits) do
        copy[k] = v
    end
    return copy
end

return Sandbox
