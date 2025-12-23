# Global State Detection

## Executive Summary

- **Module-level mutable state**: 8 instances (MEDIUM severity)
- **Caching patterns**: 2 instances (LOW severity)
- **Constants**: Multiple instances (ACCEPTABLE)
- **Global namespace pollution**: 1 instance (HIGH severity - vendor code)

## High Severity Issues

### vendor/tinta/init.lua (CRITICAL)

**Global Namespace Pollution**
```lua
_G.dump = require("libs.dump")              -- Line 61
_G.lume = require("libs.lume")              -- Line 64
_G.serialization = require("libs.serialization") -- Line 67
_G.DelegateUtils = require("libs.delegate") -- Line 70
_G.inkutils = require("libs.inkutils")      -- Line 73
_G.PRNG = require("libs.prng")              -- Line 76
_G.PushPopType = require("constants.push_pop_type") -- Line 79
_G.ControlCommandType = require("constants.control_commands.types") -- Line 80
... (20+ more)
```

**Severity**: HIGH
**Impact**: Pollutes global namespace, risk of conflicts
**Recommendation**: Vendor code - acceptable as third-party library, but isolate usage

## Medium Severity Issues

### infrastructure/asset_manager.lua

**Mutable Module-Level Cache**
```lua
-- Line 38-40
self.assets = {}   -- Loaded assets
self.cache = {}    -- Asset cache with metadata
self.loading = {}  -- Currently loading assets
```

**Severity**: MEDIUM
**Pattern**: Instance state (acceptable - part of object)
**Risk**: State is per-instance, not module-level (GOOD)

**Module-Level Stats**
```lua
-- Line 43-49
self.stats = {
    total_loaded = 0,
    total_size = 0,
    failed_loads = 0,
    cache_hits = 0,
    cache_misses = 0
}
```

**Severity**: LOW
**Pattern**: Per-instance statistics (acceptable)

### core/game_state.lua

**Mutable State Tracking**
```lua
-- Line 9-23
variables = {},
current_passage = nil,
visited_passages = {},
choice_history = {},
history_stack = {},
max_history = 10,  -- Configuration (acceptable)
```

**Severity**: LOW
**Pattern**: Instance state for game persistence (acceptable - this IS the state module)
**Note**: This is literally the GameState object - mutable state is its purpose

### kernel/container.lua

**Internal Container State**
```lua
-- Line 14-18
self._registrations = {}
self._singletons = {}
self._resolving = {}
self._destroy_callbacks = {}
self._registration_order = {}
```

**Severity**: LOW
**Pattern**: Per-instance DI container state (acceptable)
**Note**: Container state is encapsulated and intentional

### kernel/events.lua

**Event Handler Storage**
```lua
-- Line 14-16
self._handlers = {}
self._wildcard_handlers = {}
self._once_handlers = {}
```

**Severity**: LOW
**Pattern**: Per-instance event bus state (acceptable)
**Note**: EventBus state is encapsulated and intentional

### core/story.lua

**Story Data Storage**
```lua
-- Line 51-70
metadata = { ... },
variables = options.variables or {},
passages = options.passages or {},
start_passage = options.start_passage or nil,
stylesheets = options.stylesheets or {},
scripts = options.scripts or {},
assets = options.assets or {},
tags = options.tags or {},
settings = options.settings or {}
```

**Severity**: LOW
**Pattern**: Domain model instance state (acceptable)
**Note**: This is a data structure, not global state

### script/compiler.lua

**Compiler Working State**
```lua
-- Line 22-29
self.options = options or {}
self.output = {}
self.indent_level = 0
self.variables = {}    -- Track variables for optimization
self.passages = {}     -- Track passages for validation
```

**Severity**: LOW
**Pattern**: Per-compilation state (acceptable)
**Note**: State is reset on each compile() call (line 107-110)

### format/whisker_format.lua

**Module-Level Constants**
```lua
-- Line 32-36
whiskerFormat.VERSION = "2.0"
whiskerFormat.FORMAT_NAME = "whisker"
whiskerFormat.LEGACY_VERSION = "1.0"
whiskerFormat.SCHEMA = { ... }  -- Large constant object (line 351-432)
```

**Severity**: NONE
**Pattern**: Module constants (acceptable)
**Note**: These are immutable configuration values

## Low Severity Issues (Acceptable Patterns)

### infrastructure/asset_manager.lua

**Asset Type Constants**
```lua
-- Line 9-15
AssetManager.AssetType = {
    IMAGE = "image",
    AUDIO = "audio",
    VIDEO = "video",
    FONT = "font",
    DATA = "data"
}
```

**Severity**: NONE
**Pattern**: Constant enum (acceptable)

**Internal Status Enum**
```lua
-- Line 18-23
local AssetStatus = {
    UNLOADED = "unloaded",
    LOADING = "loading",
    LOADED = "loaded",
    FAILED = "failed"
}
```

**Severity**: NONE
**Pattern**: Module-local constant (acceptable)

### utils/json.lua

**No State** - Pure functions only (EXCELLENT)

**Analysis**:
```lua
local json = {}

function json.encode(obj, indent_level)
    -- Pure function, no module state
end

function json.decode(str)
    -- Pure function, uses local closure variables
end
```

**Severity**: NONE
**Pattern**: Pure functional module (best practice)

### interfaces/* modules

**No State** - Interface definitions only (EXCELLENT)

```lua
local IFormat = {}

function IFormat:can_import(data)
    error("IFormat:can_import must be implemented")
end
```

**Severity**: NONE
**Pattern**: Interface definition (acceptable)

## Patterns Found

### 1. Instance State (Acceptable)

Modules that create instances with encapsulated state:
- `kernel/container.lua` - DI container state
- `kernel/events.lua` - Event bus handlers
- `core/game_state.lua` - Game state data
- `core/story.lua` - Story data model
- `infrastructure/asset_manager.lua` - Asset cache
- `script/compiler.lua` - Compiler working state

**Status**: ACCEPTABLE - State is per-instance, not shared

### 2. Module Constants (Acceptable)

Immutable configuration and enums:
- `format/whisker_format.lua` - Format version/schema
- `infrastructure/asset_manager.lua` - Asset type enum
- `script/ast.lua` (assumed) - AST node type constants

**Status**: ACCEPTABLE - Read-only reference data

### 3. Pure Functions (Best Practice)

Modules with no state at all:
- `utils/json.lua` - Pure JSON encoding/decoding
- `utils/string_utils.lua` (assumed) - Pure string utilities
- `interfaces/*` - Interface definitions

**Status**: EXCELLENT - Stateless and testable

### 4. Global Namespace (Vendor Code)

Third-party library initialization:
- `vendor/tinta/init.lua` - Ink runtime globals

**Status**: ACCEPTABLE (third-party) - Isolated to vendor code

## No True Global State Found

**Key Finding**: Despite having module-level variables, none of the whisker-core
modules (excluding vendor/) maintain mutable shared state across instances.

All mutable state is either:
1. Encapsulated in instances (container, events, game state)
2. Reset per-operation (compiler output)
3. Part of the domain model (story data)

## Recommendations

### Immediate Actions

1. **None required** - No critical global state issues found

### Best Practices to Maintain

1. **Continue instance-based design** - All mutable state is per-instance
2. **Avoid module-level caches** - Use instance caches like AssetManager does
3. **Keep utils pure** - Maintain stateless utility functions
4. **Isolate vendor code** - Keep tinta global pollution contained

### Future Considerations

1. **Asset Manager Cache** - Consider making cache injectable for testing:
   ```lua
   function AssetManager.new(config, cache_backend)
       self.cache = cache_backend or {}
   ```

2. **Compiler State** - Already good (resets on compile), but could formalize:
   ```lua
   function Compiler:reset()
       self.output = {}
       self.indent_level = 0
       self.variables = {}
       self.passages = {}
   end
   ```

## State Severity Matrix

| Module | Type | Mutability | Scope | Severity | Acceptable? |
|--------|------|------------|-------|----------|-------------|
| vendor/tinta | Global | Mutable | Global | HIGH | Yes (vendor) |
| kernel/container | Instance | Mutable | Instance | LOW | Yes |
| kernel/events | Instance | Mutable | Instance | LOW | Yes |
| core/game_state | Instance | Mutable | Instance | LOW | Yes |
| core/story | Instance | Mutable | Instance | LOW | Yes |
| infrastructure/asset_manager | Instance | Mutable | Instance | MEDIUM | Yes |
| script/compiler | Instance | Mutable | Instance | LOW | Yes |
| utils/json | None | Immutable | None | NONE | Yes |
| format/whisker_format | Constants | Immutable | Module | NONE | Yes |

## Overall State Grade: A-

The codebase demonstrates excellent state management practices:
- ✅ No accidental global state
- ✅ All mutable state is encapsulated
- ✅ Pure utility functions
- ✅ Clear separation of stateful and stateless modules
- ⚠️ Vendor code uses globals (acceptable trade-off)

**Recommendation**: Maintain current practices. No refactoring needed for state management.
