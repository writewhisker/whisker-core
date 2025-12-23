# Plugin Troubleshooting Guide

## Plugin Not Loading

### Symptoms
- Plugin not found in whisker.plugin
- No initialization message in logs

### Causes and Solutions

**1. File not in plugin path**

Check that plugin file is in configured path:

```lua
-- Verify plugin paths
local config = {
  plugins = {
    paths = {"plugins/builtin", "plugins/community"},
  },
}
```

Ensure file is in one of these directories.

**2. Invalid plugin definition**

Check for validation errors:

```lua
-- Plugin must return table
return {
  name = "my-plugin",
  version = "1.0.0",
}

-- Not:
-- local plugin = {}
-- (missing return statement)
```

**3. Syntax error in plugin code**

Look for Lua syntax errors in log output. Common issues:
- Missing `end` keyword
- Unclosed strings
- Invalid table syntax

**4. Name mismatch**

For directory-based plugins, the directory name should match:

```
plugins/community/my-plugin/init.lua
```

```lua
-- my-plugin/init.lua
return {
  name = "my-plugin",  -- Matches directory name
  version = "1.0.0",
}
```

## Plugin Crashes Story

### Symptoms
- Story crashes on startup or during play
- Error message mentions plugin name

### Causes and Solutions

**1. Error in lifecycle hook**

Lifecycle hooks (on_init, on_enable) must not throw errors:

```lua
-- Bad
on_init = function(ctx)
  error("Something failed")  -- Crashes story
end

-- Good
on_init = function(ctx)
  local success, err = pcall(function()
    risky_operation()
  end)

  if not success then
    ctx.log.error("Init failed: " .. err)
    -- Plugin disabled but story continues
  end
end
```

**2. Missing capability**

Requesting unauthorized capability crashes plugin:

```lua
-- Must declare capabilities
capabilities = {
  "state:read",
  "state:write",
}

-- Then can use:
on_init = function(ctx)
  ctx.state.set("key", "value")  -- OK
end
```

**3. Circular dependency**

Plugin A depends on B, B depends on A:

```lua
-- plugin-a
dependencies = {
  ["plugin-b"] = "1.0.0",
}

-- plugin-b
dependencies = {
  ["plugin-a"] = "1.0.0",  -- Circular!
}
```

Solution: Restructure to remove circular dependency or extract shared logic to third plugin.

## Hook Not Firing

### Symptoms
- Hook callback never executes
- Expected behavior not occurring

### Causes and Solutions

**1. Hook name misspelled**

```lua
-- Bad
hooks = {
  onPassageEnter = function(ctx, passage) end,  -- Wrong name
}

-- Good
hooks = {
  on_passage_enter = function(ctx, passage) end,
}
```

Refer to [Hook Reference](../reference/hook-reference.md) for correct names.

**2. Hook registered but plugin not enabled**

Hooks only fire when plugin is in enabled state. Check:

```lua
local plugin = registry:get_plugin("my-plugin")
print(plugin.state)  -- Should be "enabled"
```

**3. Dynamic hook not registering**

Static hooks in `hooks = {}` table auto-register during enable. Dynamic hooks need explicit registration:

```lua
on_init = function(ctx)
  ctx.hooks.register("on_passage_enter", function(passage)
    -- Handler
  end, 50)  -- priority
end
```

## State Not Persisting

### Symptoms
- Plugin data lost after save/load
- Variables reset on story restart

### Causes and Solutions

**1. Not using plugin storage**

```lua
-- Bad: Local variable not persisted
local inventory = {}

-- Good: Plugin storage persisted
ctx.storage.set("inventory", {})
```

**2. Missing persistence hooks**

Implement on_save and on_load:

```lua
hooks = {
  on_save = function(save_data, ctx)
    save_data.my_plugin = ctx.storage.get("data")
    return save_data
  end,

  on_load = function(save_data, ctx)
    if save_data.my_plugin then
      ctx.storage.set("data", save_data.my_plugin)
    end
    return save_data
  end,
}
```

**3. Missing persistence capability**

```lua
capabilities = {
  "persistence:read",
  "persistence:write",
}
```

## API Not Accessible

### Symptoms
- `whisker.plugin.my_plugin` is nil
- Cannot call plugin functions from story

### Causes and Solutions

**1. Plugin not loaded**

Check plugin loads successfully:

```lua
-- In story
if whisker.plugin.my_plugin then
  print("Plugin loaded")
else
  print("Plugin not loaded")
end
```

**2. API not defined**

```lua
-- Must define api table
api = {
  my_function = function()
    return "result"
  end,
}
```

**3. Name mismatch in access**

```lua
-- Plugin name
name = "my-plugin"

-- Access with underscores (hyphens converted)
whisker.plugin.my_plugin.my_function()
```

Hyphens are converted to underscores in API access.

## Performance Issues

### Symptoms
- Story runs slowly
- Lag during passage navigation
- High CPU usage

### Causes and Solutions

**1. Expensive hook operations**

Hooks run during story flow. Keep fast:

```lua
-- Bad: Complex computation every passage
hooks = {
  on_passage_enter = function(ctx, passage)
    for i = 1, 1000000 do
      complex_calculation()
    end
  end,
}

-- Good: Cache or defer
local cached_value = nil
local should_recalculate = true

hooks = {
  on_passage_enter = function(ctx, passage)
    if should_recalculate then
      cached_value = complex_calculation()
      should_recalculate = false
    end
  end,
}
```

**2. Memory leaks**

Clear old data:

```lua
on_destroy = function(ctx)
  ctx.storage.clear()  -- Clear plugin data
  -- Release other resources
end
```

**3. Too many hooks**

Each hook adds overhead. Only register needed hooks.

## Capability Errors

### Symptoms
- Error: "Plugin lacks capability: X"
- Features not working

### Solution

Declare required capabilities:

```lua
capabilities = {
  "state:read",     -- For ctx.state.get()
  "state:write",    -- For ctx.state.set()
  "persistence:write",  -- For save/load
}
```

## Sandbox Errors

### Symptoms
- Error: "attempt to call 'os' (a nil value)"
- Cannot access certain Lua functions

### Explanation

Community plugins run in a sandbox that blocks dangerous operations:

**Blocked:**
- `os.execute`, `os.remove`, `os.rename`
- `io.*` (file operations)
- `debug.*` (debugging functions)
- `loadfile`, `dofile`
- `package.*`

**Allowed:**
- `math.*`
- `string.*`
- `table.*` (most functions)
- `pairs`, `ipairs`, `next`
- `type`, `tonumber`, `tostring`
- `pcall`, `xpcall`, `error`
- `os.time`, `os.date`, `os.clock`, `os.difftime`

### Solution

Use only allowed functions. For file operations, use provided APIs:

```lua
-- Bad: Direct file access (blocked)
local f = io.open("data.txt", "r")

-- Good: Use plugin storage
ctx.storage.set("my_data", data)
```

## Getting More Help

1. Enable debug logging:

```lua
ctx.log.debug("Debug message")
```

2. Check plugin state:

```lua
local plugin = registry:get_plugin("my-plugin")
print("State:", plugin.state)
print("Error:", plugin.error)
```

3. Review example plugins in `examples/`

4. Check built-in plugins for patterns:
   - `plugins/builtin/core/`
   - `plugins/builtin/inventory/`
   - `plugins/builtin/achievements/`

## See Also

- [Best Practices](best-practices.md)
- [API Reference](../reference/)
- [Examples](../examples/)
