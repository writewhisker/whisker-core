# Tutorial 2: Using Hooks

## Goal

Learn to register hooks that respond to story events like passage navigation and choices.

## Prerequisites

- Completed [Tutorial 1: Hello World](01-hello-world.md)
- Understanding of event-driven programming

## Hook Types

There are two types of hooks:

1. **Observer Hooks** - Execute for side effects, return values ignored
2. **Transform Hooks** - Modify data, return transformed value

## Step 1: Add Story Lifecycle Hooks

```lua
return {
  name = "tracker",
  version = "1.0.0",

  hooks = {
    on_story_start = function(ctx)
      ctx.log.info("Story started!")
    end,

    on_story_end = function(ctx)
      ctx.log.info("Story ended!")
    end,
  },
}
```

## Step 2: Track Passage Navigation

```lua
hooks = {
  on_passage_enter = function(ctx, passage)
    ctx.log.info("Entering: " .. passage.name)
  end,

  on_passage_exit = function(ctx, passage)
    ctx.log.info("Leaving: " .. passage.name)
  end,
}
```

The `passage` parameter contains:
- `name` - Passage identifier
- `content` - Passage text
- `tags` - Array of tags
- `metadata` - Additional data

## Step 3: Track Choices

```lua
hooks = {
  on_choice_select = function(ctx, choice)
    ctx.log.info("Player chose: " .. choice.text)
  end,
}
```

## Step 4: Transform Hooks

Transform hooks modify data flowing through the system:

```lua
hooks = {
  -- Filter available choices
  on_choice_present = function(choices, ctx)
    local filtered = {}
    for _, choice in ipairs(choices) do
      if not choice.hidden then
        table.insert(filtered, choice)
      end
    end
    return filtered
  end,

  -- Modify passage content before display
  on_passage_render = function(html, ctx, passage)
    return "<div class='custom'>" .. html .. "</div>"
  end,
}
```

## Step 5: Variable Hooks

Monitor and transform variable changes:

```lua
hooks = {
  -- Transform value before assignment
  on_variable_set = function(value, ctx, name)
    if name == "health" and type(value) == "number" then
      -- Clamp health between 0 and 100
      return math.max(0, math.min(100, value))
    end
    return value
  end,

  -- React to any state change
  on_state_change = function(ctx, changes)
    for name, value in pairs(changes) do
      ctx.log.debug(name .. " = " .. tostring(value))
    end
  end,
}
```

## Complete Example

```lua
-- passage-tracker.lua
local plugin = {
  visited = {},
  choice_count = 0,
}

return {
  name = "passage-tracker",
  version = "1.0.0",
  description = "Tracks passage visits and choices",

  hooks = {
    on_story_start = function(ctx)
      plugin.visited = {}
      plugin.choice_count = 0
      ctx.log.info("Tracking started")
    end,

    on_passage_enter = function(ctx, passage)
      plugin.visited[passage.name] = (plugin.visited[passage.name] or 0) + 1
    end,

    on_choice_select = function(ctx, choice)
      plugin.choice_count = plugin.choice_count + 1
    end,
  },

  api = {
    get_visit_count = function(passage_name)
      return plugin.visited[passage_name] or 0
    end,

    get_choice_count = function()
      return plugin.choice_count
    end,

    get_visited_passages = function()
      local list = {}
      for name in pairs(plugin.visited) do
        table.insert(list, name)
      end
      return list
    end,
  },
}
```

## Hook Priority

Hooks execute in priority order (0-100, lower first, default 50).

For dynamic hook registration with custom priority:

```lua
on_init = function(ctx)
  ctx.hooks.register("on_passage_enter", function(passage)
    -- Executes before default priority hooks
  end, 10)
end
```

## What's Next?

- [Tutorial 3: State Management](03-state-management.md) - Persist plugin data
- [Tutorial 4: Public API](04-public-api.md) - Expose functions to stories
