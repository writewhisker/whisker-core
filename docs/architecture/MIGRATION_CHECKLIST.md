# Module Migration Checklist

**Phase 1: Foundation & Modularity Architecture**
**Created:** Stage 02 - Refactoring Plan

Track the migration status of each module to the new architecture.

---

## Legend

- [ ] Not started
- [~] In progress
- [x] Complete

## Checklist Items

For each module:
1. **Metadata** - Has `_whisker` metadata table
2. **No require** - No direct `require()` of whisker modules
3. **Interface** - Implements defined interface (if applicable)
4. **Events** - Uses events for cross-module communication
5. **Tests** - Has unit tests with mocks
6. **Contract** - Passes contract tests (if implements interface)

---

## Core Modules

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `core/story.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `core/passage.lua` | [ ] | [ ] | [ ] | [ ] | [~] | [ ] |
| `core/choice.lua` | [ ] | [x] | [ ] | [ ] | [~] | [ ] |
| `core/engine.lua` | [ ] | [ ] | [ ] | [ ] | [~] | [ ] |
| `core/game_state.lua` | [ ] | [x] | [ ] | [ ] | [~] | [ ] |
| `core/event_system.lua` | [ ] | [x] | [ ] | N/A | [x] | [ ] |
| `core/lua_interpreter.lua` | [ ] | [x] | [ ] | [ ] | [~] | [ ] |
| `core/renderer.lua` | [ ] | [x] | [ ] | [ ] | [x] | [ ] |

## Format Modules

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `format/whisker_format.lua` | [ ] | [x] | [ ] | [ ] | [~] | [ ] |
| `format/whisker_loader.lua` | [ ] | [ ] | [ ] | [ ] | [~] | [ ] |
| `format/twine_importer.lua` | [ ] | [ ] | [ ] | [ ] | [~] | [ ] |
| `format/format_converter.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `format/compact_converter.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `format/story_to_whisker.lua` | [ ] | [ ] | [ ] | [ ] | [~] | [ ] |
| `format/parsers/harlowe.lua` | [ ] | [x] | [ ] | [ ] | [x] | [ ] |
| `format/parsers/snowman.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `format/parsers/chapbook.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `format/parsers/sugarcube.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |

## Infrastructure Modules

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `infrastructure/save_system.lua` | [ ] | [ ] | [ ] | [ ] | [x] | [ ] |
| `infrastructure/file_storage.lua` | [ ] | [?] | [ ] | [ ] | [ ] | [ ] |
| `infrastructure/file_system.lua` | [ ] | [?] | [ ] | [ ] | [ ] | [ ] |
| `infrastructure/asset_manager.lua` | [ ] | [?] | [ ] | [ ] | [ ] | [ ] |
| `infrastructure/input_handler.lua` | [ ] | [?] | [ ] | [ ] | [ ] | [ ] |

## Runtime Modules

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `runtime/cli_runtime.lua` | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| `runtime/desktop_runtime.lua` | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| `runtime/web_runtime.lua` | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

## Tools

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `tools/validator.lua` | [ ] | [x] | [ ] | [ ] | [x] | [ ] |
| `tools/debugger.lua` | [ ] | [?] | [ ] | [ ] | [x] | [ ] |
| `tools/profiler.lua` | [ ] | [?] | [ ] | [ ] | [x] | [ ] |

## Utilities

| Module | Metadata | No require | Interface | Events | Tests | Contract |
|--------|----------|------------|-----------|--------|-------|----------|
| `utils/json.lua` | [ ] | [x] | [ ] | N/A | [ ] | [ ] |
| `utils/file_utils.lua` | [ ] | [ ] | [ ] | N/A | [ ] | [ ] |
| `utils/string_utils.lua` | [ ] | [x] | [ ] | N/A | [x] | [ ] |
| `utils/template_processor.lua` | [ ] | [?] | [ ] | N/A | [x] | [ ] |

---

## New Infrastructure (Phase 1)

| Module | Created | Tests | Coverage |
|--------|---------|-------|----------|
| `kernel/init.lua` | [ ] | [ ] | [ ] |
| `kernel/registry.lua` | [ ] | [ ] | [ ] |
| `kernel/container.lua` | [ ] | [ ] | [ ] |
| `kernel/events.lua` | [ ] | [ ] | [ ] |
| `kernel/loader.lua` | [ ] | [ ] | [ ] |
| `kernel/capabilities.lua` | [ ] | [ ] | [ ] |
| `kernel/errors.lua` | [ ] | [ ] | [ ] |
| `interfaces/format.lua` | [ ] | [ ] | N/A |
| `interfaces/state.lua` | [ ] | [ ] | N/A |
| `interfaces/engine.lua` | [ ] | [ ] | N/A |
| `interfaces/serializer.lua` | [ ] | [ ] | N/A |
| `interfaces/condition.lua` | [ ] | [ ] | N/A |
| `interfaces/plugin.lua` | [ ] | [ ] | N/A |

---

## Summary

| Category | Total | Migrated | Percentage |
|----------|-------|----------|------------|
| Core | 8 | 0 | 0% |
| Format | 10 | 0 | 0% |
| Infrastructure | 5 | 0 | 0% |
| Runtime | 3 | 0 | 0% |
| Tools | 3 | 0 | 0% |
| Utilities | 4 | 0 | 0% |
| **Total Existing** | **33** | **0** | **0%** |
| New Kernel | 7 | 0 | 0% |
| New Interfaces | 6 | 0 | 0% |
| **Total New** | **13** | **0** | **0%** |
