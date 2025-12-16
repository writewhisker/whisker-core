# ADR-002: Dependency Injection Container

**Status:** Accepted
**Date:** 2025-12-16
**Deciders:** whisker-core maintainers

## Context

The audit identified 28+ hardcoded `require()` statements creating tight coupling between modules (ISS-003, ISS-004, ISS-007, ISS-009). For example:

```lua
-- Current: whisker_loader.lua
local Story = require("whisker.core.story")     -- Hardcoded
local Passage = require("whisker.core.passage") -- Hardcoded
local json = require("whisker.utils.json")      -- Hardcoded
```

This prevents:
- Swapping implementations (e.g., different JSON libraries)
- Testing with mocks
- Platform-specific implementations
- Optional features

## Decision

We will implement a **Dependency Injection Container** that:

1. **Manages component registration**
   ```lua
   container:register("json", JsonSerializer, { implements = "ISerializer" })
   ```

2. **Resolves dependencies automatically**
   ```lua
   local loader = container:resolve("whisker_loader")
   -- Container injects json, Story, Passage automatically
   ```

3. **Supports scopes**
   - `singleton` - One instance per container
   - `transient` - New instance each resolution

4. **Supports interface-based lookup**
   ```lua
   local serializer = container:resolve_interface("ISerializer")
   ```

5. **Validates dependency graphs**
   - Detects circular dependencies at registration
   - Ensures all dependencies exist before resolution

## Consequences

### Positive

- **Decoupling:** Modules depend on interfaces, not implementations
- **Testability:** Inject mocks for any dependency
- **Flexibility:** Swap implementations without code changes
- **Explicit dependencies:** Dependencies declared, not hidden in code

### Negative

- **Configuration overhead:** Must register all components
- **Runtime resolution:** Slightly slower than direct `require()`
- **Complexity:** Another concept developers must learn

### Neutral

- Container is a kernel module, loaded early in bootstrap
- Existing `require()` calls work during migration

## Implementation

```lua
-- lib/whisker/kernel/container.lua
local Container = {}
Container.__index = Container

function Container.new()
  return setmetatable({
    _registrations = {},
    _instances = {}
  }, Container)
end

function Container:register(name, factory, options)
  options = options or {}
  self._registrations[name] = {
    factory = factory,
    singleton = options.singleton or false,
    implements = options.implements,
    depends = options.depends or {}
  }
end

function Container:resolve(name, args)
  local reg = self._registrations[name]
  if not reg then
    error("Unknown component: " .. name)
  end

  if reg.singleton and self._instances[name] then
    return self._instances[name]
  end

  -- Resolve dependencies
  local deps = {}
  for _, dep_name in ipairs(reg.depends) do
    deps[dep_name] = self:resolve(dep_name)
  end

  local instance = reg.factory(deps, args)

  if reg.singleton then
    self._instances[name] = instance
  end

  return instance
end

return Container
```

## References

- Roadmap Section 0.1: Principle 3 - Dependency Injection Container
- ISS-003: Hardcoded Dependencies in whisker_loader.lua
- ISS-004: Engine Creates Internal Dependencies
