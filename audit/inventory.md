# Code Inventory

## Summary

- **Total Lua Files**: 67 (excluding vendor/)
- **Estimated Lines of Code**: ~12,000-15,000 (needs precise count)
- **Test Files**: 0 (no files in tests/ or spec/ directories)
- **Code-to-Test Ratio**: 67:0 (CRITICAL: No tests exist)

## Files by Directory

### Core (9 files)
```
/lib/whisker/core/
├── choice.lua
├── engine.lua
├── event_system.lua
├── game_state.lua
├── instruction_counter.lua
├── lua_interpreter.lua
├── passage.lua
├── renderer.lua
└── story.lua
```

**Status**: Core domain models and engine. Contains direct module dependencies (coupling violations).

### Kernel (6 files)
```
/lib/whisker/kernel/
├── bootstrap.lua
├── container.lua
├── events.lua
├── init.lua
├── loader.lua
└── registry.lua
```

**Status**: DI infrastructure complete and well-designed.

### Interfaces (7 files)
```
/lib/whisker/interfaces/
├── condition.lua
├── engine.lua
├── format.lua
├── init.lua
├── plugin.lua
├── serializer.lua
└── state.lua
```

**Status**: Interface definitions complete.

### Formats (6 files)
```
/lib/whisker/formats/
└── ink/
    ├── choice_mapper.lua
    ├── converter.lua
    ├── engine.lua
    ├── exporter.lua
    ├── init.lua
    └── state_bridge.lua
```

**Status**: Ink format implementation. Uses DI pattern correctly.

### Format Parsers (19 files)
```
/lib/whisker/format/
├── chapbook_parser.lua
├── compact_converter.lua
├── format_converter.lua
├── harlow_parser.lua
├── snowman_converter.lua
├── snowman_parser.lua
├── story_to_whisker.lua
├── sugarcube_parser.lua
├── twine_importer.lua
├── whisker_format.lua
├── whisker_loader.lua
├── converters/
│   ├── chapbook.lua
│   ├── harlowe.lua
│   ├── snowman.lua
│   └── sugarcube.lua
└── parsers/
    ├── chapbook.lua
    ├── harlowe.lua
    ├── snowman.lua
    └── sugarcube.lua
```

**Status**: Twine format converters. Contains coupling violations.

### Script Compiler (6 files)
```
/lib/whisker/script/
├── ast.lua
├── compiler.lua
├── errors.lua
├── init.lua
├── lexer.lua
└── parser.lua
```

**Status**: Whisker script DSL compiler. Contains coupling violations.

### Infrastructure (5 files)
```
/lib/whisker/infrastructure/
├── asset_manager.lua
├── file_storage.lua
├── file_system.lua
├── input_handler.lua
└── save_system.lua
```

**Status**: Platform services. Contains coupling violations.

### Parser (2 files)
```
/lib/whisker/parser/
├── lexer.lua
└── parser.lua
```

**Status**: Generic parser infrastructure.

### Services (0 files)
```
/lib/whisker/services/
├── history/  (empty)
├── persistence/  (empty)
├── state/  (empty)
└── variables/  (empty)
```

**Status**: PLANNED but not implemented.

### Utils (4 files)
```
/lib/whisker/utils/
├── file_utils.lua
├── json.lua
├── string_utils.lua
└── template_processor.lua
```

**Status**: Utility libraries. Contains coupling violations.

### Runtime (3 files)
```
/lib/whisker/runtime/
├── cli_runtime.lua
├── desktop_runtime.lua
└── web_runtime.lua
```

**Status**: Platform-specific runtimes.

### Tools (4 files)
```
/lib/whisker/tools/
├── debugger.lua
├── profiler.lua
├── validator.lua
└── whiskerc/
    └── init.lua
```

**Status**: Development tools.

### UI (2 files)
```
/lib/whisker/ui/
├── console.lua
└── ui_framework.lua
```

**Status**: UI components.

### Editor (4 files)
```
/lib/whisker/editor/
├── core/
│   ├── passage_manager.lua
│   └── project.lua
├── export/
│   └── exporter.lua
└── validation/
    └── validator.lua
```

**Status**: Editor functionality.

## Modules (Returns a table)

All 67 files return Lua module tables. Key architectural modules:

- **Container-based**: `formats/ink/*` (6 modules)
- **Direct require**: `core/*` (9 modules) - VIOLATION
- **Direct require**: `format/*` (19 modules) - VIOLATION
- **Direct require**: `infrastructure/*` (5 modules) - VIOLATION
- **Direct require**: `script/*` (6 modules) - VIOLATION

## Critical Gaps

1. **No Tests**: Zero test coverage despite 67 modules
2. **Empty Services**: `services/` subdirectories planned but empty
3. **Coupling Violations**: ~45 of 67 modules use direct `require()` instead of DI
4. **No Format/JSON/Twine Services**: These directories exist but are empty

## Recommendations

1. **Immediate**: Write tests for kernel modules (container, events, registry)
2. **High Priority**: Refactor core/ to use DI container
3. **Medium Priority**: Implement services/ modules
4. **Low Priority**: Refactor format parsers to use DI
