# Kernel Refactoring Plan

**Goal:** Reduce kernel from 1,175 lines to <200 lines
**Date:** 2024-12-24

---

## Current State

| File | Lines | Purpose |
|------|-------|---------|
| bootstrap.lua | 277 | Factory registrations, initialization |
| container.lua | 277 | DI container |
| events.lua | 273 | Event bus |
| loader.lua | 148 | Module loading |
| registry.lua | 125 | Service registry |
| init.lua | 47 | Package paths, capabilities |
| package.lua | 28 | Config metadata |
| **Total** | **1,175** | |

---

## Analysis by File

### bootstrap.lua (277 lines)

**MUST STAY (core abstraction):**
- Bootstrap.create() - basic container/events setup (~25 lines)
- Bootstrap.init() - thin wrapper calling create + extensions (~10 lines)

**MOVE TO `lib/whisker/extensions/`:**
- `register_media_factories()` (lines 17-127) - ~110 lines → media_extension.lua
- `register_core_factories()` (lines 129-195) - ~70 lines → core_extension.lua
- Logger creation (lines 219-232) - ~15 lines → service_extension.lua

**Target:** 35 lines

---

### container.lua (277 lines)

**MUST STAY (core DI):**
- Container.new() - constructor (~8 lines)
- Container:register() - basic registration (~25 lines)
- Container:resolve() - basic resolution (~25 lines)
- Container:has() - check existence (~3 lines)
- Container:unregister() - remove service (~3 lines)
- Container:clear() - reset state (~8 lines)
- Container:destroy() / destroy_all() - cleanup (~20 lines)

**MOVE TO `lib/whisker/extensions/container_extension.lua`:**
- Container:register_lazy() (lines 169-186) - lazy loading
- Container:resolve_with_deps() (lines 188-229) - dependency graph
- Container:create_child() (lines 139-167) - child scopes
- Container:list_services() / get_names() (lines 266-275, 119-126) - listing

**Target:** 80 lines

---

### events.lua (273 lines)

**MUST STAY (core events):**
- EventBus.new() - constructor (~8 lines)
- EventBus:on() - subscribe (~20 lines)
- EventBus:off() - unsubscribe (~25 lines)
- EventBus:emit() - emit without history (~40 lines)
- EventBus:once() - one-time subscribe (~4 lines)
- EventBus:clear() - clear handlers (~12 lines)
- EventBus:count() - handler count (~12 lines)

**MOVE TO `lib/whisker/extensions/events_extension.lua`:**
- EventBus:namespace() (lines 196-221) - namespaced bus
- EventBus:enable_history() / disable_history() (lines 223-235)
- EventBus:get_history() / clear_history() (lines 237-271)
- History recording in emit() (lines 93-104)

**Target:** 60 lines

---

### registry.lua (125 lines)

**MUST STAY (core registry):**
- Registry.new() - constructor (~8 lines)
- Registry:register() - add module (~12 lines)
- Registry:get() - get module (~3 lines)
- Registry:has() - check existence (~3 lines)
- Registry:unregister() - remove module (~15 lines)
- Registry:clear() - reset state (~5 lines)

**MOVE TO `lib/whisker/extensions/registry_extension.lua`:**
- Registry:get_names() (lines 73-79)
- Registry:get_by_category() (lines 84-86)
- Registry:get_metadata() (lines 91-93)
- Registry:get_categories() (lines 96-103)
- Registry:find() (lines 112-123) - pattern matching

**Target:** 45 lines

---

### loader.lua (148 lines)

**MUST STAY (core loading):**
- Loader.new() - constructor (~7 lines)
- Loader:load() - load single module (~35 lines)
- Loader:is_loaded() - check status (~3 lines)
- Loader:unload() - unload module (~15 lines)

**MOVE TO extensions:**
- Loader:load_all() (lines 85-96)
- Loader:load_category() (lines 103-106)
- Loader:get_loaded() (lines 140-146)

**Target:** 60 lines

---

### init.lua (47 lines)

**KEEP AS-IS** - Already within limit (50 lines)
- Capability detection
- Global whisker setup

**Target:** 47 lines (no change)

---

### package.lua (28 lines)

**KEEP AS-IS** - Metadata file
- Update limits to reflect new targets

**Target:** 28 lines (no change)

---

## Target Line Counts

| File | Current | Target | Reduction |
|------|---------|--------|-----------|
| bootstrap.lua | 277 | 35 | -242 |
| container.lua | 277 | 80 | -197 |
| events.lua | 273 | 60 | -213 |
| registry.lua | 125 | 45 | -80 |
| loader.lua | 148 | 60 | -88 |
| init.lua | 47 | 47 | 0 |
| package.lua | 28 | 28 | 0 |
| **Total** | **1,175** | **<200** | **>975** |

**Note:** Bootstrap becomes thin wrapper (~35 lines). Including it brings total to ~195 lines, well under 200.

---

## Extensions Module Structure

Create `lib/whisker/extensions/`:

```
lib/whisker/extensions/
├── init.lua                 -- Extension loader
├── media_extension.lua      -- Media factory registrations
├── core_extension.lua       -- Core factory registrations
├── service_extension.lua    -- Service registrations (logger, etc.)
├── container_extension.lua  -- Advanced container features
├── events_extension.lua     -- Event history, namespaces
└── registry_extension.lua   -- Registry utilities
```

---

## Bootstrap Flow After Refactor

```lua
-- lib/whisker/kernel/bootstrap.lua (NEW - ~35 lines)
local Bootstrap = {}

function Bootstrap.create(options)
  local Container = require("whisker.kernel.container")
  local EventBus = require("whisker.kernel.events")
  local Registry = require("whisker.kernel.registry")
  local Loader = require("whisker.kernel.loader")

  local container = Container.new()
  local events = EventBus.new()
  local registry = Registry.new()
  local loader = Loader.new(container, registry)

  container:register("events", events, {singleton = true})
  container:register("registry", registry, {singleton = true})
  container:register("loader", loader, {singleton = true})

  return { container = container, events = events, registry = registry, loader = loader }
end

function Bootstrap.init(options)
  local kernel = Bootstrap.create(options)

  -- Load extensions
  local Extensions = require("whisker.extensions")
  Extensions.load_all(kernel.container, kernel.events)

  kernel.events:emit("kernel:ready", { container = kernel.container })
  return kernel
end

return Bootstrap
```

---

## Implementation Order

1. **Stage 1.2:** Create extensions module structure
2. **Stage 1.3:** Move media registrations to media_extension.lua
3. **Stage 1.4:** Move service registrations to service_extension.lua
4. **Stage 1.5:** Slim down container.lua, events.lua, registry.lua, loader.lua
5. **Stage 1.6:** Validate total kernel size <200 lines

---

## Acceptance Criteria

- [ ] Total kernel lines < 200
- [ ] All 1,232 tests pass
- [ ] No functionality lost (advanced features in extensions)
- [ ] Extensions load correctly during bootstrap
- [ ] whisker.container, whisker.events still available globally
