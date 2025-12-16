# ADR-003: Event Bus for Module Communication

**Status:** Accepted
**Date:** 2025-12-16
**Deciders:** whisker-core maintainers

## Context

The audit found that `EventSystem` exists (`core/event_system.lua`, 372 lines) but is **not used** by any other modules (ISS-006). Cross-module communication happens via direct method calls, creating tight coupling.

For example, when a passage is entered:
- Engine should notify interested parties
- History service needs to record it
- Analytics might want to track it
- Debugger might want to pause

Currently, Engine would need to know about all these consumers and call them directly.

## Decision

We will implement an **Event Bus** as a kernel module that:

1. **Provides pub/sub messaging**
   ```lua
   -- Publisher (Engine)
   events:emit("passage:entered", { passage = passage })

   -- Subscriber (History) - doesn't know about Engine
   events:on("passage:entered", function(data)
     history:record(data.passage)
   end)
   ```

2. **Uses namespaced event names**
   - `passage:entered`, `passage:exited`
   - `choice:made`, `choice:available`
   - `state:changed`, `state:saved`
   - `story:loaded`, `story:started`

3. **Supports priorities**
   ```lua
   events:on("passage:entered", handler, { priority = 100 })
   ```

4. **Supports one-time listeners**
   ```lua
   events:once("story:loaded", handler)
   ```

5. **Is lightweight**
   - Part of kernel, not the existing 372-line EventSystem
   - Minimal implementation (~60 lines)
   - No queue, no history (those are optional modules)

## Consequences

### Positive

- **Decoupling:** Publishers don't know subscribers
- **Extensibility:** Add behavior without modifying existing code
- **Testability:** Can verify events were emitted
- **Debugging:** Central place to monitor all communication

### Negative

- **Indirection:** Harder to trace call flow
- **Ordering:** Must manage listener priorities
- **Memory:** Listeners must be cleaned up

### Neutral

- Existing EventSystem can be used by applications
- Kernel event bus is simpler, focused on module communication

## Implementation

```lua
-- lib/whisker/kernel/events.lua
local Events = {}
Events.__index = Events

function Events.new()
  return setmetatable({ _listeners = {} }, Events)
end

function Events:on(event, callback, options)
  options = options or {}
  if not self._listeners[event] then
    self._listeners[event] = {}
  end
  table.insert(self._listeners[event], {
    callback = callback,
    priority = options.priority or 0,
    once = options.once or false
  })
  -- Sort by priority (higher first)
  table.sort(self._listeners[event], function(a, b)
    return a.priority > b.priority
  end)
end

function Events:once(event, callback, options)
  options = options or {}
  options.once = true
  self:on(event, callback, options)
end

function Events:off(event, callback)
  if not self._listeners[event] then return end
  for i = #self._listeners[event], 1, -1 do
    if self._listeners[event][i].callback == callback then
      table.remove(self._listeners[event], i)
    end
  end
end

function Events:emit(event, data)
  if not self._listeners[event] then return end
  local to_remove = {}
  for i, listener in ipairs(self._listeners[event]) do
    listener.callback(data)
    if listener.once then
      table.insert(to_remove, i)
    end
  end
  for i = #to_remove, 1, -1 do
    table.remove(self._listeners[event], to_remove[i])
  end
end

return Events
```

## Standard Events

| Event | Data | Emitted By |
|-------|------|------------|
| `passage:entered` | `{passage, previous}` | Engine |
| `passage:exited` | `{passage, next}` | Engine |
| `choice:made` | `{choice, passage}` | Engine |
| `state:changed` | `{key, old, new}` | State Service |
| `story:loaded` | `{story}` | Loader |
| `story:started` | `{story, passage}` | Engine |

## References

- Roadmap Section 0.1: Principle 4 - Event-Driven Communication
- Roadmap Section 0.4: Module Communication Patterns
- ISS-006: Event System Not Integrated
