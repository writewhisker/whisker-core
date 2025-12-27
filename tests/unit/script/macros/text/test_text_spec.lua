--- Text Macros Unit Tests
-- Tests for text formatting and output macros
-- @module tests.unit.script.macros.text.test_text_spec

describe("Text Macros", function()
  local Macros, Text, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Text = require("whisker.script.macros.text")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Text.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Text.VERSION)
    end)

    it("exports text macros", function()
      -- Text output
      assert.is_table(Text.print_macro)
      assert.is_table(Text.display_macro)
      assert.is_table(Text.nobr_macro)
      assert.is_table(Text.silently_macro)
      assert.is_table(Text.verbatim_macro)

      -- Text formatting
      assert.is_table(Text.uppercase_macro)
      assert.is_table(Text.lowercase_macro)
      assert.is_table(Text.upperfirst_macro)
      assert.is_table(Text.lowerfirst_macro)
      assert.is_table(Text.trim_macro)
      assert.is_table(Text.wordcount_macro)
      assert.is_table(Text.substring_macro)
      assert.is_table(Text.replace_macro)
      assert.is_table(Text.split_macro)
      assert.is_table(Text.join_macro)
      assert.is_table(Text.pluralize_macro)

      -- Links
      assert.is_table(Text.link_macro)
      assert.is_table(Text.link_goto_macro)
      assert.is_table(Text.link_reveal_macro)
      assert.is_table(Text.link_repeat_macro)
      assert.is_table(Text.goto_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Text.register_all)
    end)
  end)

  describe("print macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("outputs string value", function()
      local result = Text.print_macro.handler(ctx, { "hello" })
      assert.equals("hello", result)
    end)

    it("outputs number value", function()
      local result = Text.print_macro.handler(ctx, { 42 })
      assert.equals("42", result)
    end)

    it("writes to context output", function()
      Text.print_macro.handler(ctx, { "output" })
      assert.equals("output", ctx:get_output())
    end)

    it("handles nil value", function()
      local result = Text.print_macro.handler(ctx, { nil })
      assert.equals("", result)
    end)

    it("is text category", function()
      assert.equals("text", Text.print_macro.category)
    end)
  end)

  describe("nobr macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("removes line breaks", function()
      local result = Text.nobr_macro.handler(ctx, { "line1\nline2\nline3" })
      assert.equals("line1 line2 line3", result)
    end)

    it("collapses whitespace", function()
      local result = Text.nobr_macro.handler(ctx, { "  multiple   spaces  " })
      assert.equals("multiple spaces", result)
    end)

    it("handles function body", function()
      local body = function(c) return "func result\nwith newline" end
      local result = Text.nobr_macro.handler(ctx, { body })
      assert.equals("func result with newline", result)
    end)
  end)

  describe("silently macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("executes function without output", function()
      local executed = false
      local fn = function(c)
        executed = true
        return "should not appear"
      end

      local result = Text.silently_macro.handler(ctx, { fn })

      assert.is_true(executed)
      assert.is_nil(result)
    end)

    it("returns nil", function()
      local result = Text.silently_macro.handler(ctx, { "content" })
      assert.is_nil(result)
    end)
  end)

  describe("verbatim macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("outputs content as-is", function()
      local result = Text.verbatim_macro.handler(ctx, { "<<not a macro>>" })
      assert.equals("<<not a macro>>", result)
    end)

    it("writes to output", function()
      Text.verbatim_macro.handler(ctx, { "raw text" })
      assert.equals("raw text", ctx:get_output())
    end)

    it("is pure", function()
      assert.is_true(Text.verbatim_macro.pure)
    end)
  end)

  describe("uppercase macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("converts to uppercase", function()
      local result = Text.uppercase_macro.handler(ctx, { "hello" })
      assert.equals("HELLO", result)
    end)

    it("handles mixed case", function()
      local result = Text.uppercase_macro.handler(ctx, { "HeLLo WoRLd" })
      assert.equals("HELLO WORLD", result)
    end)

    it("is pure", function()
      assert.is_true(Text.uppercase_macro.pure)
    end)
  end)

  describe("lowercase macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("converts to lowercase", function()
      local result = Text.lowercase_macro.handler(ctx, { "HELLO" })
      assert.equals("hello", result)
    end)

    it("is pure", function()
      assert.is_true(Text.lowercase_macro.pure)
    end)
  end)

  describe("upperfirst macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("capitalizes first character", function()
      local result = Text.upperfirst_macro.handler(ctx, { "hello" })
      assert.equals("Hello", result)
    end)

    it("handles empty string", function()
      local result = Text.upperfirst_macro.handler(ctx, { "" })
      assert.equals("", result)
    end)

    it("leaves rest unchanged", function()
      local result = Text.upperfirst_macro.handler(ctx, { "hELLO" })
      assert.equals("HELLO", result)
    end)
  end)

  describe("lowerfirst macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("lowercases first character", function()
      local result = Text.lowerfirst_macro.handler(ctx, { "Hello" })
      assert.equals("hello", result)
    end)

    it("handles empty string", function()
      local result = Text.lowerfirst_macro.handler(ctx, { "" })
      assert.equals("", result)
    end)
  end)

  describe("trim macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("removes leading whitespace", function()
      local result = Text.trim_macro.handler(ctx, { "   hello" })
      assert.equals("hello", result)
    end)

    it("removes trailing whitespace", function()
      local result = Text.trim_macro.handler(ctx, { "hello   " })
      assert.equals("hello", result)
    end)

    it("removes both", function()
      local result = Text.trim_macro.handler(ctx, { "  hello world  " })
      assert.equals("hello world", result)
    end)
  end)

  describe("wordcount macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("counts words", function()
      local result = Text.wordcount_macro.handler(ctx, { "hello world" })
      assert.equals(2, result)
    end)

    it("handles multiple spaces", function()
      local result = Text.wordcount_macro.handler(ctx, { "one   two    three" })
      assert.equals(3, result)
    end)

    it("returns 0 for empty string", function()
      local result = Text.wordcount_macro.handler(ctx, { "" })
      assert.equals(0, result)
    end)

    it("returns 0 for non-string", function()
      local result = Text.wordcount_macro.handler(ctx, { 123 })
      assert.equals(0, result)
    end)
  end)

  describe("substring macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("extracts substring", function()
      local result = Text.substring_macro.handler(ctx, { "hello", 2, 4 })
      assert.equals("ell", result)
    end)

    it("defaults to end of string", function()
      local result = Text.substring_macro.handler(ctx, { "hello", 3 })
      assert.equals("llo", result)
    end)

    it("handles full string", function()
      local result = Text.substring_macro.handler(ctx, { "hello" })
      assert.equals("hello", result)
    end)
  end)

  describe("replace macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("replaces text", function()
      local result = Text.replace_macro.handler(ctx, { "hello world", "world", "there" })
      assert.equals("hello there", result)
    end)

    it("replaces all occurrences", function()
      local result = Text.replace_macro.handler(ctx, { "a-b-c", "-", "." })
      assert.equals("a.b.c", result)
    end)

    it("handles empty replacement", function()
      local result = Text.replace_macro.handler(ctx, { "hello world", "world" })
      assert.equals("hello ", result)
    end)
  end)

  describe("split macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("splits by delimiter", function()
      local result = Text.split_macro.handler(ctx, { "a,b,c", "," })
      assert.is_table(result)
      assert.equals(3, #result)
      assert.equals("a", result[1])
      assert.equals("b", result[2])
      assert.equals("c", result[3])
    end)

    it("defaults to space delimiter", function()
      local result = Text.split_macro.handler(ctx, { "hello world" })
      assert.equals(2, #result)
    end)
  end)

  describe("join macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("joins array", function()
      local result = Text.join_macro.handler(ctx, { { "a", "b", "c" }, "," })
      assert.equals("a,b,c", result)
    end)

    it("defaults to empty delimiter", function()
      local result = Text.join_macro.handler(ctx, { { "a", "b", "c" } })
      assert.equals("abc", result)
    end)
  end)

  describe("pluralize macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns singular for 1", function()
      local result = Text.pluralize_macro.handler(ctx, { 1, "apple", "apples" })
      assert.equals("apple", result)
    end)

    it("returns plural for 0", function()
      local result = Text.pluralize_macro.handler(ctx, { 0, "apple", "apples" })
      assert.equals("apples", result)
    end)

    it("returns plural for > 1", function()
      local result = Text.pluralize_macro.handler(ctx, { 5, "apple", "apples" })
      assert.equals("apples", result)
    end)

    it("auto-generates plural", function()
      local result = Text.pluralize_macro.handler(ctx, { 2, "item" })
      assert.equals("items", result)
    end)
  end)

  describe("link macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link data", function()
      local result = Text.link_macro.handler(ctx, { "Click me", "Target" })
      assert.is_table(result)
      assert.equals("link", result._type)
      assert.equals("Click me", result.text)
      assert.equals("Target", result.target)
    end)

    it("is link category", function()
      assert.equals("link", Text.link_macro.category)
    end)
  end)

  describe("link_goto macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link_goto data", function()
      local result = Text.link_goto_macro.handler(ctx, { "Go North", "NorthRoom" })
      assert.equals("link_goto", result._type)
      assert.equals("Go North", result.text)
      assert.equals("NorthRoom", result.target)
    end)

    it("defaults target to text", function()
      local result = Text.link_goto_macro.handler(ctx, { "NextPassage" })
      assert.equals("NextPassage", result.target)
    end)
  end)

  describe("link_reveal macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates link_reveal data", function()
      local result = Text.link_reveal_macro.handler(ctx, { "Show more", "Hidden content" })
      assert.equals("link_reveal", result._type)
      assert.equals("Show more", result.text)
      assert.equals("Hidden content", result.content)
      assert.is_false(result.revealed)
    end)
  end)

  describe("goto macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns passage name", function()
      local result = Text.goto_macro.handler(ctx, { "NextPassage" })
      assert.equals("NextPassage", result)
    end)

    it("returns error for non-string", function()
      local result, err = Text.goto_macro.handler(ctx, { 123 })
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Text.register_all(registry)

      assert.is_true(count >= 20)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Text.register_all(registry)

      assert.is_not_nil(registry:get("print"))
      assert.is_not_nil(registry:get("uppercase"))
      assert.is_not_nil(registry:get("trim"))
      assert.is_not_nil(registry:get("link"))
      assert.is_not_nil(registry:get("goto"))
    end)
  end)
end)
