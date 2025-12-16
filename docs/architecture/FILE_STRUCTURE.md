# Target File Structure

**Phase 1: Foundation & Modularity Architecture**
**Created:** Stage 02 - Refactoring Plan
**Reference:** Roadmap Section 0.5

This document defines the target file organization for whisker-core after Phase 1 refactoring.

---

## Directory Layout

```
lib/whisker/
├── kernel/                     # Microkernel (< 200 lines total)
│   ├── init.lua               # Bootstrap, version, module registry
│   ├── container.lua          # Dependency injection container
│   ├── events.lua             # Event bus implementation
│   ├── registry.lua           # Generic registry pattern
│   ├── loader.lua             # Module loader and validation
│   ├── capabilities.lua       # Feature flag system
│   └── errors.lua             # Kernel error definitions
│
├── interfaces/                 # Pure interface definitions (no implementation)
│   ├── init.lua               # Interface utilities, validation
│   ├── format.lua             # IFormat - story format handlers
│   ├── state.lua              # IState - state management
│   ├── engine.lua             # IEngine - runtime engine
│   ├── serializer.lua         # ISerializer - data serialization
│   ├── condition.lua          # IConditionEvaluator - condition evaluation
│   └── plugin.lua             # IPlugin - plugin contract
│
├── core/                       # Core data structures (minimal deps)
│   ├── story.lua              # Story container
│   ├── passage.lua            # Passage representation
│   ├── choice.lua             # Choice handling
│   └── variable.lua           # Variable types (if created)
│
├── services/                   # Service implementations
│   ├── state/
│   │   └── init.lua           # IState implementation (from game_state.lua)
│   ├── history/
│   │   └── init.lua           # Navigation history service
│   └── conditions/
│       └── init.lua           # IConditionEvaluator implementation
│
├── engines/                    # IEngine implementations
│   └── default.lua            # Default engine (from core/engine.lua)
│
├── format/                     # Existing format handlers (to implement IFormat)
│   ├── whisker_format.lua
│   ├── whisker_loader.lua
│   ├── twine_importer.lua
│   ├── format_converter.lua
│   ├── compact_converter.lua
│   ├── story_to_whisker.lua
│   └── parsers/               # Format-specific parsers
│       ├── harlowe.lua
│       ├── snowman.lua
│       ├── chapbook.lua
│       └── sugarcube.lua
│
├── infrastructure/             # System infrastructure
│   ├── save_system.lua
│   ├── file_storage.lua
│   ├── file_system.lua
│   ├── asset_manager.lua
│   └── input_handler.lua
│
├── runtime/                    # Platform runtimes
│   ├── cli_runtime.lua
│   ├── desktop_runtime.lua
│   └── web_runtime.lua
│
├── tools/                      # Developer tools
│   ├── validator.lua
│   ├── debugger.lua
│   └── profiler.lua
│
├── utils/                      # Utility functions
│   ├── json.lua
│   ├── file_utils.lua
│   ├── string_utils.lua
│   └── template_processor.lua
│
├── ui/                         # UI components
│   ├── console.lua
│   └── ui_framework.lua
│
├── parser/                     # Whisker script parser
│   ├── lexer.lua
│   └── parser.lua
│
├── editor/                     # Editor components (Phase 2+)
│   ├── core/
│   └── export/
│
└── compat/                     # Backward compatibility shims (NEW)
    ├── init.lua               # Compatibility utilities
    └── engine.lua             # Old Engine API wrapper
```

---

## Test Directory Layout

```
spec/                           # Unit tests (mirror lib structure)
├── kernel/
│   ├── init_spec.lua
│   ├── container_spec.lua
│   ├── events_spec.lua
│   ├── registry_spec.lua
│   └── loader_spec.lua
├── interfaces/
│   └── validation_spec.lua
├── core/
│   ├── story_spec.lua
│   ├── passage_spec.lua
│   └── choice_spec.lua
├── services/
│   ├── state_spec.lua
│   └── conditions_spec.lua
└── engines/
    └── default_spec.lua

tests/                          # Integration and contract tests
├── support/                    # Test utilities (NEW)
│   ├── mock_factory.lua
│   ├── test_container.lua
│   └── helpers.lua
├── contracts/                  # Interface contract tests (NEW)
│   ├── format_contract.lua
│   ├── state_contract.lua
│   └── engine_contract.lua
├── fixtures/                   # Test data (NEW)
│   ├── stories/
│   └── formats/
├── integration/                # Integration tests
│   └── full_stack_spec.lua
└── [existing test files]       # Keep existing tests
```

---

## Module Metadata Convention

Every module exports a `_whisker` metadata table:

```lua
local MyModule = {}

-- Implementation...

MyModule._whisker = {
  name = "my_module",           -- Unique identifier
  version = "1.0.0",            -- Semantic version
  implements = "IMyInterface",  -- Interface implemented (if any)
  depends = {"other_module"},   -- Required dependencies
  capability = "my_feature"     -- Capability flag name
}

return MyModule
```

---

## Key Changes from Current Structure

| Change | Current | Target |
|--------|---------|--------|
| Add | N/A | `lib/whisker/kernel/` |
| Add | N/A | `lib/whisker/interfaces/` |
| Add | N/A | `lib/whisker/services/` |
| Add | N/A | `lib/whisker/engines/` |
| Add | N/A | `lib/whisker/compat/` |
| Add | N/A | `spec/kernel/` |
| Add | N/A | `tests/support/` |
| Add | N/A | `tests/contracts/` |
| Add | N/A | `tests/fixtures/` |
| Move | `core/engine.lua` | `engines/default.lua` |
| Move | `core/game_state.lua` | `services/state/init.lua` |
| Keep | All existing files | Backward compatible |
