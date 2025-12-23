--- Asset Bundler Tests
-- @module tests.unit.export.asset_bundler_spec

describe("AssetBundler", function()
  local AssetBundler
  local bundler

  before_each(function()
    package.loaded["whisker.export.asset_bundler"] = nil
    package.loaded["whisker.export.utils"] = nil
    AssetBundler = require("whisker.export.asset_bundler")
    bundler = AssetBundler.new()
  end)

  describe("new", function()
    it("creates a new bundler", function()
      assert.is_table(bundler)
    end)

    it("accepts options", function()
      local b = AssetBundler.new({
        base_path = "/foo",
        minify = true,
        inline = false,
      })
      assert.is_table(b)
    end)
  end)

  describe("add_content", function()
    it("adds content directly", function()
      bundler:add_content("style.css", "body { color: red; }", "css")

      local assets = bundler:get_all_assets()
      assert.equals(1, #assets)
      assert.equals("style.css", assets[1].path)
      assert.equals("css", assets[1].type)
      assert.equals("body { color: red; }", assets[1].content)
    end)

    it("calculates size", function()
      bundler:add_content("test.txt", "hello", "txt")

      local assets = bundler:get_all_assets()
      assert.equals(5, assets[1].size)
    end)
  end)

  describe("get_assets", function()
    it("filters by type", function()
      bundler:add_content("a.css", "css content", "css")
      bundler:add_content("b.js", "js content", "js")
      bundler:add_content("c.css", "more css", "css")

      local css_assets = bundler:get_assets("css")
      assert.equals(2, #css_assets)

      local js_assets = bundler:get_assets("js")
      assert.equals(1, #js_assets)
    end)

    it("returns empty array for no matches", function()
      bundler:add_content("a.css", "content", "css")

      local png_assets = bundler:get_assets("png")
      assert.same({}, png_assets)
    end)
  end)

  describe("get_combined_css", function()
    it("combines all CSS assets", function()
      bundler:add_content("a.css", "body { color: red; }", "css")
      bundler:add_content("b.css", "h1 { color: blue; }", "css")

      local combined = bundler:get_combined_css()
      assert.truthy(combined:match("color: red"))
      assert.truthy(combined:match("color: blue"))
    end)

    it("returns empty string when no CSS", function()
      bundler:add_content("a.js", "console.log('hi')", "js")

      local combined = bundler:get_combined_css()
      assert.equals("", combined)
    end)
  end)

  describe("get_combined_js", function()
    it("combines all JS assets", function()
      bundler:add_content("a.js", "var a = 1;", "js")
      bundler:add_content("b.js", "var b = 2;", "js")

      local combined = bundler:get_combined_js()
      assert.truthy(combined:match("var a"))
      assert.truthy(combined:match("var b"))
    end)
  end)

  describe("get_inline_css_tag", function()
    it("wraps CSS in style tag", function()
      bundler:add_content("a.css", "body { color: red; }", "css")

      local tag = bundler:get_inline_css_tag()
      assert.truthy(tag:match("^<style>"))
      assert.truthy(tag:match("</style>$"))
      assert.truthy(tag:match("color: red"))
    end)

    it("returns empty string when no CSS", function()
      local tag = bundler:get_inline_css_tag()
      assert.equals("", tag)
    end)
  end)

  describe("get_inline_js_tag", function()
    it("wraps JS in script tag", function()
      bundler:add_content("a.js", "var x = 1;", "js")

      local tag = bundler:get_inline_js_tag()
      assert.truthy(tag:match("^<script>"))
      assert.truthy(tag:match("</script>$"))
      assert.truthy(tag:match("var x"))
    end)

    it("returns empty string when no JS", function()
      local tag = bundler:get_inline_js_tag()
      assert.equals("", tag)
    end)
  end)

  describe("inline_asset", function()
    it("returns data URI for asset", function()
      bundler:add_content("test.txt", "Hello", "txt")

      local uri = bundler:inline_asset("test.txt")
      assert.truthy(uri:match("^data:"))
      assert.truthy(uri:match("base64"))
    end)

    it("returns nil for missing asset", function()
      local uri = bundler:inline_asset("nonexistent.txt")
      assert.is_nil(uri)
    end)
  end)

  describe("get_total_size", function()
    it("sums all asset sizes", function()
      bundler:add_content("a.txt", "hello", "txt")  -- 5 bytes
      bundler:add_content("b.txt", "world!", "txt")  -- 6 bytes

      assert.equals(11, bundler:get_total_size())
    end)

    it("returns 0 when no assets", function()
      assert.equals(0, bundler:get_total_size())
    end)
  end)

  describe("get_asset_count", function()
    it("returns number of assets", function()
      bundler:add_content("a.css", "a", "css")
      bundler:add_content("b.css", "b", "css")

      assert.equals(2, bundler:get_asset_count())
    end)
  end)

  describe("clear", function()
    it("removes all assets", function()
      bundler:add_content("a.css", "content", "css")
      bundler:add_content("b.js", "content", "js")

      bundler:clear()

      assert.equals(0, bundler:get_asset_count())
    end)
  end)

  describe("minify_css", function()
    it("removes comments", function()
      local css = "/* comment */ body { color: red; }"
      local minified = bundler:minify_css(css)
      assert.falsy(minified:match("comment"))
    end)

    it("collapses whitespace", function()
      local css = "body {   color:    red;   }"
      local minified = bundler:minify_css(css)
      assert.falsy(minified:match("  "))
    end)

    it("removes space around punctuation", function()
      local css = "body { color : red ; }"
      local minified = bundler:minify_css(css)
      assert.truthy(minified:match("color:red"))
    end)

    it("handles nil input", function()
      assert.equals("", bundler:minify_css(nil))
    end)
  end)

  describe("minify_js", function()
    it("removes block comments", function()
      local js = "/* comment */ var x = 1;"
      local minified = bundler:minify_js(js)
      assert.falsy(minified:match("comment"))
    end)

    it("handles nil input", function()
      assert.equals("", bundler:minify_js(nil))
    end)

    it("trims whitespace", function()
      local js = "   var x = 1;   "
      local minified = bundler:minify_js(js)
      assert.equals("var x = 1;", minified)
    end)
  end)

  describe("minify option", function()
    it("minifies CSS when enabled", function()
      local b = AssetBundler.new({ minify = true })
      b:add_content("style.css", "/* comment */ body { color: red; }", "css")

      local assets = b:get_all_assets()
      assert.falsy(assets[1].content:match("comment"))
    end)

    it("minifies JS when enabled", function()
      local b = AssetBundler.new({ minify = true })
      b:add_content("script.js", "/* comment */ var x = 1;", "js")

      local assets = b:get_all_assets()
      assert.falsy(assets[1].content:match("comment"))
    end)

    it("does not minify when disabled", function()
      local b = AssetBundler.new({ minify = false })
      b:add_content("style.css", "/* comment */ body { color: red; }", "css")

      local assets = b:get_all_assets()
      assert.truthy(assets[1].content:match("comment"))
    end)
  end)

  describe("create_bundle", function()
    it("returns bundle with all assets", function()
      bundler:add_content("a.css", "css content", "css")
      bundler:add_content("b.js", "js content", "js")

      local bundle = bundler:create_bundle()

      assert.equals(2, #bundle)
      assert.equals("a.css", bundle[1].path)
      assert.equals("b.js", bundle[2].path)
    end)
  end)
end)
