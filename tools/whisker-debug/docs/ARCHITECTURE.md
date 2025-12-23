# Whisker Debug Adapter Architecture

## Overview

whisker-debug is a Debug Adapter Protocol (DAP) implementation for the whisker-core interactive fiction framework. It enables interactive debugging of stories with breakpoints, step execution, variable inspection, and call stack navigation.

## Design Goals

1. **Standalone Adapter**: Run as separate process communicating via stdin/stdout
2. **Non-invasive Instrumentation**: Wrap runtime without modifying whisker-core source
3. **Editor Agnostic**: Works with any DAP-compatible editor (VSCode, Neovim, etc.)
4. **Low Overhead**: Minimal performance impact during normal execution

## Architectural Decisions

### AD1: Standalone Debug Adapter

**Decision**: Implement whisker-debug as standalone process.

**Rationale**:
- Consistent with whisker-lsp design
- Editor-agnostic (works with any DAP client)
- Testable via JSON message mocking
- Fault isolation (adapter crash doesn't crash editor)

### AD2: Runtime Instrumentation

**Decision**: Wrap whisker-core runtime with instrumentation hooks.

**Implementation**:
```lua
local original_goto = runtime.goto_passage

function runtime:goto_passage(name)
  if debugger:has_breakpoint(name) then
    debugger:pause({passage = name, state = self:get_state()})
    debugger:wait_for_continue()
  end
  return original_goto(self, name)
end
```

### AD3: Single Thread Model

**Decision**: Model story execution as single thread (threadId = 1).

**Rationale**: Interactive fiction is inherently single-threaded.

### AD4: Stack Frame Design

**Decision**: Represent passage navigation as DAP stack frames.

**Mapping**:
- Frame ID: Incremental integer (1 for current, 2 for caller, etc.)
- Frame Name: Passage name
- Source: File path and line number of passage header
- Line: Current line within passage

### AD5: Variable Scope Design

**Decision**: Organize variables into three scopes.

**Scopes**:
- **Globals**: Persistent variables (player_health, inventory)
- **Locals**: Variables scoped to current passage
- **Temps**: Temporary variables from conditionals

### AD6: Breakpoint Storage

**Decision**: Store breakpoints as map: `file_path -> {line_number -> breakpoint_info}`

**Rationale**: O(1) lookup during execution.

## Component Architecture

```
┌─────────────────────────────────────────────────────┐
│                  whisker-debug                       │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────┐      ┌──────────────────┐    │
│  │ DAP Adapter      │─────▶│ Breakpoint Mgr   │    │
│  │ (message handler)│      │ (store/lookup)   │    │
│  └────────┬─────────┘      └──────────────────┘    │
│           │                                          │
│           │ controls                                 │
│           ▼                                          │
│  ┌──────────────────────────────────────────────┐   │
│  │         Runtime Wrapper                       │   │
│  │  (instrumented whisker.runtime)               │   │
│  ├──────────────────────────────────────────────┤   │
│  │ - goto_passage (with breakpoint checks)       │   │
│  │ - choose (with step-into support)             │   │
│  │ - get_state (for variable inspection)         │   │
│  └─────────────────┬────────────────────────────┘   │
│                    │ uses                            │
│                    ▼                                 │
│  ┌──────────────────────────────────────────────┐   │
│  │         whisker.runtime                       │   │
│  │  (core execution engine)                      │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
└─────────────────────────────────────────────────────┘
         ▲                                    │
         │ DAP protocol (stdin/stdout)        │
         │                                    ▼
┌────────┴────────┐              ┌──────────────────┐
│  VSCode Debug   │              │  whisker.runtime │
│  Client         │              │  (unmodified)    │
└─────────────────┘              └──────────────────┘
```

## Components

### 1. DAP Adapter (dap_adapter.lua)

Main entry point handling DAP protocol messages.

**Responsibilities**:
- Parse incoming DAP requests from stdin
- Dispatch to appropriate handlers
- Send responses and events to stdout
- Manage adapter lifecycle

**Key Methods**:
- `handle_message(msg)`: Route message to handler
- `send_response(request, body)`: Send success response
- `send_event(event, body)`: Send event notification
- `send_error(request, message)`: Send error response

### 2. Breakpoint Manager (breakpoint_manager.lua)

Stores and manages breakpoint state.

**Responsibilities**:
- Store breakpoints by file and line
- Verify breakpoint locations against AST
- Support conditional breakpoints
- Track hit counts

**Key Methods**:
- `set_breakpoints(uri, breakpoints)`: Set breakpoints for file
- `has_breakpoint(uri, line)`: Check if breakpoint exists
- `check_condition(bp, state)`: Evaluate conditional breakpoint
- `clear_breakpoints(uri)`: Remove all breakpoints for file

### 3. Runtime Wrapper (runtime_wrapper.lua)

Instruments whisker-core runtime for debugging.

**Responsibilities**:
- Wrap passage navigation with breakpoint checks
- Track call stack for stack trace generation
- Support step commands (into, over, out)
- Pause and resume execution

**Key Methods**:
- `wrap_runtime(runtime)`: Instrument runtime instance
- `pause(reason, data)`: Pause execution at breakpoint
- `continue()`: Resume execution
- `step_into()`: Step to next statement
- `step_out()`: Continue until caller

### 4. Variable Serializer (variable_serializer.lua)

Converts Lua values to DAP variable format.

**Responsibilities**:
- Serialize Lua tables to DAP variables
- Handle nested structures with variable references
- Support type information display
- Evaluate expressions in debug console

**Key Methods**:
- `serialize_value(value)`: Convert value to DAP format
- `get_variables(reference)`: Get children of container
- `evaluate_expression(expr, frame)`: Evaluate debug expression

### 5. Stack Frame Manager (stack_frame_manager.lua)

Manages passage call stack for stack traces.

**Responsibilities**:
- Track passage navigation history
- Generate DAP stack frames
- Map frames to source locations
- Support frame-specific variable scopes

**Key Methods**:
- `push_frame(passage, source, line)`: Add frame to stack
- `pop_frame()`: Remove top frame
- `get_stack_trace()`: Generate DAP stack frames
- `get_frame(id)`: Get specific frame

## DAP Message Flow

### Launch Sequence

```
Client                           Adapter
   │                                │
   │──── initialize ───────────────▶│
   │◀─── initialized event ─────────│
   │                                │
   │──── launch ───────────────────▶│  Load story, instrument runtime
   │◀─── launch response ───────────│
   │                                │
   │──── setBreakpoints ───────────▶│  Store and verify breakpoints
   │◀─── breakpoints response ──────│
   │                                │
   │──── configurationDone ────────▶│
   │◀─── configurationDone resp ────│
   │                                │
   │                                │  Start execution
   │                                │  Hit breakpoint
   │                                │
   │◀─── stopped event ─────────────│
   │                                │
   │──── threads ──────────────────▶│
   │◀─── threads response ──────────│
   │                                │
   │──── stackTrace ───────────────▶│
   │◀─── stackFrames response ──────│
   │                                │
   │──── scopes ───────────────────▶│
   │◀─── scopes response ───────────│
   │                                │
   │──── variables ────────────────▶│
   │◀─── variables response ────────│
   │                                │
   │──── continue ─────────────────▶│  Resume execution
   │◀─── continued event ───────────│
   │                                │
```

### Breakpoint Hit Flow

1. Runtime calls `goto_passage("Combat")`
2. Wrapper intercepts and checks `has_breakpoint("story.ink", line 35)`
3. Breakpoint found → pause execution
4. Send `stopped` event to client with reason "breakpoint"
5. Wait for continue/step command via semaphore
6. Client requests stack trace, variables
7. User clicks continue
8. Release semaphore, resume execution

## Breakpoint Types

### Line Breakpoints

Set on specific lines within passages.

**Supported Locations**:
- Passage headers (`=== Name ===` or `:: Name`)
- Choice lines (`* [text] -> target`)
- Divert lines (`-> target`)
- Macro calls (`<<macro>>`)

**Unsupported Locations**:
- Plain text lines (no executable code)
- Comment lines

### Conditional Breakpoints

Break only if expression evaluates to true.

```lua
function check_condition(breakpoint, state)
  if not breakpoint.condition then
    return true  -- No condition, always break
  end

  local func, err = load("return " .. breakpoint.condition, "bp", "t", state)
  if not func then
    return false  -- Invalid condition, don't break
  end

  local ok, result = pcall(func)
  return ok and result
end
```

### Hit Count Breakpoints

Break after N hits.

```lua
function check_hit_count(breakpoint)
  breakpoint.hits = (breakpoint.hits or 0) + 1

  if breakpoint.hitCondition then
    -- Parse hit condition (e.g., ">= 5", "== 3")
    local op, value = breakpoint.hitCondition:match("([<>=]+)%s*(%d+)")
    value = tonumber(value)

    if op == ">=" then return breakpoint.hits >= value end
    if op == "==" then return breakpoint.hits == value end
    if op == ">" then return breakpoint.hits > value end
  end

  return true
end
```

## Step Commands

### Continue

Resume execution until next breakpoint or story end.

```lua
function continue()
  self.step_mode = nil
  self.step_depth = nil
  self:release_pause()
end
```

### Step Into

Execute current statement and stop at next executable line.

```lua
function step_into()
  self.step_mode = "into"
  self:release_pause()
  -- Will stop at next passage entry or choice
end
```

### Step Over

Execute current statement without entering subpassages.

For interactive fiction, same as Step Into (no function calls).

### Step Out

Resume until returning to caller passage.

```lua
function step_out()
  self.step_mode = "out"
  self.step_depth = #self.call_stack - 1
  self:release_pause()
  -- Will stop when call stack depth reaches step_depth
end
```

## Variable Inspection

### Serialization Format

```lua
-- Lua state
{
  player_health = 100,
  inventory = {"sword", "potion"},
  visited = {START = true}
}

-- DAP format
{
  {
    name = "player_health",
    value = "100",
    type = "number",
    variablesReference = 0
  },
  {
    name = "inventory",
    value = "table[2]",
    type = "table",
    variablesReference = 1001
  },
  {
    name = "visited",
    value = "table[1]",
    type = "table",
    variablesReference = 1002
  }
}
```

### Nested Tables

When client requests variablesReference 1001:

```lua
{
  {name = "[1]", value = "\"sword\"", type = "string", variablesReference = 0},
  {name = "[2]", value = "\"potion\"", type = "string", variablesReference = 0}
}
```

### Scope Organization

```lua
scopes = {
  {name = "Globals", variablesReference = 1000, expensive = false},
  {name = "Locals", variablesReference = 2000, expensive = false},
  {name = "Temps", variablesReference = 3000, expensive = false}
}
```

## Integration Points

### Required whisker.runtime APIs

1. `runtime:goto_passage(name)` - Navigate to passage
2. `runtime:choose(index)` - Select choice
3. `runtime:get_state()` - Get current state
4. `runtime:get_current_passage()` - Get current passage
5. `runtime:get_choices()` - Get available choices

### VSCode launch.json Configuration

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "whisker",
      "request": "launch",
      "name": "Debug Story",
      "program": "${file}",
      "stopOnEntry": false
    }
  ]
}
```

## File Structure

```
tools/whisker-debug/
├── whisker-debug.lua        # Main entry point
├── lib/
│   ├── dap_adapter.lua      # DAP protocol handler
│   ├── breakpoint_manager.lua
│   ├── runtime_wrapper.lua
│   ├── variable_serializer.lua
│   ├── stack_frame_manager.lua
│   └── interfaces.lua       # Interface definitions
├── docs/
│   └── ARCHITECTURE.md      # This document
├── diagrams/
│   ├── dap-flow.mmd         # Message flow diagram
│   ├── breakpoint-check.mmd # Breakpoint check flow
│   └── stack-frames.mmd     # Stack frame representation
└── tests/
    ├── breakpoint_manager_spec.lua
    ├── runtime_wrapper_spec.lua
    └── variable_serializer_spec.lua
```
