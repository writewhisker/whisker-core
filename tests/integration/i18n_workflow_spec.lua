-- tests/integration/i18n_workflow_spec.lua
-- Integration tests for complete i18n workflow (Stage 9)

describe("i18n Workflow Integration", function()
  local I18n
  local Extract
  local Validate
  local Status

  before_each(function()
    -- Clear all modules
    package.loaded["whisker.i18n"] = nil
    package.loaded["whisker.i18n.init"] = nil
    package.loaded["whisker.i18n.tools.extract"] = nil
    package.loaded["whisker.i18n.tools.validate"] = nil
    package.loaded["whisker.i18n.tools.status"] = nil

    I18n = require("whisker.i18n")
    Extract = require("whisker.i18n.tools.extract")
    Validate = require("whisker.i18n.tools.validate")
    Status = require("whisker.i18n.tools.status")
  end)

  describe("Extract → Template → Translate → Validate", function()
    it("extracts strings from Whisker Script", function()
      local source = [[
        @@t greeting
        You have @@p items.count count=n items.
        Welcome to @@t location.name, @@t player.name!
      ]]

      local keys = Extract.fromString(source, "demo.whisker")

      assert.equals(4, #keys)

      local keyNames = {}
      for _, k in ipairs(keys) do
        table.insert(keyNames, k.key)
      end

      table.sort(keyNames)
      assert.equals("greeting", keyNames[1])
      assert.equals("items.count", keyNames[2])
      assert.equals("location.name", keyNames[3])
      assert.equals("player.name", keyNames[4])
    end)

    it("generates template from extracted keys", function()
      local keys = {
        { key = "greeting", type = "translate" },
        { key = "items.count", type = "plural" },
        { key = "menu.title", type = "translate" }
      }

      local template = Extract.toYAML(keys)

      assert.matches("greeting:", template)
      assert.matches("items:", template)
      assert.matches("count:", template)
      assert.matches("one:", template)
      assert.matches("other:", template)
      assert.matches("menu:", template)
      assert.matches("title:", template)
    end)

    it("validates translation completeness", function()
      local base = {
        greeting = "Hello!",
        farewell = "Goodbye!",
        items = {
          count = {
            one = "{count} item",
            other = "{count} items"
          }
        }
      }

      local target = {
        greeting = "Hola!",
        -- Missing: farewell
        items = {
          count = {
            one = "{count} artículo"
            -- Missing: other
          }
        }
      }

      local issues = Validate.compare(base, target)
      local errors, warnings = Validate.countIssues(issues)

      assert.is_true(errors >= 2)  -- Missing farewell and items.count.other
    end)

    it("validates variable consistency", function()
      local base = {
        welcome = "Welcome, {name}!",
        score = "Score: {points} points"
      }

      local target = {
        welcome = "Bienvenido, {nombre}!",  -- Wrong variable
        score = "Puntos: {points}"
      }

      local issues = Validate.compare(base, target)

      local hasMissingVar = false
      for _, issue in ipairs(issues) do
        if issue.type == "missing_variable" then
          hasMissingVar = true
        end
      end

      assert.is_true(hasMissingVar)
    end)
  end)

  describe("Multi-Language Story", function()
    it("plays story in English", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "en" })

      i18n:loadData("en", {
        greeting = "Hello!",
        items = {
          count = {
            one = "{count} item",
            other = "{count} items"
          }
        }
      })

      assert.equals("Hello!", i18n:t("greeting"))
      assert.equals("1 item", i18n:p("items.count", 1))
      assert.equals("5 items", i18n:p("items.count", 5))
    end)

    it("plays story in Spanish", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "es" })

      i18n:loadData("es", {
        greeting = "¡Hola!",
        items = {
          count = {
            one = "{count} artículo",
            other = "{count} artículos"
          }
        }
      })

      assert.equals("¡Hola!", i18n:t("greeting"))
      assert.equals("1 artículo", i18n:p("items.count", 1))
      assert.equals("5 artículos", i18n:p("items.count", 5))
    end)

    it("plays story in Russian with 3 plural forms", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "ru" })

      i18n:loadData("ru", {
        greeting = "Привет!",
        items = {
          count = {
            one = "{count} предмет",
            few = "{count} предмета",
            many = "{count} предметов"
          }
        }
      })

      assert.equals("Привет!", i18n:t("greeting"))
      assert.equals("1 предмет", i18n:p("items.count", 1))
      assert.equals("2 предмета", i18n:p("items.count", 2))
      assert.equals("5 предметов", i18n:p("items.count", 5))
      assert.equals("21 предмет", i18n:p("items.count", 21))
      assert.equals("22 предмета", i18n:p("items.count", 22))
    end)

    it("plays story in Arabic with 6 plural forms", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "ar" })

      i18n:loadData("ar", {
        greeting = "مرحبا!",
        items = {
          count = {
            zero = "لا توجد عناصر",
            one = "عنصر واحد",
            two = "عنصران",
            few = "{count} عناصر",
            many = "{count} عنصرًا",
            other = "{count} عنصر"
          }
        }
      })

      assert.equals("مرحبا!", i18n:t("greeting"))
      assert.equals("لا توجد عناصر", i18n:p("items.count", 0))
      assert.equals("عنصر واحد", i18n:p("items.count", 1))
      assert.equals("عنصران", i18n:p("items.count", 2))
      assert.equals("3 عناصر", i18n:p("items.count", 3))
      assert.equals("11 عنصرًا", i18n:p("items.count", 11))
      assert.equals("100 عنصر", i18n:p("items.count", 100))
    end)

    it("plays story in Japanese (no plurals)", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "ja" })

      i18n:loadData("ja", {
        greeting = "こんにちは！",
        items = {
          count = {
            other = "{count}個のアイテム"
          }
        }
      })

      assert.equals("こんにちは！", i18n:t("greeting"))
      assert.equals("1個のアイテム", i18n:p("items.count", 1))
      assert.equals("5個のアイテム", i18n:p("items.count", 5))
    end)

    it("plays story in Hebrew (RTL)", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "he" })

      i18n:loadData("he", {
        greeting = "שלום!",
        items = {
          count = {
            one = "פריט {count}",
            two = "{count} פריטים",
            other = "{count} פריטים"
          }
        }
      })

      assert.equals("שלום!", i18n:t("greeting"))
      assert.equals("rtl", i18n:getTextDirection())
    end)
  end)

  describe("Runtime Language Switching", function()
    it("switches language at runtime", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "en" })

      i18n:loadData("en", { greeting = "Hello!" })
      i18n:loadData("es", { greeting = "¡Hola!" })
      i18n:loadData("ja", { greeting = "こんにちは！" })

      -- Start in English
      i18n:setLocale("en")
      assert.equals("Hello!", i18n:t("greeting"))

      -- Switch to Spanish
      i18n:setLocale("es")
      assert.equals("¡Hola!", i18n:t("greeting"))

      -- Switch to Japanese
      i18n:setLocale("ja")
      assert.equals("こんにちは！", i18n:t("greeting"))
    end)

    it("maintains state through language switch", function()
      local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "en" })

      i18n:loadData("en", { test = "English {value}" })
      i18n:loadData("es", { test = "Español {value}" })

      i18n:setLocale("en")
      local result1 = i18n:t("test", { value = "123" })
      assert.equals("English 123", result1)

      i18n:setLocale("es")
      local result2 = i18n:t("test", { value = "123" })
      assert.equals("Español 123", result2)
    end)
  end)

  describe("Fallback Chain", function()
    it("falls back to base language", function()
      local i18n = I18n.new():init({
        autoDetect = false,
        defaultLocale = "en"
      })

      i18n:loadData("en", { greeting = "Hello" })
      i18n:loadData("en-US", { special = "American" })

      i18n:setLocale("en-US")

      -- en-US has special, fallback to en for greeting
      assert.equals("American", i18n:t("special"))
      assert.equals("Hello", i18n:t("greeting"))  -- Falls back to en
    end)

    it("falls back to default locale", function()
      local i18n = I18n.new():init({
        autoDetect = false,
        defaultLocale = "en"
      })

      i18n:loadData("en", { fallback = "English fallback" })
      i18n:loadData("es", { spanish = "Spanish only" })

      i18n:setLocale("es")

      assert.equals("Spanish only", i18n:t("spanish"))
      assert.equals("English fallback", i18n:t("fallback"))  -- Falls back to en
    end)
  end)

  describe("Status Report", function()
    it("reports translation coverage", function()
      local baseData = {
        greeting = "Hello",
        farewell = "Goodbye",
        menu = {
          title = "Menu",
          start = "Start"
        }
      }

      local esData = {
        greeting = "Hola",
        menu = {
          title = "Menú"
          -- Missing: start
        }
        -- Missing: farewell
      }

      local status = Status.getLocaleStatus(baseData, esData, "es")

      assert.equals("es", status.locale)
      assert.equals(4, status.baseKeys)
      assert.equals(2, status.matchingKeys)
      assert.equals(50, status.coverage)
      assert.is_false(status.complete)
    end)

    it("identifies missing keys", function()
      local baseData = { a = "1", b = "2", c = "3" }
      local targetData = { a = "x" }

      local missing = Status.getMissingKeys(baseData, targetData)

      assert.equals(2, #missing)
    end)
  end)
end)

describe("i18n Performance", function()
  local I18n

  before_each(function()
    package.loaded["whisker.i18n"] = nil
    package.loaded["whisker.i18n.init"] = nil
    I18n = require("whisker.i18n")
  end)

  it("loads 1000-string table in <100ms", function()
    local data = {}
    for i = 1, 1000 do
      data["key" .. i] = "value" .. i
    end

    local i18n = I18n.new():init({ autoDetect = false })

    local start = os.clock()
    i18n:loadData("test", data)
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 100, "Load took " .. elapsed .. "ms")
  end)

  it("looks up 10,000 keys in <1s", function()
    local data = {}
    for i = 1, 1000 do
      data["key" .. i] = "value" .. i
    end

    local i18n = I18n.new():init({ autoDetect = false })
    i18n:loadData("en", data)
    i18n:setLocale("en")

    local start = os.clock()
    for i = 1, 10000 do
      local key = "key" .. ((i % 1000) + 1)
      i18n:t(key)
    end
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 1000, "Lookup took " .. elapsed .. "ms")
  end)

  it("pluralizes 10,000 times in <1s", function()
    local i18n = I18n.new():init({ autoDetect = false, defaultLocale = "ru" })

    i18n:loadData("ru", {
      items = {
        one = "{count} item",
        few = "{count} items",
        many = "{count} items"
      }
    })

    local start = os.clock()
    for i = 0, 10000 do
      i18n:p("items", i)
    end
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 1000, "Pluralization took " .. elapsed .. "ms")
  end)

  it("handles deeply nested keys efficiently", function()
    local data = {
      level1 = {
        level2 = {
          level3 = {
            level4 = {
              level5 = "deep value"
            }
          }
        }
      }
    }

    local i18n = I18n.new():init({ autoDetect = false })
    i18n:loadData("en", data)
    i18n:setLocale("en")

    local start = os.clock()
    for i = 1, 10000 do
      i18n:t("level1.level2.level3.level4.level5")
    end
    local elapsed = (os.clock() - start) * 1000

    assert.is_true(elapsed < 500, "Deep lookup took " .. elapsed .. "ms")
  end)
end)
