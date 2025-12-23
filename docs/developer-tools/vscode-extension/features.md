# VSCode Extension Features

Complete reference for Whisker VSCode extension capabilities.

## Language Support

### Supported Formats

| Format | Extensions | Features |
|--------|------------|----------|
| Ink | `.ink` | Full support |
| Twee | `.twee`, `.tw` | Full support |
| WhiskerScript | `.wscript` | Full support |

### Syntax Highlighting

The extension provides semantic highlighting for:

- **Passage headers**: Emphasized styling
- **Choices**: Distinct color for choice markers
- **Diverts**: Navigation arrow styling
- **Variables**: Highlighted in expressions
- **Comments**: Dimmed styling
- **Tags**: Attribute coloring
- **Strings**: Quote styling

## IntelliSense Features

### Auto-Completion

#### Passage Completion

Triggered after `->` in Ink/WhiskerScript or inside `[[` in Twee:

- Shows all defined passages
- Sorts by relevance
- Includes passage preview

#### Variable Completion

Triggered inside `{}` in Ink or after `$` in Twee:

- Shows all defined variables
- Displays variable type
- Shows current/initial value

#### Tag Completion

Triggered after `#` in Ink passage headers:

- Suggests common tags
- Shows tag usage count

### Signature Help

When typing function-like macros, shows:

- Parameter names
- Parameter types
- Description

### Hover Information

Hover over elements for details:

| Element | Information Shown |
|---------|------------------|
| Passage name | Line number, tags, excerpt |
| Variable | Type, initial value, assignments |
| Divert | Target passage preview |
| Choice | Target and inline text |
| Tag | Usage count and examples |

## Diagnostics

### Error Types

| Severity | Issue | Description |
|----------|-------|-------------|
| Error | Undefined passage | Reference to non-existent passage |
| Error | Undefined variable | Use of undeclared variable |
| Error | Syntax error | Invalid syntax |
| Warning | Unreachable passage | Passage never visited |
| Warning | Unused variable | Variable set but never read |
| Info | Style suggestion | Naming convention hints |

### Quick Fixes

Click the lightbulb icon for automatic fixes:

- **Create passage**: Generate missing passage stub
- **Rename passage**: Fix typos in passage names
- **Remove unused**: Delete dead code

## Navigation

### Go to Definition

Works for:
- Passage references
- Variable references
- Included files

Shortcuts:
- `F12`
- `Ctrl+Click` / `Cmd+Click`
- Right-click > "Go to Definition"

### Find All References

Find everywhere a passage or variable is used:

- `Shift+F12`
- Right-click > "Find All References"

### Document Symbols

View story structure in Outline panel:

- Passages listed hierarchically
- Variables grouped separately
- Tags as attributes

Shortcut: `Ctrl+Shift+O` / `Cmd+Shift+O`

### Workspace Symbols

Search across all story files:

- `Ctrl+T` / `Cmd+T`
- Type passage or variable name

## Preview Panel

### Features

- **Live rendering**: See story as players will
- **Choice navigation**: Click to follow paths
- **Variable display**: Current state sidebar
- **History**: Back button for navigation
- **Themes**: Light, dark, or auto

### Controls

| Action | Method |
|--------|--------|
| Open preview | Click eye icon or command |
| Follow choice | Click choice button |
| Go back | Click back arrow |
| Restart | Click restart button |
| Toggle variables | Click variables button |

### Settings

```json
{
  "whisker.preview.liveUpdate": false,
  "whisker.preview.theme": "auto"
}
```

## Graph Visualization

### Node Types

| Color | Meaning |
|-------|---------|
| Green | Start passage |
| White | Normal passage |
| Orange | Unreachable passage |
| Red | Undefined target |

### Edge Types

| Style | Meaning |
|-------|---------|
| Solid | Direct divert |
| Dashed | Choice navigation |

### Layout Options

```json
{
  "whisker.graph.layout": "TD"
}
```

Options: `TD` (top-down), `LR` (left-right), `BT` (bottom-top), `RL` (right-left)

### Export

Right-click graph to:
- Copy as Mermaid
- Copy as DOT
- Save as PNG
- Save as SVG

## Debugging

### Breakpoint Types

| Type | Description |
|------|-------------|
| Line | Stop at specific line |
| Conditional | Stop when condition is true |
| Hit count | Stop after N hits |

### Debug Views

- **Variables**: Current story state
- **Watch**: Custom expressions
- **Call Stack**: Passage navigation history
- **Breakpoints**: All breakpoints list

### Debug Console

Execute expressions while paused:

```
> player_health + 10
110
> visited("Cave")
true
```

## Formatting

### Formatting Rules

- Consistent passage header spacing
- Aligned choice markers
- Normalized indentation
- Trimmed trailing whitespace
- Consistent blank lines between passages

### Configuration

Create `.whisker-fmt.json`:

```json
{
  "indent_style": "space",
  "indent_size": 2,
  "max_line_length": 100,
  "blank_lines_between": 1
}
```

## Snippets

### Available Snippets

#### Ink

| Trigger | Result |
|---------|--------|
| `passage` | `=== Name ===` |
| `choice` | `* [text] -> target` |
| `sticky` | `+ [text] -> target` |
| `divert` | `-> target` |
| `var` | `~ name = value` |
| `if` | Conditional block |
| `include` | `INCLUDE file.ink` |

#### Twee

| Trigger | Result |
|---------|--------|
| `passage` | `:: Name` |
| `link` | `[[text|target]]` |
| `set` | `<<set $var = value>>` |
| `if` | `<<if condition>>` |
| `print` | `<<print $var>>` |

#### WhiskerScript

| Trigger | Result |
|---------|--------|
| `passage` | `passage "Name" { }` |
| `text` | `text "content"` |
| `choice` | `choice "text" { }` |
| `if` | `if condition { }` |

## Commands

All commands accessible via `Ctrl+Shift+P` / `Cmd+Shift+P`:

| Command | Description |
|---------|-------------|
| Whisker: New Story | Create new story file |
| Whisker: Preview Story | Open preview panel |
| Whisker: View Story Graph | Open graph visualization |
| Whisker: Format Document | Format current file |
| Whisker: Debug Story | Start debugging |
| Whisker: Restart Language Server | Restart LSP server |

## Settings Reference

```json
{
  // Language Server
  "whisker.lsp.serverPath": "whisker-lsp",
  "whisker.lsp.logLevel": "info",
  "whisker.lsp.trace": "off",

  // Preview
  "whisker.preview.liveUpdate": false,
  "whisker.preview.theme": "auto",

  // Graph
  "whisker.graph.layout": "TD",

  // Debug
  "whisker.debug.adapterPath": "whisker-debug"
}
```
