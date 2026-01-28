-- Luacheck configuration for Whisker
-- See docs/MODULARITY_GUIDE.md for modularity patterns
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
    "111",  -- Setting non-standard global variable
    "112",  -- Mutating non-standard global variable
    "113",  -- Accessing undefined variable (self, globals in runtime)
    "121",  -- Setting read-only global variable
    "122",  -- Setting read-only field
    "142",  -- Setting undefined field (monkey-patching string, table)
    "211",  -- Unused variable
    "212",  -- Unused argument
    "213",  -- Unused loop variable
    "221",  -- Variable never set
    "231",  -- Variable never accessed
    "241",  -- Variable mutated but never accessed
    "311",  -- Value assigned is unused
    "312",  -- Value of argument is unused
    "411",  -- Redefining variable
    "421",  -- Shadowing definition
    "431",  -- Shadowing upvalue
    "432",  -- Shadowing upvalue argument
    "512",  -- Loop executed at most once
    "511",  -- Unreachable code (intentional infinite loops)
    "542",  -- Empty if branch
    "581",  -- Negation simplification
    "611",  -- Line contains only whitespace
    "612",  -- Trailing whitespace
    "613",  -- Trailing whitespace in string
    "614",  -- Trailing whitespace in comment
    "631",  -- Line too long
}

-- Exclude build and vendor directories
exclude_files = {
    "build/",
    "dist/",
    "vendor/",
    ".luarocks/",
    "**/vendor/**",  -- Vendor code anywhere in tree
    "lib/whisker/vendor/tinta/**",  -- Tinta vendor source
    "lib/whisker/twine/export/format_template_provider.lua",  -- Contains embedded JS with [[ ]] patterns
}

-- =============================================================================
-- Modularity Configuration
-- =============================================================================
-- These settings help enforce the DI (Dependency Injection) pattern.
-- See tools/validate_modularity.lua for full modularity validation.

-- File-specific overrides for modularity
files = {
    -- Kernel files can access more globals during bootstrap
    ["lib/whisker/kernel/*.lua"] = {
        ignore = { "111", "112", "113" },
    },

    -- Test files have relaxed rules
    ["tests/**/*.lua"] = {
        std = "+busted",
        globals = {
            "describe",
            "it",
            "before_each",
            "after_each",
            "setup",
            "teardown",
            "pending",
            "spy",
            "stub",
            "mock",
            "match",
            "assert",
            "finally",
            "lazy_setup",
            "lazy_teardown",
        },
    },

    -- Testing library can register custom matchers
    ["lib/whisker/testing/matchers.lua"] = {
        globals = {
            "assert",
        },
        ignore = { "143" },  -- Accessing undefined field of global (assert.register)
    },

    -- Tools have relaxed rules
    ["tools/*.lua"] = {
        ignore = { "113" },  -- Tools may use os, io, arg globals
    },

    -- Bin scripts can use globals
    ["bin/*.lua"] = {
        ignore = { "111", "112", "113" },
    },
}
