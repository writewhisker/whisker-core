# Whisker-Core Capability Detection

The bootstrap detects available capabilities at initialization.

## Core Runtime Capabilities

| Capability | Type | Detection Method |
|------------|------|------------------|
| `lua_version` | string | `_VERSION` global |
| `luajit` | boolean | `jit` global exists |
| `io` | boolean | `io` library available |
| `os` | boolean | `os` library available |
| `package` | boolean | `package` library available |
| `debug` | boolean | `debug` library available |
| `json` | boolean | JSON library available |

## Feature Capabilities (Added by Modules)

Modules register capabilities when loaded:

| Capability | Module | Description |
|------------|--------|-------------|
| `variables` | services/variables | Variable system |
| `history` | services/history | Navigation history |
| `persistence` | services/persistence | Save/load |
| `format.json` | formats/json | JSON format |
| `format.ink` | formats/ink | Ink format |
| `script` | script | Whisker Script |
| `i18n` | i18n | Internationalization |

## Usage

```lua
local kernel = require("whisker.kernel.init")

-- Check single capability
if kernel.has_capability("json") then
  -- Use JSON features
end

-- List all capabilities
local caps = kernel.get_capabilities()
for name, available in pairs(caps) do
  print(name, available)
end

-- Access via global
if whisker._capabilities.luajit then
  print("Running on LuaJIT")
end
```

## Adding Custom Capabilities

Modules can register additional capabilities:

```lua
-- In your module's initialization
whisker._capabilities["my_feature"] = true
```

## Capability-Based Feature Loading

The loader can use capabilities to conditionally load modules:

```lua
if kernel.has_capability("io") then
  -- Load file-based persistence
else
  -- Load memory-only persistence
end
```
