-- tests/unit/i18n/init_spec.lua
-- Unit tests for i18n core module (Stage 1)

describe("I18n", function()
  local I18n
  local mock_event_bus
  local mock_logger

  -- Mock event bus
  local function create_mock_event_bus()
    local events = {}
    return {
      emit = function(self, event, data)
        events[event] = events[event] or {}
        table.insert(events[event], data)
      end,
      on = function(self, event, callback)
        events[event] = events[event] or {}
        table.insert(events[event], { callback = callback })
      end,
      off = function(self, event, callback)
      end,
      getEmitted = function(self, event)
        return events[event] or {}
      end
    }
  end

  -- Mock logger
  local function create_mock_logger()
    local logs = {}
    return {
      warn = function(self, msg, ...)
        table.insert(logs, { level = "warn", message = string.format(msg, ...) })
      end,
      error = function(self, msg, ...)
        table.insert(logs, { level = "error", message = string.format(msg, ...) })
      end,
      info = function(self, msg, ...)
        table.insert(logs, { level = "info", message = string.format(msg, ...) })
      end,
      getLogs = function(self)
        return logs
      end
    }
  end

  before_each(function()
    -- Clear package cache to ensure fresh module
    package.loaded["whisker.i18n"] = nil
    package.loaded["whisker.i18n.init"] = nil

    I18n = require("whisker.i18n")
    mock_event_bus = create_mock_event_bus()
    mock_logger = create_mock_logger()
  end)

  describe("new()", function()
    it("creates a new I18n instance", function()
      local i18n = I18n.new()
      assert.is_not_nil(i18n)
    end)

    it("accepts dependencies", function()
      local i18n = I18n.new({
        event_bus = mock_event_bus,
        logger = mock_logger
      })
      assert.equals(mock_event_bus, i18n.events)
      assert.equals(mock_logger, i18n.log)
    end)

    it("initializes with default configuration", function()
      local i18n = I18n.new()
      assert.equals("en", i18n.config.defaultLocale)
      assert.is_nil(i18n.config.fallbackLocale)
      assert.equals("locales/{locale}.yml", i18n.config.loadPath)
      assert.is_true(i18n.config.autoDetect)
      assert.is_true(i18n.config.logMissing)
      assert.is_false(i18n.config.strictMode)
    end)

    it("initializes empty string tables", function()
      local i18n = I18n.new()
      assert.same({}, i18n.stringTable)
      assert.same({}, i18n.flatIndex)
      assert.same({}, i18n.missingKeys)
    end)
  end)

  describe("init()", function()
    it("accepts configuration options", function()
      local i18n = I18n.new()
      i18n:init({
        defaultLocale = "es",
        fallbackLocale = "en",
        logMissing = false,
        strictMode = true
      })

      assert.equals("es", i18n.config.defaultLocale)
      assert.equals("en", i18n.config.fallbackLocale)
      assert.is_false(i18n.config.logMissing)
      assert.is_true(i18n.config.strictMode)
    end)

    it("sets initialized flag", function()
      local i18n = I18n.new()
      assert.is_false(i18n:isInitialized())
      i18n:init()
      assert.is_true(i18n:isInitialized())
    end)

    it("emits initialized event", function()
      local i18n = I18n.new({ event_bus = mock_event_bus })
      i18n:init({ defaultLocale = "en" })

      local emitted = mock_event_bus:getEmitted("i18n:initialized")
      assert.equals(1, #emitted)
      assert.equals("en", emitted[1].locale)
    end)

    it("returns self for chaining", function()
      local i18n = I18n.new()
      local result = i18n:init()
      assert.equals(i18n, result)
    end)

    it("accepts custom missing translation handler", function()
      local handler_called = false
      local i18n = I18n.new()
      i18n:init({
        onMissingTranslation = function(locale, key, vars)
          handler_called = true
          return "custom: " .. key
        end
      })
      i18n:loadData("en", { greeting = "Hello" })
      local result = i18n:t("missing_key")
      assert.is_true(handler_called)
      assert.equals("custom: missing_key", result)
    end)
  end)

  describe("loadData()", function()
    it("loads hierarchical translation data", function()
      local i18n = I18n.new():init()
      i18n:loadData("en", {
        greeting = "Hello",
        farewell = "Goodbye"
      })

      assert.is_not_nil(i18n.stringTable.en)
      assert.equals("Hello", i18n.stringTable.en.greeting)
    end)

    it("flattens nested data to dot notation", function()
      local i18n = I18n.new():init()
      i18n:loadData("en", {
        items = {
          sword = "a sword",
          shield = "a shield"
        }
      })

      assert.equals("a sword", i18n.flatIndex.en["items.sword"])
      assert.equals("a shield", i18n.flatIndex.en["items.shield"])
    end)

    it("handles deeply nested data", function()
      local i18n = I18n.new():init()
      i18n:loadData("en", {
        level1 = {
          level2 = {
            level3 = {
              key = "deep value"
            }
          }
        }
      })

      assert.equals("deep value", i18n.flatIndex.en["level1.level2.level3.key"])
    end)

    it("emits loaded event with key count", function()
      local i18n = I18n.new({ event_bus = mock_event_bus }):init()
      i18n:loadData("en", {
        key1 = "value1",
        key2 = "value2"
      })

      local emitted = mock_event_bus:getEmitted("i18n:loaded")
      assert.equals(1, #emitted)
      assert.equals("en", emitted[1].locale)
      assert.equals(2, emitted[1].keyCount)
    end)

    it("requires locale parameter", function()
      local i18n = I18n.new():init()
      assert.has_error(function()
        i18n:loadData(nil, {})
      end, "I18n:loadData() requires locale parameter")
    end)

    it("requires data to be a table", function()
      local i18n = I18n.new():init()
      assert.has_error(function()
        i18n:loadData("en", "not a table")
      end, "I18n:loadData() requires data to be a table")
    end)
  end)

  describe("t() - translation", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init({ defaultLocale = "en" })
      i18n:loadData("en", {
        greeting = "Hello!",
        welcome = "Welcome, {name}!",
        items = {
          sword = "a rusty sword"
        }
      })
    end)

    it("translates simple keys", function()
      assert.equals("Hello!", i18n:t("greeting"))
    end)

    it("translates nested keys with dot notation", function()
      assert.equals("a rusty sword", i18n:t("items.sword"))
    end)

    it("interpolates variables", function()
      assert.equals("Welcome, Alice!", i18n:t("welcome", { name = "Alice" }))
    end)

    it("returns missing placeholder for unknown keys", function()
      local result = i18n:t("unknown_key")
      assert.equals("[MISSING: unknown_key]", result)
    end)

    it("allows locale override", function()
      i18n:loadData("es", { greeting = "¡Hola!" })
      assert.equals("¡Hola!", i18n:t("greeting", {}, "es"))
    end)

    it("uses current locale by default", function()
      i18n:loadData("es", { greeting = "¡Hola!" })
      i18n:setLocale("es")
      assert.equals("¡Hola!", i18n:t("greeting"))
    end)

    it("preserves placeholder when variable is missing", function()
      assert.equals("Welcome, {name}!", i18n:t("welcome", {}))
    end)

    it("returns empty string for nil key", function()
      assert.equals("", i18n:t(nil))
    end)
  end)

  describe("p() - pluralization", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init({ defaultLocale = "en" })
      i18n:loadData("en", {
        items = {
          count = {
            one = "{count} item",
            other = "{count} items"
          }
        }
      })
    end)

    it("selects singular form for count of 1", function()
      assert.equals("1 item", i18n:p("items.count", 1))
    end)

    it("selects plural form for count > 1", function()
      assert.equals("5 items", i18n:p("items.count", 5))
    end)

    it("selects plural form for count of 0", function()
      assert.equals("0 items", i18n:p("items.count", 0))
    end)

    it("includes additional variables", function()
      i18n:loadData("en", {
        found = {
          one = "Found {count} item in {location}",
          other = "Found {count} items in {location}"
        }
      })
      assert.equals("Found 3 items in dungeon", i18n:p("found", 3, { location = "dungeon" }))
    end)

    it("falls back to other when specific category not found", function()
      i18n:loadData("en", {
        messages = {
          other = "{count} messages"
        }
      })
      assert.equals("1 messages", i18n:p("messages", 1))
    end)
  end)

  describe("locale management", function()
    local i18n

    before_each(function()
      i18n = I18n.new({ event_bus = mock_event_bus }):init()
      i18n:loadData("en", { greeting = "Hello" })
      i18n:loadData("es", { greeting = "Hola" })
    end)

    it("setLocale() changes current locale", function()
      i18n:setLocale("es")
      assert.equals("es", i18n:getLocale())
    end)

    it("setLocale() emits localeChanged event", function()
      i18n:setLocale("es")
      local emitted = mock_event_bus:getEmitted("i18n:localeChanged")
      assert.equals(1, #emitted)
      assert.equals("en", emitted[1].from)
      assert.equals("es", emitted[1].to)
    end)

    it("getAvailableLocales() returns loaded locales", function()
      local locales = i18n:getAvailableLocales()
      assert.equals(2, #locales)
      assert.is_true(locales[1] == "en" or locales[2] == "en")
      assert.is_true(locales[1] == "es" or locales[2] == "es")
    end)

    it("hasLocale() returns true for loaded locales", function()
      assert.is_true(i18n:hasLocale("en"))
      assert.is_true(i18n:hasLocale("es"))
    end)

    it("hasLocale() returns false for unloaded locales", function()
      assert.is_false(i18n:hasLocale("fr"))
    end)
  end)

  describe("unload()", function()
    local i18n

    before_each(function()
      i18n = I18n.new({ event_bus = mock_event_bus }):init({ defaultLocale = "en" })
      i18n:loadData("en", { greeting = "Hello" })
      i18n:loadData("es", { greeting = "Hola" })
    end)

    it("removes locale data", function()
      i18n:unload("es")
      assert.is_false(i18n:hasLocale("es"))
      assert.is_nil(i18n.stringTable.es)
      assert.is_nil(i18n.flatIndex.es)
    end)

    it("emits unloaded event", function()
      i18n:unload("es")
      local emitted = mock_event_bus:getEmitted("i18n:unloaded")
      assert.equals(1, #emitted)
      assert.equals("es", emitted[1].locale)
    end)

    it("prevents unloading default locale", function()
      local result = i18n:unload("en")
      assert.is_false(result)
      assert.is_true(i18n:hasLocale("en"))
    end)
  end)

  describe("fallback chain", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init({
        defaultLocale = "en",
        fallbackLocale = "en"
      })
      i18n:loadData("en", {
        greeting = "Hello",
        english_only = "English only"
      })
      i18n:loadData("es", {
        greeting = "Hola"
      })
    end)

    it("falls back to base language", function()
      i18n:loadData("en", { greeting = "Hello" })
      -- en-US should fall back to en
      i18n:setLocale("en-US")
      assert.equals("Hello", i18n:t("greeting"))
    end)

    it("falls back to fallback locale", function()
      i18n:setLocale("es")
      -- es doesn't have english_only, should fall back to en
      assert.equals("English only", i18n:t("english_only"))
    end)

    it("falls back to default locale", function()
      i18n:loadData("fr", { greeting = "Bonjour" })
      i18n:setLocale("fr")
      -- fr doesn't have english_only, should fall back to en
      assert.equals("English only", i18n:t("english_only"))
    end)

    it("supports custom fallback chain", function()
      i18n:loadData("fr", { french_key = "Valeur française" })
      i18n:setFallbackChain({"de", "fr", "en"})
      i18n:setLocale("de")
      -- de not loaded, fr has french_key
      assert.equals("Valeur française", i18n:t("french_key"))
    end)
  end)

  describe("has()", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init()
      i18n:loadData("en", { greeting = "Hello" })
    end)

    it("returns true for existing keys", function()
      assert.is_true(i18n:has("greeting"))
    end)

    it("returns false for missing keys", function()
      assert.is_false(i18n:has("missing"))
    end)

    it("checks specific locale", function()
      i18n:loadData("es", { spanish_key = "valor" })
      assert.is_true(i18n:has("spanish_key", "es"))
      assert.is_false(i18n:has("spanish_key", "en"))
    end)
  end)

  describe("getTextDirection()", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init()
    end)

    it("returns ltr for English", function()
      assert.equals("ltr", i18n:getTextDirection("en"))
    end)

    it("returns rtl for Arabic", function()
      assert.equals("rtl", i18n:getTextDirection("ar"))
    end)

    it("returns rtl for Hebrew", function()
      assert.equals("rtl", i18n:getTextDirection("he"))
    end)

    it("returns rtl for Persian", function()
      assert.equals("rtl", i18n:getTextDirection("fa"))
    end)

    it("handles locale variants", function()
      assert.equals("rtl", i18n:getTextDirection("ar-SA"))
    end)
  end)

  describe("wrapBidi()", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init()
    end)

    it("wraps RTL text with markers", function()
      local wrapped = i18n:wrapBidi("مرحبا", "ar")
      -- Should contain BiDi markers
      assert.is_true(#wrapped > #"مرحبا")
    end)

    it("leaves LTR text unchanged", function()
      local wrapped = i18n:wrapBidi("Hello", "en")
      assert.equals("Hello", wrapped)
    end)
  end)

  describe("getLocaleName()", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init()
    end)

    it("returns native name for known locales", function()
      assert.equals("English", i18n:getLocaleName("en"))
      assert.equals("Español", i18n:getLocaleName("es"))
      assert.equals("Français", i18n:getLocaleName("fr"))
      assert.equals("العربية", i18n:getLocaleName("ar"))
    end)

    it("returns locale code for unknown locales", function()
      assert.equals("xx", i18n:getLocaleName("xx"))
    end)
  end)

  describe("getMissingTranslations()", function()
    local i18n

    before_each(function()
      i18n = I18n.new():init()
      i18n:loadData("en", { greeting = "Hello" })
      i18n:loadData("es", { greeting = "Hola" })
    end)

    it("tracks missing keys", function()
      i18n:setLocale("es")
      i18n:t("missing_key_1")
      i18n:t("missing_key_2")

      local missing = i18n:getMissingTranslations()
      assert.is_not_nil(missing.es)
      assert.equals(2, #missing.es)
    end)

    it("avoids duplicate entries", function()
      i18n:setLocale("es")
      i18n:t("missing_key")
      i18n:t("missing_key")
      i18n:t("missing_key")

      local missing = i18n:getMissingTranslations()
      assert.equals(1, #missing.es)
    end)
  end)

  describe("strict mode", function()
    it("throws error on missing translation", function()
      local i18n = I18n.new():init({
        strictMode = true,
        logMissing = false
      })
      i18n:loadData("en", { greeting = "Hello" })

      assert.has_error(function()
        i18n:t("missing_key")
      end)
    end)
  end)

  describe("event listeners", function()
    it("supports on() for event registration", function()
      local i18n = I18n.new({ event_bus = mock_event_bus }):init()
      local callback = function() end
      -- Should not error
      i18n:on("localeChanged", callback)
    end)

    it("supports off() for event unregistration", function()
      local i18n = I18n.new({ event_bus = mock_event_bus }):init()
      local callback = function() end
      -- Should not error
      i18n:off("localeChanged", callback)
    end)
  end)

  describe("module metadata", function()
    it("has _VERSION", function()
      assert.is_not_nil(I18n._VERSION)
      assert.is_string(I18n._VERSION)
    end)

    it("has _dependencies", function()
      assert.is_table(I18n._dependencies)
      assert.is_true(#I18n._dependencies >= 1)
    end)
  end)
end)
