# i18n Best Practices

Guidelines for creating maintainable, high-quality internationalized stories.

## Key Naming Conventions

### Use Hierarchical Keys

```yaml
# Good
ui:
  buttons:
    save: "Save"
    load: "Load"

game:
  inventory:
    full: "Inventory full"

# Avoid flat keys
ui_buttons_save: "Save"
game_inventory_full: "Inventory full"
```

### Be Descriptive

```yaml
# Good
dialogue:
  npc:
    blacksmith:
      greeting: "Welcome to my forge!"

# Too vague
text1: "Welcome to my forge!"
```

### Context for Disambiguation

```yaml
# Good - clear context
actions:
  open: "Open"      # Verb: open the door

states:
  open: "Open"      # Adjective: door is open

# Ambiguous
open: "Open"
```

### Suggested Key Structure

```yaml
# UI elements
ui:
  buttons: { ... }
  labels: { ... }
  menus: { ... }

# Game content
game:
  items: { ... }
  locations: { ... }
  characters: { ... }

# Dialogue
dialogue:
  npc:
    [npc_name]:
      [context]: "..."

# System messages
system:
  errors: { ... }
  confirmations: { ... }
```

## Variable Naming

### Use Clear Names

```yaml
# Good
welcome: "Hello, {playerName}, you are in {locationName}."

# Unclear
welcome: "Hello, {p}, you are in {l}."
```

### Consistent Naming

```yaml
# Good - consistent 'Name' suffix
character:
  greeting: "Hello, {characterName}!"
location:
  entered: "You entered {locationName}."

# Inconsistent
character:
  greeting: "Hello, {char}!"
location:
  entered: "You entered {place}."
```

### Common Variable Patterns

| Variable | Usage |
|----------|-------|
| `{name}` | Character/player name |
| `{count}` | Quantity (for plurals) |
| `{item}` | Item name |
| `{location}` | Place name |
| `{value}` | Numeric value |
| `{action}` | Action description |

## Pluralization

### Always Provide 'other'

```yaml
# Good
items:
  count:
    one: "{count} item"
    other: "{count} items"

# Missing fallback - may break
items:
  count:
    one: "{count} item"
```

### Don't Hardcode Numbers

```yaml
# Good
items:
  count:
    zero: "No items"
    one: "One item"
    other: "{count} items"

# Hardcoded - can't translate properly
message: "You have 0 items"
```

### Handle Zero Specially

```yaml
# Consider zero as special case
inventory:
  status:
    zero: "Your inventory is empty."
    one: "You have one item."
    other: "You have {count} items."
```

## RTL Considerations

### Let System Handle Direction

```yaml
# Good - just translate naturally
welcome: "مرحبا بك في اللعبة"

# Don't try to force direction in text
welcome: "‏مرحبا بك في اللعبة‏"  # Let BiDi handle it
```

### Isolate LTR in RTL Context

When mixing English terms in RTL text:

```lua
local BiDi = require("whisker.i18n.bidi")

-- Isolate English game title in Arabic text
local title = BiDi.isolate("Whisker Quest", "ltr")
local text = i18n:t("welcome", { title = title })
```

### Test RTL Languages

- Arabic (ar)
- Hebrew (he)
- Persian (fa)
- Urdu (ur)

Verify text displays correctly with mixed content.

## Performance

### Bundle Only Needed Locales

```lua
-- Don't load all 50 locales
-- Only load what user needs

i18n:load(userLocale, "locales/" .. userLocale .. ".lua")
```

### Use Compiled Format in Production

```bash
# Development: YAML (editable)
whisker-i18n validate locales/en.yml locales/es.yml

# Production: Lua (fast loading)
whisker-i18n compile locales/en.yml build/locales/en.lua
whisker-i18n compile locales/es.yml build/locales/es.lua
```

### Lazy Load Locales

```lua
-- Load base locale at startup
i18n:load("en", "locales/en.lua")

-- Load others on demand
function switchLocale(locale)
  if not i18n:has("test", locale) then
    i18n:load(locale, "locales/" .. locale .. ".lua")
  end
  i18n:setLocale(locale)
end
```

## Translation Quality

### Provide Context in Comments

```yaml
# The player character's name (used in save files)
player:
  name: "Hero"

# NPC blacksmith greeting (friendly, casual tone)
dialogue:
  blacksmith:
    greeting: "Welcome, friend!"

# Error when inventory is full (apologetic tone)
errors:
  inventory_full: "Sorry, you can't carry any more."
```

### Create Translation Notes

Create a separate `translation-notes.md`:

```markdown
# Translation Notes

## Tone
This game is lighthearted and humorous. Translations should maintain
a casual, friendly tone. Avoid overly formal language.

## Character Names
- "Hero" - Generic, can be localized
- "Grimwald" - Keep as-is (fantasy name)
- "The Merchant" - Localize the title

## Game-Specific Terms
- "mana" - Use local fantasy game convention
- "quest" - Standard RPG term, localize normally
```

### Test Edge Cases

- Very long translations (German often 30% longer than English)
- Very short translations (Chinese/Japanese often shorter)
- Special characters (é, ñ, ü, 日本語)
- Zero, one, and large numbers in plurals
- Empty strings
- Strings with only variables

## Common Anti-Patterns

### String Concatenation

```lua
-- Bad: Can't translate properly
local message = "You have " .. count .. " items"

-- Good: Use i18n
local message = i18n:p("items.count", count)
```

### Hardcoded Formatting

```yaml
# Bad: Assumes English word order
message: "{verb} the {object}"  # "Open the door"

# Good: Full sentence (word order varies by language)
open_door: "Open the door"
```

### Splitting Sentences

```yaml
# Bad: Grammatically incorrect in many languages
part1: "You have"
part2: "items"
# Combine: "You have {count} items"

# Good: Complete sentence
full_message: "You have {count} items"
```

### Embedded Logic

```yaml
# Bad: Logic embedded in translation
greeting: "Good {timeOfDay}, {name}!"
# This fails when languages structure time differently

# Good: Separate keys
greeting_morning: "Good morning, {name}!"
greeting_afternoon: "Good afternoon, {name}!"
greeting_evening: "Good evening, {name}!"
```

### Gender Assumptions

```yaml
# Bad: Assumes one form works for all
hero_wins: "The hero wins! She is victorious!"

# Good: Either gender-neutral or separate keys
hero_wins: "The hero wins! Victory is achieved!"
# Or
hero_wins_male: "The hero wins! He is victorious!"
hero_wins_female: "The hero wins! She is victorious!"
```

## Project Organization

### Recommended Structure

```
my-story/
  src/
    story.whisker
    chapters/
  locales/
    en.yml          # Base language
    es.yml          # Spanish
    fr.yml          # French
    de.yml          # German
    ja.yml          # Japanese
    ar.yml          # Arabic (RTL)
    zh-Hans.yml     # Simplified Chinese
    zh-Hant.yml     # Traditional Chinese
    translation-notes.md
  build/
    locales/        # Compiled .lua files
```

### Locale File Naming

Use BCP 47 locale codes:

| Code | Language |
|------|----------|
| en | English |
| es | Spanish |
| fr | French |
| de | German |
| ja | Japanese |
| zh-Hans | Simplified Chinese |
| zh-Hant | Traditional Chinese |
| pt-BR | Brazilian Portuguese |
| en-GB | British English |

### Version Control

- Commit base locale (en.yml) with code changes
- Have translators work on separate branches or files
- Use validation before merging translations
- Keep translation-notes.md updated

## Workflow Checklist

### For Authors

1. [ ] Use `@@t` and `@@p` tags for all user-visible text
2. [ ] Run extraction to find all keys
3. [ ] Create base translation (usually English)
4. [ ] Add context comments for ambiguous strings
5. [ ] Validate translations before release
6. [ ] Test in each supported language

### For Translators

1. [ ] Understand the context (play the game if possible)
2. [ ] Preserve all `{variables}`
3. [ ] Use correct plural forms for your language
4. [ ] Run validation to check for issues
5. [ ] Have native speaker review
6. [ ] Test in context

### For Release

1. [ ] All locales validated
2. [ ] Status report shows 100% coverage
3. [ ] Compiled to Lua for production
4. [ ] Tested on target platforms
5. [ ] RTL languages verified
