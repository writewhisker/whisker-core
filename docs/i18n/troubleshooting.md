# i18n Troubleshooting

Solutions to common i18n issues.

## Missing Translations

### Problem: "[MISSING: key]" appears in output

**Cause:** Translation key not found in current locale.

**Solutions:**

1. Check if key exists in translation file:
   ```bash
   grep "key_name" locales/en.yml
   ```

2. Check for typos in key name:
   ```whisker
   # Wrong
   @@t greeeting   # Extra 'e'

   # Correct
   @@t greeting
   ```

3. Ensure locale is loaded:
   ```lua
   i18n:load("en", "locales/en.yml")
   ```

4. Check fallback is configured:
   ```lua
   i18n:init({
     defaultLocale = "en",
     fallbackLocale = "en"
   })
   ```

### Problem: Translation exists but not found

**Cause:** Key path doesn't match.

**Solutions:**

1. Use dot notation correctly:
   ```yaml
   # Translation file
   dialogue:
     npc:
       greeting: "Hello!"
   ```
   ```whisker
   # Correct
   @@t dialogue.npc.greeting

   # Wrong
   @@t dialogue_npc_greeting
   ```

2. Check indentation in YAML:
   ```yaml
   # Wrong - inconsistent indent
   dialogue:
       npc:     # 4 spaces
     greeting:  # 2 spaces

   # Correct - consistent 2-space indent
   dialogue:
     npc:
       greeting: "Hello!"
   ```

## Variable Issues

### Problem: "{name}" appears literally in output

**Cause:** Variable not passed or wrong name.

**Solutions:**

1. Pass variable in translation call:
   ```lua
   -- Wrong
   i18n:t("welcome")

   -- Correct
   i18n:t("welcome", { name = "Alice" })
   ```

2. Match variable names exactly:
   ```yaml
   welcome: "Hello, {name}!"
   ```
   ```lua
   -- Wrong
   i18n:t("welcome", { nombre = "Alice" })

   -- Correct
   i18n:t("welcome", { name = "Alice" })
   ```

### Problem: Variable value is nil

**Cause:** Variable expression evaluates to nil.

**Solution:**
```lua
-- Check value before passing
local playerName = player and player.name or "Unknown"
i18n:t("welcome", { name = playerName })
```

## Plural Issues

### Problem: Wrong plural form used

**Cause:** Incorrect plural rule or missing form.

**Solutions:**

1. Check you have all required forms:
   ```yaml
   # English needs: one, other
   items:
     count:
       one: "{count} item"
       other: "{count} items"

   # Russian needs: one, few, many, other
   items:
     count:
       one: "{count} предмет"
       few: "{count} предмета"
       many: "{count} предметов"
       other: "{count} предметов"
   ```

2. Always include `other` as fallback:
   ```yaml
   items:
     count:
       one: "{count} item"
       other: "{count} items"  # Required!
   ```

3. Use `:p()` not `:t()` for plurals:
   ```lua
   -- Wrong
   i18n:t("items.count", { count = 5 })

   -- Correct
   i18n:p("items.count", 5)
   ```

### Problem: Zero not handled

**Cause:** Missing zero form or language doesn't use zero.

**Solution:**
```yaml
# For languages with zero form (Arabic)
items:
  count:
    zero: "No items"
    one: "One item"
    other: "{count} items"

# For other languages, zero uses "other"
# You can handle specially in code:
if count == 0 then
  text = i18n:t("items.none")
else
  text = i18n:p("items.count", count)
end
```

## YAML Syntax Errors

### Problem: YAML parsing fails

**Common causes and fixes:**

1. **Unquoted colons:**
   ```yaml
   # Wrong
   message: Error: Something failed

   # Correct
   message: "Error: Something failed"
   ```

2. **Tabs instead of spaces:**
   ```yaml
   # Wrong (using tabs)
   parent:
   	child: value

   # Correct (using spaces)
   parent:
     child: value
   ```

3. **Inconsistent indentation:**
   ```yaml
   # Wrong
   parent:
       child1: value    # 4 spaces
     child2: value      # 2 spaces

   # Correct
   parent:
     child1: value
     child2: value
   ```

4. **Special characters unquoted:**
   ```yaml
   # Wrong
   message: Yes/No?

   # Correct
   message: "Yes/No?"
   ```

5. **Invalid multiline:**
   ```yaml
   # Wrong
   message: This is
   a long message

   # Correct (literal block)
   message: |
     This is
     a long message

   # Or single line
   message: "This is a long message"
   ```

## RTL Issues

### Problem: Text direction wrong

**Solutions:**

1. Check locale is RTL:
   ```lua
   print(i18n:getTextDirection("ar"))  -- Should be "rtl"
   ```

2. Apply direction to UI:
   ```lua
   if i18n:isRTL() then
     setUIDirection("rtl")
   end
   ```

### Problem: Mixed LTR/RTL text garbled

**Cause:** BiDi algorithm confusion.

**Solution:** Isolate foreign text:
```lua
local BiDi = require("whisker.i18n.bidi")

-- Isolate English brand name in Arabic text
local brand = BiDi.isolate("Whisker Quest", "ltr")
local message = i18n:t("welcome_game", { game = brand })
```

### Problem: Numbers appear reversed

**Cause:** RTL affects number display.

**Solution:**
```lua
-- Numbers should be LTR even in RTL context
local BiDi = require("whisker.i18n.bidi")
local price = BiDi.isolate(tostring(amount), "ltr")
```

## Locale Detection Issues

### Problem: Wrong locale detected

**Solutions:**

1. Explicitly set locale:
   ```lua
   i18n:setLocale("en")  -- Override detection
   ```

2. Check detection order:
   ```lua
   -- Detection tries: env vars, system calls
   local detected = Locale.detect()
   print("Detected: " .. detected)
   ```

3. Disable auto-detection:
   ```lua
   i18n:init({
     autoDetect = false,
     defaultLocale = "en"
   })
   ```

### Problem: Locale not matched

**Cause:** Exact locale not available.

**Solution:** Fallback chain handles this:
```lua
-- User has "en-GB", you only have "en"
-- System will match "en-GB" → "en"

-- Check what's available
print(table.concat(i18n:getAvailableLocales(), ", "))
```

## File Loading Issues

### Problem: Translation file not found

**Solutions:**

1. Check file path is correct:
   ```lua
   -- Relative to working directory
   i18n:load("en", "locales/en.yml")

   -- Or absolute path
   i18n:load("en", "/path/to/locales/en.yml")
   ```

2. Check file extension:
   ```lua
   i18n:load("en", "locales/en.yml")   -- YAML
   i18n:load("en", "locales/en.json")  -- JSON
   i18n:load("en", "locales/en.lua")   -- Lua
   ```

### Problem: File loads but data empty

**Cause:** Parser error or wrong format.

**Solutions:**

1. Validate YAML syntax online
2. Check file encoding is UTF-8
3. Try loading manually:
   ```lua
   local YAML = require("whisker.i18n.formats.yaml")
   local content = io.open("locales/en.yml"):read("*a")
   local data, err = pcall(YAML.parse, content)
   if not data then print("Error: " .. err) end
   ```

## Performance Issues

### Problem: Slow loading

**Solutions:**

1. Use compiled Lua format:
   ```bash
   whisker-i18n compile locales/en.yml build/en.lua
   ```

2. Load only needed locales:
   ```lua
   -- Don't load all at startup
   i18n:load(userLocale, "locales/" .. userLocale .. ".lua")
   ```

3. Use lazy loading:
   ```lua
   function getI18n()
     if not _i18n then
       _i18n = require("whisker.i18n").new():init({...})
     end
     return _i18n
   end
   ```

### Problem: Slow lookups

**Cause:** Unusual; system uses O(1) lookups.

**Solutions:**

1. Check for extremely deep nesting (>5 levels)
2. Ensure using latest version
3. Profile to confirm i18n is the bottleneck

## Validation Errors

### Problem: "missing_key" error

**Cause:** Key in base not in target.

**Solution:**
```bash
whisker-i18n validate locales/en.yml locales/es.yml
```

Add missing keys to target translation.

### Problem: "missing_variable" error

**Cause:** Variable in base not in target.

**Solution:**
```yaml
# Base (en.yml)
welcome: "Hello, {name}!"

# Wrong (es.yml) - missing {name}
welcome: "¡Hola!"

# Correct (es.yml)
welcome: "¡Hola, {name}!"
```

### Problem: "unused_key" warning

**Cause:** Key in target not in base.

**Solution:** Either:
1. Remove unused key from target
2. Add key to base if it should exist

## Getting More Help

1. Check the [API Reference](api-reference.md) for method details
2. Review [Best Practices](best-practices.md) for patterns
3. Look at [Examples](examples/) for working code
4. File an issue on GitHub with:
   - Lua version
   - whisker-core version
   - Minimal reproduction code
   - Expected vs actual behavior
