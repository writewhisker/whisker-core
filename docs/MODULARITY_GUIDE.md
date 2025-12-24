# Whisker-Core Modularity Guide

This guide explains the Dependency Injection (DI) patterns used in whisker-core and how to contribute DI-compliant code.

## Quick Start

### Creating a New Module

Use the template generator:

```bash
lua tools/new_module.lua core.my_feature
```

This creates:
- `lib/whisker/core/my_feature.lua` - Module implementation
- `tests/unit/core/my_feature_spec.lua` - Unit tests

### Validating Modularity

Run the modularity validator:

```bash
lua tools/validate_modularity.lua lib/
```

Options:
- `--errors-only` - Show only errors, not warnings
- `--format=ci` - Output GitHub Actions annotations
- `--format=json` - JSON output

### Visualizing Dependencies

Generate a dependency graph:

```bash
lua tools/dependency_graph.lua --format=dot lib/ > graph.dot
dot -Tpng graph.dot -o graph.png
```

## DI Pattern Reference

### Module Structure

Every module should follow this pattern:

```lua
local MyModule = {}
MyModule.__index = MyModule

--- Declare dependencies for documentation and validation
MyModule._dependencies = { "logger", "event_bus" }

--- Constructor accepting injected dependencies
function MyModule.new(deps)
  local self = setmetatable({}, MyModule)

  deps = deps or {}
  self.logger = deps.logger
  self.event_bus = deps.event_bus

  return self
end

--- Factory for container integration
function MyModule.create(container)
  local deps = {}
  if container and container.has then
    if container:has("logger") then
      deps.logger = container:resolve("logger")
    end
    if container:has("event_bus") then
      deps.event_bus = container:resolve("event_bus")
    end
  end
  return MyModule.new(deps)
end

return MyModule
```

### Key Elements

1. **`_dependencies` Declaration**: List all dependencies the module needs
2. **`new(deps)` Constructor**: Accept dependencies as a table parameter
3. **`create(container)` Factory**: Resolve dependencies from container
4. **Lazy Loading**: For optional dependencies, load on first use

### Allowed Direct Requires

Some modules can be required directly:

| Pattern | Reason |
|---------|--------|
| `whisker.interfaces.*` | Interface definitions |
| `whisker.vendor.*` | Vendor abstractions |
| `whisker.kernel.container` | Bootstrap only |
| `whisker.kernel.event_bus` | Bootstrap only |
| `whisker.core.choice` | Core types for factories |
| `whisker.core.passage` | Core types for factories |
| `whisker.core.story` | Core types for factories |

### Files Exempt from Strict DI

| Pattern | Reason |
|---------|--------|
| `init.lua` | Entry points wire dependencies |
| `kernel/bootstrap.lua` | Creates the container |
| `vendor/codecs/*.lua` | Vendor abstraction layer |
| `vendor/runtimes/*.lua` | Vendor abstraction layer |

## Validation Rules

### Error-Level Rules (Must Fix)

| Rule ID | Description |
|---------|-------------|
| `DIRECT_REQUIRE` | Don't require whisker modules directly (use DI) |
| `DIRECT_VENDOR` | Don't require vendor libs directly (use abstractions) |
| `GLOBAL_ASSIGN` | Don't use global variables |

### Warning-Level Rules (Should Fix)

| Rule ID | Description |
|---------|-------------|
| `MISSING_DEPENDENCIES` | Module with `new()` should declare `_dependencies` |
| `NO_DEPS_PARAM` | Constructor should accept deps parameter |
| `HARDCODED_DEP` | Don't create dependencies inside module |

### Info-Level Rules (Consider)

| Rule ID | Description |
|---------|-------------|
| `MISSING_CREATE` | Consider adding `create()` factory function |

## Event-Driven Communication

Use events instead of direct method calls between modules:

```lua
-- Publishing events (decoupled from listeners)
self.event_bus:emit("asset:loaded", { id = asset_id, asset = asset })

-- Subscribing to events (decoupled from publishers)
self.event_bus:on("asset:loaded", function(data)
  -- Handle event
end)
```

### Standard Events

| Event | Payload | Emitter |
|-------|---------|---------|
| `passage:enter` | `{ passage }` | Engine |
| `passage:exit` | `{ passage }` | Engine |
| `choice:select` | `{ choice, index }` | Engine |
| `state:change` | `{ key, old_value, new_value }` | State |
| `asset:loaded` | `{ id, asset }` | AssetManager |
| `audio:play` | `{ id, channel }` | AudioManager |

## Testing Patterns

### Unit Tests with Mock Dependencies

```lua
describe("MyModule", function()
  local MyModule
  local mock_deps

  before_each(function()
    mock_deps = {
      logger = {
        info = function() end,
        warn = function() end,
        error = function() end
      },
      event_bus = {
        emit = spy.new(function() end),
        on = function() end
      },
    }
    MyModule = require("whisker.my_module")
  end)

  it("emits events on action", function()
    local instance = MyModule.new(mock_deps)
    instance:do_something()
    assert.spy(mock_deps.event_bus.emit).was_called_with(
      "my_module:action",
      match._
    )
  end)
end)
```

### Contract Tests

Verify interface compliance:

```lua
describe("MyModule contract", function()
  local IMyInterface = require("whisker.interfaces.my_interface")
  local MyModule = require("whisker.my_module")

  it("implements IMyInterface", function()
    local instance = MyModule.new({})
    for method, _ in pairs(IMyInterface) do
      if type(_) == "function" and method ~= "new" then
        assert.is_function(instance[method],
          "Missing method: " .. method)
      end
    end
  end)
end)
```

## Common Patterns

### Lazy Loading

For optional or heavy dependencies:

```lua
function MyModule:get_heavy_dep()
  if not self._heavy_dep then
    -- Only load when needed
    self._heavy_dep = self.container:resolve("heavy_dep")
  end
  return self._heavy_dep
end
```

### Backward Compatibility

When refactoring existing modules:

```lua
function MyModule.new(deps)
  local self = setmetatable({}, MyModule)

  deps = deps or {}

  -- Support injected dependency
  if deps.json_codec then
    self.json_codec = deps.json_codec
  else
    -- Fallback for backward compatibility
    self.json_codec = nil  -- Will lazy-load
  end

  return self
end

function MyModule:get_codec()
  if not self.json_codec then
    -- Lazy load fallback
    local JsonCodec = require("whisker.vendor.codecs.json_codec")
    self.json_codec = JsonCodec.new()
  end
  return self.json_codec
end
```

### Vendor Abstractions

Wrap external libraries behind interfaces:

```lua
-- lib/whisker/vendor/codecs/json_codec.lua
local JsonCodec = {}
JsonCodec._dependencies = { "logger" }

function JsonCodec.new(deps)
  local self = setmetatable({}, { __index = JsonCodec })
  self.logger = deps and deps.logger
  -- Load underlying library
  self._cjson = require("cjson")  -- OK - this is the abstraction layer
  return self
end

function JsonCodec:encode(value)
  return self._cjson.encode(value)
end

function JsonCodec:decode(str)
  return self._cjson.decode(str)
end

return JsonCodec
```

## CI Integration

The CI pipeline runs modularity checks on every PR:

```yaml
# .github/workflows/test.yml
modularity:
  name: Modularity Validation
  steps:
    - name: Run modularity validation
      run: lua tools/validate_modularity.lua --errors-only --format=ci lib/
```

### Bypassing Checks

For exceptional cases, add `[skip-modularity]` to commit message:

```bash
git commit -m "Emergency fix for prod issue [skip-modularity]"
```

## Luacheck Integration

The `.luacheckrc` includes modularity-related configuration:

```lua
-- Modularity configuration
files = {
  -- Kernel files can access more globals during bootstrap
  ["lib/whisker/kernel/*.lua"] = {
    ignore = { "111", "112", "113" },
  },

  -- Test files have relaxed rules
  ["tests/**/*.lua"] = {
    std = "+busted",
  },
}
```

## Tools Reference

| Tool | Purpose |
|------|---------|
| `tools/validate_modularity.lua` | Validate DI compliance |
| `tools/dependency_graph.lua` | Visualize dependencies |
| `tools/new_module.lua` | Scaffold new modules |

## Further Reading

- [Architecture Overview](guides/ARCHITECTURE_OVERVIEW.md) - System architecture
- [Testing Guide](testing/TESTING_GUIDE.md) - Testing patterns
- [Plugin Development](plugins/README.md) - Plugin system

## Migration Guide

### Refactoring to DI

1. Add `_dependencies` declaration
2. Change constructor to accept `deps` parameter
3. Replace direct requires with injected deps
4. Add lazy-loading fallbacks for backward compatibility
5. Add `create()` factory if using container
6. Run `lua tools/validate_modularity.lua` to verify

### Example Migration

Before:
```lua
local MyModule = {}
local OtherModule = require("whisker.other")  -- Direct require

function MyModule.new()
  local self = setmetatable({}, { __index = MyModule })
  self.other = OtherModule.new()  -- Direct instantiation
  return self
end
```

After:
```lua
local MyModule = {}
MyModule.__index = MyModule
MyModule._dependencies = { "other_module" }

function MyModule.new(deps)
  local self = setmetatable({}, MyModule)
  deps = deps or {}
  self.other = deps.other_module
  return self
end

function MyModule.create(container)
  local deps = {}
  if container:has("other_module") then
    deps.other_module = container:resolve("other_module")
  end
  return MyModule.new(deps)
end
```
