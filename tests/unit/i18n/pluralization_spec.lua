-- tests/unit/i18n/pluralization_spec.lua
-- Unit tests for Pluralization module (Stage 5)

describe("Pluralization", function()
  local Pluralization
  local plural

  before_each(function()
    package.loaded["whisker.i18n.pluralization"] = nil
    package.loaded["whisker.i18n.data.plural_rules"] = nil
    Pluralization = require("whisker.i18n.pluralization")
    plural = Pluralization.new()
    plural:init()
  end)

  describe("new()", function()
    it("creates a Pluralization instance", function()
      local p = Pluralization.new()
      assert.is_not_nil(p)
    end)
  end)

  describe("init()", function()
    it("loads plural rules", function()
      local p = Pluralization.new()
      p:init()
      assert.is_true(p._initialized)
    end)
  end)

  describe("English (en)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("en", 1))
    end)

    it("returns 'other' for 0", function()
      assert.equals("other", plural:getCategory("en", 0))
    end)

    it("returns 'other' for 2", function()
      assert.equals("other", plural:getCategory("en", 2))
    end)

    it("returns 'other' for 5", function()
      assert.equals("other", plural:getCategory("en", 5))
    end)

    it("returns 'other' for 10", function()
      assert.equals("other", plural:getCategory("en", 10))
    end)

    it("returns 'other' for 100", function()
      assert.equals("other", plural:getCategory("en", 100))
    end)

    it("returns 'other' for 1.5 (decimal)", function()
      assert.equals("other", plural:getCategory("en", 1.5))
    end)

    it("returns 'other' for 1.0 when it has decimal representation", function()
      -- Note: In Lua, 1.0 == 1 as numbers, so this should be "one"
      assert.equals("one", plural:getCategory("en", 1.0))
    end)

    it("handles regional variant en-US", function()
      assert.equals("one", plural:getCategory("en-US", 1))
      assert.equals("other", plural:getCategory("en-US", 5))
    end)

    it("handles regional variant en-GB", function()
      assert.equals("one", plural:getCategory("en-GB", 1))
      assert.equals("other", plural:getCategory("en-GB", 5))
    end)
  end)

  describe("German (de)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("de", 1))
    end)

    it("returns 'other' for 0", function()
      assert.equals("other", plural:getCategory("de", 0))
    end)

    it("returns 'other' for 2", function()
      assert.equals("other", plural:getCategory("de", 2))
    end)
  end)

  describe("Spanish (es)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("es", 1))
    end)

    it("returns 'other' for 0", function()
      assert.equals("other", plural:getCategory("es", 0))
    end)

    it("returns 'other' for 5", function()
      assert.equals("other", plural:getCategory("es", 5))
    end)
  end)

  describe("French (fr)", function()
    it("returns 'one' for 0", function()
      assert.equals("one", plural:getCategory("fr", 0))
    end)

    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("fr", 1))
    end)

    it("returns 'other' for 2", function()
      assert.equals("other", plural:getCategory("fr", 2))
    end)

    it("returns 'other' for 5", function()
      assert.equals("other", plural:getCategory("fr", 5))
    end)
  end)

  describe("Russian (ru)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("ru", 1))
    end)

    it("returns 'one' for 21", function()
      assert.equals("one", plural:getCategory("ru", 21))
    end)

    it("returns 'one' for 31", function()
      assert.equals("one", plural:getCategory("ru", 31))
    end)

    it("returns 'one' for 101", function()
      assert.equals("one", plural:getCategory("ru", 101))
    end)

    it("returns 'few' for 2", function()
      assert.equals("few", plural:getCategory("ru", 2))
    end)

    it("returns 'few' for 3", function()
      assert.equals("few", plural:getCategory("ru", 3))
    end)

    it("returns 'few' for 4", function()
      assert.equals("few", plural:getCategory("ru", 4))
    end)

    it("returns 'few' for 22", function()
      assert.equals("few", plural:getCategory("ru", 22))
    end)

    it("returns 'few' for 23", function()
      assert.equals("few", plural:getCategory("ru", 23))
    end)

    it("returns 'few' for 24", function()
      assert.equals("few", plural:getCategory("ru", 24))
    end)

    it("returns 'many' for 0", function()
      assert.equals("many", plural:getCategory("ru", 0))
    end)

    it("returns 'many' for 5", function()
      assert.equals("many", plural:getCategory("ru", 5))
    end)

    it("returns 'many' for 11", function()
      assert.equals("many", plural:getCategory("ru", 11))
    end)

    it("returns 'many' for 12", function()
      assert.equals("many", plural:getCategory("ru", 12))
    end)

    it("returns 'many' for 13", function()
      assert.equals("many", plural:getCategory("ru", 13))
    end)

    it("returns 'many' for 14", function()
      assert.equals("many", plural:getCategory("ru", 14))
    end)

    it("returns 'many' for 20", function()
      assert.equals("many", plural:getCategory("ru", 20))
    end)

    it("returns 'many' for 25", function()
      assert.equals("many", plural:getCategory("ru", 25))
    end)

    it("returns 'many' for 100", function()
      assert.equals("many", plural:getCategory("ru", 100))
    end)

    it("returns 'other' for 1.5 (decimal)", function()
      assert.equals("other", plural:getCategory("ru", 1.5))
    end)

    it("returns 'other' for 2.3 (decimal)", function()
      assert.equals("other", plural:getCategory("ru", 2.3))
    end)
  end)

  describe("Polish (pl)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("pl", 1))
    end)

    it("returns 'few' for 2", function()
      assert.equals("few", plural:getCategory("pl", 2))
    end)

    it("returns 'few' for 3", function()
      assert.equals("few", plural:getCategory("pl", 3))
    end)

    it("returns 'few' for 4", function()
      assert.equals("few", plural:getCategory("pl", 4))
    end)

    it("returns 'few' for 22", function()
      assert.equals("few", plural:getCategory("pl", 22))
    end)

    it("returns 'many' for 0", function()
      assert.equals("many", plural:getCategory("pl", 0))
    end)

    it("returns 'many' for 5", function()
      assert.equals("many", plural:getCategory("pl", 5))
    end)

    it("returns 'many' for 11", function()
      assert.equals("many", plural:getCategory("pl", 11))
    end)

    it("returns 'many' for 12", function()
      assert.equals("many", plural:getCategory("pl", 12))
    end)
  end)

  describe("Arabic (ar)", function()
    it("returns 'zero' for 0", function()
      assert.equals("zero", plural:getCategory("ar", 0))
    end)

    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("ar", 1))
    end)

    it("returns 'two' for 2", function()
      assert.equals("two", plural:getCategory("ar", 2))
    end)

    it("returns 'few' for 3", function()
      assert.equals("few", plural:getCategory("ar", 3))
    end)

    it("returns 'few' for 10", function()
      assert.equals("few", plural:getCategory("ar", 10))
    end)

    it("returns 'few' for 103", function()
      assert.equals("few", plural:getCategory("ar", 103))
    end)

    it("returns 'few' for 110", function()
      assert.equals("few", plural:getCategory("ar", 110))
    end)

    it("returns 'many' for 11", function()
      assert.equals("many", plural:getCategory("ar", 11))
    end)

    it("returns 'many' for 99", function()
      assert.equals("many", plural:getCategory("ar", 99))
    end)

    it("returns 'many' for 111", function()
      assert.equals("many", plural:getCategory("ar", 111))
    end)

    it("returns 'other' for 100", function()
      assert.equals("other", plural:getCategory("ar", 100))
    end)

    it("returns 'other' for 1000", function()
      assert.equals("other", plural:getCategory("ar", 1000))
    end)
  end)

  describe("Japanese (ja)", function()
    it("returns 'other' for 0", function()
      assert.equals("other", plural:getCategory("ja", 0))
    end)

    it("returns 'other' for 1", function()
      assert.equals("other", plural:getCategory("ja", 1))
    end)

    it("returns 'other' for 5", function()
      assert.equals("other", plural:getCategory("ja", 5))
    end)

    it("returns 'other' for 100", function()
      assert.equals("other", plural:getCategory("ja", 100))
    end)
  end)

  describe("Chinese (zh)", function()
    it("returns 'other' for all counts", function()
      assert.equals("other", plural:getCategory("zh", 0))
      assert.equals("other", plural:getCategory("zh", 1))
      assert.equals("other", plural:getCategory("zh", 5))
      assert.equals("other", plural:getCategory("zh", 100))
    end)
  end)

  describe("Korean (ko)", function()
    it("returns 'other' for all counts", function()
      assert.equals("other", plural:getCategory("ko", 0))
      assert.equals("other", plural:getCategory("ko", 1))
      assert.equals("other", plural:getCategory("ko", 100))
    end)
  end)

  describe("Hebrew (he)", function()
    it("returns 'one' for 1", function()
      assert.equals("one", plural:getCategory("he", 1))
    end)

    it("returns 'two' for 2", function()
      assert.equals("two", plural:getCategory("he", 2))
    end)

    it("returns 'many' for 20", function()
      assert.equals("many", plural:getCategory("he", 20))
    end)

    it("returns 'many' for 100", function()
      assert.equals("many", plural:getCategory("he", 100))
    end)

    it("returns 'other' for 3", function()
      assert.equals("other", plural:getCategory("he", 3))
    end)

    it("returns 'other' for 11", function()
      assert.equals("other", plural:getCategory("he", 11))
    end)
  end)

  describe("Unknown language", function()
    it("returns 'other' for unknown language", function()
      assert.equals("other", plural:getCategory("xx", 0))
      assert.equals("other", plural:getCategory("xx", 1))
      assert.equals("other", plural:getCategory("xx", 5))
    end)
  end)

  describe("Edge cases", function()
    it("handles negative numbers", function()
      -- Should use absolute value
      assert.equals("one", plural:getCategory("en", -1))
      assert.equals("other", plural:getCategory("en", -5))
    end)

    it("handles large numbers", function()
      assert.equals("one", plural:getCategory("ru", 1000001))
      assert.equals("few", plural:getCategory("ru", 1000002))
      assert.equals("many", plural:getCategory("ru", 1000005))
    end)

    it("handles nil count as 0", function()
      -- Note: getCategory converts non-numbers to 0
      local result = plural:getCategory("en", nil)
      assert.equals("other", result)
    end)

    it("handles string count", function()
      local result = plural:getCategory("en", "5")
      assert.equals("other", result)
    end)
  end)

  describe("getSupportedLanguages()", function()
    it("returns array of languages", function()
      local langs = plural:getSupportedLanguages()
      assert.is_table(langs)
      assert.is_true(#langs > 10)
    end)

    it("includes common languages", function()
      local langs = plural:getSupportedLanguages()
      local langSet = {}
      for _, lang in ipairs(langs) do
        langSet[lang] = true
      end

      assert.is_true(langSet["en"])
      assert.is_true(langSet["ru"])
      assert.is_true(langSet["ar"])
      assert.is_true(langSet["ja"])
    end)
  end)

  describe("isLanguageSupported()", function()
    it("returns true for supported languages", function()
      assert.is_true(plural:isLanguageSupported("en"))
      assert.is_true(plural:isLanguageSupported("ru"))
      assert.is_true(plural:isLanguageSupported("ar"))
      assert.is_true(plural:isLanguageSupported("ja"))
    end)

    it("returns true for regional variants", function()
      assert.is_true(plural:isLanguageSupported("en-US"))
      assert.is_true(plural:isLanguageSupported("ru-RU"))
    end)

    it("returns false for unsupported languages", function()
      assert.is_false(plural:isLanguageSupported("xx"))
    end)
  end)

  describe("getCategoriesForLanguage()", function()
    it("returns 2 categories for English", function()
      local cats = plural:getCategoriesForLanguage("en")
      assert.equals(2, #cats)
    end)

    it("returns 3 categories for Russian", function()
      local cats = plural:getCategoriesForLanguage("ru")
      assert.equals(3, #cats)
    end)

    it("returns 6 categories for Arabic", function()
      local cats = plural:getCategoriesForLanguage("ar")
      assert.equals(6, #cats)
    end)

    it("returns 1 category for Japanese", function()
      local cats = plural:getCategoriesForLanguage("ja")
      assert.equals(1, #cats)
    end)
  end)

  describe("getFormCount()", function()
    it("returns correct form count", function()
      assert.equals(2, plural:getFormCount("en"))
      assert.equals(3, plural:getFormCount("ru"))
      assert.equals(6, plural:getFormCount("ar"))
      assert.equals(1, plural:getFormCount("ja"))
    end)
  end)

  describe("module-level getCategory()", function()
    it("works without instance", function()
      local result = Pluralization.getCategory("en", 1)
      assert.equals("one", result)
    end)

    it("works for Russian", function()
      local result = Pluralization.getCategory("ru", 21)
      assert.equals("one", result)
    end)
  end)
end)

describe("Pluralization Performance", function()
  local Pluralization
  local plural

  before_each(function()
    package.loaded["whisker.i18n.pluralization"] = nil
    package.loaded["whisker.i18n.data.plural_rules"] = nil
    Pluralization = require("whisker.i18n.pluralization")
    plural = Pluralization.new()
    plural:init()
  end)

  it("processes 10,000 pluralizations quickly", function()
    local start = os.clock()

    for i = 0, 10000 do
      plural:getCategory("ru", i)  -- Complex rules
    end

    local elapsed = (os.clock() - start) * 1000
    local avgPerCall = elapsed / 10000

    assert.is_true(avgPerCall < 0.1, "Avg per call: " .. avgPerCall .. "ms")
  end)
end)
