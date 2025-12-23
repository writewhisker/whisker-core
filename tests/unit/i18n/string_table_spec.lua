-- tests/unit/i18n/string_table_spec.lua
-- Unit tests for StringTable module (Stage 2)

describe("StringTable", function()
  local StringTable
  local mock_logger
  local st

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
      getLogs = function(self)
        return logs
      end,
      clear = function(self)
        logs = {}
      end
    }
  end

  before_each(function()
    -- Clear package cache
    package.loaded["whisker.i18n.string_table"] = nil
    StringTable = require("whisker.i18n.string_table")
    mock_logger = create_mock_logger()
  end)

  describe("new()", function()
    it("creates a StringTable instance with default config", function()
      st = StringTable.new()
      assert.is_not_nil(st)
      assert.equals("en", st.config.defaultLocale)
    end)

    it("accepts configuration options", function()
      st = StringTable.new({
        defaultLocale = "es",
        fallbackLocale = "en",
        strictMode = true,
        logMissing = true
      })
      assert.equals("es", st.config.defaultLocale)
      assert.equals("en", st.config.fallbackLocale)
      assert.is_true(st.config.strictMode)
      assert.is_true(st.config.logMissing)
    end)

    it("initializes empty data structures", function()
      st = StringTable.new()
      assert.same({}, st.data)
      assert.same({}, st.index)
      assert.same({}, st.missing)
      assert.same({}, st.metadata)
    end)
  end)

  describe("load()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
    end)

    it("loads hierarchical data", function()
      st:load("en", {
        greeting = "Hello",
        items = {
          sword = "sword"
        }
      })

      assert.is_not_nil(st.data["en"])
      assert.is_not_nil(st.index["en"])
    end)

    it("flattens nested keys", function()
      st:load("en", {
        items = {
          sword = "sword",
          shield = "shield"
        }
      })

      assert.equals("sword", st.index["en"]["items.sword"])
      assert.equals("shield", st.index["en"]["items.shield"])
    end)

    it("handles deeply nested structures", function()
      st:load("en", {
        level1 = {
          level2 = {
            level3 = {
              level4 = {
                key = "deep value"
              }
            }
          }
        }
      })

      assert.equals("deep value", st.index["en"]["level1.level2.level3.level4.key"])
    end)

    it("stores metadata", function()
      st:load("en", { greeting = "Hello" })
      local meta = st:getMetadata("en")

      assert.is_not_nil(meta.loadTime)
      assert.equals(1, meta.keyCount)
    end)

    it("converts non-string values to strings", function()
      st:load("en", {
        number = 123,
        boolean_true = true,
        boolean_false = false
      })

      assert.equals("123", st:lookup("en", "number"))
      assert.equals("true", st:lookup("en", "boolean_true"))
      assert.equals("false", st:lookup("en", "boolean_false"))
    end)

    it("skips nil values", function()
      st:load("en", {
        key1 = "value1",
        key2 = nil,
        key3 = "value3"
      })

      assert.equals("value1", st:lookup("en", "key1"))
      assert.is_nil(st:lookup("en", "key2"))
      assert.equals("value3", st:lookup("en", "key3"))
    end)

    it("detects circular references", function()
      local data = { a = {} }
      data.a.b = data  -- circular

      assert.has_error(function()
        st:load("en", data)
      end, "Invalid translation data for en: Circular reference detected")
    end)

    it("handles empty data", function()
      st:load("en", {})
      assert.is_not_nil(st.data["en"])
      assert.same({}, st.index["en"])
    end)

    it("supports lazy loading option", function()
      st:load("en", { greeting = "Hello" }, { lazy = true })

      assert.is_not_nil(st.data["en"])
      local meta = st:getMetadata("en")
      assert.is_true(meta.needsIndex)
    end)
  end)

  describe("lookup()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        items = {
          sword = "a sword"
        }
      })
    end)

    it("finds exact key match", function()
      local value = st:lookup("en", "greeting")
      assert.equals("Hello", value)
    end)

    it("finds nested key", function()
      local value = st:lookup("en", "items.sword")
      assert.equals("a sword", value)
    end)

    it("returns nil for missing key", function()
      local value = st:lookup("en", "nonexistent")
      assert.is_nil(value)
    end)

    it("falls back to default locale", function()
      st:load("es", { greeting = "Hola" })
      local value = st:lookup("es", "items.sword")  -- not in es
      assert.equals("a sword", value)  -- from en
    end)

    it("builds index on first lookup for lazy-loaded data", function()
      st:load("fr", { greeting = "Bonjour" }, { lazy = true })

      -- Before lookup, index should not exist
      local meta = st:getMetadata("fr")
      assert.is_true(meta.needsIndex)

      -- After lookup, index should be built
      st:lookup("fr", "greeting")
      meta = st:getMetadata("fr")
      assert.is_false(meta.needsIndex)
    end)
  end)

  describe("fallback chain", function()
    before_each(function()
      st = StringTable.new({
        defaultLocale = "en",
        fallbackLocale = "en"
      })
    end)

    it("builds chain for regional locale", function()
      local chain = st:buildFallbackChain("es-MX")

      assert.equals(2, #chain)
      assert.equals("es", chain[1])
      assert.equals("en", chain[2])
    end)

    it("handles complex locale codes (language-script-region)", function()
      local chain = st:buildFallbackChain("zh-Hant-TW")

      assert.equals(3, #chain)
      assert.equals("zh-Hant", chain[1])
      assert.equals("zh", chain[2])
      assert.equals("en", chain[3])
    end)

    it("handles simple locale codes", function()
      local chain = st:buildFallbackChain("fr")
      assert.equals(1, #chain)
      assert.equals("en", chain[1])
    end)

    it("avoids duplicate entries", function()
      st.config.fallbackLocale = "en"
      st.config.defaultLocale = "en"
      local chain = st:buildFallbackChain("en-US")

      -- Should not have duplicate "en" entries
      local count = 0
      for _, loc in ipairs(chain) do
        if loc == "en" then count = count + 1 end
      end
      assert.equals(1, count)
    end)

    it("uses fallback chain during lookup", function()
      st:load("en", {
        english_only = "English value",
        shared = "English shared"
      })
      st:load("es", {
        spanish_only = "Spanish value",
        shared = "Spanish shared"
      })

      -- Spanish should find its own key
      assert.equals("Spanish shared", st:lookup("es", "shared"))

      -- Spanish should fall back to English for missing key
      assert.equals("English value", st:lookup("es", "english_only"))
    end)
  end)

  describe("missing tracking", function()
    before_each(function()
      st = StringTable.new({
        defaultLocale = "en",
        logMissing = false
      })
      st:load("en", { greeting = "Hello" })
    end)

    it("tracks missing keys", function()
      st:lookup("en", "missing.key")

      local missing = st:getMissing("en")
      assert.equals(1, #missing)
      assert.equals("missing.key", missing[1])
    end)

    it("doesn't duplicate missing keys", function()
      st:lookup("en", "missing.key")
      st:lookup("en", "missing.key")
      st:lookup("en", "missing.key")

      local missing = st:getMissing("en")
      assert.equals(1, #missing)
    end)

    it("tracks multiple different missing keys", function()
      st:lookup("en", "missing.key1")
      st:lookup("en", "missing.key2")
      st:lookup("en", "missing.key3")

      local missing = st:getMissing("en")
      assert.equals(3, #missing)
    end)

    it("returns all missing by locale when no filter", function()
      st:load("es", { greeting = "Hola" })
      st:lookup("en", "missing.en")
      st:lookup("es", "missing.es")

      local all = st:getMissing()
      assert.is_not_nil(all.en)
      assert.is_not_nil(all.es)
    end)

    it("clears missing keys for specific locale", function()
      st:lookup("en", "missing.key")
      st:clearMissing("en")

      local missing = st:getMissing("en")
      assert.equals(0, #missing)
    end)

    it("clears all missing keys", function()
      st:load("es", { greeting = "Hola" })
      st:lookup("en", "missing.en")
      st:lookup("es", "missing.es")
      st:clearMissing()

      local all = st:getMissing()
      assert.same({}, all)
    end)

    it("logs missing when configured", function()
      st = StringTable.new({
        defaultLocale = "en",
        logMissing = true,
        logger = mock_logger
      })
      st:load("en", { greeting = "Hello" })

      st:lookup("en", "missing.key")

      local logs = mock_logger:getLogs()
      assert.equals(1, #logs)
      assert.equals("warn", logs[1].level)
      assert.truthy(logs[1].message:match("missing.key"))
    end)
  end)

  describe("has()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        items = { sword = "sword" }
      })
    end)

    it("returns true for existing keys", function()
      assert.is_true(st:has("en", "greeting"))
      assert.is_true(st:has("en", "items.sword"))
    end)

    it("returns false for missing keys", function()
      assert.is_false(st:has("en", "nonexistent"))
    end)

    it("considers fallback chain", function()
      st:load("es", { greeting = "Hola" })
      -- items.sword only in en, but accessible from es via fallback
      assert.is_true(st:has("es", "items.sword"))
    end)
  end)

  describe("getKeys()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        b_key = "b",
        a_key = "a",
        c = { nested = "c" }
      })
    end)

    it("returns all keys for locale", function()
      local keys = st:getKeys("en")
      assert.equals(3, #keys)
    end)

    it("returns keys in sorted order", function()
      local keys = st:getKeys("en")
      assert.equals("a_key", keys[1])
      assert.equals("b_key", keys[2])
      assert.equals("c.nested", keys[3])
    end)

    it("returns empty array for unloaded locale", function()
      local keys = st:getKeys("fr")
      assert.same({}, keys)
    end)
  end)

  describe("getLocales()", function()
    it("returns loaded locales", function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", { greeting = "Hello" })
      st:load("es", { greeting = "Hola" })
      st:load("fr", { greeting = "Bonjour" })

      local locales = st:getLocales()
      assert.equals(3, #locales)
    end)

    it("returns locales in sorted order", function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("fr", { greeting = "Bonjour" })
      st:load("en", { greeting = "Hello" })
      st:load("es", { greeting = "Hola" })

      local locales = st:getLocales()
      assert.equals("en", locales[1])
      assert.equals("es", locales[2])
      assert.equals("fr", locales[3])
    end)
  end)

  describe("unload()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", { greeting = "Hello" })
      st:load("es", { greeting = "Hola" })
    end)

    it("removes locale data", function()
      st:unload("es")

      assert.is_nil(st.data["es"])
      assert.is_nil(st.index["es"])
      assert.is_nil(st.metadata["es"])
    end)

    it("keeps other locales intact", function()
      st:unload("es")

      assert.is_not_nil(st.data["en"])
      assert.equals("Hello", st:lookup("en", "greeting"))
    end)

    it("clears missing keys for unloaded locale", function()
      st:lookup("es", "missing.key")
      st:unload("es")

      assert.is_nil(st.missing["es"])
    end)
  end)

  describe("memory management", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
    end)

    it("estimates memory usage for locale", function()
      st:load("en", { greeting = "Hello" })
      local bytes = st:getMemoryUsage("en")

      assert.is_true(bytes > 0)
      assert.is_true(bytes < 1000)  -- Simple data should be small
    end)

    it("estimates total memory usage", function()
      st:load("en", { greeting = "Hello" })
      st:load("es", { greeting = "Hola" })

      local bytes = st:getMemoryUsage()
      assert.is_true(bytes > 0)
    end)
  end)

  describe("clone()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        nested = { key = "value" }
      })
    end)

    it("clones locale data to new locale", function()
      st:clone("en", "en-clone")

      assert.equals("Hello", st:lookup("en-clone", "greeting"))
      assert.equals("value", st:lookup("en-clone", "nested.key"))
    end)

    it("creates independent copy", function()
      st:clone("en", "en-clone")

      -- Modify original
      st.data["en"].greeting = "Modified"
      st.index["en"]["greeting"] = "Modified"

      -- Clone should be unchanged
      assert.equals("Hello", st:lookup("en-clone", "greeting"))
    end)

    it("errors when source locale not loaded", function()
      assert.has_error(function()
        st:clone("fr", "fr-clone")
      end, "Source locale not loaded: fr")
    end)
  end)

  describe("merge()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        existing = "original"
      })
    end)

    it("merges additional data", function()
      st:merge("en", { farewell = "Goodbye" })

      assert.equals("Hello", st:lookup("en", "greeting"))
      assert.equals("Goodbye", st:lookup("en", "farewell"))
    end)

    it("does not overwrite by default", function()
      st:merge("en", { existing = "new value" })

      assert.equals("original", st:lookup("en", "existing"))
    end)

    it("overwrites when specified", function()
      st:merge("en", { existing = "new value" }, true)

      assert.equals("new value", st:lookup("en", "existing"))
    end)

    it("merges nested structures", function()
      st:load("en", {
        nested = { a = "a value" }
      })
      st:merge("en", {
        nested = { b = "b value" }
      })

      assert.equals("a value", st:lookup("en", "nested.a"))
      assert.equals("b value", st:lookup("en", "nested.b"))
    end)

    it("creates new locale if not loaded", function()
      st:merge("fr", { greeting = "Bonjour" })

      assert.equals("Bonjour", st:lookup("fr", "greeting"))
    end)
  end)

  describe("getData()", function()
    it("returns raw hierarchical data", function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        nested = { key = "value" }
      })

      local data = st:getData("en")
      assert.is_table(data)
      assert.is_not_nil(data.nested)
    end)

    it("returns nil for unloaded locale", function()
      st = StringTable.new({ defaultLocale = "en" })
      assert.is_nil(st:getData("fr"))
    end)
  end)

  describe("getIndex()", function()
    it("returns flattened index", function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", {
        greeting = "Hello",
        nested = { key = "value" }
      })

      local index = st:getIndex("en")
      assert.equals("Hello", index["greeting"])
      assert.equals("value", index["nested.key"])
    end)

    it("builds index for lazy-loaded data", function()
      st = StringTable.new({ defaultLocale = "en" })
      st:load("en", { greeting = "Hello" }, { lazy = true })

      local index = st:getIndex("en")
      assert.equals("Hello", index["greeting"])
    end)
  end)

  describe("flatten()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
    end)

    it("flattens simple table", function()
      local result = st:flatten({ a = "1", b = "2" })
      assert.equals("1", result["a"])
      assert.equals("2", result["b"])
    end)

    it("flattens nested table", function()
      local result = st:flatten({
        level1 = {
          level2 = "value"
        }
      })
      assert.equals("value", result["level1.level2"])
    end)

    it("handles numeric keys", function()
      local result = st:flatten({
        items = {
          [1] = "first",
          [2] = "second"
        }
      })
      assert.equals("first", result["items.1"])
      assert.equals("second", result["items.2"])
    end)

    it("returns empty table for non-table input", function()
      local result = st:flatten("not a table")
      assert.same({}, result)
    end)
  end)

  describe("splitLocale()", function()
    before_each(function()
      st = StringTable.new({ defaultLocale = "en" })
    end)

    it("splits simple locale", function()
      local parts = st:splitLocale("en")
      assert.equals(1, #parts)
      assert.equals("en", parts[1])
    end)

    it("splits language-region locale", function()
      local parts = st:splitLocale("en-US")
      assert.equals(2, #parts)
      assert.equals("en", parts[1])
      assert.equals("US", parts[2])
    end)

    it("splits language-script-region locale", function()
      local parts = st:splitLocale("zh-Hant-TW")
      assert.equals(3, #parts)
      assert.equals("zh", parts[1])
      assert.equals("Hant", parts[2])
      assert.equals("TW", parts[3])
    end)
  end)

  describe("module metadata", function()
    it("has _VERSION", function()
      assert.is_not_nil(StringTable._VERSION)
      assert.is_string(StringTable._VERSION)
    end)

    it("has _dependencies", function()
      assert.is_table(StringTable._dependencies)
    end)
  end)
end)

-- Performance tests
describe("StringTable Performance", function()
  local StringTable
  local st
  local testData

  before_each(function()
    package.loaded["whisker.i18n.string_table"] = nil
    StringTable = require("whisker.i18n.string_table")
    st = StringTable.new({ defaultLocale = "en" })

    -- Generate 1000 test strings
    testData = {}
    for i = 1, 1000 do
      testData["key" .. i] = "value" .. i
    end
  end)

  it("loads 1000 strings in <50ms", function()
    local start = os.clock()
    st:load("en", testData)
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 50, "Load took " .. elapsed .. "ms")
  end)

  it("looks up keys in <0.1ms average", function()
    st:load("en", testData)

    local start = os.clock()
    for i = 1, 1000 do
      st:lookup("en", "key" .. i)
    end
    local elapsed = (os.clock() - start) * 1000
    local avgPerLookup = elapsed / 1000

    assert.is_true(avgPerLookup < 0.1, "Avg lookup: " .. avgPerLookup .. "ms")
  end)

  it("handles 100 locales efficiently", function()
    for i = 1, 100 do
      st:load("locale" .. i, testData)
    end

    local start = os.clock()
    st:lookup("locale50", "key500")
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 0.1, "Lookup in 100 locales: " .. elapsed .. "ms")
  end)

  it("uses reasonable memory per 100 strings", function()
    local smallData = {}
    for i = 1, 100 do
      smallData["key" .. i] = "value" .. i
    end

    st:load("en", smallData)
    local bytes = st:getMemoryUsage("en")

    -- Memory usage should be reasonable (allowing for some overhead)
    assert.is_true(bytes < 10000, "Memory: " .. bytes .. " bytes for 100 strings")
  end)
end)
