# Vendored tinta Changes

Changes made to the vendored tinta library for whisker-core integration.

## Files Added

| File | Purpose |
|------|---------|
| `init.lua` | Entry point that sets up import() function and provides whisker-core compatible API |
| `VERSION` | Tracks source repository and commit hash |
| `LICENSE` | MIT license from original repository |
| `CHANGES.md` | This file |

## Modifications to Original Code

**None.** The vendored tinta code is unmodified from the source repository.

All adaptation is handled through `init.lua` which:
1. Provides a global `import()` function that translates tinta's path format to Lua `require()` calls
2. Sets up required globals (`compat`, `dump`)
3. Exposes a clean API for whisker-core integration

## Module Loading Adaptation

tinta uses a custom `import()` function with paths like:
```lua
import("../engine/story")
import("../values/string")
```

The `init.lua` translates these to standard Lua requires:
```lua
require("whisker.vendor.tinta.engine.story")
require("whisker.vendor.tinta.values.string")
```

## Globals Set by tinta

When `tinta.Story()` is called, the following globals are set:

### By init.lua
- `import` - Path translation function
- `compat` - Lua version compatibility utilities
- `dump` - Debug printing utility

### By ink_header.lua (loaded automatically)
- `classic` - OOP library
- `lume` - Utility library
- `inkutils` - Ink-specific utilities
- `PRNG` - Pseudo-random number generator
- `serialization` - JSON/Lua serialization
- `DelegateUtils` - Event delegation utilities
- Plus many value types (BaseValue, Container, Choice, etc.)

## Usage

```lua
local tinta = require("whisker.vendor.tinta")

-- Get Story constructor
local Story = tinta.Story()

-- Or create story directly
local story = tinta.create_story(story_definition)
```
