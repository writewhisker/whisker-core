# ADR-001: Microkernel Architecture

**Status:** Accepted
**Date:** 2025-12-16
**Deciders:** whisker-core maintainers

## Context

The whisker-core framework requires "extreme modularity" to support:
- Multiple Lua versions (5.1, 5.2, 5.3, 5.4, LuaJIT)
- Multiple platforms (CLI, web, desktop, embedded)
- Optional features that can be omitted to reduce size
- Swappable implementations of core services

The current architecture (ISS-001) has no central coordination mechanism. Modules depend directly on each other via `require()`, creating tight coupling and making it impossible to swap implementations or run with reduced feature sets.

## Decision

We will implement a **microkernel architecture** where:

1. **The kernel is minimal** (< 200 lines total)
   - Only provides: module registry, capability detection, bootstrap
   - No business logic, no story processing
   - Zero dependencies beyond Lua standard library

2. **All functionality is in modules**
   - Even "core" features (state, history, variables) are modules
   - Modules register with the kernel at startup
   - Modules declare their capabilities and dependencies

3. **The kernel provides:**
   - `registry` - Module registration and lookup
   - `capabilities` - Feature flag queries
   - `bootstrap()` - System initialization

4. **The kernel does NOT provide:**
   - Dependency injection (separate container module)
   - Event bus (separate events module)
   - Any story/passage/choice logic

## Consequences

### Positive

- **Extreme flexibility:** Any module can be replaced or omitted
- **Testability:** Kernel can be tested with zero modules loaded
- **Size optimization:** Minimal builds exclude unused modules
- **Platform adaptation:** Platform-specific modules swap seamlessly
- **Clear boundaries:** Kernel vs module responsibilities well-defined

### Negative

- **Indirection overhead:** Module lookup vs direct `require()`
- **Bootstrap complexity:** Modules must register before use
- **Learning curve:** Developers must understand module patterns

### Neutral

- Existing modules continue to work during migration
- Compatibility shims bridge old and new APIs

## Implementation

```lua
-- lib/whisker/kernel/init.lua
local Kernel = {
  _VERSION = "0.1.0",
  _modules = {},
  _capabilities = {}
}

function Kernel.bootstrap()
  -- Minimal initialization, no module loading
end

function Kernel.register(name, module)
  Kernel._modules[name] = module
  if module._whisker and module._whisker.capability then
    Kernel._capabilities[module._whisker.capability] = true
  end
end

function Kernel.get(name)
  return Kernel._modules[name]
end

function Kernel.has_capability(name)
  return Kernel._capabilities[name] == true
end

return Kernel
```

## References

- Roadmap Section 0.1: Core Architectural Principles
- Roadmap Principle 1: Microkernel Architecture
- ISS-001: Missing Microkernel Infrastructure
