# Getting Started with Whisker VSCode Extension

The Whisker VSCode extension provides a complete development environment for interactive fiction.

## Installation

1. Install the Whisker extension from VSCode Marketplace
2. Install whisker-lsp server: `luarocks install whisker-lsp`
3. Restart VSCode

## Creating Your First Story

### Using Command Palette

1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS)
2. Type "Whisker: New Story"
3. Enter a story name (e.g., "MyAdventure")
4. Choose format: Ink, Twee, or WhiskerScript
5. Extension creates the file with a starter template

### Template Example (Ink)

```ink
=== Start ===
Welcome to your adventure!

What would you like to do?
* [Explore the cave] -> Cave
* [Climb the mountain] -> Mountain

=== Cave ===
The cave is dark and mysterious.
-> End

=== Mountain ===
The view from here is breathtaking.
-> End

=== End ===
THE END
```

## Language Features

### Auto-Completion

Type `->` to trigger passage completion:

```ink
=== Start ===
Welcome!
-> [cursor here, see passage suggestions]
```

Type `{` to trigger variable completion:

```ink
Your health: {[cursor here, see variable suggestions]}
```

### Error Checking

Red squiggles appear under errors:

- **Undefined passage**: Reference to non-existent passage
- **Undefined variable**: Use of undeclared variable
- **Unreachable passage**: Yellow warning for orphan passages

Hover over errors to see detailed messages.

### Hover Documentation

Hover over elements to see information:

- **Passages**: Description, tags, and source location
- **Variables**: Type and initial value
- **Choices**: Target passage preview

### Go to Definition

Navigate to definitions with:

- `F12` key
- `Ctrl+Click` (Windows/Linux) or `Cmd+Click` (macOS)
- Right-click > "Go to Definition"

Works for:
- Passage references -> jumps to passage header
- Variable references -> jumps to first assignment

## Story Preview

Preview your story as readers will experience it:

1. Click the **eye icon** in the editor title bar
2. Or use command: "Whisker: Preview Story"

The preview panel shows:
- Current passage content
- Available choices (click to navigate)
- Auto-updates on file save

### Live Preview (Optional)

Enable real-time preview updates:

```json
{
  "whisker.preview.liveUpdate": true
}
```

Note: May impact performance on large stories.

## Story Graph

Visualize your story structure:

1. Click the **graph icon** in the editor title bar
2. Or use command: "Whisker: View Story Graph"

The graph shows:
- **Green nodes**: Start passage
- **White nodes**: Regular passages
- **Orange nodes**: Unreachable passages
- **Red nodes**: Undefined targets
- **Arrows**: Navigation flow

## Debugging Stories

Step through your story execution:

### Setting Breakpoints

Click the gutter (left margin) next to:
- Passage headers (`=== Name ===`)
- Choice lines (`* [text] -> target`)
- Divert lines (`-> target`)

### Starting Debug Session

1. Press `F5`
2. Or use command: "Whisker: Debug Story"

### Debug Controls

- `F5`: Continue to next breakpoint
- `F10`: Step over (next line)
- `F11`: Step into (follow divert)
- `Shift+F11`: Step out (return to caller)

### Inspecting State

When paused:
- **Variables pane**: Shows all story variables
- **Call Stack pane**: Shows passage navigation history
- **Hover**: Quick view of variable values

## Code Formatting

Format your story code:

### Manual Formatting

- Command: "Whisker: Format Document"
- Keyboard: `Shift+Alt+F` (Windows/Linux) or `Shift+Option+F` (macOS)

### Format on Save

Enable auto-formatting in settings:

```json
{
  "editor.formatOnSave": true,
  "[ink]": {
    "editor.defaultFormatter": "whisker.whisker"
  },
  "[wscript]": {
    "editor.defaultFormatter": "whisker.whisker"
  },
  "[twee]": {
    "editor.defaultFormatter": "whisker.whisker"
  }
}
```

## Code Snippets

Quickly insert common patterns:

### Ink Snippets

| Prefix | Description |
|--------|-------------|
| `passage` | New passage |
| `choice` | Choice with target |
| `divert` | Divert to passage |
| `var` | Variable declaration |
| `if` | Conditional block |

### Twee Snippets

| Prefix | Description |
|--------|-------------|
| `passage` | New passage |
| `link` | Link to passage |
| `set` | Set variable |
| `if` | Conditional |

### WhiskerScript Snippets

| Prefix | Description |
|--------|-------------|
| `passage` | New passage |
| `choice` | Choice block |
| `text` | Text content |

## Keyboard Shortcuts

| Action | Windows/Linux | macOS |
|--------|--------------|-------|
| Go to Definition | `F12` | `F12` |
| Trigger Completion | `Ctrl+Space` | `Cmd+Space` |
| Format Document | `Shift+Alt+F` | `Shift+Option+F` |
| Toggle Breakpoint | `F9` | `F9` |
| Start Debugging | `F5` | `F5` |
| Command Palette | `Ctrl+Shift+P` | `Cmd+Shift+P` |

## Extension Settings

Configure in Settings (JSON):

```json
{
  // LSP Server
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

## Troubleshooting

### Extension Not Activating

1. Ensure file has `.ink`, `.wscript`, or `.twee` extension
2. Check Output panel for errors
3. Reload window: `Ctrl+Shift+P` > "Developer: Reload Window"

### Language Server Not Starting

1. Verify whisker-lsp is installed: `which whisker-lsp`
2. Check `whisker.lsp.serverPath` setting
3. View Output panel > "Whisker Language Server"

### Debugging Not Working

1. Verify whisker-debug is installed: `which whisker-debug`
2. Check `whisker.debug.adapterPath` setting
3. Ensure breakpoints are on valid lines

See [Troubleshooting Guide](../troubleshooting.md) for more solutions.
