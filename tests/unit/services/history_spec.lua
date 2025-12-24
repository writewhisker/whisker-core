--- HistoryService Unit Tests
-- @module tests.unit.services.history_spec
-- @author Whisker Core Team

describe("HistoryService", function()
  local HistoryService
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    HistoryService = require("whisker.services.history")
  end)

  describe("initialization", function()
    it("creates history service without container", function()
      local history = HistoryService.new(nil)
      assert.is_not_nil(history)
      assert.equals(0, history:depth())
    end)

    it("creates history service with container", function()
      local container = TestContainer.create()
      local history = HistoryService.new(container)
      assert.is_not_nil(history)
    end)
  end)

  describe("push operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("pushes passage to history", function()
      history:push("passage1")
      assert.equals(1, history:depth())
    end)

    it("pushes multiple passages", function()
      history:push("passage1")
      history:push("passage2")
      history:push("passage3")
      assert.equals(3, history:depth())
    end)

    it("enforces max size", function()
      history:set_max_size(3)
      history:push("p1")
      history:push("p2")
      history:push("p3")
      history:push("p4")

      assert.equals(3, history:depth())
      -- First entry should have been removed
      local all = history:get_all()
      assert.equals("p2", all[1].passage_id)
    end)
  end)

  describe("pop operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("pops most recent entry", function()
      history:push("passage1")
      history:push("passage2")

      local entry = history:pop()

      assert.equals("passage2", entry.passage_id)
      assert.equals(1, history:depth())
    end)

    it("returns nil for empty history", function()
      local entry = history:pop()
      assert.is_nil(entry)
    end)
  end)

  describe("peek operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("peeks at most recent entry", function()
      history:push("passage1")
      history:push("passage2")

      local entry = history:peek()

      assert.equals("passage2", entry.passage_id)
      assert.equals(2, history:depth())  -- unchanged
    end)

    it("returns nil for empty history", function()
      local entry = history:peek()
      assert.is_nil(entry)
    end)
  end)

  describe("back operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("goes back one step", function()
      history:push("p1")
      history:push("p2")
      history:push("p3")

      local passage_id = history:back()

      assert.equals("p2", passage_id)
      assert.equals(2, history:depth())
    end)

    it("goes back multiple steps", function()
      history:push("p1")
      history:push("p2")
      history:push("p3")
      history:push("p4")

      local passage_id = history:back(2)

      assert.equals("p2", passage_id)
      assert.equals(2, history:depth())
    end)

    it("returns nil when cannot go back", function()
      history:push("p1")
      local passage_id = history:back()
      assert.is_nil(passage_id)
    end)
  end)

  describe("can_back operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("returns true when can go back", function()
      history:push("p1")
      history:push("p2")
      assert.is_true(history:can_back())
    end)

    it("returns false when cannot go back", function()
      history:push("p1")
      assert.is_false(history:can_back())
    end)

    it("checks for multiple steps", function()
      history:push("p1")
      history:push("p2")
      history:push("p3")

      assert.is_true(history:can_back(2))
      assert.is_false(history:can_back(3))
    end)
  end)

  describe("go_back operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("goes back and returns previous entry", function()
      history:push("p1")
      history:push("p2")

      local entry = history:go_back()

      assert.equals("p1", entry.passage_id)
      assert.equals(1, history:depth())
    end)

    it("returns nil when cannot go back", function()
      history:push("p1")
      local entry = history:go_back()
      assert.is_nil(entry)
    end)
  end)

  describe("get_history/get_all", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("returns all history entries", function()
      history:push("p1")
      history:push("p2")
      history:push("p3")

      local all = history:get_all()

      assert.equals(3, #all)
      assert.equals("p1", all[1].passage_id)
      assert.equals("p2", all[2].passage_id)
      assert.equals("p3", all[3].passage_id)
    end)

    it("returns empty table for empty history", function()
      local all = history:get_all()
      assert.same({}, all)
    end)
  end)

  describe("clear operation", function()
    local history

    before_each(function()
      history = HistoryService.new(nil)
    end)

    it("clears all history", function()
      history:push("p1")
      history:push("p2")
      history:clear()

      assert.equals(0, history:depth())
    end)
  end)

  describe("event handling", function()
    local history, events

    before_each(function()
      local container = TestContainer.create()
      events = container:resolve("events")
      history = HistoryService.new(container)
    end)

    it("auto-pushes on passage:entered event", function()
      events:emit("passage:entered", { passage = { id = "auto_passage" } })

      -- Give time for event handling
      assert.equals(1, history:depth())
      assert.equals("auto_passage", history:peek().passage_id)
    end)

    it("handles passage_id format in event", function()
      events:emit("passage:entered", { passage_id = "simple_passage" })

      assert.equals(1, history:depth())
      assert.equals("simple_passage", history:peek().passage_id)
    end)
  end)

  describe("destroy", function()
    it("cleans up subscriptions and history", function()
      local container = TestContainer.create()
      local history = HistoryService.new(container)

      history:push("p1")
      history:destroy()

      assert.equals(0, history:depth())
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(HistoryService._dependencies)
      assert.same({"event_bus", "state", "logger"}, HistoryService._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(HistoryService.create)
    end)

    it("create returns a factory function", function()
      local mock_event_bus = {
        emit = function() end,
        on = function() return function() end end
      }
      local mock_logger = { debug = function() end }

      local factory = HistoryService.create({
        event_bus = mock_event_bus,
        logger = mock_logger
      })

      assert.is_function(factory)
    end)

    it("factory creates history instances with injected deps", function()
      local mock_event_bus = {
        emit = function() end,
        on = function() return function() end end
      }
      local mock_logger = { debug = function() end }

      local factory = HistoryService.create({
        event_bus = mock_event_bus,
        logger = mock_logger
      })
      local history = factory({})

      assert.is_not_nil(history)
      assert.equals(mock_event_bus, history._events)
      assert.equals(mock_logger, history._logger)
    end)

    it("new accepts config and deps parameters", function()
      local mock_event_bus = {
        emit = function() end,
        on = function() return function() end end
      }
      local mock_logger = { debug = function() end }

      local history = HistoryService.new({}, {
        event_bus = mock_event_bus,
        logger = mock_logger
      })

      assert.equals(mock_event_bus, history._events)
      assert.equals(mock_logger, history._logger)
    end)

    it("applies config from first parameter", function()
      local history = HistoryService.new({ max_size = 50 }, {})

      assert.equals(50, history._max_size)
    end)

    it("maintains backward compatibility with container", function()
      local container = TestContainer.create()
      local history = HistoryService.new(container)

      assert.is_not_nil(history)
      assert.is_not_nil(history._events)
    end)

    it("works without deps (backward compatibility)", function()
      local history = HistoryService.new(nil)

      assert.is_not_nil(history)
      assert.is_nil(history._events)
      assert.is_nil(history._logger)
    end)
  end)

  describe("IService interface", function()
    it("implements getName", function()
      local history = HistoryService.new(nil)
      assert.equals("history", history:getName())
    end)

    it("implements isInitialized", function()
      local history = HistoryService.new(nil)
      assert.is_true(history:isInitialized())
    end)

    it("isInitialized returns false after destroy", function()
      local history = HistoryService.new(nil)
      history:destroy()
      assert.is_false(history:isInitialized())
    end)
  end)

  describe("logger integration", function()
    local history, log_calls

    before_each(function()
      log_calls = {}
      local mock_logger = {
        debug = function(self, msg)
          table.insert(log_calls, msg)
        end
      }
      local mock_event_bus = {
        emit = function() end,
        on = function() return function() end end
      }

      history = HistoryService.new({}, {
        event_bus = mock_event_bus,
        logger = mock_logger
      })
      log_calls = {}  -- Clear initialization log
    end)

    it("logs on push", function()
      history:push("passage1")

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("push"))
    end)

    it("logs on pop", function()
      history:push("passage1")
      log_calls = {}

      history:pop()

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("pop"))
    end)

    it("logs on back", function()
      history:push("p1")
      history:push("p2")
      history:push("p3")
      log_calls = {}

      history:back()

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("back"))
    end)

    it("logs on clear", function()
      history:clear()

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("cleared"))
    end)

    it("logs on destroy", function()
      history:destroy()

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("destroying"))
    end)
  end)
end)
