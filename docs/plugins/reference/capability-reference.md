# Capability Reference

## Overview

Capabilities are permissions that plugins request to access framework features. This system provides security by limiting what untrusted plugins can do.

## Declaring Capabilities

```lua
return {
  name = "my-plugin",
  version = "1.0.0",

  capabilities = {
    "state:read",
    "state:write",
    "persistence:write",
  },
}
```

## State Capabilities

### state:read

**Description:** Read story variables

**Enables:**
- `ctx.state.get(name)`

**Example Use:**
```lua
local health = ctx.state.get("health")
local gold = ctx.state.get("gold")
```

### state:write

**Description:** Modify story variables

**Enables:**
- `ctx.state.set(name, value)`

**Example Use:**
```lua
ctx.state.set("health", 100)
ctx.state.set("quest_complete", true)
```

### state:watch

**Description:** Register callbacks for variable changes

**Enables:**
- `ctx.state.watch(name, callback)`

**Example Use:**
```lua
ctx.state.watch("health", function(new_value, old_value)
  if new_value <= 0 then
    handle_death()
  end
end)
```

## Persistence Capabilities

### persistence:read

**Description:** Load plugin data from saves

**Enables:**
- `ctx.storage.get(key)`

**Example Use:**
```lua
local inventory = ctx.storage.get("inventory")
local settings = ctx.storage.get("settings")
```

### persistence:write

**Description:** Store plugin data in saves

**Enables:**
- `ctx.storage.set(key, value)`
- `ctx.storage.clear()`

**Example Use:**
```lua
ctx.storage.set("inventory", items)
ctx.storage.set("last_save", os.time())
```

## UI Capabilities

### ui:inject

**Description:** Add UI components to the story display

**Enables:**
- `ctx.ui.inject(component)`
- `ctx.ui.remove(component_id)`

**Example Use:**
```lua
ctx.ui.inject({
  id = "health_bar",
  type = "progress",
  value = health,
  max = 100,
})
```

### ui:style

**Description:** Modify CSS styling

**Enables:**
- `ctx.ui.add_style(css)`
- `ctx.ui.remove_style(style_id)`

**Example Use:**
```lua
ctx.ui.add_style([[
  .health-bar {
    background: red;
    height: 20px;
  }
]])
```

### ui:theme

**Description:** Register theme definitions

**Enables:**
- `ctx.ui.register_theme(theme)`

**Example Use:**
```lua
ctx.ui.register_theme({
  name = "dark",
  colors = {
    background = "#1a1a1a",
    text = "#ffffff",
  },
})
```

## Capability Groups

Common capability combinations:

### Read-Only Plugin
```lua
capabilities = {
  "state:read",
  "persistence:read",
}
```

### State Management Plugin
```lua
capabilities = {
  "state:read",
  "state:write",
  "persistence:read",
  "persistence:write",
}
```

### UI Enhancement Plugin
```lua
capabilities = {
  "state:read",
  "ui:inject",
  "ui:style",
}
```

### Full-Featured Plugin
```lua
capabilities = {
  "state:read",
  "state:write",
  "state:watch",
  "persistence:read",
  "persistence:write",
  "ui:inject",
  "ui:style",
}
```

## Capability Errors

When a plugin tries to use functionality without the required capability:

```
Error: Plugin 'my-plugin' lacks capability 'state:write'
```

### Debugging Capability Issues

1. Check error message for missing capability
2. Add capability to plugin definition
3. Reload plugin

```lua
-- Before: Error on ctx.state.set()
capabilities = {
  "state:read",
}

-- After: Works correctly
capabilities = {
  "state:read",
  "state:write",  -- Added
}
```

## Built-in Plugin Capabilities

Built-in (trusted) plugins have access to all capabilities without declaring them:

```lua
return {
  name = "core",
  version = "1.0.0",
  _trusted = true,  -- Full access
}
```

Only whisker-core built-in plugins should use `_trusted = true`.

## Best Practices

### Request Minimum Capabilities

Only request what you need:

```lua
-- Bad: Overly broad
capabilities = {
  "state:read",
  "state:write",
  "state:watch",
  "persistence:read",
  "persistence:write",
  "ui:inject",
  "ui:style",
  "ui:theme",
}

-- Good: Minimal required
capabilities = {
  "state:read",
  "persistence:write",
}
```

### Document Required Capabilities

Include in plugin README:

```markdown
## Required Capabilities

- `state:read` - Read player stats
- `persistence:write` - Save achievement progress
```

### Handle Missing Capabilities Gracefully

```lua
api = {
  save_data = function(data)
    local success, err = pcall(function()
      ctx.storage.set("data", data)
    end)

    if not success then
      ctx.log.error("Cannot save: " .. err)
      return false
    end
    return true
  end,
}
```

## See Also

- [IPlugin Interface](iplugin-interface.md)
- [PluginContext Reference](plugin-context.md)
- [Security Guide](../guides/security.md)
