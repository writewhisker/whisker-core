--- PersistenceService Unit Tests
-- @module tests.unit.services.persistence_spec
-- @author Whisker Core Team

describe("PersistenceService", function()
  local PersistenceService
  local StateManager
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    PersistenceService = require("whisker.services.persistence")
    StateManager = require("whisker.services.state")
  end)

  describe("initialization", function()
    it("creates persistence service without container", function()
      local persistence = PersistenceService.new(nil)
      assert.is_not_nil(persistence)
    end)

    it("creates persistence service with container", function()
      local container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      local persistence = PersistenceService.new(container)
      assert.is_not_nil(persistence)
    end)
  end)

  describe("save and load", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("saves state to a slot", function()
      state:set("player_name", "Alice")
      state:set("gold", 100)

      local success = persistence:save("slot1")

      assert.is_true(success)
    end)

    it("loads state from a slot", function()
      state:set("player_name", "Alice")
      state:set("gold", 100)
      persistence:save("slot1")

      -- Clear state
      state:clear()
      assert.is_nil(state:get("player_name"))

      -- Load
      local success = persistence:load("slot1")

      assert.is_true(success)
      assert.equals("Alice", state:get("player_name"))
      assert.equals(100, state:get("gold"))
    end)

    it("returns false when loading nonexistent slot", function()
      local success = persistence:load("nonexistent")
      assert.is_false(success)
    end)

    it("saves with metadata", function()
      state:set("chapter", 3)
      persistence:save("slot1", { description = "Chapter 3 start" })

      local metadata = persistence:get_metadata("slot1")
      assert.equals("Chapter 3 start", metadata.description)
    end)
  end)

  describe("delete operation", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("deletes existing save", function()
      state:set("key", "value")
      persistence:save("slot1")

      local result = persistence:delete("slot1")

      assert.is_true(result)
      assert.is_false(persistence:exists("slot1"))
    end)

    it("returns false for nonexistent save", function()
      local result = persistence:delete("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("exists operation", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("returns true for existing save", function()
      state:set("key", "value")
      persistence:save("slot1")

      assert.is_true(persistence:exists("slot1"))
    end)

    it("returns false for nonexistent save", function()
      assert.is_false(persistence:exists("nonexistent"))
    end)
  end)

  describe("list_saves operation", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("lists all saves", function()
      state:set("key", "value")
      persistence:save("slot1")
      persistence:save("slot2")
      persistence:save("slot3")

      local saves = persistence:list_saves()

      assert.equals(3, #saves)
      assert.equals("slot1", saves[1].slot)
      assert.equals("slot2", saves[2].slot)
      assert.equals("slot3", saves[3].slot)
    end)

    it("returns empty table when no saves", function()
      local saves = persistence:list_saves()
      assert.same({}, saves)
    end)
  end)

  describe("quick save/load", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("quick saves to quicksave slot", function()
      state:set("quick", "data")
      local success = persistence:quick_save()

      assert.is_true(success)
      assert.is_true(persistence:exists("quicksave"))
    end)

    it("quick loads from quicksave slot", function()
      state:set("quick", "data")
      persistence:quick_save()
      state:clear()

      local success = persistence:quick_load()

      assert.is_true(success)
      assert.equals("data", state:get("quick"))
    end)
  end)

  describe("auto save", function()
    local container, state, persistence

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
    end)

    it("auto saves to numbered slots", function()
      state:set("data", "value")

      persistence:auto_save(3)
      persistence:auto_save(3)
      persistence:auto_save(3)

      assert.is_true(persistence:exists("autosave_1"))
      assert.is_true(persistence:exists("autosave_2"))
      assert.is_true(persistence:exists("autosave_3"))
    end)

    it("wraps around max slots", function()
      state:set("data", "value")

      for _ = 1, 5 do
        persistence:auto_save(3)
      end

      -- Should have overwritten slot 1 and 2
      local saves = persistence:list_saves()
      assert.equals(3, #saves)
    end)
  end)

  describe("event emission", function()
    local container, state, persistence, events, emitted

    before_each(function()
      container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      events = container:resolve("events")
      state = container:resolve("state")
      persistence = PersistenceService.new(container)
      emitted = {}

      events:on("save:*", function(data)
        table.insert(emitted, data)
      end)
    end)

    it("emits save:created when saved", function()
      state:set("key", "value")
      persistence:save("slot1")

      assert.equals(1, #emitted)
      assert.equals("slot1", emitted[1].slot)
    end)

    it("emits save:loaded when loaded", function()
      state:set("key", "value")
      persistence:save("slot1")
      emitted = {}

      persistence:load("slot1")

      assert.equals(1, #emitted)
      assert.equals("slot1", emitted[1].slot)
    end)

    it("emits save:deleted when deleted", function()
      state:set("key", "value")
      persistence:save("slot1")
      emitted = {}

      persistence:delete("slot1")

      assert.equals(1, #emitted)
      assert.equals("slot1", emitted[1].slot)
    end)
  end)

  describe("destroy", function()
    it("cleans up resources", function()
      local container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      local persistence = PersistenceService.new(container)

      persistence:destroy()
      -- Should not throw
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(PersistenceService._dependencies)
      assert.same({"state", "event_bus", "serializer", "file_storage", "logger"}, PersistenceService._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(PersistenceService.create)
    end)

    it("create returns a factory function", function()
      local mock_state = {
        snapshot = function() return {} end,
        restore = function() end
      }
      local mock_event_bus = { emit = function() end }
      local mock_logger = { debug = function() end }

      local factory = PersistenceService.create({
        state = mock_state,
        event_bus = mock_event_bus,
        logger = mock_logger
      })

      assert.is_function(factory)
    end)

    it("factory creates persistence instances with injected deps", function()
      local mock_state = {
        snapshot = function() return {} end,
        restore = function() end
      }
      local mock_event_bus = { emit = function() end }
      local mock_logger = { debug = function() end }

      local factory = PersistenceService.create({
        state = mock_state,
        event_bus = mock_event_bus,
        logger = mock_logger
      })
      local persistence = factory({})

      assert.is_not_nil(persistence)
      assert.equals(mock_state, persistence._state)
      assert.equals(mock_event_bus, persistence._events)
      assert.equals(mock_logger, persistence._logger)
    end)

    it("new accepts config and deps parameters", function()
      local mock_state = {
        snapshot = function() return {} end,
        restore = function() end
      }
      local mock_event_bus = { emit = function() end }
      local mock_logger = { debug = function() end }

      local persistence = PersistenceService.new({}, {
        state = mock_state,
        event_bus = mock_event_bus,
        logger = mock_logger
      })

      assert.equals(mock_state, persistence._state)
      assert.equals(mock_event_bus, persistence._events)
      assert.equals(mock_logger, persistence._logger)
    end)

    it("accepts file_storage as platform dependency", function()
      local mock_storage = { save = function() end, load = function() end }

      local persistence = PersistenceService.new({}, {
        file_storage = mock_storage
      })

      assert.equals(mock_storage, persistence._platform)
    end)

    it("maintains backward compatibility with container", function()
      local container = TestContainer.create()
      container:register("state", StateManager, { singleton = true })
      local persistence = PersistenceService.new(container)

      assert.is_not_nil(persistence)
      assert.is_not_nil(persistence._state)
      assert.is_not_nil(persistence._events)
    end)

    it("works without deps (backward compatibility)", function()
      local persistence = PersistenceService.new(nil)

      assert.is_not_nil(persistence)
      assert.is_nil(persistence._state)
      assert.is_nil(persistence._events)
    end)
  end)

  describe("IService interface", function()
    it("implements getName", function()
      local persistence = PersistenceService.new(nil)
      assert.equals("persistence", persistence:getName())
    end)

    it("implements isInitialized", function()
      local persistence = PersistenceService.new(nil)
      assert.is_true(persistence:isInitialized())
    end)

    it("isInitialized returns false after destroy", function()
      local persistence = PersistenceService.new(nil)
      persistence:destroy()
      assert.is_false(persistence:isInitialized())
    end)
  end)

  describe("logger integration", function()
    local persistence, state, log_calls

    before_each(function()
      log_calls = {}
      local mock_logger = {
        debug = function(self, msg)
          table.insert(log_calls, msg)
        end
      }
      state = StateManager.new(nil)

      persistence = PersistenceService.new({}, {
        state = state,
        logger = mock_logger
      })
      log_calls = {}  -- Clear initialization log
    end)

    it("logs on save", function()
      state:set("key", "value")
      persistence:save("slot1")

      assert.is_true(#log_calls >= 1)
      local found = false
      for _, msg in ipairs(log_calls) do
        if msg:match("Saving") or msg:match("Save") then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("logs on load", function()
      state:set("key", "value")
      persistence:save("slot1")
      log_calls = {}

      persistence:load("slot1")

      assert.is_true(#log_calls >= 1)
    end)

    it("logs on delete", function()
      state:set("key", "value")
      persistence:save("slot1")
      log_calls = {}

      persistence:delete("slot1")

      assert.is_true(#log_calls >= 1)
    end)

    it("logs on destroy", function()
      persistence:destroy()

      assert.equals(1, #log_calls)
      assert.is_truthy(log_calls[1]:match("destroying"))
    end)
  end)
end)
