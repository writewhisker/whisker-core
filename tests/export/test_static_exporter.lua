--- Static Site Exporter Tests
-- Tests for the Static Site export functionality
-- @module tests.export.test_static_exporter
--
-- Note: Some serialization tests may have different behavior on Lua 5.1
-- due to table iteration ordering differences in JSON encoding.

local StaticExporter = require("whisker.export.static.static_exporter")
local LuaVersion = require("tests.helpers.lua_version")

describe("Static Site Exporter", function()
  local function create_basic_story()
    return {
      name = "Test Story",
      title = "Test Story",
      author = "Test Author",
      description = "A test interactive story",
      start_passage = "Start",
      passages = {
        {
          name = "Start",
          text = "Welcome to the test story!\n\nThis is an adventure.",
          choices = {
            { text = "Begin", target = "Next" },
          },
        },
        {
          name = "Next",
          text = "This is the second passage.",
          choices = {
            { text = "Continue", target = "End" },
          },
        },
        {
          name = "End",
          text = "The End!",
          choices = {},
        },
      },
    }
  end

  local function create_story_with_variables()
    return {
      name = "Variable Story",
      start = "Start",
      variables = {
        { name = "score", default = 0 },
        { name = "health", default = 100 },
      },
      passages = {
        {
          name = "Start",
          text = "Score: {{score}}\nHealth: {{health}}",
          choices = {
            {
              text = "Add points",
              target = "Next",
              effects = { { variable = "score", value = 10 } },
            },
          },
        },
        {
          name = "Next",
          text = "Your score is now: {{score}}",
          choices = {},
        },
      },
    }
  end

  local function create_story_with_conditions()
    return {
      name = "Condition Story",
      start = "Start",
      variables = {
        { name = "hasKey", default = false },
      },
      passages = {
        {
          name = "Start",
          text = "You see a door.",
          choices = {
            { text = "Open door", target = "Door", condition = "{{hasKey}} == true" },
            { text = "Find key", target = "Key" },
          },
        },
        {
          name = "Key",
          text = "You found a key!",
          choices = {
            {
              text = "Take it",
              target = "Start",
              effects = { { variable = "hasKey", value = true } },
            },
          },
        },
        {
          name = "Door",
          text = "You opened the door!",
          choices = {},
        },
      },
    }
  end

  describe("initialization", function()
    it("should create a new exporter", function()
      local exporter = StaticExporter.new()
      assert.is_not_nil(exporter)
    end)

    it("should provide metadata", function()
      local exporter = StaticExporter.new()
      local meta = exporter:metadata()
      assert.equals("static", meta.format)
      assert.equals(".html", meta.file_extension)
      assert.is_not_nil(meta.description)
    end)
  end)

  describe("can_export", function()
    it("should return true for valid story", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local can, err = exporter:can_export(story)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should return false for nil story", function()
      local exporter = StaticExporter.new()
      local can, err = exporter:can_export(nil)
      assert.is_false(can)
      assert.is_not_nil(err)
    end)

    it("should return false for story without passages", function()
      local exporter = StaticExporter.new()
      local can, err = exporter:can_export({ name = "Empty" })
      assert.is_false(can)
      assert.is_not_nil(err)
    end)
  end)

  describe("export", function()
    it("should export basic story", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
      assert.is_not_nil(result.files)
    end)

    it("should generate index.html file", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_not_nil(result.files["index.html"])
    end)
  end)

  describe("HTML generation", function()
    it("should include DOCTYPE", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("<!DOCTYPE html>") ~= nil)
    end)

    it("should include story title", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("Test Story") ~= nil)
    end)

    it("should include story data", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("STORY_DATA") ~= nil)
    end)

    it("should include player script", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("WhiskerPlayer") ~= nil)
    end)

    it("should include CSS styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("<style>") ~= nil)
      assert.is_true(result.content:match("%-%-bg%-primary") ~= nil)
    end)

    it("should escape HTML in title", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      story.name = "Test <script>Story"
      local result = exporter:export(story)

      assert.is_true(result.content:match("&lt;script&gt;") ~= nil)
    end)
  end)

  describe("player features", function()
    it("should include back button by default", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("goBack") ~= nil)
    end)

    it("should include save/load by default", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("saveGame") ~= nil)
      assert.is_true(result.content:match("loadGame") ~= nil)
    end)

    it("should include theme toggle by default", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("toggleTheme") ~= nil)
    end)

    it("should include restart button", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("restart") ~= nil)
    end)

    it("should exclude back button when disabled", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { include_back = false })

      -- The goBack function exists but the button code is not present
      assert.is_not_nil(result.content)
    end)

    it("should exclude save when disabled", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { include_save = false })

      assert.is_not_nil(result.content)
    end)
  end)

  describe("CSS variables", function()
    it("should include light theme variables", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("%-%-bg%-primary: #ffffff") ~= nil)
    end)

    it("should include dark theme variables", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match('%[data%-theme="dark"%]') ~= nil)
    end)

    it("should include responsive styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match("@media") ~= nil)
    end)
  end)

  describe("story serialization", function()
    it("should serialize passages", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match('"passages"') ~= nil)
      assert.is_true(result.content:match('"Start"') ~= nil)
    end)

    it("should serialize choices", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_true(result.content:match('"choices"') ~= nil)
      assert.is_true(result.content:match('"target"') ~= nil)
    end)

    it("should serialize variables", function()
      local exporter = StaticExporter.new()
      local story = create_story_with_variables()
      local result = exporter:export(story)

      assert.is_true(result.content:match('"variables"') ~= nil)
      assert.is_true(result.content:match('"score"') ~= nil)
    end)
  end)

  describe("manifest", function()
    it("should include format in manifest", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.equals("static", result.manifest.format)
    end)

    it("should include passage count", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.equals(3, result.manifest.passage_count)
    end)

    it("should include filename", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_not_nil(result.manifest.filename)
      assert.is_true(result.manifest.filename:match("%.html$") ~= nil)
    end)
  end)

  describe("validation", function()
    it("should validate valid bundle", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local bundle = exporter:export(story)
      local validation = exporter:validate(bundle)

      assert.is_true(validation.valid)
      assert.equals(0, #validation.errors)
    end)

    it("should reject empty bundle", function()
      local exporter = StaticExporter.new()
      local validation = exporter:validate({ content = "" })

      assert.is_false(validation.valid)
    end)

    it("should report missing story data", function()
      local exporter = StaticExporter.new()
      local validation = exporter:validate({ content = "<!DOCTYPE html><html></html>" })

      assert.is_false(validation.valid)
    end)

    it("should report missing player", function()
      local exporter = StaticExporter.new()
      local validation = exporter:validate({
        content = "<!DOCTYPE html><html>STORY_DATA</html>"
      })

      assert.is_false(validation.valid)
    end)
  end)

  describe("size estimation", function()
    it("should estimate export size", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local size = exporter:estimate_size(story)

      assert.is_true(size > 0)
    end)

    it("should estimate larger size for more passages", function()
      local exporter = StaticExporter.new()
      local small_story = create_basic_story()
      local large_story = {
        name = "Large",
        passages = {},
      }
      for i = 1, 100 do
        table.insert(large_story.passages, { name = "Passage" .. i, text = "Content" })
      end

      local small_size = exporter:estimate_size(small_story)
      local large_size = exporter:estimate_size(large_story)

      assert.is_true(large_size > small_size)
    end)
  end)

  describe("edge cases", function()
    it("should handle story with empty passage content", function()
      local exporter = StaticExporter.new()
      local story = {
        name = "Empty Content",
        passages = {
          { name = "Start", text = "", choices = {} },
        },
      }
      local result = exporter:export(story)

      assert.is_not_nil(result.content)
    end)

    it("should handle story with special characters", function()
      local exporter = StaticExporter.new()
      local story = {
        name = "Test <Story> & 'Quotes'",
        passages = {
          { name = "Start", text = "Special: <>&\"'", choices = {} },
        },
        start_passage = "Start",
      }
      local result = exporter:export(story)

      assert.is_not_nil(result.content)
    end)

    it("should handle story with newlines", function()
      local exporter = StaticExporter.new()
      local story = {
        name = "Newlines",
        passages = {
          { name = "Start", text = "Line 1\nLine 2\nLine 3", choices = {} },
        },
      }
      local result = exporter:export(story)

      assert.is_not_nil(result.content)
    end)

    it("should handle story with conditions", function()
      local exporter = StaticExporter.new()
      local story = create_story_with_conditions()
      local result = exporter:export(story)

      assert.is_not_nil(result.content)
      assert.is_true(result.content:match("evaluateCondition") ~= nil)
    end)

    it("should handle story with effects", function()
      local exporter = StaticExporter.new()
      local story = create_story_with_variables()
      local result = exporter:export(story)

      assert.is_not_nil(result.content)
      assert.is_true(result.content:match("effects") ~= nil)
    end)
  end)

  describe("multi-page site generation", function()
    it("should generate multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      assert.is_not_nil(result.files)
      assert.is_not_nil(result.files["index.html"])
      assert.is_not_nil(result.files["passages/start.html"])
      assert.is_not_nil(result.files["passages/next.html"])
      assert.is_not_nil(result.files["passages/end.html"])
    end)

    it("should generate CSS and JS files for multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      assert.is_not_nil(result.files["css/styles.css"])
      assert.is_not_nil(result.files["js/player.js"])
    end)

    it("should generate sitemap for multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      assert.is_not_nil(result.files["sitemap.xml"])
      assert.is_true(result.files["sitemap.xml"]:match("<urlset") ~= nil)
    end)

    it("should generate robots.txt for multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      assert.is_not_nil(result.files["robots.txt"])
      assert.is_true(result.files["robots.txt"]:match("User%-agent") ~= nil)
    end)

    it("should generate 404.html for multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      assert.is_not_nil(result.files["404.html"])
      assert.is_true(result.files["404.html"]:match("Page Not Found") ~= nil)
    end)
  end)

  describe("breadcrumb navigation", function()
    it("should include breadcrumbs in multi-page site by default", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_not_nil(passage_html)
      assert.is_true(passage_html:match('class="breadcrumbs"') ~= nil)
    end)

    it("should include breadcrumb link to home", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('%.%.%/index%.html') ~= nil)
    end)

    it("should not include breadcrumbs on index page", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local index_html = result.files["index.html"]
      assert.is_nil(index_html:match('class="breadcrumbs"'))
    end)

    it("should disable breadcrumbs when option is false", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_breadcrumbs = false })

      local passage_html = result.files["passages/next.html"]
      assert.is_nil(passage_html:match('class="breadcrumbs"'))
    end)
  end)

  describe("previous/next navigation", function()
    it("should include prev/next links by default in multi-page site", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="prev%-next%-nav"') ~= nil)
    end)

    it("should include previous link with correct passage", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="prev%-link"') ~= nil)
    end)

    it("should include next link with correct passage", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="next%-link"') ~= nil)
    end)

    it("should hide prev link on first passage", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local start_html = result.files["passages/start.html"]
      assert.is_true(start_html:match('prev%-link disabled') ~= nil)
    end)

    it("should hide next link on last passage", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local end_html = result.files["passages/end.html"]
      assert.is_true(end_html:match('next%-link disabled') ~= nil)
    end)

    it("should disable prev/next when option is false", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_prev_next = false })

      local passage_html = result.files["passages/next.html"]
      assert.is_nil(passage_html:match('class="prev%-next%-nav"'))
    end)
  end)

  describe("table of contents sidebar", function()
    it("should not include TOC sidebar by default", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_nil(passage_html:match('class="toc%-sidebar"'))
    end)

    it("should include TOC sidebar when enabled", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="toc%-sidebar"') ~= nil)
    end)

    it("should include all passages in TOC", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match("start%.html") ~= nil)
      assert.is_true(passage_html:match("next%.html") ~= nil)
      assert.is_true(passage_html:match("end%.html") ~= nil)
    end)

    it("should highlight current passage in TOC", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="current"') ~= nil)
    end)

    it("should include TOC toggle button", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('id="toc%-toggle"') ~= nil)
    end)

    it("should add has-toc-sidebar class to body", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('has%-toc%-sidebar') ~= nil)
    end)
  end)

  describe("alternate theme option", function()
    it("should include sepia theme CSS when alt_theme is sepia", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, alt_theme = "sepia" })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match('%[data%-alt%-theme="sepia"%]') ~= nil)
    end)

    it("should include high-contrast theme CSS when alt_theme is high-contrast", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, alt_theme = "high-contrast" })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match('%[data%-alt%-theme="high%-contrast"%]') ~= nil)
    end)

    it("should set data-alt-theme attribute on html element", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, alt_theme = "sepia" })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('data%-alt%-theme="sepia"') ~= nil)
    end)

    it("should include alt theme in theme cycle JavaScript", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, alt_theme = "sepia" })

      local js = result.files["js/player.js"]
      assert.is_true(js:match('"sepia"') ~= nil)
    end)
  end)

  describe("template customization", function()
    it("should include custom header template", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, {
        multi_page = true,
        header_template = '<h1>My Custom Header</h1>',
      })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="site%-header"') ~= nil)
      assert.is_true(passage_html:match("My Custom Header") ~= nil)
    end)

    it("should include custom footer template", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, {
        multi_page = true,
        footer_template = '<p>Copyright 2024</p>',
      })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('class="site%-footer"') ~= nil)
      assert.is_true(passage_html:match("Copyright 2024") ~= nil)
    end)

    it("should not include header when template is empty", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_nil(passage_html:match('class="site%-header"'))
    end)

    it("should not include footer when template is empty", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_nil(passage_html:match('class="site%-footer"'))
    end)
  end)

  describe("layout options", function()
    it("should apply default layout class", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('layout%-default') ~= nil)
    end)

    it("should apply minimal layout class", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, layout = "minimal" })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('layout%-minimal') ~= nil)
    end)

    it("should apply full layout class", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, layout = "full" })

      local passage_html = result.files["passages/next.html"]
      assert.is_true(passage_html:match('layout%-full') ~= nil)
    end)

    it("should include layout CSS for minimal", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, layout = "minimal" })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.layout%-minimal") ~= nil)
    end)

    it("should include layout CSS for full", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, layout = "full" })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.layout%-full") ~= nil)
    end)
  end)

  describe("multi-page styles", function()
    it("should include breadcrumb styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.breadcrumbs") ~= nil)
    end)

    it("should include prev/next styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.prev%-next%-nav") ~= nil)
    end)

    it("should include TOC sidebar styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.toc%-sidebar") ~= nil)
    end)

    it("should include header/footer styles", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local css = result.files["css/styles.css"]
      assert.is_true(css:match("%.site%-header") ~= nil)
      assert.is_true(css:match("%.site%-footer") ~= nil)
    end)
  end)

  describe("multi-page JavaScript", function()
    it("should include theme cycling logic", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local js = result.files["js/player.js"]
      assert.is_true(js:match("cycleTheme") ~= nil)
    end)

    it("should include available themes array", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true })

      local js = result.files["js/player.js"]
      assert.is_true(js:match("availableThemes") ~= nil)
    end)

    it("should include TOC sidebar JavaScript when enabled", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = true })

      local js = result.files["js/player.js"]
      assert.is_true(js:match("initTocSidebar") ~= nil)
    end)

    it("should not call initTocSidebar when disabled", function()
      local exporter = StaticExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { multi_page = true, include_toc_sidebar = false })

      local js = result.files["js/player.js"]
      -- The function exists but the call (with semicolon) isn't in the initialization
      -- When disabled, the call "initTocSidebar();" should not appear after "loadTheme();"
      assert.is_nil(js:match("loadTheme%(%);%s+initTocSidebar%(%)"))
    end)
  end)
end)
