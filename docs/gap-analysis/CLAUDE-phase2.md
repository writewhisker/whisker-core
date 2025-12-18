# CLAUDE.md — Phase 2: Ink Integration

## Project Context

This is **whisker-core**, a Lua-based interactive fiction framework. You are working on **Phase 2: Ink Integration**, which adds support for Inkle's Ink narrative scripting language.

**Repository:** https://github.com/writewhisker/whisker-core
**Phase:** 2 of 7
**Prerequisites:** Phase 1 (Foundation & Modularity) must be complete

## Phase 2 Objectives

1. Vendor the tinta library (Lua port of Ink runtime) into whisker-core
2. Adapt tinta to use whisker-core's interfaces (IFormat, IState, IEngine)
3. Create bidirectional conversion: Ink ↔ Whisker native format
4. Emit events through whisker-core's event bus
5. Register all components with the DI container
6. Test with real-world Ink projects

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    whisker-core                          │
├─────────────────────────────────────────────────────────┤
│  lib/whisker/formats/ink/                               │
│  ├── format.lua      → IInkFormat (implements IFormat)  │
│  ├── engine.lua      → InkEngine (implements IEngine)   │
│  ├── state.lua       → InkState (implements IState)     │
│  ├── converter.lua   → Ink-to-Whisker conversion        │
│  ├── exporter.lua    → Whisker-to-Ink export            │
│  └── ...                                                │
├─────────────────────────────────────────────────────────┤
│  lib/whisker/vendor/tinta/    (vendored, minimal mods)  │
│  ├── engine/story.lua                                   │
│  ├── engine/state.lua                                   │
│  └── ...                                                │
└─────────────────────────────────────────────────────────┘
```

## Key Interfaces

All Ink components must implement whisker-core interfaces from `lib/whisker/interfaces/`.

### IFormat (format.lua)
```lua
IFormat = {
  can_import = function(self, source) end,  -- Returns boolean
  import = function(self, source) end,       -- Returns Story
  can_export = function(self, story) end,    -- Returns boolean
  export = function(self, story) end,        -- Returns string/bytes
}
```

### IEngine (engine.lua)
```lua
IEngine = {
  load = function(self, story) end,
  start = function(self) end,
  get_current_passage = function(self) end,
  get_available_choices = function(self) end,
  make_choice = function(self, index) end,
  can_continue = function(self) end,
}
```

### IState (state.lua)
```lua
IState = {
  get = function(self, key) end,
  set = function(self, key, value) end,
  has = function(self, key) end,
  clear = function(self) end,
  snapshot = function(self) end,
  restore = function(self, snapshot) end,
}
```

## Directory Structure

```
lib/whisker/
├── kernel/                    # Phase 1 - DO NOT MODIFY
│   ├── container.lua          # DI container
│   ├── events.lua             # Event bus
│   └── ...
├── interfaces/                # Phase 1 - Reference only
│   ├── format.lua
│   ├── engine.lua
│   ├── state.lua
│   └── ...
├── core/                      # Phase 1 - Reference only
│   ├── story.lua
│   ├── passage.lua
│   ├── choice.lua
│   └── variable.lua
├── formats/
│   └── ink/                   # PHASE 2 - Your work goes here
│       ├── init.lua
│       ├── format.lua
│       ├── engine.lua
│       ├── state.lua
│       ├── story.lua
│       ├── json_loader.lua
│       ├── converter.lua
│       ├── exporter.lua
│       ├── externals.lua
│       ├── flows.lua
│       ├── events.lua
│       ├── validator.lua
│       ├── compare.lua
│       ├── transformers/
│       │   ├── init.lua
│       │   ├── knot.lua
│       │   ├── stitch.lua
│       │   ├── choice.lua
│       │   ├── variable.lua
│       │   ├── logic.lua
│       │   ├── tunnel.lua
│       │   └── thread.lua
│       └── generators/
│           ├── init.lua
│           ├── passage.lua
│           ├── choice.lua
│           ├── divert.lua
│           ├── variable.lua
│           └── logic.lua
└── vendor/
    └── tinta/                 # PHASE 2 - Vendored library
        ├── init.lua
        ├── VERSION
        ├── engine/
        │   ├── story.lua
        │   ├── state.lua
        │   ├── callstack.lua
        │   ├── variables_state.lua
        │   └── flow.lua
        └── values/
            ├── value.lua
            └── list.lua

spec/formats/ink/              # PHASE 2 - Tests
├── format_spec.lua
├── engine_spec.lua
├── state_spec.lua
├── story_spec.lua
├── json_loader_spec.lua
├── converter_spec.lua
├── exporter_spec.lua
├── externals_spec.lua
├── flows_spec.lua
├── events_spec.lua
├── choices_spec.lua
├── roundtrip_spec.lua
└── integration_spec.lua

test/fixtures/ink/             # PHASE 2 - Test data
├── minimal.json
├── choices.json
├── variables.json
├── conditionals.json
├── tunnels.json
├── flows.json
├── metadata.json
├── externals.json
├── stitches.json
└── real_world/
    └── intercept/
```

## Coding Conventions

### Module Pattern
```lua
-- lib/whisker/formats/ink/example.lua
local Example = {}
Example.__index = Example

function Example.new(dependencies)
  local self = setmetatable({}, Example)
  self.container = dependencies.container
  self.events = dependencies.events
  return self
end

function Example:some_method()
  -- Implementation
end

return Example
```

### DI Container Registration
```lua
-- In init.lua or during bootstrap
local container = require("whisker.kernel.container")

container:register("format.ink", InkFormat, {
  implements = "IFormat",
  singleton = true,
  depends = {"events"}
})
```

### Event Emission
```lua
local events = self.container:resolve("events")

events:emit("ink.story.loaded", {
  story = story,
  path = file_path,
  format = "ink"
})
```

### Error Handling
```lua
-- Use pcall for external operations
local ok, result = pcall(function()
  return json.decode(content)
end)

if not ok then
  error("Failed to parse ink.json: " .. tostring(result))
end
```

## Ink-Whisker Concept Mapping

| Ink | Whisker | Notes |
|-----|---------|-------|
| Knot (`=== name ===`) | Passage | `type = "knot"` |
| Stitch (`= name`) | Passage | `parent` reference to knot |
| Choice (`*`) | Choice | `once = true, sticky = false` |
| Sticky (`+`) | Choice | `once = false, sticky = true` |
| Divert (`->`) | Link | Target passage ID |
| VAR | Variable | Global scope |
| temp | Variable | Function/tunnel scope |
| Tag (`#`) | Metadata | Attached to passage/choice |
| Tunnel (`->->`) | Passage + CallStack | Special handling |
| Thread (`<-`) | GatheredContent | Parallel eval |

## tinta Adaptation Notes

### Module Loading
tinta uses custom `import()`. Convert to standard `require()`:
```lua
-- Original tinta
local Story = import("tinta/engine/story")

-- Adapted for whisker-core
local Story = require("whisker.vendor.tinta.engine.story")
```

### Story Initialization
```lua
local tinta = require("whisker.vendor.tinta")
local story_def = json_loader.load(path)  -- Returns Lua table
local story = tinta.Story(story_def)
```

### Key tinta APIs
```lua
-- Continuation
story:canContinue()           -- Boolean
story:Continue()              -- Returns text
story:ContinueAsync(ms)       -- Async version
story:asyncContinueComplete() -- Check async status

-- Choices
story.currentChoices          -- Array of choice objects
story:ChooseChoiceIndex(idx)  -- Select choice (1-indexed)

-- Navigation
story:ChoosePathString(path)  -- Jump to path

-- State
story.state:save()            -- Returns Lua table
story.state:load(data)        -- Restore from table

-- Variables
story.variablesState["name"]           -- Get
story.variablesState["name"] = value   -- Set

-- Observers
story:ObserveVariable("name", function(name, value) end)

-- External Functions
story:BindExternalFunction("name", function(args) end)

-- Flows
story:SwitchFlow("name")
story:RemoveFlow("name")
story:currentFlowName()
story:aliveFlowNames()
```

## Testing Guidelines

### Test Framework
Using **busted** for all tests.

### Running Tests
```bash
# All Ink tests
busted spec/formats/ink/

# Specific test file
busted spec/formats/ink/engine_spec.lua

# With coverage
busted --coverage spec/formats/ink/
```

### Test Structure
```lua
-- spec/formats/ink/example_spec.lua
describe("Example", function()
  local Example
  local mock_container
  
  before_each(function()
    Example = require("whisker.formats.ink.example")
    mock_container = {
      resolve = function(name) return {} end
    }
  end)
  
  describe("new", function()
    it("creates instance with dependencies", function()
      local instance = Example.new({ container = mock_container })
      assert.is_not_nil(instance)
    end)
  end)
  
  describe("some_method", function()
    it("does expected behavior", function()
      local instance = Example.new({ container = mock_container })
      local result = instance:some_method()
      assert.equals("expected", result)
    end)
  end)
end)
```

### Contract Tests
Every interface implementation must pass contract tests:
```lua
-- spec/contracts/format_contract.lua is reusable
local contract = require("spec.contracts.format_contract")
local InkFormat = require("whisker.formats.ink.format")

contract(InkFormat, {
  valid_source = load_fixture("ink/minimal.json"),
  invalid_source = "not json",
  expected_passage_count = 1
})
```

### Test Coverage Target
- **80%+ coverage** for all new code
- All public methods must have tests
- Edge cases documented in tests

## Common Tasks

### Adding a New Transformer
1. Create `lib/whisker/formats/ink/transformers/new_type.lua`
2. Implement transform function
3. Register in `transformers/init.lua`
4. Add tests in `spec/formats/ink/new_type_converter_spec.lua`
5. Add test fixture in `test/fixtures/ink/`

### Adding a New Generator
1. Create `lib/whisker/formats/ink/generators/new_type.lua`
2. Implement generate function
3. Register in `generators/init.lua`
4. Add tests in `spec/formats/ink/new_type_exporter_spec.lua`

### Adding Event Types
1. Define in `lib/whisker/formats/ink/events.lua`
2. Document payload structure
3. Emit from appropriate location
4. Add test verifying emission

## Ink JSON Format Reference

### Basic Structure
```json
{
  "inkVersion": 21,
  "root": [
    "^Hello, world!",
    "\n",
    ["done", null]
  ]
}
```

### Control Commands
- `"ev"` — Start evaluation mode
- `"/ev"` — End evaluation mode
- `"str"` — Start string building
- `"/str"` — End string building
- `"out"` — Output to stream
- `"pop"` — Pop from stack
- `"done"` — End section
- `"end"` — End story
- `"nop"` — No operation

### Content Types
- `"^text"` — String literal (^ prefix)
- `5`, `3.14` — Numbers
- `true`, `false` — Booleans
- `{"->": "target"}` — Divert
- `{"*": "choice_path", "flg": 4}` — Choice point
- `{"VAR?": "name"}` — Variable lookup
- `{"VAR=": "name"}` — Variable assignment

### Reference Documentation
- Ink JSON format: https://github.com/inkle/ink/blob/master/Documentation/ink_JSON_runtime_format.md
- Ink architecture: https://github.com/inkle/ink/blob/master/Documentation/ArchitectureAndDevOverview.md
- tinta source: https://github.com/smwhr/tinta

## Debugging Tips

### Inspect tinta State
```lua
local state = story.state
print("Can continue:", story:canContinue())
print("Current text:", story:currentText())
print("Choices:", #story.currentChoices)
print("Flow:", story:currentFlowName())
```

### Trace Event Flow
```lua
events:on("*", function(event_name, data)
  print("EVENT:", event_name, vim.inspect(data))
end)
```

### Validate Converted Story
```lua
local validator = require("whisker.formats.ink.validator")
local report = validator:validate(converted_story)
if not report.valid then
  for _, err in ipairs(report.errors) do
    print("ERROR:", err.message)
  end
end
```

## Dependencies

### Required (Phase 1)
- `lib/whisker/kernel/container.lua` — DI container
- `lib/whisker/kernel/events.lua` — Event bus
- `lib/whisker/interfaces/*.lua` — Interface definitions
- `lib/whisker/core/*.lua` — Core data structures

### External
- JSON library (cjson, dkjson, or similar)
- busted (testing)
- luacov (coverage)

## Files NOT to Modify

These files are from Phase 1 and should be treated as stable APIs:

- `lib/whisker/kernel/*` — Microkernel infrastructure
- `lib/whisker/interfaces/*` — Interface definitions
- `lib/whisker/core/*` — Core data structures
- `spec/contracts/*` — Contract test suites

## Quick Reference: Stage Checklist

For each stage, ensure:

- [ ] All tasks from stage definition completed
- [ ] New files created in correct locations
- [ ] Interfaces properly implemented
- [ ] DI container registration added
- [ ] Events emitted for significant operations
- [ ] Unit tests written (80%+ coverage)
- [ ] Contract tests pass (if implementing interface)
- [ ] All tests pass: `busted spec/formats/ink/`
- [ ] Code follows module pattern conventions
- [ ] No modifications to Phase 1 files

## Getting Help

- **Ink Language:** https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md
- **tinta Issues:** https://github.com/smwhr/tinta/issues
- **whisker-core Roadmap:** See `docs/whisker-core-roadmap.md`
- **Phase 2 Stages:** See `PHASE_2_IMPLEMENTATION.md`
