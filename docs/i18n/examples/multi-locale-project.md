# Multi-Locale Project Example

A complete project setup supporting multiple languages with workflow automation.

## Project Structure

```
my-game/
├── src/
│   ├── main.lua
│   ├── game.lua
│   └── story/
│       ├── chapter1.whisker
│       ├── chapter2.whisker
│       └── chapter3.whisker
├── locales/
│   ├── en.yml              # English (base)
│   ├── es.yml              # Spanish
│   ├── fr.yml              # French
│   ├── de.yml              # German
│   ├── ja.yml              # Japanese
│   ├── zh-Hans.yml         # Simplified Chinese
│   ├── ar.yml              # Arabic (RTL)
│   └── ru.yml              # Russian
├── build/
│   └── locales/            # Compiled Lua files
├── scripts/
│   ├── extract.sh
│   ├── validate.sh
│   ├── compile.sh
│   └── status.sh
├── config/
│   └── i18n.lua
└── translation-notes.md
```

## Configuration

### config/i18n.lua

```lua
-- i18n configuration
return {
  -- Default locale when detection fails
  defaultLocale = "en",

  -- Fallback when key missing in current locale
  fallbackLocale = "en",

  -- Auto-detect user's locale from system
  autoDetect = true,

  -- Log missing translations (useful in development)
  logMissing = true,

  -- Supported locales (for language selector)
  supportedLocales = {
    { code = "en", name = "English", native = "English" },
    { code = "es", name = "Spanish", native = "Español" },
    { code = "fr", name = "French", native = "Français" },
    { code = "de", name = "German", native = "Deutsch" },
    { code = "ja", name = "Japanese", native = "日本語" },
    { code = "zh-Hans", name = "Chinese (Simplified)", native = "简体中文" },
    { code = "ar", name = "Arabic", native = "العربية" },
    { code = "ru", name = "Russian", native = "Русский" },
  },

  -- Path to locale files
  -- Use .yml in development, .lua in production
  localePath = "locales/{locale}.yml",
  -- localePath = "build/locales/{locale}.lua",
}
```

### src/main.lua

```lua
local I18n = require("whisker.i18n")
local Game = require("game")

-- Load configuration
local config = require("config.i18n")

-- Initialize i18n
local i18n = I18n.new():init({
  defaultLocale = config.defaultLocale,
  fallbackLocale = config.fallbackLocale,
  autoDetect = config.autoDetect,
  logMissing = config.logMissing,
})

-- Load all supported locales
for _, locale in ipairs(config.supportedLocales) do
  local path = config.localePath:gsub("{locale}", locale.code)
  local success = i18n:load(locale.code, path)
  if not success then
    print("Warning: Could not load locale: " .. locale.code)
  end
end

-- Show language selector on first run
local function showLanguageSelector()
  print("\nSelect Language / Seleccionar Idioma / 言語を選択")
  print(string.rep("-", 50))

  for i, locale in ipairs(config.supportedLocales) do
    local rtlMark = ""
    if i18n:isRTL(locale.code) then
      rtlMark = " [RTL]"
    end
    print(string.format("%d. %s (%s)%s",
      i, locale.native, locale.name, rtlMark))
  end

  print("")
  io.write("Choice: ")
  local choice = tonumber(io.read())

  if choice and config.supportedLocales[choice] then
    i18n:setLocale(config.supportedLocales[choice].code)
    return true
  end

  return false
end

-- Allow language switching mid-game
local function createLanguageMenu()
  return {
    title = i18n:t("ui.settings.language"),
    options = {},
    onSelect = function(index)
      local locale = config.supportedLocales[index]
      if locale then
        i18n:setLocale(locale.code)
        -- Trigger UI refresh
        Game.refreshUI()
      end
    end
  }

  for _, locale in ipairs(config.supportedLocales) do
    table.insert(menu.options, {
      label = locale.native,
      selected = i18n:getLocale() == locale.code
    })
  end

  return menu
end

-- Main entry point
local function main()
  -- First run: show language selector
  if not showLanguageSelector() then
    print("Invalid selection, using default: " .. config.defaultLocale)
  end

  -- Start game with selected locale
  print("")
  print(i18n:t("ui.loading"))
  print("")

  local game = Game.new({ i18n = i18n })
  game:run()
end

main()
```

## Workflow Scripts

### scripts/extract.sh

```bash
#!/bin/bash
# Extract all translatable strings from source files

set -e

echo "Extracting i18n strings..."

# Find all whisker files and extract
whisker-i18n extract src/story/ \
  --recursive \
  --pattern "*.whisker" \
  --output locales/template.yml

echo "Template generated: locales/template.yml"
echo ""

# Show summary
echo "Summary:"
grep -c ":" locales/template.yml | xargs echo "  Total keys:"
```

### scripts/validate.sh

```bash
#!/bin/bash
# Validate all translations against base (English)

set -e

BASE="locales/en.yml"
ERRORS=0

echo "Validating translations against $BASE"
echo ""

for file in locales/*.yml; do
  [ "$file" = "$BASE" ] && continue
  [ "$file" = "locales/template.yml" ] && continue

  locale=$(basename "$file" .yml)
  echo "=== $locale ==="

  if whisker-i18n validate "$BASE" "$file" --strict; then
    echo "  OK"
  else
    ERRORS=$((ERRORS + 1))
  fi
  echo ""
done

if [ $ERRORS -gt 0 ]; then
  echo "FAILED: $ERRORS locale(s) have errors"
  exit 1
else
  echo "All translations valid!"
fi
```

### scripts/compile.sh

```bash
#!/bin/bash
# Compile all translations to Lua for production

set -e

mkdir -p build/locales

echo "Compiling translations..."

for yml in locales/*.yml; do
  [ "$yml" = "locales/template.yml" ] && continue

  locale=$(basename "$yml" .yml)
  lua="build/locales/${locale}.lua"

  whisker-i18n compile "$yml" "$lua" --minify
  echo "  $yml -> $lua"
done

echo ""
echo "Done. Compiled files in build/locales/"

# Show size comparison
echo ""
echo "Size comparison:"
for yml in locales/*.yml; do
  [ "$yml" = "locales/template.yml" ] && continue

  locale=$(basename "$yml" .yml)
  lua="build/locales/${locale}.lua"

  yml_size=$(wc -c < "$yml")
  lua_size=$(wc -c < "$lua")
  savings=$((100 - (lua_size * 100 / yml_size)))

  printf "  %s: %d bytes -> %d bytes (%d%% smaller)\n" \
    "$locale" "$yml_size" "$lua_size" "$savings"
done
```

### scripts/status.sh

```bash
#!/bin/bash
# Show translation status for all locales

echo "Translation Status Report"
echo "========================="
echo ""

whisker-i18n status en locales/

echo ""
echo "Missing keys by locale:"
echo "------------------------"

for file in locales/*.yml; do
  [ "$file" = "locales/en.yml" ] && continue
  [ "$file" = "locales/template.yml" ] && continue

  locale=$(basename "$file" .yml)
  missing=$(whisker-i18n validate locales/en.yml "$file" 2>&1 | grep -c "missing_key" || true)

  if [ "$missing" -gt 0 ]; then
    echo "$locale: $missing missing keys"
  fi
done
```

## Translation Files

### locales/en.yml (Base)

```yaml
# English - Base Language
# All other translations must match this structure

meta:
  language: "English"
  direction: "ltr"

ui:
  loading: "Loading..."
  continue: "Press ENTER to continue"
  choices: "Your choices:"
  settings:
    title: "Settings"
    language: "Language"
    save: "Save"
    cancel: "Cancel"

game:
  title: "The Adventure"
  new_game: "New Game"
  continue_game: "Continue"
  load_game: "Load Game"
  save_game: "Save Game"
  quit: "Quit"

story:
  chapter1:
    title: "Chapter 1: The Beginning"
    intro: "Your adventure begins in the village of {village}."

  chapter2:
    title: "Chapter 2: The Journey"

  chapter3:
    title: "Chapter 3: The Conclusion"

character:
  player:
    default_name: "Hero"

  npc:
    merchant:
      greeting: "Welcome, {name}! What can I get you?"
      farewell: "Come back soon!"

items:
  gold:
    one: "{count} gold piece"
    other: "{count} gold pieces"

  potion:
    one: "{count} potion"
    other: "{count} potions"

  sword: "Iron Sword"
  shield: "Wooden Shield"

errors:
  not_enough_gold: "You don't have enough gold."
  inventory_full: "Your inventory is full."
  save_failed: "Failed to save game."
```

### translation-notes.md

```markdown
# Translation Notes

## General Guidelines

1. **Tone**: This is a fantasy adventure game. Keep the tone
   light and adventurous, not too formal.

2. **Player Address**: Use informal "you" forms where applicable
   (tu vs usted in Spanish, du vs Sie in German).

3. **Fantasy Terms**: Standard fantasy RPG terminology should be
   localized using common conventions for the target language.

## Specific Terms

| English | Notes |
|---------|-------|
| Hero | Generic, can be localized |
| Gold pieces | Standard fantasy currency |
| Potion | Health potion, use standard RPG term |

## Character Names

- **Hero** - Player character, localize freely
- **The Merchant** - Generic NPC, localize the title
- Village names - Keep as-is (they're fantasy names)

## Variables

These variables appear in translations:

| Variable | Type | Description |
|----------|------|-------------|
| {name} | string | Character name |
| {count} | number | Item count (for plurals) |
| {village} | string | Village name |

## RTL Languages (Arabic)

- UI should mirror
- English game/character names can stay LTR
- Test with mixed content

## Plural Forms

| Language | Forms Needed |
|----------|--------------|
| English | one, other |
| Spanish | one, other |
| French | one, other |
| German | one, other |
| Russian | one, few, many, other |
| Arabic | zero, one, two, few, many, other |
| Japanese | other (only) |
| Chinese | other (only) |
```

## CI/CD Integration

### .github/workflows/i18n.yml

```yaml
name: i18n Validation

on:
  push:
    paths:
      - 'locales/**'
      - 'src/**/*.whisker'
  pull_request:
    paths:
      - 'locales/**'

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Lua
        uses: leafo/gh-actions-lua@v9

      - name: Install whisker-core
        run: luarocks install whisker-core

      - name: Check for new strings
        run: |
          whisker-i18n extract src/story/ -o /tmp/current.yml
          if ! diff -q locales/template.yml /tmp/current.yml; then
            echo "::warning::New strings found. Update locales/template.yml"
          fi

      - name: Validate translations
        run: ./scripts/validate.sh

      - name: Check coverage
        run: |
          whisker-i18n status en locales/ --threshold 80 || \
            echo "::warning::Some locales below 80% coverage"

  compile:
    runs-on: ubuntu-latest
    needs: validate

    steps:
      - uses: actions/checkout@v3

      - name: Setup Lua
        uses: leafo/gh-actions-lua@v9

      - name: Compile translations
        run: ./scripts/compile.sh

      - name: Upload compiled locales
        uses: actions/upload-artifact@v3
        with:
          name: compiled-locales
          path: build/locales/
```

## Production Checklist

### Before Release

- [ ] All locales pass validation (`./scripts/validate.sh`)
- [ ] All locales at 100% coverage (`./scripts/status.sh`)
- [ ] Translations compiled to Lua (`./scripts/compile.sh`)
- [ ] RTL languages tested (ar)
- [ ] Pluralization tested for complex languages (ru, ar)
- [ ] All strings proofread by native speakers
- [ ] Config points to compiled files

### Updating config for production

```lua
-- config/i18n.lua
return {
  -- ...
  -- Development: YAML files
  -- localePath = "locales/{locale}.yml",

  -- Production: Compiled Lua files
  localePath = "build/locales/{locale}.lua",
}
```

## Adding a New Language

1. **Copy template:**
   ```bash
   cp locales/template.yml locales/XX.yml
   ```

2. **Add to config:**
   ```lua
   -- config/i18n.lua
   { code = "XX", name = "Language", native = "Native Name" },
   ```

3. **Translate:**
   Edit `locales/XX.yml` with translations

4. **Validate:**
   ```bash
   whisker-i18n validate locales/en.yml locales/XX.yml
   ```

5. **Test:**
   Run game with `--locale XX`

6. **Compile:**
   ```bash
   whisker-i18n compile locales/XX.yml build/locales/XX.lua
   ```
