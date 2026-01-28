# Lua Version Compatibility

Whisker Core is designed to work across multiple Lua versions. This document describes the compatibility status and any known limitations.

## Supported Lua Versions

| Version | Status | Notes |
|---------|--------|-------|
| Lua 5.4 | **Fully Supported** | Primary development target |
| Lua 5.3 | **Fully Supported** | All features available |
| Lua 5.2 | Supported | Uses `bit32` library for bitwise operations |
| Lua 5.1 | Partial Support | Some features may have different behavior |
| LuaJIT | Partial Support | Based on Lua 5.1 with extensions |

## Version Detection

The codebase provides utilities for detecting the Lua version at runtime:

### In Production Code

Use the compatibility module:

```lua
local compat = require("whisker.vendor.compat")

-- Version detection
print(compat.lua_version)       -- e.g., 5.4
print(compat.is_lua51)          -- true if Lua 5.1
print(compat.is_lua53_plus)     -- true if Lua 5.3 or later
print(compat.is_luajit)         -- true if LuaJIT

-- Cross-version bitwise operations
local bxor = compat.bit.bxor
local result = bxor(0xFF, 0x0F)  -- Works on all versions
```

### In Test Code

Use the test helper:

```lua
local LuaVersion = require("tests.helpers.lua_version")

-- Version checks
if LuaVersion.is_53_plus then
  -- Use Lua 5.3+ features
end

-- Skip tests on specific versions
describe("feature requiring Lua 5.3+", function()
  it("uses native bitwise operators", function()
    if not LuaVersion.skip_below(5.3, "native bitwise operators") then
      return
    end
    -- Test code here
  end)
end)

-- Skip on LuaJIT
it("timing-sensitive test", function()
  if not LuaVersion.skip_on_luajit("JIT compilation affects timing") then
    return
  end
  -- Test code here
end)
```

## Feature Availability by Version

### Bitwise Operations

| Feature | 5.1 | 5.2 | 5.3+ | LuaJIT |
|---------|-----|-----|------|--------|
| Native operators (`&`, `|`, `~`, `>>`, `<<`) | No | No | Yes | No |
| `bit32` library | No | Yes | Deprecated | No |
| `bit` library | No* | No | No | Yes |
| `compat.bit.*` functions | Yes | Yes | Yes | Yes |

*Lua 5.1 requires external bit library or uses pure Lua fallback.

**Recommendation:** Always use `compat.bit.*` functions for cross-version compatibility.

```lua
local compat = require("whisker.vendor.compat")
local band = compat.bit.band
local bor = compat.bit.bor
local bxor = compat.bit.bxor
local bnot = compat.bit.bnot
local rshift = compat.bit.rshift
local lshift = compat.bit.lshift
```

### UTF-8 Support

| Feature | 5.1 | 5.2 | 5.3+ | LuaJIT |
|---------|-----|-----|------|--------|
| `utf8` library | No | No | Yes | No |
| `compat.utf8` | No | No | Yes | No |

### Table Functions

| Feature | 5.1 | 5.2 | 5.3+ | LuaJIT |
|---------|-----|-----|------|--------|
| `table.pack` | No | Yes | Yes | No |
| `table.unpack` | No* | Yes | Yes | No* |
| `table.move` | No | No | Yes | No |
| `compat.pack` | Yes | Yes | Yes | Yes |
| `compat.move` | Yes | Yes | Yes | Yes |

*Lua 5.1 and LuaJIT have global `unpack` instead.

### Environment Functions

| Feature | 5.1 | 5.2+ | LuaJIT |
|---------|-----|------|--------|
| `setfenv` / `getfenv` | Yes | No | Yes |
| `_ENV` upvalue | No | Yes | No |
| `compat.setfenv` / `compat.getfenv` | Yes | Yes | Yes |

### Load Functions

| Feature | 5.1 | 5.2+ | LuaJIT |
|---------|-----|------|--------|
| `loadstring` | Yes | Deprecated | Yes |
| `load` with env param | No | Yes | No |
| `compat.load` | Yes | Yes | Yes |

## Known Limitations

### Lua 5.1

- No native bitwise operators
- No `utf8` library
- No integer division operator (`//`)
- `loadstring` instead of `load` with env parameter
- `setfenv`/`getfenv` available (removed in 5.2+)
- `unpack` is global (moved to `table.unpack` in 5.2+)
- JSON encoding order may differ from 5.3+

### Lua 5.2

- No native bitwise operators (use `bit32` library)
- No `utf8` library
- No integer division operator (`//`)
- `bit32` library available for bitwise operations

### LuaJIT

- Based on Lua 5.1 with extensions
- Uses `bit` library for bitwise operations (not `bit32`)
- JIT compilation may affect timing-sensitive tests
- FFI available for C interop
- Some table iteration ordering differences

## Writing Compatible Code

### DO: Use the Compatibility Module

```lua
local compat = require("whisker.vendor.compat")

-- Bitwise operations
local bxor = compat.bit.bxor
local result = bxor(a, b)

-- Table operations
local packed = compat.pack(...)
compat.move(src, 1, #src, 1, dst)

-- Load with environment
local fn = compat.load(code, "chunk", "t", env)
```

### DON'T: Use Version-Specific Features Directly

```lua
-- BAD: Will fail on Lua 5.1/5.2
local result = a ~ b

-- GOOD: Works on all versions
local compat = require("whisker.vendor.compat")
local result = compat.bit.bxor(a, b)
```

### Conditional Code

When you must use version-specific features:

```lua
local compat = require("whisker.vendor.compat")

if compat.is_lua53_plus then
  -- Use native operators via load() to avoid parse errors
  local native_xor = load("return function(a, b) return a ~ b end")()
  result = native_xor(a, b)
else
  result = compat.bit.bxor(a, b)
end
```

## CI Configuration

The CI workflow tests against multiple Lua versions:

```yaml
matrix:
  lua-version: ['5.1', '5.2', '5.3', '5.4', 'luajit']
```

### Expected CI Results

- **Lua 5.3, 5.4**: All tests should pass
- **Lua 5.2**: All tests should pass (uses `bit32`)
- **Lua 5.1, LuaJIT**: Most tests pass; some may be skipped or have known differences

## Updating Version-Conditional Tests

When a test must behave differently on certain Lua versions:

```lua
local LuaVersion = require("tests.helpers.lua_version")

describe("my feature", function()
  it("works on Lua 5.3+", function()
    -- Skip test on older versions
    if not LuaVersion.skip_below(5.3, "feature name") then
      return
    end

    -- Test code that requires Lua 5.3+
  end)

  it("has alternative behavior on Lua 5.1", function()
    if LuaVersion.is_51 or LuaVersion.is_luajit then
      -- Test the fallback behavior
    else
      -- Test the standard behavior
    end
  end)
end)
```

## Reporting Compatibility Issues

If you encounter a compatibility issue:

1. Check if it's a known limitation (listed above)
2. Verify the issue reproduces on the specific Lua version
3. Check if there's a workaround using the `compat` module
4. Open an issue with:
   - Lua version (`lua -v`)
   - Minimal reproduction code
   - Expected vs actual behavior
