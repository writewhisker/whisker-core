# Interface Compliance Check

## Interface Definitions

### Available Interfaces (7 total)

Located in `/lib/whisker/interfaces/`:

1. **IFormat** (`format.lua`) - Story format import/export
2. **IState** (`state.lua`) - State management
3. **ISerializer** (`serializer.lua`) - Data serialization
4. **IConditionEvaluator** (`condition.lua`) - Condition evaluation
5. **IEngine** (`engine.lua`) - Story execution engine
6. **IPlugin** (`plugin.lua`) - Plugin system
7. **interfaces/init.lua** - Facade module

## Interface Implementations

### IFormat Implementations

**Implemented**:
- ✅ `formats/ink/converter.lua` - Ink format converter (partial)
- ✅ `formats/ink/exporter.lua` - Ink format exporter (partial)

**Missing Implementations**:
- ❌ No JSON format implementation
- ❌ No Twine format implementation implementing IFormat
- ❌ No Whisker native format implementation

**Current Format Modules (Not Using Interface)**:
```
format/whisker_format.lua       - Should implement IFormat
format/format_converter.lua     - Coordinator, not implementation
format/twine_importer.lua       - Should implement IFormat
format/whisker_loader.lua       - Should implement IFormat
format/compact_converter.lua    - Should implement IFormat
format/story_to_whisker.lua     - Utility, not format handler
format/parsers/*.lua            - Sub-parsers, not full implementations
format/converters/*.lua         - Sub-converters, not full implementations
```

**Analysis**:
The `format/` directory has 19 Lua files but NONE properly implement the IFormat interface. Instead, they use ad-hoc patterns and direct coupling.

**Recommendation**:
Create proper IFormat implementations:
```
formats/json/
  ├── init.lua          -- IFormat implementation
  └── serializer.lua    -- JSON serialization

formats/twine/
  ├── init.lua          -- IFormat implementation
  ├── harlowe.lua       -- Harlowe sub-parser
  ├── sugarcube.lua     -- SugarCube sub-parser
  └── ...

formats/whisker/
  ├── init.lua          -- IFormat implementation
  ├── compact.lua       -- Compact format variant
  └── verbose.lua       -- Verbose format variant
```

### IState Implementations

**Implemented**:
- ✅ `core/game_state.lua` - DOES NOT implement IState interface (uses own API)

**Missing**:
- ❌ No module implements IState interface

**Current State Modules**:
```
core/game_state.lua             - Has similar API but not interface-compliant
formats/ink/state_bridge.lua    - Bridges Ink state to GameState
```

**Analysis**:
`core/game_state.lua` has the functionality but doesn't formally implement IState.
It has its own API (`get()`, `set()`, `increment()`, etc.) instead of interface methods.

**IState Interface Methods** (from `interfaces/state.lua`):
```lua
-- Expected interface methods (need to verify actual interface)
function IState:initialize(story)
function IState:get_variable(name)
function IState:set_variable(name, value)
function IState:serialize()
function IState:deserialize(data)
```

**GameState Actual Methods**:
```lua
function GameState:initialize(story)      -- ✅ Match
function GameState:get(key, default)      -- ❌ Different signature
function GameState:set(key, value)        -- ❌ Different name
function GameState:serialize()            -- ✅ Match
function GameState:deserialize(data)      -- ✅ Match
function GameState:get_variable(key)      -- ✅ Alias exists (line 119)
function GameState:set_variable(key)      -- ✅ Alias exists (line 123)
```

**Status**: PARTIAL COMPLIANCE - Has aliases but not primary API

**Recommendation**: Refactor GameState to implement IState formally:
```lua
-- Add to core/game_state.lua
GameState._implements = { "whisker.interfaces.state" }

-- Already has these methods (good)
function GameState:get_variable(key, default_value)
    return self:get(key, default_value)
end

function GameState:set_variable(key, value)
    return self:set(key, value)
end
```

### ISerializer Implementations

**Implemented**:
- ❌ No modules implement ISerializer

**Current Serialization Modules**:
```
utils/json.lua                  - JSON encoding/decoding (should implement ISerializer)
format/compact_converter.lua    - Compact format serializer
```

**Missing**:
- No formal ISerializer implementations
- Multiple ad-hoc serialization approaches

**Recommendation**:
Create ISerializer implementations:
```lua
-- utils/serializers/json.lua
local JsonSerializer = {}
JsonSerializer._implements = { "whisker.interfaces.serializer" }

function JsonSerializer.new(deps)
    local json = require("whisker.utils.json")
    return {
        serialize = json.encode,
        deserialize = json.decode,
    }
end

return JsonSerializer
```

### IConditionEvaluator Implementations

**Implemented**:
- ❌ No modules implement IConditionEvaluator

**Current Condition Evaluation**:
```
core/lua_interpreter.lua        - Has evaluate_condition() method (line 210+)
core/engine.lua                 - Calls interpreter for conditions
```

**Analysis**:
`core/lua_interpreter.lua` evaluates conditions but doesn't implement the interface.

**Recommendation**:
Refactor lua_interpreter to implement IConditionEvaluator, or create adapter.

### IEngine Implementations

**Implemented**:
- ✅ `formats/ink/engine.lua` - Implements IEngine interface (uses DI)
- ❌ `core/engine.lua` - Does NOT implement IEngine interface

**Analysis**:
Two engine implementations, only one uses the interface:
1. `formats/ink/engine.lua` - Modern DI-based, interface-compliant
2. `core/engine.lua` - Legacy direct-require based, not interface-compliant

**IEngine Expected Methods**:
```lua
function IEngine:load_story(story_data)
function IEngine:start()
function IEngine:get_current_content()
function IEngine:make_choice(choice_index)
function IEngine:can_continue()
function IEngine:save_state()
function IEngine:restore_state(state)
```

**core/engine.lua Actual Methods**:
```lua
function Engine:load_story(story)           -- ✅ Match
function Engine:start_story(starting_passage_id) -- ❌ Different name
function Engine:get_current_content()       -- ✅ Match
function Engine:make_choice(choice_index)   -- ✅ Match
function Engine:navigate_to_passage(id)     -- ❌ Extra method
-- Missing: can_continue, save_state, restore_state
```

**Status**: NON-COMPLIANT

**Recommendation**:
Refactor core/engine.lua to implement IEngine or rename to WhiskerEngine and create IEngine wrapper.

### IPlugin Implementations

**Implemented**:
- ❌ No modules implement IPlugin

**Missing**:
- No plugin system implemented
- Interface exists but unused

**Recommendation**:
Future work - implement plugin system or remove unused interface.

## Compliance Matrix

| Interface | Implementations | Status | Priority |
|-----------|----------------|--------|----------|
| IFormat | 0 of 19 format modules | ❌ CRITICAL | HIGH |
| IState | 0 (GameState partial) | ⚠️ PARTIAL | HIGH |
| ISerializer | 0 of 2 serializers | ❌ MISSING | MEDIUM |
| IConditionEvaluator | 0 (LuaInterpreter exists) | ❌ MISSING | MEDIUM |
| IEngine | 1 of 2 engines | ⚠️ PARTIAL | HIGH |
| IPlugin | 0 | ❌ UNUSED | LOW |

**Overall Compliance**: 16% (1 of 6 interfaces properly used)

## Interface Usage Patterns

### Good Pattern (formats/ink/*)

```lua
-- formats/ink/engine.lua
local InkEngine = {}
InkEngine._dependencies = { "events", "state", "logger" }

function InkEngine.new(deps)
    local self = setmetatable({}, InkEngine)
    self.events = deps.events      -- Injected IEventBus
    self.state = deps.state        -- Injected IState
    self.log = deps.logger         -- Injected logger
    return self
end
```

**Status**: ✅ EXCELLENT
- Declares dependencies
- Uses DI container
- Depends on interfaces, not implementations
- No direct require() calls

### Bad Pattern (core/engine.lua)

```lua
-- core/engine.lua
function Engine.new(story, game_state, config)
    if not instance.game_state then
        local GameState = require("whisker.core.game_state")
        instance.game_state = GameState.new()
    end

    if not instance.interpreter then
        local LuaInterpreter = require("whisker.core.lua_interpreter")
        instance.interpreter = LuaInterpreter.new()
    end
end
```

**Status**: ❌ VIOLATION
- Direct require() of concrete classes
- No DI container usage
- Tight coupling to implementations
- Hard to test or substitute

## Missing Interface Implementations

### Critical (Blocking DI Adoption)

1. **IFormat implementations** for:
   - Whisker native format
   - Twine HTML format
   - JSON format

2. **IState compliance**:
   - Refactor GameState to implement IState properly

3. **IEngine compliance**:
   - Refactor core/Engine to implement IEngine

### Medium Priority

4. **ISerializer implementations** for:
   - JSON serializer
   - Compact format serializer
   - Binary serializer (future)

5. **IConditionEvaluator implementation**:
   - Wrap or refactor LuaInterpreter

### Low Priority

6. **IPlugin implementation**:
   - Design and implement plugin system
   - Or remove unused interface

## Recommended Refactoring Plan

### Phase 1: Core Interfaces (Week 1-2)

1. Make GameState implement IState
   ```lua
   -- core/game_state.lua
   local IState = require("whisker.interfaces.state")
   GameState._implements = { IState }
   -- Ensure all IState methods are implemented
   ```

2. Make core/Engine implement IEngine
   ```lua
   -- core/engine.lua
   local IEngine = require("whisker.interfaces.engine")
   Engine._implements = { IEngine }
   -- Add missing methods: can_continue, save_state, restore_state
   ```

### Phase 2: Format System (Week 3-4)

3. Create IFormat implementation for Whisker format
   ```lua
   -- formats/whisker/init.lua
   local WhiskerFormat = {}
   WhiskerFormat._dependencies = { "events" }
   WhiskerFormat._implements = { "whisker.interfaces.format" }

   function WhiskerFormat:can_import(data)
       -- Detect whisker JSON format
   end

   function WhiskerFormat:import(data)
       -- Parse whisker format
       return story, nil
   end

   function WhiskerFormat:export(story, options)
       -- Serialize to whisker format
       return json_data, nil
   end
   ```

4. Create IFormat implementation for Twine format
5. Create IFormat implementation for JSON format

### Phase 3: Utilities (Week 5)

6. Create ISerializer implementations
   ```lua
   -- formats/serializers/json.lua
   -- formats/serializers/compact.lua
   ```

7. Create IConditionEvaluator wrapper
   ```lua
   -- core/condition_evaluator.lua (wraps lua_interpreter)
   ```

## Testing Requirements

Each interface implementation should have:

1. **Contract Tests** - Verify interface compliance
   ```lua
   -- tests/contracts/iformat_spec.lua
   local function test_iformat_contract(implementation)
       it("should implement can_import", function()
           assert.is_function(implementation.can_import)
       end)
       -- ... test all interface methods
   end
   ```

2. **Integration Tests** - Test actual functionality
   ```lua
   -- tests/integration/whisker_format_spec.lua
   describe("WhiskerFormat", function()
       it("should import valid whisker JSON", function()
           local format = WhiskerFormat.new(deps)
           local story, err = format:import(test_data)
           assert.is_not_nil(story)
           assert.is_nil(err)
       end)
   end)
   ```

## Interface Grade: D

**Breakdown**:
- Interface definitions: A (well-designed)
- Interface adoption: F (16% compliance)
- Interface usage: A (formats/ink/*) or F (core/*)
- Overall: D (some good examples, but mostly unused)

**Critical Issues**:
1. 5 of 6 interfaces have zero implementations
2. 19 format modules ignore IFormat interface
3. Core modules don't use any interfaces
4. No contract testing

**Strengths**:
1. Interfaces are well-designed
2. formats/ink/* shows correct pattern
3. Interface facade module exists
4. Separation of concerns is clear

**Recommendation**: Major refactoring needed. Start with Phase 1 (Core Interfaces) to unblock DI adoption in core modules.
