--- Audio & Media Macros Unit Tests
-- Tests for audio playback and media macros
-- @module tests.unit.script.macros.audio.test_audio_spec

describe("Audio Macros", function()
  local Macros, Audio, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Audio = require("whisker.script.macros.audio")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Audio.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Audio.VERSION)
    end)

    it("exports audio macros", function()
      -- Playback control
      assert.is_table(Audio.audio_macro)
      assert.is_table(Audio.play_macro)
      assert.is_table(Audio.stop_macro)
      assert.is_table(Audio.pause_macro)
      assert.is_table(Audio.resume_macro)
      assert.is_table(Audio.volume_macro)
      assert.is_table(Audio.mute_macro)
      assert.is_table(Audio.loop_macro)

      -- Audio management
      assert.is_table(Audio.cacheaudio_macro)
      assert.is_table(Audio.playlist_macro)
      assert.is_table(Audio.masteraudio_macro)
      assert.is_table(Audio.waitforaudio_macro)

      -- Sound types
      assert.is_table(Audio.sfx_macro)
      assert.is_table(Audio.music_macro)
      assert.is_table(Audio.ambience_macro)

      -- Media
      assert.is_table(Audio.image_macro)
      assert.is_table(Audio.video_macro)

      -- Queries
      assert.is_table(Audio.isplaying_macro)
      assert.is_table(Audio.duration_macro)
      assert.is_table(Audio.time_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Audio.register_all)
    end)
  end)

  describe("audio macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates audio data with default play action", function()
      local result = Audio.audio_macro.handler(ctx, { "bgm" })
      assert.is_table(result)
      assert.equals("audio", result._type)
      assert.equals("bgm", result.track)
      assert.equals("play", result.action)
    end)

    it("accepts different actions", function()
      local result = Audio.audio_macro.handler(ctx, { "sfx", "stop" })
      assert.equals("stop", result.action)
    end)

    it("accepts options", function()
      local result = Audio.audio_macro.handler(ctx, { "music", "play", { volume = 0.5, loop = true } })
      assert.equals(0.5, result.options.volume)
      assert.is_true(result.options.loop)
    end)

    it("is audio category", function()
      assert.equals("audio", Audio.audio_macro.category)
    end)
  end)

  describe("play macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates play data", function()
      local result = Audio.play_macro.handler(ctx, { "track1" })
      assert.is_table(result)
      assert.equals("audio_play", result._type)
      assert.equals("track1", result.track)
    end)

    it("defaults volume to 1.0", function()
      local result = Audio.play_macro.handler(ctx, { "track" })
      assert.equals(1.0, result.volume)
    end)

    it("accepts options", function()
      local result = Audio.play_macro.handler(ctx, { "track", { volume = 0.7, loop = true } })
      assert.equals(0.7, result.volume)
      assert.is_true(result.loop)
    end)
  end)

  describe("stop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates stop data for specific track", function()
      local result = Audio.stop_macro.handler(ctx, { "bgm" })
      assert.is_table(result)
      assert.equals("audio_stop", result._type)
      assert.equals("bgm", result.track)
    end)

    it("creates stop data for all tracks", function()
      local result = Audio.stop_macro.handler(ctx, {})
      assert.is_nil(result.track)
    end)

    it("accepts fade duration", function()
      local result = Audio.stop_macro.handler(ctx, { "music", { fadeDuration = 1000 } })
      assert.equals(1000, result.fadeDuration)
    end)
  end)

  describe("pause macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates pause data", function()
      local result = Audio.pause_macro.handler(ctx, { "music" })
      assert.is_table(result)
      assert.equals("audio_pause", result._type)
      assert.equals("music", result.track)
    end)

    it("can pause all tracks", function()
      local result = Audio.pause_macro.handler(ctx, {})
      assert.is_nil(result.track)
    end)
  end)

  describe("resume macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates resume data", function()
      local result = Audio.resume_macro.handler(ctx, { "music" })
      assert.is_table(result)
      assert.equals("audio_resume", result._type)
      assert.equals("music", result.track)
    end)
  end)

  describe("volume macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets volume for track", function()
      local result = Audio.volume_macro.handler(ctx, { "music", 0.5 })
      assert.is_table(result)
      assert.equals("audio_volume", result._type)
      assert.equals("music", result.track)
      assert.equals(0.5, result.volume)
    end)

    it("sets master volume when only number provided", function()
      local result = Audio.volume_macro.handler(ctx, { 0.8 })
      assert.is_nil(result.track)
      assert.equals(0.8, result.volume)
    end)

    it("clamps volume to 0-1 range", function()
      local result1 = Audio.volume_macro.handler(ctx, { "x", 1.5 })
      assert.equals(1, result1.volume)

      local result2 = Audio.volume_macro.handler(ctx, { "x", -0.5 })
      assert.equals(0, result2.volume)
    end)
  end)

  describe("mute macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("mutes track by default", function()
      local result = Audio.mute_macro.handler(ctx, { "sfx" })
      assert.is_table(result)
      assert.equals("audio_mute", result._type)
      assert.is_true(result.muted)
    end)

    it("can unmute track", function()
      local result = Audio.mute_macro.handler(ctx, { "sfx", false })
      assert.is_false(result.muted)
    end)

    it("can mute master", function()
      local result = Audio.mute_macro.handler(ctx, { true })
      assert.is_nil(result.track)
      assert.is_true(result.muted)
    end)
  end)

  describe("loop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("enables looping by default", function()
      local result = Audio.loop_macro.handler(ctx, { "bgm" })
      assert.is_table(result)
      assert.equals("audio_loop", result._type)
      assert.is_true(result.loop)
    end)

    it("can disable looping", function()
      local result = Audio.loop_macro.handler(ctx, { "bgm", false })
      assert.is_false(result.loop)
    end)
  end)

  describe("cacheaudio macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates cache data", function()
      local result = Audio.cacheaudio_macro.handler(ctx, { "bgm", "music.mp3", "music.ogg" })
      assert.is_table(result)
      assert.equals("audio_cache", result._type)
      assert.equals("bgm", result.id)
      assert.equals(2, #result.sources)
    end)

    it("accepts array of sources", function()
      local result = Audio.cacheaudio_macro.handler(ctx, { "sfx", { "a.mp3", "b.mp3" } })
      assert.equals(2, #result.sources)
    end)
  end)

  describe("playlist macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates playlist data", function()
      local tracks = { "track1", "track2", "track3" }
      local result = Audio.playlist_macro.handler(ctx, { "battle", tracks })
      assert.is_table(result)
      assert.equals("audio_playlist", result._type)
      assert.equals("battle", result.id)
      assert.equals(3, #result.tracks)
    end)

    it("accepts options", function()
      local result = Audio.playlist_macro.handler(ctx, { "music", {}, { shuffle = true, loop = true } })
      assert.is_true(result.shuffle)
      assert.is_true(result.loop)
    end)
  end)

  describe("masteraudio macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets master volume", function()
      local result = Audio.masteraudio_macro.handler(ctx, { "volume", 0.5 })
      assert.is_table(result)
      assert.equals("audio_master", result._type)
      assert.equals(0.5, result.volume)
    end)

    it("mutes master", function()
      local result = Audio.masteraudio_macro.handler(ctx, { "mute" })
      assert.is_true(result.muted)
    end)

    it("unmutes master", function()
      local result = Audio.masteraudio_macro.handler(ctx, { "unmute" })
      assert.is_false(result.muted)
    end)

    it("stops all audio", function()
      local result = Audio.masteraudio_macro.handler(ctx, { "stop" })
      assert.is_true(result.stopped)
    end)
  end)

  describe("waitforaudio macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates wait data", function()
      local result = Audio.waitforaudio_macro.handler(ctx, { "speech" })
      assert.is_table(result)
      assert.equals("audio_wait", result._type)
      assert.equals("speech", result.track)
    end)

    it("is async", function()
      assert.is_true(Audio.waitforaudio_macro.async)
    end)
  end)

  describe("sfx macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates sfx data", function()
      local result = Audio.sfx_macro.handler(ctx, { "click" })
      assert.is_table(result)
      assert.equals("sfx", result._type)
      assert.equals("click", result.effect)
    end)

    it("accepts options", function()
      local result = Audio.sfx_macro.handler(ctx, { "explosion", { volume = 0.8, pitch = 1.2 } })
      assert.equals(0.8, result.volume)
      assert.equals(1.2, result.pitch)
    end)
  end)

  describe("music macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates music data", function()
      local result = Audio.music_macro.handler(ctx, { "theme" })
      assert.is_table(result)
      assert.equals("music", result._type)
      assert.equals("theme", result.track)
    end)

    it("loops by default", function()
      local result = Audio.music_macro.handler(ctx, { "bgm" })
      assert.is_true(result.loop)
    end)

    it("accepts crossfade option", function()
      local result = Audio.music_macro.handler(ctx, { "battle", { crossfade = true } })
      assert.is_true(result.crossfade)
    end)
  end)

  describe("ambience macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates ambience data", function()
      local result = Audio.ambience_macro.handler(ctx, { "forest" })
      assert.is_table(result)
      assert.equals("ambience", result._type)
      assert.equals("forest", result.track)
    end)

    it("has lower default volume", function()
      local result = Audio.ambience_macro.handler(ctx, { "rain" })
      assert.equals(0.5, result.volume)
    end)

    it("has longer default fade", function()
      local result = Audio.ambience_macro.handler(ctx, { "wind" })
      assert.equals(2000, result.fadeDuration)
    end)
  end)

  describe("image macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates image data", function()
      local result = Audio.image_macro.handler(ctx, { "hero.png" })
      assert.is_table(result)
      assert.equals("image", result._type)
      assert.equals("hero.png", result.src)
    end)

    it("accepts options", function()
      local result = Audio.image_macro.handler(ctx, { "map.jpg", { width = 400, alt = "Map" } })
      assert.equals(400, result.width)
      assert.equals("Map", result.alt)
    end)
  end)

  describe("video macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates video data", function()
      local result = Audio.video_macro.handler(ctx, { "intro.mp4" })
      assert.is_table(result)
      assert.equals("video", result._type)
      assert.equals("intro.mp4", result.src)
    end)

    it("shows controls by default", function()
      local result = Audio.video_macro.handler(ctx, { "video.mp4" })
      assert.is_true(result.controls)
    end)

    it("accepts options", function()
      local result = Audio.video_macro.handler(ctx, { "cutscene.webm", { autoplay = true, muted = true } })
      assert.is_true(result.autoplay)
      assert.is_true(result.muted)
    end)
  end)

  describe("isplaying macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates query data", function()
      local result = Audio.isplaying_macro.handler(ctx, { "music" })
      assert.is_table(result)
      assert.equals("audio_query", result._type)
      assert.equals("isplaying", result.query)
      assert.equals("music", result.track)
    end)

    it("is pure", function()
      assert.is_true(Audio.isplaying_macro.pure)
    end)
  end)

  describe("duration macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates duration query", function()
      local result = Audio.duration_macro.handler(ctx, { "track" })
      assert.is_table(result)
      assert.equals("audio_query", result._type)
      assert.equals("duration", result.query)
    end)
  end)

  describe("time macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("gets time when no value provided", function()
      local result = Audio.time_macro.handler(ctx, { "track" })
      assert.is_table(result)
      assert.equals("audio_query", result._type)
      assert.equals("time", result.query)
    end)

    it("seeks when value provided", function()
      local result = Audio.time_macro.handler(ctx, { "track", 30 })
      assert.is_table(result)
      assert.equals("audio_seek", result._type)
      assert.equals(30, result.time)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Audio.register_all(registry)

      assert.is_true(count >= 20)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Audio.register_all(registry)

      assert.is_not_nil(registry:get("audio"))
      assert.is_not_nil(registry:get("play"))
      assert.is_not_nil(registry:get("music"))
      assert.is_not_nil(registry:get("sfx"))
      assert.is_not_nil(registry:get("image"))
    end)

    it("audio macros have audio category", function()
      local registry = Registry.new()
      Audio.register_all(registry)

      local macro = registry:get("audio")
      assert.equals("audio", macro.category)
    end)
  end)
end)
