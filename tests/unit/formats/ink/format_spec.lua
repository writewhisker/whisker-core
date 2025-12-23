--- Ink Format Tests
-- Tests for InkFormat IFormat implementation
-- @module tests.unit.formats.ink.format_spec

describe("InkFormat", function()
  local InkFormat
  local mock_events
  local mock_logger

  before_each(function()
    -- Clear module cache for fresh tests
    package.loaded["whisker.formats.ink"] = nil
    package.loaded["whisker.formats.ink.converter"] = nil
    package.loaded["whisker.formats.ink.exporter"] = nil

    InkFormat = require("whisker.formats.ink")

    mock_events = {
      emit = function() end,
      on = function() return function() end end,
    }

    mock_logger = {
      debug = function() end,
      info = function() end,
      warn = function() end,
      error = function() end,
    }
  end)

  describe("new", function()
    it("creates instance with dependencies", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      assert.is_not_nil(format)
      assert.equals(mock_events, format.events)
      assert.equals(mock_logger, format.log)
    end)
  end)

  describe("get_name", function()
    it("returns 'ink'", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      assert.equals("ink", format:get_name())
    end)
  end)

  describe("get_extensions", function()
    it("returns supported extensions", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local extensions = format:get_extensions()
      assert.is_table(extensions)
      assert.is_true(#extensions > 0)
    end)

    it("includes .ink.json", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local extensions = format:get_extensions()
      local found = false
      for _, ext in ipairs(extensions) do
        if ext == ".ink.json" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("get_mime_type", function()
    it("returns application/json", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      assert.equals("application/json", format:get_mime_type())
    end)
  end)

  describe("can_import", function()
    it("returns true for valid Ink JSON", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local valid_ink = '{"inkVersion": 21, "root": ["done"]}'
      assert.is_true(format:can_import(valid_ink))
    end)

    it("returns false for non-string input", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      assert.is_false(format:can_import(nil))
      assert.is_false(format:can_import(123))
      assert.is_false(format:can_import({}))
    end)

    it("returns false for non-Ink JSON", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local not_ink = '{"foo": "bar"}'
      assert.is_false(format:can_import(not_ink))
    end)

    it("returns false for missing inkVersion", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local missing_version = '{"root": ["done"]}'
      assert.is_false(format:can_import(missing_version))
    end)

    it("returns false for missing root", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local missing_root = '{"inkVersion": 21}'
      assert.is_false(format:can_import(missing_root))
    end)
  end)

  describe("can_export", function()
    it("returns false for nil story", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      assert.is_false(format:can_export(nil))
    end)

    it("returns true for valid story", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local story = {
        passages = {
          { id = "start", content = "Hello" },
        },
      }
      assert.is_true(format:can_export(story))
    end)

    it("returns false for story with no passages", function()
      local format = InkFormat.new({
        events = mock_events,
        logger = mock_logger,
      })

      local empty_story = {
        passages = {},
      }
      assert.is_false(format:can_export(empty_story))
    end)
  end)
end)
