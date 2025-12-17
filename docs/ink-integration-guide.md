# Ink Integration Guide

This guide covers the integration of Ink narrative format with whisker-core, enabling import, export, and runtime execution of Ink stories.

## Overview

Whisker-core provides comprehensive Ink support through:

- **Converter**: Transform Ink JSON to whisker-core format
- **Exporter**: Transform whisker-core stories to Ink JSON
- **Transformers**: Modular conversion pipeline components
- **Generators**: Modular export pipeline components
- **Validator**: Story structure validation
- **Compare**: Round-trip verification utilities

## Quick Start

### Loading an Ink Story

```lua
local Converter = require("whisker.formats.ink.converter")

-- Create converter
local converter = Converter.new()

-- Convert Ink JSON to whisker format
local ink_data = { inkVersion = 20, root = { ... } }
local story = converter:convert(ink_data)

-- Access passages
for id, passage in pairs(story.passages) do
  print(id, passage.content)
end
```

### Exporting to Ink JSON

```lua
local Exporter = require("whisker.formats.ink.exporter")

-- Create exporter
local exporter = Exporter.new()

-- Define whisker story
local story = {
  start = "intro",
  passages = {
    intro = { id = "intro", content = "Hello, World!" }
  },
  variables = {}
}

-- Export to Ink JSON
local ink_json = exporter:export(story)
print(ink_json.inkVersion) -- 20
```

### Validating Stories

```lua
local Validator = require("whisker.formats.ink.validator")

local validator = Validator.new()
local result = validator:validate(story)

if result.success then
  print("Story is valid!")
else
  for _, err in ipairs(result.errors) do
    print("Error:", err.message)
  end
end
```

## Story Structure

### Passages

Passages map to Ink knots and stitches:

```lua
local passages = {
  -- Knot (top-level)
  chapter1 = {
    id = "chapter1",
    content = "Chapter content",
    tags = { "chapter" }
  },

  -- Stitch (nested under knot)
  ["chapter1.scene1"] = {
    id = "chapter1.scene1",
    content = "Scene content"
  }
}
```

### Choices

Choices support all Ink choice types:

```lua
local passage = {
  id = "crossroads",
  content = "Which way?",
  choices = {
    -- Once-only choice (default)
    { text = "Go north", target = "north" },

    -- Sticky choice (repeatable)
    { text = "Wait here", target = "crossroads", sticky = true },

    -- Conditional choice
    { text = "Use key", target = "door", condition = "has_key" },

    -- Fallback choice
    { text = "Give up", target = "end", fallback = true }
  }
}
```

### Variables

Variables preserve type information:

```lua
local variables = {
  health = { name = "health", type = "integer", default = 100 },
  name = { name = "name", type = "string", default = "Hero" },
  has_key = { name = "has_key", type = "boolean", default = false },
  inventory = { name = "inventory", type = "list", items = { "sword", "shield" } }
}
```

## Conversion Pipeline

### Transformers

The conversion pipeline uses modular transformers:

```lua
local transformers = require("whisker.formats.ink.transformers")

-- Available transformers
local list = transformers.list()
-- { "knot", "stitch", "gather", "choice", "variable", "logic", "tunnel", "thread" }

-- Create specific transformer
local knot_transformer = transformers.create("knot")
local passage = knot_transformer:transform(ink_knot, options)
```

### Generators

The export pipeline uses modular generators:

```lua
local generators = require("whisker.formats.ink.generators")

-- Available generators
local list = generators.list()
-- { "passage", "choice", "divert", "variable", "logic" }

-- Create specific generator
local passage_gen = generators.create("passage")
local container = passage_gen:generate(whisker_passage, options)
```

## Validation

### Error Types

| Type | Description |
|------|-------------|
| `missing_passage` | Referenced passage doesn't exist |
| `content_mismatch` | Content differs unexpectedly |
| `missing_variable` | Referenced variable undefined |
| `variable_type_mismatch` | Variable type doesn't match |

### Validation Options

```lua
local result = validator:validate(story, {
  validate_conditions = true,  -- Check condition variable refs
})
```

### Accessing Statistics

```lua
local result = validator:validate(story)
print("Passages:", result.stats.passages)
print("Choices:", result.stats.choices)
print("Variables:", result.stats.variables)
print("Orphaned:", result.stats.orphaned)
```

## Round-Trip Verification

### Comparing Stories

```lua
local Compare = require("whisker.formats.ink.compare")

local cmp = Compare.new()
local match, differences = cmp:compare(original, converted)

if not match then
  print(cmp:generate_report())
end
```

### Difference Types

```lua
local missing = cmp:get_differences_by_type("missing_passage")
local content = cmp:get_differences_by_type("content_mismatch")
```

## Generating Reports

```lua
local Report = require("whisker.formats.ink.report")

local report = Report.from_conversion(
  { path = "story.json", ink_version = 20 },
  { passages = 10, choices = 25 },
  validation_result
)

-- Text output
print(report:to_text())

-- JSON-serializable output
local data = report:to_table()
```

## Best Practices

### For Import

1. Validate Ink JSON version (19+)
2. Check for unsupported features
3. Use the validation module
4. Preserve original data for debugging

### For Export

1. Define explicit start passage
2. Use dot-notation for stitches
3. Set variable types explicitly
4. Validate before export

### For Testing

1. Use round-trip tests for fidelity
2. Test with various story structures
3. Verify choice behavior
4. Check variable preservation

## API Reference

### Converter

- `new(options)` - Create converter
- `convert(ink_data)` - Convert Ink to whisker
- `get_transformers()` - Get transformer registry

### Exporter

- `new(options)` - Create exporter
- `export(story)` - Export to Ink JSON
- `validate(story)` - Pre-export validation
- `get_ink_version()` - Get target Ink version

### Validator

- `new()` - Create validator
- `validate(story, options)` - Validate story
- `get_result()` - Get validation result
- `is_valid()` - Check if valid

### Compare

- `new()` - Create comparator
- `compare(original, converted)` - Compare stories
- `generate_report()` - Get text report
- `get_differences_by_type(type)` - Filter differences

## Troubleshooting

### Common Issues

**"Passage not found"**
- Check passage ID spelling
- Verify dot-notation for stitches

**"Variable type mismatch"**
- Ensure consistent type declarations
- Check for implicit type conversion

**"Orphaned passage warning"**
- Verify all passages are reachable
- Check choice targets

### Debug Mode

```lua
local converter = Converter.new({ debug = true })
-- Logs conversion steps
```

## Version Compatibility

| Component | Supported Versions |
|-----------|-------------------|
| Ink JSON | 19+ (targets 20) |
| Lua | 5.1, 5.2, 5.3, 5.4, LuaJIT |
| whisker-core | 1.0+ |
