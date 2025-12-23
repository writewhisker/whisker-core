# Tinta Modifications for Whisker-Core

This document tracks all changes made to the vendored tinta library for whisker-core compatibility.

## Modification Philosophy

- Minimal changes required
- Prefer additive changes over modifications
- Document rationale for each change
- Enable future upstream updates

## Modification Log

### [2024-12-19] Initial Vendoring

**Status:** Clean vendor, no modifications required

Tinta was evaluated and found to be compatible with whisker-core architecture:

1. **Instance Isolation:** Stories are independent objects with no shared state
2. **Pure Lua:** No FFI or C dependencies
3. **Clean API:** Maps well to IFormat interface
4. **Observer Support:** Built-in variable observation

## Planned Modifications

The following modifications may be needed during integration:

### 1. JSON Library Injection (if needed)

**Purpose:** Allow whisker-core to provide JSON library
**Location:** TBD during integration
**Type:** Additive

### 2. Enhanced Observers (if needed)

**Purpose:** Additional hooks for whisker-core events
**Location:** TBD during integration
**Type:** Additive

## Compatibility Notes

### Lua Version Support

Tinta is compatible with:
- Lua 5.1, 5.2, 5.3, 5.4
- LuaJIT

### Dependencies

Tinta includes bundled utility libraries:
- `classic.lua` - OOP library
- `lume.lua` - Utility functions
- `prng.lua` - Pseudo-random number generator
- `serialization.lua` - JSON handling
- `inkutils.lua` - Ink-specific utilities
- `delegate.lua` - Event delegation

These are internal to tinta and should not be used directly.

## Testing After Modifications

After any modification:

1. Run vendor verification tests:
   ```bash
   busted tests/vendor/tinta_vendor_spec.lua
   ```

2. Run integration tests:
   ```bash
   busted tests/integration/ink_spec.lua
   ```

3. Verify multiple instance isolation

4. Update this document with the modification details

## Upstream Contributions

The following modifications could be contributed upstream:

| Modification | Status | Notes |
|--------------|--------|-------|
| (None yet)   | -      | -     |
