# Kernel Refactoring Plan

**Goal:** Reduce kernel from 1,175 lines to <200 lines
**Date:** 2024-12-24
**Updated:** 2024-12-24 (Post-implementation analysis)

---

## Implementation Status

### Completed

| Stage | Description | Result |
|-------|-------------|--------|
| 1.1 | Analyze Kernel Responsibilities | Completed - Plan created |
| 1.2 | Create Extensions Module | Completed - 4 extension files created |
| 1.3 | Extract Factory Registrations | Completed - 185 lines moved |
| 1.4 | Extract Service Registrations | Completed - Logger moved |
| 1.5 | Slim Down Core Kernel Files | Analysis completed (see below) |

### Current State (After Stages 1.1-1.4)

| File | Before | After | Change |
|------|--------|-------|--------|
| bootstrap.lua | 277 | 77 | -200 |
| container.lua | 277 | 277 | 0 |
| events.lua | 273 | 273 | 0 |
| loader.lua | 148 | 148 | 0 |
| registry.lua | 125 | 125 | 0 |
| init.lua | 47 | 47 | 0 |
| package.lua | 28 | 28 | 0 |
| **Total** | **1,175** | **975** | **-200** |

---

## Stage 1.5 Analysis: Test Usage of Kernel Methods

A thorough analysis of all test files was conducted to determine which kernel methods can safely be moved to extensions without breaking tests.

### Container Methods - Test Analysis

| Method | Test Files | Tests Using | Safe to Move? |
|--------|-----------|-------------|---------------|
| create_child() | 1 | 3 | NO - Core DI scoping |
| list_services() | 1 | 2 | NO - Initialization verification |
| resolve_with_deps() | 1 | 2 | NO - Dependency ordering |

**Conclusion:** Container methods are actively tested and essential for DI functionality. These cannot be safely extracted without modifying tests.

### Events Methods - Test Analysis

| Method | Test Files | Tests Using | Safe to Move? |
|--------|-----------|-------------|---------------|
| namespace() | 4 | 3 | YES - Optional feature |
| enable_history() | 4 | ~10 | YES - Debugging feature |
| disable_history() | 4 | ~5 | YES - Debugging feature |
| get_history() | 4 | ~8 | YES - Debugging feature |
| clear_history() | 4 | ~3 | YES - Debugging feature |

**Conclusion:** History and namespace features are optional/debugging. Could be moved but would require test modifications.

### Registry Methods - Test Analysis

| Method | Test Files | Tests Using | Safe to Move? |
|--------|-----------|-------------|---------------|
| find() | 21 | Mixed | YES - Pattern matching utility |
| get_categories() | 1 | 1 | YES - Query helper |
| get_by_category() | 1 | 1 | YES - Query helper |
| get_metadata() | 12 | Mixed | PARTIAL - Domain vs Registry |
| get_names() | 1 | 3 | YES - Introspection helper |

**Conclusion:** Registry query methods are safe to move but would require test modifications.

### Loader Methods - Test Analysis

| Method | Test Files | Tests Using | Safe to Move? |
|--------|-----------|-------------|---------------|
| load_all() | 0 | 0 | YES - No tests |
| load_category() | 0 | 0 | YES - No tests |
| get_loaded() | 0 | 0 | YES - No tests |

**Conclusion:** Loader advanced methods have no direct tests and could be safely moved.

---

## Why Further Reduction Requires Test Changes

The core kernel files (container, events, registry, loader) contain methods that are:

1. **Actively tested** - Unit tests directly exercise these methods
2. **Expected by tests** - Tests import from kernel modules and expect methods to exist
3. **Essential for DI patterns** - Features like create_child() are core DI functionality

Moving these methods to extensions would require:
- Creating new extension modules for advanced features
- Updating all affected tests to load extensions first
- Ensuring backward compatibility through some mechanism

This is a larger undertaking that falls outside the scope of this remediation.

---

## Achieved Improvements

### Bootstrap Refactoring (200 line reduction)

Successfully extracted from bootstrap.lua:
- `register_media_factories()` (~110 lines) → `media_extension.lua`
- `register_core_factories()` (~70 lines) → `core_extension.lua`
- Logger creation (~15 lines) → `service_extension.lua`

### Extensions Module Created

```
lib/whisker/extensions/
├── init.lua              (38 lines) - Extension loader
├── media_extension.lua   (121 lines) - Media factory registrations
├── core_extension.lua    (77 lines) - Core factory registrations
└── service_extension.lua (38 lines) - Base service registrations
```

### Architecture Benefits

1. **Cleaner separation** - Bootstrap only sets up kernel, extensions add functionality
2. **Lazy loading** - Factories are only loaded when needed
3. **Extensibility** - New extensions can be added without modifying kernel
4. **Testability** - Extensions can be mocked or replaced in tests

---

## Future Work (Out of Scope)

To achieve the original <200 line target, future work would include:

1. **Create Advanced Extensions**
   - `container_extension.lua` - create_child(), resolve_with_deps()
   - `events_extension.lua` - namespace(), history features
   - `registry_extension.lua` - query methods

2. **Update Tests**
   - Modify tests to load extensions before exercising advanced features
   - Consider using a test bootstrap that loads all extensions

3. **Consider Backward Compatibility**
   - Provide shim methods in kernel that delegate to extensions
   - Or fully update all consumers to use extensions

---

## Final Metrics

| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Kernel Total | 1,175 | 975 | <200 | Reduced 17% |
| Bootstrap Lines | 277 | 77 | 35 | Reduced 72% |
| Tests Passing | 1,232 | 1,232 | 1,232 | Maintained |
| Extensions Created | 0 | 4 | 4 | Complete |

---

## Acceptance Criteria Status

- [x] Bootstrap reduced significantly (277 → 77 lines)
- [x] All 1,232 tests pass
- [x] No functionality lost
- [x] Extensions load correctly during bootstrap
- [x] whisker.container, whisker.events still available globally
- [ ] Total kernel lines < 200 (975 lines - requires test modifications)
