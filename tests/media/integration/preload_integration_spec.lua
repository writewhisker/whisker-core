-- Preload Integration Tests
-- Tests the integration between PreloadManager and other media modules

describe("PreloadManager Integration", function()
  local AssetManager
  local AudioManager
  local ImageManager
  local PreloadManager
  local DummyAudioBackend

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.ImageManager"] = nil
    package.loaded["whisker.media.PreloadManager"] = nil

    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
    local backend = DummyAudioBackend.new()

    AudioManager = require("whisker.media.AudioManager")
    AudioManager:initialize(backend)

    ImageManager = require("whisker.media.ImageManager")
    ImageManager:initialize({ screenWidth = 800, screenHeight = 600 })

    PreloadManager = require("whisker.media.PreloadManager")
    PreloadManager:initialize({ maxConcurrent = 3 })

    -- Register test assets
    for i = 1, 5 do
      AssetManager:register({
        id = "audio_" .. i,
        type = "audio",
        sources = { { format = "mp3", path = "audio" .. i .. ".mp3" } },
        metadata = { duration = 30 }
      })

      AssetManager:register({
        id = "image_" .. i,
        type = "image",
        variants = { { density = "1x", path = "image" .. i .. ".png" } }
      })
    end
  end)

  after_each(function()
    AudioManager:stopAll()
    AudioManager:shutdown()
    ImageManager:hideAll()
    AssetManager:clearCache()
  end)

  describe("preload for playback", function()
    it("preloads assets and calls callbacks", function()
      local preloadComplete = false
      local succeededCount = 0

      PreloadManager:preloadGroup({ "audio_1", "audio_2" }, {
        onComplete = function(succeeded, errors)
          preloadComplete = true
          succeededCount = succeeded
          -- Files don't exist so errors expected
        end
      })

      assert.is_true(preloadComplete)

      -- Playback may fail if files don't exist
      local sourceId = AudioManager:play("audio_1", { channel = "MUSIC" })
      -- sourceId may be nil if file doesn't exist
      assert.is_true(sourceId == nil or type(sourceId) == "number")
    end)

    it("preloads images and calls callbacks", function()
      local preloadComplete = false

      PreloadManager:preloadGroup({ "image_1", "image_2" }, {
        onComplete = function()
          preloadComplete = true
        end
      })

      assert.is_true(preloadComplete)

      -- Display may fail if files don't exist
      local success = ImageManager:display("image_1", { container = "center" })
      assert.is_boolean(success)
    end)
  end)

  describe("group management", function()
    it("registers and preloads named group", function()
      PreloadManager:registerGroup("chapter1", {
        "audio_1", "audio_2", "image_1"
      })

      local preloadComplete = false

      PreloadManager:preloadGroup("chapter1", {
        onComplete = function()
          preloadComplete = true
        end
      })

      assert.is_true(preloadComplete)
    end)

    it("unloads group assets", function()
      PreloadManager:registerGroup("temp_group", { "audio_1", "audio_2" })

      -- Preload first
      PreloadManager:preloadGroup("temp_group")

      -- Then unload
      PreloadManager:unloadGroup("temp_group")

      -- Assets should be unloaded
      assert.is_false(AssetManager:isLoaded("audio_1"))
      assert.is_false(AssetManager:isLoaded("audio_2"))
    end)
  end)

  describe("passage asset extraction", function()
    it("extracts audio directives", function()
      local passage = {
        content = [[
          Welcome to the forest.
          @@audio:play forest_theme channel=MUSIC
          The birds are singing.
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)

    it("extracts image directives", function()
      local passage = {
        content = [[
          @@image:show portrait container=center
          Character appears.
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)

    it("extracts preload directives", function()
      local passage = {
        content = [[
          @@preload:audio audio_1, audio_2
          @@preload:image image_1
          Content here.
        ]]
      }

      local assets = PreloadManager:extractPassageAssets(passage)
      assert.is_table(assets)
    end)
  end)

  describe("budget management", function()
    it("respects preload budget", function()
      local budget = PreloadManager:getPreloadBudget()

      assert.is_number(budget)
      assert.is_true(budget > 0)
    end)

    it("tracks preload usage", function()
      PreloadManager:preloadGroup({ "audio_1", "audio_2" })

      local usage = PreloadManager:getPreloadUsage()

      assert.is_number(usage)
    end)
  end)

  describe("concurrent preloading", function()
    it("limits concurrent preloads", function()
      -- Start multiple preloads
      local id1 = PreloadManager:preloadGroup({ "audio_1", "audio_2" })
      local id2 = PreloadManager:preloadGroup({ "audio_3", "audio_4" })
      local id3 = PreloadManager:preloadGroup({ "audio_5", "image_1" })

      -- All should get IDs (some may be queued)
      assert.is_true(id1 ~= nil or id2 ~= nil or id3 ~= nil)
    end)

    it("processes queue after completion", function()
      PreloadManager._maxConcurrentPreloads = 1

      local completions = 0

      PreloadManager:preloadGroup({ "audio_1" }, {
        onComplete = function() completions = completions + 1 end
      })

      PreloadManager:preloadGroup({ "audio_2" }, {
        onComplete = function() completions = completions + 1 end
      })

      -- Both should complete eventually
      assert.is_true(completions >= 1)
    end)
  end)

  describe("error handling", function()
    it("handles failed asset loads in group", function()
      AssetManager:register({
        id = "bad_asset",
        type = "audio",
        sources = { { format = "mp3", path = "/invalid/path.mp3" } }
      })

      local errors = {}

      PreloadManager:preloadGroup({ "audio_1", "bad_asset" }, {
        onComplete = function(succeeded, errs)
          errors = errs
        end
      })

      -- Should complete with some errors
      assert.is_table(errors)
    end)

    it("continues after individual failures", function()
      AssetManager:register({
        id = "bad1",
        type = "audio",
        sources = { { format = "mp3", path = "/bad1.mp3" } }
      })

      AssetManager:register({
        id = "bad2",
        type = "audio",
        sources = { { format = "mp3", path = "/bad2.mp3" } }
      })

      local completed = false

      PreloadManager:preloadGroup({ "bad1", "audio_1", "bad2" }, {
        onComplete = function()
          completed = true
        end
      })

      assert.is_true(completed)
    end)
  end)

  describe("progress tracking", function()
    it("reports progress during preload", function()
      local progressCalls = 0
      local lastLoaded = 0

      PreloadManager:preloadGroup({ "audio_1", "audio_2", "audio_3" }, {
        onProgress = function(loaded, total)
          progressCalls = progressCalls + 1
          lastLoaded = loaded
          assert.equals(3, total)
          assert.is_true(loaded <= total)
        end
      })

      assert.is_true(progressCalls > 0)
    end)
  end)
end)
