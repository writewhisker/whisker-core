-- Tests for MediaDirectiveParser
describe("MediaDirectiveParser", function()
  local MediaDirectiveParser, AssetManager, AudioManager, PreloadManager

  -- Helper to register and cache an asset for testing
  local function registerAndCacheAsset(id, assetType)
    AssetManager:register({
      id = id,
      type = assetType,
      sources = {{format = assetType == "audio" and "mp3" or "png", path = id .. (assetType == "audio" and ".mp3" or ".png")}}
    })
    -- Manually put asset in cache (simulating a loaded asset)
    AssetManager._cache:set(id, {
      id = id,
      type = assetType,
      data = "mock_data",
      sizeBytes = 1024
    }, 1024)
    AssetManager._states[id] = require("whisker.media.types").AssetState.LOADED
  end

  before_each(function()
    package.loaded["whisker.media.MediaDirectiveParser"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.PreloadManager"] = nil
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.types"] = nil

    MediaDirectiveParser = require("whisker.media.MediaDirectiveParser")
    AssetManager = require("whisker.media.AssetManager")
    AudioManager = require("whisker.media.AudioManager")
    PreloadManager = require("whisker.media.PreloadManager")

    AssetManager:initialize()
    local DummyBackend = require("whisker.media.backends.DummyAudioBackend")
    AudioManager:initialize(DummyBackend.new())
    PreloadManager:initialize()
  end)

  describe("parse", function()
    it("parses audio:play directive", function()
      local directive = MediaDirectiveParser:parse("@@audio:play forest_theme channel=MUSIC loop=true volume=0.7")

      assert.equals("audio", directive.type)
      assert.equals("play", directive.command)
      assert.equals("forest_theme", directive.args[1])
      assert.equals("MUSIC", directive.params.channel)
      assert.equals(true, directive.params.loop)
      assert.equals(0.7, directive.params.volume)
    end)

    it("parses audio:stop directive with fadeOut", function()
      local directive = MediaDirectiveParser:parse("@@audio:stop forest_theme fadeOut=1.5")

      assert.equals("audio", directive.type)
      assert.equals("stop", directive.command)
      assert.equals("forest_theme", directive.args[1])
      assert.equals(1.5, directive.params.fadeOut)
    end)

    it("parses audio:crossfade directive", function()
      local directive = MediaDirectiveParser:parse("@@audio:crossfade forest_theme cave_theme duration=3")

      assert.equals("audio", directive.type)
      assert.equals("crossfade", directive.command)
      assert.equals("forest_theme", directive.args[1])
      assert.equals("cave_theme", directive.args[2])
      assert.equals(3, directive.params.duration)
    end)

    it("parses image:show directive", function()
      local directive = MediaDirectiveParser:parse("@@image:show portrait_alice position=left fadeIn=0.5")

      assert.equals("image", directive.type)
      assert.equals("show", directive.command)
      assert.equals("portrait_alice", directive.args[1])
      assert.equals("left", directive.params.position)
      assert.equals(0.5, directive.params.fadeIn)
    end)

    it("parses image:hide directive", function()
      local directive = MediaDirectiveParser:parse("@@image:hide portrait_alice fadeOut=0.3")

      assert.equals("image", directive.type)
      assert.equals("hide", directive.command)
      assert.equals("portrait_alice", directive.args[1])
      assert.equals(0.3, directive.params.fadeOut)
    end)

    it("parses image:clear directive", function()
      local directive = MediaDirectiveParser:parse("@@image:clear")

      assert.equals("image", directive.type)
      assert.equals("clear", directive.command)
    end)

    it("parses preload:audio directive with multiple assets", function()
      local directive = MediaDirectiveParser:parse("@@preload:audio forest_theme cave_theme footstep")

      assert.equals("preload", directive.type)
      assert.equals("audio", directive.command)
      assert.equals(3, #directive.args)
      assert.equals("forest_theme", directive.args[1])
      assert.equals("cave_theme", directive.args[2])
      assert.equals("footstep", directive.args[3])
    end)

    it("parses preload:image directive", function()
      local directive = MediaDirectiveParser:parse("@@preload:image portrait_alice portrait_bob")

      assert.equals("preload", directive.type)
      assert.equals("image", directive.command)
      assert.equals(2, #directive.args)
    end)

    it("parses preload:group directive", function()
      local directive = MediaDirectiveParser:parse("@@preload:group chapter_2")

      assert.equals("preload", directive.type)
      assert.equals("group", directive.command)
      assert.equals("chapter_2", directive.args[1])
    end)

    it("parses video:play directive", function()
      local directive = MediaDirectiveParser:parse("@@video:play cutscene_intro fullscreen=true")

      assert.equals("video", directive.type)
      assert.equals("play", directive.command)
      assert.equals("cutscene_intro", directive.args[1])
      assert.equals(true, directive.params.fullscreen)
    end)

    it("rejects invalid directive format", function()
      local directive, err = MediaDirectiveParser:parse("invalid directive")

      assert.is_nil(directive)
      assert.is_not_nil(err)
    end)

    it("rejects directive without type", function()
      local directive, err = MediaDirectiveParser:parse("@@:play something")

      assert.is_nil(directive)
    end)

    it("rejects directive without command", function()
      local directive, err = MediaDirectiveParser:parse("@@audio:")

      assert.is_nil(directive)
      assert.is_not_nil(err)
    end)

    it("stores raw directive text", function()
      local rawText = "@@audio:play test volume=0.5"
      local directive = MediaDirectiveParser:parse(rawText)

      assert.equals(rawText, directive.raw)
    end)
  end)

  describe("_parseValue", function()
    it("parses boolean true", function()
      assert.equals(true, MediaDirectiveParser:_parseValue("true"))
    end)

    it("parses boolean false", function()
      assert.equals(false, MediaDirectiveParser:_parseValue("false"))
    end)

    it("parses integers", function()
      assert.equals(42, MediaDirectiveParser:_parseValue("42"))
    end)

    it("parses floats", function()
      assert.equals(0.75, MediaDirectiveParser:_parseValue("0.75"))
    end)

    it("parses quoted strings", function()
      assert.equals("hello world", MediaDirectiveParser:_parseValue("'hello world'"))
      assert.equals("hello world", MediaDirectiveParser:_parseValue('"hello world"'))
    end)

    it("parses identifiers", function()
      assert.equals("MUSIC", MediaDirectiveParser:_parseValue("MUSIC"))
    end)
  end)

  describe("execute", function()
    it("returns false for nil directive", function()
      local success, err = MediaDirectiveParser:execute(nil)
      assert.is_false(success)
    end)

    it("returns false for directive without type", function()
      local success, err = MediaDirectiveParser:execute({})
      assert.is_false(success)
    end)

    it("returns false for unknown directive type", function()
      local success, err = MediaDirectiveParser:execute({type = "unknown", command = "test"})
      assert.is_false(success)
      assert.matches("Unknown directive type", err)
    end)
  end)

  describe("audio execution", function()
    it("executes audio:play directive", function()
      registerAndCacheAsset("test_sound", "audio")

      local directive = MediaDirectiveParser:parse("@@audio:play test_sound channel=MUSIC loop=true")
      local success, result = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails audio:play without asset ID", function()
      local directive = {type = "audio", command = "play", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires asset ID", err)
    end)

    it("executes audio:stop directive", function()
      registerAndCacheAsset("test_sound", "audio")

      -- Play first
      AudioManager:play("test_sound", {channel = "MUSIC"})

      local directive = MediaDirectiveParser:parse("@@audio:stop test_sound fadeOut=0.5")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails audio:stop without target", function()
      local directive = {type = "audio", command = "stop", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires", err)
    end)

    it("executes audio:pause directive", function()
      registerAndCacheAsset("test_sound", "audio")

      local sourceId = AudioManager:play("test_sound", {channel = "MUSIC"})
      assert.is_not_nil(sourceId)

      local directive = MediaDirectiveParser:parse("@@audio:pause " .. sourceId)
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes audio:resume directive", function()
      registerAndCacheAsset("test_sound", "audio")

      local sourceId = AudioManager:play("test_sound", {channel = "MUSIC"})
      assert.is_not_nil(sourceId)
      AudioManager:pause(sourceId)

      local directive = MediaDirectiveParser:parse("@@audio:resume " .. sourceId)
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes audio:volume for channel", function()
      local directive = MediaDirectiveParser:parse("@@audio:volume MUSIC 0.5")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails audio:volume without target", function()
      local directive = {type = "audio", command = "volume", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
    end)

    it("executes audio:crossfade directive", function()
      registerAndCacheAsset("sound_a", "audio")
      registerAndCacheAsset("sound_b", "audio")

      AudioManager:play("sound_a", {channel = "MUSIC"})

      local directive = MediaDirectiveParser:parse("@@audio:crossfade sound_a sound_b duration=2")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails audio command for unknown command", function()
      local directive = {type = "audio", command = "unknown", args = {"test"}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("Unknown audio command", err)
    end)
  end)

  describe("image execution", function()
    local ImageManager

    before_each(function()
      ImageManager = require("whisker.media.ImageManager")
      ImageManager:initialize()
    end)

    it("executes image:show directive", function()
      registerAndCacheAsset("test_image", "image")
      ImageManager:createContainer("default", {width = 800, height = 600})

      local directive = MediaDirectiveParser:parse("@@image:show test_image position=default fadeIn=0.5")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails image:show without asset ID", function()
      local directive = {type = "image", command = "show", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires asset ID", err)
    end)

    it("executes image:hide directive", function()
      registerAndCacheAsset("test_image", "image")
      ImageManager:createContainer("default", {width = 800, height = 600})
      ImageManager:display("test_image", {container = "default"})

      local directive = MediaDirectiveParser:parse("@@image:hide default fadeOut=0.3")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails image:hide without container", function()
      local directive = {type = "image", command = "hide", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires", err)
    end)

    it("executes image:clear directive", function()
      ImageManager:createContainer("container1", {width = 100, height = 100})

      local directive = MediaDirectiveParser:parse("@@image:clear")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails image command for unknown command", function()
      local directive = {type = "image", command = "unknown", args = {"test"}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("Unknown image command", err)
    end)
  end)

  describe("preload execution", function()
    it("executes preload:audio directive", function()
      local directive = MediaDirectiveParser:parse("@@preload:audio sound_a sound_b")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes preload:image directive", function()
      local directive = MediaDirectiveParser:parse("@@preload:image image_a image_b")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("executes preload:group directive", function()
      PreloadManager:registerGroup("test_group", {"asset_a", "asset_b"})

      local directive = MediaDirectiveParser:parse("@@preload:group test_group")
      local success = MediaDirectiveParser:execute(directive)

      assert.is_true(success)
    end)

    it("fails preload without assets", function()
      local directive = {type = "preload", command = "audio", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires", err)
    end)

    it("fails preload:group without group name", function()
      local directive = {type = "preload", command = "group", args = {}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("requires group name", err)
    end)

    it("fails preload for unknown command", function()
      local directive = {type = "preload", command = "unknown", args = {"test"}, params = {}}
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("Unknown preload command", err)
    end)
  end)

  describe("video execution", function()
    it("returns not supported for video directives", function()
      local directive = MediaDirectiveParser:parse("@@video:play cutscene")
      local success, err = MediaDirectiveParser:execute(directive)

      assert.is_false(success)
      assert.matches("not yet supported", err)
    end)
  end)

  describe("extractDirectives", function()
    it("extracts all directives from content", function()
      local content = [[
You enter the forest.
@@audio:play forest_theme loop=true
The trees sway gently.
@@image:show background_forest
A path leads deeper.
]]
      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(2, #directives)
      assert.equals("audio", directives[1].type)
      assert.equals("image", directives[2].type)
    end)

    it("returns empty array for content without directives", function()
      local content = "Just some regular text."
      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(0, #directives)
    end)

    it("handles malformed directives gracefully", function()
      local content = [[
@@audio:play valid_sound
@@invalid
@@audio:
Regular text
]]
      local directives = MediaDirectiveParser:extractDirectives(content)

      assert.equals(1, #directives)
      assert.equals("valid_sound", directives[1].args[1])
    end)
  end)

  describe("processContent", function()
    it("removes executed directives from content", function()
      local content = [[
Hello world.
@@audio:play test_sound
Goodbye.
]]
      registerAndCacheAsset("test_sound", "audio")

      local processed, results = MediaDirectiveParser:processContent(content)

      assert.not_matches("@@audio", processed)
      assert.matches("Hello world", processed)
      assert.matches("Goodbye", processed)
    end)

    it("returns execution results", function()
      local content = "@@audio:play test_sound"
      registerAndCacheAsset("test_sound", "audio")

      local processed, results = MediaDirectiveParser:processContent(content)

      assert.equals(1, #results)
      assert.is_true(results[1].success)
    end)

    it("includes errors in results when showErrors is true", function()
      local content = "@@audio:play missing_asset"

      local processed, results = MediaDirectiveParser:processContent(content, {showErrors = true})

      assert.matches("%[ERROR:", processed)
    end)

    it("silently removes failed directives when showErrors is false", function()
      local content = "Before\n@@audio:play missing_asset\nAfter"

      local processed, results = MediaDirectiveParser:processContent(content, {showErrors = false})

      assert.not_matches("@@audio", processed)
      assert.not_matches("ERROR", processed)
      assert.matches("Before", processed)
      assert.matches("After", processed)
    end)
  end)
end)
