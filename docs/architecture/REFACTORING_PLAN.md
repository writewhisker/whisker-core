# Refactoring Plan

**Phase 1: Foundation & Modularity Architecture**
**Created:** Stage 02 - Refactoring Plan
**Date:** 2025-12-16

This document outlines the step-by-step approach to refactor whisker-core for extreme modularity.

---

## Overview

The refactoring proceeds in three waves:

1. **Wave 1: Infrastructure** (Stages 03-10) - Build the microkernel, DI container, event bus, and test infrastructure
2. **Wave 2: Contracts** (Stages 11-12) - Define interfaces for all module types
3. **Wave 3: Module Migration** (Stages 13-21) - Refactor existing modules to use new infrastructure

---

## Wave 1: Infrastructure (Stages 03-10)

### Stage 03: Microkernel Core
Create minimal kernel that bootstraps the system.

| Action | File | Description |
|--------|------|-------------|
| Create | `lib/whisker/kernel/init.lua` | Entry point, version, bootstrap |
| Create | `lib/whisker/kernel/registry.lua` | Module registration |
| Create | `lib/whisker/kernel/capabilities.lua` | Feature flag system |
| Create | `lib/whisker/kernel/errors.lua` | Kernel error definitions |

**Constraint:** Total kernel < 200 lines, zero external dependencies.

### Stage 04: Interface Definitions
Define contracts for all swappable components.

| Action | File | Interface |
|--------|------|-----------|
| Create | `lib/whisker/interfaces/init.lua` | Interface utilities |
| Create | `lib/whisker/interfaces/format.lua` | IFormat |
| Create | `lib/whisker/interfaces/state.lua` | IState |
| Create | `lib/whisker/interfaces/engine.lua` | IEngine |
| Create | `lib/whisker/interfaces/serializer.lua` | ISerializer |
| Create | `lib/whisker/interfaces/condition.lua` | IConditionEvaluator |
| Create | `lib/whisker/interfaces/plugin.lua` | IPlugin |

### Stage 05: DI Container
Implement dependency injection container.

| Action | File | Description |
|--------|------|-------------|
| Create | `lib/whisker/kernel/container.lua` | Registration, resolution, lifecycle |

**Features:** Singleton/transient scopes, interface-based lookup, dependency graphs.

### Stage 06: Event Bus
Implement decoupled communication system.

| Action | File | Description |
|--------|------|-------------|
| Create | `lib/whisker/kernel/events.lua` | Pub/sub event system |

**Note:** Replace existing `core/event_system.lua` usage in later stages.

### Stage 07: Module Loader
Implement dynamic module loading.

| Action | File | Description |
|--------|------|-------------|
| Create | `lib/whisker/kernel/loader.lua` | Module discovery, validation, loading |

### Stages 08-10: Test Infrastructure
Build testing support.

| Stage | Action | File | Description |
|-------|--------|------|-------------|
| 08 | Create | `tests/support/mock_factory.lua` | Generate mocks from interfaces |
| 09 | Create | `tests/support/test_container.lua` | Pre-configured test container |
| 10 | Create | `tests/fixtures/` | Standard test data |

---

## Wave 2: Contracts (Stages 11-12)

### Stage 11: IFormat Contract
Define format handler contract with tests.

| Action | File | Description |
|--------|------|-------------|
| Create | `tests/contracts/format_contract.lua` | Contract tests any IFormat must pass |
| Verify | `lib/whisker/format/*.lua` | Ensure formats can implement IFormat |

### Stage 12: IState/IEngine Contracts
Define state and engine contracts.

| Action | File | Description |
|--------|------|-------------|
| Create | `tests/contracts/state_contract.lua` | Contract tests for IState |
| Create | `tests/contracts/engine_contract.lua` | Contract tests for IEngine |

---

## Wave 3: Module Migration (Stages 13-21)

### Migration Strategy

For each module:
1. Add `_whisker` metadata table
2. Replace direct `require()` with container resolution
3. Implement relevant interface
4. Emit events instead of direct calls
5. Add contract test coverage

### Stage 13-16: Core Data Structures

| Stage | Module | Changes |
|-------|--------|---------|
| 13 | `core/passage.lua` | Add metadata, factory pattern for Choice creation |
| 14 | `core/choice.lua` | Add metadata (already standalone) |
| 15 | `core/variable.lua` | Create if needed, or document decision |
| 16 | `core/story.lua` | Add metadata, factory pattern for Passage creation |

### Stage 17-19: Services

| Stage | Module | Changes |
|-------|--------|---------|
| 17 | State Service | Refactor `game_state.lua` to implement IState |
| 18 | Engine Service | Refactor `engine.lua` to implement IEngine, accept deps via constructor |
| 19 | History Service | Extract history from GameState if separate service needed |

### Stage 20: Condition Evaluator
Extract condition evaluation.

| Action | File | Description |
|--------|------|-------------|
| Create | `lib/whisker/services/conditions/init.lua` | Implements IConditionEvaluator |
| Modify | `core/lua_interpreter.lua` | Delegate to condition service |

### Stage 21: CI/CD and Integration
Validate full system.

| Action | Description |
|--------|-------------|
| Fix | Wrong paths in runtime files (ISS-005) |
| Add | Integration tests for kernel + modules |
| Verify | All 689+ tests still pass |

---

## Backward Compatibility Approach

### Compatibility Shims

For each refactored module, provide a compatibility layer:

```lua
-- lib/whisker/compat/engine.lua
-- Provides old API on top of new implementation
local container = require("whisker.kernel").container
local Engine = {}

function Engine.new(story)
  -- Old API: Engine.new(story)
  -- New API: container:resolve("engine", {story = story})
  return container:resolve("engine", {story = story})
end

return Engine
```

### Deprecation Warnings

```lua
function deprecated(old_name, new_name)
  io.stderr:write(string.format(
    "[DEPRECATED] %s is deprecated, use %s instead\n",
    old_name, new_name
  ))
end
```

### Migration Path for Consumers

1. **Phase 1 Release:** Both old and new APIs work
2. **Phase 2 Release:** Deprecation warnings on old APIs
3. **Phase 3 Release:** Remove old APIs (major version bump)

---

## Issue Resolution Mapping

| Issue | Stage | Resolution |
|-------|-------|------------|
| ISS-001 | 03-07 | Create kernel infrastructure |
| ISS-002 | 04 | Create interface definitions |
| ISS-003 | 11 | Refactor whisker_loader with DI |
| ISS-004 | 18 | Refactor engine with DI |
| ISS-005 | 21 | Fix runtime paths |
| ISS-006 | 06, 16-18 | Integrate kernel event bus |
| ISS-007 | 13-16 | Factory patterns in deserialize |
| ISS-008 | N/A | Editor (Phase 2+) |
| ISS-009 | 17 | Refactor save_system |
| ISS-010 | 11 | Parser composition |
| ISS-011 | 15 | Variable module decision |
| ISS-012 | 08-10 | Test infrastructure |
| ISS-013 | 20 | Extract condition evaluator |
| ISS-014 | Post-Phase 1 | Plugin system |
| ISS-015 | 13 | Constructor injection for Renderer |

---

## Success Criteria

Phase 1 is complete when:

- [ ] Kernel loads with zero dependencies
- [ ] All interfaces defined and documented
- [ ] DI container manages all component lifecycles
- [ ] Event bus replaces direct cross-module calls
- [ ] All 15 issues addressed or deferred with rationale
- [ ] 689+ tests passing
- [ ] Coverage targets met (kernel 95%, core 90%)
- [ ] No direct `require()` between whisker modules
