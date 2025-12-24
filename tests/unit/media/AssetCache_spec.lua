-- Tests for AssetCache module
describe("AssetCache", function()
  local AssetCache
  local mock_event_bus
  local mock_logger

  before_each(function()
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.types"] = nil
    AssetCache = require("whisker.media.AssetCache")

    -- Create mock event bus
    mock_event_bus = {
      events = {},
      emit = function(self, event, data)
        table.insert(self.events, {event = event, data = data})
      end
    }

    -- Create mock logger
    mock_logger = {
      logs = {},
      debug = function(self, msg) table.insert(self.logs, {level = "debug", msg = msg}) end,
      info = function(self, msg) table.insert(self.logs, {level = "info", msg = msg}) end,
      warn = function(self, msg) table.insert(self.logs, {level = "warn", msg = msg}) end,
      error = function(self, msg) table.insert(self.logs, {level = "error", msg = msg}) end
    }
  end)

  describe("new", function()
    it("creates cache with default config", function()
      local cache = AssetCache.new()
      assert.is_not_nil(cache)
      local stats = cache:getStats()
      assert.equals(0, stats.bytesUsed)
      assert.equals(0, stats.assetCount)
    end)

    it("creates cache with custom memory budget", function()
      local cache = AssetCache.new({bytesLimit = 50 * 1024 * 1024})
      local stats = cache:getStats()
      assert.equals(50 * 1024 * 1024, stats.bytesLimit)
    end)
  end)

  describe("set and get", function()
    it("stores and retrieves assets", function()
      local cache = AssetCache.new()
      local data = {id = "test", value = 123}

      cache:set("test_asset", data, 1024)
      local retrieved = cache:get("test_asset")

      assert.equals(data, retrieved)
    end)

    it("returns nil for missing assets", function()
      local cache = AssetCache.new()
      assert.is_nil(cache:get("nonexistent"))
    end)

    it("tracks bytes used", function()
      local cache = AssetCache.new()
      cache:set("asset1", {}, 1000)
      cache:set("asset2", {}, 2000)

      local stats = cache:getStats()
      assert.equals(3000, stats.bytesUsed)
      assert.equals(2, stats.assetCount)
    end)
  end)

  describe("has", function()
    it("returns true for cached assets", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      assert.is_true(cache:has("test"))
    end)

    it("returns false for missing assets", function()
      local cache = AssetCache.new()
      assert.is_false(cache:has("missing"))
    end)
  end)

  describe("remove", function()
    it("removes assets from cache", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 1000)

      local removed = cache:remove("test")

      assert.is_true(removed)
      assert.is_false(cache:has("test"))
    end)

    it("updates bytes used", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 1000)
      cache:remove("test")

      local stats = cache:getStats()
      assert.equals(0, stats.bytesUsed)
    end)

    it("returns false for missing assets", function()
      local cache = AssetCache.new()
      assert.is_false(cache:remove("missing"))
    end)
  end)

  describe("pin and unpin", function()
    it("pins assets to prevent eviction", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      cache:pin("test")

      assert.is_true(cache:isPinned("test"))
    end)

    it("unpins assets", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      cache:pin("test")
      cache:unpin("test")

      assert.is_false(cache:isPinned("test"))
    end)

    it("prevents removal of pinned assets", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      cache:pin("test")

      local removed = cache:remove("test")

      assert.is_false(removed)
      assert.is_true(cache:has("test"))
    end)
  end)

  describe("retain and release", function()
    it("tracks reference counts", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)

      cache:retain("test")
      assert.equals(1, cache:getRefCount("test"))

      cache:retain("test")
      assert.equals(2, cache:getRefCount("test"))

      cache:release("test")
      assert.equals(1, cache:getRefCount("test"))
    end)

    it("prevents removal of referenced assets", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      cache:retain("test")

      local removed = cache:remove("test")

      assert.is_false(removed)
      assert.is_true(cache:has("test"))
    end)

    it("allows removal when all references released", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)
      cache:retain("test")
      cache:release("test")

      local removed = cache:remove("test")
      assert.is_true(removed)
    end)
  end)

  describe("eviction", function()
    it("evicts LRU assets when over budget", function()
      local cache = AssetCache.new({bytesLimit = 2000})

      cache:set("first", {order = 1}, 1000)
      cache:set("second", {order = 2}, 1000)
      cache:set("third", {order = 3}, 1000)

      assert.is_false(cache:has("first"))
      assert.is_true(cache:has("second"))
      assert.is_true(cache:has("third"))
    end)

    it("does not evict pinned assets", function()
      local cache = AssetCache.new({bytesLimit = 2000})

      cache:set("first", {}, 1000)
      cache:pin("first")
      cache:set("second", {}, 1000)
      cache:set("third", {}, 1000)

      assert.is_true(cache:has("first"))
    end)
  end)

  describe("clear", function()
    it("clears non-pinned assets", function()
      local cache = AssetCache.new()
      cache:set("normal", {}, 100)
      cache:set("pinned", {}, 100)
      cache:pin("pinned")

      cache:clear()

      assert.is_false(cache:has("normal"))
      assert.is_true(cache:has("pinned"))
    end)
  end)

  describe("clearAll", function()
    it("clears all assets including pinned", function()
      local cache = AssetCache.new()
      cache:set("normal", {}, 100)
      cache:set("pinned", {}, 100)
      cache:pin("pinned")

      cache:clearAll()

      assert.is_false(cache:has("normal"))
      assert.is_false(cache:has("pinned"))
    end)
  end)

  describe("getStats", function()
    it("tracks hits and misses", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)

      cache:get("test")
      cache:get("test")
      cache:get("missing")

      local stats = cache:getStats()
      assert.equals(2, stats.hits)
      assert.equals(1, stats.misses)
    end)

    it("calculates hit rate", function()
      local cache = AssetCache.new()
      cache:set("test", {}, 100)

      cache:get("test")
      cache:get("test")
      cache:get("missing")
      cache:get("missing")

      local stats = cache:getStats()
      assert.equals(0.5, stats.hitRate)
    end)
  end)

  describe("setMemoryBudget", function()
    it("evicts when new budget is smaller", function()
      local cache = AssetCache.new({bytesLimit = 5000})
      cache:set("a", {}, 1000)
      cache:set("b", {}, 1000)
      cache:set("c", {}, 1000)

      cache:setMemoryBudget(2000)

      local stats = cache:getStats()
      assert.is_true(stats.bytesUsed <= 2000)
    end)
  end)

  describe("DI pattern", function()
    it("declares dependencies", function()
      assert.is_table(AssetCache._dependencies)
      assert.same({"logger", "event_bus"}, AssetCache._dependencies)
    end)

    it("provides create factory function", function()
      assert.is_function(AssetCache.create)
    end)

    it("create returns a factory function", function()
      local factory = AssetCache.create({
        logger = mock_logger,
        event_bus = mock_event_bus
      })
      assert.is_function(factory)
    end)

    it("factory creates cache instances with injected deps", function()
      local factory = AssetCache.create({
        logger = mock_logger,
        event_bus = mock_event_bus
      })
      local cache = factory({bytesLimit = 1024 * 1024})
      assert.is_not_nil(cache)
      assert.is_function(cache.get)
      assert.is_function(cache.set)
    end)

    it("stores event_bus dependency", function()
      local cache = AssetCache.new({}, {event_bus = mock_event_bus})
      assert.equals(mock_event_bus, cache._event_bus)
    end)

    it("stores logger dependency", function()
      local cache = AssetCache.new({}, {logger = mock_logger})
      assert.equals(mock_logger, cache._logger)
    end)

    it("works without deps (backward compatibility)", function()
      local cache = AssetCache.new({bytesLimit = 1024})
      assert.is_not_nil(cache)
      cache:set("test", {}, 100)
      assert.is_true(cache:has("test"))
    end)
  end)

  describe("event emission", function()
    it("emits cache:set event when setting asset", function()
      local cache = AssetCache.new({}, {event_bus = mock_event_bus})
      cache:set("test", {data = "value"}, 500)

      assert.equals(1, #mock_event_bus.events)
      local event = mock_event_bus.events[1]
      assert.equals("cache:set", event.event)
      assert.equals("test", event.data.assetId)
      assert.equals(500, event.data.sizeBytes)
    end)

    it("emits cache:remove event when removing asset", function()
      local cache = AssetCache.new({}, {event_bus = mock_event_bus})
      cache:set("test", {}, 500)
      mock_event_bus.events = {} -- Clear set event
      cache:remove("test")

      assert.equals(1, #mock_event_bus.events)
      local event = mock_event_bus.events[1]
      assert.equals("cache:remove", event.event)
      assert.equals("test", event.data.assetId)
      assert.equals(500, event.data.freedBytes)
    end)

    it("emits cache:evict event when evicting assets", function()
      local cache = AssetCache.new({bytesLimit = 1500}, {event_bus = mock_event_bus})
      cache:set("first", {}, 1000)
      cache:set("second", {}, 1000) -- This should evict "first"

      -- Find the evict event
      local found_evict = false
      for _, e in ipairs(mock_event_bus.events) do
        if e.event == "cache:evict" then
          found_evict = true
          assert.equals("first", e.data.assetId)
        end
      end
      assert.is_true(found_evict, "Should have emitted cache:evict event")
    end)

    it("does not emit events when event_bus is nil", function()
      local cache = AssetCache.new({})
      -- These should not error even without event_bus
      cache:set("test", {}, 100)
      cache:remove("test")
    end)
  end)

  describe("put alias", function()
    it("put is an alias for set", function()
      assert.equals(AssetCache.set, AssetCache.put)
    end)

    it("put works the same as set", function()
      local cache = AssetCache.new()
      cache:put("test", {value = 42}, 100)
      assert.is_true(cache:has("test"))
      local retrieved = cache:get("test")
      assert.equals(42, retrieved.value)
    end)
  end)
end)
