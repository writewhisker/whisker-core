# PluginContext Reference

## Overview

The PluginContext (`ctx`) is passed to all plugin lifecycle hooks and provides controlled access to framework functionality. Access is limited by declared capabilities.

## Properties

### name

**Type:** `string`

**Description:** Plugin name

**Example:**
```lua
on_init = function(ctx)
  print("Plugin: " .. ctx.name)
end
```

### version

**Type:** `string`

**Description:** Plugin version

## Logging

### ctx.log

Logging interface with level-based methods.

#### debug(message)

Log debug-level message (verbose, development only).

```lua
ctx.log.debug("Processing item: " .. item.id)
```

#### info(message)

Log informational message.

```lua
ctx.log.info("Plugin initialized successfully")
```

#### warn(message)

Log warning message.

```lua
ctx.log.warn("Deprecated API used")
```

#### error(message)

Log error message.

```lua
ctx.log.error("Failed to load data: " .. err)
```

## Storage

### ctx.storage

Plugin-specific key-value storage. Data persists automatically with story saves.

**Required Capability:** `persistence:read` and/or `persistence:write`

#### get(key)

Retrieve value by key.

```lua
local value = ctx.storage.get("my_data")
if value then
  -- Use value
end
```

#### set(key, value)

Store value by key.

```lua
ctx.storage.set("counter", 42)
ctx.storage.set("items", {"sword", "shield"})
ctx.storage.set("config", {enabled = true, level = 5})
```

#### clear()

Remove all stored data.

```lua
ctx.storage.clear()
```

## State

### ctx.state

Access to story variables.

**Required Capability:** `state:read` and/or `state:write`

#### get(name)

Read story variable.

```lua
local health = ctx.state.get("health")
local player_name = ctx.state.get("player_name")
```

#### set(name, value)

Write story variable.

```lua
ctx.state.set("health", 100)
ctx.state.set("visited_cave", true)
```

#### watch(name, callback)

Register callback for variable changes.

**Required Capability:** `state:watch`

```lua
ctx.state.watch("health", function(new_value, old_value)
  if new_value <= 0 then
    ctx.log.info("Player died!")
  end
end)
```

## Hooks

### ctx.hooks

Dynamic hook registration interface.

#### register(event, handler, priority)

Register hook handler at runtime.

**Parameters:**
- `event` - Hook event name (e.g., "on_passage_enter")
- `handler` - Callback function
- `priority` - Execution priority (0-100, default 50, lower = earlier)

**Returns:** Handler ID for unregistering

```lua
local handler_id = ctx.hooks.register("on_passage_enter", function(passage)
  print("Entered: " .. passage.name)
end, 10)
```

#### unregister(handler_id)

Remove registered hook handler.

```lua
ctx.hooks.unregister(handler_id)
```

## Events

### ctx.events

Event bus for plugin communication.

#### emit(event, ...)

Emit custom event.

```lua
ctx.events.emit("item_collected", item)
ctx.events.emit("quest_complete", quest_id, reward)
```

#### on(event, handler)

Subscribe to custom event.

```lua
ctx.events.on("item_collected", function(item)
  print("Collected: " .. item.name)
end)
```

#### off(event, handler)

Unsubscribe from event.

```lua
ctx.events.off("item_collected", my_handler)
```

## Plugin Access

### ctx.plugins

Access other plugin APIs.

```lua
-- Check if plugin exists
if ctx.plugins.inventory then
  -- Use inventory API
  ctx.plugins.inventory.add_item({id = "sword", name = "Sword"})
end
```

## Complete Example

```lua
return {
  name = "example",
  version = "1.0.0",

  capabilities = {
    "state:read",
    "state:write",
    "persistence:read",
    "persistence:write",
  },

  on_init = function(ctx)
    ctx.log.info("Initializing " .. ctx.name .. " v" .. ctx.version)

    -- Load saved data or initialize
    local data = ctx.storage.get("data")
    if not data then
      data = {count = 0}
      ctx.storage.set("data", data)
    end

    -- Register dynamic hook
    ctx.hooks.register("on_passage_enter", function(passage)
      local data = ctx.storage.get("data")
      data.count = data.count + 1
      ctx.storage.set("data", data)
    end)

    -- Watch state changes
    ctx.state.watch("health", function(new_val)
      if new_val <= 0 then
        ctx.events.emit("player_died")
      end
    end)
  end,

  api = {
    get_count = function()
      return ctx.storage.get("data").count
    end,
  },
}
```

## Capability Restrictions

If a plugin attempts to use functionality without declaring the required capability, an error is raised:

```
Error: Plugin 'my-plugin' lacks capability 'state:write'
```

Always declare required capabilities:

```lua
capabilities = {
  "state:read",     -- For ctx.state.get()
  "state:write",    -- For ctx.state.set()
  "persistence:read",   -- For ctx.storage.get()
  "persistence:write",  -- For ctx.storage.set()
}
```

## See Also

- [IPlugin Interface](iplugin-interface.md)
- [Capability Reference](capability-reference.md)
- [Hook Reference](hook-reference.md)
