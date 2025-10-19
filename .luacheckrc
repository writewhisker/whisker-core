-- Luacheck configuration for Whisker
std = "lua54"

-- Ignore warnings about line length
codes = true
max_line_length = 130

-- Global variables that are okay to use
globals = {
    "love",  -- LÖVE framework
    "js",    -- Fengari JS interop
}

-- Read-only globals
read_globals = {
    "love",
    "js",
    "window",
    "localStorage",
    "unpack",  -- Lua 5.1 compatibility
}

-- Exclude certain warnings
ignore = {
    "113",  -- Accessing undefined variable (self, globals in runtime)
    "142",  -- Setting undefined field (monkey-patching string, table)
    "211",  -- Unused variable
    "212",  -- Unused argument
    "213",  -- Unused loop variable
    "411",  -- Redefining variable
    "421",  -- Shadowing definition
    "431",  -- Shadowing upvalue
    "512",  -- Loop executed at most once
    "542",  -- Empty if branch
    "612",  -- Trailing whitespace
    "613",  -- Trailing whitespace in string
    "631",  -- Line too long
}

-- Exclude build and vendor directories
exclude_files = {
    "build/",
    "dist/",
    "vendor/",
    ".luarocks/",
}
