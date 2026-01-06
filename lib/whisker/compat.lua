--- Lua Version Compatibility Module
-- Provides compatibility shims for Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT
-- @module whisker.compat
-- @author Whisker Core Team
-- @license MIT

local compat = {
    _VERSION = "1.0.0",
    _DESCRIPTION = "Lua 5.1-5.4 compatibility layer"
}

-- ============================================================================
-- Version Detection
-- ============================================================================

--- Lua version as a number (5.1, 5.2, 5.3, 5.4)
compat.lua_version = tonumber(_VERSION:match("Lua (%d+%.%d+)")) or 5.1

--- Is this Lua 5.1?
compat.is_lua51 = compat.lua_version == 5.1

--- Is this Lua 5.2 or later?
compat.is_lua52_plus = compat.lua_version >= 5.2

--- Is this Lua 5.3 or later?
compat.is_lua53_plus = compat.lua_version >= 5.3

--- Is this Lua 5.4 or later?
compat.is_lua54_plus = compat.lua_version >= 5.4

--- Is this LuaJIT?
compat.is_luajit = type(jit) == "table"

-- ============================================================================
-- Global Function Compatibility
-- ============================================================================

--- unpack - moved to table.unpack in Lua 5.2+
compat.unpack = unpack or table.unpack

--- loadstring - renamed to load in Lua 5.2+
compat.loadstring = loadstring or load

--- setfenv/getfenv - removed in Lua 5.2+
-- These functions manipulate the environment of a function
-- In Lua 5.2+, we use the _ENV upvalue instead

if setfenv then
    -- Lua 5.1 / LuaJIT with 5.1 compat
    compat.setfenv = setfenv
    compat.getfenv = getfenv
else
    -- Lua 5.2+ - provide compatibility implementations
    -- These work with functions that have _ENV as their first upvalue

    --- Get the environment of a function (Lua 5.2+ compatible)
    -- @param fn function or call level
    -- @return table The environment table
    function compat.getfenv(fn)
        if type(fn) == "number" then
            fn = debug.getinfo(fn + 1, "f").func
        end
        local name, val
        local up = 0
        repeat
            up = up + 1
            name, val = debug.getupvalue(fn, up)
        until name == "_ENV" or name == nil
        return val or _G
    end

    --- Set the environment of a function (Lua 5.2+ compatible)
    -- @param fn function or call level
    -- @param env table The new environment
    -- @return function The function
    function compat.setfenv(fn, env)
        if type(fn) == "number" then
            fn = debug.getinfo(fn + 1, "f").func
        end
        local up = 0
        repeat
            up = up + 1
            local name = debug.getupvalue(fn, up)
        until name == "_ENV" or name == nil
        if name then
            debug.upvaluejoin(fn, up, function() return env end, 1)
        end
        return fn
    end
end

-- ============================================================================
-- Load Functions with Environment Support
-- ============================================================================

--- Load code string with optional environment (works on all Lua versions)
-- @param code string The code to load
-- @param chunkname string Optional chunk name for error messages
-- @param mode string Optional mode ("t" for text, "b" for binary, "bt" for both)
-- @param env table Optional environment table
-- @return function, string The loaded function or nil and error message
function compat.load(code, chunkname, mode, env)
    local func, err

    if compat.is_lua51 then
        -- Lua 5.1: use loadstring, then setfenv
        func, err = loadstring(code, chunkname)
        if func and env then
            setfenv(func, env)
        end
    else
        -- Lua 5.2+: load accepts env parameter directly
        func, err = load(code, chunkname, mode or "t", env)
    end

    return func, err
end

--- Load file with optional environment (works on all Lua versions)
-- @param filename string The file to load
-- @param mode string Optional mode
-- @param env table Optional environment table
-- @return function, string The loaded function or nil and error message
function compat.loadfile(filename, mode, env)
    local func, err

    if compat.is_lua51 then
        -- Lua 5.1: use loadfile, then setfenv
        func, err = loadfile(filename)
        if func and env then
            setfenv(func, env)
        end
    else
        -- Lua 5.2+: loadfile accepts env parameter directly
        func, err = loadfile(filename, mode or "t", env)
    end

    return func, err
end

-- ============================================================================
-- Bit Operations
-- ============================================================================

-- Try to get bit operations from the best available source
local band, bor, bxor, bnot, rshift, lshift, rrotate, lrotate

if compat.is_lua53_plus then
    -- Lua 5.3+: use native operators via load to avoid parse errors
    band = load("return function(a, b) return a & b end")()
    bor = load("return function(a, b) return a | b end")()
    bxor = load("return function(a, b) return a ~ b end")()
    bnot = load("return function(a) return ~a end")()
    rshift = load("return function(a, n) return a >> n end")()
    lshift = load("return function(a, n) return a << n end")()
    -- Rotate operations (useful for cryptography)
    rrotate = load("return function(a, n) return (a >> n) | (a << (32 - n)) end")()
    lrotate = load("return function(a, n) return (a << n) | (a >> (32 - n)) end")()
elseif bit32 then
    -- Lua 5.2: use bit32 library
    band = bit32.band
    bor = bit32.bor
    bxor = bit32.bxor
    bnot = bit32.bnot
    rshift = bit32.rshift
    lshift = bit32.lshift
    rrotate = bit32.rrotate
    lrotate = bit32.lrotate
elseif bit then
    -- LuaJIT: use bit library
    band = bit.band
    bor = bit.bor
    bxor = bit.bxor
    bnot = bit.bnot
    rshift = bit.rshift
    lshift = bit.lshift
    rrotate = bit.ror
    lrotate = bit.rol
else
    -- Pure Lua fallback for Lua 5.1 without bit library
    local function normalize(n)
        return n % 0x100000000
    end

    band = function(a, b)
        local result = 0
        local bit_val = 1
        for _ = 1, 32 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bit_val
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit_val = bit_val * 2
        end
        return result
    end

    bor = function(a, b)
        local result = 0
        local bit_val = 1
        for _ = 1, 32 do
            if a % 2 == 1 or b % 2 == 1 then
                result = result + bit_val
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit_val = bit_val * 2
        end
        return result
    end

    bxor = function(a, b)
        local result = 0
        local bit_val = 1
        for _ = 1, 32 do
            if (a % 2 == 1) ~= (b % 2 == 1) then
                result = result + bit_val
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit_val = bit_val * 2
        end
        return result
    end

    bnot = function(a)
        return normalize(0xFFFFFFFF - normalize(a))
    end

    rshift = function(a, n)
        return math.floor(normalize(a) / (2 ^ n))
    end

    lshift = function(a, n)
        return normalize(a * (2 ^ n))
    end

    rrotate = function(a, n)
        n = n % 32
        a = normalize(a)
        return bor(rshift(a, n), lshift(a, 32 - n))
    end

    lrotate = function(a, n)
        n = n % 32
        a = normalize(a)
        return bor(lshift(a, n), rshift(a, 32 - n))
    end
end

compat.bit = {
    band = band,
    bor = bor,
    bxor = bxor,
    bnot = bnot,
    rshift = rshift,
    lshift = lshift,
    rrotate = rrotate,
    lrotate = lrotate
}

-- ============================================================================
-- Table Functions
-- ============================================================================

--- table.pack (added in Lua 5.2)
compat.pack = table.pack or function(...)
    return { n = select("#", ...), ... }
end

--- table.move (added in Lua 5.3)
compat.move = table.move or function(a1, f, e, t, a2)
    a2 = a2 or a1
    if t > f then
        for i = e - f, 0, -1 do
            a2[t + i] = a1[f + i]
        end
    else
        for i = 0, e - f do
            a2[t + i] = a1[f + i]
        end
    end
    return a2
end

-- ============================================================================
-- String Functions
-- ============================================================================

--- string.pack (added in Lua 5.3)
-- Note: Full implementation would be complex; this is a stub
compat.string_pack = string.pack or nil

--- string.unpack (added in Lua 5.3)
compat.string_unpack = string.unpack or nil

--- string.packsize (added in Lua 5.3)
compat.string_packsize = string.packsize or nil

-- ============================================================================
-- Math Functions
-- ============================================================================

--- math.type (added in Lua 5.3)
compat.math_type = math.type or function(x)
    if type(x) ~= "number" then
        return nil
    end
    return x % 1 == 0 and "integer" or "float"
end

--- math.tointeger (added in Lua 5.3)
compat.math_tointeger = math.tointeger or function(x)
    local n = tonumber(x)
    if n and n % 1 == 0 then
        return n
    end
    return nil
end

--- math.ult (unsigned less than, added in Lua 5.3)
compat.math_ult = math.ult or function(a, b)
    -- Normalize to unsigned 64-bit
    if a < 0 then a = a + 0x10000000000000000 end
    if b < 0 then b = b + 0x10000000000000000 end
    return a < b
end

-- ============================================================================
-- UTF-8 Support (Lua 5.3+)
-- ============================================================================

-- utf8 library is only available in Lua 5.3+
compat.utf8 = utf8 or nil

-- ============================================================================
-- Coroutine Functions
-- ============================================================================

--- coroutine.isyieldable (added in Lua 5.3)
compat.isyieldable = coroutine.isyieldable or function()
    -- In Lua 5.1/5.2, we can't easily determine this
    -- Return true as a safe default (may cause errors if wrong)
    return coroutine.running() ~= nil
end

-- ============================================================================
-- Debug Functions
-- ============================================================================

--- Safely get upvalue (works across versions)
compat.getupvalue = debug.getupvalue

--- Safely set upvalue (works across versions)
compat.setupvalue = debug.setupvalue

--- debug.upvaluejoin (added in Lua 5.2)
compat.upvaluejoin = debug.upvaluejoin or nil

-- ============================================================================
-- Module Loading
-- ============================================================================

--- package.searchpath (added in Lua 5.2)
compat.searchpath = package.searchpath or function(name, path, sep, rep)
    sep = sep or "."
    rep = rep or package.config:sub(1, 1) -- directory separator
    local pname = name:gsub("%"..sep, rep)
    local msg = {}
    for template in path:gmatch("[^;]+") do
        local fpath = template:gsub("%?", pname)
        local f = io.open(fpath, "r")
        if f then
            f:close()
            return fpath
        end
        table.insert(msg, "\n\tno file '" .. fpath .. "'")
    end
    return nil, table.concat(msg)
end

-- ============================================================================
-- OS/IO Functions (version-specific behaviors)
-- ============================================================================

--- os.execute return value changed in Lua 5.2
-- In 5.1: returns status code
-- In 5.2+: returns true/nil, "exit"/"signal", status code
compat.execute = function(cmd)
    local result = os.execute(cmd)
    if compat.is_lua51 then
        return result == 0, "exit", result
    else
        return result
    end
end

-- ============================================================================
-- Warn function (Lua 5.4+)
-- ============================================================================

compat.warn = warn or function(msg, ...)
    io.stderr:write("Lua warning: ", tostring(msg), "\n")
end

-- ============================================================================
-- Install compatibility globally (optional)
-- ============================================================================

--- Install compatibility shims into global environment
-- @param options table Optional settings { unpack=true, loadstring=true, ... }
function compat.install(options)
    options = options or {}

    if options.unpack ~= false and not rawget(_G, "unpack") then
        _G.unpack = compat.unpack
    end

    if options.loadstring ~= false and not rawget(_G, "loadstring") then
        _G.loadstring = compat.loadstring
    end

    if options.setfenv ~= false and not rawget(_G, "setfenv") then
        _G.setfenv = compat.setfenv
        _G.getfenv = compat.getfenv
    end

    if options.pack ~= false and not table.pack then
        table.pack = compat.pack
    end

    if options.move ~= false and not table.move then
        table.move = compat.move
    end

    return compat
end

return compat
