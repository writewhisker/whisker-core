# Plugin Development Best Practices

## Code Organization

### Directory Structure

```
my-plugin/
  init.lua           -- Plugin entry point
  core.lua           -- Core logic
  storage.lua        -- State management
  README.md          -- Documentation
```

### Module Pattern

```lua
-- my-plugin/storage.lua
local Storage = {}
Storage.__index = Storage

function Storage.new(ctx)
  local self = setmetatable({}, Storage)
  self.ctx = ctx
  self.data = {}
  return self
end

function Storage:save()
  self.ctx.storage.set("data", self.data)
end

return Storage
```

```lua
-- my-plugin/init.lua
local Storage = require("my-plugin.storage")

local plugin = {}
plugin._storage = nil

return {
  name = "my-plugin",
  version = "1.0.0",

  on_init = function(ctx)
    plugin._storage = Storage.new(ctx)
  end,

  api = {
    get_data = function()
      return plugin._storage.data
    end,
  },
}
```

## Error Handling

### Validate Inputs

```lua
api = {
  add_item = function(item)
    if type(item) ~= "table" then
      return false, "item must be table, got " .. type(item)
    end

    if not item.id then
      return false, "item must have 'id' field"
    end

    -- Proceed with validated input
    return true
  end,
}
```

### Use pcall for Risky Operations

```lua
hooks = {
  on_passage_enter = function(ctx, passage)
    local success, err = pcall(function()
      -- Risky operation
      process_passage(passage)
    end)

    if not success then
      ctx.log.error("Failed to process passage: " .. err)
    end
  end,
}
```

### Provide Helpful Error Messages

```lua
-- Bad
error("Invalid input")

-- Good
error(string.format(
  "Invalid input: expected table with 'id' field, got %s",
  type(input)
))
```

## Performance

### Cache Expensive Computations

```lua
local cache = {}

api = {
  get_expensive_value = function(key)
    if cache[key] then
      return cache[key]
    end

    local value = compute_expensive_value(key)
    cache[key] = value
    return value
  end,
}
```

### Minimize Hook Overhead

```lua
-- Bad: Complex logic in every hook
hooks = {
  on_passage_enter = function(ctx, passage)
    -- Complex computation every passage
    calculate_complex_thing()
  end,
}

-- Good: Only run when needed
hooks = {
  on_passage_enter = function(ctx, passage)
    if should_calculate(passage) then
      calculate_complex_thing()
    end
  end,
}
```

### Lazy Initialization

```lua
local expensive_resource = nil

api = {
  use_resource = function()
    if not expensive_resource then
      expensive_resource = create_expensive_resource()
    end
    return expensive_resource
  end,
}
```

## State Management

### Namespace Storage Keys

```lua
-- Bad: Generic keys conflict with other plugins
ctx.storage.set("data", {})

-- Good: Prefixed keys
ctx.storage.set("myplugin_data", {})
```

### Separate Transient and Persistent State

```lua
-- Transient (not saved)
local temp_cache = {}

-- Persistent (saved automatically)
ctx.storage.set("inventory", items)
```

### Version Save Data

```lua
hooks = {
  on_save = function(save_data, ctx)
    save_data.my_plugin = {
      version = "1.0.0",  -- Include version
      data = serialize_data(),
    }
    return save_data
  end,

  on_load = function(save_data, ctx)
    if save_data.my_plugin then
      local version = save_data.my_plugin.version

      if version == "1.0.0" then
        load_v1(save_data.my_plugin.data)
      else
        ctx.log.warn("Unknown save version: " .. version)
      end
    end
    return save_data
  end,
}
```

## API Design

### Consistent Naming

```lua
-- Good: Consistent verb_noun pattern
api = {
  add_item = function(item) end,
  remove_item = function(id) end,
  get_item = function(id) end,
  has_item = function(id) end,
}

-- Bad: Inconsistent naming
api = {
  addItem = function(item) end,     -- camelCase
  RemoveItem = function(id) end,    -- PascalCase
  item_get = function(id) end,      -- noun_verb
}
```

### Return Values

```lua
-- Return success and error
api = {
  add_item = function(item)
    if not validate(item) then
      return false, "Invalid item"
    end

    add_to_inventory(item)
    return true
  end,
}

-- Usage
local success, err = whisker.plugin.inventory.add_item(item)
if not success then
  print("Error: " .. err)
end
```

### Document Public API

```lua
--- Add item to inventory
-- @param item table Item definition {id, name, quantity}
-- @return boolean success
-- @return string|nil error Error message if failed
api = {
  add_item = function(item)
    -- Implementation
  end,
}
```

## Testing

### Unit Tests

```lua
-- test/my_plugin_test.lua
local MyPlugin = require("my-plugin.init")

-- Test API
local result = MyPlugin.api.calculate(10, 20)
assert(result == 30, "Calculate failed")

-- Test with mock context
local mock_ctx = {
  state = {
    get = function(key) return 0 end,
    set = function(key, value) end,
  },
  log = {
    info = function(msg) end,
  },
}

MyPlugin.on_init(mock_ctx)
```

### Integration Tests

```lua
-- Test plugin in full story environment
local story = Story.new({
  plugins = {
    paths = {"test/plugins"},
  },
})

story:start()

-- Test plugin functionality
local value = whisker.plugin.my_plugin.get_value()
assert(value == expected)
```

## Documentation

### Include README

```markdown
# My Plugin

## Installation

Place `my-plugin/` in `plugins/community/`.

## Usage

```lua
whisker.plugin.my_plugin.do_something()
```

## API Reference

### do_something()

Does something useful.

**Returns:** result

## License

MIT
```

### Comment Complex Logic

```lua
-- Calculate weighted score based on multiple factors
-- Formula: (base * multiplier) + bonus - penalty
-- Where multiplier is clamped between 0.5 and 2.0
local function calculate_score(base, factors)
  local multiplier = math.max(0.5, math.min(2.0, factors.multiplier))
  local score = (base * multiplier) + factors.bonus - factors.penalty
  return math.floor(score)
end
```

## Security

### Validate External Input

```lua
api = {
  set_config = function(config)
    -- Validate type
    if type(config) ~= "table" then
      return false, "Config must be table"
    end

    -- Validate values
    if config.max_items and type(config.max_items) ~= "number" then
      return false, "max_items must be number"
    end

    apply_config(config)
    return true
  end,
}
```

### Don't Trust User Data

```lua
-- Bad: Direct use of user input
local user_input = get_user_input()
ctx.state.set(user_input.key, user_input.value)

-- Good: Validate and sanitize
local user_input = get_user_input()
if is_valid_key(user_input.key) and is_valid_value(user_input.value) then
  ctx.state.set(user_input.key, user_input.value)
else
  return false, "Invalid input"
end
```

## Versioning

Follow semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking API changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

```lua
version = "1.2.3"
```

Update version when:
- API changes (major)
- New features added (minor)
- Bugs fixed (patch)

## Distribution

### Include License

```lua
license = "MIT"
```

### Minimize Dependencies

Only depend on plugins that are absolutely necessary.

### Test Before Release

Run full test suite before releasing new version.

## See Also

- [IPlugin Interface](../reference/iplugin-interface.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Examples](../examples/)
