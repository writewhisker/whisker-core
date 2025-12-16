# Prioritized Issue List

**Generated:** Stage 01 - Repository Audit
**Date:** 2025-12-16

Issues identified during repository audit, prioritized for Phase 1 implementation.

---

## Priority 1: Critical - Must Fix

### ISS-001: Missing Microkernel Infrastructure
**Category:** Architecture
**Severity:** Critical
**Location:** `lib/whisker/` (missing `kernel/` directory)

**Description:** No microkernel infrastructure exists. The roadmap requires a kernel under 200 lines providing: module loading, dependency injection, event bus, and registry services.

**Required Action:**
- Create `lib/whisker/kernel/init.lua`
- Create `lib/whisker/kernel/container.lua`
- Create `lib/whisker/kernel/events.lua`
- Create `lib/whisker/kernel/registry.lua`
- Create `lib/whisker/kernel/loader.lua`

**Stage:** 03-07

---

### ISS-002: Missing Interface Definitions
**Category:** Architecture
**Severity:** Critical
**Location:** `lib/whisker/` (missing `interfaces/` directory)

**Description:** No formal interface definitions exist. All modules interact directly without contracts.

**Required Interfaces:**
- `IFormat` - Story format handlers
- `IState` - State management
- `IEngine` - Runtime engine
- `ISerializer` - Data serialization
- `IConditionEvaluator` - Condition evaluation
- `IPlugin` - Plugin contract

**Stage:** 04

---

### ISS-003: Hardcoded Dependencies in whisker_loader.lua
**Category:** Coupling
**Severity:** Critical
**Location:** `lib/whisker/format/whisker_loader.lua:66-74`

**Description:** Module-level requires create tight coupling:
```lua
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")
local json = require("whisker.utils.json")
local CompactConverter = require("whisker.format.compact_converter")
```

**Required Action:** Refactor to use DI container for dependencies.

**Stage:** 11 (IFormat contract implementation)

---

### ISS-004: Engine Creates Internal Dependencies
**Category:** Coupling
**Severity:** Critical
**Location:** `lib/whisker/core/engine.lua:26-46, 56-78`

**Description:** Engine creates its own dependencies internally:
```lua
local Story = require("whisker.core.story")
local GameState = require("whisker.core.game_state")
local LuaInterpreter = require("whisker.core.lua_interpreter")
```

**Required Action:** Accept dependencies via constructor, use IEngine interface.

**Stage:** 18

---

## Priority 2: High - Should Fix

### ISS-005: Wrong Module Paths in Runtime Files
**Category:** Bug
**Severity:** High
**Location:**
- `lib/whisker/runtime/cli_runtime.lua:8-10`
- `lib/whisker/runtime/desktop_runtime.lua:9-10`

**Description:** Files use deprecated `src.*` paths instead of `whisker.*`:
```lua
local Engine = require('src.core.engine')  -- Should be whisker.core.engine
```

**Required Action:** Update paths to use `whisker.*` namespace.

**Stage:** 21 (CI/CD integration testing)

---

### ISS-006: Event System Not Integrated
**Category:** Architecture
**Severity:** High
**Location:** `lib/whisker/core/event_system.lua` (exists but unused)

**Description:** A complete EventSystem implementation exists but no other modules use it. Cross-module communication happens via direct method calls.

**Required Action:**
- Integrate events into Engine (passage:entered, choice:made)
- Integrate events into GameState (state:changed)
- Consider replacing with kernel event bus

**Stage:** 06, 16-18

---

### ISS-007: Deserialize Methods Require Dependencies
**Category:** Coupling
**Severity:** High
**Location:**
- `lib/whisker/core/story.lua:438, 463, 509`
- `lib/whisker/core/passage.lua:170, 195, 232`

**Description:** Deserialize and from_table methods require sibling modules:
```lua
local Passage = require("whisker.core.passage")  -- Inside Story.deserialize
local Choice = require("whisker.core.choice")    -- Inside Passage.deserialize
```

**Required Action:** Use factory pattern or injected builders for deserialization.

**Stage:** 13-16

---

### ISS-008: Global JSON Dependency in Editor
**Category:** Coupling
**Severity:** High
**Location:**
- `lib/whisker/editor/core/project.lua:109, 120`
- `lib/whisker/editor/export/exporter.lua:22`

**Description:** Editor modules expect a global `json` library:
```lua
local json = require('json')  -- Expects global, not whisker.utils.json
```

**Required Action:** Use `whisker.utils.json` or inject serializer.

**Stage:** N/A (Editor refactoring may be Phase 2+)

---

## Priority 3: Medium - Recommended

### ISS-009: save_system.lua Multiple Internal Requires
**Category:** Coupling
**Severity:** Medium
**Location:** `lib/whisker/infrastructure/save_system.lua:49-211`

**Description:** 8 require statements inside methods for json, Story, GameState, file_utils.

**Required Action:** Accept dependencies via constructor using ISerializer, IState patterns.

**Stage:** 17

---

### ISS-010: Format Parsers Inherit via Require
**Category:** Coupling
**Severity:** Medium
**Location:**
- `lib/whisker/format/parsers/snowman.lua:4`
- `lib/whisker/format/parsers/chapbook.lua:4`
- `lib/whisker/format/parsers/sugarcube.lua:5`

**Description:** Format parsers inherit from harlowe_parser via direct require.

**Required Action:** Use composition over inheritance, or accept base parser via DI.

**Stage:** 11 (IFormat implementation)

---

### ISS-011: Missing Variable Module
**Category:** Architecture
**Severity:** Medium
**Location:** `lib/whisker/core/` (no variable.lua)

**Description:** The roadmap mentions a Variable module, but variables are stored as plain data in Story.variables. The v2.0 format supports typed variables but there's no Variable class.

**Required Action:** Evaluate if Variable class is needed or if current approach is sufficient.

**Stage:** 15

---

### ISS-012: Missing Test Infrastructure
**Category:** Testing
**Severity:** Medium
**Location:** `tests/` (missing `support/`, `contracts/`, `fixtures/`)

**Description:** Test infrastructure from roadmap doesn't exist:
- No `tests/support/mock_factory.lua`
- No `tests/support/test_container.lua`
- No `tests/contracts/` directory
- No `tests/fixtures/` directory (using `stories/examples/` instead)

**Required Action:** Create test infrastructure as specified in Stages 08-12.

**Stage:** 08-12

---

## Priority 4: Low - Nice to Have

### ISS-013: Condition Evaluation Embedded in Interpreter
**Category:** Architecture
**Severity:** Low
**Location:** `lib/whisker/core/lua_interpreter.lua:233-244`

**Description:** Condition evaluation is part of LuaInterpreter, not a separate IConditionEvaluator.

**Required Action:** Extract to separate service implementing IConditionEvaluator.

**Stage:** 20

---

### ISS-014: No Plugin System
**Category:** Architecture
**Severity:** Low
**Location:** N/A (not implemented)

**Description:** IPlugin interface defined in roadmap but no plugin system exists.

**Required Action:** Implement plugin loading after core infrastructure complete.

**Stage:** Post-Phase 1

---

### ISS-015: Renderer Accepts Interpreter via Setter
**Category:** Architecture
**Severity:** Low
**Location:** `lib/whisker/core/renderer.lua:81-83`

**Description:** Renderer uses setter injection instead of constructor injection:
```lua
function Renderer:set_interpreter(interpreter)
```

**Required Action:** Consider constructor injection for consistency.

**Stage:** 13 (Passage refactoring)

---

## Summary

| Priority | Count | Key Focus |
|----------|-------|-----------|
| Critical | 4 | Missing infrastructure, hardcoded deps |
| High | 4 | Wrong paths, event integration |
| Medium | 4 | Save system, parsers, testing |
| Low | 3 | Extraction, plugins |
| **Total** | **15** | |

---

## Issue-to-Stage Mapping

| Issue | Stage(s) |
|-------|----------|
| ISS-001 | 03-07 |
| ISS-002 | 04 |
| ISS-003 | 11 |
| ISS-004 | 18 |
| ISS-005 | 21 |
| ISS-006 | 06, 16-18 |
| ISS-007 | 13-16 |
| ISS-008 | N/A |
| ISS-009 | 17 |
| ISS-010 | 11 |
| ISS-011 | 15 |
| ISS-012 | 08-12 |
| ISS-013 | 20 |
| ISS-014 | Post-Phase 1 |
| ISS-015 | 13 |
