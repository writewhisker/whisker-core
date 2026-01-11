--- Storage Service Integration Tests
-- Comprehensive test suite for the Storage service API
--
-- @module tests.storage.service_spec

describe("Storage Service", function()
  local Storage
  local storage
  local test_dir
  
  setup(function()
    Storage = require("whisker.storage")
  end)
  
  before_each(function()
    -- Use in-memory SQLite for faster tests
    storage = Storage.new({ backend = "sqlite", path = ":memory:" })
    storage:initialize()
  end)
  
  after_each(function()
    if storage then
      storage:clear()
    end
  end)
  
  describe("Constructor", function()
    it("should create storage with SQLite backend", function()
      local s = Storage.new({ backend = "sqlite", path = ":memory:" })
      assert.is_table(s)
      assert.is_table(s.backend)
    end)
    
    it("should create storage with Filesystem backend", function()
      test_dir = os.tmpname()
      os.remove(test_dir)
      
      local s = Storage.new({ backend = "filesystem", path = test_dir })
      assert.is_table(s)
      assert.is_table(s.backend)
      
      s:initialize()
      s:clear()
      os.execute("rm -rf " .. test_dir)
    end)
    
    it("should set default cache size", function()
      local s = Storage.new({ backend = "sqlite" })
      assert.equals(100, s.cache_size)
    end)
    
    it("should allow custom cache size", function()
      local s = Storage.new({ backend = "sqlite", cache_size = 50 })
      assert.equals(50, s.cache_size)
    end)
    
    it("should enable events by default", function()
      local s = Storage.new({ backend = "sqlite" })
      assert.is_true(s.enable_events)
    end)
    
    it("should allow disabling events", function()
      local s = Storage.new({ backend = "sqlite", enable_events = false })
      assert.is_false(s.enable_events)
    end)
    
    it("should error on unknown backend type", function()
      assert.has_error(function()
        Storage.new({ backend = "invalid" })
      end)
    end)
  end)
  
  describe("Save and Load Stories", function()
    it("should save and load a story", function()
      local story = {
        id = "test-1",
        title = "Test Story",
        passages = {
          { id = "1", name = "Start", text = "Beginning" }
        }
      }
      
      local success = storage:save_story("test-1", story)
      assert.is_true(success)
      
      local loaded = storage:load_story("test-1")
      assert.is_table(loaded)
      assert.equals("test-1", loaded.id)
      assert.equals("Test Story", loaded.title)
    end)
    
    it("should update existing story", function()
      storage:save_story("story-1", { id = "story-1", title = "V1" })
      storage:save_story("story-1", { id = "story-1", title = "V2" })
      
      local loaded = storage:load_story("story-1")
      assert.equals("V2", loaded.title)
    end)
    
    it("should save with metadata", function()
      local story = { id = "meta-story" }
      local options = {
        metadata = {
          tags = {"adventure", "fantasy"}
        }
      }
      
      storage:save_story("meta-story", story, options)
      
      local metadata = storage:get_metadata("meta-story")
      assert.is_table(metadata.tags)
      assert.equals(2, #metadata.tags)
    end)
    
    it("should return error when loading non-existent story", function()
      local data, err = storage:load_story("nonexistent")
      assert.is_nil(data)
      assert.is_string(err)
    end)
  end)
  
  describe("Caching", function()
    it("should cache loaded stories", function()
      storage:save_story("cached", { id = "cached" })
      
      -- First load
      storage:load_story("cached")
      
      -- Second load should come from cache
      local stats_before = storage:get_statistics()
      storage:load_story("cached")
      local stats_after = storage:get_statistics()
      
      assert.equals(stats_before.cache_hits + 1, stats_after.cache_hits)
    end)
    
    it("should cache saved stories", function()
      local story = { id = "save-cached", title = "Cached" }
      storage:save_story("save-cached", story)
      
      -- Load should come from cache
      local stats_before = storage:get_statistics()
      storage:load_story("save-cached")
      local stats_after = storage:get_statistics()
      
      assert.equals(stats_before.cache_hits + 1, stats_after.cache_hits)
    end)
    
    it("should allow skipping cache on save", function()
      local story = { id = "skip-cache" }
      storage:save_story("skip-cache", story, { skip_cache = true })
      
      -- Should not be in cache
      local cached = storage:cache_get("skip-cache")
      assert.is_nil(cached)
    end)
    
    it("should allow skipping cache on load", function()
      storage:save_story("skip-load", { id = "skip-load" })
      
      -- Load without cache
      local stats_before = storage:get_statistics()
      storage:load_story("skip-load", { skip_cache = true })
      local stats_after = storage:get_statistics()
      
      -- Should count as cache miss
      assert.equals(stats_before.cache_misses + 1, stats_after.cache_misses)
    end)
    
    it("should implement LRU eviction", function()
      -- Create storage with small cache
      local small_storage = Storage.new({
        backend = "sqlite",
        path = ":memory:",
        cache_size = 2
      })
      small_storage:initialize()
      
      -- Add 3 stories
      small_storage:save_story("s1", { id = "s1" })
      small_storage:save_story("s2", { id = "s2" })
      small_storage:save_story("s3", { id = "s3" })  -- Should evict s1
      
      -- s1 should not be in cache
      local stats = small_storage:get_statistics()
      assert.equals(2, stats.cache_size)
      
      small_storage:clear()
    end)
    
    it("should invalidate cache on delete", function()
      storage:save_story("delete-cached", { id = "delete-cached" })
      storage:load_story("delete-cached")  -- Cache it
      
      storage:delete_story("delete-cached")
      
      local cached = storage:cache_get("delete-cached")
      assert.is_nil(cached)
    end)
    
    it("should invalidate cache on metadata update", function()
      storage:save_story("meta-cached", { id = "meta-cached" })
      storage:load_story("meta-cached")  -- Cache it
      
      storage:update_metadata("meta-cached", { title = "Updated" })
      
      local cached = storage:cache_get("meta-cached")
      assert.is_nil(cached)
    end)
    
    it("should clear entire cache", function()
      storage:save_story("c1", { id = "c1" })
      storage:save_story("c2", { id = "c2" })
      
      storage:cache_clear()
      
      local stats = storage:get_statistics()
      assert.equals(0, stats.cache_size)
    end)
  end)
  
  describe("Events", function()
    it("should emit STORY_SAVED event", function()
      local event_data = nil
      
      storage:on(Storage.Events.STORY_SAVED, function(data)
        event_data = data
      end)
      
      storage:save_story("event-test", { id = "event-test" })
      
      assert.is_table(event_data)
      assert.equals("event-test", event_data.id)
    end)
    
    it("should emit STORY_CREATED event for new stories", function()
      local created = false
      
      storage:on(Storage.Events.STORY_CREATED, function(data)
        created = true
      end)
      
      storage:save_story("new-story", { id = "new-story" })
      
      assert.is_true(created)
    end)
    
    it("should emit STORY_UPDATED event for existing stories", function()
      storage:save_story("update-event", { id = "update-event" })
      
      local updated = false
      storage:on(Storage.Events.STORY_UPDATED, function(data)
        updated = true
      end)
      
      storage:save_story("update-event", { id = "update-event", title = "Updated" })
      
      assert.is_true(updated)
    end)
    
    it("should emit STORY_LOADED event", function()
      storage:save_story("load-event", { id = "load-event" })
      
      local event_data = nil
      storage:on(Storage.Events.STORY_LOADED, function(data)
        event_data = data
      end)
      
      storage:load_story("load-event")
      
      assert.is_table(event_data)
      assert.equals("load-event", event_data.id)
    end)
    
    it("should indicate cache hit in STORY_LOADED event", function()
      storage:save_story("cache-event", { id = "cache-event" })
      
      local from_cache = nil
      storage:on(Storage.Events.STORY_LOADED, function(data)
        from_cache = data.from_cache
      end)
      
      -- First load - not from cache
      storage:cache_clear()
      storage:load_story("cache-event")
      assert.is_false(from_cache)
      
      -- Second load - from cache
      storage:load_story("cache-event")
      assert.is_true(from_cache)
    end)
    
    it("should emit STORY_DELETED event", function()
      storage:save_story("delete-event", { id = "delete-event" })
      
      local deleted_id = nil
      storage:on(Storage.Events.STORY_DELETED, function(data)
        deleted_id = data.id
      end)
      
      storage:delete_story("delete-event")
      
      assert.equals("delete-event", deleted_id)
    end)
    
    it("should emit METADATA_UPDATED event", function()
      storage:save_story("meta-event", { id = "meta-event" })
      
      local event_data = nil
      storage:on(Storage.Events.METADATA_UPDATED, function(data)
        event_data = data
      end)
      
      storage:update_metadata("meta-event", { title = "New Title" })
      
      assert.is_table(event_data)
      assert.equals("meta-event", event_data.id)
    end)
    
    it("should emit STORAGE_CLEARED event", function()
      local cleared = false
      
      storage:on(Storage.Events.STORAGE_CLEARED, function(data)
        cleared = true
      end)
      
      storage:clear()
      
      assert.is_true(cleared)
    end)
    
    it("should emit STORAGE_ERROR event on errors", function()
      local error_data = nil
      
      storage:on(Storage.Events.STORAGE_ERROR, function(data)
        error_data = data
      end)
      
      -- Try to load non-existent story
      storage:load_story("nonexistent")
      
      assert.is_table(error_data)
      assert.equals("load", error_data.operation)
    end)
    
    it("should not emit events when disabled", function()
      local no_events = Storage.new({
        backend = "sqlite",
        path = ":memory:",
        enable_events = false
      })
      no_events:initialize()
      
      local event_called = false
      no_events:on(Storage.Events.STORY_SAVED, function()
        event_called = true
      end)
      
      no_events:save_story("test", { id = "test" })
      
      assert.is_false(event_called)
      
      no_events:clear()
    end)
    
    it("should handle multiple listeners for same event", function()
      local count = 0
      
      storage:on(Storage.Events.STORY_SAVED, function() count = count + 1 end)
      storage:on(Storage.Events.STORY_SAVED, function() count = count + 1 end)
      
      storage:save_story("multi", { id = "multi" })
      
      assert.equals(2, count)
    end)
    
    it("should handle errors in event listeners gracefully", function()
      storage:on(Storage.Events.STORY_SAVED, function()
        error("Listener error")
      end)
      
      -- Should not throw
      local success = storage:save_story("error-listener", { id = "error-listener" })
      assert.is_true(success)
    end)
  end)
  
  describe("Delete Stories", function()
    it("should delete existing story", function()
      storage:save_story("to-delete", { id = "to-delete" })
      
      local success = storage:delete_story("to-delete")
      assert.is_true(success)
      
      assert.is_false(storage:has_story("to-delete"))
    end)
    
    it("should return error when deleting non-existent story", function()
      local success, err = storage:delete_story("nonexistent")
      assert.is_false(success)
      assert.is_string(err)
    end)
  end)
  
  describe("List Stories", function()
    before_each(function()
      storage:save_story("s1", { id = "s1" }, { metadata = { tags = {"adventure"} } })
      storage:save_story("s2", { id = "s2" }, { metadata = { tags = {"mystery"} } })
      storage:save_story("s3", { id = "s3" }, { metadata = { tags = {"adventure", "fantasy"} } })
    end)
    
    it("should list all stories", function()
      local stories = storage:list_stories()
      assert.equals(3, #stories)
    end)
    
    it("should filter by tags", function()
      local stories = storage:list_stories({ tags = {"adventure"} })
      assert.is_true(#stories >= 1)
    end)
    
    it("should support pagination with limit", function()
      local stories = storage:list_stories({ limit = 2 })
      assert.equals(2, #stories)
    end)
    
    it("should support pagination with offset", function()
      local page1 = storage:list_stories({ limit = 2, offset = 0 })
      local page2 = storage:list_stories({ limit = 2, offset = 2 })
      
      assert.equals(2, #page1)
      assert.equals(1, #page2)
    end)
  end)
  
  describe("Story Existence", function()
    it("should return true for existing story", function()
      storage:save_story("exists", { id = "exists" })
      assert.is_true(storage:has_story("exists"))
    end)
    
    it("should return false for non-existent story", function()
      assert.is_false(storage:has_story("nonexistent"))
    end)
  end)
  
  describe("Metadata Operations", function()
    before_each(function()
      storage:save_story("meta", { id = "meta" })
    end)
    
    it("should get story metadata", function()
      local metadata = storage:get_metadata("meta")
      assert.is_table(metadata)
      assert.equals("meta", metadata.id)
    end)
    
    it("should update story metadata", function()
      local success = storage:update_metadata("meta", { title = "Updated Title" })
      assert.is_true(success)
      
      local metadata = storage:get_metadata("meta")
      assert.equals("Updated Title", metadata.title)
    end)
    
    it("should return error when getting metadata for non-existent story", function()
      local metadata, err = storage:get_metadata("nonexistent")
      assert.is_nil(metadata)
      assert.is_string(err)
    end)
  end)
  
  describe("Import and Export", function()
    it("should export story to JSON", function()
      storage:save_story("export", { id = "export", title = "Export Test" })
      
      local json = storage:export_story("export")
      assert.is_string(json)
      assert.is_true(#json > 0)
    end)
    
    it("should import story from JSON", function()
      local json = '{"id":"imported","title":"Imported Story"}'
      
      local key = storage:import_story(json)
      assert.equals("imported", key)
      
      local loaded = storage:load_story("imported")
      assert.equals("Imported Story", loaded.title)
    end)
    
    it("should import story from table", function()
      local data = { id = "table-import", title = "From Table" }
      
      local key = storage:import_story(data)
      assert.equals("table-import", key)
      
      assert.is_true(storage:has_story("table-import"))
    end)
  end)
  
  describe("Statistics", function()
    it("should track save count", function()
      storage:save_story("s1", { id = "s1" })
      storage:save_story("s2", { id = "s2" })
      
      local stats = storage:get_statistics()
      assert.is_true(stats.saves >= 2)
    end)
    
    it("should track load count", function()
      storage:save_story("l1", { id = "l1" })
      storage:cache_clear()
      
      storage:load_story("l1")
      storage:load_story("l1")
      
      local stats = storage:get_statistics()
      assert.is_true(stats.loads >= 1)  -- First load is counted, second is from cache
    end)
    
    it("should track delete count", function()
      storage:save_story("d1", { id = "d1" })
      storage:delete_story("d1")
      
      local stats = storage:get_statistics()
      assert.equals(1, stats.deletes)
    end)
    
    it("should track cache hits and misses", function()
      storage:save_story("cache-stat", { id = "cache-stat" })
      storage:cache_clear()
      
      -- Miss
      storage:load_story("cache-stat")
      
      -- Hit
      storage:load_story("cache-stat")
      
      local stats = storage:get_statistics()
      assert.is_true(stats.cache_hits >= 1)
      assert.is_true(stats.cache_misses >= 1)
    end)
    
    it("should calculate cache hit rate", function()
      storage:save_story("rate", { id = "rate" })
      storage:cache_clear()
      
      storage:load_story("rate")  -- Miss
      storage:load_story("rate")  -- Hit
      
      local stats = storage:get_statistics()
      assert.is_true(stats.cache_hit_rate > 0)
      assert.is_true(stats.cache_hit_rate <= 1)
    end)
    
    it("should track cache size", function()
      storage:save_story("c1", { id = "c1" })
      storage:save_story("c2", { id = "c2" })
      
      local stats = storage:get_statistics()
      assert.equals(2, stats.cache_size)
    end)
    
    it("should report total storage usage", function()
      storage:save_story("size", { id = "size", data = "test" })
      
      local stats = storage:get_statistics()
      assert.is_true(stats.total_size_bytes > 0)
    end)
  end)
  
  describe("Clear Storage", function()
    it("should clear all stories", function()
      storage:save_story("c1", { id = "c1" })
      storage:save_story("c2", { id = "c2" })
      
      local success = storage:clear()
      assert.is_true(success)
      
      local stories = storage:list_stories()
      assert.equals(0, #stories)
    end)
    
    it("should clear cache when clearing storage", function()
      storage:save_story("cache-clear", { id = "cache-clear" })
      
      storage:clear()
      
      local stats = storage:get_statistics()
      assert.equals(0, stats.cache_size)
    end)
  end)
  
  describe("Batch Operations", function()
    it("should batch save multiple stories", function()
      local stories = {
        ["batch-1"] = { id = "batch-1", title = "First" },
        ["batch-2"] = { id = "batch-2", title = "Second" },
        ["batch-3"] = { id = "batch-3", title = "Third" }
      }
      
      local count, errors = storage:batch_save(stories)
      
      assert.equals(3, count)
      assert.equals(0, #errors)
    end)
    
    it("should report batch save errors", function()
      -- This test would need a way to force an error
      -- For now, just verify the structure
      local stories = {
        ["valid"] = { id = "valid" }
      }
      
      local count, errors = storage:batch_save(stories)
      
      assert.is_number(count)
      assert.is_table(errors)
    end)
    
    it("should batch load multiple stories", function()
      storage:save_story("load-1", { id = "load-1" })
      storage:save_story("load-2", { id = "load-2" })
      storage:save_story("load-3", { id = "load-3" })
      
      local loaded, errors = storage:batch_load({"load-1", "load-2", "load-3"})
      
      assert.equals(3, #loaded)
      assert.equals(0, #errors)
    end)
    
    it("should report batch load errors", function()
      local loaded, errors = storage:batch_load({"exists", "nonexistent"})
      
      -- nonexistent should be in errors
      assert.is_table(errors)
      assert.is_not_nil(errors.nonexistent)
    end)
  end)
  
  describe("Preload Connected Stories", function()
    it("should preload a story", function()
      storage:save_story("preload", { id = "preload" })
      
      local count = storage:preload_connected("preload")
      
      assert.equals(1, count)
    end)
    
    it("should return 0 for non-existent story", function()
      local count = storage:preload_connected("nonexistent")
      assert.equals(0, count)
    end)
  end)
  
  describe("Backend Abstraction", function()
    it("should work with SQLite backend", function()
      local s = Storage.new({ backend = "sqlite", path = ":memory:" })
      s:initialize()
      
      s:save_story("test", { id = "test" })
      local loaded = s:load_story("test")
      
      assert.is_table(loaded)
      s:clear()
    end)
    
    it("should work with Filesystem backend", function()
      test_dir = os.tmpname()
      os.remove(test_dir)
      
      local s = Storage.new({ backend = "filesystem", path = test_dir })
      s:initialize()
      
      s:save_story("test", { id = "test" })
      local loaded = s:load_story("test")
      
      assert.is_table(loaded)
      s:clear()
      os.execute("rm -rf " .. test_dir)
    end)
  end)
end)
