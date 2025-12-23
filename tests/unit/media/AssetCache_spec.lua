-- Tests for AssetCache module
describe("AssetCache", function()
  local AssetCache

  before_each(function()
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.types"] = nil
    AssetCache = require("whisker.media.AssetCache")
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
end)
