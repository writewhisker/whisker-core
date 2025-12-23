# Using Ink with Whisker-Core

This guide covers everything you need to know about using Ink stories with whisker-core.

## Introduction

Whisker-core provides full support for Ink, the narrative scripting language created by Inkle Studios. Ink is a powerful tool for creating interactive fiction, and whisker-core's integration allows you to:

- Load and run compiled Ink JSON stories
- Access Ink variables through Whisker's state system
- Bind Lua functions to Ink external functions
- Save and restore story state
- Export Whisker stories to Ink format

## Quick Start

### Loading an Ink Story

```lua
local whisker = require("whisker")
local InkEngine = require("whisker.formats.ink.engine")

-- Create container with dependencies
local container = whisker.create_container()

-- Create engine
local engine = InkEngine.new({
  events = container:resolve("events"),
  state = container:resolve("state"),
  logger = container:resolve("logger"),
})

-- Load Ink JSON
local json = read_file("story.ink.json")
engine:load(json)

-- Start the story
engine:start()

-- Play loop
while engine:can_continue() do
  local text = engine:continue()
  print(text)

  local choices = engine:get_choices()
  if #choices > 0 then
    for i, choice in ipairs(choices) do
      print(i .. ". " .. choice.text)
    end

    local input = tonumber(io.read())
    engine:make_choice(input)
  end
end

print("The End")
```

### Compiling Ink Source

Before using an Ink story with whisker-core, you need to compile it to JSON:

```bash
# Install inklecate (Ink compiler)
npm install -g inkjs

# Compile .ink to .json
inklecate story.ink -o story.ink.json
```

## Features

### Variables

Ink variables are automatically synchronized with Whisker's state system:

```lua
-- Get Ink variable directly
local health = engine:get_variable("health")

-- Set Ink variable
engine:set_variable("health", 100)

-- Also accessible via Whisker state (prefixed with "ink.")
local state = container:resolve("state")
local health = state:get("ink.health")
state:set("ink.health", 75)  -- Syncs back to Ink
```

### Variable Observation

Watch for variable changes:

```lua
-- Observe a specific variable
local unsubscribe = engine:observe_variable("health", function(name, old_val, new_val)
  print(name .. " changed from " .. tostring(old_val) .. " to " .. tostring(new_val))
end)

-- Observe all variables
engine:observe_variable("*", function(name, old_val, new_val)
  print("Variable changed: " .. name)
end)

-- Stop observing
unsubscribe()
```

### Tags

Access tags from Ink content:

```lua
local text, tags = engine:continue()

for _, tag in ipairs(tags) do
  print("Tag: " .. tag)
end

-- Tags are also available on choices
local choices = engine:get_choices()
for _, choice in ipairs(choices) do
  if #choice.tags > 0 then
    print("Choice tags: " .. table.concat(choice.tags, ", "))
  end
end
```

### External Functions

Bind Lua functions callable from Ink:

```lua
-- Bind a function
engine:bind_external_function("get_time", function()
  return os.date("%H:%M")
end, true)  -- true = lookahead safe

-- Bind with arguments
engine:bind_external_function("calculate_damage", function(base, modifier)
  return base * modifier
end, false)  -- false = not lookahead safe
```

In your Ink story:

```ink
EXTERNAL get_time()
EXTERNAL calculate_damage(base, modifier)

The time is {get_time()}.
You take {calculate_damage(10, 1.5)} damage.
```

### Navigation

Navigate to specific story locations:

```lua
-- Go to a specific knot
engine:go_to_path("chapter_2")

-- Go to a knot and stitch
engine:go_to_path("chapter_2.intro")

-- Check if a knot exists
if engine:has_function("secret_ending") then
  engine:go_to_path("secret_ending")
end
```

### Evaluate Functions

Call Ink functions directly:

```lua
-- Evaluate a function defined in Ink
local result, text_output = engine:evaluate_function("calculate_score")

print("Result: " .. tostring(result))
print("Output: " .. text_output)
```

### Save/Load

Save and restore story state:

```lua
-- Save current state
local saved_state = engine:save_state()

-- Write to file
local json = require("cjson")
write_file("savegame.json", json.encode(saved_state))

-- Later, restore
local loaded = json.decode(read_file("savegame.json"))
engine:restore_state(loaded)
```

### Multi-Flow (Threads)

Work with parallel narrative flows:

```lua
-- Get current flow
local flow = engine:get_current_flow()

-- Switch to a different flow
engine:switch_flow("background_music")

-- Get all active flows
local flows = engine:get_alive_flows()

-- Remove a flow
engine:remove_flow("old_flow")
```

## IFormat Interface

whisker-core provides an IFormat implementation for Ink:

```lua
local InkFormat = require("whisker.formats.ink")

local format = InkFormat.new({
  events = events,
  logger = logger,
})

-- Check if content is Ink
if format:can_import(json_string) then
  local story = format:import(json_string)
end

-- Export Whisker story to Ink
if format:can_export(story) then
  local json = format:export(story)
end
```

## Events

The Ink engine emits events during execution:

| Event | Description |
|-------|-------------|
| `ink:loaded` | Story JSON loaded |
| `ink:started` | Story started |
| `ink:continued` | Story continued (text available) |
| `ink:choices_available` | Choices are ready |
| `ink:choice_made` | A choice was selected |
| `ink:variable_changed` | Variable value changed |
| `ink:path_changed` | Navigation occurred |
| `ink:flow_switched` | Active flow changed |
| `ink:state_restored` | State was restored |
| `ink:reset` | Engine was reset |

Listen for events:

```lua
local events = container:resolve("events")

events:on("ink:choices_available", function(data)
  print("There are " .. data.count .. " choices")
end)

events:on("ink:variable_changed", function(data)
  print(data.name .. " = " .. tostring(data.value))
end)
```

## Limitations

See [EXPORT_LIMITATIONS.md](../formats/ink/EXPORT_LIMITATIONS.md) for details on:

- Features not supported in export
- Round-trip conversion fidelity
- Known issues

## Best Practices

### 1. Error Handling

Always check for errors when loading:

```lua
local ok, err = engine:load(json)
if not ok then
  print("Error loading story: " .. err)
  return
end
```

### 2. State Management

Use the state bridge for persistence:

```lua
-- Save both Ink state and Whisker state together
local ink_state = engine:save_state()
local whisker_state = container:resolve("state"):snapshot()

local full_save = {
  ink = ink_state,
  whisker = whisker_state,
}
```

### 3. External Function Safety

Mark external functions correctly:

```lua
-- Lookahead-safe functions have no side effects
engine:bind_external_function("get_random", math.random, false)  -- NOT safe

-- Side-effect-free functions are safe
engine:bind_external_function("get_name", function() return player.name end, true)
```

## Troubleshooting

### Story won't load

1. Verify the JSON is valid
2. Check inkVersion is 19, 20, or 21
3. Ensure the file has a `root` key

### Choices not appearing

1. Make sure you've called `continue()` until `can_continue()` is false
2. Check that choices aren't conditionally hidden
3. Verify once-only choices haven't been consumed

### Variables not syncing

1. Ensure state bridge is set up (happens automatically if state is in container)
2. Check variable names don't have typos
3. Verify variables are declared in Ink (`VAR health = 100`)

## Further Reading

- [Ink Documentation](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md)
- [Whisker API Reference](../api/INK_API.md)
- [Getting Started Tutorial](../tutorials/INK_GETTING_STARTED.md)
- [Examples](../../examples/ink/)
