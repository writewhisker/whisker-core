# Tutorial 3: State Management

## Goal

Learn to persist plugin data across save/load cycles and story restarts.

## Prerequisites

- Completed [Tutorial 2: Using Hooks](02-using-hooks.md)
- Understanding of data persistence concepts

## Storage Types

Plugins have two storage mechanisms:

1. **Plugin Storage** (`ctx.storage`) - Automatic per-plugin key-value store
2. **Story State** (`ctx.state`) - Shared story variables

## Step 1: Request Capabilities

Declare required capabilities:

```lua
return {
  name = "data-plugin",
  version = "1.0.0",

  capabilities = {
    "state:read",         -- Read story variables
    "state:write",        -- Modify story variables
    "persistence:read",   -- Load plugin data
    "persistence:write",  -- Save plugin data
  },
}
```

## Step 2: Use Plugin Storage

```lua
on_init = function(ctx)
  -- Initialize plugin data
  ctx.storage.set("counter", 0)
  ctx.storage.set("items", {})
end

api = {
  increment = function()
    local count = ctx.storage.get("counter") or 0
    ctx.storage.set("counter", count + 1)
    return count + 1
  end,

  get_count = function()
    return ctx.storage.get("counter") or 0
  end,
}
```

## Step 3: Access Story State

```lua
api = {
  -- Read story variable
  get_health = function()
    return ctx.state.get("health") or 100
  end,

  -- Modify story variable
  heal = function(amount)
    local current = ctx.state.get("health") or 100
    ctx.state.set("health", current + amount)
  end,
}
```

## Step 4: Implement Save/Load Hooks

For custom serialization:

```lua
hooks = {
  on_save = function(save_data, ctx)
    -- Inject plugin data into save
    save_data.my_plugin = {
      version = "1.0.0",
      counter = ctx.storage.get("counter"),
      items = ctx.storage.get("items"),
    }
    return save_data
  end,

  on_load = function(save_data, ctx)
    -- Restore plugin data from save
    if save_data.my_plugin then
      ctx.storage.set("counter", save_data.my_plugin.counter or 0)
      ctx.storage.set("items", save_data.my_plugin.items or {})
    end
    return save_data
  end,
}
```

## Step 5: Handle Story Reset

```lua
hooks = {
  on_story_start = function(ctx)
    -- Initialize fresh state
    ctx.storage.set("session_data", {
      started_at = os.time(),
      passages_visited = 0,
    })
  end,

  on_story_reset = function(ctx)
    -- Clear session data, keep persistent data
    ctx.storage.set("session_data", nil)
  end,
}
```

## Complete Example

```lua
-- score-tracker.lua
local plugin = {}

return {
  name = "score-tracker",
  version = "1.0.0",
  description = "Tracks and persists player score",

  capabilities = {
    "persistence:read",
    "persistence:write",
  },

  on_init = function(ctx)
    plugin.ctx = ctx
    -- Load previous high score or default
    plugin.high_score = ctx.storage.get("high_score") or 0
    plugin.current_score = 0
  end,

  hooks = {
    on_story_start = function(ctx)
      plugin.current_score = 0
    end,

    on_story_end = function(ctx)
      -- Update high score if beaten
      if plugin.current_score > plugin.high_score then
        plugin.high_score = plugin.current_score
        ctx.storage.set("high_score", plugin.high_score)
        ctx.log.info("New high score: " .. plugin.high_score)
      end
    end,

    on_save = function(save_data, ctx)
      save_data.score_tracker = {
        current_score = plugin.current_score,
        high_score = plugin.high_score,
      }
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.score_tracker then
        plugin.current_score = save_data.score_tracker.current_score or 0
        plugin.high_score = save_data.score_tracker.high_score or 0
        ctx.storage.set("high_score", plugin.high_score)
      end
      return save_data
    end,
  },

  api = {
    add_score = function(points)
      plugin.current_score = plugin.current_score + points
      return plugin.current_score
    end,

    get_score = function()
      return plugin.current_score
    end,

    get_high_score = function()
      return plugin.high_score
    end,

    reset_high_score = function()
      plugin.high_score = 0
      plugin.ctx.storage.set("high_score", 0)
    end,
  },
}
```

## Best Practices

1. **Version your save data** - Include version for migration support
2. **Validate on load** - Check data integrity before restoring
3. **Separate transient and persistent** - Not all data needs saving
4. **Namespace keys** - Prefix storage keys with plugin name

## What's Next?

- [Tutorial 4: Public API](04-public-api.md) - Design plugin APIs
- [Tutorial 5: Testing](05-testing.md) - Write plugin tests
