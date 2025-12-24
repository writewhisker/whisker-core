-- Tests for BundlingStrategy
describe("BundlingStrategy", function()
  local BundlingStrategy
  local mock_event_bus
  local mock_file_system

  before_each(function()
    package.loaded["whisker.media.bundlers.BundlingStrategy"] = nil
    BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock file system
    mock_file_system = {
      _files = {},
      copy = function(self, src, dest, opts)
        self._files[dest] = true
        return true, nil
      end,
      getSize = function(self, path)
        return 1000
      end
    }
  end)

  describe("isFormatSupported", function()
    it("returns true for supported formats", function()
      local strategy = BundlingStrategy.new()
      local supported = {"mp3", "ogg", "wav"}

      assert.is_true(strategy:isFormatSupported("mp3", supported))
      assert.is_true(strategy:isFormatSupported("ogg", supported))
    end)

    it("returns false for unsupported formats", function()
      local strategy = BundlingStrategy.new()
      local supported = {"mp3", "ogg"}

      assert.is_false(strategy:isFormatSupported("flac", supported))
    end)
  end)

  describe("selectSources", function()
    it("selects matching sources", function()
      local strategy = BundlingStrategy.new()

      local assetConfig = {
        id = "test",
        type = "audio",
        sources = {
          {format = "mp3", path = "test.mp3"},
          {format = "ogg", path = "test.ogg"},
          {format = "flac", path = "test.flac"}
        }
      }

      local selected = strategy:selectSources(assetConfig, {"mp3", "ogg"})

      assert.equals(2, #selected)
    end)

    it("selects from variants", function()
      local strategy = BundlingStrategy.new()

      local assetConfig = {
        id = "test",
        type = "image",
        variants = {
          {density = "1x", path = "test.png"},
          {density = "2x", path = "test@2x.png"},
          {density = "1x", path = "test.webp"}
        }
      }

      local selected = strategy:selectSources(assetConfig, {"png"})

      assert.equals(2, #selected)
    end)
  end)

  describe("getFileSize", function()
    it("returns 0 for missing files", function()
      local strategy = BundlingStrategy.new()
      local size = strategy:getFileSize("/nonexistent/file.txt")
      assert.equals(0, size)
    end)

    it("uses injected file_system when available", function()
      local strategy = BundlingStrategy.new({}, {file_system = mock_file_system})
      local size = strategy:getFileSize("/any/path.txt")
      assert.equals(1000, size)
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(BundlingStrategy._dependencies)
      assert.same({"file_system", "event_bus"}, BundlingStrategy._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(BundlingStrategy.create)
    end)

    it("provides new constructor", function()
      assert.is_function(BundlingStrategy.new)
    end)

    it("create returns a factory function", function()
      local factory = BundlingStrategy.create({
        file_system = mock_file_system,
        event_bus = mock_event_bus
      })
      assert.is_function(factory)
    end)

    it("factory creates strategy instances with injected deps", function()
      local factory = BundlingStrategy.create({
        file_system = mock_file_system,
        event_bus = mock_event_bus
      })
      local strategy = factory({})
      assert.is_not_nil(strategy)
      assert.equals(mock_file_system, strategy._file_system)
      assert.equals(mock_event_bus, strategy._event_bus)
    end)

    it("new creates instance with injected file_system", function()
      local strategy = BundlingStrategy.new({}, {file_system = mock_file_system})
      assert.equals(mock_file_system, strategy._file_system)
    end)

    it("new creates instance with injected event_bus", function()
      local strategy = BundlingStrategy.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, strategy._event_bus)
    end)

    it("works without deps (backward compatibility)", function()
      local strategy = BundlingStrategy.new({})
      assert.is_not_nil(strategy)
    end)
  end)

  describe("file_system injection", function()
    it("uses injected file_system for copyAsset", function()
      local strategy = BundlingStrategy.new({}, {file_system = mock_file_system})
      local success, err = strategy:copyAsset("src/test.mp3", "dest/test.mp3", {})
      assert.is_true(success)
      assert.is_true(mock_file_system._files["dest/test.mp3"])
    end)
  end)
end)
