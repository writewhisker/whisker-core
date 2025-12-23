# Whisker Interactive Fiction Extension

Language support for whisker-core interactive fiction framework.

## Features

- **Syntax Highlighting**: Full syntax highlighting for .ink, .wscript, and .twee files
- **Auto-Completion**: Intelligent completion for passages, variables, and macros
- **Error Checking**: Real-time diagnostics for syntax and semantic errors
- **Hover Documentation**: View passage descriptions and variable types on hover
- **Go to Definition**: Navigate from passage references to definitions
- **Symbol Outline**: View passage hierarchy in outline view

## Requirements

- `whisker-lsp` must be installed and available in PATH
- Install via: `luarocks install whisker-lsp`

## Extension Settings

- `whisker.lsp.serverPath`: Path to whisker-lsp executable
- `whisker.lsp.logLevel`: Log level (error, warn, info, debug)
- `whisker.lsp.trace`: Trace LSP communication (off, messages, verbose)

## Usage

1. Open a .ink, .wscript, or .twee file
2. Extension activates automatically
3. Language features work out of the box

## Commands

- `Whisker: Restart Language Server`: Restart the language server

## Known Issues

- Multi-file analysis not yet supported
- Cross-file navigation requires workspace indexing (planned)

## Release Notes

### 0.1.0

Initial release with syntax highlighting and basic LSP features.
