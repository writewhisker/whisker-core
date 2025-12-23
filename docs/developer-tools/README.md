# Whisker Developer Tools

This documentation covers the developer experience tools for the whisker-core interactive fiction framework.

## Overview

Whisker provides a comprehensive tooling ecosystem for story development:

- **whisker-lsp**: Language Server Protocol implementation for IDE integration
- **VSCode Extension**: Full-featured extension with syntax highlighting, preview, and debugging
- **whisker-debug**: Debug Adapter Protocol implementation for stepping through stories
- **whisker-graph**: Visualize story passage flow as graphs
- **whisker-repl**: Interactive playground for testing stories
- **whisker-lint**: Static analysis for detecting errors and style issues
- **whisker-fmt**: Code formatter for consistent style

## Quick Start

### Install CLI Tools

```bash
# Install all tools via LuaRocks
luarocks install whisker-lsp
luarocks install whisker-debug
luarocks install whisker-graph
luarocks install whisker-repl
luarocks install whisker-lint
luarocks install whisker-fmt
```

### Install VSCode Extension

1. Open VSCode
2. Go to Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Search for "Whisker"
4. Click Install

Or install from VSIX:

```bash
code --install-extension whisker-0.1.0.vsix
```

## Documentation

- [Installation Guide](installation.md) - Detailed setup instructions
- [VSCode Extension](vscode-extension/getting-started.md) - IDE setup and features
- [LSP Server](lsp-server/editor-integration.md) - Using whisker-lsp with other editors
- [Debugger](debugger/debugging-workflow.md) - Debugging your stories
- [CLI Tools](cli-tools/whisker-lint.md) - Command-line tools reference
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Supported Formats

All tools support these interactive fiction formats:

| Format | Extension | Description |
|--------|-----------|-------------|
| Ink | `.ink` | Inkle's narrative scripting language |
| Twee | `.twee`, `.tw` | Twine's plain-text format |
| WhiskerScript | `.wscript` | Native whisker-core format |

## Feature Matrix

| Feature | VSCode | Neovim | Emacs | CLI |
|---------|--------|--------|-------|-----|
| Syntax Highlighting | ✓ | ✓ | ✓ | - |
| Auto-completion | ✓ | ✓ | ✓ | - |
| Error Diagnostics | ✓ | ✓ | ✓ | whisker-lint |
| Hover Documentation | ✓ | ✓ | ✓ | - |
| Go to Definition | ✓ | ✓ | ✓ | - |
| Story Preview | ✓ | - | - | whisker-repl |
| Graph Visualization | ✓ | - | - | whisker-graph |
| Debugging | ✓ | ✓ | ✓ | - |
| Formatting | ✓ | ✓ | ✓ | whisker-fmt |

## System Requirements

- **Lua**: 5.1, 5.2, 5.3, 5.4, or LuaJIT
- **LuaRocks**: For package installation
- **VSCode**: 1.75+ (for extension)
- **Node.js**: 18+ (for building extension)

## Getting Help

- **GitHub Issues**: [whisker-core issues](https://github.com/writewhisker/whisker-core/issues)
- **Documentation**: This documentation
- **Examples**: See `examples/` in the repository
