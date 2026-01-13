# WLS 2.0 Hooks System - Implementation

This directory contains the implementation of the WLS 2.0 Hooks system.

## Implemented Components

### Stage 1A: HookManager (Lua) ✅

**File**: `hook_manager.lua`

**Features**:
- Hook registration with unique IDs
- Hook operations: replace, append, prepend, show, hide
- Lifecycle management: clear passage hooks on navigation
- State serialization for save/load
- 22+ unit tests

**Usage**:
```lua
local HookManager = require("lib.whisker.wls2.hook_manager")

local manager = HookManager.new()

-- Register a hook
local hook_id = manager:register_hook("passage_1", "flowers", "roses")

-- Modify hook
manager:replace_hook(hook_id, "wilted petals")

-- Get hook state
local hook = manager:get_hook(hook_id)
print(hook.current_content) -- "wilted petals"
```

**Tests**: `spec/wls2/test_hook_manager_spec.lua`

Run tests with: `busted spec/wls2/`

## Next Steps

- Stage 1C: Parser Extension (Lua) - Add hook syntax recognition
- Stage 2A: Renderer Integration (Lua) - Multi-phase rendering with hooks
- Stage 2B: Engine Integration (Lua) - Lifecycle and operation execution

## Status

| Stage | Status | Files |
|-------|--------|-------|
| 1A: HookManager | ✅ Complete | hook_manager.lua, test_hook_manager_spec.lua |
| 1C: Parser | ⏳ Pending | - |
| 2A: Renderer | ⏳ Pending | - |
| 2B: Engine | ⏳ Pending | - |
