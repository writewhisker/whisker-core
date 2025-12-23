--- Screen Reader Adapter Tests
-- Tests for ScreenReaderAdapter implementation
-- @module tests.a11y.screen_reader_adapter_spec

describe("ScreenReaderAdapter", function()
  local ScreenReaderAdapter
  local adapter
  local mock_event_bus
  local mock_logger

  setup(function()
    ScreenReaderAdapter = require("whisker.a11y.screen_reader_adapter")
  end)

  before_each(function()
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end,
    }

    mock_logger = {
      debug = function() end,
    }

    adapter = ScreenReaderAdapter.new({
      event_bus = mock_event_bus,
      logger = mock_logger,
    })
  end)

  describe("new()", function()
    it("should create an adapter instance", function()
      assert.is_not_nil(adapter)
      assert.is_table(adapter)
    end)

    it("should work without dependencies", function()
      local minimal = ScreenReaderAdapter.new({})
      assert.is_not_nil(minimal)
    end)
  end)

  describe("create()", function()
    it("should be a factory method", function()
      local instance = ScreenReaderAdapter.create({
        event_bus = mock_event_bus,
        logger = mock_logger,
      })
      assert.is_not_nil(instance)
    end)
  end)

  describe("announce()", function()
    it("should emit announcement event", function()
      adapter:announce("Test message", "polite")

      assert.equals(1, #mock_event_bus.events)
      assert.equals("a11y.announcement", mock_event_bus.events[1].event)
      assert.equals("Test message", mock_event_bus.events[1].data.message)
      assert.equals("polite", mock_event_bus.events[1].data.priority)
    end)

    it("should default to polite priority", function()
      adapter:announce("Test message")

      assert.equals("polite", mock_event_bus.events[1].data.priority)
    end)

    it("should not announce empty messages", function()
      adapter:announce("")
      adapter:announce(nil)

      assert.equals(0, #mock_event_bus.events)
    end)
  end)

  describe("announce_passage_change()", function()
    it("should format passage announcement with choices", function()
      adapter:announce_passage_change("The Cave", 3)

      assert.equals(1, #mock_event_bus.events)
      local message = mock_event_bus.events[1].data.message
      assert.truthy(message:match("The Cave"))
      assert.truthy(message:match("3 choices"))
    end)

    it("should format single choice correctly", function()
      adapter:announce_passage_change("The Cave", 1)

      local message = mock_event_bus.events[1].data.message
      assert.truthy(message:match("1 choice available"))
    end)

    it("should work without choices", function()
      adapter:announce_passage_change("The End")

      local message = mock_event_bus.events[1].data.message
      assert.truthy(message:match("The End"))
      assert.is_nil(message:match("choices"))
    end)
  end)

  describe("announce_choice_selection()", function()
    it("should format choice selection announcement", function()
      adapter:announce_choice_selection("Go north")

      local message = mock_event_bus.events[1].data.message
      assert.truthy(message:match("Selected"))
      assert.truthy(message:match("Go north"))
    end)
  end)

  describe("announce_error()", function()
    it("should use assertive priority for errors", function()
      adapter:announce_error("Something went wrong")

      assert.equals("assertive", mock_event_bus.events[1].data.priority)
      assert.truthy(mock_event_bus.events[1].data.message:match("Error"))
    end)
  end)

  describe("announce_loading()", function()
    it("should announce loading start", function()
      adapter:announce_loading(true)

      assert.truthy(mock_event_bus.events[1].data.message:match("Loading"))
    end)

    it("should announce loading complete", function()
      adapter:announce_loading(false)

      assert.truthy(mock_event_bus.events[1].data.message:match("complete"))
    end)
  end)

  describe("clear_announcements()", function()
    it("should clear the announcement queue", function()
      adapter:clear_announcements()
      -- Should not throw error
      assert.is_true(true)
    end)
  end)

  describe("get_live_region_html()", function()
    it("should return valid HTML", function()
      local html = adapter:get_live_region_html()

      assert.truthy(html:match('aria%-live="polite"'))
      assert.truthy(html:match('aria%-live="assertive"'))
      assert.truthy(html:match('aria%-atomic="true"'))
    end)
  end)

  describe("init_live_regions()", function()
    it("should store live region references", function()
      local polite = {set_text = function() end}
      local assertive = {set_text = function() end}

      adapter:init_live_regions(polite, assertive)

      assert.equals(polite, adapter:get_live_region("polite"))
      assert.equals(assertive, adapter:get_live_region("assertive"))
    end)
  end)
end)
