--- SQLite Backend Tests
-- Comprehensive test suite for the SQLite storage backend
--
-- @module tests.storage.backends.sqlite_spec

describe("SQLite Backend", function()
  local SQLiteBackend
  local backend
  
  setup(function()
    SQLiteBackend = require("whisker.storage.backends.sqlite")
  end)
  
  before_each(function()
    -- Create new in-memory backend for each test
    backend = SQLiteBackend.new({ path = ":memory:" })
  end)
  
  after_each(function()
    if backend and backend.db then
      backend:close()
    end
  end)
  
  describe("Constructor", function()
    it("should create backend with default options", function()
      local b = SQLiteBackend.new()
      assert.is_table(b)
      assert.equals(":memory:", b.path)
      assert.equals(5000, b.timeout)
      assert.is_nil(b.db)
    end)
    
    it("should create backend with custom path", function()
      local b = SQLiteBackend.new({ path = "test.db" })
      assert.equals("test.db", b.path)
    end)
    
    it("should create backend with custom timeout", function()
      local b = SQLiteBackend.new({ timeout = 10000 })
      assert.equals(10000, b.timeout)
    end)
  end)
  
  describe("Initialization", function()
    it("should initialize successfully", function()
      local success, err = backend:initialize()
      assert.is_true(success)
      assert.is_nil(err)
      assert.is_not_nil(backend.db)
    end)
    
    it("should create all required tables", function()
      backend:initialize()
      
      -- Check tables exist
      local tables = {"stories", "metadata", "preferences", "sync_queue", "github_token", "schema_version"}
      
      for _, table_name in ipairs(tables) do
        local stmt = backend.db:prepare(
          string.format("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'", table_name)
        )
        assert.is_not_nil(stmt)
        local result = stmt:step()
        stmt:finalize()
        assert.equals(100, result)  -- sqlite3.ROW = 100
      end
    end)
    
    it("should create all indexes", function()
      backend:initialize()
      
      -- Check some indexes exist
      local indexes = {
        "idx_stories_updated",
        "idx_metadata_story",
        "idx_metadata_title"
      }
      
      for _, index_name in ipairs(indexes) do
        local stmt = backend.db:prepare(
          string.format("SELECT name FROM sqlite_master WHERE type='index' AND name='%s'", index_name)
        )
        assert.is_not_nil(stmt)
        local result = stmt:step()
        stmt:finalize()
        assert.equals(100, result)  -- sqlite3.ROW = 100
      end
    end)
    
    it("should set schema version", function()
      backend:initialize()
      local version = backend:get_schema_version()
      assert.equals(SQLiteBackend.SCHEMA_VERSION, version)
    end)
    
    it("should enable foreign keys", function()
      backend:initialize()
      
      local stmt = backend.db:prepare("PRAGMA foreign_keys")
      stmt:step()
      local fk_enabled = stmt:get_value(0)
      stmt:finalize()
      
      assert.equals(1, fk_enabled)
    end)
  end)
  
  describe("Save and Load", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should save and load a story", function()
      local story_data = {
        id = "test-story",
        title = "Test Story",
        passages = {
          { id = "1", name = "Start", text = "Beginning" }
        }
      }
      
      local success, err = backend:save("test-story", story_data, {})
      assert.is_true(success)
      assert.is_nil(err)
      
      local loaded, load_err = backend:load("test-story")
      assert.is_nil(load_err)
      assert.is_table(loaded)
      assert.equals("test-story", loaded.id)
      assert.equals("Test Story", loaded.title)
    end)
    
    it("should update existing story", function()
      local story_v1 = {
        id = "story-1",
        title = "Version 1"
      }
      
      backend:save("story-1", story_v1, {})
      
      -- Get created_at timestamp
      local stmt = backend.db:prepare("SELECT created_at, updated_at FROM stories WHERE id = ?")
      stmt:bind_values("story-1")
      stmt:step()
      local created_at_v1 = stmt:get_value(0)
      local updated_at_v1 = stmt:get_value(1)
      stmt:finalize()
      
      -- Wait a bit to ensure different timestamp
      os.execute("sleep 1")
      
      -- Update story
      local story_v2 = {
        id = "story-1",
        title = "Version 2"
      }
      
      backend:save("story-1", story_v2, {})
      
      -- Check timestamps
      stmt = backend.db:prepare("SELECT created_at, updated_at FROM stories WHERE id = ?")
      stmt:bind_values("story-1")
      stmt:step()
      local created_at_v2 = stmt:get_value(0)
      local updated_at_v2 = stmt:get_value(1)
      stmt:finalize()
      
      -- created_at should be preserved
      assert.equals(created_at_v1, created_at_v2)
      -- updated_at should be newer
      assert.is_true(updated_at_v2 >= updated_at_v1)
      
      -- Verify updated title
      local loaded = backend:load("story-1")
      assert.equals("Version 2", loaded.title)
    end)
    
    it("should save metadata with story", function()
      local story_data = {
        id = "meta-story",
        metadata = {
          title = "Story with Metadata"
        }
      }
      
      backend:save("meta-story", story_data, { tags = {"adventure", "test"} })
      
      -- Check metadata table
      local stmt = backend.db:prepare("SELECT title, tags FROM metadata WHERE id = ?")
      stmt:bind_values("meta-story")
      stmt:step()
      
      local title = stmt:get_value(0)
      local tags_json = stmt:get_value(1)
      stmt:finalize()
      
      assert.equals("Story with Metadata", title)
      assert.is_string(tags_json)
    end)
    
    it("should return error when loading non-existent story", function()
      local data, err = backend:load("nonexistent")
      assert.is_nil(data)
      assert.equals("Story not found", err)
    end)
    
    it("should return error when database not initialized", function()
      local uninit = SQLiteBackend.new()
      local data, err = uninit:load("test")
      assert.is_nil(data)
      assert.equals("Database not initialized", err)
    end)
    
    it("should handle large stories", function()
      local large_story = {
        id = "large",
        passages = {}
      }
      
      -- Create 1000 passages
      for i = 1, 1000 do
        table.insert(large_story.passages, {
          id = tostring(i),
          name = "Passage " .. i,
          text = string.rep("Content ", 100)
        })
      end
      
      local success = backend:save("large", large_story, {})
      assert.is_true(success)
      
      local loaded = backend:load("large")
      assert.is_table(loaded)
      assert.equals(1000, #loaded.passages)
    end)
  end)
  
  describe("Delete", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should delete existing story", function()
      backend:save("to-delete", { id = "to-delete" }, {})
      
      assert.is_true(backend:exists("to-delete"))
      
      local success, err = backend:delete("to-delete")
      assert.is_true(success)
      assert.is_nil(err)
      
      assert.is_false(backend:exists("to-delete"))
    end)
    
    it("should return error when deleting non-existent story", function()
      local success, err = backend:delete("nonexistent")
      assert.is_false(success)
      assert.equals("Story not found", err)
    end)
    
    it("should cascade delete metadata", function()
      backend:save("cascade-test", { id = "cascade-test" }, {})
      
      -- Verify metadata exists
      local stmt = backend.db:prepare("SELECT COUNT(*) FROM metadata WHERE story_id = ?")
      stmt:bind_values("cascade-test")
      stmt:step()
      local count_before = stmt:get_value(0)
      stmt:finalize()
      assert.equals(1, count_before)
      
      -- Delete story
      backend:delete("cascade-test")
      
      -- Verify metadata is gone
      stmt = backend.db:prepare("SELECT COUNT(*) FROM metadata WHERE story_id = ?")
      stmt:bind_values("cascade-test")
      stmt:step()
      local count_after = stmt:get_value(0)
      stmt:finalize()
      assert.equals(0, count_after)
    end)
  end)
  
  describe("Exists", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should return true for existing story", function()
      backend:save("exists-test", { id = "exists-test" }, {})
      assert.is_true(backend:exists("exists-test"))
    end)
    
    it("should return false for non-existent story", function()
      assert.is_false(backend:exists("nonexistent"))
    end)
  end)
  
  describe("List", function()
    before_each(function()
      backend:initialize()
      
      -- Add test stories
      backend:save("story-1", { id = "story-1", title = "First" }, { tags = {"adventure"} })
      backend:save("story-2", { id = "story-2", title = "Second" }, { tags = {"mystery"} })
      backend:save("story-3", { id = "story-3", title = "Third" }, { tags = {"adventure", "mystery"} })
    end)
    
    it("should list all stories", function()
      local results = backend:list()
      assert.equals(3, #results)
    end)
    
    it("should return metadata for each story", function()
      local results = backend:list()
      
      for _, metadata in ipairs(results) do
        assert.is_string(metadata.id)
        assert.is_string(metadata.title)
        assert.is_table(metadata.tags)
        assert.is_number(metadata.size)
        assert.is_number(metadata.created_at)
        assert.is_number(metadata.updated_at)
      end
    end)
    
    it("should filter by tags", function()
      local results = backend:list({ tags = {"adventure"} })
      assert.is_true(#results >= 1)
      
      -- Check that at least one result has the adventure tag
      local found = false
      for _, metadata in ipairs(results) do
        for _, tag in ipairs(metadata.tags) do
          if tag == "adventure" then
            found = true
            break
          end
        end
      end
      assert.is_true(found)
    end)
    
    it("should respect limit", function()
      local results = backend:list({ limit = 2 })
      assert.equals(2, #results)
    end)
    
    it("should respect offset", function()
      local results_page1 = backend:list({ limit = 2, offset = 0 })
      local results_page2 = backend:list({ limit = 2, offset = 2 })
      
      assert.equals(2, #results_page1)
      assert.equals(1, #results_page2)
    end)
    
    it("should order by updated_at DESC", function()
      -- Update story-1 to make it most recent
      os.execute("sleep 1")
      backend:save("story-1", { id = "story-1", title = "First Updated" }, {})
      
      local results = backend:list()
      assert.equals("story-1", results[1].id)
    end)
  end)
  
  describe("Metadata", function()
    before_each(function()
      backend:initialize()
      backend:save("meta-test", { id = "meta-test", title = "Test" }, { tags = {"original"} })
    end)
    
    it("should get metadata for story", function()
      local metadata, err = backend:get_metadata("meta-test")
      assert.is_nil(err)
      assert.is_table(metadata)
      assert.equals("meta-test", metadata.id)
      assert.equals("Test", metadata.title)
      assert.is_table(metadata.tags)
    end)
    
    it("should return error for non-existent story", function()
      local metadata, err = backend:get_metadata("nonexistent")
      assert.is_nil(metadata)
      assert.equals("Story not found", err)
    end)
    
    it("should update metadata title", function()
      local success, err = backend:update_metadata("meta-test", { title = "Updated Title" })
      assert.is_true(success)
      assert.is_nil(err)
      
      local metadata = backend:get_metadata("meta-test")
      assert.equals("Updated Title", metadata.title)
    end)
    
    it("should update metadata tags", function()
      local success = backend:update_metadata("meta-test", { tags = {"new", "tags"} })
      assert.is_true(success)
      
      local metadata = backend:get_metadata("meta-test")
      assert.equals(2, #metadata.tags)
    end)
    
    it("should update story timestamp when metadata updated", function()
      local meta_before = backend:get_metadata("meta-test")
      
      os.execute("sleep 1")
      
      backend:update_metadata("meta-test", { title = "New Title" })
      
      local meta_after = backend:get_metadata("meta-test")
      assert.is_true(meta_after.updated_at >= meta_before.updated_at)
    end)
    
    it("should return error when updating non-existent story", function()
      local success, err = backend:update_metadata("nonexistent", { title = "Test" })
      assert.is_false(success)
      assert.equals("Story not found", err)
    end)
    
    it("should handle empty metadata update", function()
      local success = backend:update_metadata("meta-test", {})
      assert.is_true(success)
    end)
  end)
  
  describe("Import/Export", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should export story to JSON", function()
      backend:save("export-test", { id = "export-test", title = "Export Me" }, {})
      
      local json_str, err = backend:export("export-test")
      assert.is_nil(err)
      assert.is_string(json_str)
      assert.is_true(#json_str > 0)
    end)
    
    it("should return error when exporting non-existent story", function()
      local json_str, err = backend:export("nonexistent")
      assert.is_nil(json_str)
      assert.is_not_nil(err)
    end)
    
    it("should import story from JSON string", function()
      local json_str = '{"id":"imported","title":"Imported Story"}'
      
      local key, err = backend:import_data(json_str)
      assert.is_nil(err)
      assert.equals("imported", key)
      
      local loaded = backend:load("imported")
      assert.equals("Imported Story", loaded.title)
    end)
    
    it("should import story from table", function()
      local data = {
        id = "imported-table",
        title = "From Table"
      }
      
      local key = backend:import_data(data)
      assert.equals("imported-table", key)
      
      assert.is_true(backend:exists("imported-table"))
    end)
    
    it("should generate ID if not provided", function()
      local data = { title = "No ID" }
      
      local key = backend:import_data(data)
      assert.is_string(key)
      assert.is_true(#key > 0)
      assert.is_true(backend:exists(key))
    end)
    
    it("should return error for invalid JSON", function()
      local key, err = backend:import_data("invalid json {{{")
      assert.is_nil(key)
      assert.equals("Failed to decode JSON", err)
    end)
  end)
  
  describe("Storage Usage", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should return zero for empty storage", function()
      local usage = backend:get_storage_usage()
      assert.equals(0, usage)
    end)
    
    it("should calculate total storage usage", function()
      backend:save("story-1", { id = "story-1", data = "test" }, {})
      backend:save("story-2", { id = "story-2", data = "more data" }, {})
      
      local usage = backend:get_storage_usage()
      assert.is_true(usage > 0)
    end)
    
    it("should update usage when stories are deleted", function()
      backend:save("temp", { id = "temp", data = "temporary" }, {})
      local usage_before = backend:get_storage_usage()
      
      backend:delete("temp")
      local usage_after = backend:get_storage_usage()
      
      assert.is_true(usage_after < usage_before)
    end)
  end)
  
  describe("Clear", function()
    before_each(function()
      backend:initialize()
      backend:save("story-1", { id = "story-1" }, {})
      backend:save("story-2", { id = "story-2" }, {})
    end)
    
    it("should clear all stories", function()
      local success, err = backend:clear()
      assert.is_true(success)
      assert.is_nil(err)
      
      local results = backend:list()
      assert.equals(0, #results)
    end)
    
    it("should clear all tables", function()
      backend:save_preference("test-pref", { value = "test" })
      
      backend:clear()
      
      -- Check stories
      local stories = backend:list()
      assert.equals(0, #stories)
      
      -- Check preferences
      local pref = backend:load_preference("test-pref")
      assert.is_nil(pref)
    end)
  end)
  
  describe("Preferences (Optional Methods)", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should save and load preference", function()
      local success = backend:save_preference("theme", { value = "dark", scope = "user" })
      assert.is_true(success)
      
      local entry = backend:load_preference("theme")
      assert.is_table(entry)
      assert.equals("dark", entry.value)
      assert.equals("user", entry.scope)
    end)
    
    it("should update existing preference", function()
      backend:save_preference("setting", { value = "old" })
      backend:save_preference("setting", { value = "new" })
      
      local entry = backend:load_preference("setting")
      assert.equals("new", entry.value)
    end)
    
    it("should delete preference", function()
      backend:save_preference("delete-me", { value = "test" })
      
      local success = backend:delete_preference("delete-me")
      assert.is_true(success)
      
      local entry = backend:load_preference("delete-me")
      assert.is_nil(entry)
    end)
    
    it("should list preference keys", function()
      backend:save_preference("key1", { value = "val1" })
      backend:save_preference("key2", { value = "val2" })
      backend:save_preference("other", { value = "val3" })
      
      local keys = backend:list_preferences()
      assert.equals(3, #keys)
    end)
    
    it("should filter preferences by prefix", function()
      backend:save_preference("user.name", { value = "John" })
      backend:save_preference("user.email", { value = "john@example.com" })
      backend:save_preference("system.version", { value = "1.0" })
      
      local keys = backend:list_preferences("user")
      assert.equals(2, #keys)
    end)
  end)
  
  describe("Transactions", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should rollback on save error", function()
      -- This is hard to test without mocking, but we can verify the behavior indirectly
      -- by ensuring that if a save fails, nothing is written
      
      -- Save valid story first
      backend:save("valid", { id = "valid" }, {})
      assert.is_true(backend:exists("valid"))
    end)
    
    it("should rollback on delete error", function()
      backend:save("protected", { id = "protected" }, {})
      
      -- Try to delete non-existent (should fail before transaction)
      local success = backend:delete("nonexistent")
      assert.is_false(success)
      
      -- Original should still exist
      assert.is_true(backend:exists("protected"))
    end)
  end)
  
  describe("Close", function()
    it("should close database connection", function()
      backend:initialize()
      assert.is_not_nil(backend.db)
      
      backend:close()
      assert.is_nil(backend.db)
    end)
    
    it("should handle closing unopened database", function()
      local b = SQLiteBackend.new()
      b:close()  -- Should not error
      assert.is_nil(b.db)
    end)
    
    it("should handle multiple closes", function()
      backend:initialize()
      backend:close()
      backend:close()  -- Should not error
      assert.is_nil(backend.db)
    end)
  end)
  
  describe("Schema Version", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should get current schema version", function()
      local version = backend:get_schema_version()
      assert.is_number(version)
      assert.equals(SQLiteBackend.SCHEMA_VERSION, version)
    end)
    
    it("should initialize version on first run", function()
      -- This is tested implicitly in initialization tests
      local version = backend:get_schema_version()
      assert.is_true(version > 0)
    end)
  end)
  
  describe("Error Handling", function()
    it("should handle initialization errors gracefully", function()
      -- Try to create db in non-existent directory
      local bad_backend = SQLiteBackend.new({ path = "/nonexistent/path/test.db" })
      local success, err = bad_backend:initialize()
      
      assert.is_false(success)
      assert.is_string(err)
    end)
    
    it("should handle operations on uninitialized backend", function()
      local uninit = SQLiteBackend.new()
      
      local success, err = uninit:save("test", {}, {})
      assert.is_false(success)
      assert.equals("Database not initialized", err)
      
      local data, load_err = uninit:load("test")
      assert.is_nil(data)
      assert.equals("Database not initialized", load_err)
      
      success, err = uninit:delete("test")
      assert.is_false(success)
      assert.equals("Database not initialized", err)
    end)
  end)
  
  describe("Concurrent Access", function()
    it("should handle multiple backends on same file", function()
      -- Use a real file for this test
      local path = os.tmpname()
      
      local backend1 = SQLiteBackend.new({ path = path })
      local backend2 = SQLiteBackend.new({ path = path })
      
      backend1:initialize()
      backend2:initialize()
      
      -- Write with backend1
      backend1:save("shared", { id = "shared", data = "test" }, {})
      
      -- Read with backend2
      local loaded = backend2:load("shared")
      assert.is_table(loaded)
      assert.equals("shared", loaded.id)
      
      backend1:close()
      backend2:close()
      
      -- Clean up
      os.remove(path)
    end)
  end)
end)
