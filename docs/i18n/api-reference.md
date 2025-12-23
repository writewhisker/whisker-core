# i18n API Reference

Complete reference for whisker-core's internationalization API.

## Modules

- [I18n](#i18n) - Main i18n interface
- [StringTable](#stringtable) - Translation storage
- [Locale](#locale) - Locale detection and management
- [Pluralization](#pluralization) - Plural form selection
- [BiDi](#bidi) - Bidirectional text utilities
- [Formats](#formats) - Translation file loaders
- [Tools](#tools) - Workflow tools

---

## I18n

Main entry point for i18n functionality.

```lua
local I18n = require("whisker.i18n")
local i18n = I18n.new()
```

### I18n.new()

Create a new I18n instance.

**Returns:** I18n instance

**Example:**
```lua
local i18n = I18n.new()
```

### I18n:init(config)

Initialize the i18n system.

**Parameters:**
- `config` (table): Configuration options
  - `defaultLocale` (string): Default language (e.g., "en")
  - `fallbackLocale` (string): Fallback when translation missing
  - `loadPath` (string): Path template for translation files
  - `autoDetect` (boolean): Auto-detect user locale (default: true)
  - `logMissing` (boolean): Log missing translations (default: false)

**Returns:** self (for chaining)

**Example:**
```lua
local i18n = I18n.new():init({
  defaultLocale = "en",
  autoDetect = true
})
```

### I18n:load(locale, filepath)

Load translation file for a locale.

**Parameters:**
- `locale` (string): Locale code (e.g., "en", "es-MX")
- `filepath` (string): Path to translation file (.yml, .json, .lua)

**Returns:** boolean (success)

**Example:**
```lua
i18n:load("en", "locales/en.yml")
i18n:load("es", "locales/es.json")
```

### I18n:loadData(locale, data)

Load translation data from table.

**Parameters:**
- `locale` (string): Locale code
- `data` (table): Translation data (hierarchical)

**Returns:** boolean (success)

**Example:**
```lua
i18n:loadData("en", {
  greeting = "Hello!",
  items = { sword = "a sword" }
})
```

### I18n:t(key, vars?, locale?)

Translate a key.

**Parameters:**
- `key` (string): Translation key (e.g., "items.sword")
- `vars` (table, optional): Variables for interpolation
- `locale` (string, optional): Override current locale

**Returns:** (string) Translated text or "[MISSING: key]"

**Example:**
```lua
i18n:t("greeting")
-- "Hello!"

i18n:t("welcome", { name = "Alice" })
-- "Welcome, Alice!"

i18n:t("greeting", {}, "es")
-- "¡Hola!" (override to Spanish)
```

### I18n:p(key, count, vars?, locale?)

Pluralize a translation.

**Parameters:**
- `key` (string): Base translation key
- `count` (number): Count for plural form selection
- `vars` (table, optional): Additional variables
- `locale` (string, optional): Override current locale

**Returns:** (string) Pluralized and translated text

**Example:**
```lua
i18n:p("items.count", 1)
-- "1 item"

i18n:p("items.count", 5)
-- "5 items"

i18n:p("items.count", 2, {}, "ru")
-- "2 предмета" (Russian few form)
```

### I18n:has(key, locale?)

Check if translation exists.

**Parameters:**
- `key` (string): Translation key
- `locale` (string, optional): Check specific locale

**Returns:** (boolean) true if exists

**Example:**
```lua
if i18n:has("optional.message") then
  print(i18n:t("optional.message"))
end
```

### I18n:setLocale(locale)

Change current locale.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (boolean) Success

**Example:**
```lua
i18n:setLocale("es")
-- All subsequent i18n:t() calls use Spanish
```

### I18n:getLocale()

Get current locale.

**Returns:** (string) Current locale code

**Example:**
```lua
local current = i18n:getLocale()
print("Current language: " .. current)
```

### I18n:getAvailableLocales()

Get list of loaded locales.

**Returns:** (table) Array of locale codes

**Example:**
```lua
local locales = i18n:getAvailableLocales()
for _, locale in ipairs(locales) do
  print("Available: " .. locale)
end
```

### I18n:getTextDirection(locale?)

Get text direction for locale.

**Parameters:**
- `locale` (string, optional): Locale to check (default: current)

**Returns:** (string) "rtl" or "ltr"

**Example:**
```lua
if i18n:getTextDirection() == "rtl" then
  -- Apply RTL layout
end
```

### I18n:isRTL(locale?)

Check if locale is right-to-left.

**Parameters:**
- `locale` (string, optional): Locale to check

**Returns:** (boolean) true if RTL

**Example:**
```lua
if i18n:isRTL("ar") then
  print("Arabic is RTL")
end
```

### I18n:wrapBidi(text, locale?)

Wrap text with BiDi control characters.

**Parameters:**
- `text` (string): Text to wrap
- `locale` (string, optional): Locale for direction

**Returns:** (string) Wrapped text (only for RTL locales)

**Example:**
```lua
local wrapped = i18n:wrapBidi("مرحبا")
```

---

## StringTable

Storage for translation key-value pairs.

```lua
local StringTable = require("whisker.i18n.string_table")
local table = StringTable.new()
```

### StringTable.new()

Create a new StringTable.

**Returns:** StringTable instance

### StringTable:set(key, value)

Set a translation.

**Parameters:**
- `key` (string): Dot-separated key (e.g., "items.sword")
- `value` (string|table): Translation or nested table

### StringTable:get(key)

Get a translation.

**Parameters:**
- `key` (string): Dot-separated key

**Returns:** (string|table|nil) Translation value

### StringTable:has(key)

Check if key exists.

**Parameters:**
- `key` (string): Translation key

**Returns:** (boolean)

### StringTable:loadData(data)

Load hierarchical data.

**Parameters:**
- `data` (table): Nested translation data

### StringTable:flatten()

Get flattened key-value map.

**Returns:** (table) Flat key-value pairs

### StringTable:keys()

Get all keys.

**Returns:** (table) Array of keys

---

## Locale

Locale detection and management.

```lua
local Locale = require("whisker.i18n.locale")
```

### Locale.detect()

Detect system locale.

**Returns:** (string) Detected locale code or "en"

**Example:**
```lua
local userLocale = Locale.detect()
```

### Locale.normalize(locale)

Normalize locale code to BCP 47 format.

**Parameters:**
- `locale` (string): Raw locale (e.g., "en_US", "EN-us")

**Returns:** (string) Normalized locale (e.g., "en-US")

### Locale.parse(locale)

Parse locale into components.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (table) `{ language, script, region }`

**Example:**
```lua
local parts = Locale.parse("zh-Hant-TW")
-- { language = "zh", script = "Hant", region = "TW" }
```

### Locale.match(requested, available)

Find best matching locale.

**Parameters:**
- `requested` (string): Requested locale
- `available` (table): Array of available locales

**Returns:** (string|nil) Best match

**Example:**
```lua
local match = Locale.match("en-US", {"en", "es", "fr"})
-- "en"
```

### Locale.getFallbackChain(locale)

Get fallback chain for locale.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (table) Fallback chain

**Example:**
```lua
local chain = Locale.getFallbackChain("zh-Hant-TW")
-- {"zh-Hant-TW", "zh-Hant", "zh"}
```

---

## Pluralization

Plural form selection.

```lua
local Pluralization = require("whisker.i18n.pluralization")
```

### Pluralization.getCategory(count, locale)

Get plural category for count.

**Parameters:**
- `count` (number): The count
- `locale` (string): Locale code

**Returns:** (string) Category: "zero", "one", "two", "few", "many", "other"

**Example:**
```lua
Pluralization.getCategory(1, "en")   -- "one"
Pluralization.getCategory(5, "en")   -- "other"
Pluralization.getCategory(2, "ru")   -- "few"
Pluralization.getCategory(5, "ru")   -- "many"
Pluralization.getCategory(0, "ar")   -- "zero"
```

### Pluralization.getCategories(locale)

Get required categories for locale.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (table) Array of category names

**Example:**
```lua
Pluralization.getCategories("en")
-- {"one", "other"}

Pluralization.getCategories("ru")
-- {"one", "few", "many", "other"}

Pluralization.getCategories("ar")
-- {"zero", "one", "two", "few", "many", "other"}
```

### Pluralization.hasRule(locale)

Check if pluralization rule exists.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (boolean)

---

## BiDi

Bidirectional text utilities.

```lua
local BiDi = require("whisker.i18n.bidi")
```

### BiDi.getDirection(locale)

Get text direction for locale.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (string) "rtl" or "ltr"

**Example:**
```lua
BiDi.getDirection("en")  -- "ltr"
BiDi.getDirection("ar")  -- "rtl"
BiDi.getDirection("he")  -- "rtl"
```

### BiDi.isRTL(locale)

Check if locale is RTL.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (boolean)

### BiDi.isLTR(locale)

Check if locale is LTR.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (boolean)

### BiDi.wrap(text, direction)

Wrap text with directional embedding.

**Parameters:**
- `text` (string): Text to wrap
- `direction` (string): "rtl" or "ltr"

**Returns:** (string) Wrapped text

**Example:**
```lua
BiDi.wrap("مرحبا", "rtl")
-- "\u{202B}مرحبا\u{202C}"
```

### BiDi.isolate(text, direction)

Isolate text with directional isolation.

**Parameters:**
- `text` (string): Text to isolate
- `direction` (string): "rtl" or "ltr"

**Returns:** (string) Isolated text

**Example:**
```lua
BiDi.isolate("Alice", "ltr")
-- "\u{2066}Alice\u{2069}"
```

### BiDi.mark(direction)

Get directional mark character.

**Parameters:**
- `direction` (string): "rtl" or "ltr"

**Returns:** (string) LRM or RLM character

### BiDi.htmlDir(locale)

Get HTML dir attribute value.

**Parameters:**
- `locale` (string): Locale code

**Returns:** (string) "rtl" or "ltr"

### BiDi.detectFromText(text)

Detect direction from text content.

**Parameters:**
- `text` (string): Text to analyze

**Returns:** (string) "rtl", "ltr", or "neutral"

---

## Formats

Translation file loaders.

### YAML Loader

```lua
local YAML = require("whisker.i18n.formats.yaml")

local data = YAML.parse(yamlString)
local yaml = YAML.stringify(data)
```

### JSON Loader

```lua
local JSON = require("whisker.i18n.formats.json")

local data = JSON.parse(jsonString)
local json = JSON.stringify(data)
```

### Lua Loader

```lua
local LuaFormat = require("whisker.i18n.formats.lua")

local data = LuaFormat.load(filepath)
local lua = LuaFormat.stringify(data)
```

---

## Tools

Workflow tools for translation management.

### Extract

```lua
local Extract = require("whisker.i18n.tools.extract")
```

#### Extract.fromString(content, filename)

Extract i18n keys from source.

**Parameters:**
- `content` (string): Source content
- `filename` (string): Source filename

**Returns:** (table) Array of key objects

**Example:**
```lua
local keys = Extract.fromString("@@t greeting\n@@p items count=n", "story.whisker")
-- {{key="greeting", type="translate", line=1}, {key="items", type="plural", line=2}}
```

#### Extract.toYAML(keys)

Generate YAML template.

**Parameters:**
- `keys` (table): Extracted keys

**Returns:** (string) YAML template

#### Extract.toJSON(keys)

Generate JSON template.

**Parameters:**
- `keys` (table): Extracted keys

**Returns:** (string) JSON template

### Validate

```lua
local Validate = require("whisker.i18n.tools.validate")
```

#### Validate.compare(baseData, targetData)

Compare translations.

**Parameters:**
- `baseData` (table): Base translation data
- `targetData` (table): Target translation data

**Returns:** (table) Array of issues

#### Validate.report(issues)

Generate validation report.

**Parameters:**
- `issues` (table): Issues from compare()

**Returns:** (string) Report text

### Status

```lua
local Status = require("whisker.i18n.tools.status")
```

#### Status.getLocaleStatus(baseData, targetData, locale)

Get status for locale.

**Parameters:**
- `baseData` (table): Base translation data
- `targetData` (table): Target translation data
- `locale` (string): Locale code

**Returns:** (table) Status object

#### Status.report(baseLocale, localesData)

Generate status report.

**Parameters:**
- `baseLocale` (string): Base locale code
- `localesData` (table): Map of locale to data

**Returns:** (string) Report text
