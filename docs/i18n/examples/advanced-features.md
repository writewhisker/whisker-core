# Advanced Features Example

Demonstrates variables, pluralization, and complex patterns.

## Project Structure

```
advanced-story/
  story.whisker
  locales/
    en.yml
    es.yml
    ru.yml
  main.lua
```

## Features Covered

1. Variable interpolation
2. Pluralization
3. Nested variables
4. Dynamic content
5. Fallback handling

## The Story

### story.whisker

```whisker
:: start
>> player_name = input(@@t prompts.enter_name)
>> gold = 50
>> items = 3

@@t welcome name=player_name

-> inventory

:: inventory
@@t inventory.title

@@t inventory.gold amount=gold
@@p inventory.items count=items

>> action = input(@@t prompts.action)

{action == "buy"}:
  -> shop

{action == "use"}:
  -> use_item

:: shop
@@t shop.greeting name=player_name

>> item_count = 2
>> cost = item_count * 10

@@p shop.offer count=item_count price=cost

{gold >= cost}:
  >> gold = gold - cost
  >> items = items + item_count
  @@t shop.success
  -> inventory

{gold < cost}:
  @@t shop.insufficient have=gold need=cost
  -> inventory

:: use_item
{items > 0}:
  >> items = items - 1
  @@p actions.used count=1
  @@p inventory.remaining count=items
  -> inventory

{items == 0}:
  @@t errors.no_items
  -> inventory
```

## Translation Files

### locales/en.yml

```yaml
prompts:
  enter_name: "Enter your name:"
  action: "What would you like to do? (buy/use)"

welcome: "Welcome, {name}! Your adventure begins."

inventory:
  title: "=== Inventory ==="
  gold: "Gold: {amount}"
  items:
    one: "{count} item"
    other: "{count} items"
  remaining:
    zero: "You have no items left."
    one: "You have {count} item remaining."
    other: "You have {count} items remaining."

shop:
  greeting: "Hello, {name}! Welcome to my shop."
  offer:
    one: "I have {count} potion for {price} gold. Buy it?"
    other: "I have {count} potions for {price} gold. Buy them?"
  success: "Transaction complete! Enjoy your purchase."
  insufficient: "Sorry, you need {need} gold but only have {have}."

actions:
  used:
    one: "You used {count} item."
    other: "You used {count} items."

errors:
  no_items: "You don't have any items to use!"
```

### locales/es.yml

```yaml
prompts:
  enter_name: "Ingresa tu nombre:"
  action: "¿Qué te gustaría hacer? (comprar/usar)"

welcome: "¡Bienvenido, {name}! Tu aventura comienza."

inventory:
  title: "=== Inventario ==="
  gold: "Oro: {amount}"
  items:
    one: "{count} artículo"
    other: "{count} artículos"
  remaining:
    zero: "No te quedan artículos."
    one: "Te queda {count} artículo."
    other: "Te quedan {count} artículos."

shop:
  greeting: "¡Hola, {name}! Bienvenido a mi tienda."
  offer:
    one: "Tengo {count} poción por {price} de oro. ¿La compras?"
    other: "Tengo {count} pociones por {price} de oro. ¿Las compras?"
  success: "¡Transacción completada! Disfruta tu compra."
  insufficient: "Lo siento, necesitas {need} de oro pero solo tienes {have}."

actions:
  used:
    one: "Usaste {count} artículo."
    other: "Usaste {count} artículos."

errors:
  no_items: "¡No tienes artículos para usar!"
```

### locales/ru.yml

Russian demonstrates 3 plural forms.

```yaml
prompts:
  enter_name: "Введите ваше имя:"
  action: "Что вы хотите сделать? (купить/использовать)"

welcome: "Добро пожаловать, {name}! Ваше приключение начинается."

inventory:
  title: "=== Инвентарь ==="
  gold: "Золото: {amount}"
  items:
    one: "{count} предмет"
    few: "{count} предмета"
    many: "{count} предметов"
    other: "{count} предметов"
  remaining:
    zero: "У вас не осталось предметов."
    one: "У вас остался {count} предмет."
    few: "У вас осталось {count} предмета."
    many: "У вас осталось {count} предметов."
    other: "У вас осталось {count} предметов."

shop:
  greeting: "Здравствуйте, {name}! Добро пожаловать в мой магазин."
  offer:
    one: "У меня есть {count} зелье за {price} золота. Купите?"
    few: "У меня есть {count} зелья за {price} золота. Купите?"
    many: "У меня есть {count} зелий за {price} золота. Купите?"
    other: "У меня есть {count} зелий за {price} золота. Купите?"
  success: "Сделка завершена! Наслаждайтесь покупкой."
  insufficient: "Извините, вам нужно {need} золота, но у вас только {have}."

actions:
  used:
    one: "Вы использовали {count} предмет."
    few: "Вы использовали {count} предмета."
    many: "Вы использовали {count} предметов."
    other: "Вы использовали {count} предметов."

errors:
  no_items: "У вас нет предметов для использования!"
```

## Game Code

### main.lua

```lua
local I18n = require("whisker.i18n")
local Story = require("whisker.story")

-- Initialize i18n
local i18n = I18n.new():init({
  defaultLocale = "en",
  fallbackLocale = "en",
  autoDetect = true
})

-- Load all translations
i18n:load("en", "locales/en.yml")
i18n:load("es", "locales/es.yml")
i18n:load("ru", "locales/ru.yml")

-- Show language selector
print("Select language:")
print("1. English")
print("2. Español")
print("3. Русский")

local choice = io.read()
local locales = { "en", "es", "ru" }
i18n:setLocale(locales[tonumber(choice)] or "en")

-- Create and run story
local story = Story.new({ i18n = i18n })
story:load("story.whisker")
story:run()
```

## Plural Rules Comparison

### English (1 item, 5 items)

| Count | Form | Output |
|-------|------|--------|
| 0 | other | "0 items" |
| 1 | one | "1 item" |
| 2 | other | "2 items" |
| 100 | other | "100 items" |

### Russian (1 предмет, 2 предмета, 5 предметов)

| Count | Form | Output |
|-------|------|--------|
| 0 | many | "0 предметов" |
| 1 | one | "1 предмет" |
| 2 | few | "2 предмета" |
| 5 | many | "5 предметов" |
| 21 | one | "21 предмет" |
| 22 | few | "22 предмета" |
| 25 | many | "25 предметов" |

## Key Patterns

### Multiple Variables

```yaml
shop:
  insufficient: "Sorry, you need {need} gold but only have {have}."
```

```whisker
@@t shop.insufficient have=gold need=cost
```

### Plurals with Extra Variables

```yaml
shop:
  offer:
    one: "I have {count} potion for {price} gold."
    other: "I have {count} potions for {price} gold."
```

```whisker
@@p shop.offer count=item_count price=cost
```

### Zero Handling

```yaml
inventory:
  remaining:
    zero: "You have no items left."
    one: "You have {count} item remaining."
    other: "You have {count} items remaining."
```

### Dynamic Key Selection

```lua
-- Choose key based on game state
local key = player.is_vip and "shop.vip_greeting" or "shop.greeting"
local text = i18n:t(key, { name = player.name })
```

## Testing Plurals

```lua
-- Test all forms
local counts = {0, 1, 2, 3, 4, 5, 11, 21, 22, 25, 100}

for _, locale in ipairs({"en", "es", "ru"}) do
  i18n:setLocale(locale)
  print("=== " .. locale .. " ===")
  for _, n in ipairs(counts) do
    print(n .. ": " .. i18n:p("inventory.items", n))
  end
end
```

## Next Steps

- See [RTL Languages](rtl-languages.md) for Arabic/Hebrew support
- See [Multi-Locale Project](multi-locale-project.md) for full project setup
- Read [Best Practices](../best-practices.md) for more patterns
