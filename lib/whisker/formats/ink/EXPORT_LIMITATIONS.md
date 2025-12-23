# Ink Export Limitations

This document describes the capabilities and limitations of exporting Whisker stories to Ink JSON format.

## Fully Supported Features

- [x] Basic passages (knots)
- [x] Text content
- [x] Simple choices (once-only and sticky)
- [x] Choice targets (diverts)
- [x] Tags
- [x] Global variables (simple types)

## Partially Supported Features

| Feature | Support Level | Notes |
|---------|--------------|-------|
| Variables | Partial | Strings, numbers, booleans only. Lists and complex types may not convert. |
| Conditionals | Basic | Simple conditions export; complex nested logic may not preserve structure. |
| Weave/Gathers | Partial | Converted to flat knots; nesting structure may be lost. |
| Stitches | Partial | Exported as separate knots with prefixed names. |

## Not Supported

- [ ] Whisker-specific plugins
- [ ] Custom script expressions that don't map to Ink
- [ ] Multimedia content (images, audio)
- [ ] Whisker extension metadata
- [ ] Complex conditional logic with external dependencies
- [ ] Non-Ink-compatible choice types

## Round-Trip Fidelity

When exporting a Whisker story to Ink and re-importing:

| Content Type | Fidelity | Notes |
|--------------|----------|-------|
| Passage count | ~95% | Some structural passages may merge or split |
| Text content | 100% | Preserved exactly |
| Choices | ~90% | Once-only vs sticky may need verification |
| Variables | ~80% | Simple types only; initial values may differ |
| Conditionals | ~70% | Complex logic may simplify |
| Tags | 100% | Fully preserved |

## Known Issues

### 1. Variable Type Coercion
Ink JSON requires specific value representations. Some Whisker variable types may be coerced during export:
- Tables become JSON objects (may not be valid Ink lists)
- Functions cannot be exported

### 2. Passage Naming
Ink has restrictions on knot names (alphanumeric + underscore). Passages with incompatible names will be transformed:
- Spaces become underscores
- Special characters are removed
- Numbers at start get prefixed with underscore

### 3. Choice Complexity
Ink's choice flags encode specific behaviors. Some Whisker choice patterns may not map exactly:
- Conditional choices need careful validation
- Choice-only vs start content may be approximated

## Validation Recommendations

After exporting, we recommend:

1. **Load in tinta**: Verify the JSON loads without errors
2. **Run through story**: Test all paths manually
3. **Compare variables**: Check variable values match expectations
4. **Test with inklecate**: If available, run `inklecate -s` on the JSON

## Improving Export Fidelity

To maximize export quality:

1. Use simple variable types (string, number, boolean)
2. Avoid Whisker-specific extensions in exportable content
3. Use Ink-compatible passage names
4. Test incrementally as you build

## Reporting Issues

If you encounter export problems:

1. Create a minimal reproduction case
2. Include the original Whisker story
3. Show the exported Ink JSON
4. Describe expected vs actual behavior
5. Report to the whisker-core issue tracker
