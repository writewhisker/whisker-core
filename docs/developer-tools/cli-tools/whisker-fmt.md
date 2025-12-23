# whisker-fmt: Code Formatter

whisker-fmt formats story files for consistent style and readability.

## Installation

```bash
luarocks install whisker-fmt
```

Verify installation:

```bash
whisker-fmt --version
# whisker-fmt 0.1.0
```

## Basic Usage

### Format a Single File

```bash
whisker-fmt story.ink
# Formatted: story.ink
```

### Format Multiple Files

```bash
whisker-fmt story.ink chapter1.ink chapter2.ink
```

### Format a Directory

```bash
whisker-fmt src/
```

Recursively formats all `.ink`, `.twee`, `.tw`, and `.wscript` files.

## Command-Line Options

```
whisker-fmt [options] <file|directory>...

Options:
  -h, --help           Show help message
  -v, --version        Show version
  -c, --config FILE    Use custom config file
  --check              Check formatting without modifying
  --diff               Show diff of changes (implies --check)
  --stdin              Read from stdin, write to stdout
  --write              Write formatted output back to files (default)
```

## Check Mode

Verify files are formatted without modifying them:

```bash
whisker-fmt --check src/
```

Exit codes:
- `0`: All files formatted correctly
- `1`: Some files would be modified

Useful for CI pipelines.

## Diff Mode

See what would change:

```bash
whisker-fmt --diff story.ink
```

Output shows files that would be modified.

## Stdin/Stdout Mode

Format from stdin:

```bash
cat story.ink | whisker-fmt --stdin > formatted.ink
```

Specify format explicitly:

```bash
cat story.twee | whisker-fmt --stdin --stdin-format twee
```

## Configuration

### Config File Location

whisker-fmt looks for `.whisker-fmt.json` in the current directory.

Specify a custom path:
```bash
whisker-fmt -c custom-fmt.json story.ink
```

### Config File Format

```json
{
  "indent_style": "space",
  "indent_size": 2,
  "max_line_length": 100,
  "normalize_whitespace": true,
  "blank_lines_between": 1,
  "align_choices": true,
  "sort_passages": false
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `indent_style` | `"space"` or `"tab"` | `"space"` | Indentation character |
| `indent_size` | number | 2 | Spaces per indent level |
| `max_line_length` | number | 100 | Soft line length limit |
| `normalize_whitespace` | boolean | true | Trim trailing whitespace |
| `blank_lines_between` | number | 1 | Blank lines between passages |
| `align_choices` | boolean | true | Align choice markers |
| `sort_passages` | boolean | false | Sort passages alphabetically |

## Formatting Rules

### Ink Formatting

#### Passage Headers

Before:
```ink
===  Start   ===
```

After:
```ink
=== Start ===
```

#### Choices

Before:
```ink
*   [Go left]   ->  Left
```

After:
```ink
* [Go left] -> Left
```

#### Diverts

Before:
```ink
->   Chapter1
```

After:
```ink
-> Chapter1
```

#### Variables

Before:
```ink
~  health   =   100
```

After:
```ink
~ health = 100
```

#### Comments

Before:
```ink
//    This is a comment
```

After:
```ink
// This is a comment
```

### Twee Formatting

#### Passage Headers

Before:
```twee
::   Start   [tags]
```

After:
```twee
:: Start [tags]
```

#### Links

Before:
```twee
[[  Go to chapter  |  Chapter1  ]]
```

After:
```twee
[[Go to chapter|Chapter1]]
```

### WhiskerScript Formatting

#### Passage Declarations

Before:
```wscript
passage   "Start"   {
text "Hello"
}
```

After:
```wscript
passage "Start" {
  text "Hello"
}
```

## Idempotent Formatting

whisker-fmt is idempotent: formatting twice produces the same result.

```bash
whisker-fmt story.ink
whisker-fmt story.ink  # No changes
```

## IDE Integration

### VSCode

The Whisker extension uses whisker-fmt for formatting.

Enable format on save:
```json
{
  "editor.formatOnSave": true,
  "[ink]": {
    "editor.defaultFormatter": "whisker.whisker"
  }
}
```

### Neovim

Using null-ls:

```lua
local null_ls = require('null-ls')

null_ls.setup({
  sources = {
    null_ls.builtins.formatting.whisker_fmt.with({
      filetypes = { "ink", "wscript", "twee" }
    })
  }
})
```

Or with conform.nvim:

```lua
require('conform').setup({
  formatters_by_ft = {
    ink = { "whisker_fmt" },
    wscript = { "whisker_fmt" },
    twee = { "whisker_fmt" }
  }
})
```

### Emacs

Using format-all:

```elisp
(use-package format-all
  :commands format-all-mode
  :hook (ink-mode . format-all-mode)
  :config
  (define-format-all-formatter whisker-fmt
    (:executable "whisker-fmt")
    (:install "luarocks install whisker-fmt")
    (:modes ink-mode wscript-mode twee-mode)
    (:format (format-all--buffer-easy executable "--stdin"))))
```

## CI Integration

### GitHub Actions

```yaml
name: Format Check

on: [push, pull_request]

jobs:
  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Lua
        uses: leafo/gh-actions-lua@v10

      - name: Install LuaRocks
        uses: leafo/gh-actions-luarocks@v4

      - name: Install whisker-fmt
        run: luarocks install whisker-fmt

      - name: Check formatting
        run: whisker-fmt --check src/
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Get staged story files
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ink|twee|tw|wscript)$')

if [ -n "$staged" ]; then
  whisker-fmt --check $staged
  if [ $? -ne 0 ]; then
    echo "Run 'whisker-fmt' to fix formatting."
    exit 1
  fi
fi
```

## Examples

### Format All Story Files

```bash
whisker-fmt src/stories/
```

### Check CI Formatting

```bash
whisker-fmt --check src/ || exit 1
```

### Custom Indentation

```bash
cat > .whisker-fmt.json << EOF
{
  "indent_style": "tab",
  "indent_size": 1
}
EOF
whisker-fmt story.ink
```

### Pipeline Processing

```bash
cat story.ink | whisker-fmt --stdin | tee formatted.ink
```

## Troubleshooting

### "Cannot open file"

Check file exists and has write permissions:
```bash
ls -la story.ink
```

### "Unsupported format"

Ensure file has a supported extension: `.ink`, `.twee`, `.tw`, `.wscript`

Or specify format for stdin:
```bash
whisker-fmt --stdin --stdin-format ink
```

### "Config file not parsed"

Validate JSON syntax:
```bash
cat .whisker-fmt.json | python -m json.tool
```
