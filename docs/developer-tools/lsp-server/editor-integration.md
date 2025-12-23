# LSP Editor Integration

whisker-lsp implements the Language Server Protocol for integration with any LSP-compatible editor.

## Server Capabilities

whisker-lsp supports these LSP features:

| Capability | Description |
|------------|-------------|
| `textDocumentSync` | Incremental document sync |
| `completionProvider` | Auto-completion |
| `hoverProvider` | Hover information |
| `definitionProvider` | Go to definition |
| `referencesProvider` | Find all references |
| `documentSymbolProvider` | Document outline |
| `workspaceSymbolProvider` | Workspace search |
| `diagnosticProvider` | Error checking |
| `documentFormattingProvider` | Code formatting |

## Starting the Server

```bash
# Standard mode (stdio)
whisker-lsp --stdio

# TCP mode (for network connections)
whisker-lsp --tcp --port 7777

# With logging
whisker-lsp --stdio --log-level debug --log-file /tmp/whisker-lsp.log
```

## VSCode Configuration

The Whisker VSCode extension handles this automatically. For manual configuration:

```json
{
  "whisker.lsp.serverPath": "/path/to/whisker-lsp",
  "whisker.lsp.logLevel": "info"
}
```

## Neovim Configuration

### Using nvim-lspconfig

```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

-- Define the whisker server
if not configs.whisker then
  configs.whisker = {
    default_config = {
      cmd = { 'whisker-lsp', '--stdio' },
      filetypes = { 'ink', 'wscript', 'twee' },
      root_dir = lspconfig.util.root_pattern('.git', '.whisker'),
      settings = {}
    }
  }
end

-- Setup the server
lspconfig.whisker.setup{
  on_attach = function(client, bufnr)
    -- Your on_attach configuration
  end,
  capabilities = require('cmp_nvim_lsp').default_capabilities()
}
```

### File Type Detection

Add to your Neovim config:

```lua
vim.filetype.add({
  extension = {
    ink = 'ink',
    wscript = 'wscript',
    twee = 'twee',
    tw = 'twee'
  }
})
```

### Syntax Highlighting

Create `after/syntax/ink.vim`:

```vim
" Ink syntax highlighting
syn match inkPassageHeader /^===.*===$/
syn match inkDivert /->.*$/
syn match inkChoice /^\s*[\*+]\s*\[.*\]/
syn match inkVariable /{[^}]*}/
syn match inkComment /\/\/.*/

hi link inkPassageHeader Title
hi link inkDivert Keyword
hi link inkChoice String
hi link inkVariable Identifier
hi link inkComment Comment
```

## Emacs Configuration

### Using lsp-mode

```elisp
(require 'lsp-mode)

;; Register whisker-lsp
(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("whisker-lsp" "--stdio"))
  :activation-fn (lsp-activate-on "ink" "wscript" "twee")
  :server-id 'whisker-lsp
  :priority -1))

;; Define major modes for story formats
(define-derived-mode ink-mode text-mode "Ink"
  "Major mode for editing Ink files.")

(define-derived-mode wscript-mode text-mode "WScript"
  "Major mode for editing WhiskerScript files.")

(define-derived-mode twee-mode text-mode "Twee"
  "Major mode for editing Twee files.")

;; File associations
(add-to-list 'auto-mode-alist '("\\.ink\\'" . ink-mode))
(add-to-list 'auto-mode-alist '("\\.wscript\\'" . wscript-mode))
(add-to-list 'auto-mode-alist '("\\.twee\\'" . twee-mode))
(add-to-list 'auto-mode-alist '("\\.tw\\'" . twee-mode))

;; Enable LSP for these modes
(add-hook 'ink-mode-hook #'lsp)
(add-hook 'wscript-mode-hook #'lsp)
(add-hook 'twee-mode-hook #'lsp)
```

### Using eglot (Emacs 29+)

```elisp
(require 'eglot)

(add-to-list 'eglot-server-programs
             '((ink-mode wscript-mode twee-mode) . ("whisker-lsp" "--stdio")))

(add-hook 'ink-mode-hook 'eglot-ensure)
(add-hook 'wscript-mode-hook 'eglot-ensure)
(add-hook 'twee-mode-hook 'eglot-ensure)
```

## Sublime Text Configuration

### LSP Package

Install "LSP" package, then create `Packages/User/LSP-whisker.sublime-settings`:

```json
{
  "clients": {
    "whisker": {
      "enabled": true,
      "command": ["whisker-lsp", "--stdio"],
      "selector": "source.ink | source.wscript | source.twee"
    }
  }
}
```

### Syntax Definition

Create `Packages/User/Ink.sublime-syntax`:

```yaml
%YAML 1.2
---
name: Ink
file_extensions: [ink]
scope: source.ink

contexts:
  main:
    - match: '^===.*===$'
      scope: entity.name.section.ink
    - match: '->.*$'
      scope: keyword.control.ink
    - match: '^\s*[\*\+]\s*\[.*\]'
      scope: string.quoted.ink
    - match: '\{[^\}]*\}'
      scope: variable.other.ink
    - match: '//.*$'
      scope: comment.line.ink
```

## Helix Configuration

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "ink"
scope = "source.ink"
injection-regex = "ink"
file-types = ["ink"]
roots = []
language-server = { command = "whisker-lsp", args = ["--stdio"] }

[[language]]
name = "wscript"
scope = "source.wscript"
injection-regex = "wscript"
file-types = ["wscript"]
roots = []
language-server = { command = "whisker-lsp", args = ["--stdio"] }

[[language]]
name = "twee"
scope = "source.twee"
injection-regex = "twee"
file-types = ["twee", "tw"]
roots = []
language-server = { command = "whisker-lsp", args = ["--stdio"] }
```

## Zed Configuration

Add to Zed settings:

```json
{
  "lsp": {
    "whisker": {
      "binary": {
        "path": "whisker-lsp",
        "arguments": ["--stdio"]
      }
    }
  },
  "languages": {
    "Ink": {
      "language_servers": ["whisker"]
    }
  }
}
```

## Server Configuration

whisker-lsp accepts configuration via the `initialize` request:

```json
{
  "settings": {
    "whisker": {
      "diagnostics": {
        "enable": true,
        "delay": 500
      },
      "completion": {
        "snippets": true,
        "autoImport": false
      },
      "format": {
        "enable": true,
        "indentSize": 2,
        "indentStyle": "space"
      }
    }
  }
}
```

## Troubleshooting

### Server Not Starting

1. Check whisker-lsp is in PATH:
   ```bash
   which whisker-lsp
   ```

2. Verify it runs:
   ```bash
   whisker-lsp --version
   ```

3. Test stdio mode:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | whisker-lsp --stdio
   ```

### No Completions

1. Check server is connected (look for LSP indicator in editor)
2. Verify file type is recognized
3. Check server logs for errors

### Performance Issues

1. Enable incremental sync in your editor
2. Reduce diagnostic delay for smoother experience
3. Consider disabling live diagnostics for very large files

See [Troubleshooting Guide](../troubleshooting.md) for more solutions.
