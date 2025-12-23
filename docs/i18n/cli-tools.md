# i18n CLI Tools

Command-line tools for the translation workflow.

## Overview

whisker-core provides three CLI tools for managing translations:

| Tool | Purpose |
|------|---------|
| `extract` | Extract translatable strings from source files |
| `validate` | Check translations for errors and completeness |
| `status` | Report translation coverage |

## Extract

Extract translatable strings from Whisker Script files.

### Usage

```bash
whisker-i18n extract <source> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<source>` | Source file or directory |

### Options

| Option | Description |
|--------|-------------|
| `-o, --output <file>` | Output file (default: stdout) |
| `-f, --format <fmt>` | Output format: yaml, json (default: yaml) |
| `--recursive` | Search directories recursively |
| `--pattern <glob>` | File pattern (default: *.whisker) |

### Examples

```bash
# Extract from single file
whisker-i18n extract story.whisker -o locales/template.yml

# Extract from directory
whisker-i18n extract src/ -o locales/template.yml --recursive

# Output as JSON
whisker-i18n extract src/ -f json -o locales/template.json

# Only .whisker files
whisker-i18n extract src/ --pattern "*.whisker" -o template.yml
```

### Output Format

The extract tool generates a template file:

```yaml
# Auto-generated translation template
# Generated from: src/

greeting: ""

dialogue:
  npc:
    intro: ""
    farewell: ""

items:
  count:
    one: ""
    other: ""
```

### Programmatic Usage

```lua
local Extract = require("whisker.i18n.tools.extract")

-- Extract from string content
local keys = Extract.fromString(content, "story.whisker")

-- Generate template
local yaml = Extract.toYAML(keys)
local json = Extract.toJSON(keys)

-- Get summary
local summary = Extract.getSummary(keys)
print("Found " .. summary.total .. " keys")
print("  Translate: " .. summary.translate)
print("  Plural: " .. summary.plural)
```

## Validate

Check translations for completeness and errors.

### Usage

```bash
whisker-i18n validate <base> <target> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<base>` | Base translation file (usually English) |
| `<target>` | Target translation file to validate |

### Options

| Option | Description |
|--------|-------------|
| `--strict` | Treat warnings as errors |
| `--format <fmt>` | Output format: text, json |
| `-q, --quiet` | Only show errors |

### Examples

```bash
# Validate Spanish translation
whisker-i18n validate locales/en.yml locales/es.yml

# Validate all translations
for f in locales/*.yml; do
  whisker-i18n validate locales/en.yml "$f"
done

# Strict mode (fail on warnings)
whisker-i18n validate locales/en.yml locales/de.yml --strict

# JSON output for CI
whisker-i18n validate locales/en.yml locales/fr.yml --format json
```

### Issue Types

| Type | Severity | Description |
|------|----------|-------------|
| `missing_key` | Error | Key in base not in target |
| `missing_section` | Error | Section in base not in target |
| `missing_variable` | Error | Variable in base not in target |
| `missing_plural` | Error | Required plural form missing |
| `unused_key` | Warning | Key in target not in base |
| `unused_section` | Warning | Section in target not in base |
| `extra_variable` | Warning | Variable in target not in base |

### Output Example

```
Translation Validation Report
=============================
Base: locales/en.yml
Target: locales/es.yml

Errors: 2
Warnings: 1

ERRORS:
  [missing_key] dialogue.farewell
    Missing translation for key

  [missing_variable] welcome
    Missing variable: {name}
    Base: "Hello, {name}!"
    Target: "¡Hola!"

WARNINGS:
  [unused_key] extra_key
    Key not in base translation
```

### Programmatic Usage

```lua
local Validate = require("whisker.i18n.tools.validate")

-- Compare translations
local issues = Validate.compare(baseData, targetData)

-- Count issues
local errors, warnings = Validate.countIssues(issues)

-- Generate report
local report = Validate.report(issues)
print(report)

-- Check specific aspects
local missing = {}
Validate.findMissing(baseData, targetData, "", missing)

local unused = {}
Validate.findUnused(baseData, targetData, "", unused)

local varIssues = {}
Validate.checkVariables(baseData, targetData, "", varIssues)
```

## Status

Report translation coverage across locales.

### Usage

```bash
whisker-i18n status <base-locale> <locales-dir> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<base-locale>` | Base locale code (e.g., "en") |
| `<locales-dir>` | Directory containing translation files |

### Options

| Option | Description |
|--------|-------------|
| `--format <fmt>` | Output format: text, json, csv |
| `--missing` | Show missing keys per locale |
| `--threshold <n>` | Warn if coverage below n% |

### Examples

```bash
# Basic status report
whisker-i18n status en locales/

# Show missing keys
whisker-i18n status en locales/ --missing

# JSON for CI
whisker-i18n status en locales/ --format json

# Fail if any locale below 80%
whisker-i18n status en locales/ --threshold 80
```

### Output Example

```
Translation Status Report
=========================
Base: en (150 keys)

Locale    Keys    Coverage  Status
------    ----    --------  ------
en        150/150   100%    complete
es        148/150    99%    good
fr        120/150    80%    good
de        100/150    67%    partial
ja         75/150    50%    partial
ar         30/150    20%    incomplete

Summary:
  Total locales: 6
  Complete: 1
  Good (80%+): 2
  Partial (50%+): 2
  Incomplete (<50%): 1
  Average coverage: 69%
```

### Programmatic Usage

```lua
local Status = require("whisker.i18n.tools.status")

-- Get status for single locale
local status = Status.getLocaleStatus(baseData, targetData, "es")
print(status.locale .. ": " .. status.coverage .. "%")

-- Get coverage status label
local label = Status.getCoverageStatus(75)  -- "partial"

-- Get missing keys
local missing = Status.getMissingKeys(baseData, targetData)
for _, key in ipairs(missing) do
  print("Missing: " .. key)
end

-- Generate full report
local report = Status.report("en", localesData)
print(report)

-- Get summary statistics
local summary = Status.getSummary("en", localesData)
print("Complete: " .. summary.completeCount)
print("Average: " .. summary.averageCoverage .. "%")
```

## Integration Examples

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Validate all translations before commit
for f in locales/*.yml; do
  if [ "$f" != "locales/en.yml" ]; then
    whisker-i18n validate locales/en.yml "$f" --strict || exit 1
  fi
done
```

### CI Pipeline

```yaml
# .github/workflows/i18n.yml
name: i18n Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Extract and check for new keys
        run: |
          whisker-i18n extract src/ -o /tmp/current.yml
          diff locales/template.yml /tmp/current.yml

      - name: Validate translations
        run: |
          for f in locales/*.yml; do
            [ "$f" != "locales/en.yml" ] && \
            whisker-i18n validate locales/en.yml "$f" --strict
          done

      - name: Check coverage
        run: whisker-i18n status en locales/ --threshold 80
```

### Build Script

```bash
#!/bin/bash
# scripts/build-i18n.sh

# Compile all translations to Lua
mkdir -p build/locales

for yml in locales/*.yml; do
  locale=$(basename "$yml" .yml)
  lua="build/locales/${locale}.lua"
  whisker-i18n compile "$yml" "$lua" --minify
  echo "Compiled: $yml -> $lua"
done

echo "Done. Compiled $(ls build/locales/*.lua | wc -l) locales."
```

### Translator Report

```bash
#!/bin/bash
# scripts/translator-report.sh

echo "Translation Status"
echo "=================="
whisker-i18n status en locales/

echo ""
echo "Missing Keys by Locale"
echo "======================"

for f in locales/*.yml; do
  locale=$(basename "$f" .yml)
  [ "$locale" = "en" ] && continue

  echo ""
  echo "=== $locale ==="
  whisker-i18n validate locales/en.yml "$f" 2>&1 | grep "missing_key"
done
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Validation errors found |
| 2 | File not found |
| 3 | Parse error |
| 4 | Coverage below threshold |
