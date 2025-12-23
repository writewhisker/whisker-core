# Whisker-Core Plugin Development

## What are Plugins?

Plugins extend whisker-core with custom functionality without modifying the core framework. Use plugins to add:

- Gameplay mechanics (inventory, achievements, combat)
- UI enhancements (custom themes, components)
- Story tools (debugging, analytics)
- Format converters (export to different formats)

## Quick Start

### Minimal Plugin

Create `my-plugin.lua`:

```lua
return {
  name = "my-plugin",
  version = "1.0.0",

  on_init = function(ctx)
    ctx.log.info("My plugin initialized!")
  end,

  api = {
    hello = function()
      return "Hello from my plugin!"
    end,
  },
}
```

### Use in Story

```lua
-- Story script
local message = whisker.plugin.my_plugin.hello()
print(message)  -- "Hello from my plugin!"
```

## Learning Path

1. **Tutorial**: Step-by-step plugin creation ([tutorial/](tutorial/))
2. **Reference**: Complete API documentation ([reference/](reference/))
3. **Guides**: Architecture and best practices ([guides/](guides/))
4. **Examples**: Working plugin implementations ([examples/](examples/))

## Core Concepts

### Plugin Lifecycle

```
discovered -> loaded -> initialized -> enabled -> disabled -> destroyed
```

Each state transition triggers lifecycle hooks (on_load, on_init, etc.).

### Hook System

Plugins register callbacks that execute during story events:

```lua
hooks = {
  on_passage_enter = function(ctx, passage)
    print("Entering passage: " .. passage.name)
  end,
}
```

### Capabilities

Plugins request permissions for framework features:

```lua
capabilities = {
  "state:read",     -- Read story variables
  "state:write",    -- Modify story variables
  "persistence:write",  -- Save data
}
```

### Plugin Context

The `ctx` parameter provides controlled access to framework:

```lua
on_init = function(ctx)
  ctx.state.set("my_var", 10)       -- Set story variable
  ctx.storage.set("plugin_data", {}) -- Plugin storage
  ctx.log.info("Initialized")        -- Logging
end
```

## Built-in Plugins

whisker-core includes these built-in plugins:

### core

Core utilities for other plugins. Provides:
- `deep_copy(obj)` - Deep clone objects
- `merge(a, b)` - Shallow merge tables
- `map(t, fn)` - Map over array
- `filter(t, fn)` - Filter array
- `reduce(t, fn, init)` - Reduce array

### inventory

Item management system:
- `add_item(item)` - Add item to inventory
- `remove_item(id, quantity)` - Remove item
- `has_item(id, quantity)` - Check for item
- `get_all_items()` - List all items

### achievements

Trophy/achievement system:
- `define_achievement(def)` - Define achievement
- `is_unlocked(id)` - Check if unlocked
- `get_progress(id)` - Get completion progress
- `get_statistics()` - Get overall stats

## Next Steps

- [Tutorial: Hello World Plugin](tutorial/01-hello-world.md)
- [Reference: IPlugin Interface](reference/iplugin-interface.md)
- [Examples: Browse Example Plugins](examples/)

## Getting Help

- Check [Troubleshooting Guide](guides/troubleshooting.md)
- Review [Best Practices](guides/best-practices.md)
- Browse [Example Plugins](examples/)
