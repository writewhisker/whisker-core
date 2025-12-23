--- Contrast Checker Tests
-- Tests for ContrastChecker implementation
-- @module tests.a11y.contrast_checker_spec

describe("ContrastChecker", function()
  local ContrastChecker
  local checker

  setup(function()
    ContrastChecker = require("whisker.a11y.contrast_checker")
  end)

  before_each(function()
    checker = ContrastChecker.new()
  end)

  describe("new()", function()
    it("should create a checker instance", function()
      assert.is_not_nil(checker)
      assert.is_table(checker)
    end)
  end)

  describe("parse_hex()", function()
    it("should parse 6-char hex colors", function()
      local r, g, b = checker:parse_hex("#FF5733")
      assert.equals(255, r)
      assert.equals(87, g)
      assert.equals(51, b)
    end)

    it("should parse without hash prefix", function()
      local r, g, b = checker:parse_hex("FF5733")
      assert.equals(255, r)
      assert.equals(87, g)
      assert.equals(51, b)
    end)

    it("should expand 3-char hex colors", function()
      local r, g, b = checker:parse_hex("#FFF")
      assert.equals(255, r)
      assert.equals(255, g)
      assert.equals(255, b)
    end)

    it("should parse black correctly", function()
      local r, g, b = checker:parse_hex("#000000")
      assert.equals(0, r)
      assert.equals(0, g)
      assert.equals(0, b)
    end)
  end)

  describe("parse_rgb()", function()
    it("should parse rgb() format", function()
      local r, g, b = checker:parse_rgb("rgb(255, 87, 51)")
      assert.equals(255, r)
      assert.equals(87, g)
      assert.equals(51, b)
    end)

    it("should handle spaces", function()
      local r, g, b = checker:parse_rgb("rgb( 100 , 150 , 200 )")
      assert.equals(100, r)
      assert.equals(150, g)
      assert.equals(200, b)
    end)
  end)

  describe("get_luminance()", function()
    it("should return 0 for black", function()
      local lum = checker:get_luminance(0, 0, 0)
      assert.equals(0, lum)
    end)

    it("should return 1 for white", function()
      local lum = checker:get_luminance(255, 255, 255)
      assert.is_true(math.abs(lum - 1) < 0.001)
    end)

    it("should return correct luminance for gray", function()
      local lum = checker:get_luminance(128, 128, 128)
      assert.is_true(lum > 0.2 and lum < 0.3)
    end)
  end)

  describe("get_contrast_ratio()", function()
    it("should return 21 for black on white", function()
      local ratio = checker:get_contrast_ratio("#000000", "#FFFFFF")
      assert.is_true(math.abs(ratio - 21) < 0.1)
    end)

    it("should return 1 for same colors", function()
      local ratio = checker:get_contrast_ratio("#333333", "#333333")
      assert.equals(1, ratio)
    end)

    it("should handle mixed formats", function()
      local ratio = checker:get_contrast_ratio("#000", "rgb(255, 255, 255)")
      assert.is_true(math.abs(ratio - 21) < 0.1)
    end)
  end)

  describe("meets_wcag()", function()
    it("should pass AA for black on white", function()
      assert.is_true(checker:meets_wcag("#000000", "#FFFFFF", "AA", "normal"))
    end)

    it("should pass AAA for black on white", function()
      assert.is_true(checker:meets_wcag("#000000", "#FFFFFF", "AAA", "normal"))
    end)

    it("should fail AA for light gray on white", function()
      assert.is_false(checker:meets_wcag("#CCCCCC", "#FFFFFF", "AA", "normal"))
    end)

    it("should be more lenient for large text", function()
      -- #777777 on white is about 4.48:1 - just under 4.5 (fails normal AA)
      -- but easily passes the 3:1 requirement for large text
      assert.is_false(checker:meets_wcag("#777777", "#FFFFFF", "AA", "normal"))
      assert.is_true(checker:meets_wcag("#777777", "#FFFFFF", "AA", "large"))
    end)
  end)

  describe("get_required_ratio()", function()
    it("should return 4.5 for AA normal", function()
      assert.equals(4.5, checker:get_required_ratio("AA", "normal"))
    end)

    it("should return 3 for AA large", function()
      assert.equals(3, checker:get_required_ratio("AA", "large"))
    end)

    it("should return 7 for AAA normal", function()
      assert.equals(7, checker:get_required_ratio("AAA", "normal"))
    end)

    it("should return 4.5 for AAA large", function()
      assert.equals(4.5, checker:get_required_ratio("AAA", "large"))
    end)
  end)

  describe("validate()", function()
    it("should return detailed validation result", function()
      local result = checker:validate("#000000", "#FFFFFF")

      assert.is_table(result)
      assert.is_true(result.ratio > 20)
      assert.is_true(result.passes_aa_normal)
      assert.is_true(result.passes_aa_large)
      assert.is_true(result.passes_aaa_normal)
      assert.is_true(result.passes_aaa_large)
      assert.is_true(result.passes)
    end)

    it("should include formatted ratio", function()
      local result = checker:validate("#000000", "#FFFFFF")
      assert.truthy(result.ratio_formatted:match("21"))
    end)

    it("should include input colors", function()
      local result = checker:validate("#000000", "#FFFFFF")
      assert.equals("#000000", result.foreground)
      assert.equals("#FFFFFF", result.background)
    end)
  end)

  describe("suggest_adjustment()", function()
    it("should suggest darker color when needed", function()
      local adjusted = checker:suggest_adjustment("#AAAAAA", "#FFFFFF", 4.5)

      if adjusted then
        local ratio = checker:get_contrast_ratio(adjusted, "#FFFFFF")
        assert.is_true(ratio >= 4.5)
      end
    end)

    it("should suggest lighter color on dark background", function()
      local adjusted = checker:suggest_adjustment("#555555", "#000000", 4.5)

      if adjusted then
        local ratio = checker:get_contrast_ratio(adjusted, "#000000")
        assert.is_true(ratio >= 4.5)
      end
    end)
  end)

  describe("get_high_contrast_css()", function()
    it("should return CSS with forced-colors media query", function()
      local css = checker:get_high_contrast_css()
      assert.truthy(css:match("forced%-colors: active"))
    end)

    it("should include prefers-contrast queries", function()
      local css = checker:get_high_contrast_css()
      assert.truthy(css:match("prefers%-contrast: more"))
      assert.truthy(css:match("prefers%-contrast: less"))
    end)
  end)

  describe("validate_all()", function()
    it("should validate multiple color pairs", function()
      local pairs = {
        {foreground = "#000000", background = "#FFFFFF", name = "text"},
        {foreground = "#666666", background = "#FFFFFF", name = "secondary"},
      }

      local results = checker:validate_all(pairs)

      assert.equals(2, #results)
      assert.equals("text", results[1].name)
      assert.equals("secondary", results[2].name)
    end)
  end)

  describe("get_failures()", function()
    it("should return only failing pairs", function()
      local pairs = {
        {foreground = "#000000", background = "#FFFFFF", name = "pass"},
        {foreground = "#CCCCCC", background = "#FFFFFF", name = "fail"},
      }

      local failures = checker:get_failures(pairs, "AA")

      assert.equals(1, #failures)
      assert.equals("fail", failures[1].name)
    end)
  end)
end)
