# Module Inventory

**Generated:** Stage 01 - Repository Audit
**Date:** 2025-12-16
**Total Modules:** 51 Lua files in `lib/whisker/`

---

## Summary by Directory

| Directory | File Count | Purpose |
|-----------|------------|---------|
| `core/` | 8 | Core data structures and engine |
| `format/` | 11 | Format handlers and converters |
| `format/parsers/` | 4 | Twine format parsers |
| `format/converters/` | 4 | Twine format converters |
| `infrastructure/` | 5 | System infrastructure |
| `runtime/` | 3 | Platform runtimes |
| `tools/` | 3 | Developer tools |
| `utils/` | 4 | Utility functions |
| `ui/` | 2 | UI components |
| `parser/` | 2 | Whisker parser |
| `editor/` | 4 | Editor components |

---

## Core Modules (`lib/whisker/core/`)

### story.lua
- **Purpose:** Story data structure with passages, variables, assets, and metadata
- **Lines:** ~530
- **Dependencies:** `whisker.core.passage` (in deserialize/from_table)
- **Key Classes:** `Story`
- **Modularity Issues:** Direct require of Passage in deserialize methods

### passage.lua
- **Purpose:** Passage representation with content, choices, and metadata
- **Lines:** ~253
- **Dependencies:** `whisker.core.choice` (in deserialize/from_table)
- **Key Classes:** `Passage`
- **Modularity Issues:** Direct require of Choice in deserialize methods

### choice.lua
- **Purpose:** Choice handling with conditions and actions
- **Lines:** ~182
- **Dependencies:** None (standalone)
- **Key Classes:** `Choice`
- **Modularity Issues:** None - pure data structure

### engine.lua
- **Purpose:** Story engine with navigation and script execution
- **Lines:** ~296
- **Dependencies:** `whisker.core.story`, `whisker.core.game_state`, `whisker.core.lua_interpreter`
- **Key Classes:** `Engine`
- **Modularity Issues:** Multiple direct requires, creates dependencies internally

### game_state.lua
- **Purpose:** Complete state management with undo/redo and serialization
- **Lines:** ~222
- **Dependencies:** None (standalone)
- **Key Classes:** `GameState`
- **Modularity Issues:** None - pure state container

### event_system.lua
- **Purpose:** Pub/sub event system for game events
- **Lines:** ~372
- **Dependencies:** None (standalone)
- **Key Classes:** `EventSystem`
- **Modularity Issues:** None - standalone implementation

### lua_interpreter.lua
- **Purpose:** Secure Lua sandbox with instruction counting
- **Lines:** ~280
- **Dependencies:** None (uses Lua debug library)
- **Key Classes:** `LuaInterpreter`
- **Modularity Issues:** None - standalone sandbox

### renderer.lua
- **Purpose:** Text rendering with formatting and variable evaluation
- **Lines:** ~444
- **Dependencies:** None (accepts interpreter via setter)
- **Key Classes:** `Renderer`
- **Modularity Issues:** None - uses dependency injection

### instruction_counter.lua
- **Purpose:** Instruction counting for sandbox
- **Lines:** ~50 (estimated)
- **Dependencies:** None
- **Modularity Issues:** None

---

## Format Modules (`lib/whisker/format/`)

### whisker_format.lua
- **Purpose:** Whisker JSON schema definition (v2.0)
- **Lines:** ~434
- **Dependencies:** None
- **Key Classes:** `whiskerFormat`
- **Modularity Issues:** None - schema definitions only

### whisker_loader.lua
- **Purpose:** Load Whisker JSON files to Story objects
- **Lines:** ~326
- **Dependencies:** `whisker.core.story`, `whisker.core.passage`, `whisker.core.choice`, `whisker.utils.json`, `whisker.format.compact_converter`
- **Key Functions:** `load_from_file`, `load_from_string`
- **Modularity Issues:** Multiple hardcoded requires at module level

### twine_importer.lua
- **Purpose:** Import Twine HTML files
- **Lines:** ~200 (estimated)
- **Dependencies:** `whisker.format.whisker_format`
- **Modularity Issues:** Direct require of whisker_format

### format_converter.lua
- **Purpose:** Central format conversion hub
- **Lines:** ~200 (estimated)
- **Dependencies:** `whisker.format.story_to_whisker`, `whisker.format.whisker_format`, `whisker.format.twine_importer`
- **Modularity Issues:** Multiple hardcoded requires

### story_to_whisker.lua
- **Purpose:** Convert Story to Whisker JSON format
- **Lines:** ~100 (estimated)
- **Dependencies:** `whisker.utils.json`
- **Modularity Issues:** Direct require of json

### compact_converter.lua
- **Purpose:** Compact binary format conversion
- **Lines:** ~350 (estimated)
- **Dependencies:** `whisker.utils.json` (optional)
- **Modularity Issues:** Conditional require

### harlowe_parser.lua, snowman_parser.lua, chapbook_parser.lua, sugarcube_parser.lua
- **Purpose:** Parse Twine format-specific syntax
- **Dependencies:** Various format parsers depend on harlowe_parser as base
- **Modularity Issues:** Inheritance via require

---

## Format Parsers (`lib/whisker/format/parsers/`)

### harlowe.lua
- **Purpose:** Harlowe format parser
- **Dependencies:** None
- **Modularity Issues:** None

### snowman.lua, chapbook.lua, sugarcube.lua
- **Purpose:** Format-specific parsers
- **Dependencies:** `whisker.format.parsers.harlowe`
- **Modularity Issues:** Direct inheritance from harlowe

---

## Format Converters (`lib/whisker/format/converters/`)

### harlowe.lua, snowman.lua, chapbook.lua, sugarcube.lua
- **Purpose:** Convert format-specific syntax to Whisker
- **Dependencies:** Various
- **Modularity Issues:** Direct requires

---

## Infrastructure Modules (`lib/whisker/infrastructure/`)

### save_system.lua
- **Purpose:** Save/load game state
- **Lines:** ~216
- **Dependencies:** `whisker.utils.json`, `whisker.core.story`, `whisker.core.game_state`, `whisker.utils.file_utils`
- **Modularity Issues:** Multiple requires inside methods

### file_storage.lua
- **Purpose:** File storage abstraction
- **Dependencies:** None
- **Modularity Issues:** None

### file_system.lua
- **Purpose:** File system operations
- **Dependencies:** None
- **Modularity Issues:** None

### asset_manager.lua
- **Purpose:** Asset management
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

### input_handler.lua
- **Purpose:** Input handling
- **Dependencies:** None
- **Modularity Issues:** None

---

## Runtime Modules (`lib/whisker/runtime/`)

### cli_runtime.lua
- **Purpose:** Command-line runtime
- **Dependencies:** `src.core.engine` (wrong path), `src.utils.json`, `src.utils.template_processor`
- **Modularity Issues:** Uses old `src.*` paths instead of `whisker.*`

### desktop_runtime.lua
- **Purpose:** Desktop (LÖVE2D) runtime
- **Dependencies:** `src.core.engine` (wrong path), `src.utils.json`
- **Modularity Issues:** Uses old `src.*` paths

### web_runtime.lua
- **Purpose:** Web runtime
- **Dependencies:** `whisker`, `json`, `whisker.utils.template_processor`
- **Modularity Issues:** Requires top-level `whisker` module

---

## Tools (`lib/whisker/tools/`)

### validator.lua
- **Purpose:** Story validation and analysis
- **Lines:** ~614
- **Dependencies:** None
- **Modularity Issues:** None - standalone tool

### debugger.lua
- **Purpose:** Interactive debugger
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

### profiler.lua
- **Purpose:** Performance profiler
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

---

## Utilities (`lib/whisker/utils/`)

### json.lua
- **Purpose:** JSON encode/decode
- **Dependencies:** None
- **Modularity Issues:** None

### file_utils.lua
- **Purpose:** File operations
- **Dependencies:** `whisker.utils.json`
- **Modularity Issues:** Direct require of json

### string_utils.lua
- **Purpose:** String utilities
- **Dependencies:** None
- **Modularity Issues:** None

### template_processor.lua
- **Purpose:** Template processing
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

---

## UI Modules (`lib/whisker/ui/`)

### console.lua
- **Purpose:** Console UI
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

### ui_framework.lua
- **Purpose:** UI framework abstraction
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

---

## Parser Modules (`lib/whisker/parser/`)

### lexer.lua
- **Purpose:** Whisker syntax lexer
- **Dependencies:** None
- **Modularity Issues:** None

### parser.lua
- **Purpose:** Whisker syntax parser
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

---

## Editor Modules (`lib/whisker/editor/`)

### editor/core/project.lua
- **Purpose:** Project management
- **Dependencies:** `json` (global)
- **Modularity Issues:** Assumes global json library

### editor/core/passage_manager.lua
- **Purpose:** Passage editing
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

### editor/export/exporter.lua
- **Purpose:** Story export
- **Dependencies:** `json` (global)
- **Modularity Issues:** Assumes global json library

### editor/validation/validator.lua
- **Purpose:** Editor validation
- **Dependencies:** Unknown
- **Modularity Issues:** Unknown

---

## Dependency Graph (Key Relationships)

```
whisker_loader
├── whisker.core.story
│   └── whisker.core.passage
│       └── whisker.core.choice
├── whisker.core.passage
├── whisker.core.choice
├── whisker.utils.json
└── whisker.format.compact_converter

engine
├── whisker.core.story
├── whisker.core.game_state
└── whisker.core.lua_interpreter

save_system
├── whisker.utils.json
├── whisker.core.story
├── whisker.core.game_state
└── whisker.utils.file_utils

format_converter
├── whisker.format.story_to_whisker
├── whisker.format.whisker_format
└── whisker.format.twine_importer
```

---

## Notes

- **Total Lines of Code (estimated):** ~6,000+ lines in `lib/whisker/`
- **Test Files:** 43 test files in `tests/`
- **Test Results:** 689 passing, 0 failures, 2 pending
- **Missing:** No `Variable` class (variables are plain data, not objects)
