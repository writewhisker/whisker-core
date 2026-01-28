-- Tests for Content Escape Sequences (GAP-001)
-- Tests the process_escapes functionality in the renderer

describe("Content Escape Sequences (GAP-001)", function()
  local Renderer
  local HookManager

  setup(function()
    Renderer = require("lib.whisker.core.renderer")
    HookManager = require("lib.whisker.wls2.hook_manager")
  end)

  local function render_content(content)
    local hook_manager = HookManager.new()
    local renderer = Renderer.new(nil, "plain", hook_manager)
    local passage = { content = content }
    return renderer:render_passage(passage, {}, "test_passage")
  end

  describe("bracket escapes", function()
    it("should render escaped left bracket as literal", function()
      local result = render_content("This is \\[literal\\] text")
      assert.equals("This is [literal] text", result)
    end)

    it("should render escaped brackets without interpreting as hooks", function()
      local result = render_content("Show \\[this\\] literally")
      assert.equals("Show [this] literally", result)
    end)
  end)

  describe("brace escapes", function()
    it("should render escaped braces as literal", function()
      local result = render_content("JSON: \\{key: value\\}")
      assert.equals("JSON: {key: value}", result)
    end)

    it("should not interpret escaped braces as conditionals", function()
      local result = render_content("Show \\{this\\} literally")
      assert.equals("Show {this} literally", result)
    end)
  end)

  describe("angle bracket escapes", function()
    it("should render escaped angle brackets", function()
      local result = render_content("HTML: \\<div\\>content\\</div\\>")
      assert.equals("HTML: <div>content</div>", result)
    end)

    it("should handle mixed angle brackets", function()
      local result = render_content("Compare: a \\< b and b \\> a")
      assert.equals("Compare: a < b and b > a", result)
    end)
  end)

  describe("whitespace escapes", function()
    it("should render newline escape", function()
      local result = render_content("Line 1\\nLine 2")
      assert.equals("Line 1\nLine 2", result)
    end)

    it("should render tab escape", function()
      local result = render_content("Col1\\tCol2")
      assert.equals("Col1\tCol2", result)
    end)

    it("should handle multiple whitespace escapes", function()
      local result = render_content("A\\tB\\tC\\nD\\tE\\tF")
      assert.equals("A\tB\tC\nD\tE\tF", result)
    end)
  end)

  describe("unicode escapes", function()
    it("should render unicode heart", function()
      local result = render_content("I \\u2764 Whisker")
      -- Unicode heart U+2764 = "heart" symbol
      assert.equals("I \226\157\164 Whisker", result)
    end)

    it("should render unicode smiley", function()
      local result = render_content("Hello \\u263A")
      -- Unicode U+263A = white smiling face
      assert.equals("Hello \226\152\186", result)
    end)

    it("should handle invalid unicode gracefully", function()
      local result = render_content("Bad \\uXXXX escape")
      -- Invalid unicode escape should be preserved literally
      assert.equals("Bad \\uXXXX escape", result)
    end)

    it("should handle incomplete unicode escape", function()
      local result = render_content("End: \\u12")
      -- Incomplete unicode (less than 4 hex digits) preserved
      assert.equals("End: \\u12", result)
    end)
  end)

  describe("backslash escape", function()
    it("should render escaped backslash as literal", function()
      local result = render_content("Path: C:\\\\Users\\\\name")
      assert.equals("Path: C:\\Users\\name", result)
    end)

    it("should handle single backslash followed by non-escape", function()
      local result = render_content("Test \\x unknown")
      -- Unknown escape, backslash preserved
      assert.equals("Test \\x unknown", result)
    end)
  end)

  describe("mixed escapes", function()
    it("should handle multiple different escape types", function()
      local result = render_content("\\[brackets\\] and \\{braces\\} and \\<angles\\>")
      assert.equals("[brackets] and {braces} and <angles>", result)
    end)

    it("should handle escapes with normal text", function()
      local result = render_content("Normal text \\n with a newline \\t and tab.")
      assert.equals("Normal text \n with a newline \t and tab.", result)
    end)

    it("should handle escape at end of string", function()
      local result = render_content("End with backslash \\\\")
      assert.equals("End with backslash \\", result)
    end)

    it("should handle escape at start of string", function()
      local result = render_content("\\[Start with bracket")
      assert.equals("[Start with bracket", result)
    end)
  end)

  describe("edge cases", function()
    it("should handle empty string", function()
      local result = render_content("")
      assert.equals("", result)
    end)

    it("should handle string with no escapes", function()
      local result = render_content("No escapes here")
      assert.equals("No escapes here", result)
    end)

    it("should handle consecutive escapes", function()
      local result = render_content("\\[\\]\\{\\}")
      assert.equals("[]{}", result)
    end)

    it("should handle double backslash followed by escape", function()
      -- \\n should become \n (backslash + n), not a newline
      local result = render_content("\\\\n")
      assert.equals("\\n", result)
    end)
  end)
end)
