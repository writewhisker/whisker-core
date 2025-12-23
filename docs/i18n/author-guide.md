# Internationalization Guide for Authors

This guide shows you how to internationalize your whisker-core stories so players can enjoy them in their preferred language.

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Start](#quick-start)
3. [Translation Syntax](#translation-syntax)
4. [Working with Variables](#working-with-variables)
5. [Pluralization](#pluralization)
6. [Project Structure](#project-structure)
7. [Testing Your Translations](#testing-your-translations)
8. [Building for Production](#building-for-production)

## Introduction

whisker-core's i18n system lets you create stories that work in multiple languages. Benefits include:

- **Reach more players**: Make your story accessible to non-English speakers
- **Better experience**: Players read in their native language
- **Easy workflow**: Simple extraction and validation tools
- **Professional quality**: CLDR-compliant pluralization

## Quick Start

Let's internationalize a simple story in 15 minutes.

### 1. Write Your Story

```whisker
You wake up in a dark room.

You see a rusty sword on the floor.

>> pick_up_sword = input("Pick it up? (yes/no)")
```

### 2. Mark Text for Translation

Replace hardcoded text with `@@t` tags:

```whisker
@@t intro.wake_up

@@t items.sword_description

>> pick_up_sword = input(@@t prompts.pick_up)
```

### 3. Extract Translatable Strings

Run the extraction tool:

```bash
whisker-i18n extract src/ -o locales/template.yml
```

### 4. Create English Translation

Edit `locales/en.yml`:

```yaml
intro:
  wake_up: "You wake up in a dark room."

items:
  sword_description: "You see a rusty sword on the floor."

prompts:
  pick_up: "Pick it up? (yes/no)"
```

### 5. Test Your Story

```bash
whisker-core run story.whisker --locale en
```

Your story now loads from the translation file!

### 6. Add Spanish Translation

Copy `en.yml` to `es.yml` and translate:

```yaml
intro:
  wake_up: "Te despiertas en una habitación oscura."

items:
  sword_description: "Ves una espada oxidada en el suelo."

prompts:
  pick_up: "¿Recogerla? (sí/no)"
```

### 7. Play in Spanish

```bash
whisker-core run story.whisker --locale es
```

Done! Your story now supports two languages.

## Translation Syntax

### Simple Translation

```whisker
@@t key
```

Example:
```whisker
@@t greeting
```

Translation file:
```yaml
greeting: "Hello, adventurer!"
```

### Translation with Variables

```whisker
@@t key var1=value1 var2=value2
```

Example:
```whisker
@@t welcome name=player.name location=current_room
```

Translation file:
```yaml
welcome: "Welcome, {name}, to {location}!"
```

### Pluralization

```whisker
@@p key count=expression
```

Example:
```whisker
You have @@p items.count count=inventory.size items.
```

Translation file:
```yaml
items:
  count:
    one: "{count} item"
    other: "{count} items"
```

## Working with Variables

Variables are interpolated using `{variable}` syntax in translations.

### Simple Variables

```yaml
greeting: "Hello, {name}!"
```

```whisker
@@t greeting name=player.name
```

### Nested Variables

```yaml
location_message: "You are in {location} on {floor} floor."
```

```whisker
@@t location_message location=room.name floor=room.floor
```

### Computed Expressions

```whisker
>> health_percent = (player.health / player.max_health) * 100
@@t status.health percent=health_percent
```

```yaml
status:
  health: "Health: {percent}%"
```

## Pluralization

Different languages have different plural rules. whisker-core handles this automatically.

### English (2 forms)

```yaml
items:
  count:
    one: "{count} item"      # 1
    other: "{count} items"   # 0, 2, 3, 4, ...
```

### Spanish (2 forms, same as English)

```yaml
items:
  count:
    one: "{count} artículo"
    other: "{count} artículos"
```

### Russian (3 forms)

```yaml
items:
  count:
    one: "{count} предмет"       # 1, 21, 31, ...
    few: "{count} предмета"      # 2-4, 22-24, ...
    many: "{count} предметов"    # 0, 5-20, 25-30, ...
```

### Arabic (6 forms)

```yaml
items:
  count:
    zero: "لا توجد عناصر"        # 0
    one: "عنصر واحد"             # 1
    two: "عنصران"                # 2
    few: "{count} عناصر"         # 3-10
    many: "{count} عنصرًا"       # 11-99
    other: "{count} عنصر"        # 100, 1000, ...
```

Always provide at least `other` as a fallback.

## Project Structure

Recommended directory structure:

```
my-story/
  story.whisker           -- Main story
  chapters/
    chapter1.whisker
    chapter2.whisker
  locales/
    en.yml                -- English (base)
    es.yml                -- Spanish
    fr.yml                -- French
    de.yml                -- German
    ar.yml                -- Arabic (RTL)
    ja.yml                -- Japanese
    ru.yml                -- Russian
    zh-Hans.yml           -- Simplified Chinese
  build/
    locales/              -- Compiled .lua files
```

## Testing Your Translations

### 1. Validate Completeness

```bash
whisker-i18n validate locales/en.yml locales/es.yml
```

Checks for:
- Missing keys
- Unused keys
- Variable mismatches

### 2. Check Status

```bash
whisker-i18n status en locales/
```

Shows completion percentage for each language.

### 3. Play Through Story

Test in each language:

```bash
whisker-core run story.whisker --locale en
whisker-core run story.whisker --locale es
whisker-core run story.whisker --locale ar
```

Pay attention to:
- Text fits in UI
- Plurals work correctly
- Variables interpolate properly
- RTL languages display correctly

## Building for Production

### Compile Translations

```bash
whisker-i18n compile locales/en.yml build/locales/en.lua --minify
whisker-i18n compile locales/es.yml build/locales/es.lua --minify
```

Benefits:
- 50%+ smaller file size
- Faster loading
- No YAML parser needed at runtime

### Bundle Only Used Locales

Don't ship all 20 translations if only using 3.

### Set Default Locale

In your game config:

```lua
local I18n = require("whisker.i18n")

local i18n = I18n.new():init({
  defaultLocale = "en",
  loadPath = "locales/{locale}.lua"
})
```

## Next Steps

- Read [Translator Guide](translator-guide.md) if managing translations
- See [Best Practices](best-practices.md) for key naming conventions
- Check [Examples](examples/) for complete working projects
