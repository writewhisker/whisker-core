# Hook Reference

## Overview

Hooks are callbacks that execute at specific points during story execution. Plugins register hooks to observe events, transform data, or inject behavior.

## Hook Types

### Observer Hooks

Execute for side effects, return values ignored.

**Example:**
```lua
on_passage_enter = function(ctx, passage)
  print("Entered: " .. passage.name)
  -- Return value ignored
end
```

### Transform Hooks

Modify data flowing through the system, return transformed value.

**Example:**
```lua
on_variable_set = function(value, ctx, name)
  if type(value) == "number" then
    return value * 2  -- Double numeric values
  end
  return value  -- Keep original
end
```

Returning `nil` keeps original value (no transformation).

## Story Lifecycle Hooks

### on_story_start

**Type:** Observer

**Signature:** `function(ctx)`

**When:** Story begins (once per playthrough)

**Use:** Initialize plugin state, set default variables

**Example:**
```lua
on_story_start = function(ctx)
  ctx.storage.set("started_at", os.time())
end
```

### on_story_end

**Type:** Observer

**Signature:** `function(ctx)`

**When:** Story completes

**Use:** Cleanup, final statistics

### on_story_reset

**Type:** Observer

**Signature:** `function(ctx)`

**When:** Story restarts

**Use:** Reset plugin state

## Passage Navigation Hooks

### on_passage_enter

**Type:** Observer

**Signature:** `function(ctx, passage)`

**When:** Before displaying new passage

**Parameters:**
- `passage` - `{name: string, content: string, tags: string[], metadata: table}`

**Example:**
```lua
on_passage_enter = function(ctx, passage)
  -- Track passage visits
  local visits = ctx.storage.get("passage_visits") or {}
  visits[passage.name] = (visits[passage.name] or 0) + 1
  ctx.storage.set("passage_visits", visits)
end
```

### on_passage_exit

**Type:** Observer

**Signature:** `function(ctx, passage)`

**When:** After leaving passage

### on_passage_render

**Type:** Transform

**Signature:** `function(html, ctx, passage) -> string`

**When:** During passage rendering

**Returns:** Modified HTML string

**Example:**
```lua
on_passage_render = function(html, ctx, passage)
  -- Inject header
  return "<div class='header'>Chapter 1</div>" .. html
end
```

## Choice Handling Hooks

### on_choice_present

**Type:** Transform

**Signature:** `function(choices, ctx) -> table`

**When:** Before showing choices to player

**Parameters:**
- `choices` - Array of `{text: string, target: string, condition: any, metadata: table}`

**Returns:** Modified choices array

**Example:**
```lua
on_choice_present = function(choices, ctx)
  -- Filter disabled choices
  local filtered = {}
  for _, choice in ipairs(choices) do
    if not choice.disabled then
      table.insert(filtered, choice)
    end
  end
  return filtered
end
```

### on_choice_select

**Type:** Observer

**Signature:** `function(ctx, choice)`

**When:** After player selects choice

**Example:**
```lua
on_choice_select = function(ctx, choice)
  -- Track choices made
  local count = ctx.storage.get("choices_made") or 0
  ctx.storage.set("choices_made", count + 1)
end
```

## Variable Management Hooks

### on_variable_set

**Type:** Transform

**Signature:** `function(value, ctx, name) -> any`

**When:** Before variable assignment

**Returns:** Transformed value

**Example:**
```lua
on_variable_set = function(value, ctx, name)
  -- Clamp health between 0 and 100
  if name == "health" and type(value) == "number" then
    return math.max(0, math.min(100, value))
  end
  return value
end
```

### on_variable_get

**Type:** Transform

**Signature:** `function(value, ctx, name) -> any`

**When:** Before variable access

**Returns:** Transformed value

**Example:**
```lua
on_variable_get = function(value, ctx, name)
  -- Provide computed value
  if name == "health_percent" then
    local health = ctx.state.get("health") or 100
    local max_health = ctx.state.get("max_health") or 100
    return (health / max_health) * 100
  end
  return value
end
```

### on_state_change

**Type:** Observer

**Signature:** `function(ctx, changes)`

**When:** After any state modification

**Parameters:**
- `changes` - `{variable_name = new_value}`

**Example:**
```lua
on_state_change = function(ctx, changes)
  for name, value in pairs(changes) do
    ctx.log.debug(string.format("%s = %s", name, tostring(value)))
  end
end
```

## Persistence Hooks

### on_save

**Type:** Transform

**Signature:** `function(save_data, ctx) -> table`

**When:** Before saving story

**Returns:** Modified save data

**Example:**
```lua
on_save = function(save_data, ctx)
  -- Inject plugin data
  save_data.my_plugin = {
    custom_data = ctx.storage.get("custom_data"),
    version = "1.0.0",
  }
  return save_data
end
```

### on_load

**Type:** Transform

**Signature:** `function(save_data, ctx) -> table`

**When:** After loading story

**Returns:** Modified save data

**Example:**
```lua
on_load = function(save_data, ctx)
  -- Extract plugin data
  if save_data.my_plugin then
    ctx.storage.set("custom_data", save_data.my_plugin.custom_data)
  end
  return save_data
end
```

## Error Hooks

### on_error

**Type:** Observer

**Signature:** `function(ctx, error_info)`

**When:** Runtime error occurs

**Parameters:**
- `error_info` - `{message: string, stack: string, context: table}`

**Example:**
```lua
on_error = function(ctx, error_info)
  -- Log error for analytics
  ctx.log.error("Error: " .. error_info.message)
end
```

## Hook Execution Order

Hooks with lower priority execute first (0-100, default 50).

**Example:**
```lua
-- Register hook with custom priority
ctx.hooks.register("on_passage_enter", function(passage)
  print("High priority hook")
end, 10)  -- Priority 10 (executes early)
```

## Multiple Handlers

Multiple plugins can register for the same hook:
- Observer hooks: All handlers execute in priority order
- Transform hooks: Each handler receives previous handler's output

## Best Practices

1. **Keep Hooks Fast**: Hooks execute during story flow. Avoid slow operations.
2. **Handle Errors**: Use pcall for risky operations to prevent breaking story.
3. **Return Correctly**: Transform hooks must return value or nil.
4. **Check Nil**: Always validate hook parameters before use.
5. **Log Sparingly**: Excessive logging degrades performance.

## See Also

- [IPlugin Interface](iplugin-interface.md)
- [PluginContext Reference](plugin-context.md)
- [Tutorial: Using Hooks](../tutorial/02-using-hooks.md)
