# Plugin Examples

This directory contains example plugins demonstrating various plugin development patterns.

## Examples

### counter-plugin.lua

Simple plugin demonstrating:
- Basic plugin structure
- State management with `ctx.storage`
- Public API exposure
- Save/load persistence

**Key Concepts:**
- Minimal plugin structure
- Return values from API functions
- Plugin-scoped state

### timer-plugin.lua

Time tracking plugin demonstrating:
- Multiple hooks working together
- Passage tracking via `on_passage_enter`
- Computed values from stored data
- Formatted output helpers

**Key Concepts:**
- Hook coordination
- Data aggregation
- Derived calculations

## Using Examples

1. Copy example to your plugins directory:
   ```
   cp counter-plugin.lua plugins/community/
   ```

2. Load plugin in story configuration:
   ```lua
   local story = Story.new({
     plugins = {
       paths = {"plugins/builtin", "plugins/community"},
     },
   })
   ```

3. Use in story:
   ```lua
   whisker.plugin.counter.increment()
   local count = whisker.plugin.counter.get()
   ```

## Built-in Plugin Examples

For more complex examples, see the built-in plugins:

- `plugins/builtin/core/` - Utility functions
- `plugins/builtin/inventory/` - Item management
- `plugins/builtin/achievements/` - Trophy system

## Creating Your Own

1. Start with the minimal structure:
   ```lua
   return {
     name = "my-plugin",
     version = "1.0.0",
   }
   ```

2. Add lifecycle hooks as needed:
   ```lua
   on_init = function(ctx)
     -- Setup
   end
   ```

3. Add story hooks:
   ```lua
   hooks = {
     on_passage_enter = function(ctx, passage)
       -- React to passage
     end,
   }
   ```

4. Expose API:
   ```lua
   api = {
     my_function = function()
       return "result"
     end,
   }
   ```

See [Tutorial](../tutorial/) for step-by-step guidance.
