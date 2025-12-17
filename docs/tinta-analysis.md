# tinta Architecture Analysis

Analysis of the tinta Lua Ink runtime for whisker-core integration.

**Repository:** https://github.com/smwhr/tinta
**License:** MIT
**Purpose:** Lua implementation of inkle's Ink scripting language runtime

---

## Directory Structure

```
tinta/source/
├── compat/           # Platform compatibility utilities
├── constants/        # Constant definitions
├── engine/           # Core runtime engine
│   ├── call_stack/   # Call stack implementation
│   ├── call_stack.lua
│   ├── flow.lua
│   ├── ink_header.lua
│   ├── pointer.lua
│   ├── state_patch.lua
│   ├── story.lua
│   ├── story_state.lua
│   └── variables_state.lua
├── libs/             # Utility libraries
├── tests/            # Test files
├── values/           # Value type implementations
│   ├── base.lua
│   ├── boolean.lua
│   ├── choice.lua
│   ├── choice_point.lua
│   ├── container.lua
│   ├── control_command.lua
│   ├── create.lua
│   ├── divert.lua
│   ├── divert_target.lua
│   ├── float.lua
│   ├── glue.lua
│   ├── integer.lua
│   ├── native_function.lua
│   ├── path.lua
│   ├── search_result.lua
│   ├── string.lua
│   ├── tag.lua
│   ├── variable_assignment.lua
│   ├── variable_pointer.lua
│   ├── variable_reference.lua
│   └── void.lua
├── love.lua          # LÖVE2D platform entry
├── picotron.lua      # Picotron platform entry
├── playdate.lua      # Playdate SDK entry
└── run.lua           # Generic runner
```

---

## Core Engine Components

### Story (`engine/story.lua`)

The main entry point for story execution. Manages the complete lifecycle of an Ink story.

**Constructor:**
```lua
local story = Story(storyDefinition)  -- storyDefinition is pre-converted Lua table
```

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `Continue()` | Advances story by one line, returns text |
| `ContinueAsync(ms)` | Async continuation with time budget |
| `ContinueMaximally()` | Continues until no more content |
| `canContinue()` | Checks if more content available |
| `ChooseChoiceIndex(idx)` | Selects a choice by index |
| `ChoosePathString(path)` | Navigates to specific location |
| `currentText()` | Gets current text output |
| `currentTags()` | Gets current metadata tags |
| `currentChoices()` | Gets available choices |
| `BindExternalFunction(name, fn, safe)` | Binds Lua function |
| `ObserveVariable(name, observer)` | Watches variable changes |
| `SwitchFlow(name)` | Changes active flow |
| `HasFunction(name)` | Checks function existence |
| `EvaluateFunction(name, args)` | Calls Ink function |

### StoryState (`engine/story_state.lua`)

Maintains all runtime state including position, variables, and output.

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `currentPathString()` | Returns current location as path |
| `currentText()` | Gets rendered output |
| `currentTags()` | Gets current tags |
| `currentChoices()` | Gets available choices |
| `VisitCountAtPathString(path)` | Gets visit count |
| `save()` | Serializes state to table |
| `load(data)` | Restores state from table |
| `GoToStart()` | Resets to story beginning |
| `ForceEnd()` | Ends current flow |
| `SwitchFlow(name)` | Changes active flow |

### VariablesState (`engine/variables_state.lua`)

Handles all variable storage, assignment, and observation.

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `GetVariableWithName(name)` | Gets variable value |
| `SetGlobal(name, value)` | Sets global variable |
| `GlobalVariableExistsWithName(name)` | Checks existence |
| `Assign(varAss, value)` | Assigns via descriptor |
| `variableChangedEvent` | Change notification delegate |
| `save()` / `load()` | Serialization |

### CallStack (`engine/call_stack.lua`)

Manages execution stack for function calls, tunnels, and threads.

**Key Responsibilities:**
- Function call/return tracking
- Tunnel entry/exit management
- Thread context management
- Temporary variable scoping

### Flow (`engine/flow.lua`)

Represents a parallel execution context with independent callstack.

**Key Features:**
- Each flow has own callstack
- Shares global variables across flows
- DEFAULT_FLOW always exists
- Flows support save/restore

---

## Value Types (`values/`)

| File | Type | Description |
|------|------|-------------|
| `base.lua` | Base | Abstract base for all values |
| `boolean.lua` | Boolean | true/false values |
| `integer.lua` | Integer | Whole numbers |
| `float.lua` | Float | Decimal numbers |
| `string.lua` | String | Text values |
| `void.lua` | Void | Null/empty value |
| `choice.lua` | Choice | Player choice representation |
| `choice_point.lua` | ChoicePoint | Decision point in story |
| `container.lua` | Container | Content container/array |
| `divert.lua` | Divert | Navigation command |
| `divert_target.lua` | DivertTarget | Navigation target |
| `glue.lua` | Glue | Whitespace control |
| `tag.lua` | Tag | Metadata tag |
| `path.lua` | Path | Story location path |
| `control_command.lua` | ControlCommand | Runtime instruction |
| `native_function.lua` | NativeFunction | Built-in operation |
| `variable_assignment.lua` | VariableAssignment | Assignment operation |
| `variable_pointer.lua` | VariablePointer | Variable reference |
| `variable_reference.lua` | VariableReference | Named variable access |
| `search_result.lua` | SearchResult | Path search result |
| `create.lua` | Factory | Value creation utilities |

---

## Module Loading Pattern

tinta uses a custom `import()` function instead of standard `require()`:

```lua
-- tinta pattern
local Story = import('tinta/engine/story')

-- Must be adapted to whisker-core pattern
local Story = require('whisker.vendor.tinta.engine.story')
```

**Adaptation Required:**
1. Replace all `import()` calls with `require()`
2. Update path separators (`/` to `.`)
3. Add whisker.vendor.tinta prefix

---

## JSON Conversion

tinta requires pre-conversion of ink.json to Lua tables:

```bash
# Original workflow
./json_to_lua.sh story.ink.json story.lua
```

**For whisker-core integration:**
- Implement native JSON loading in `json_loader.lua`
- Parse JSON at runtime, convert to tinta's expected format
- Eliminate need for pre-conversion step

---

## State Serialization Format

tinta's `state:save()` returns a Lua table containing:

```lua
{
  callstackThreads = {...},     -- CallStack state
  outputStream = {...},          -- Current output
  currentChoices = {...},        -- Available choices
  variablesState = {...},        -- All variables
  evalStack = {...},             -- Evaluation stack
  currentTurnIndex = number,     -- Turn counter
  storySeed = number,            -- Random seed
  previousRandom = number,       -- Last random value
  inkSaveVersion = number,       -- Format version
}
```

---

## Extension Points

### External Functions

```lua
story:BindExternalFunction("functionName", function(args)
  -- args is a TABLE, access via args[1], args[2], etc.
  return result
end, true)  -- true = lookahead safe
```

### Variable Observers

```lua
story:ObserveVariable("varName", function(varName, newValue)
  -- Called when variable changes
end)
```

### Custom Ink Functions

```lua
if story:HasFunction("myFunction") then
  local result = story:EvaluateFunction("myFunction", {arg1, arg2})
end
```

---

## Adaptation Requirements for whisker-core

### High Priority

1. **Module Loading**: Convert `import()` to `require()` throughout
2. **JSON Loading**: Implement native JSON parsing (eliminate json_to_lua.sh)
3. **Entry Point**: Create `init.lua` exporting Story constructor

### Medium Priority

4. **Error Handling**: Wrap tinta errors in whisker-core error format
5. **Event Integration**: Bridge tinta callbacks to whisker-core event bus
6. **State Adapter**: Wrap VariablesState to implement IState interface

### Low Priority

7. **Platform Code**: Remove Playdate/Picotron-specific code paths
8. **Documentation**: Add JSDoc-style comments for whisker-core docs

---

## Interface Mapping Summary

| tinta Component | whisker-core Interface | Adaptation Strategy |
|-----------------|----------------------|---------------------|
| Story | IEngine | Wrap with InkEngine adapter |
| StoryState.save/load | IState.snapshot/restore | Direct mapping |
| VariablesState | IState | Wrap with InkState adapter |
| Story(definition) | IFormat.import | Wrap with InkFormat |
| currentChoices | Choice[] | Map to whisker Choice |
| currentTags | Passage.metadata | Extract to passage |
| BindExternalFunction | Custom API | Expose via InkEngine |
| ObserveVariable | Event bus | Bridge to ink.variable.changed |

---

## Notes

- tinta is designed for Playdate's constraints (memory, performance)
- No external dependencies (pure Lua)
- Supports Lua 5.1+ and LuaJIT
- MIT licensed - compatible with whisker-core's MIT license
- Active maintenance as of 2024
