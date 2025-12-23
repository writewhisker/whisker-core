-- tests/unit/i18n/bidi_spec.lua
-- Unit tests for BiDi (Bidirectional Text) module (Stage 6)

describe("BiDi", function()
  local bidi

  before_each(function()
    package.loaded["whisker.i18n.bidi"] = nil
    bidi = require("whisker.i18n.bidi")
  end)

  describe("module", function()
    it("has version", function()
      assert.equals("1.0.0", bidi._VERSION)
    end)

    it("exports MARKS table", function()
      assert.is_table(bidi.MARKS)
      assert.is_string(bidi.MARKS.LRM)
      assert.is_string(bidi.MARKS.RLM)
    end)
  end)

  describe("getDirection()", function()
    it("returns 'ltr' for English", function()
      assert.equals("ltr", bidi.getDirection("en"))
      assert.equals("ltr", bidi.getDirection("en-US"))
      assert.equals("ltr", bidi.getDirection("en-GB"))
    end)

    it("returns 'ltr' for other LTR languages", function()
      assert.equals("ltr", bidi.getDirection("es"))
      assert.equals("ltr", bidi.getDirection("fr"))
      assert.equals("ltr", bidi.getDirection("de"))
      assert.equals("ltr", bidi.getDirection("ja"))
      assert.equals("ltr", bidi.getDirection("zh"))
      assert.equals("ltr", bidi.getDirection("ru"))
    end)

    it("returns 'rtl' for Arabic", function()
      assert.equals("rtl", bidi.getDirection("ar"))
      assert.equals("rtl", bidi.getDirection("ar-SA"))
      assert.equals("rtl", bidi.getDirection("ar-EG"))
    end)

    it("returns 'rtl' for Hebrew", function()
      assert.equals("rtl", bidi.getDirection("he"))
      assert.equals("rtl", bidi.getDirection("he-IL"))
      assert.equals("rtl", bidi.getDirection("iw"))  -- old code
    end)

    it("returns 'rtl' for Persian/Farsi", function()
      assert.equals("rtl", bidi.getDirection("fa"))
      assert.equals("rtl", bidi.getDirection("fa-IR"))
    end)

    it("returns 'rtl' for Urdu", function()
      assert.equals("rtl", bidi.getDirection("ur"))
      assert.equals("rtl", bidi.getDirection("ur-PK"))
    end)

    it("returns 'rtl' for Yiddish", function()
      assert.equals("rtl", bidi.getDirection("yi"))
      assert.equals("rtl", bidi.getDirection("ji"))  -- old code
    end)

    it("returns 'rtl' for other RTL languages", function()
      assert.equals("rtl", bidi.getDirection("ps"))   -- Pashto
      assert.equals("rtl", bidi.getDirection("sd"))   -- Sindhi
      assert.equals("rtl", bidi.getDirection("ug"))   -- Uyghur
      assert.equals("rtl", bidi.getDirection("dv"))   -- Dhivehi
      assert.equals("rtl", bidi.getDirection("ckb"))  -- Central Kurdish
    end)

    it("handles nil input", function()
      assert.equals("ltr", bidi.getDirection(nil))
    end)

    it("handles non-string input", function()
      assert.equals("ltr", bidi.getDirection(123))
      assert.equals("ltr", bidi.getDirection({}))
    end)

    it("is case-insensitive for language code", function()
      assert.equals("rtl", bidi.getDirection("AR"))
      assert.equals("rtl", bidi.getDirection("He"))
      assert.equals("ltr", bidi.getDirection("EN"))
    end)
  end)

  describe("isRTL()", function()
    it("returns true for RTL locales", function()
      assert.is_true(bidi.isRTL("ar"))
      assert.is_true(bidi.isRTL("he"))
      assert.is_true(bidi.isRTL("fa"))
      assert.is_true(bidi.isRTL("ur"))
    end)

    it("returns false for LTR locales", function()
      assert.is_false(bidi.isRTL("en"))
      assert.is_false(bidi.isRTL("es"))
      assert.is_false(bidi.isRTL("fr"))
      assert.is_false(bidi.isRTL("ja"))
    end)
  end)

  describe("isLTR()", function()
    it("returns true for LTR locales", function()
      assert.is_true(bidi.isLTR("en"))
      assert.is_true(bidi.isLTR("es"))
      assert.is_true(bidi.isLTR("zh"))
    end)

    it("returns false for RTL locales", function()
      assert.is_false(bidi.isLTR("ar"))
      assert.is_false(bidi.isLTR("he"))
    end)
  end)

  describe("wrap()", function()
    it("wraps RTL text with RLE and PDF", function()
      local result = bidi.wrap("مرحبا", "rtl")
      assert.equals(bidi.MARKS.RLE .. "مرحبا" .. bidi.MARKS.PDF, result)
    end)

    it("wraps LTR text with LRE and PDF", function()
      local result = bidi.wrap("Hello", "ltr")
      assert.equals(bidi.MARKS.LRE .. "Hello" .. bidi.MARKS.PDF, result)
    end)

    it("handles locale code as direction", function()
      local result = bidi.wrap("مرحبا", "ar")
      assert.equals(bidi.MARKS.RLE .. "مرحبا" .. bidi.MARKS.PDF, result)
    end)

    it("handles empty text", function()
      assert.equals("", bidi.wrap("", "rtl"))
    end)

    it("handles nil text", function()
      assert.equals("", bidi.wrap(nil, "rtl"))
    end)
  end)

  describe("isolate()", function()
    it("isolates RTL text with RLI and PDI", function()
      local result = bidi.isolate("مرحبا", "rtl")
      assert.equals(bidi.MARKS.RLI .. "مرحبا" .. bidi.MARKS.PDI, result)
    end)

    it("isolates LTR text with LRI and PDI", function()
      local result = bidi.isolate("Hello", "ltr")
      assert.equals(bidi.MARKS.LRI .. "Hello" .. bidi.MARKS.PDI, result)
    end)

    it("uses FSI for auto direction", function()
      local result = bidi.isolate("Hello", "auto")
      assert.equals(bidi.MARKS.FSI .. "Hello" .. bidi.MARKS.PDI, result)
    end)

    it("handles locale code as direction", function()
      local result = bidi.isolate("שלום", "he")
      assert.equals(bidi.MARKS.RLI .. "שלום" .. bidi.MARKS.PDI, result)
    end)

    it("handles empty text", function()
      assert.equals("", bidi.isolate("", "rtl"))
    end)

    it("handles nil text", function()
      assert.equals("", bidi.isolate(nil, "ltr"))
    end)
  end)

  describe("mark()", function()
    it("adds RLM before RTL text", function()
      local result = bidi.mark("مرحبا", "rtl")
      assert.equals(bidi.MARKS.RLM .. "مرحبا", result)
    end)

    it("adds LRM before LTR text", function()
      local result = bidi.mark("Hello", "ltr")
      assert.equals(bidi.MARKS.LRM .. "Hello", result)
    end)

    it("handles nil text", function()
      assert.equals("", bidi.mark(nil, "rtl"))
    end)
  end)

  describe("htmlDir()", function()
    it("generates dir attribute for RTL", function()
      assert.equals('dir="rtl"', bidi.htmlDir("ar"))
      assert.equals('dir="rtl"', bidi.htmlDir("he"))
    end)

    it("generates dir attribute for LTR", function()
      assert.equals('dir="ltr"', bidi.htmlDir("en"))
      assert.equals('dir="ltr"', bidi.htmlDir("es"))
    end)
  end)

  describe("htmlSpan()", function()
    it("generates span for RTL text", function()
      local result = bidi.htmlSpan("مرحبا", "ar")
      assert.equals('<span dir="rtl">مرحبا</span>', result)
    end)

    it("generates span for LTR text", function()
      local result = bidi.htmlSpan("Hello", "en")
      assert.equals('<span dir="ltr">Hello</span>', result)
    end)

    it("escapes HTML entities", function()
      local result = bidi.htmlSpan("<script>alert('xss')</script>", "en")
      assert.equals('<span dir="ltr">&lt;script&gt;alert(\'xss\')&lt;/script&gt;</span>', result)
    end)

    it("escapes ampersand", function()
      local result = bidi.htmlSpan("A & B", "en")
      assert.equals('<span dir="ltr">A &amp; B</span>', result)
    end)

    it("escapes quotes", function()
      local result = bidi.htmlSpan('Say "Hello"', "en")
      assert.equals('<span dir="ltr">Say &quot;Hello&quot;</span>', result)
    end)
  end)

  describe("htmlBdi()", function()
    it("generates bdi element without direction", function()
      local result = bidi.htmlBdi("Username")
      assert.equals('<bdi>Username</bdi>', result)
    end)

    it("generates bdi with direction when locale provided", function()
      local result = bidi.htmlBdi("مستخدم", "ar")
      assert.equals('<bdi dir="rtl">مستخدم</bdi>', result)
    end)

    it("escapes HTML entities", function()
      local result = bidi.htmlBdi("<user>")
      assert.equals('<bdi>&lt;user&gt;</bdi>', result)
    end)
  end)

  describe("cssDirection()", function()
    it("returns 'rtl' for RTL locales", function()
      assert.equals("rtl", bidi.cssDirection("ar"))
      assert.equals("rtl", bidi.cssDirection("he"))
    end)

    it("returns 'ltr' for LTR locales", function()
      assert.equals("ltr", bidi.cssDirection("en"))
      assert.equals("ltr", bidi.cssDirection("es"))
    end)
  end)

  describe("cssTextAlign()", function()
    it("returns 'right' for RTL locales", function()
      assert.equals("right", bidi.cssTextAlign("ar"))
      assert.equals("right", bidi.cssTextAlign("he"))
    end)

    it("returns 'left' for LTR locales", function()
      assert.equals("left", bidi.cssTextAlign("en"))
      assert.equals("left", bidi.cssTextAlign("es"))
    end)
  end)

  describe("detectFromText()", function()
    it("returns 'ltr' for Latin text", function()
      assert.equals("ltr", bidi.detectFromText("Hello World"))
      assert.equals("ltr", bidi.detectFromText("Bonjour"))
    end)

    it("returns 'rtl' for Arabic text", function()
      assert.equals("rtl", bidi.detectFromText("مرحبا"))
      assert.equals("rtl", bidi.detectFromText("السلام عليكم"))
    end)

    it("returns 'rtl' for Hebrew text", function()
      assert.equals("rtl", bidi.detectFromText("שלום"))
      assert.equals("rtl", bidi.detectFromText("עברית"))
    end)

    it("returns 'neutral' for numbers only", function()
      assert.equals("neutral", bidi.detectFromText("12345"))
    end)

    it("returns 'neutral' for empty text", function()
      assert.equals("neutral", bidi.detectFromText(""))
    end)

    it("returns 'neutral' for nil", function()
      assert.equals("neutral", bidi.detectFromText(nil))
    end)

    it("detects based on first strong character", function()
      -- Number followed by Arabic
      assert.equals("rtl", bidi.detectFromText("123 مرحبا"))
      -- Number followed by Latin
      assert.equals("ltr", bidi.detectFromText("123 Hello"))
    end)

    it("handles mixed text by first strong char", function()
      -- Latin first
      assert.equals("ltr", bidi.detectFromText("Hello مرحبا"))
      -- Arabic first
      assert.equals("rtl", bidi.detectFromText("مرحبا Hello"))
    end)
  end)

  describe("stripMarks()", function()
    it("removes all BiDi control characters", function()
      local text = bidi.MARKS.LRM .. "Hello" .. bidi.MARKS.RLM
      assert.equals("Hello", bidi.stripMarks(text))
    end)

    it("removes embedding markers", function()
      local text = bidi.MARKS.RLE .. "مرحبا" .. bidi.MARKS.PDF
      assert.equals("مرحبا", bidi.stripMarks(text))
    end)

    it("removes isolate markers", function()
      local text = bidi.MARKS.RLI .. "שלום" .. bidi.MARKS.PDI
      assert.equals("שלום", bidi.stripMarks(text))
    end)

    it("handles nil input", function()
      assert.equals("", bidi.stripMarks(nil))
    end)

    it("handles text without marks", function()
      assert.equals("Hello", bidi.stripMarks("Hello"))
    end)
  end)

  describe("containsRTL()", function()
    it("returns true for Arabic text", function()
      assert.is_true(bidi.containsRTL("مرحبا"))
    end)

    it("returns true for Hebrew text", function()
      assert.is_true(bidi.containsRTL("שלום"))
    end)

    it("returns false for Latin text", function()
      assert.is_false(bidi.containsRTL("Hello"))
    end)

    it("returns false for empty text", function()
      assert.is_false(bidi.containsRTL(""))
    end)
  end)

  describe("getRTLLanguages()", function()
    it("returns array of RTL language codes", function()
      local langs = bidi.getRTLLanguages()
      assert.is_table(langs)
      assert.is_true(#langs > 5)
    end)

    it("includes common RTL languages", function()
      local langs = bidi.getRTLLanguages()
      local langSet = {}
      for _, lang in ipairs(langs) do
        langSet[lang] = true
      end

      assert.is_true(langSet["ar"])
      assert.is_true(langSet["he"])
      assert.is_true(langSet["fa"])
      assert.is_true(langSet["ur"])
    end)

    it("returns sorted array", function()
      local langs = bidi.getRTLLanguages()
      for i = 2, #langs do
        assert.is_true(langs[i] >= langs[i-1], "Languages not sorted: " .. langs[i-1] .. " > " .. langs[i])
      end
    end)
  end)

  describe("isRTLLanguage()", function()
    it("returns true for RTL language codes", function()
      assert.is_true(bidi.isRTLLanguage("ar"))
      assert.is_true(bidi.isRTLLanguage("he"))
      assert.is_true(bidi.isRTLLanguage("fa"))
    end)

    it("returns false for LTR language codes", function()
      assert.is_false(bidi.isRTLLanguage("en"))
      assert.is_false(bidi.isRTLLanguage("es"))
      assert.is_false(bidi.isRTLLanguage("ja"))
    end)

    it("is case-insensitive", function()
      assert.is_true(bidi.isRTLLanguage("AR"))
      assert.is_true(bidi.isRTLLanguage("He"))
    end)

    it("handles nil", function()
      assert.is_false(bidi.isRTLLanguage(nil))
    end)
  end)
end)

describe("BiDi MARKS constants", function()
  local bidi

  before_each(function()
    package.loaded["whisker.i18n.bidi"] = nil
    bidi = require("whisker.i18n.bidi")
  end)

  it("has correct LRM (U+200E)", function()
    assert.equals("\xE2\x80\x8E", bidi.MARKS.LRM)
  end)

  it("has correct RLM (U+200F)", function()
    assert.equals("\xE2\x80\x8F", bidi.MARKS.RLM)
  end)

  it("has correct LRE (U+202A)", function()
    assert.equals("\xE2\x80\xAA", bidi.MARKS.LRE)
  end)

  it("has correct RLE (U+202B)", function()
    assert.equals("\xE2\x80\xAB", bidi.MARKS.RLE)
  end)

  it("has correct PDF (U+202C)", function()
    assert.equals("\xE2\x80\xAC", bidi.MARKS.PDF)
  end)

  it("has correct LRI (U+2066)", function()
    assert.equals("\xE2\x81\xA6", bidi.MARKS.LRI)
  end)

  it("has correct RLI (U+2067)", function()
    assert.equals("\xE2\x81\xA7", bidi.MARKS.RLI)
  end)

  it("has correct FSI (U+2068)", function()
    assert.equals("\xE2\x81\xA8", bidi.MARKS.FSI)
  end)

  it("has correct PDI (U+2069)", function()
    assert.equals("\xE2\x81\xA9", bidi.MARKS.PDI)
  end)
end)
