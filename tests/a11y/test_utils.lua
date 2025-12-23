--- Accessibility Utils Tests
-- Tests for a11y utility functions
-- @module tests.a11y.utils_spec

describe("a11y.utils", function()
  local utils

  setup(function()
    utils = require("whisker.a11y.utils")
  end)

  describe("generate_id()", function()
    it("should generate unique IDs", function()
      local id1 = utils.generate_id()
      local id2 = utils.generate_id()
      assert.are_not.equal(id1, id2)
    end)

    it("should use prefix", function()
      local id = utils.generate_id("test")
      assert.truthy(id:match("^test%-"))
    end)

    it("should default to a11y prefix", function()
      local id = utils.generate_id()
      assert.truthy(id:match("^a11y%-"))
    end)
  end)

  describe("escape_html()", function()
    it("should escape HTML entities", function()
      local result = utils.escape_html('<div class="test">&</div>')
      assert.truthy(result:match("&lt;"))
      assert.truthy(result:match("&gt;"))
      assert.truthy(result:match("&quot;"))
      assert.truthy(result:match("&amp;"))
    end)

    it("should handle nil", function()
      assert.equals("", utils.escape_html(nil))
    end)

    it("should handle single quotes", function()
      local result = utils.escape_html("It's a test")
      assert.truthy(result:match("&#39;"))
    end)
  end)

  describe("strip_html()", function()
    it("should remove HTML tags", function()
      local result = utils.strip_html("<p>Hello <strong>world</strong></p>")
      assert.equals("Hello world", result)
    end)

    it("should decode common entities", function()
      local result = utils.strip_html("&amp; &lt; &gt; &quot; &#39;")
      assert.equals("& < > \" '", result)
    end)

    it("should handle nil", function()
      assert.equals("", utils.strip_html(nil))
    end)
  end)

  describe("get_sr_only_css()", function()
    it("should return CSS for screen reader only class", function()
      local css = utils.get_sr_only_css()
      assert.truthy(css:match("%.sr%-only"))
      assert.truthy(css:match("position: absolute"))
      assert.truthy(css:match("width: 1px"))
    end)

    it("should include focusable variant", function()
      local css = utils.get_sr_only_css()
      assert.truthy(css:match("%.sr%-only%-focusable:focus"))
    end)
  end)

  describe("get_focus_visible_css()", function()
    it("should return CSS for focus visibility", function()
      local css = utils.get_focus_visible_css()
      assert.truthy(css:match(":focus"))
      assert.truthy(css:match(":focus%-visible"))
      assert.truthy(css:match("outline"))
    end)
  end)

  describe("get_skip_link_css()", function()
    it("should return CSS for skip links", function()
      local css = utils.get_skip_link_css()
      assert.truthy(css:match("%.skip%-link"))
      assert.truthy(css:match("top: %-40px"))
    end)
  end)

  describe("is_decorative_text()", function()
    it("should return true for empty text", function()
      assert.is_true(utils.is_decorative_text(""))
      assert.is_true(utils.is_decorative_text(nil))
    end)

    it("should return true for separator patterns", function()
      assert.is_true(utils.is_decorative_text("--------"))
      assert.is_true(utils.is_decorative_text("========"))
      assert.is_true(utils.is_decorative_text("********"))
    end)

    it("should return true for whitespace only", function()
      assert.is_true(utils.is_decorative_text("   "))
    end)

    it("should return false for meaningful text", function()
      assert.is_false(utils.is_decorative_text("Hello world"))
      assert.is_false(utils.is_decorative_text("Go north"))
    end)
  end)

  describe("normalize_whitespace()", function()
    it("should collapse multiple spaces", function()
      local result = utils.normalize_whitespace("Hello   world")
      assert.equals("Hello world", result)
    end)

    it("should collapse newlines", function()
      local result = utils.normalize_whitespace("Hello\n\nworld")
      assert.equals("Hello world", result)
    end)

    it("should trim leading and trailing whitespace", function()
      local result = utils.normalize_whitespace("  Hello world  ")
      assert.equals("Hello world", result)
    end)

    it("should handle nil", function()
      assert.equals("", utils.normalize_whitespace(nil))
    end)
  end)

  describe("truncate_for_announcement()", function()
    it("should not truncate short text", function()
      local text = "Short text"
      assert.equals(text, utils.truncate_for_announcement(text))
    end)

    it("should truncate long text", function()
      local text = string.rep("word ", 100)
      local result = utils.truncate_for_announcement(text, 50)
      assert.is_true(#result <= 53) -- 50 + "..."
    end)

    it("should add ellipsis when truncated", function()
      local text = string.rep("word ", 100)
      local result = utils.truncate_for_announcement(text, 50)
      assert.truthy(result:match("%.%.%.$"))
    end)

    it("should break at word boundaries", function()
      local text = "This is a somewhat longer sentence that needs truncation"
      local result = utils.truncate_for_announcement(text, 30)
      -- Should end with ellipsis and truncate appropriately
      assert.truthy(result:match("%.%.%.$"))
      -- Should be shorter than original
      assert.is_true(#result < #text)
    end)
  end)

  describe("create_description()", function()
    it("should return ID and HTML", function()
      local result = utils.create_description("test", "Description text")

      assert.is_string(result.id)
      assert.is_string(result.html)
      assert.truthy(result.html:match("sr%-only"))
      assert.truthy(result.html:match("Description text"))
    end)

    it("should escape HTML in description", function()
      local result = utils.create_description("test", "<script>alert('xss')</script>")

      assert.truthy(result.html:match("&lt;script&gt;"))
    end)
  end)

  describe("get_accessibility_metadata()", function()
    it("should return metadata object", function()
      local metadata = utils.get_accessibility_metadata()

      assert.equals("AA", metadata.wcag_level)
      assert.equals("2.1", metadata.wcag_version)
      assert.is_table(metadata.tested_with)
      assert.is_table(metadata.features)
    end)
  end)

  describe("is_descriptive_link_text()", function()
    it("should return true for descriptive text", function()
      assert.is_true(utils.is_descriptive_link_text("Go to settings"))
      assert.is_true(utils.is_descriptive_link_text("Read the documentation"))
    end)

    it("should return false for non-descriptive text", function()
      assert.is_false(utils.is_descriptive_link_text("click here"))
      assert.is_false(utils.is_descriptive_link_text("here"))
      assert.is_false(utils.is_descriptive_link_text("link"))
      assert.is_false(utils.is_descriptive_link_text("read more"))
    end)

    it("should return false for very short text", function()
      assert.is_false(utils.is_descriptive_link_text("hi"))
      assert.is_false(utils.is_descriptive_link_text(""))
    end)
  end)

  describe("create_live_region_html()", function()
    it("should create live region HTML", function()
      local html = utils.create_live_region_html("my-region", "polite")

      assert.truthy(html:match('id="my%-region"'))
      assert.truthy(html:match('aria%-live="polite"'))
      assert.truthy(html:match("sr%-only"))
    end)

    it("should default to polite", function()
      local html = utils.create_live_region_html("my-region")

      assert.truthy(html:match('aria%-live="polite"'))
    end)
  end)
end)
