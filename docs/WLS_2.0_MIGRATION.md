# WLS 2.0 Migration Guide

This guide helps you migrate stories from WLS 1.x to WLS 2.0.

## Overview

WLS 2.0 is a major version with new features and some breaking changes. Most WLS 1.x stories will work without modification, but some patterns require updates.

## Quick Start

### Automated Migration

Use the migration tool for automatic conversion:

```bash
# Single file
lua tools/migrate_1x_to_2x.lua mystory.ws -o mystory_2x.ws

# With report
lua tools/migrate_1x_to_2x.lua mystory.ws -o mystory_2x.ws --report

# Dry run (preview changes)
lua tools/migrate_1x_to_2x.lua mystory.ws --dry-run
```

### What the Tool Handles

| Change Type | Automatic | Manual |
|-------------|-----------|--------|
| Reserved word renaming | Yes | - |
| Header comment | Yes | - |
| Tunnel deprecation warnings | Yes (warns) | Review needed |
| Script block warnings | Yes (warns) | Rewrite needed |
| Legacy syntax warnings | Yes (warns) | Rewrite needed |

---

## Breaking Changes

### Reserved Words

WLS 2.0 reserves new keywords for thread and media features. If your story uses these as variable names, they must be renamed:

| Reserved Word | Use in 2.0 |
|---------------|------------|
| `thread` | Thread operations |
| `await` | Thread synchronization |
| `spawn` | Thread creation |
| `sync` | Synchronization point |
| `channel` | Audio channels |
| `timer` | Timed content |
| `effect` | Text effects |
| `audio` | Audio control |
| `external` | External functions |

**Before (1.x):**
```whisker
:: Start
@set $thread = "main"
@set $await = true
The $thread continues.
```

**After (2.0):**
```whisker
:: Start
@set $_thread = "main"
@set $_await = true
The $_thread continues.
```

The migration tool automatically renames variables by adding an underscore prefix.

### Why These Names?

These keywords are reserved because they're used by new WLS 2.0 features:

```whisker
:: Example
== BackgroundThread     // Thread definition
-> BackgroundThread     // Spawns thread
@await BackgroundThread // Waits for completion
@effect typewriter { }  // Text effect
@audio bgm = "music.mp3"// Audio declaration
```

---

## Deprecated Patterns

### Tunnels (`->->`)

Tunnels are deprecated in favor of parameterized passages. The migration tool adds warnings but doesn't automatically convert them.

**Before (1.x):**
```whisker
:: Start
You enter.
->-> Describe
You continue.

:: Describe
A dark room.
->->
```

**After (2.0 - Recommended):**
```whisker
:: Start
You enter.
-> Describe() ->
You continue.

:: Describe()
A dark room.
```

**Migration Steps:**
1. Add empty parameter list to tunnel passage: `:: Describe` → `:: Describe()`
2. Replace `->->` call with `-> Passage() ->`
3. Remove standalone `->->` return

### Script Blocks

Legacy `<script>` blocks should use `@set` directives.

**Before (1.x):**
```whisker
:: Start
<script>
  counter = 0
  name = "Player"
</script>
```

**After (2.0):**
```whisker
:: Start
@set counter = 0
@set name = "Player"
```

### Legacy Conditionals

Mustache-style conditionals should use directives.

**Before (1.x):**
```whisker
:: Start
{{#if hasKey}}
You have the key.
{{/if}}
```

**After (2.0):**
```whisker
:: Start
@if hasKey
You have the key.
@endif
```

### Legacy Loops

**Before (1.x):**
```whisker
:: Start
{{#each items}}
- {{this}}
{{/each}}
```

**After (2.0):**
```whisker
:: Start
@each item in items
- $item
@endeach
```

---

## Migration Workflow

### Step 1: Backup

Always backup your original files:

```bash
cp -r stories/ stories_backup/
```

### Step 2: Run Migration Tool

```bash
for file in stories/*.ws; do
  lua tools/migrate_1x_to_2x.lua "$file" -o "${file%.ws}_2x.ws" --report
done
```

### Step 3: Review Reports

Check migration reports for warnings:

```
=== Migration Report ===
File: mystory.ws

Changes: 3
- Line 5: $thread → $_thread
- Line 12: $await → $_await
- Line 45: $thread → $_thread

Warnings: 2
- Line 23: Tunnel usage (->->) is deprecated
- Line 67: Legacy <script> block detected
```

### Step 4: Manual Updates

Address warnings by rewriting deprecated patterns:

1. Convert tunnels to parameterized passages
2. Replace `<script>` with `@set` directives
3. Update legacy conditionals to directive syntax

### Step 5: Test

Run your story in the WLS 2.0 runtime to verify behavior:

```bash
lua -e "
  local engine = require('whisker.core.engine')
  local e = engine.create({ enable_wls2 = true })
  e:load_file('mystory_2x.ws')
  e:start()
  -- Run tests
"
```

---

## Feature-by-Feature Migration

### Adding Threads

New feature - no migration needed. Add threads to enhance your story:

```whisker
:: Start
-> AmbientSounds    // New: spawn ambient thread
Main story content.

== AmbientSounds    // New: define thread
{~|Birds chirp.|Wind blows.|Leaves rustle.}
@delay 3s { -> AmbientSounds }
```

### Adding Timed Content

New feature - enhance existing stories with delays:

```whisker
:: Suspense
You wait nervously.

@delay 2s {
A knock at the door!
}
```

### Adding Audio

New feature - add sound to your story:

```whisker
@audio theme = "music/main.mp3" loop

:: Start
@play theme
Your adventure begins...
```

### Converting to Parameterized Passages

Replace repetitive passages with parameterized versions:

**Before (1.x):**
```whisker
:: DescribeSword
You examine the sword.
It gleams in the light.

:: DescribeShield
You examine the shield.
It's dented but sturdy.

:: DescribeArmor
You examine the armor.
Heavy but protective.
```

**After (2.0):**
```whisker
:: Examine(item, description)
You examine the $item.
$description

:: Inventory
+ [Sword] -> Examine("sword", "It gleams in the light.") ->
+ [Shield] -> Examine("shield", "It's dented but sturdy.") ->
+ [Armor] -> Examine("armor", "Heavy but protective.") ->
```

---

## Compatibility Matrix

| Feature | 1.x | 2.0 | Notes |
|---------|-----|-----|-------|
| Basic passages | Yes | Yes | Unchanged |
| Choices | Yes | Yes | Unchanged |
| Variables | Yes | Yes | Some reserved names |
| Conditionals | Yes | Yes | Directive syntax preferred |
| Links | Yes | Yes | Unchanged |
| Includes | Yes | Yes | Unchanged |
| Tunnels | Yes | Deprecated | Use parameterized passages |
| Script blocks | Yes | Deprecated | Use @set |
| Threads | No | Yes | New feature |
| Timed content | No | Yes | New feature |
| Audio | No | Yes | New feature |
| Effects | No | Yes | New feature |
| External functions | No | Yes | New feature |

---

## Common Issues

### "Variable $thread is reserved"

**Problem:** You used a reserved word as a variable name.

**Solution:** The migration tool renames it automatically, or manually change:
```whisker
// Before
@set $thread = "main"

// After
@set $_thread = "main"
```

### "Tunnel syntax deprecated"

**Problem:** Tunnels (`->->`) are deprecated.

**Solution:** Convert to parameterized passages:
```whisker
// Before
->-> MyTunnel

// After
-> MyPassage() ->
```

### "Unknown directive @delay"

**Problem:** Running 2.0 syntax on 1.x runtime.

**Solution:** Ensure WLS 2.0 is enabled:
```lua
local e = engine.create({ enable_wls2 = true })
```

### "Thread not found"

**Problem:** Trying to await a thread that doesn't exist.

**Solution:** Ensure thread is spawned before awaiting:
```whisker
:: Start
-> MyThread        // Spawn first
@await MyThread    // Then await
```

---

## Testing Migration

### Unit Tests

Test critical passages individually:

```lua
describe("migrated story", function()
  local engine = require("whisker.core.engine")

  it("handles renamed variables", function()
    local e = engine.create({ enable_wls2 = true })
    e:load([[
      :: Start
      @set $_thread = "test"
      Value: $_thread
    ]])
    e:start()
    assert.contains(e:get_output(), "Value: test")
  end)
end)
```

### Integration Tests

Test full story flow:

```lua
it("completes story without errors", function()
  local e = engine.create({ enable_wls2 = true })
  e:load_file("mystory_2x.ws")
  e:start()

  -- Navigate through story
  while e:has_choices() do
    e:select_choice(1)
  end

  assert.is_true(e:is_complete())
  assert.is_nil(e:get_error())
end)
```

### Regression Tests

Compare 1.x and 2.0 output:

```lua
it("produces same output as 1.x", function()
  local e1 = engine.create()  -- 1.x mode
  local e2 = engine.create({ enable_wls2 = true })  -- 2.0 mode

  e1:load_file("mystory.ws")
  e2:load_file("mystory_2x.ws")

  e1:start()
  e2:start()

  -- Compare outputs (ignoring new features)
  assert.equals(
    normalize(e1:get_output()),
    normalize(e2:get_output())
  )
end)
```

---

## Getting Help

### Resources

- **WLS 2.0 Reference**: See `docs/WLS_2.0_REFERENCE.md`
- **API Documentation**: See `docs/WLS_2.0_API.md`
- **Test Corpus**: See `spec/test-corpus/wls-2.0/`

### Migration Tool Help

```bash
lua tools/migrate_1x_to_2x.lua --help
```

### Report Issues

If you encounter migration problems:

1. Check the error message for hints
2. Search existing issues in the repository
3. Create a new issue with:
   - Your WLS 1.x source code
   - The error message
   - Expected behavior
