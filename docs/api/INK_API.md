# Ink Integration API Reference

Complete API documentation for whisker-core's Ink integration.

## InkEngine

Main engine for executing Ink stories.

### Constructor

```lua
InkEngine.new(deps) → InkEngine
```

Creates a new Ink engine instance.

**Parameters:**
- `deps` (table): Dependencies table
  - `deps.events` (EventBus): Event bus for notifications
  - `deps.state` (IState): Whisker state for variable sync
  - `deps.logger` (Logger): Logger instance

**Returns:** InkEngine instance

**Example:**
```lua
local engine = InkEngine.new({
  events = container:resolve("events"),
  state = container:resolve("state"),
  logger = container:resolve("logger"),
})
```

---

### load(json_text)

Load Ink JSON into the engine.

```lua
engine:load(json_text) → boolean, string|nil
```

**Parameters:**
- `json_text` (string): Compiled Ink JSON string

**Returns:**
- `success` (boolean): True if loaded successfully
- `error` (string|nil): Error message if failed

**Throws:** None (returns error message instead)

**Emits:** `ink:loaded`

---

### start(knot_name)

Start story execution.

```lua
engine:start(knot_name) → boolean, string|nil
```

**Parameters:**
- `knot_name` (string|nil): Optional starting knot name

**Returns:**
- `success` (boolean): True if started
- `error` (string|nil): Error message if failed

**Emits:** `ink:started`

---

### can_continue()

Check if the story can continue.

```lua
engine:can_continue() → boolean
```

**Returns:** True if `continue()` can be called

---

### continue()

Continue the story and get the next line of text.

```lua
engine:continue() → string|nil, table|nil
```

**Returns:**
- `text` (string|nil): The text content
- `tags` (table|nil): Array of tags for this line

**Emits:** `ink:continued`

---

### continue_maximally()

Continue until choices or end, collecting all text.

```lua
engine:continue_maximally() → string, table
```

**Returns:**
- `text` (string): All combined text
- `tags` (table): All tags encountered

---

### get_current_text()

Get the current text (after Continue).

```lua
engine:get_current_text() → string
```

**Returns:** Current text content

---

### get_current_tags()

Get current tags.

```lua
engine:get_current_tags() → table
```

**Returns:** Array of tag strings

---

### get_choices()

Get available choices.

```lua
engine:get_choices() → table
```

**Returns:** Array of choice objects:
```lua
{
  index = 1,           -- 1-based index
  text = "Go north",   -- Choice text
  tags = {},           -- Choice tags
  original = {...},    -- Raw Ink choice
}
```

**Emits:** `ink:choices_available` (if choices exist)

---

### make_choice(index)

Select a choice by index.

```lua
engine:make_choice(index) → boolean, string|nil
```

**Parameters:**
- `index` (number): 1-based choice index

**Returns:**
- `success` (boolean): True if choice was made
- `error` (string|nil): Error message if failed

**Emits:** `ink:choice_made`

---

### has_ended()

Check if the story has ended.

```lua
engine:has_ended() → boolean
```

**Returns:** True if story is complete

---

### get_variable(name)

Get an Ink variable value.

```lua
engine:get_variable(name) → any
```

**Parameters:**
- `name` (string): Variable name

**Returns:** Variable value (string, number, boolean, or nil)

---

### set_variable(name, value)

Set an Ink variable value.

```lua
engine:set_variable(name, value)
```

**Parameters:**
- `name` (string): Variable name
- `value` (any): New value

**Emits:** `ink:variable_changed`

---

### get_variable_names()

Get all global variable names.

```lua
engine:get_variable_names() → table
```

**Returns:** Array of variable name strings

---

### observe_variable(name, callback)

Watch a variable for changes.

```lua
engine:observe_variable(name, callback) → function
```

**Parameters:**
- `name` (string): Variable name, or "*" for all
- `callback` (function): Called with (name, old_value, new_value)

**Returns:** Unsubscribe function

---

### bind_external_function(name, fn, lookahead_safe)

Bind a Lua function callable from Ink.

```lua
engine:bind_external_function(name, fn, lookahead_safe)
```

**Parameters:**
- `name` (string): Function name in Ink
- `fn` (function): Lua function to call
- `lookahead_safe` (boolean): True if function has no side effects

---

### unbind_external_function(name)

Remove an external function binding.

```lua
engine:unbind_external_function(name)
```

---

### go_to_path(path, reset_callstack)

Navigate to a specific story path.

```lua
engine:go_to_path(path, reset_callstack) → boolean, string|nil
```

**Parameters:**
- `path` (string): Path like "knot" or "knot.stitch"
- `reset_callstack` (boolean): Reset call stack (default: true)

**Emits:** `ink:path_changed`

---

### evaluate_function(function_name, ...)

Call an Ink function and get its result.

```lua
engine:evaluate_function(function_name, ...) → any, string
```

**Parameters:**
- `function_name` (string): Name of Ink function
- `...` (any): Arguments to pass

**Returns:**
- `result` (any): Return value from function
- `text_output` (string): Any text produced

---

### has_function(name)

Check if a knot/function exists.

```lua
engine:has_function(name) → boolean
```

---

### save_state()

Save the current engine state.

```lua
engine:save_state() → table, string|nil
```

**Returns:**
- `state` (table): Serializable state
- `error` (string|nil): Error if save failed

---

### restore_state(state)

Restore a saved state.

```lua
engine:restore_state(state) → boolean, string|nil
```

**Emits:** `ink:state_restored`

---

### reset()

Reset the engine to initial state.

```lua
engine:reset()
```

**Emits:** `ink:reset`

---

### get_current_flow()

Get the current flow name.

```lua
engine:get_current_flow() → string
```

---

### switch_flow(flow_name)

Switch to a different flow.

```lua
engine:switch_flow(flow_name) → boolean
```

**Emits:** `ink:flow_switched`

---

### get_alive_flows()

Get all active flow names.

```lua
engine:get_alive_flows() → table
```

---

### is_loaded()

Check if a story is loaded.

```lua
engine:is_loaded() → boolean
```

---

### is_started()

Check if the story has started.

```lua
engine:is_started() → boolean
```

---

## InkFormat

IFormat implementation for Ink.

### Constructor

```lua
InkFormat.new(deps) → InkFormat
```

**Parameters:**
- `deps.events` (EventBus): Event bus
- `deps.logger` (Logger): Logger

---

### get_name()

```lua
format:get_name() → "ink"
```

---

### get_extensions()

```lua
format:get_extensions() → {".ink.json", ".json"}
```

---

### get_mime_type()

```lua
format:get_mime_type() → "application/json"
```

---

### can_import(source)

Check if source is Ink JSON.

```lua
format:can_import(source) → boolean
```

---

### import(source)

Import Ink JSON to Whisker story.

```lua
format:import(source) → Story, string|nil
```

**Emits:** `format:imported`

---

### can_export(story)

Check if story can be exported to Ink.

```lua
format:can_export(story) → boolean
```

---

### export(story)

Export Whisker story to Ink JSON.

```lua
format:export(story) → string, string|nil
```

**Emits:** `format:exported`

---

## Events Reference

### ink:loaded

Emitted when Ink JSON is loaded.

```lua
{
  metadata = {
    inkVersion = 21,
    hasVariables = true,
  }
}
```

### ink:started

Emitted when story execution starts.

```lua
{
  knot = "chapter_1"  -- or nil
}
```

### ink:continued

Emitted after each continue.

```lua
{
  text = "Hello, world!",
  tags = {"speaker:narrator"},
}
```

### ink:choices_available

Emitted when choices are presented.

```lua
{
  count = 3,
  choices = {...},
}
```

### ink:choice_made

Emitted when a choice is selected.

```lua
{
  index = 1,
  text = "Go north",
}
```

### ink:variable_changed

Emitted when a variable changes.

```lua
{
  name = "health",
  old_value = 100,
  value = 75,
}
```

### ink:path_changed

Emitted on navigation.

```lua
{
  path = "chapter_2.intro",
}
```

### ink:flow_switched

Emitted on flow change.

```lua
{
  flow = "background",
}
```

### ink:state_restored

Emitted after state restore.

```lua
{}
```

### ink:reset

Emitted after engine reset.

```lua
{}
```

---

## StateBridge

Bidirectional sync between Ink and Whisker state.

### Constructor

```lua
StateBridge.new(ink_engine, whisker_state, events) → StateBridge
```

### sync_all()

Sync all Ink variables to Whisker state.

```lua
bridge:sync_all()
```

### get(name)

Get variable from Whisker state.

```lua
bridge:get(name) → any
```

### set(name, value)

Set variable (syncs to Ink).

```lua
bridge:set(name, value)
```

### snapshot()

Create snapshot of all Ink variables.

```lua
bridge:snapshot() → table
```

### restore(snap)

Restore from snapshot.

```lua
bridge:restore(snap)
```

### destroy()

Clean up and unsubscribe.

```lua
bridge:destroy()
```

---

## ChoiceMapper

Utility for choice format conversion.

### to_whisker(ink_choices)

Convert Ink choices to Whisker format.

```lua
ChoiceMapper.to_whisker(ink_choices) → table
```

### filter_visible(choices)

Filter to visible choices only.

```lua
ChoiceMapper.filter_visible(choices) → table
```

### has_tag(choice, tag)

Check if choice has a specific tag.

```lua
ChoiceMapper.has_tag(choice, tag) → boolean
```
