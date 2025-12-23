# Simple Story Example

A minimal example showing basic i18n setup.

## Project Structure

```
simple-story/
  story.whisker
  locales/
    en.yml
    es.yml
  main.lua
```

## The Story

### story.whisker

```whisker
:: start
@@t intro.wake_up

@@t intro.look_around

You see:
- @@t items.sword
- @@t items.torch

>> choice = input(@@t prompts.what_do)

{choice == "sword"}:
  @@t actions.pick_sword
  -> sword_path

{choice == "torch"}:
  @@t actions.pick_torch
  -> torch_path

:: sword_path
@@t endings.sword

:: torch_path
@@t endings.torch
```

## Translation Files

### locales/en.yml

```yaml
intro:
  wake_up: "You wake up in a dark dungeon."
  look_around: "As your eyes adjust, you can make out some objects nearby."

items:
  sword: "A rusty sword"
  torch: "An unlit torch"

prompts:
  what_do: "What do you pick up? (sword/torch)"

actions:
  pick_sword: "You grab the sword. It feels heavy but reassuring."
  pick_torch: "You take the torch. Maybe you can light it somehow."

endings:
  sword: "With sword in hand, you venture deeper into the dungeon. THE END."
  torch: "The torch flickers to life, revealing a hidden passage! THE END."
```

### locales/es.yml

```yaml
intro:
  wake_up: "Te despiertas en una mazmorra oscura."
  look_around: "Mientras tus ojos se adaptan, puedes distinguir algunos objetos cercanos."

items:
  sword: "Una espada oxidada"
  torch: "Una antorcha apagada"

prompts:
  what_do: "¿Qué recoges? (espada/antorcha)"

actions:
  pick_sword: "Agarras la espada. Se siente pesada pero reconfortante."
  pick_torch: "Tomas la antorcha. Quizás puedas encenderla de alguna manera."

endings:
  sword: "Con la espada en mano, te adentras en la mazmorra. FIN."
  torch: "La antorcha cobra vida, revelando un pasaje oculto! FIN."
```

## Game Code

### main.lua

```lua
local I18n = require("whisker.i18n")
local Story = require("whisker.story")

-- Initialize i18n
local i18n = I18n.new():init({
  defaultLocale = "en",
  autoDetect = true
})

-- Load translations
i18n:load("en", "locales/en.yml")
i18n:load("es", "locales/es.yml")

-- Create story with i18n
local story = Story.new({
  i18n = i18n
})

-- Load and run
story:load("story.whisker")
story:run()
```

## Running the Example

### In English (default)

```bash
lua main.lua
```

Output:
```
You wake up in a dark dungeon.
As your eyes adjust, you can make out some objects nearby.

You see:
- A rusty sword
- An unlit torch

What do you pick up? (sword/torch)
```

### In Spanish

```bash
LANG=es lua main.lua
```

Or set programmatically:

```lua
i18n:setLocale("es")
```

Output:
```
Te despiertas en una mazmorra oscura.
Mientras tus ojos se adaptan, puedes distinguir algunos objetos cercanos.

Ves:
- Una espada oxidada
- Una antorcha apagada

¿Qué recoges? (espada/antorcha)
```

## Key Points

1. **All text uses `@@t` tags** - No hardcoded strings in the story
2. **Hierarchical keys** - Organized by category (intro, items, prompts, etc.)
3. **Simple translation files** - YAML format is easy to edit
4. **Language switching** - Works via locale detection or explicit setting

## Next Steps

- Add more languages by creating additional .yml files
- See [Advanced Features](advanced-features.md) for variables and plurals
- Read [Best Practices](../best-practices.md) for key naming
