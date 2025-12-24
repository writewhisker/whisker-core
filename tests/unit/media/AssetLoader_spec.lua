-- Tests for AssetLoader module
describe("AssetLoader", function()
  local AssetLoader
  local mock_event_bus
  local mock_format_detector
  local mock_file_system

  before_each(function()
    package.loaded["whisker.media.AssetLoader"] = nil
    package.loaded["whisker.media.types"] = nil
    package.loaded["whisker.media.FormatDetector"] = nil
    AssetLoader = require("whisker.media.AssetLoader")

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock format detector
    mock_format_detector = {
      detectPlatform = function() return "lua" end,
      selectBestFormat = function(self, sources, asset_type)
        return sources and sources[1] or nil
      end,
      getFormatFromPath = function(self, path)
        return path:match("%.(%w+)$")
      end,
      getAssetTypeFromFormat = function(self, format)
        if format == "mp3" or format == "ogg" or format == "wav" then
          return "audio"
        elseif format == "png" or format == "jpg" or format == "jpeg" then
          return "image"
        end
        return "data"
      end
    }

    -- Create mock file system
    mock_file_system = {
      files = {},
      read = function(self, path, asset_type)
        local content = self.files[path]
        if content then
          return {raw = content, path = path, size = #content}, nil
        end
        return nil, "File not found: " .. path
      end,
      exists = function(self, path)
        return self.files[path] ~= nil
      end
    }
  end)

  describe("new", function()
    it("creates loader with default config", function()
      local loader = AssetLoader.new()
      assert.is_not_nil(loader)
    end)

    it("creates loader with custom base path", function()
      local loader = AssetLoader.new({basePath = "/assets"})
      assert.equals("/assets", loader._basePath)
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(AssetLoader._dependencies)
      assert.same({"event_bus", "format_detector", "file_system"}, AssetLoader._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(AssetLoader.create)
    end)

    it("create returns a factory function", function()
      local factory = AssetLoader.create({
        event_bus = mock_event_bus,
        format_detector = mock_format_detector
      })
      assert.is_function(factory)
    end)

    it("factory creates loader instances with injected deps", function()
      local factory = AssetLoader.create({
        event_bus = mock_event_bus,
        format_detector = mock_format_detector
      })
      local loader = factory({basePath = "/test"})
      assert.is_not_nil(loader)
      assert.equals("/test", loader._basePath)
    end)

    it("stores event_bus dependency", function()
      local loader = AssetLoader.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, loader._event_bus)
    end)

    it("stores format_detector dependency", function()
      local loader = AssetLoader.new({}, {format_detector = mock_format_detector})
      assert.equals(mock_format_detector, loader._format_detector)
    end)

    it("stores file_system dependency", function()
      local loader = AssetLoader.new({}, {file_system = mock_file_system})
      assert.equals(mock_file_system, loader._file_system)
    end)

    it("works without deps (backward compatibility)", function()
      local loader = AssetLoader.new({basePath = "/test"})
      assert.is_not_nil(loader)
      assert.is_not_nil(loader._format_detector)
    end)
  end)

  describe("isLoading", function()
    it("returns false for non-loading assets", function()
      local loader = AssetLoader.new()
      assert.is_false(loader:isLoading("test"))
    end)
  end)

  describe("cancel", function()
    it("returns false for non-loading assets", function()
      local loader = AssetLoader.new()
      assert.is_false(loader:cancel("test"))
    end)
  end)

  describe("exists", function()
    it("uses injected file_system when available", function()
      mock_file_system.files["/test/file.png"] = "test content"
      local loader = AssetLoader.new({}, {file_system = mock_file_system})
      assert.is_true(loader:exists("/test/file.png"))
      assert.is_false(loader:exists("/test/missing.png"))
    end)

    it("falls back to io.open when no file_system", function()
      local loader = AssetLoader.new()
      assert.is_false(loader:exists("/nonexistent/file.txt"))
    end)
  end)

  describe("detectType", function()
    it("detects audio types", function()
      local loader = AssetLoader.new({}, {format_detector = mock_format_detector})
      assert.equals("audio", loader:detectType("/path/to/file.mp3"))
      assert.equals("audio", loader:detectType("/path/to/file.ogg"))
    end)

    it("detects image types", function()
      local loader = AssetLoader.new({}, {format_detector = mock_format_detector})
      assert.equals("image", loader:detectType("/path/to/file.png"))
      assert.equals("image", loader:detectType("/path/to/file.jpg"))
    end)

    it("returns data for unknown types", function()
      local loader = AssetLoader.new({}, {format_detector = mock_format_detector})
      assert.equals("data", loader:detectType("/path/to/file.xyz"))
    end)
  end)

  describe("load with file_system", function()
    it("uses injected file_system for loading", function()
      mock_file_system.files["/test/audio.mp3"] = "mock audio content"
      local loader = AssetLoader.new({}, {
        file_system = mock_file_system,
        format_detector = mock_format_detector,
        event_bus = mock_event_bus
      })

      local loaded = false
      loader:load({
        id = "test_audio",
        type = "audio",
        sources = {{path = "/test/audio.mp3", format = "mp3"}}
      }, function(asset, err)
        loaded = true
        assert.is_nil(err)
        assert.is_not_nil(asset)
        assert.equals("test_audio", asset.id)
      end)

      assert.is_true(loaded)
    end)
  end)

  describe("event emission", function()
    it("emits loader:start event when loading", function()
      mock_file_system.files["/test/file.mp3"] = "content"
      local loader = AssetLoader.new({}, {
        event_bus = mock_event_bus,
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      loader:load({
        id = "test",
        type = "audio",
        sources = {{path = "/test/file.mp3", format = "mp3"}}
      })

      local found_start = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "loader:start" then
          found_start = true
          assert.equals("test", e.data.assetId)
          assert.equals("audio", e.data.assetType)
        end
      end
      assert.is_true(found_start, "Should have emitted loader:start event")
    end)

    it("emits loader:complete event on success", function()
      mock_file_system.files["/test/file.mp3"] = "content"
      local loader = AssetLoader.new({}, {
        event_bus = mock_event_bus,
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      loader:load({
        id = "test",
        type = "audio",
        sources = {{path = "/test/file.mp3", format = "mp3"}}
      })

      local found_complete = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "loader:complete" then
          found_complete = true
          assert.equals("test", e.data.assetId)
        end
      end
      assert.is_true(found_complete, "Should have emitted loader:complete event")
    end)

    it("emits loader:error event on failure", function()
      local loader = AssetLoader.new({}, {
        event_bus = mock_event_bus,
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      loader:load({
        id = "test",
        type = "audio",
        sources = {{path = "/nonexistent/file.mp3", format = "mp3"}}
      })

      local found_error = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "loader:error" then
          found_error = true
          assert.equals("test", e.data.assetId)
        end
      end
      assert.is_true(found_error, "Should have emitted loader:error event")
    end)

    it("does not emit events when event_bus is nil", function()
      local loader = AssetLoader.new({}, {
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      mock_file_system.files["/test/file.mp3"] = "content"

      -- Should not error
      loader:load({
        id = "test",
        type = "audio",
        sources = {{path = "/test/file.mp3", format = "mp3"}}
      })
    end)
  end)

  describe("loadAsync", function()
    it("provides async loading interface", function()
      mock_file_system.files["/test/file.mp3"] = "content"
      local loader = AssetLoader.new({}, {
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      local called = false
      loader:loadAsync("/test/file.mp3", function(success, result)
        called = true
        assert.is_true(success)
        assert.is_not_nil(result)
      end, "audio")

      assert.is_true(called)
    end)

    it("auto-detects asset type from path", function()
      mock_file_system.files["/test/image.png"] = "png content"
      local loader = AssetLoader.new({}, {
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      local asset_type_received = nil
      loader:loadAsync("/test/image.png", function(success, result)
        if success then
          asset_type_received = result.type
        end
      end)

      assert.equals("image", asset_type_received)
    end)
  end)

  describe("loadSync", function()
    it("returns asset synchronously", function()
      mock_file_system.files["/test/file.mp3"] = "content"
      local loader = AssetLoader.new({}, {
        format_detector = mock_format_detector,
        file_system = mock_file_system
      })

      local asset, err = loader:loadSync({
        id = "test",
        type = "audio",
        sources = {{path = "/test/file.mp3", format = "mp3"}}
      })

      assert.is_nil(err)
      assert.is_not_nil(asset)
      assert.equals("test", asset.id)
    end)
  end)
end)
