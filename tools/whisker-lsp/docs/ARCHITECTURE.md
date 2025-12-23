# whisker-lsp Architecture

## Overview

whisker-lsp is a Language Server Protocol (LSP) implementation for the whisker-core interactive fiction framework. It provides IDE features for `.ink`, `.wscript`, and `.twee` files including auto-completion, diagnostics, hover documentation, and go-to-definition.

## Architectural Decisions

### Decision 1: Standalone Server Process

**Choice**: Implement as standalone Lua executable communicating via stdin/stdout.

**Rationale**:
- Editor-agnostic: Works with VSCode, Neovim, Emacs, Sublime
- Testable: Mock stdin/stdout for unit tests
- Fault isolation: Server crash doesn't crash editor
- Consistent with whisker-core's Lua-first approach

**Alternative Rejected**: Node.js wrapper calling Lua. Rejected due to added complexity and dependency.

### Decision 2: Incremental Document Sync

**Choice**: Use `textDocumentSync: Incremental` for document synchronization.

**Rationale**:
- Lower bandwidth: Only changed regions transmitted
- Better performance: Reduced parsing overhead
- Standard LSP practice for production servers

**Trade-off**: More complex change tracking, but worth it for large files.

### Decision 3: Parse-on-Type with Debouncing

**Choice**: Re-parse on every keystroke with 300ms debounce.

**Rationale**:
- Immediate feedback for syntax errors
- Debouncing prevents excessive CPU usage
- Matches user expectations from modern IDEs

### Decision 4: AST Caching with Invalidation

**Choice**: Cache parsed AST per document, invalidate on change.

**Rationale**:
- Completion/hover need quick AST access
- Reparsing on every request too slow
- Change events trigger cache invalidation

### Decision 5: Modular Provider Architecture

**Choice**: Separate provider modules for each LSP capability.

**Rationale**:
- Single responsibility: Each provider handles one feature
- Testable: Unit test providers in isolation
- Extensible: Add new providers without modifying core

## Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     whisker-lsp                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐     ┌──────────────────────────┐     │
│  │ LSP Transport    │────▶│ Message Dispatcher       │     │
│  │ (stdin/stdout)   │     │ (route to handlers)      │     │
│  └──────────────────┘     └───────────┬──────────────┘     │
│                                       │                     │
│                    ┌──────────────────┼──────────────────┐  │
│                    │                  │                  │  │
│                    ▼                  ▼                  ▼  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────┐  │
│  │ Document Manager │  │ Capability       │  │ Settings │  │
│  │ (text, versions) │  │ Registrar        │  │ Manager  │  │
│  └────────┬─────────┘  └──────────────────┘  └──────────┘  │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 Parser Integration                    │  │
│  │         (whisker.parser, whisker.lexer)              │  │
│  └────────────────────────┬─────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────┼────────────────────────────┐   │
│  │                        ▼                            │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────┐ │   │
│  │  │Completion│  │Diagnostic│  │  Hover   │  │Def  │ │   │
│  │  │ Provider │  │ Provider │  │ Provider │  │Find │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────┘ │   │
│  │                   Providers                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Initialization Sequence

```
Client                          Server
  │                               │
  │─── initialize ───────────────▶│
  │                               │ Register capabilities
  │                               │ Set up document manager
  │◀── InitializeResult ─────────│
  │                               │
  │─── initialized ──────────────▶│
  │                               │ Ready to process
```

### Document Open/Change

```
Client                          Server
  │                               │
  │─── textDocument/didOpen ────▶│
  │                               │ Store document text
  │                               │ Parse document
  │                               │ Cache AST
  │◀── textDocument/publishDiagnostics ─│
  │                               │
  │─── textDocument/didChange ──▶│
  │                               │ Apply incremental changes
  │                               │ Invalidate AST cache
  │                               │ Re-parse (debounced)
  │◀── textDocument/publishDiagnostics ─│
```

### Completion Request

```
Client                          Server
  │                               │
  │─── textDocument/completion ─▶│
  │                               │ Get cached AST
  │                               │ Find node at position
  │                               │ Determine context:
  │                               │   - After "->" → passage names
  │                               │   - In "{}" → variable names
  │                               │   - In "<<" → macro names
  │                               │ Build completion list
  │◀── CompletionList ──────────│
```

## Module Responsibilities

### lsp_server.lua

Main entry point and message loop.

- Initialize JSON-RPC transport
- Dispatch messages to handlers
- Manage server lifecycle

### document_manager.lua

Track open documents and their state.

- Store document text content
- Apply incremental changes
- Track document versions
- Trigger re-parse on change

### parser_integration.lua

Bridge to whisker-core parsers.

- Parse document content
- Cache AST per document
- Invalidate cache on change
- Provide AST queries

### providers/completion.lua

Auto-completion suggestions.

- Passage name completion after "->"
- Variable completion in "{}"
- Macro completion in "<<>>"
- Snippet expansion

### providers/diagnostics.lua

Error and warning reporting.

- Syntax error detection
- Undefined passage references
- Undefined variable warnings
- Unreachable passage detection

### providers/hover.lua

Hover documentation.

- Passage descriptions
- Variable type/value info
- Macro documentation

### providers/definition.lua

Go-to-definition support.

- Jump to passage header
- Jump to variable assignment

### providers/symbols.lua

Document symbols for outline view.

- List all passages
- Hierarchical structure

## File Format Support

| Format | Extension | Parser |
|--------|-----------|--------|
| Ink | .ink | whisker.format.parsers.ink |
| WhiskerScript | .wscript | whisker.language.parser |
| Twee | .twee | whisker.format.parsers.twee |

## Performance Considerations

### Debouncing

All document changes are debounced (300ms default) before triggering:
- AST re-parse
- Diagnostic publish
- Symbol update

### Caching Strategy

```
Document Changed
       │
       ▼
┌─────────────────┐
│ Invalidate AST  │
└────────┬────────┘
         │ (debounced)
         ▼
┌─────────────────┐
│ Parse Document  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Cache AST       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Publish Diags   │
└─────────────────┘
```

### Large File Handling

For files > 100KB:
- Increase debounce to 500ms
- Disable some features (full validation)
- Show warning to user

## Testing Strategy

### Unit Tests

- Parser integration tests
- Each provider tested in isolation
- Mock document manager

### Integration Tests

- Full LSP message round-trip
- Multiple document scenarios
- Error recovery

### Performance Tests

- Parse time benchmarks
- Memory usage monitoring
- Response latency measurement

## Configuration

Settings via `whisker.lsp.*` namespace:

| Setting | Default | Description |
|---------|---------|-------------|
| logLevel | "info" | Log verbosity |
| debounceMs | 300 | Change debounce |
| maxFileSize | 1048576 | Max file size (bytes) |
| enableCompletion | true | Enable completion |
| enableDiagnostics | true | Enable diagnostics |

## Error Handling

### Parser Errors

- Catch all parser exceptions
- Convert to LSP Diagnostic format
- Include line/column information
- Provide recovery suggestions

### Server Errors

- Log all exceptions
- Return LSP error response
- Avoid crashing server process

## Future Extensions

- Semantic tokens for advanced highlighting
- Code actions (quick fixes)
- Rename refactoring
- Find all references
- Workspace symbol search
- Call hierarchy
