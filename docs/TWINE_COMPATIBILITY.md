# Twine Format Compatibility

whisker-core provides bidirectional conversion between whisker stories and Twine HTML formats. This document details support levels for each format.

## Supported Formats

| Format | Version | Import | Export | Support Level |
|--------|---------|--------|--------|---------------|
| Harlowe | 3.0.0+ | ✅ | ✅ | ~75% macros |
| SugarCube | 2.30.0+ | ✅ | ✅ | ~80% macros |
| Chapbook | 1.0.0+ | ✅ | ✅ | ~90% features |
| Snowman | 2.0.0+ | ⚠️ | ⚠️ | Basic support |

**Legend**:
- ✅ Full support: Production-ready
- ⚠️ Partial support: Works with limitations
- ❌ Not supported

## Format Selection Guide

### Use Harlowe if:
- Writing narrative-focused interactive fiction
- Want natural language-like syntax
- Need beginner-friendly macros
- Prefer built-in data types (arrays, datamaps)

### Use SugarCube if:
- Building complex games with heavy state management
- Need custom widgets/components
- Want JavaScript integration
- Require precise control over passage lifecycle

### Use Chapbook if:
- Writing text-heavy stories
- Prefer markdown formatting
- Want minimal syntax
- Need quick prototyping

### Use Snowman if:
- You're a JavaScript developer
- Want full control over story engine
- Need custom DOM manipulation
- Prefer templates over macros

## Macro Compatibility

### Harlowe

#### Core Macros (100% supported)

| Macro | Support | Notes |
|-------|---------|-------|
| `(set:)` | ✅ | Full support including chaining |
| `(put:)` | ✅ | Translates to (set:) |
| `(if:)` | ✅ | Including (else-if:) and (else:) |
| `(link:)` | ✅ | Both (link:) and (link-goto:) |
| `(goto:)` | ✅ | Direct translation |
| `(display:)` | ✅ | Embeds passage content |

#### Advanced Macros (75% supported)

| Macro | Support | Notes |
|-------|---------|-------|
| `(for:)` | ✅ | Each-style loops |
| `(a:)` | ✅ | Array creation |
| `(dm:)` | ✅ | Datamap creation |
| `(live:)` | ⚠️ | Executes once (no live updates in text mode) |
| `(event:)` | ⚠️ | Simplified event handling |
| `(append:)` | ✅ | Named hook manipulation |
| `(replace:)` | ✅ | Named hook replacement |

#### Unsupported Macros

| Macro | Status | Alternative |
|-------|--------|-------------|
| `(enchant:)` | ❌ | Use CSS styling |
| `(transition:)` | ❌ | Not applicable in text mode |
| `(animate:)` | ❌ | Not applicable in text mode |
| `(track:)` | ❌ | Use variables for tracking |
| `(dialog:)` | ❌ | Use passages for dialogs |

### SugarCube

#### Core Macros (100% supported)

| Macro | Support | Notes |
|-------|---------|-------|
| `<<set>>` | ✅ | All assignment forms (=, +=, ++, etc.) |
| `<<unset>>` | ✅ | Variable deletion |
| `<<if>>` | ✅ | Including <<elseif>> and <<else>> |
| `<<link>>` | ✅ | Both link and button variants |
| `<<goto>>` | ✅ | Direct translation |
| `<<print>>` | ✅ | Also <<=>>, <<->> |

#### Advanced Macros (80% supported)

| Macro | Support | Notes |
|-------|---------|-------|
| `<<for>>` | ✅ | C-style and range loops |
| `<<switch>>` | ✅ | Multi-case branching |
| `<<widget>>` | ⚠️ | Basic support, complex widgets may fail |
| `<<script>>` | ⚠️ | Simple JS translates to Lua, complex warns |
| `<<run>>` | ⚠️ | Limited JavaScript translation |
| `<<nobr>>` | ✅ | Whitespace stripping |
| `<<capture>>` | ✅ | Variable scoping |

#### Unsupported Macros

| Macro | Status | Alternative |
|-------|--------|-------------|
| `<<audio>>` | ❌ | Not supported in text mode |
| `<<cacheaudio>>` | ❌ | N/A |
| `<<createaudiogroup>>` | ❌ | N/A |
| `<<waitforaudio>>` | ❌ | N/A |
| `<<type>>` | ❌ | No typing animation in text mode |

### Chapbook

#### Modifiers (90% supported)

| Modifier | Support | Notes |
|----------|---------|-------|
| `[if]` | ✅ | Full conditional support |
| `[unless]` | ✅ | Negated conditionals |
| `[after]` | ⚠️ | Displays immediately (no delay in text mode) |
| `[continue]` | ✅ | Interaction prompt |
| `[align]` | ⚠️ | Limited text alignment |
| `[note]` | ✅ | Aside/note display |

#### Inserts (100% supported)

| Insert | Support | Notes |
|--------|---------|-------|
| `{variable}` | ✅ | Variable interpolation |
| `{var, default: val}` | ✅ | Default values |
| `{random(min, max)}` | ✅ | Random numbers |
| `{either(...)}` | ✅ | Random choice |

### Snowman

| Feature | Support | Notes |
|---------|---------|-------|
| `<%= expr %>` | ⚠️ | Simple expressions only |
| `<% code %>` | ⚠️ | Limited JS to Lua translation |
| `s.variable` | ✅ | Translates to whisker variables |
| `window.story.show()` | ✅ | Translates to goto |
| Underscore.js | ❌ | Limited support |
| DOM manipulation | ❌ | Not available in text mode |

## Conversion Notes

### Harlowe → whisker-core

**Automatic conversions**:
- `(set: $var to value)` → `@set var = value`
- `(if: condition)[body]` → `@if condition ... @end`
- `$var's 1st` → `var[1]` (array access)

**Manual review needed**:
- `(live:)` macros - check behavior
- Complex (enchant:) usage - rework as CSS
- Named hooks with complex manipulation

### SugarCube → whisker-core

**Automatic conversions**:
- `<<set $var to value>>` → `@set var = value`
- `<<if condition>>` → `@if condition`
- `State.variables.x` → `x` (in <<script>>)

**Manual review needed**:
- Custom <<widget>> definitions - test thoroughly
- <<script>> blocks with complex JS - may need Lua rewrite
- Save system usage - whisker-core has different save mechanism

### Chapbook → whisker-core

**Automatic conversions**:
- `variableName: value` → `@set variableName = value`
- `[if condition]` → `@if condition`
- `{variable}` → `{variable}` (interpolation preserved)

**Manual review needed**:
- `[after]` modifiers - timing not preserved
- Markdown formatting - ensure preserved correctly

### Snowman → whisker-core

**Automatic conversions**:
- `s.variable` → `variable`
- `<% if (condition) { %>` → `@if condition`
- `window.story.show()` → `@goto`

**Manual review needed**:
- All JavaScript code - translation is best-effort
- DOM queries - need alternative approaches
- Async operations - not supported

## Round-Trip Conversion

### What's Preserved

- **Story structure**: Passage names, links, hierarchy
- **Variables**: Names, assignments, references
- **Logic**: Conditionals, loops, branches
- **Text content**: Including markdown and HTML
- **Metadata**: Story title, IFID, tags

### What May Change

- **Whitespace**: Formatting may differ
- **Comments**: May be removed
- **Operator syntax**: `is` ↔ `==`, etc.
- **Variable sigils**: `$var` may become `var` (format-dependent)

### What's Lost

- **Live updates**: (live:), timed events
- **Animations**: Transitions, enchantments
- **Audio**: Sound effects, music
- **Custom CSS/JS**: May not translate
- **Format-specific features**: Special macros

## Best Practices

### For Twine Authors Migrating to whisker-core

1. **Start with core features**: Use basic macros (set, if, link) first
2. **Test incrementally**: Import passages one at a time
3. **Review warnings**: Check console for unsupported features
4. **Simplify macros**: Break complex chains into multiple statements
5. **Avoid format-specific**: Stick to common Twine patterns

### For whisker-core Authors Exporting to Twine

1. **Choose target format carefully**: Match features you use
2. **Test in Twine editor**: Open exported HTML in Twine to verify
3. **Keep macros simple**: Complex WhiskerScript may not translate perfectly
4. **Document assumptions**: Note any manual changes needed after export
5. **Version control**: Keep whisker-core source as primary

## Troubleshooting

### Common Issues

**Problem**: "Unsupported macro" warning during import

**Solution**: Check compatibility matrix above. Either:
- Remove unsupported macro from source
- Use alternative approach
- Accept warning if feature optional

---

**Problem**: Round-trip changes variable names

**Solution**: Variable name preservation is format-dependent:
- Harlowe/SugarCube: Preserve `$var` prefix
- Chapbook: No prefix (vars may lose `$` when exported)
- Use consistent naming to avoid confusion

---

**Problem**: Links broken after export/import

**Solution**:
- Verify passage names unchanged
- Check for special characters in passage names
- Ensure no duplicate passage names

---

**Problem**: JavaScript in <<script>> doesn't translate

**Solution**:
- Rewrite as WhiskerScript/Lua
- Use supported macro equivalents
- Mark as custom code that won't translate

## See Also

- [Twine Import Guide](TWINE_IMPORT_GUIDE.md)
- [Twine Export Guide](TWINE_EXPORT_GUIDE.md)
