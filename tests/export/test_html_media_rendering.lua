-- tests/export/test_html_media_rendering.lua
-- Tests for HTML export of media elements (GAP-037 through GAP-043)

describe("HTML Media Rendering", function()
  local HTMLExporter

  before_each(function()
    package.loaded["whisker.export.html.html_exporter"] = nil
    HTMLExporter = require("whisker.export.html.html_exporter")
  end)

  describe("Audio Rendering (GAP-037)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should render basic audio element", function()
      local node = {
        type = "audio",
        src = "music.mp3",
        controls = true,
        autoplay = false,
        loop = false,
        muted = false,
        volume = 1.0
      }

      local html = exporter:render_audio(node)
      assert.is_not_nil(html)
      assert.is_not_nil(html:match('<audio'))
      assert.is_not_nil(html:match('src="music%.mp3"'))
      assert.is_not_nil(html:match('controls'))
    end)

    it("should render audio with autoplay", function()
      local node = {
        type = "audio",
        src = "music.mp3",
        controls = true,
        autoplay = true,
        loop = false,
        muted = false,
        volume = 1.0
      }

      local html = exporter:render_audio(node)
      assert.is_not_nil(html:match('autoplay'))
    end)

    it("should render audio with loop", function()
      local node = {
        type = "audio",
        src = "ambient.mp3",
        controls = true,
        autoplay = false,
        loop = true,
        muted = false,
        volume = 1.0
      }

      local html = exporter:render_audio(node)
      assert.is_not_nil(html:match(' loop'))
    end)

    it("should render audio without controls when false", function()
      local node = {
        type = "audio",
        src = "hidden.mp3",
        controls = false,
        autoplay = true,
        loop = false,
        muted = false,
        volume = 1.0
      }

      local html = exporter:render_audio(node)
      assert.is_nil(html:match(' controls'))
    end)

    it("should include volume script when not 1.0", function()
      local node = {
        type = "audio",
        src = "quiet.mp3",
        controls = true,
        autoplay = false,
        loop = false,
        muted = false,
        volume = 0.5,
        position = 1
      }

      local html = exporter:render_audio(node)
      assert.is_not_nil(html:match('volume = 0%.5'))
    end)

    it("should render audio placeholder for non-web", function()
      local node = {
        type = "audio",
        src = "music.mp3"
      }

      local result = exporter:render_media_node(node, "console")
      assert.equals("[Audio: music.mp3]", result)
    end)
  end)

  describe("Video Rendering (GAP-038)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should render basic video element", function()
      local node = {
        type = "video",
        src = "intro.mp4",
        controls = true,
        autoplay = false,
        loop = false,
        muted = false
      }

      local html = exporter:render_video(node)
      assert.is_not_nil(html)
      assert.is_not_nil(html:match('<video'))
      assert.is_not_nil(html:match('src="intro%.mp4"'))
      assert.is_not_nil(html:match('controls'))
    end)

    it("should render video with dimensions", function()
      local node = {
        type = "video",
        src = "scene.mp4",
        controls = true,
        width = 640,
        height = 480
      }

      local html = exporter:render_video(node)
      assert.is_not_nil(html:match('width="640"'))
      assert.is_not_nil(html:match('height="480"'))
    end)

    it("should render video with poster", function()
      local node = {
        type = "video",
        src = "movie.mp4",
        controls = true,
        poster = "thumbnail.jpg"
      }

      local html = exporter:render_video(node)
      assert.is_not_nil(html:match('poster="thumbnail%.jpg"'))
    end)

    it("should render video with autoplay and muted", function()
      local node = {
        type = "video",
        src = "bg.mp4",
        controls = false,
        autoplay = true,
        loop = true,
        muted = true
      }

      local html = exporter:render_video(node)
      assert.is_not_nil(html:match('autoplay'))
      assert.is_not_nil(html:match('muted'))
      assert.is_not_nil(html:match(' loop'))
    end)

    it("should render video placeholder for non-web", function()
      local node = {
        type = "video",
        src = "movie.mp4",
        width = 800,
        height = 600
      }

      local result = exporter:render_media_node(node, "plain")
      assert.equals("[Video: movie.mp4 (800x600)]", result)
    end)
  end)

  describe("Embed/Iframe Rendering (GAP-039)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should render basic embed element", function()
      local node = {
        type = "embed",
        url = "https://example.com/widget",
        width = 560,
        height = 315,
        sandbox = true,
        allow = "",
        title = "Widget",
        loading = "lazy"
      }

      local html = exporter:render_embed(node)
      assert.is_not_nil(html)
      assert.is_not_nil(html:match('<iframe'))
      assert.is_not_nil(html:match('src="https://example%.com/widget"'))
    end)

    it("should include sandbox attribute when true", function()
      local node = {
        type = "embed",
        url = "https://example.com",
        width = 560,
        height = 315,
        sandbox = true,
        allow = "",
        title = "Test",
        loading = "lazy"
      }

      local html = exporter:render_embed(node)
      assert.is_not_nil(html:match('sandbox='))
    end)

    it("should not include sandbox when false", function()
      local node = {
        type = "embed",
        url = "https://trusted.com",
        width = 560,
        height = 315,
        sandbox = false,
        allow = "",
        title = "Trusted",
        loading = "lazy"
      }

      local html = exporter:render_embed(node)
      assert.is_nil(html:match('sandbox='))
    end)

    it("should include title attribute", function()
      local node = {
        type = "embed",
        url = "https://example.com",
        width = 560,
        height = 315,
        sandbox = true,
        allow = "",
        title = "My Widget",
        loading = "lazy"
      }

      local html = exporter:render_embed(node)
      assert.is_not_nil(html:match('title="My Widget"'))
    end)

    it("should include referrerpolicy for security", function()
      local node = {
        type = "embed",
        url = "https://example.com",
        width = 560,
        height = 315,
        sandbox = true,
        allow = "",
        title = "Test",
        loading = "lazy"
      }

      local html = exporter:render_embed(node)
      assert.is_not_nil(html:match('referrerpolicy="no%-referrer"'))
    end)

    it("should render embed placeholder for non-web", function()
      local node = {
        type = "embed",
        url = "https://youtube.com/embed/abc"
      }

      local result = exporter:render_media_node(node, "console")
      assert.equals("[Embed: https://youtube.com/embed/abc]", result)
    end)
  end)

  describe("Image Rendering with Attributes (GAP-043)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should render image with all attributes", function()
      local node = {
        type = "image",
        src = "photo.jpg",
        alt = "A photo",
        title = "Photo title",
        width = 400,
        height = 300,
        loading = "lazy",
        class = "hero-image",
        id = "main-photo"
      }

      local html = exporter:render_image(node)
      assert.is_not_nil(html)
      assert.is_not_nil(html:match('<img'))
      assert.is_not_nil(html:match('src="photo%.jpg"'))
      assert.is_not_nil(html:match('alt="A photo"'))
      assert.is_not_nil(html:match('title="Photo title"'))
      assert.is_not_nil(html:match('width="400"'))
      assert.is_not_nil(html:match('height="300"'))
      assert.is_not_nil(html:match('loading="lazy"'))
      assert.is_not_nil(html:match('class="whisker%-media hero%-image"'))
      assert.is_not_nil(html:match('id="main%-photo"'))
    end)

    it("should render image with minimal attributes", function()
      local node = {
        type = "image",
        src = "simple.jpg",
        alt = ""
      }

      local html = exporter:render_image(node)
      assert.is_not_nil(html:match('<img'))
      assert.is_not_nil(html:match('src="simple%.jpg"'))
      assert.is_not_nil(html:match('alt=""'))
    end)

    it("should render image placeholder for non-web", function()
      local node = {
        type = "image",
        src = "photo.jpg",
        alt = "My photo",
        width = 800,
        height = 600
      }

      local result = exporter:render_media_node(node, "plain")
      assert.equals("[Image: My photo (800x600)]", result)
    end)

    it("should use src as fallback for alt in placeholder", function()
      local node = {
        type = "image",
        src = "unnamed.jpg"
      }

      local result = exporter:render_media_node(node, "console")
      assert.equals("[Image: unnamed.jpg]", result)
    end)
  end)

  describe("Theme CSS Integration (GAP-040, GAP-042)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should get theme CSS for story with themes", function()
      local story = {
        metadata = {
          themes = {"dark"}
        }
      }

      local css = exporter:get_theme_css(story)
      assert.is_not_nil(css)
      assert.is_not_nil(css:match("whisker%-theme%-dark"))
    end)

    it("should get theme classes for story", function()
      local story = {
        metadata = {
          themes = {"dark", "high-contrast"}
        }
      }

      local classes = exporter:get_theme_classes(story)
      assert.equals("whisker-theme-dark whisker-theme-high-contrast", classes)
    end)

    it("should handle story without themes", function()
      local story = {
        metadata = {}
      }

      local css = exporter:get_theme_css(story)
      assert.is_not_nil(css) -- Should still return base CSS

      local classes = exporter:get_theme_classes(story)
      assert.equals("", classes)
    end)
  end)

  describe("Custom CSS Integration (GAP-041)", function()
    local exporter

    before_each(function()
      exporter = HTMLExporter.new()
    end)

    it("should get custom CSS from story", function()
      local story = {
        metadata = {
          custom_styles = {".custom { color: red; }"}
        }
      }

      local css = exporter:get_custom_css(story)
      assert.is_not_nil(css)
      assert.is_not_nil(css:match("<style>"))
      assert.is_not_nil(css:match("%.custom"))
    end)

    it("should combine multiple custom styles", function()
      local story = {
        metadata = {
          custom_styles = {
            ".first { color: red; }",
            ".second { color: blue; }"
          }
        }
      }

      local css = exporter:get_custom_css(story)
      assert.is_not_nil(css:match("%.first"))
      assert.is_not_nil(css:match("%.second"))
    end)

    it("should return empty for no custom styles", function()
      local story = {
        metadata = {}
      }

      local css = exporter:get_custom_css(story)
      assert.equals("", css)
    end)
  end)
end)
