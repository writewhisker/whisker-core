# IPlugin Interface Reference

## Overview

The IPlugin interface defines the contract between plugins and whisker-core. Every plugin is a Lua module returning a table conforming to this specification.

## Required Fields

### name

**Type:** `string`

**Description:** Unique plugin identifier using lowercase letters, numbers, and hyphens.

**Pattern:** `^[a-z][a-z0-9-]*$`

**Example:**
```lua
name = "my-awesome-plugin"
```

### version

**Type:** `string`

**Description:** Semantic version (MAJOR.MINOR.PATCH)

**Pattern:** `^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$`

**Example:**
```lua
version = "1.0.0"
```

## Optional Fields

### author

**Type:** `string`

**Description:** Plugin author name or organization

**Example:**
```lua
author = "Jane Developer"
```

### description

**Type:** `string`

**Description:** Brief plugin purpose (recommended max 200 characters)

**Example:**
```lua
description = "Adds inventory management to stories"
```

### license

**Type:** `string`

**Description:** SPDX license identifier

**Example:**
```lua
license = "MIT"
```

### homepage

**Type:** `string`

**Description:** URL to plugin documentation or repository

**Example:**
```lua
homepage = "https://github.com/user/plugin"
```

### _trusted

**Type:** `boolean`

**Description:** If true, plugin runs outside sandbox (built-in plugins only)

**Example:**
```lua
_trusted = true
```

### dependencies

**Type:** `table<string, string>`

**Description:** Map of plugin names to version constraints

**Example:**
```lua
dependencies = {
  ["other-plugin"] = "^1.0.0",   -- Compatible with 1.x
  core = "~1.2.0",               -- Compatible with 1.2.x
}
```

**Version Constraints:**
- `1.2.3` - Exact version
- `^1.2.3` - Compatible (>= 1.2.3, < 2.0.0)
- `~1.2.3` - Approximately (>= 1.2.3, < 1.3.0)
- `*` - Any version (not recommended)

### capabilities

**Type:** `string[]`

**Description:** Array of required capability permissions

**Example:**
```lua
capabilities = {
  "state:read",
  "state:write",
  "persistence:write",
}
```

**Available Capabilities:**
- `state:read` - Read story variables
- `state:write` - Modify story variables
- `state:watch` - Register variable change listeners
- `persistence:read` - Load plugin data from saves
- `persistence:write` - Store plugin data in saves
- `ui:inject` - Add UI components
- `ui:style` - Modify CSS styling
- `ui:theme` - Register theme definitions

## Lifecycle Hooks

### on_load

**Type:** `function(ctx: PluginContext)`

**When:** Plugin module loaded into memory

**Use:** Initialize module-level data structures

**Example:**
```lua
on_load = function(ctx)
  ctx.log.debug("Plugin loaded")
end
```

### on_init

**Type:** `function(ctx: PluginContext)`

**When:** Story initialization

**Use:** Register hooks, validate dependencies, initialize transient state

**Example:**
```lua
on_init = function(ctx)
  ctx.log.info("Plugin initialized")
end
```

### on_enable

**Type:** `function(ctx: PluginContext)`

**When:** Plugin transitions to active state

**Use:** Start background tasks, register UI components

**Example:**
```lua
on_enable = function(ctx)
  ctx.log.info("Plugin enabled")
end
```

### on_disable

**Type:** `function(ctx: PluginContext)`

**When:** Plugin transitions to inactive state

**Use:** Clean up background tasks, remove UI components

**Example:**
```lua
on_disable = function(ctx)
  ctx.log.info("Plugin disabled")
end
```

### on_destroy

**Type:** `function(ctx: PluginContext)`

**When:** Plugin completely unloaded

**Use:** Release all resources, clear persistent state if needed

**Example:**
```lua
on_destroy = function(ctx)
  ctx.log.info("Plugin destroyed")
end
```

## Story Event Hooks

### hooks

**Type:** `table<string, function>`

**Description:** Map of event names to callback functions

**Example:**
```lua
hooks = {
  on_story_start = function(ctx)
    ctx.log.info("Story started")
  end,

  on_passage_enter = function(ctx, passage)
    ctx.log.info("Entering: " .. passage.name)
  end,

  on_variable_set = function(value, ctx, name)
    -- Transform value before assignment
    return value
  end,
}
```

**Available Hooks:** See [Hook Reference](hook-reference.md)

## Public API

### api

**Type:** `table<string, function>`

**Description:** Functions exposed to story scripts

**Example:**
```lua
api = {
  add_item = function(item)
    -- Implementation
  end,

  has_item = function(item_id)
    -- Implementation
    return true
  end,
}
```

**Access:** `whisker.plugin.<plugin_name>.<function_name>()`

Note: Hyphens in plugin names are converted to underscores for API access.

## Complete Example

```lua
return {
  -- Required
  name = "example-plugin",
  version = "1.0.0",

  -- Optional metadata
  author = "Plugin Developer",
  description = "Example plugin demonstrating IPlugin interface",
  license = "MIT",
  homepage = "https://example.com",

  -- Dependencies
  dependencies = {
    core = "^1.0.0",
  },

  -- Capabilities
  capabilities = {
    "state:read",
    "state:write",
  },

  -- Lifecycle
  on_init = function(ctx)
    ctx.log.info("Initialized")
  end,

  on_enable = function(ctx)
    ctx.log.debug("Enabled")
  end,

  on_disable = function(ctx)
    ctx.log.debug("Disabled")
  end,

  on_destroy = function(ctx)
    ctx.log.debug("Destroyed")
  end,

  -- Hooks
  hooks = {
    on_story_start = function(ctx)
      ctx.state.set("plugin_active", true)
    end,
  },

  -- API
  api = {
    do_something = function()
      return "done"
    end,
  },
}
```

## See Also

- [PluginContext Reference](plugin-context.md)
- [Hook Reference](hook-reference.md)
- [Capability Reference](capability-reference.md)
