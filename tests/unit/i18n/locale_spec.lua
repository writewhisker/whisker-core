-- tests/unit/i18n/locale_spec.lua
-- Unit tests for Locale module (Stage 4)

describe("Locale", function()
  local Locale
  local locale

  before_each(function()
    package.loaded["whisker.i18n.locale"] = nil
    Locale = require("whisker.i18n.locale")
    Locale.clearGlobalAdapters()
    locale = Locale.new()
  end)

  describe("new()", function()
    it("creates a Locale instance", function()
      assert.is_not_nil(locale)
    end)

    it("initializes with default config", function()
      assert.equals("en", locale.config.defaultLocale)
      assert.is_true(locale.config.autoDetect)
    end)

    it("initializes empty available locales", function()
      assert.same({}, locale.availableLocales)
    end)
  end)

  describe("init()", function()
    it("accepts configuration options", function()
      locale:init({
        defaultLocale = "es",
        autoDetect = false
      })

      assert.equals("es", locale.config.defaultLocale)
      assert.is_false(locale.config.autoDetect)
    end)

    it("sets current locale to default when autoDetect is false", function()
      locale:init({
        defaultLocale = "fr",
        autoDetect = false
      })

      assert.equals("fr", locale:getLocale())
    end)
  end)

  describe("setLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("sets current locale", function()
      locale:registerLocale("es")
      locale:setLocale("es")

      assert.equals("es", locale:getLocale())
    end)

    it("normalizes locale format", function()
      locale:registerLocale("en-US")
      locale:setLocale("en_us")

      assert.equals("en-US", locale:getLocale())
    end)

    it("accepts locale when no available locales registered", function()
      locale:setLocale("de")

      assert.equals("de", locale:getLocale())
    end)

    it("falls back to default for unavailable locale when locales registered", function()
      locale:registerLocale("en")
      locale:registerLocale("es")
      locale:setLocale("fr")

      assert.equals("en", locale:getLocale())
    end)

    it("triggers callback on change", function()
      local called = false
      local newVal, oldVal
      locale.config.onLocaleChange = function(new, old)
        called = true
        newVal = new
        oldVal = old
      end

      locale:registerLocale("es")
      locale:setLocale("es")

      assert.is_true(called)
      assert.equals("es", newVal)
    end)

    it("does not trigger callback when locale unchanged", function()
      local callCount = 0
      locale.config.onLocaleChange = function()
        callCount = callCount + 1
      end

      -- First set to something different from default
      locale:registerLocale("es")
      locale:setLocale("es")
      -- Now set to same locale again
      locale:setLocale("es")

      -- Should only be called once (first change from en to es)
      assert.equals(1, callCount)
    end)
  end)

  describe("getLocale()", function()
    it("returns current locale", function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      assert.equals("en", locale:getLocale())
    end)

    it("returns default if no current locale set", function()
      locale.config.defaultLocale = "fr"
      locale.currentLocale = nil
      assert.equals("fr", locale:getLocale())
    end)
  end)

  describe("registerLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("registers a locale", function()
      locale:registerLocale("es")
      assert.is_true(locale:hasLocale("es"))
    end)

    it("normalizes locale on register", function()
      locale:registerLocale("en_us")
      assert.is_true(locale:hasLocale("en-US"))
    end)

    it("does not duplicate locales", function()
      locale:registerLocale("es")
      locale:registerLocale("es")
      locale:registerLocale("ES")

      local available = locale:getAvailableLocales()
      local count = 0
      for _, loc in ipairs(available) do
        if loc == "es" then count = count + 1 end
      end
      assert.equals(1, count)
    end)
  end)

  describe("unregisterLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      locale:registerLocale("es")
      locale:registerLocale("fr")
    end)

    it("removes a locale", function()
      locale:unregisterLocale("es")
      assert.is_false(locale:hasLocale("es"))
    end)

    it("returns true on success", function()
      assert.is_true(locale:unregisterLocale("es"))
    end)

    it("returns false when locale not found", function()
      assert.is_false(locale:unregisterLocale("de"))
    end)
  end)

  describe("hasLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      locale:registerLocale("es")
    end)

    it("returns true for registered locale", function()
      assert.is_true(locale:hasLocale("es"))
    end)

    it("returns false for unregistered locale", function()
      assert.is_false(locale:hasLocale("fr"))
    end)

    it("normalizes input", function()
      locale:registerLocale("en-US")
      assert.is_true(locale:hasLocale("en_us"))
    end)
  end)

  describe("getAvailableLocales()", function()
    it("returns empty array when no locales registered", function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      assert.same({}, locale:getAvailableLocales())
    end)

    it("returns registered locales", function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      locale:registerLocale("en")
      locale:registerLocale("es")
      locale:registerLocale("fr")

      local available = locale:getAvailableLocales()
      assert.equals(3, #available)
    end)

    it("returns sorted locales", function()
      locale:init({ defaultLocale = "en", autoDetect = false })
      locale:registerLocale("fr")
      locale:registerLocale("es")
      locale:registerLocale("en")

      local available = locale:getAvailableLocales()
      assert.equals("en", available[1])
      assert.equals("es", available[2])
      assert.equals("fr", available[3])
    end)
  end)

  describe("matchLocale()", function()
    local available = { "en", "en-US", "es", "fr", "zh-Hans", "zh-Hant" }

    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("matches exact locale", function()
      local matched = locale:matchLocale("es", available)
      assert.equals("es", matched)
    end)

    it("matches regional to exact", function()
      local matched = locale:matchLocale("en-US", available)
      assert.equals("en-US", matched)
    end)

    it("matches regional to base language", function()
      local matched = locale:matchLocale("es-MX", available)
      assert.equals("es", matched)
    end)

    it("handles complex locale codes", function()
      local matched = locale:matchLocale("zh-Hant-TW", available)
      assert.equals("zh-Hant", matched)
    end)

    it("returns nil for no match", function()
      local matched = locale:matchLocale("de", available)
      assert.is_nil(matched)
    end)

    it("handles empty available list", function()
      local matched = locale:matchLocale("en", {})
      assert.is_nil(matched)
    end)

    it("handles nil input", function()
      local matched = locale:matchLocale(nil, available)
      assert.is_nil(matched)
    end)
  end)

  describe("getNativeName()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("returns native name for known locales", function()
      assert.equals("English", locale:getNativeName("en"))
      assert.equals("Español", locale:getNativeName("es"))
      assert.equals("Français", locale:getNativeName("fr"))
      assert.equals("日本語", locale:getNativeName("ja"))
      assert.equals("العربية", locale:getNativeName("ar"))
    end)

    it("returns regional name when available", function()
      assert.equals("English (US)", locale:getNativeName("en-US"))
      assert.equals("Español (México)", locale:getNativeName("es-MX"))
    end)

    it("falls back to base language name for unknown regions", function()
      -- en-XX is not in the list, so should fall back to "English"
      assert.equals("English", locale:getNativeName("en-XX"))
    end)

    it("returns locale code for unknown", function()
      assert.equals("xx", locale:getNativeName("xx"))
    end)
  end)

  describe("getTextDirection()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("returns ltr for English", function()
      assert.equals("ltr", locale:getTextDirection("en"))
      assert.equals("ltr", locale:getTextDirection("en-US"))
    end)

    it("returns rtl for Arabic", function()
      assert.equals("rtl", locale:getTextDirection("ar"))
      assert.equals("rtl", locale:getTextDirection("ar-SA"))
    end)

    it("returns rtl for Hebrew", function()
      assert.equals("rtl", locale:getTextDirection("he"))
    end)

    it("returns rtl for Persian", function()
      assert.equals("rtl", locale:getTextDirection("fa"))
    end)

    it("returns rtl for Urdu", function()
      assert.equals("rtl", locale:getTextDirection("ur"))
    end)

    it("uses current locale when none specified", function()
      locale:setLocale("ar")
      assert.equals("rtl", locale:getTextDirection())
    end)
  end)

  describe("isRTL()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("returns true for RTL locales", function()
      assert.is_true(locale:isRTL("ar"))
      assert.is_true(locale:isRTL("he"))
    end)

    it("returns false for LTR locales", function()
      assert.is_false(locale:isRTL("en"))
      assert.is_false(locale:isRTL("es"))
    end)
  end)

  describe("parseLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("parses simple locale", function()
      local result = locale:parseLocale("en")
      assert.equals("en", result.language)
      assert.is_nil(result.script)
      assert.is_nil(result.region)
    end)

    it("parses language-region", function()
      local result = locale:parseLocale("en-US")
      assert.equals("en", result.language)
      assert.is_nil(result.script)
      assert.equals("US", result.region)
    end)

    it("parses language-script-region", function()
      local result = locale:parseLocale("zh-Hant-TW")
      assert.equals("zh", result.language)
      assert.equals("Hant", result.script)
      assert.equals("TW", result.region)
    end)
  end)

  describe("buildLocale()", function()
    before_each(function()
      locale:init({ defaultLocale = "en", autoDetect = false })
    end)

    it("builds simple locale", function()
      local result = locale:buildLocale({ language = "en" })
      assert.equals("en", result)
    end)

    it("builds language-region", function()
      local result = locale:buildLocale({ language = "en", region = "US" })
      assert.equals("en-US", result)
    end)

    it("builds language-script-region", function()
      local result = locale:buildLocale({
        language = "zh",
        script = "Hant",
        region = "TW"
      })
      assert.equals("zh-Hant-TW", result)
    end)
  end)

  describe("storage integration", function()
    local mockStorage

    before_each(function()
      mockStorage = {
        data = {},
        get = function(self, key)
          return self.data[key]
        end,
        set = function(self, key, value)
          self.data[key] = value
        end
      }
    end)

    it("saves locale preference", function()
      locale:init({
        defaultLocale = "en",
        autoDetect = false,
        storage = mockStorage
      })

      locale:setLocale("fr")

      assert.equals("fr", mockStorage.data.whisker_locale)
    end)

    it("loads saved preference", function()
      mockStorage.data.whisker_locale = "de"

      locale:init({
        defaultLocale = "en",
        autoDetect = true,
        storage = mockStorage
      })

      assert.equals("de", locale:getLocale())
    end)

    it("clears preference", function()
      mockStorage.data.whisker_locale = "de"
      locale:init({
        defaultLocale = "en",
        autoDetect = false,
        storage = mockStorage
      })

      locale:clearPreference()

      assert.is_nil(mockStorage.data.whisker_locale)
    end)
  end)

  describe("adapter registration", function()
    it("registers instance adapter", function()
      local mockAdapter = {
        detect = function()
          return "mock-locale"
        end
      }

      locale:init({ defaultLocale = "en", autoDetect = false })
      locale:registerAdapter(mockAdapter)

      local detected = locale:detectPlatform()
      assert.equals("mock-locale", detected)
    end)

    it("registers global adapter", function()
      local mockAdapter = {
        detect = function()
          return "global-locale"
        end
      }

      Locale.registerGlobalAdapter(mockAdapter)
      locale:init({ defaultLocale = "en", autoDetect = false })

      local detected = locale:detectPlatform()
      assert.equals("global-locale", detected)
    end)
  end)
end)

describe("Locale Helper Functions", function()
  local Locale

  before_each(function()
    package.loaded["whisker.i18n.locale"] = nil
    Locale = require("whisker.i18n.locale")
  end)

  describe("normalizeLocaleTag()", function()
    it("converts underscores to hyphens", function()
      local result = Locale.normalizeLocaleTag("en_US")
      assert.equals("en-US", result)
    end)

    it("removes encoding suffix", function()
      local result = Locale.normalizeLocaleTag("en_US.UTF-8")
      assert.equals("en-US", result)
    end)

    it("normalizes case correctly", function()
      local result = Locale.normalizeLocaleTag("ZH-hant-TW")
      assert.equals("zh-Hant-TW", result)
    end)

    it("handles simple locale", function()
      local result = Locale.normalizeLocaleTag("en")
      assert.equals("en", result)
    end)

    it("handles nil input", function()
      local result = Locale.normalizeLocaleTag(nil)
      assert.is_nil(result)
    end)
  end)

  describe("buildPriorityList()", function()
    it("builds priority list for complex locale", function()
      local list = Locale.buildPriorityList("zh-Hant-TW")

      assert.equals(3, #list)
      assert.equals("zh-Hant-TW", list[1])
      assert.equals("zh-Hant", list[2])
      assert.equals("zh", list[3])
    end)

    it("builds priority list for regional locale", function()
      local list = Locale.buildPriorityList("en-US")

      assert.equals(2, #list)
      assert.equals("en-US", list[1])
      assert.equals("en", list[2])
    end)

    it("handles simple locale", function()
      local list = Locale.buildPriorityList("en")

      assert.equals(1, #list)
      assert.equals("en", list[1])
    end)
  end)
end)

describe("Desktop Adapter", function()
  local DesktopAdapter

  before_each(function()
    package.loaded["whisker.i18n.adapters.desktop"] = nil
    DesktopAdapter = require("whisker.i18n.adapters.desktop")
  end)

  describe("windowsLocaleIdToBCP47()", function()
    it("converts common Windows locale IDs", function()
      assert.equals("en-US", DesktopAdapter.windowsLocaleIdToBCP47("0409"))
      assert.equals("en-GB", DesktopAdapter.windowsLocaleIdToBCP47("0809"))
      assert.equals("es-ES", DesktopAdapter.windowsLocaleIdToBCP47("040a"))
      assert.equals("fr-FR", DesktopAdapter.windowsLocaleIdToBCP47("040c"))
      assert.equals("de-DE", DesktopAdapter.windowsLocaleIdToBCP47("0407"))
      assert.equals("ja-JP", DesktopAdapter.windowsLocaleIdToBCP47("0411"))
      assert.equals("zh-CN", DesktopAdapter.windowsLocaleIdToBCP47("0804"))
      assert.equals("ar-SA", DesktopAdapter.windowsLocaleIdToBCP47("0401"))
    end)

    it("returns en-US for unknown IDs", function()
      assert.equals("en-US", DesktopAdapter.windowsLocaleIdToBCP47("9999"))
    end)
  end)

  describe("isWindows()", function()
    it("returns boolean", function()
      local result = DesktopAdapter.isWindows()
      assert.is_boolean(result)
    end)
  end)
end)
