# Coverage Baseline Report

**Generated:** Stage 01 - Repository Audit
**Date:** 2025-12-16
**Test Framework:** busted

---

## Test Execution Summary

```
Tests Run:    689 successes / 0 failures / 0 errors / 2 pending
Duration:     0.387 seconds
```

### Pending Tests

| File | Description |
|------|-------------|
| `tests/test_converter_roundtrip.lua:152` | Conversion Loss Detection - should warn about incompatible features |
| `tests/test_converter_roundtrip.lua:169` | Conversion Loss Detection - should detect when exact conversion isn't possible |

---

## Test File Inventory

**Total Test Files:** 43

### By Category

| Category | Files | Description |
|----------|-------|-------------|
| Core | 1 | `test_story.lua` |
| Format Converters | 6 | harlowe, snowman, chapbook, sugarcube converters |
| Format Parsers | 4 | harlowe, snowman, chapbook, sugarcube parsers |
| Format Integration | 3 | converter roundtrip, format converter, compact format |
| Import/Export | 2 | `test_import.lua`, `test_export.lua` |
| Infrastructure | 1 | `test_save_system.lua` |
| Runtime Components | 3 | renderer, template processor, event system |
| Tools | 3 | validator, debugger, profiler |
| Utilities | 1 | `test_string_utils.lua` |
| Metatable | 1 | `test_metatable_preservation.lua` |
| Format-Specific | 12 | harlowe/, snowman/, chapbook/, sugarcube/ subdirs |
| Other | 6 | rijks_load, compact_integration, etc. |

---

## Test Directory Structure

```
tests/
├── test_*.lua              # Main test files (27 files)
├── harlowe/                # Harlowe format tests (4 files)
│   ├── test_combat.lua
│   ├── test_datastructures.lua
│   ├── test_inventory.lua
│   └── test_storylets.lua
├── snowman/                # Snowman format tests (4 files)
│   ├── test_basic.lua
│   ├── test_combat.lua
│   ├── test_quest.lua
│   └── test_shop.lua
├── chapbook/               # Chapbook format tests (4 files)
│   ├── test_confitionals.lua
│   ├── test_inserts.lua
│   ├── test_modifiers.lua
│   └── test_variables.lua
├── sugarcube/              # SugarCube format tests (5 files)
│   ├── test_combat.lua
│   ├── test_inventory.lua
│   ├── test_save.lua
│   ├── test_shop.lua
│   └── test_time.lua
└── test_helper.lua         # Test utilities
```

---

## Coverage Gaps Analysis

### Modules with Direct Test Coverage

| Module | Test File | Status |
|--------|-----------|--------|
| `core/story.lua` | `test_story.lua` | ✅ Covered |
| `core/event_system.lua` | `test_event_system.lua` | ✅ Covered |
| `core/renderer.lua` | `test_renderer.lua` | ✅ Covered |
| `tools/validator.lua` | `test_validator.lua` | ✅ Covered |
| `tools/debugger.lua` | `test_debugger.lua` | ✅ Covered |
| `tools/profiler.lua` | `test_profiler.lua` | ✅ Covered |
| `infrastructure/save_system.lua` | `test_save_system.lua` | ✅ Covered |
| `utils/string_utils.lua` | `test_string_utils.lua` | ✅ Covered |
| `utils/template_processor.lua` | `test_template_processor.lua` | ✅ Covered |
| `format/compact_converter.lua` | `test_compact_format.lua`, `test_compact_integration.lua` | ✅ Covered |

### Modules with Indirect Test Coverage

| Module | Covered Via | Status |
|--------|-------------|--------|
| `core/passage.lua` | `test_story.lua`, format tests | ⚠️ Indirect |
| `core/choice.lua` | `test_story.lua`, format tests | ⚠️ Indirect |
| `core/engine.lua` | Format tests, integration tests | ⚠️ Indirect |
| `core/game_state.lua` | `test_save_system.lua`, integration | ⚠️ Indirect |
| `core/lua_interpreter.lua` | Engine tests, renderer tests | ⚠️ Indirect |
| `format/whisker_loader.lua` | `test_import.lua` | ⚠️ Indirect |
| `format/whisker_format.lua` | Format tests | ⚠️ Indirect |

### Modules Lacking Test Coverage

| Module | Status |
|--------|--------|
| `core/instruction_counter.lua` | ❌ No direct tests |
| `infrastructure/file_storage.lua` | ❌ No direct tests |
| `infrastructure/file_system.lua` | ❌ No direct tests |
| `infrastructure/asset_manager.lua` | ❌ No direct tests |
| `infrastructure/input_handler.lua` | ❌ No direct tests |
| `runtime/cli_runtime.lua` | ❌ No direct tests |
| `runtime/desktop_runtime.lua` | ❌ No direct tests |
| `runtime/web_runtime.lua` | ❌ No direct tests |
| `ui/console.lua` | ❌ No direct tests |
| `ui/ui_framework.lua` | ❌ No direct tests |
| `parser/lexer.lua` | ❌ No direct tests |
| `parser/parser.lua` | ❌ No direct tests |
| `editor/core/project.lua` | ❌ No direct tests |
| `editor/core/passage_manager.lua` | ❌ No direct tests |
| `editor/export/exporter.lua` | ❌ No direct tests |
| `editor/validation/validator.lua` | ❌ No direct tests |
| `utils/json.lua` | ❌ No direct tests (used everywhere) |
| `utils/file_utils.lua` | ❌ No direct tests |

---

## Coverage Tool Status

**LuaCov:** Not installed

```
busted --coverage
busted: error: LuaCov not found on the system, try running without --coverage option, or install LuaCov first
```

**Action Required:** Install LuaCov for accurate line/branch coverage metrics.

```bash
luarocks install luacov
```

---

## Phase 1 Coverage Targets

Per the implementation guide, these are the coverage targets:

| Component | Target Line | Target Branch |
|-----------|-------------|---------------|
| `kernel/*` | 95% | 90% |
| `core/*` | 90% | 85% |
| `services/*` | 85% | 80% |
| `formats/*` | 80% | 75% |

---

## Baseline Metrics

### Test Count by Type

| Type | Count |
|------|-------|
| Unit Tests | ~600 |
| Integration Tests | ~50 |
| Format-Specific Tests | ~39 |
| **Total** | ~689 |

### Estimated Coverage (without LuaCov)

| Component | Estimated Coverage | Notes |
|-----------|-------------------|-------|
| `core/story.lua` | ~80% | Direct tests exist |
| `core/passage.lua` | ~70% | Indirect coverage |
| `core/choice.lua` | ~70% | Indirect coverage |
| `core/engine.lua` | ~60% | Integration only |
| `core/game_state.lua` | ~70% | Via save_system |
| `format/*` | ~75% | Good converter tests |
| `tools/*` | ~80% | Direct tests exist |
| `infrastructure/*` | ~40% | Only save_system |
| `runtime/*` | ~10% | No direct tests |
| `utils/*` | ~50% | Some coverage |
| `editor/*` | ~0% | No tests |
| `ui/*` | ~0% | No tests |
| `parser/*` | ~20% | Minimal |

---

## Recommendations

1. **Install LuaCov** to get accurate coverage metrics
2. **Add unit tests** for core modules (passage, choice, engine)
3. **Add tests for** json.lua, file_utils.lua (heavily used)
4. **Create test fixtures** directory as per roadmap
5. **Add contract tests** after interfaces are defined
6. **Consider** skipping editor/ui coverage until Phase 2+

---

## Commands

```bash
# Run all tests
busted

# Run specific test file
busted tests/test_story.lua

# Run tests in directory
busted tests/harlowe/

# Install LuaCov
luarocks install luacov

# Run with coverage (after LuaCov installed)
busted --coverage

# View coverage report
luacov && cat luacov.report.out
```
