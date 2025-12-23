# Tinta Vendoring Information

**Upstream:** https://github.com/smwhr/tinta
**Version:** Latest (commit from Dec 2024)
**Vendored Date:** 2024-12-19
**License:** MIT (see LICENSE file)
**Modifications:** See MODIFICATIONS.md

## About Tinta

Tinta is a Lua implementation of inkle's Ink runtime for interactive narrative.
It provides full compatibility with the Ink specification and supports:

- Complete Ink JSON runtime
- Variables and observation
- External function binding
- Multi-flow (threads)
- Save/load state
- Async continuation

## Updating from Upstream

To update from upstream:

1. Clone the latest tinta
2. Copy source files to `vendor/tinta/source/`
3. Re-apply modifications from MODIFICATIONS.md
4. Run vendor verification tests
5. Run integration tests
6. Update this file with new version info

## Directory Structure

```
vendor/tinta/
  LICENSE           - MIT license (original)
  README.md         - Original README
  VENDOR.md         - This file
  MODIFICATIONS.md  - Change log
  source/           - Tinta source code
    engine/         - Core runtime
    values/         - Value types
    constants/      - Constants
    libs/           - Utility libraries
    compat/         - Lua compatibility
```

## Integration Points

Tinta is wrapped by the following whisker-core modules:

- `lib/whisker/formats/ink/runtime.lua` - Adapter layer
- `lib/whisker/formats/ink/init.lua` - IFormat implementation

Do not require tinta directly outside of these modules.
