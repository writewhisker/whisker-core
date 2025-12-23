--- XSS Prevention Tests
-- Security tests for content sanitization
-- @module tests.unit.security.xss_prevention_spec

describe("XSS Prevention", function()
  local ContentSanitizer

  before_each(function()
    package.loaded["whisker.security.content_sanitizer"] = nil
    package.loaded["whisker.security.html_parser"] = nil
    ContentSanitizer = require("whisker.security.content_sanitizer")
  end)

  describe("Script Tag Removal", function()
    it("removes basic script tags", function()
      local html = [[<script>alert('XSS')</script>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<script", result:lower())
      assert.does_not.match("alert", result)
    end)

    it("removes script tags with src attribute", function()
      local html = [[<script src="https://evil.com/xss.js"></script>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<script", result:lower())
    end)

    it("removes case-varied script tags", function()
      local html = [[<ScRiPt>alert('XSS')</sCrIpT>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("script", result:lower())
    end)
  end)

  describe("Event Handler Removal", function()
    it("removes onclick handlers", function()
      local html = [[<div onclick="alert('XSS')">Click me</div>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onclick", result:lower())
      assert.matches("Click me", result)
    end)

    it("removes onerror handlers", function()
      local html = [[<img src="x" onerror="alert('XSS')">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onerror", result:lower())
    end)

    it("removes onload handlers", function()
      local html = [[<body onload="alert('XSS')">Content</body>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onload", result:lower())
    end)

    it("removes onmouseover handlers", function()
      local html = [[<a onmouseover="alert('XSS')">Hover</a>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onmouseover", result:lower())
    end)

    it("removes case-varied event handlers", function()
      local html = [[<img src="x" OnErRoR="alert('XSS')">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onerror", result:lower())
    end)
  end)

  describe("JavaScript URL Removal", function()
    it("removes javascript: in href", function()
      local html = [[<a href="javascript:alert('XSS')">Click</a>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("javascript:", result:lower())
    end)

    it("removes javascript: in img src", function()
      local html = [[<img src="javascript:alert('XSS')">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("javascript:", result:lower())
    end)

    it("removes encoded javascript: URLs", function()
      -- HTML entity encoded javascript:
      local html = [[<a href="&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;alert(1)">Click</a>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("javascript:", result:lower())
    end)
  end)

  describe("Dangerous Tag Removal", function()
    it("removes iframe tags", function()
      local html = [[<iframe src="https://evil.com"></iframe>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<iframe", result:lower())
    end)

    it("removes object tags", function()
      local html = [[<object data="https://evil.com/flash.swf"></object>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<object", result:lower())
    end)

    it("removes embed tags", function()
      local html = [[<embed src="https://evil.com/flash.swf">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<embed", result:lower())
    end)

    it("removes form tags", function()
      local html = [[<form action="https://evil.com"><input type="submit"></form>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<form", result:lower())
    end)

    it("removes style tags", function()
      local html = [[<style>body{background:url('javascript:alert(1)')}</style>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<style", result:lower())
    end)

    it("removes svg tags", function()
      local html = [[<svg onload="alert('XSS')"><script>alert(1)</script></svg>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<svg", result:lower())
    end)

    it("removes meta refresh", function()
      local html = [[<meta http-equiv="refresh" content="0;url=javascript:alert('XSS')">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<meta", result:lower())
    end)
  end)

  describe("Data URL Handling", function()
    it("allows data: URLs for images", function()
      local html = [[<img src="data:image/png;base64,iVBORw0KGgo=">]]
      local result = ContentSanitizer.sanitize(html)
      -- data:image/ should be preserved
      assert.matches("data:image/", result)
    end)

    it("removes data:text/html URLs", function()
      local html = [[<img src="data:text/html,<script>alert('XSS')</script>">]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("data:text/html", result:lower())
    end)
  end)

  describe("Safe Content Preservation", function()
    it("preserves safe HTML tags", function()
      local html = [[<p>Hello <strong>world</strong>!</p>]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches("<p>", result)
      assert.matches("<strong>", result)
      assert.matches("Hello", result)
    end)

    it("preserves safe attributes", function()
      local html = [[<p id="intro" class="text-large">Hello</p>]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches('id="intro"', result)
      assert.matches('class="text%-large"', result)
    end)

    it("preserves links with safe URLs", function()
      local html = [[<a href="https://example.com">Link</a>]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches('href="https://example%.com"', result)
    end)

    it("preserves ARIA attributes", function()
      local html = [[<div aria-label="Close" role="button">X</div>]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches('aria%-label', result)
      assert.matches('role=', result)
    end)

    it("preserves data-* attributes", function()
      local html = [[<div data-passage="intro" data-count="5">Content</div>]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches('data%-passage', result)
      assert.matches('data%-count', result)
    end)

    it("preserves image with alt text", function()
      local html = [[<img src="photo.jpg" alt="A photo" width="100">]]
      local result = ContentSanitizer.sanitize(html)
      assert.matches('alt="A photo"', result)
      assert.matches('width="100"', result)
    end)
  end)

  describe("Nested Content", function()
    it("removes scripts inside nested divs", function()
      local html = [[<div><div><script>alert('XSS')</script></div></div>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("<script", result:lower())
      assert.matches("<div>", result)
    end)

    it("removes dangerous attributes in nested elements", function()
      local html = [[<div><p><span onclick="evil()">Text</span></p></div>]]
      local result = ContentSanitizer.sanitize(html)
      assert.does_not.match("onclick", result)
      assert.matches("Text", result)
    end)
  end)

  describe("validate", function()
    it("returns true for safe HTML", function()
      local html = [[<p>Safe <strong>content</strong></p>]]
      local safe, issues = ContentSanitizer.validate(html)
      assert.is_true(safe)
      -- issues is empty table when no issues
      assert.equals(0, #(issues or {}))
    end)

    it("returns false for dangerous HTML", function()
      local html = [[<script>alert('XSS')</script>]]
      local safe, issues = ContentSanitizer.validate(html)
      assert.is_false(safe)
      assert.is_table(issues)
      assert.is_true(#issues > 0)
    end)
  end)

  describe("edge cases", function()
    it("handles empty input", function()
      assert.equals("", ContentSanitizer.sanitize(""))
      assert.equals("", ContentSanitizer.sanitize(nil))
    end)

    it("handles malformed HTML", function()
      local html = [[<div><p>Unclosed]]
      local result = ContentSanitizer.sanitize(html)
      -- Should not crash
      assert.is_string(result)
    end)
  end)
end)
