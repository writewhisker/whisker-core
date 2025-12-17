# Ink Conversion Fidelity

This document describes the fidelity of conversions between Ink JSON and whisker-core format, including any lossy transformations.

## Overview

Whisker-core provides bidirectional conversion between Ink JSON format and its native story format:

- **Ink → Whisker**: Full fidelity for supported features
- **Whisker → Ink**: Full fidelity for whisker-origin stories

## Supported Features

### Full Support (Lossless)

| Feature | Import | Export | Notes |
|---------|--------|--------|-------|
| Knots | ✓ | ✓ | Maps to passages with simple IDs |
| Stitches | ✓ | ✓ | Maps to passages with dot-notation IDs |
| Text content | ✓ | ✓ | Preserved exactly |
| Once-only choices | ✓ | ✓ | Default choice type |
| Sticky choices | ✓ | ✓ | Preserved via sticky flag |
| Fallback choices | ✓ | ✓ | Preserved via fallback flag |
| Simple diverts | ✓ | ✓ | Target path preserved |
| DONE/END | ✓ | ✓ | Special target handling |
| Global variables | ✓ | ✓ | Name, type, default preserved |
| Integer/float/string/boolean types | ✓ | ✓ | Type inference on import |
| Arithmetic operators | ✓ | ✓ | Direct mapping |
| Comparison operators | ✓ | ✓ | ~= ↔ != mapping |
| Logical operators | ✓ | ✓ | and ↔ &&, or ↔ ||, not ↔ ! |
| Tags | ✓ | ✓ | Preserved as metadata |
| Tunnel diverts | ✓ | ✓ | Call stack semantics |
| Tunnel returns | ✓ | ✓ | ->-> marker |
| Gathers | ✓ | ✓ | Named and anonymous |

### Partial Support

| Feature | Import | Export | Notes |
|---------|--------|--------|-------|
| Threads | ✓ | ✓ | Basic gathering supported; complex patterns may require runtime |
| Lists | ✓ | ✓ | Simple lists supported; operations limited |
| Visit counts | ✓ | ✓ | CNT? reference; complex uses may vary |
| External functions | ✓ | - | Declarations preserved; bindings not exported |
| Flows | ✓ | - | Import supported; export not implemented |

### Known Limitations

1. **Complex conditionals**: Deeply nested conditionals may not round-trip perfectly
2. **Inline alternatives**: Sequence variations ({&shuffle|options}) preserved at runtime only
3. **Glue markers**: Whitespace control preserved but may differ in output
4. **Function definitions**: Ink functions not converted (use external functions)

## Round-Trip Verification

### Test Categories

1. **Structural tests**: Verify passage/knot/stitch structure preserved
2. **Content tests**: Verify text content byte-for-byte identical
3. **Choice tests**: Verify choice counts and properties match
4. **Variable tests**: Verify variable declarations and defaults
5. **Functional tests**: Verify same playthrough behavior

### Comparison Algorithm

The `Compare` module performs structural comparison:

```lua
local Compare = require("whisker.formats.ink.compare")
local cmp = Compare.new()

local match, differences = cmp:compare(original, converted)

if not match then
  print(cmp:generate_report())
end
```

### Difference Types

| Type | Severity | Description |
|------|----------|-------------|
| `missing_passage` | Error | Passage exists in original but not converted |
| `extra_passage` | Warning | Passage exists in converted but not original |
| `content_mismatch` | Error | Text content differs |
| `choice_count_mismatch` | Error | Number of choices differs |
| `missing_variable` | Error | Variable not present in converted |
| `variable_type_mismatch` | Warning | Variable type changed |
| `variable_default_mismatch` | Warning | Default value changed |
| `start_mismatch` | Warning | Start passage differs |

## Fidelity Metrics

When converting stories, the following metrics are tracked:

- **Passages converted**: Total passage count
- **Choices converted**: Total choice count
- **Variables converted**: Total variable count
- **Warnings generated**: Non-critical issues
- **Errors generated**: Critical issues

## Best Practices

### For Ink → Whisker

1. Use simple, flat structure when possible
2. Avoid deeply nested conditionals
3. Use external functions for complex logic
4. Test with the validation module before deployment

### For Whisker → Ink

1. Use dot-notation for stitch-like passages
2. Set explicit start passage
3. Define variable types explicitly
4. Avoid whisker-specific features not in Ink

## Version Compatibility

- **Ink JSON Version**: 19+ (targets version 20)
- **tinta Compatibility**: Full runtime support
- **inklecate Compatibility**: Verified with inklecate output

## Testing

Run round-trip tests:

```bash
busted spec/formats/ink/roundtrip_spec.lua
```

Run full Ink test suite:

```bash
busted spec/formats/ink/
```
