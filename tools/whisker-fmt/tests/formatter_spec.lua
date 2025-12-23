-- Tests for whisker-fmt

package.path = "./tools/whisker-fmt/?.lua;./tools/whisker-fmt/lib/?.lua;" .. package.path

describe("whisker-fmt", function()
  local fmt_module

  before_each(function()
    fmt_module = require("whisker-fmt")
  end)

  describe("ConfigLoader", function()
    local ConfigLoader

    before_each(function()
      ConfigLoader = fmt_module.ConfigLoader
    end)

    it("returns default config when no file exists", function()
      local config = ConfigLoader.load("nonexistent.json")
      assert.equals("space", config.indent_style)
      assert.equals(2, config.indent_size)
      assert.equals(100, config.max_line_length)
      assert.is_true(config.normalize_whitespace)
    end)
  end)

  describe("InkFormatter", function()
    local InkFormatter
    local config

    before_each(function()
      InkFormatter = fmt_module.InkFormatter
      config = {
        indent_style = "space",
        indent_size = 2,
        normalize_whitespace = true,
        blank_lines_between = 1,
        align_choices = true
      }
    end)

    it("normalizes passage headers", function()
      local input = "===  Start   ==="
      local expected = "=== Start ===\n"
      local result = InkFormatter.format(input, config)
      assert.equals(expected, result)
    end)

    it("normalizes choice formatting", function()
      local input = [[
=== Start ===
*   [Go left]   ->  Left
]]
      local result = InkFormatter.format(input, config)
      assert.truthy(result:match("%* %[Go left%] %-> Left"))
    end)

    it("normalizes variable assignments", function()
      local input = [[
=== Start ===
~  health   =   100
]]
      local result = InkFormatter.format(input, config)
      assert.truthy(result:match("~ health = 100"))
    end)

    it("normalizes diverts", function()
      local input = [[
=== Start ===
->   Chapter1
]]
      local result = InkFormatter.format(input, config)
      assert.truthy(result:match("%-> Chapter1"))
    end)

    it("trims trailing whitespace", function()
      local input = "=== Start ===   \nHello world!   \n"
      local result = InkFormatter.format(input, config)
      assert.is_nil(result:match("   \n"))
    end)

    it("adds blank lines between passages", function()
      local input = [[=== Start ===
Hello!
=== Chapter1 ===
World!]]
      local result = InkFormatter.format(input, config)
      assert.truthy(result:match("Hello!\n\n=== Chapter1 ==="))
    end)

    it("formats comments consistently", function()
      local input = [[
=== Start ===
//    This is a comment
]]
      local result = InkFormatter.format(input, config)
      assert.truthy(result:match("// This is a comment"))
    end)

    it("is idempotent", function()
      local input = [[
=== Start ===
Welcome to the story!
* [Choice A] -> A
* [Choice B] -> B

=== A ===
You chose A.
-> End

=== B ===
You chose B.
-> End

=== End ===
The end.
]]
      local first_pass = InkFormatter.format(input, config)
      local second_pass = InkFormatter.format(first_pass, config)
      assert.equals(first_pass, second_pass)
    end)
  end)

  describe("TweeFormatter", function()
    local TweeFormatter
    local config

    before_each(function()
      TweeFormatter = fmt_module.TweeFormatter
      config = {
        indent_style = "space",
        indent_size = 2,
        normalize_whitespace = true,
        blank_lines_between = 1
      }
    end)

    it("normalizes passage headers", function()
      local input = "::   Start   "
      local expected = ":: Start\n"
      local result = TweeFormatter.format(input, config)
      assert.equals(expected, result)
    end)

    it("normalizes passage headers with tags", function()
      local input = "::   Start    [startup]"
      local result = TweeFormatter.format(input, config)
      assert.truthy(result:match(":: Start %[startup%]"))
    end)

    it("normalizes link formatting", function()
      local input = [=[
:: Start
[[  Go to chapter  |  Chapter1  ]]
]=]
      local result = TweeFormatter.format(input, config)
      assert.truthy(result:match("%[%[Go to chapter|Chapter1%]%]"))
    end)

    it("adds blank lines between passages", function()
      local input = [[:: Start
Hello!
:: Chapter1
World!]]
      local result = TweeFormatter.format(input, config)
      assert.truthy(result:match("Hello!\n\n:: Chapter1"))
    end)

    it("is idempotent", function()
      local input = [=[
:: Start
Welcome!
[[Go to A|ChapterA]]
[[Go to B|ChapterB]]

:: ChapterA
You chose A.

:: ChapterB
You chose B.
]=]
      local first_pass = TweeFormatter.format(input, config)
      local second_pass = TweeFormatter.format(first_pass, config)
      assert.equals(first_pass, second_pass)
    end)
  end)

  describe("WScriptFormatter", function()
    local WScriptFormatter
    local config

    before_each(function()
      WScriptFormatter = fmt_module.WScriptFormatter
      config = {
        indent_style = "space",
        indent_size = 2,
        normalize_whitespace = true,
        blank_lines_between = 1
      }
    end)

    it("normalizes passage declarations", function()
      local input = [[
passage   "Start"   {
text "Hello"
}
]]
      local result = WScriptFormatter.format(input, config)
      assert.truthy(result:match('passage "Start" {'))
    end)

    it("applies consistent indentation", function()
      local input = [[
passage "Start" {
text "Hello"
choice "A" {
   text "Choice A"
}
}
]]
      local result = WScriptFormatter.format(input, config)
      -- Should have proper indentation
      assert.truthy(result:match("  text"))
      assert.truthy(result:match("  choice"))
    end)

    it("adds blank lines between passages", function()
      local input = [[
passage "Start" {
text "Hello"
}
passage "Chapter1" {
text "World"
}
]]
      local result = WScriptFormatter.format(input, config)
      assert.truthy(result:match("}\n\npassage"))
    end)

    it("is idempotent", function()
      local input = [[
passage "Start" {
  text "Welcome!"
  choice "Go to A" {
    -> ChapterA
  }
}

passage "ChapterA" {
  text "You chose A."
}
]]
      local first_pass = WScriptFormatter.format(input, config)
      local second_pass = WScriptFormatter.format(first_pass, config)
      assert.equals(first_pass, second_pass)
    end)
  end)

  describe("Formatter", function()
    local Formatter

    before_each(function()
      Formatter = fmt_module.Formatter
    end)

    it("can be instantiated", function()
      local formatter = Formatter.new()
      assert.is_not_nil(formatter)
      assert.is_not_nil(formatter.config)
      assert.is_not_nil(formatter.formatters)
    end)

    it("formats ink content", function()
      local formatter = Formatter.new()
      local input = "===  Start  ===\nHello!   "
      local result = formatter:format_content(input, "ink")
      assert.is_not_nil(result)
      assert.truthy(result:match("=== Start ==="))
    end)

    it("formats twee content", function()
      local formatter = Formatter.new()
      local input = "::   Start   \nHello!   "
      local result = formatter:format_content(input, "twee")
      assert.is_not_nil(result)
      assert.truthy(result:match(":: Start"))
    end)

    it("formats wscript content", function()
      local formatter = Formatter.new()
      local input = 'passage "Start" {\ntext "Hello"\n}'
      local result = formatter:format_content(input, "wscript")
      assert.is_not_nil(result)
    end)

    it("returns error for unsupported format", function()
      local formatter = Formatter.new()
      local result, err = formatter:format_content("content", "unknown")
      assert.is_nil(result)
      assert.truthy(err:match("Unsupported"))
    end)

    it("formats files correctly", function()
      local formatter = Formatter.new()

      -- Create a test file
      local test_file = "/tmp/test_story.ink"
      local f = io.open(test_file, "w")
      f:write("===  Start  ===\nHello!   \n")
      f:close()

      -- Format with check mode
      local changed = formatter:format_file(test_file, {check = true})
      assert.is_true(changed)

      os.remove(test_file)
    end)
  end)
end)
