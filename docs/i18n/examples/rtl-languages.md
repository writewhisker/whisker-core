# RTL Languages Example

Demonstrates right-to-left language support for Arabic, Hebrew, and other RTL languages.

## RTL Languages

The following languages are automatically detected as RTL:

| Language | Code | Script |
|----------|------|--------|
| Arabic | ar | العربية |
| Hebrew | he | עברית |
| Persian (Farsi) | fa | فارسی |
| Urdu | ur | اردو |
| Yiddish | yi | ייִדיש |
| Pashto | ps | پښتو |
| Dari | prs | دری |
| Kurdish (Sorani) | ckb | کوردی |
| Sindhi | sd | سنڌي |
| Uyghur | ug | ئۇيغۇرچە |

## Project Structure

```
rtl-story/
  story.whisker
  locales/
    en.yml
    ar.yml
    he.yml
  main.lua
```

## Translation Files

### locales/en.yml

```yaml
title: "The Quest"

intro:
  welcome: "Welcome to {game_title}!"
  begin: "Your journey begins in the ancient city of {city}."

character:
  name: "Hero"
  greeting: "Greetings, traveler!"

items:
  gold:
    one: "{count} gold coin"
    other: "{count} gold coins"
  sword: "Enchanted Sword"

dialogue:
  merchant:
    greeting: "Welcome to my shop, {name}!"
    offer: "I have {item} for sale."
    price: "Price: {amount} gold"

directions:
  north: "North"
  south: "South"
  east: "East"
  west: "West"

ui:
  continue: "Press ENTER to continue"
  choices: "Your choices:"
```

### locales/ar.yml

Arabic translation with RTL text.

```yaml
title: "المهمة"

intro:
  welcome: "مرحبا بك في {game_title}!"
  begin: "تبدأ رحلتك في مدينة {city} القديمة."

character:
  name: "البطل"
  greeting: "تحياتي أيها المسافر!"

items:
  gold:
    zero: "لا توجد عملات ذهبية"
    one: "عملة ذهبية واحدة"
    two: "عملتان ذهبيتان"
    few: "{count} عملات ذهبية"
    many: "{count} عملة ذهبية"
    other: "{count} عملة ذهبية"
  sword: "السيف المسحور"

dialogue:
  merchant:
    greeting: "مرحبا بك في متجري يا {name}!"
    offer: "لدي {item} للبيع."
    price: "السعر: {amount} ذهب"

directions:
  north: "شمال"
  south: "جنوب"
  east: "شرق"
  west: "غرب"

ui:
  continue: "اضغط ENTER للمتابعة"
  choices: "خياراتك:"
```

### locales/he.yml

Hebrew translation with RTL text.

```yaml
title: "המסע"

intro:
  welcome: "ברוכים הבאים ל{game_title}!"
  begin: "המסע שלך מתחיל בעיר העתיקה {city}."

character:
  name: "גיבור"
  greeting: "שלום לך, נוסע!"

items:
  gold:
    one: "מטבע זהב {count}"
    two: "{count} מטבעות זהב"
    other: "{count} מטבעות זהב"
  sword: "חרב קסומה"

dialogue:
  merchant:
    greeting: "ברוך הבא לחנות שלי, {name}!"
    offer: "יש לי {item} למכירה."
    price: "מחיר: {amount} זהב"

directions:
  north: "צפון"
  south: "דרום"
  east: "מזרח"
  west: "מערב"

ui:
  continue: "לחץ ENTER להמשך"
  choices: "הבחירות שלך:"
```

## Game Code with RTL Support

### main.lua

```lua
local I18n = require("whisker.i18n")
local BiDi = require("whisker.i18n.bidi")

-- Initialize i18n
local i18n = I18n.new():init({
  defaultLocale = "en",
  autoDetect = true
})

-- Load translations
i18n:load("en", "locales/en.yml")
i18n:load("ar", "locales/ar.yml")
i18n:load("he", "locales/he.yml")

-- UI helper for RTL-aware output
function printText(text)
  -- For console, we just print
  -- Real UI would apply CSS direction or layout
  print(text)
end

function printWithDirection(text, forceDir)
  local dir = forceDir or i18n:getTextDirection()
  if dir == "rtl" then
    text = i18n:wrapBidi(text)
  end
  printText(text)
end

-- Apply direction to UI
function setupUI()
  local dir = i18n:getTextDirection()
  print("UI Direction: " .. dir)

  -- In a real game, you would:
  -- - Set CSS direction: rtl
  -- - Mirror UI layout
  -- - Adjust text alignment
end

-- Handle mixed content
function formatMixedContent()
  local locale = i18n:getLocale()

  -- English brand name in Arabic text
  if locale == "ar" then
    local gameTitle = BiDi.isolate("Whisker Quest", "ltr")
    return i18n:t("intro.welcome", { game_title = gameTitle })
  else
    return i18n:t("intro.welcome", { game_title = "Whisker Quest" })
  end
end

-- Language selection
print("Select language / בחר שפה / اختر اللغة:")
print("1. English")
print("2. العربية (Arabic)")
print("3. עברית (Hebrew)")

local choice = io.read()
local locales = { "en", "ar", "he" }
i18n:setLocale(locales[tonumber(choice)] or "en")

-- Setup UI direction
setupUI()

-- Show content
print("")
print(formatMixedContent())
print("")

-- Show direction info
print("Text direction: " .. i18n:getTextDirection())
print("Is RTL: " .. tostring(i18n:isRTL()))
print("HTML dir: " .. BiDi.htmlDir(i18n:getLocale()))
```

## BiDi Utilities

### Wrapping RTL Text

```lua
local BiDi = require("whisker.i18n.bidi")

-- Wrap RTL text with embeddings
local arabicText = "مرحبا"
local wrapped = BiDi.wrap(arabicText, "rtl")
-- Result: "\u{202B}مرحبا\u{202C}"
```

### Isolating LTR in RTL

```lua
-- English name in Arabic sentence
local englishName = BiDi.isolate("Alice", "ltr")
local sentence = i18n:t("greeting", { name = englishName })
-- Prevents the English text from affecting surrounding RTL flow
```

### Directional Marks

```lua
-- Get mark character
local ltrMark = BiDi.mark("ltr")  -- U+200E LRM
local rtlMark = BiDi.mark("rtl")  -- U+200F RLM

-- Use to force direction
local number = "123"
local rtlNumber = rtlMark .. number .. rtlMark
```

### Detecting Direction from Text

```lua
-- Auto-detect from content
local dir1 = BiDi.detectFromText("Hello world")    -- "ltr"
local dir2 = BiDi.detectFromText("مرحبا")           -- "rtl"
local dir3 = BiDi.detectFromText("123")            -- "neutral"
```

## HTML/Web Integration

```lua
-- Get HTML attribute value
local htmlDir = BiDi.htmlDir(i18n:getLocale())

-- Generate HTML
local html = string.format([[
<html dir="%s" lang="%s">
  <body>
    <p>%s</p>
  </body>
</html>
]], htmlDir, i18n:getLocale(), i18n:t("intro.welcome", { game_title = "Game" }))
```

```html
<!-- For Arabic -->
<html dir="rtl" lang="ar">
  <body>
    <p>مرحبا بك في Game!</p>
  </body>
</html>
```

## CSS for RTL

```css
/* Base styles */
body {
  direction: ltr;
  text-align: left;
}

/* RTL override */
body[dir="rtl"] {
  direction: rtl;
  text-align: right;
}

/* Flip layouts */
body[dir="rtl"] .sidebar {
  left: auto;
  right: 0;
}

/* Bidirectional safe */
.bidi-isolate {
  unicode-bidi: isolate;
}
```

## Testing RTL

### Checklist

- [ ] Text flows right-to-left
- [ ] Numbers appear correctly (usually LTR within RTL)
- [ ] English words/names don't break layout
- [ ] UI elements mirror appropriately
- [ ] Punctuation at correct end of sentences
- [ ] Mixed content (LTR in RTL) renders correctly

### Test Cases

```lua
-- Test with various inputs
local tests = {
  { "Pure Arabic", "مرحبا بالعالم" },
  { "With numbers", "لديك 5 رسائل" },
  { "With English", "مرحبا Alice" },
  { "Mixed heavy", "Go to مكتبة then Café" },
}

i18n:setLocale("ar")
for _, test in ipairs(tests) do
  print(test[1] .. ": " .. i18n:wrapBidi(test[2]))
end
```

## Common Issues

### Numbers Reversed

**Problem:** "You have 123 coins" appears as "snioc 321 evah uoY"

**Solution:** Numbers are inherently weak directional. The BiDi algorithm usually handles them, but you can force:

```lua
local amount = BiDi.isolate(tostring(123), "ltr")
```

### Brand Names Broken

**Problem:** "Welcome to Whisker Quest!" becomes garbled in Arabic.

**Solution:** Isolate LTR content:

```lua
local brand = BiDi.isolate("Whisker Quest", "ltr")
i18n:t("welcome", { game = brand })
```

### Punctuation Placement

**Problem:** Exclamation mark at wrong end.

**Solution:** Usually handled by BiDi algorithm. If not, the translation may need adjustment:

```yaml
# Ensure punctuation is correctly placed in translation
ar:
  greeting: "!مرحبا"  # Note: appears at "end" in RTL
```

## Next Steps

- See [Multi-Locale Project](multi-locale-project.md) for full setup
- Read [Troubleshooting](../troubleshooting.md) for more RTL issues
- Check [Best Practices](../best-practices.md) for RTL guidelines
