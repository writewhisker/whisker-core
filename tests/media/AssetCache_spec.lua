-- AssetCache Tests
-- Unit tests for the AssetCache module

describe("AssetCache", function()
  local AssetCache
  local cache

  before_each(function()
    package.loaded["whisker.media.AssetCache"] = nil
    package.loaded["whisker.media.types"] = nil

    AssetCache = require("whisker.media.AssetCache")
    cache = AssetCache.new({
      bytesLimit = 1024 * 1024 -- 1MB
    })
  end)

  describe("basic operations", function()
    it("creates new cache with config", function()
      local c = AssetCache.new({
        bytesLimit = 500 * 1024
      })

      local stats = c:getStats()
      assert.equals(500 * 1024, stats.bytesLimit)
    end)

    it("creates cache with default config", function()
      local c = AssetCache.new()

      local stats = c:getStats()
      assert.is_true(stats.bytesLimit > 0)
    end)
  end)

  describe("set and get", function()
    it("stores and retrieves data", function()
      local data = { value = "test data" }

      cache:set("test_id", data, 100)

      local retrieved = cache:get("test_id")
      assert.equals(data.value, retrieved.value)
    end)

    it("returns nil for missing key", function()
      local retrieved = cache:get("nonexistent")
      assert.is_nil(retrieved)
    end)

    it("tracks cache hits", function()
      cache:set("hit_test", { data = "test" }, 100)

      cache:get("hit_test")
      cache:get("hit_test")

      local stats = cache:getStats()
      assert.equals(2, stats.hits)
    end)

    it("tracks cache misses", function()
      cache:get("miss1")
      cache:get("miss2")

      local stats = cache:getStats()
      assert.equals(2, stats.misses)
    end)

    it("calculates hit rate", function()
      cache:set("test", { data = "test" }, 100)

      cache:get("test") -- hit
      cache:get("test") -- hit
      cache:get("missing") -- miss

      local stats = cache:getStats()
      assert.is_true(stats.hitRate > 0.5)
    end)
  end)

  describe("size tracking", function()
    it("tracks bytes used", function()
      cache:set("item1", { data = "a" }, 100)
      cache:set("item2", { data = "b" }, 200)

      local stats = cache:getStats()
      assert.equals(300, stats.bytesUsed)
    end)

    it("tracks asset count", function()
      cache:set("item1", { data = "a" }, 100)
      cache:set("item2", { data = "b" }, 100)
      cache:set("item3", { data = "c" }, 100)

      local stats = cache:getStats()
      assert.equals(3, stats.assetCount)
    end)

    it("updates bytes when replacing item", function()
      cache:set("item", { data = "a" }, 100)
      cache:set("item", { data = "b" }, 200)

      local stats = cache:getStats()
      assert.equals(200, stats.bytesUsed)
      assert.equals(1, stats.assetCount)
    end)
  end)

  describe("removal", function()
    it("removes item from cache", function()
      cache:set("to_remove", { data = "test" }, 100)

      local removed = cache:remove("to_remove")

      assert.is_true(removed)
      assert.is_nil(cache:get("to_remove"))
    end)

    it("returns false for non-existent item", function()
      local removed = cache:remove("nonexistent")
      assert.is_false(removed)
    end)

    it("updates bytes used after removal", function()
      cache:set("item", { data = "test" }, 100)
      cache:remove("item")

      local stats = cache:getStats()
      assert.equals(0, stats.bytesUsed)
    end)

    it("updates asset count after removal", function()
      cache:set("item", { data = "test" }, 100)
      cache:remove("item")

      local stats = cache:getStats()
      assert.equals(0, stats.assetCount)
    end)
  end)

  describe("has", function()
    it("returns true for existing item", function()
      cache:set("exists", { data = "test" }, 100)
      assert.is_true(cache:has("exists"))
    end)

    it("returns false for non-existent item", function()
      assert.is_false(cache:has("nonexistent"))
    end)
  end)

  describe("pinning", function()
    it("pins existing item", function()
      cache:set("pinned", { data = "test" }, 100)

      local success = cache:pin("pinned")

      assert.is_true(success)
      assert.is_true(cache:isPinned("pinned"))
    end)

    it("returns false when pinning non-existent item", function()
      local success = cache:pin("nonexistent")
      assert.is_false(success)
    end)

    it("unpins item", function()
      cache:set("to_unpin", { data = "test" }, 100)
      cache:pin("to_unpin")

      cache:unpin("to_unpin")

      assert.is_false(cache:isPinned("to_unpin"))
    end)

    it("pinned item cannot be removed", function()
      cache:set("pinned", { data = "test" }, 100)
      cache:pin("pinned")

      local removed = cache:remove("pinned")

      assert.is_false(removed)
      assert.is_true(cache:has("pinned"))
    end)

    it("tracks pinned count", function()
      cache:set("pin1", { data = "a" }, 100)
      cache:set("pin2", { data = "b" }, 100)

      cache:pin("pin1")
      cache:pin("pin2")

      local stats = cache:getStats()
      assert.equals(2, stats.pinnedCount)
    end)
  end)

  describe("reference counting", function()
    it("retain increments ref count", function()
      cache:set("ref_test", { data = "test" }, 100)

      cache:retain("ref_test")

      assert.equals(1, cache:getRefCount("ref_test"))
    end)

    it("release decrements ref count", function()
      cache:set("ref_test", { data = "test" }, 100)

      cache:retain("ref_test")
      cache:retain("ref_test")
      cache:release("ref_test")

      assert.equals(1, cache:getRefCount("ref_test"))
    end)

    it("returns 0 for unretained item", function()
      cache:set("no_refs", { data = "test" }, 100)
      assert.equals(0, cache:getRefCount("no_refs"))
    end)

    it("referenced item cannot be removed", function()
      cache:set("referenced", { data = "test" }, 100)
      cache:retain("referenced")

      local removed = cache:remove("referenced")

      assert.is_false(removed)
      assert.is_true(cache:has("referenced"))
    end)

    it("returns false when retaining non-existent item", function()
      local success = cache:retain("nonexistent")
      assert.is_false(success)
    end)

    it("returns false when releasing non-existent item", function()
      local success = cache:release("nonexistent")
      assert.is_false(success)
    end)
  end)

  describe("eviction", function()
    it("evicts LRU item when over budget", function()
      local smallCache = AssetCache.new({ bytesLimit = 250 })

      smallCache:set("item1", { data = "a" }, 100)
      smallCache:set("item2", { data = "b" }, 100)
      -- This should trigger eviction of item1
      smallCache:set("item3", { data = "c" }, 100)

      -- item1 should be evicted (LRU)
      assert.is_false(smallCache:has("item1"))
      assert.is_true(smallCache:has("item3"))
    end)

    it("does not evict pinned items", function()
      local smallCache = AssetCache.new({ bytesLimit = 250 })

      smallCache:set("pinned", { data = "a" }, 100)
      smallCache:pin("pinned")

      smallCache:set("item2", { data = "b" }, 100)
      smallCache:set("item3", { data = "c" }, 100)

      assert.is_true(smallCache:has("pinned"))
    end)

    it("does not evict referenced items", function()
      local smallCache = AssetCache.new({ bytesLimit = 250 })

      smallCache:set("referenced", { data = "a" }, 100)
      smallCache:retain("referenced")

      smallCache:set("item2", { data = "b" }, 100)
      smallCache:set("item3", { data = "c" }, 100)

      assert.is_true(smallCache:has("referenced"))
    end)

    it("updates access order on get", function()
      local smallCache = AssetCache.new({ bytesLimit = 250 })

      smallCache:set("item1", { data = "a" }, 100)
      smallCache:set("item2", { data = "b" }, 100)

      -- Access item1 to make it most recently used
      smallCache:get("item1")

      -- Add item3, should evict item2 (LRU)
      smallCache:set("item3", { data = "c" }, 100)

      assert.is_true(smallCache:has("item1"))
      assert.is_false(smallCache:has("item2"))
    end)
  end)

  describe("clear", function()
    it("clears non-pinned, non-referenced items", function()
      cache:set("item1", { data = "a" }, 100)
      cache:set("pinned", { data = "b" }, 100)
      cache:set("referenced", { data = "c" }, 100)

      cache:pin("pinned")
      cache:retain("referenced")

      cache:clear()

      assert.is_false(cache:has("item1"))
      assert.is_true(cache:has("pinned"))
      assert.is_true(cache:has("referenced"))
    end)

    it("clearAll removes everything", function()
      cache:set("item1", { data = "a" }, 100)
      cache:set("pinned", { data = "b" }, 100)
      cache:pin("pinned")

      cache:clearAll()

      local stats = cache:getStats()
      assert.equals(0, stats.assetCount)
      assert.equals(0, stats.bytesUsed)
    end)
  end)

  describe("setMemoryBudget", function()
    it("updates budget", function()
      cache:setMemoryBudget(500 * 1024)

      local stats = cache:getStats()
      assert.equals(500 * 1024, stats.bytesLimit)
    end)

    it("triggers eviction if over new budget", function()
      cache:set("item1", { data = "a" }, 100)
      cache:set("item2", { data = "b" }, 100)
      cache:set("item3", { data = "c" }, 100)

      cache:setMemoryBudget(200)

      local stats = cache:getStats()
      assert.is_true(stats.bytesUsed <= 200)
    end)
  end)
end)
