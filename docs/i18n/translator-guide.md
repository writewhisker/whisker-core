# Translation Guide

This guide helps translators create high-quality translations for whisker-core stories.

## What You'll Need

- A text editor (VS Code, Sublime Text, or even Notepad)
- Basic YAML knowledge (we'll teach you)
- The base language translation file (usually English)

## YAML Basics

YAML is a human-friendly format for structured data.

### Rules

1. **Indentation matters**: Use 2 spaces (not tabs)
2. **Colons separate keys and values**: `key: value`
3. **Nested keys are indented**:
   ```yaml
   parent:
     child: value
   ```
4. **Quotes for special characters**:
   ```yaml
   message: "Text with: special characters"
   ```

### Example

```yaml
# Comments start with #
greeting: "Hello!"

dialogue:
  npc:
    greeting: "Welcome, traveler!"
    farewell: "Safe travels!"

items:
  sword: "a rusty sword"
  shield: "a wooden shield"
```

## Translation Workflow

### 1. Receive Base File

You'll receive `en.yml` (English):

```yaml
intro:
  wake_up: "You wake up in a dark room."

items:
  sword: "a rusty sword"
  count:
    one: "{count} item"
    other: "{count} items"
```

### 2. Create Your Language File

Copy to `es.yml` (Spanish) and translate:

```yaml
intro:
  wake_up: "Te despiertas en una habitación oscura."

items:
  sword: "una espada oxidada"
  count:
    one: "{count} artículo"
    other: "{count} artículos"
```

### 3. Keep Structure Identical

**Correct:**
```yaml
# en.yml
items:
  sword: "a sword"

# es.yml
items:
  sword: "una espada"
```

**Wrong:**
```yaml
# es.yml
weapons:           # Changed key!
  sword: "una espada"
```

### 4. Preserve Variables

Variables look like `{name}`. Keep them exactly as-is:

**Correct:**
```yaml
# en.yml
welcome: "Hello, {name}!"

# es.yml
welcome: "¡Hola, {name}!"
```

**Wrong:**
```yaml
# es.yml
welcome: "¡Hola, {nombre}!"    # Changed variable name!
```

### 5. Handle Plurals

Your language may have different plural forms than English.

**English (2 forms):**
```yaml
items:
  count:
    one: "{count} item"
    other: "{count} items"
```

**Spanish (2 forms):**
```yaml
items:
  count:
    one: "{count} artículo"
    other: "{count} artículos"
```

**Russian (3 forms):**
```yaml
items:
  count:
    one: "{count} предмет"       # 1, 21, 31
    few: "{count} предмета"      # 2-4, 22-24
    many: "{count} предметов"    # 0, 5-20, 25-30
```

**Arabic (6 forms):**
```yaml
items:
  count:
    zero: "لا توجد عناصر"
    one: "عنصر واحد"
    two: "عنصران"
    few: "{count} عناصر"
    many: "{count} عنصرًا"
    other: "{count} عنصر"
```

Always include `other` as a fallback.

### 6. Validate Your Work

Ask the author to run:

```bash
whisker-i18n validate locales/en.yml locales/es.yml
```

This checks for:
- Missing translations
- Variable mismatches
- Syntax errors

## Plural Forms by Language

| Language | Forms | Categories |
|----------|-------|------------|
| English | 2 | one, other |
| Spanish | 2 | one, other |
| French | 2 | one, other |
| German | 2 | one, other |
| Russian | 3 | one, few, many |
| Polish | 3 | one, few, many |
| Arabic | 6 | zero, one, two, few, many, other |
| Japanese | 1 | other |
| Chinese | 1 | other |
| Korean | 1 | other |

Check [CLDR Plural Rules](http://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html) for your language.

## Translation Tips

### Context Matters

Sometimes the same word translates differently:

```yaml
# "Open" as verb
actions:
  open_door: "Open the door"

# "Open" as state
states:
  door_open: "The door is open"
```

If unclear, ask the author for context.

### Cultural Adaptation

Don't translate literally. Adapt for your culture:

```yaml
# en.yml
greeting: "What's up?"

# es.yml (Latin America)
greeting: "¿Qué onda?"

# es.yml (Spain)
greeting: "¿Qué tal?"
```

### Length and UI

Translations may be longer or shorter:

- German words often longer than English
- Japanese can be more compact
- Test that text fits in UI

### Gender and Formality

Some languages have gendered words or formality levels:

```yaml
# French: vous (formal) vs tu (informal)
greeting_formal: "Bonjour, comment allez-vous?"
greeting_casual: "Salut, comment vas-tu?"
```

### RTL Languages

For Arabic, Hebrew, Persian, Urdu:

- Write naturally in your language
- whisker-core handles text direction
- English names/terms stay LTR automatically

## Common Mistakes

### Changing Keys

```yaml
# Wrong: Changed "greeting" to "saludo"
saludo: "¡Hola!"

# Correct: Keep key as "greeting"
greeting: "¡Hola!"
```

### Removing Variables

```yaml
# Wrong: Removed {name}
welcome: "¡Hola!"

# Correct: Keep variable
welcome: "¡Hola, {name}!"
```

### Breaking YAML Syntax

```yaml
# Wrong: Missing quotes for colon
message: Text with: colon

# Correct: Quote strings with special characters
message: "Text with: colon"
```

### Inconsistent Indentation

```yaml
# Wrong: Mixed indentation
parent:
    child: value    # 4 spaces
  other: value      # 2 spaces

# Correct: Consistent 2-space indent
parent:
  child: value
  other: value
```

## Quality Checklist

Before submitting:

- [ ] All keys present (no missing translations)
- [ ] All variables preserved (check {name}, {count}, etc.)
- [ ] Plural forms appropriate for language
- [ ] YAML syntax valid (no errors)
- [ ] Validation passes: `whisker-i18n validate`
- [ ] Text flows naturally (not literal translation)
- [ ] Cultural references adapted
- [ ] Proofread for typos

## Getting Help

- Ask author for context on unclear strings
- Check [CLDR Plural Rules](http://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html) for your language
- Test the story to see translations in context
- See [Troubleshooting](troubleshooting.md) for common issues
