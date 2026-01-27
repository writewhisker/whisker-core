-- tests/presentation/test_theme_and_style.lua
-- Tests for GAP-040, GAP-041, GAP-042: Theme and Style Features

local ws_parser = require("whisker.parser.ws_parser")

describe("Theme and Style Parsing", function()
  local parser

  before_each(function()
    parser = ws_parser.new()
  end)

  -- GAP-040: THEME Directive
  describe("THEME Directive (GAP-040)", function()
    it("should parse @theme directive with single theme", function()
      local input = [[
@theme: dark

:: Start
Hello world
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_not_nil(result.story.metadata.themes)
      assert.equals(1, #result.story.metadata.themes)
      assert.equals("dark", result.story.metadata.themes[1])
    end)

    it("should parse @theme directive with multiple themes", function()
      local input = [[
@theme: dark, high-contrast

:: Start
Hello world
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.equals(2, #result.story.metadata.themes)
      assert.equals("dark", result.story.metadata.themes[1])
      assert.equals("high-contrast", result.story.metadata.themes[2])
    end)

    it("should parse @theme with quoted theme name", function()
      local input = [[
@theme: "custom-theme"

:: Start
Hello world
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.equals("custom-theme", result.story.metadata.themes[1])
    end)

    it("should parse @theme with light theme", function()
      local input = [[
@theme: light

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.equals("light", result.story.metadata.themes[1])
    end)

    it("should trim whitespace from theme names", function()
      local input = [[
@theme:   dark  ,   light

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.equals("dark", result.story.metadata.themes[1])
      assert.equals("light", result.story.metadata.themes[2])
    end)
  end)

  -- GAP-041: STYLE Block
  describe("STYLE Block (GAP-041)", function()
    it("should parse simple @style block", function()
      local input = [[
@style {
    .custom-class {
        color: red;
    }
}

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_not_nil(result.story.metadata.custom_styles)
      assert.equals(1, #result.story.metadata.custom_styles)
      assert.is_not_nil(result.story.metadata.custom_styles[1]:match("color: red"))
    end)

    it("should parse @style block with nested rules", function()
      local input = [[
@style {
    .parent {
        .child {
            color: blue;
        }
    }
}

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_not_nil(result.story.metadata.custom_styles[1]:match("%.child"))
    end)

    it("should parse multiple @style blocks", function()
      local input = [[
@style {
    .first { color: red; }
}

@style {
    .second { color: blue; }
}

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.equals(2, #result.story.metadata.custom_styles)
    end)

    it("should preserve CSS content exactly", function()
      local input = [[
@style {
    passage.combat {
        background: linear-gradient(to bottom, #300, #100);
        font-weight: bold;
    }
}

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      local css = result.story.metadata.custom_styles[1]
      assert.is_not_nil(css:match("passage%.combat"))
      assert.is_not_nil(css:match("linear%-gradient"))
    end)

    it("should handle @style with both theme and style", function()
      local input = [[
@theme: dark
@style {
    .dark-mode { opacity: 0.9; }
}

:: Start
Content
]]
      local result = parser:parse(input)
      assert.is_not_nil(result)
      assert.equals("dark", result.story.metadata.themes[1])
      assert.equals(1, #result.story.metadata.custom_styles)
    end)
  end)
end)

-- GAP-042: Theme CSS Variables
describe("CSS Variables Module (GAP-042)", function()
  local CSSVariables

  before_each(function()
    package.loaded["whisker.export.html.css_variables"] = nil
    CSSVariables = require("whisker.export.html.css_variables")
  end)

  describe("BASE variables", function()
    it("should define all required CSS variables", function()
      local base = CSSVariables.BASE
      assert.is_not_nil(base)

      -- Check color variables
      assert.is_not_nil(base:match("%-%-ws%-bg%-color"))
      assert.is_not_nil(base:match("%-%-ws%-text%-color"))
      assert.is_not_nil(base:match("%-%-ws%-link%-color"))

      -- Check choice variables
      assert.is_not_nil(base:match("%-%-ws%-choice%-bg"))
      assert.is_not_nil(base:match("%-%-ws%-choice%-hover%-bg"))
      assert.is_not_nil(base:match("%-%-ws%-choice%-text%-color"))

      -- Check typography variables
      assert.is_not_nil(base:match("%-%-ws%-font%-family"))
      assert.is_not_nil(base:match("%-%-ws%-font%-size"))
      assert.is_not_nil(base:match("%-%-ws%-line%-height"))

      -- Check spacing variables
      assert.is_not_nil(base:match("%-%-ws%-passage%-padding"))
      assert.is_not_nil(base:match("%-%-ws%-choice%-margin"))
    end)
  end)

  describe("DARK_THEME", function()
    it("should define dark theme overrides", function()
      local dark = CSSVariables.DARK_THEME
      assert.is_not_nil(dark)
      assert.is_not_nil(dark:match("whisker%-theme%-dark"))
      assert.is_not_nil(dark:match("%-%-ws%-bg%-color"))
    end)
  end)

  describe("HIGH_CONTRAST_THEME", function()
    it("should define high contrast theme overrides", function()
      local hc = CSSVariables.HIGH_CONTRAST_THEME
      assert.is_not_nil(hc)
      assert.is_not_nil(hc:match("whisker%-theme%-high%-contrast"))
    end)
  end)

  describe("get_theme_css", function()
    it("should return base CSS for no themes", function()
      local css = CSSVariables.get_theme_css({})
      assert.is_not_nil(css)
      assert.is_not_nil(css:match(":root"))
    end)

    it("should include dark theme CSS", function()
      local css = CSSVariables.get_theme_css({"dark"})
      assert.is_not_nil(css)
      assert.is_not_nil(css:match("whisker%-theme%-dark"))
    end)

    it("should include multiple theme CSS", function()
      local css = CSSVariables.get_theme_css({"dark", "high-contrast"})
      assert.is_not_nil(css)
      assert.is_not_nil(css:match("whisker%-theme%-dark"))
      assert.is_not_nil(css:match("whisker%-theme%-high%-contrast"))
    end)

    it("should include component styles", function()
      local css = CSSVariables.get_theme_css({})
      assert.is_not_nil(css)
      assert.is_not_nil(css:match("%.whisker%-passage"))
      assert.is_not_nil(css:match("%.whisker%-choice"))
    end)
  end)

  describe("get_theme_classes", function()
    it("should return empty string for no themes", function()
      local classes = CSSVariables.get_theme_classes({})
      assert.equals("", classes)
    end)

    it("should return single theme class", function()
      local classes = CSSVariables.get_theme_classes({"dark"})
      assert.equals("whisker-theme-dark", classes)
    end)

    it("should return multiple theme classes", function()
      local classes = CSSVariables.get_theme_classes({"dark", "high-contrast"})
      assert.equals("whisker-theme-dark whisker-theme-high-contrast", classes)
    end)
  end)

  describe("get_available_themes", function()
    it("should return list of built-in themes", function()
      local themes = CSSVariables.get_available_themes()
      assert.is_table(themes)
      assert.is_true(#themes >= 3)

      -- Check for standard themes
      local has_light = false
      local has_dark = false
      local has_high_contrast = false

      for _, theme in ipairs(themes) do
        if theme == "light" then has_light = true end
        if theme == "dark" then has_dark = true end
        if theme == "high-contrast" then has_high_contrast = true end
      end

      assert.is_true(has_light)
      assert.is_true(has_dark)
      assert.is_true(has_high_contrast)
    end)
  end)
end)
