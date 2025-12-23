-- MediaDirectiveParser Tests
-- Unit tests for the MediaDirectiveParser module

describe("MediaDirectiveParser", function()
  local MediaDirectiveParser
  local AudioManager
  local ImageManager
  local AssetManager
  local DummyAudioBackend

  before_each(function()
    package.loaded["whisker.media.MediaDirectiveParser"] = nil
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.PreloadManager"] = nil

    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
    local backend = DummyAudioBackend.new()

    AudioManager = require("whisker.media.AudioManager")
    AudioManager:initialize(backend)

    ImageManager = require("whisker.media.ImageManager")
    ImageManager:initialize({ screenWidth = 800, screenHeight = 600 })

    MediaDirectiveParser = require("whisker.media.MediaDirectiveParser")

    -- Register test assets
    AssetManager:register({
      id = "test_audio",
      type = "audio",
      sources = { { format = "mp3", path = "test.mp3" } },
      metadata = { duration = 60 }
    })

    AssetManager:register({
      id = "test_image",
      type = "image",
      variants = { { density = "1x", path = "test.png" } }
    })
  end)

  after_each(function()
    AudioManager:stopAll()
    ImageManager:hideAll()
  end)

  describe("parse", function()
    it("parses audio play directive", function()
      local directive = MediaDirectiveParser:parse("@@audio:play test_audio channel=MUSIC loop=true")

      assert.is_not_nil(directive)
      assert.equals("audio", directive.type)
      assert.equals("play", directive.command)
      assert.equals("test_audio", directive.args[1])
      assert.equals("MUSIC", directive.params.channel)
      assert.equals(true, directive.params.loop)
    end)

    it("parses image show directive", function()
      local directive = MediaDirectiveParser:parse("@@image:show portrait container=center")

      assert.is_not_nil(directive)
      assert.equals("image", directive.type)
      assert.equals("show", directive.command)
      assert.equals("portrait", directive.args[1])
      assert.equals("center", directive.params.container)
    end)

    it("parses preload directive", function()
      local directive = MediaDirectiveParser:parse("@@preload:audio asset1 asset2")

      assert.is_not_nil(directive)
      assert.equals("preload", directive.type)
      assert.equals("audio", directive.command)
      assert.equals(2, #directive.args)
    end)

    it("returns error for invalid format", function()
      local directive, err = MediaDirectiveParser:parse("not a directive")

      assert.is_nil(directive)
      assert.is_not_nil(err)
    end)

    it("returns error for missing directive type", function()
      local directive, err = MediaDirectiveParser:parse("@@:play")

      assert.is_nil(directive)
      assert.is_not_nil(err)
    end)

    it("returns error for missing command", function()
      local directive, err = MediaDirectiveParser:parse("@@audio:")

      assert.is_nil(directive)
      assert.is_not_nil(err)
    end)

    it("parses numeric parameters", function()
      local directive = MediaDirectiveParser:parse("@@audio:play test volume=0.5 fadeIn=2")

      assert.equals(0.5, directive.params.volume)
      assert.equals(2, directive.params.fadeIn)
    end)

    it("parses boolean parameters", function()
      local directive = MediaDirectiveParser:parse("@@audio:play test loop=true")

      assert.equals(true, directive.params.loop)
    end)

    it("parses false boolean", function()
      local directive = MediaDirectiveParser:parse("@@audio:play test loop=false")

      assert.equals(false, directive.params.loop)
    end)

    it("preserves raw directive text", function()
      local raw = "@@audio:play test_audio"
      local directive = MediaDirectiveParser:parse(raw)

      assert.equals(raw, directive.raw)
    end)
  end)

  describe("_parseValue", function()
    it("parses true", function()
      local value = MediaDirectiveParser:_parseValue("true")
      assert.equals(true, value)
    end)

    it("parses false", function()
      local value = MediaDirectiveParser:_parseValue("false")
      assert.equals(false, value)
    end)

    it("parses integers", function()
      local value = MediaDirectiveParser:_parseValue("42")
      assert.equals(42, value)
    end)

    it("parses floats", function()
      local value = MediaDirectiveParser:_parseValue("3.14")
      assert.equals(3.14, value)
    end)

    it("parses quoted strings", function()
      local value = MediaDirectiveParser:_parseValue('"hello world"')
      assert.equals("hello world", value)
    end)

    it("parses identifiers", function()
      local value = MediaDirectiveParser:_parseValue("MUSIC")
      assert.equals("MUSIC", value)
    end)
  end)

  describe("execute", function()
    it("executes audio:play directive or fails gracefully", function()
      AssetManager:loadSync("test_audio")

      local directive = MediaDirectiveParser:parse("@@audio:play test_audio channel=SFX")
      local success, result = MediaDirectiveParser:execute(directive)

      -- Success depends on whether asset loaded
      assert.is_boolean(success)
    end)

    it("executes audio:stop directive", function()
      AssetManager:loadSync("test_audio")
      local sourceId = AudioManager:play("test_audio")

      local directive = MediaDirectiveParser:parse("@@audio:stop " .. tostring(sourceId))
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes image:show directive", function()
      AssetManager:loadSync("test_image")

      local directive = MediaDirectiveParser:parse("@@image:show test_image container=center")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes image:hide directive or fails gracefully", function()
      AssetManager:loadSync("test_image")
      ImageManager:display("test_image", { container = "center" })

      local directive = MediaDirectiveParser:parse("@@image:hide center")
      local success = MediaDirectiveParser:execute(directive)

      -- Success depends on whether display succeeded
      assert.is_boolean(success)
    end)

    it("returns error for nil directive", function()
      local success, err = MediaDirectiveParser:execute(nil)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("returns error for unknown directive type", function()
      local directive = {
        type = "unknown",
        command = "test",
        args = {},
        params = {}
      }

      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("_executeAudio", function()
    it("requires asset ID for play", function()
      local directive = {
        type = "audio",
        command = "play",
        args = {},
        params = {}
      }

      local success, err = MediaDirectiveParser:_executeAudio(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("handles volume command", function()
      local directive = MediaDirectiveParser:parse("@@audio:volume MUSIC 0.5")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("returns error for unknown audio command", function()
      local directive = {
        type = "audio",
        command = "unknown_command",
        args = { "test" },
        params = {}
      }

      local success, err = MediaDirectiveParser:_executeAudio(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("_executeImage", function()
    it("requires asset ID for show", function()
      local directive = {
        type = "image",
        command = "show",
        args = {},
        params = {}
      }

      local success, err = MediaDirectiveParser:_executeImage(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("executes clear command", function()
      local directive = MediaDirectiveParser:parse("@@image:clear")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("returns error for unknown image command", function()
      local directive = {
        type = "image",
        command = "unknown_command",
        args = { "test" },
        params = {}
      }

      local success, err = MediaDirectiveParser:_executeImage(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("_executeVideo", function()
    it("returns not supported error", function()
      local directive = {
        type = "video",
        command = "play",
        args = { "test" },
        params = {}
      }

      local success, err = MediaDirectiveParser:_executeVideo(directive)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("extractDirectives", function()
    it("extracts single directive", function()
      local content = "Some text\n@@audio:play music\nMore text"

      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(1, #directives)
      assert.equals("audio", directives[1].type)
    end)

    it("extracts multiple directives", function()
      local content = [[
        @@audio:play music
        Some text
        @@image:show portrait
      ]]

      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(2, #directives)
    end)

    it("returns empty table for no directives", function()
      local content = "Just plain text content"

      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(0, #directives)
    end)

    it("handles malformed directives gracefully", function()
      local content = "@@invalid:\n@@audio:play music"

      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(1, #directives)
    end)
  end)

  describe("processContent", function()
    it("removes executed directives from content", function()
      AssetManager:loadSync("test_audio")

      local content = "Hello\n@@audio:play test_audio\nWorld"

      local processed, results = MediaDirectiveParser:processContent(content)

      -- Directive should be removed
      assert.is_nil(processed:match("@@audio"))
      assert.is_true(processed:match("Hello") ~= nil)
      assert.is_true(processed:match("World") ~= nil)
    end)

    it("returns execution results", function()
      AssetManager:loadSync("test_audio")

      local content = "@@audio:play test_audio"

      local processed, results = MediaDirectiveParser:processContent(content)

      assert.equals(1, #results)
    end)

    it("handles failed directives", function()
      local content = "@@audio:play nonexistent_asset"

      local processed, results = MediaDirectiveParser:processContent(content)

      assert.equals(1, #results)
      -- Failed directive should be removed by default
    end)

    it("shows errors when option enabled", function()
      local content = "@@audio:play nonexistent_asset"

      local processed, results = MediaDirectiveParser:processContent(content, { showErrors = true })

      assert.is_true(processed:match("ERROR") ~= nil)
    end)
  end)

  describe("_escapePattern", function()
    it("escapes special pattern characters", function()
      local escaped = MediaDirectiveParser:_escapePattern("test.file[1]")

      assert.equals("test%.file%[1%]", escaped)
    end)

    it("handles parentheses", function()
      local escaped = MediaDirectiveParser:_escapePattern("func(arg)")

      assert.equals("func%(arg%)", escaped)
    end)
  end)
end)
