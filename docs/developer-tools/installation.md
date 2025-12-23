# Installing Whisker Developer Tools

## Prerequisites

Before installing Whisker developer tools, ensure you have:

- **Lua**: Version 5.1 or later (including LuaJIT)
- **LuaRocks**: Lua package manager
- **VSCode**: Version 1.75+ (for the extension)
- **Node.js**: Version 18+ (for building the extension from source)

### Installing Prerequisites

#### macOS

```bash
brew install lua luarocks
```

#### Ubuntu/Debian

```bash
sudo apt install lua5.4 luarocks
```

#### Windows

Download installers from:
- Lua: https://www.lua.org/download.html
- LuaRocks: https://luarocks.org/

## Installing LSP Server

The Language Server provides IDE features like auto-completion and diagnostics.

```bash
luarocks install whisker-lsp
```

Verify installation:

```bash
whisker-lsp --version
# whisker-lsp 0.1.0
```

## Installing Debug Adapter

The debug adapter enables stepping through stories in supported editors.

```bash
luarocks install whisker-debug
```

Verify installation:

```bash
whisker-debug --version
# whisker-debug 0.1.0
```

## Installing CLI Tools

### All-in-One Installation

```bash
luarocks install whisker-graph
luarocks install whisker-repl
luarocks install whisker-lint
luarocks install whisker-fmt
```

### Individual Tools

#### whisker-graph (Story Visualizer)

```bash
luarocks install whisker-graph
whisker-graph --version
```

#### whisker-repl (Interactive Playground)

```bash
luarocks install whisker-repl
whisker-repl --version
```

#### whisker-lint (Static Analyzer)

```bash
luarocks install whisker-lint
whisker-lint --version
```

#### whisker-fmt (Code Formatter)

```bash
luarocks install whisker-fmt
whisker-fmt --version
```

## Installing VSCode Extension

### From Marketplace (Recommended)

1. Open VSCode
2. Open Extensions panel: `Ctrl+Shift+X` (Windows/Linux) or `Cmd+Shift+X` (macOS)
3. Search for "Whisker Interactive Fiction"
4. Click **Install**

### From VSIX File

If you have a `.vsix` package:

```bash
code --install-extension whisker-0.1.0.vsix
```

### Building from Source

```bash
cd tools/vscode-whisker
npm install
npm run compile
npm run package
code --install-extension whisker-0.1.0.vsix
```

## Verifying Installation

Run this script to verify all tools are installed:

```bash
#!/bin/bash
echo "Checking Whisker Developer Tools..."

check_tool() {
  if command -v $1 &> /dev/null; then
    echo "✓ $1: $($1 --version 2>&1 | head -1)"
  else
    echo "✗ $1: not found"
  fi
}

check_tool whisker-lsp
check_tool whisker-debug
check_tool whisker-graph
check_tool whisker-repl
check_tool whisker-lint
check_tool whisker-fmt
```

## Post-Installation Configuration

### VSCode Extension Settings

After installing the extension, configure settings in `.vscode/settings.json`:

```json
{
  "whisker.lsp.serverPath": "whisker-lsp",
  "whisker.lsp.logLevel": "info",
  "whisker.debug.adapterPath": "whisker-debug",
  "whisker.preview.theme": "auto"
}
```

### Neovim LSP Configuration

Add to your Neovim configuration:

```lua
require('lspconfig').whisker.setup{
  cmd = { "whisker-lsp", "--stdio" },
  filetypes = { "ink", "wscript", "twee" }
}
```

### Emacs LSP Configuration

Add to your Emacs configuration:

```elisp
(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("whisker-lsp" "--stdio"))
  :activation-fn (lsp-activate-on "ink" "wscript" "twee")
  :server-id 'whisker-lsp))
```

## Updating Tools

Update all tools to the latest version:

```bash
luarocks install --force whisker-lsp
luarocks install --force whisker-debug
luarocks install --force whisker-graph
luarocks install --force whisker-repl
luarocks install --force whisker-lint
luarocks install --force whisker-fmt
```

## Uninstalling

Remove all Whisker tools:

```bash
luarocks remove whisker-lsp
luarocks remove whisker-debug
luarocks remove whisker-graph
luarocks remove whisker-repl
luarocks remove whisker-lint
luarocks remove whisker-fmt
```

For VSCode extension:

1. Open Extensions panel
2. Find "Whisker Interactive Fiction"
3. Click **Uninstall**

## Next Steps

- [VSCode Extension Guide](vscode-extension/getting-started.md)
- [Editor Integration](lsp-server/editor-integration.md)
- [Debugging Workflow](debugger/debugging-workflow.md)
