# Coupling Analysis

**Generated:** Stage 01 - Repository Audit
**Date:** 2025-12-16

This document analyzes modularity violations based on the checklist from the Phase 1 Implementation Guide.

---

## Modularity Checklist Reference

Each module should pass:
- [ ] No hardcoded dependencies (uses container/registry)
- [ ] Implements a defined interface
- [ ] Testable in isolation with mocks
- [ ] Optional loading (system works if absent)
- [ ] Event-based communication
- [ ] Single responsibility
- [ ] Documented contract
- [ ] No global state

---

## Direct Require Violations

### Critical (Module-Level Requires)

| File | Line | Require Statement | Violation |
|------|------|-------------------|-----------|
| `whisker_loader.lua` | 66-74 | `require("whisker.core.story")` + 4 more | Multiple hardcoded dependencies at module level |
| `format_converter.lua` | 8, 22-23 | `require("whisker.format.*")` | Hardcoded format dependencies |
| `twine_importer.lua` | 18 | `require("whisker.format.whisker_format")` | Hardcoded format dependency |
| `parsers/snowman.lua` | 4 | `require("whisker.format.parsers.harlowe")` | Inherits from harlowe parser |
| `parsers/chapbook.lua` | 4 | `require("whisker.format.parsers.harlowe")` | Inherits from harlowe parser |
| `parsers/sugarcube.lua` | 5 | `require("whisker.format.parsers.harlowe")` | Inherits from harlowe parser |

### Medium (Inside Method Requires)

| File | Line | Require Statement | Violation |
|------|------|-------------------|-----------|
| `story.lua` | 438, 463, 509 | `require("whisker.core.passage")` | Requires inside deserialize methods |
| `passage.lua` | 170, 195, 232 | `require("whisker.core.choice")` | Requires inside deserialize methods |
| `engine.lua` | 26, 40, 46, 56, 70, 76 | Multiple requires | Creates internal dependencies |
| `save_system.lua` | 49, 75, 88, 113, 162, 197, 204, 211 | Multiple requires | Requires inside methods |
| `file_utils.lua` | 240, 245 | `require("whisker.utils.json")` | Requires inside methods |
| `compact_converter.lua` | 328 | `require("whisker.utils.json")` | Conditional require |

### Low (Documentation/Test References)

Files in `parser/usage.md`, `runtime/README.md`, `format/FORMAT_PARSER.md` contain example requires - not runtime issues.

---

## Wrong Path Violations

| File | Line | Issue |
|------|------|-------|
| `cli_runtime.lua` | 8-10 | Uses `src.*` paths instead of `whisker.*` |
| `desktop_runtime.lua` | 9-10 | Uses `src.*` paths instead of `whisker.*` |
| `editor/core/project.lua` | 109, 120 | Expects global `json` library |
| `editor/export/exporter.lua` | 22 | Expects global `json` library |

---

## Missing Interface Implementations

Based on roadmap interfaces (IFormat, IState, IEngine, ISerializer, IConditionEvaluator, IPlugin):

| Interface | Current Implementation | Status |
|-----------|----------------------|--------|
| `IFormat` | `whisker_format.lua`, `twine_importer.lua` | No formal interface, ad-hoc methods |
| `IState` | `game_state.lua` | Close to IState, missing `clear()` method |
| `IEngine` | `engine.lua` | Partially matches, different method names |
| `ISerializer` | `json.lua`, `compact_converter.lua` | No formal interface |
| `IConditionEvaluator` | Built into `lua_interpreter.lua` | Not separated |
| `IPlugin` | None | Not implemented |

---

## Event System Usage Analysis

The `EventSystem` class exists (`core/event_system.lua`) but is **not used** by other modules.

| Module | Uses Events | Notes |
|--------|-------------|-------|
| `engine.lua` | No | Could emit passage:entered, choice:made |
| `game_state.lua` | No | Could emit state:changed |
| `story.lua` | No | Could emit story:loaded, passage:added |
| `save_system.lua` | No | Could emit state:saved, state:loaded |

**Violation:** Cross-module communication happens via direct method calls, not events.

---

## Global State Analysis

Searched for potential global state patterns:

| Pattern | Occurrences | Files |
|---------|-------------|-------|
| Module-level mutable state | 0 | None found |
| Singletons without container | 1 | EventSystem could be singleton |
| Hardcoded configuration | Few | Various config defaults |

**Status:** No severe global state issues. Configuration is passed via constructors.

---

## Testability Analysis

| Module | Testable in Isolation? | Blocking Factors |
|--------|----------------------|------------------|
| `choice.lua` | Yes | None |
| `passage.lua` | Partial | Requires Choice in deserialize |
| `story.lua` | Partial | Requires Passage in deserialize |
| `game_state.lua` | Yes | None |
| `engine.lua` | No | Creates internal dependencies |
| `lua_interpreter.lua` | Yes | None |
| `renderer.lua` | Yes | Uses DI for interpreter |
| `event_system.lua` | Yes | None |
| `validator.lua` | Yes | None |
| `whisker_loader.lua` | No | Multiple hardcoded requires |
| `save_system.lua` | No | Multiple hardcoded requires |

---

## Circular Dependency Risk

```
whisker_loader → story → passage → choice (OK - linear)
                       ↘         ↗
                        choice (OK)

engine → story → passage (OK - linear)
       → game_state (OK)
       → lua_interpreter (OK)
```

**Status:** No circular dependencies detected. Dependency graph is tree-shaped.

---

## Summary of Violations

| Category | Count | Severity |
|----------|-------|----------|
| Hardcoded requires (module level) | 6 | High |
| Hardcoded requires (inside methods) | 18 | Medium |
| Wrong paths | 4 | High |
| Missing interfaces | 6 | Medium |
| No event usage | 4+ | Medium |
| Untestable in isolation | 3 | Medium |
| Global state | 0 | None |
| Circular dependencies | 0 | None |

---

## Recommended Refactoring Priority

1. **High Priority**
   - Fix wrong paths in runtime files
   - Create formal interfaces (IFormat, IState, IEngine)
   - Add DI container for managing dependencies

2. **Medium Priority**
   - Move module-level requires to factory/container pattern
   - Integrate EventSystem into core modules
   - Extract condition evaluation into IConditionEvaluator

3. **Low Priority**
   - Refactor deserialize methods to use injected factories
   - Add IPlugin interface for extensibility
   - Document all module contracts
