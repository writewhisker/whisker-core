# Ink Compatibility Matrix

This document provides a comprehensive overview of Ink feature support in whisker-core.

## Feature Support Levels

- **Full**: Complete support, lossless conversion
- **Partial**: Basic support, some limitations
- **Runtime**: Supported during execution only
- **None**: Not currently supported

## Structural Features

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Knots (`=== name ===`) | ✓ | ✓ | Full | Maps to top-level passages |
| Stitches (`= name`) | ✓ | ✓ | Full | Maps to dot-notation passages |
| Gathers (`-`) | ✓ | ✓ | Full | Named and anonymous |
| Labels | ✓ | ✓ | Full | Included in passage metadata |
| Comments | - | - | None | Stripped during compilation |

## Navigation

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Diverts (`->`) | ✓ | ✓ | Full | Target path preserved |
| DONE | ✓ | ✓ | Full | End current section |
| END | ✓ | ✓ | Full | End story |
| Tunnels (`->->`) | ✓ | ✓ | Full | Call stack semantics |
| Threads (`<-`) | ✓ | ✓ | Partial | Basic gathering |

## Choices

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Once-only (`*`) | ✓ | ✓ | Full | Default choice type |
| Sticky (`+`) | ✓ | ✓ | Full | Repeatable choices |
| Fallback | ✓ | ✓ | Full | Auto-select when no others |
| Conditional choices | ✓ | ✓ | Full | Guard expressions |
| Choice text `[brackets]` | ✓ | ✓ | Full | Choice-only vs output text |
| Nested choices | ✓ | ✓ | Full | Via gather structure |

## Variables

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Global VAR | ✓ | ✓ | Full | Name, type, default |
| Temporary (temp) | ✓ | ✓ | Full | Scoped variables |
| Integer | ✓ | ✓ | Full | Numeric type |
| Float | ✓ | ✓ | Full | Decimal type |
| String | ✓ | ✓ | Full | Text type |
| Boolean | ✓ | ✓ | Full | true/false |
| Lists | ✓ | ✓ | Partial | Basic list support |
| Divert targets | ✓ | - | Partial | Import only |

## Logic and Expressions

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Arithmetic (`+`, `-`, `*`, `/`, `%`) | ✓ | ✓ | Full | Direct mapping |
| Comparison (`==`, `!=`, `<`, `>`, `<=`, `>=`) | ✓ | ✓ | Full | ~= ↔ != |
| Logical (`and`, `or`, `not`) | ✓ | ✓ | Full | && \|\| ! |
| Assignment (`=`) | ✓ | ✓ | Full | Simple assignment |
| Compound (`+=`, `-=`, `*=`, `/=`) | ✓ | ✓ | Full | Expanded form |
| Increment/decrement | ✓ | ✓ | Full | Via compound |
| Visit counts | ✓ | ✓ | Full | CNT? reference |

## Conditionals

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Inline `{condition}` | ✓ | ✓ | Full | Boolean evaluation |
| If/else | ✓ | ✓ | Full | Branch structure |
| Switch/case | ✓ | ✓ | Partial | Converted to if/else |
| Nested conditionals | ✓ | ✓ | Partial | May require flattening |

## Text Features

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Plain text | ✓ | ✓ | Full | Exact preservation |
| Tags (`#`) | ✓ | ✓ | Full | As metadata |
| Glue (`<>`) | ✓ | ✓ | Full | Whitespace control |
| String interpolation | ✓ | - | Runtime | Evaluated at runtime |

## Sequences

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| Cycle `{&a|b|c}` | ✓ | - | Runtime | Runtime evaluation |
| Shuffle `{~a|b|c}` | ✓ | - | Runtime | Runtime evaluation |
| Stopping `{a|b|c}` | ✓ | - | Runtime | Runtime evaluation |
| Once `{!a|b|c}` | ✓ | - | Runtime | Runtime evaluation |

## Advanced Features

| Feature | Import | Export | Level | Notes |
|---------|--------|--------|-------|-------|
| External functions | ✓ | - | Partial | Declarations only |
| Variable observers | ✓ | - | Runtime | Event-based |
| Flows | ✓ | - | Partial | Import supported |
| Save/Load state | ✓ | ✓ | Full | State serialization |

## Runtime Features

These features require the Ink runtime and are not statically converted:

| Feature | Support | Notes |
|---------|---------|-------|
| External function calls | ✓ | Lua bindings |
| Variable observation | ✓ | Event system |
| State persistence | ✓ | Snapshot/restore |
| Choice tracking | ✓ | Visit counts |
| Flow management | ✓ | Parallel contexts |

## Ink JSON Version Support

| Version | Status | Notes |
|---------|--------|-------|
| 21 | ✓ | Current target |
| 20 | ✓ | Default export version |
| 19 | ✓ | Minimum supported |
| 18 | ~ | Limited testing |
| <18 | ✗ | Not supported |

## Known Limitations

1. **Complex list operations**: Advanced list manipulation limited
2. **Function definitions**: Ink functions not converted (use external)
3. **Inline sequences**: Runtime-only evaluation
4. **Deep nesting**: Very deep conditionals may not round-trip perfectly

## Testing Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| Converter | 100+ | 85%+ |
| Exporter | 85+ | 80%+ |
| Transformers | 180+ | 85%+ |
| Generators | 125+ | 80%+ |
| Validator | 53 | 90%+ |
| Round-trip | 25 | 80%+ |
| Integration | 20+ | 75%+ |

## Reporting Issues

If you encounter compatibility issues:

1. Check this matrix for known limitations
2. Verify Ink JSON version
3. Test with minimal reproduction case
4. Report with Ink source and JSON if possible
