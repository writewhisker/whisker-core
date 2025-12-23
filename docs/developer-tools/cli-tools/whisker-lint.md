# whisker-lint: Static Analysis

whisker-lint performs static analysis on story files to detect errors, warnings, and style issues.

## Installation

```bash
luarocks install whisker-lint
```

Verify installation:

```bash
whisker-lint --version
# whisker-lint 0.1.0
```

## Basic Usage

### Lint a Single File

```bash
whisker-lint story.ink
```

Output:
```
story.ink:15:0 - warning - Passage 'Orphan' is unreachable (unreachable-passage)
story.ink:42:0 - error - Undefined passage 'Typo' (undefined-reference)
```

### Lint a Directory

```bash
whisker-lint src/
```

Recursively lints all `.ink`, `.twee`, `.tw`, and `.wscript` files.

### JSON Output

```bash
whisker-lint --format json story.ink
```

Output:
```json
[
  {
    "file": "story.ink",
    "line": 15,
    "column": 0,
    "severity": "warn",
    "message": "Passage 'Orphan' is unreachable",
    "rule": "unreachable-passage"
  }
]
```

## Command-Line Options

```
whisker-lint [options] <file|directory>...

Options:
  -h, --help           Show help message
  -v, --version        Show version
  -c, --config FILE    Use custom config file
  -f, --format FORMAT  Output format: text, json
  --fix                Auto-fix fixable issues
  --quiet              Only show errors, not warnings
  --max-warnings N     Exit with error if warnings exceed N
```

## Configuration

### Config File Location

whisker-lint looks for `.whisker-lint.json` in the current directory.

Specify a custom path:
```bash
whisker-lint -c custom-lint.json story.ink
```

### Config File Format

```json
{
  "rules": {
    "unreachable-passage": "warn",
    "undefined-reference": "error",
    "unused-variable": "warn",
    "missing-start": "error",
    "empty-passage": "warn",
    "circular-only": "warn"
  },
  "exclude": [
    "test/**/*.ink",
    "examples/**/*.ink"
  ]
}
```

### Rule Severities

| Severity | Exit Code | Description |
|----------|-----------|-------------|
| `"error"` | 2 | Fails CI builds |
| `"warn"` | 1 | Warning only |
| `"off"` | 0 | Rule disabled |

## Available Rules

### Core Rules

#### `missing-start`

Detects when no Start passage is defined.

```ink
// Error: No 'Start' passage defined
=== Chapter1 ===
...
```

Fix: Add a `Start`, `START`, or `start` passage.

#### `unreachable-passage`

Detects passages that can never be visited.

```ink
=== Start ===
Welcome!
-> Chapter1

=== Chapter1 ===
The end.

=== Orphan ===     // Warning: unreachable
This is never visited.
```

Fix: Add a path to the passage or remove it.

#### `undefined-reference`

Detects references to non-existent passages.

```ink
=== Start ===
-> NonExistent     // Error: undefined passage

=== Chapter1 ===
...
```

Fix: Create the passage or fix the typo.

#### `unused-variable`

Detects variables that are set but never read.

```ink
=== Start ===
~ unused_var = 100    // Warning: never read
Hello world!
```

Fix: Use the variable or remove the assignment.

#### `empty-passage`

Detects passages with no content or choices.

```ink
=== Empty ===
                      // Warning: no content
```

Fix: Add content or remove the passage.

#### `circular-only`

Detects passages only reachable through self-reference.

```ink
=== Loop ===
You are stuck.
-> Loop              // Warning: circular only
```

Fix: Add an entry point from another passage.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No issues found |
| 1 | Warnings found (errors suppressed with --quiet) |
| 2 | Errors found |

## CI Integration

### GitHub Actions

```yaml
name: Lint Stories

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Lua
        uses: leafo/gh-actions-lua@v10

      - name: Install LuaRocks
        uses: leafo/gh-actions-luarocks@v4

      - name: Install whisker-lint
        run: luarocks install whisker-lint

      - name: Run linter
        run: whisker-lint src/
```

### GitLab CI

```yaml
lint:
  image: nickblah/lua:5.4-luarocks
  script:
    - luarocks install whisker-lint
    - whisker-lint src/
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
whisker-lint src/
if [ $? -ne 0 ]; then
  echo "Lint errors found. Commit aborted."
  exit 1
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

## IDE Integration

### VSCode

The Whisker extension automatically runs whisker-lint and shows issues as diagnostics.

### Vim/Neovim (ALE)

```vim
let g:ale_linters = {
\   'ink': ['whisker-lint'],
\}
```

### Emacs (Flycheck)

```elisp
(flycheck-define-checker whisker-lint
  "A linter for Whisker story files."
  :command ("whisker-lint" "--format" "json" source)
  :error-parser flycheck-parse-json
  :modes (ink-mode wscript-mode twee-mode))

(add-to-list 'flycheck-checkers 'whisker-lint)
```

## Examples

### Lint with Error Threshold

Fail if more than 5 warnings:

```bash
whisker-lint --max-warnings 5 src/
```

### Lint Only Errors

```bash
whisker-lint --quiet src/
```

### Custom Config

```bash
whisker-lint -c strict-config.json src/
```

### JSON for Processing

```bash
whisker-lint --format json src/ | jq '.[] | select(.severity == "error")'
```

## Troubleshooting

### "Cannot open file"

Check file exists and has read permissions:
```bash
ls -la story.ink
```

### "Unknown file format"

Ensure file has a supported extension: `.ink`, `.twee`, `.tw`, `.wscript`

### "Config file not parsed"

Validate JSON syntax:
```bash
cat .whisker-lint.json | python -m json.tool
```
