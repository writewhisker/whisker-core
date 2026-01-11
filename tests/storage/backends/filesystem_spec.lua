--- Filesystem Backend Tests
-- Comprehensive test suite for the Filesystem storage backend
--
-- @module tests.storage.backends.filesystem_spec

describe("Filesystem Backend", function()
  local FilesystemBackend
  local backend
  local test_dir
  
  setup(function()
    FilesystemBackend = require("whisker.storage.backends.filesystem")
  end)
  
  before_each(function()
    -- Create unique test directory for each test
    test_dir = os.tmpname()
    os.remove(test_dir)  -- Remove the file created by tmpname
    backend = FilesystemBackend.new({ path = test_dir })
  end)
  
  after_each(function()
    if backend then
      backend:clear()
    end
    
    -- Clean up test directory
    if test_dir then
      os.execute("rm -rf " .. test_dir)
    end
  end)
  
  describe("Constructor", function()
    it("should create backend with default options", function()
      local b = FilesystemBackend.new()
      assert.is_table(b)
      assert.equals("./whisker_storage", b.root)
      assert.equals("./whisker_storage/stories", b.stories_dir)
      assert.equals("./whisker_storage/metadata", b.metadata_dir)
      assert.is_table(b.index)
    end)
    
    it("should create backend with custom path", function()
      local b = FilesystemBackend.new({ path = "/tmp/custom" })
      assert.equals("/tmp/custom", b.root)
      assert.equals("/tmp/custom/stories", b.stories_dir)
      assert.equals("/tmp/custom/metadata", b.metadata_dir)
    end)
  end)
  
  describe("Initialization", function()
    it("should initialize successfully", function()
      local success, err = backend:initialize()
      assert.is_true(success)
      assert.is_nil(err)
    end)
    
    it("should create directory structure", function()
      backend:initialize()
      
      local lfs = require("lfs")
      
      -- Check root directory
      local attr = lfs.attributes(backend.root)
      assert.is_not_nil(attr)
      assert.equals("directory", attr.mode)
      
      -- Check stories directory
      attr = lfs.attributes(backend.stories_dir)
      assert.is_not_nil(attr)
      assert.equals("directory", attr.mode)
      
      -- Check metadata directory
      attr = lfs.attributes(backend.metadata_dir)
      assert.is_not_nil(attr)
      assert.equals("directory", attr.mode)
    end)
    
    it("should create index file", function()
      backend:initialize()
      
      local file = io.open(backend.index_file, "r")
      assert.is_not_nil(file)
      file:close()
    end)
    
    it("should load existing index", function()
      backend:initialize()
      
      -- Add a story
      backend:save("test", { id = "test" }, {})
      
      -- Create new backend instance
      local backend2 = FilesystemBackend.new({ path = test_dir })
      backend2:initialize()
      
      -- Should have loaded the index
      assert.is_true(backend2:exists("test"))
    end)
    
    it("should handle corrupted index gracefully", function()
      backend:initialize()
      
      -- Corrupt the index file
      local file = io.open(backend.index_file, "w")
      file:write("invalid json {{{")
      file:close()
      
      -- Create new backend and initialize
      local backend2 = FilesystemBackend.new({ path = test_dir })
      local success = backend2:initialize()
      
      -- Should succeed and create empty index
      assert.is_true(success)
      assert.is_table(backend2.index)
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
    
    it("should create story file", function()
      backend:save("file-test", { id = "file-test" }, {})
      
      local story_path = backend:get_story_path("file-test")
      local file = io.open(story_path, "r")
      assert.is_not_nil(file)
      file:close()
    end)
    
    it("should create metadata file", function()
      backend:save("meta-test", { id = "meta-test" }, {})
      
      local meta_path = backend:get_metadata_path("meta-test")
      local file = io.open(meta_path, "r")
      assert.is_not_nil(file)
      file:close()
    end)
    
    it("should update existing story", function()
      local story_v1 = {
        id = "story-1",
        title = "Version 1"
      }
      
      backend:save("story-1", story_v1, {})
      
      local story_v2 = {
        id = "story-1",
        title = "Version 2"
      }
      
      backend:save("story-1", story_v2, {})
      
      local loaded = backend:load("story-1")
      assert.equals("Version 2", loaded.title)
    end)
    
    it("should preserve created_at on update", function()
      backend:save("preserve-test", { id = "preserve-test" }, {})
      
      local meta1 = backend:get_metadata("preserve-test")
      local created_at = meta1.created_at
      
      -- Wait a bit
      os.execute("sleep 1")
      
      -- Update
      backend:save("preserve-test", { id = "preserve-test", title = "Updated" }, {})
      
      local meta2 = backend:get_metadata("preserve-test")
      assert.equals(created_at, meta2.created_at)
      assert.is_true(meta2.updated_at > meta1.updated_at)
    end)
    
    it("should save metadata with tags", function()
      backend:save("tagged", { id = "tagged" }, { tags = {"adventure", "test"} })
      
      local metadata = backend:get_metadata("tagged")
      assert.is_table(metadata.tags)
      assert.equals(2, #metadata.tags)
    end)
    
    it("should return error when loading non-existent story", function()
      local data, err = backend:load("nonexistent")
      assert.is_nil(data)
      assert.equals("Story not found", err)
    end)
    
    it("should handle large stories", function()
      local large_story = {
        id = "large",
        passages = {}
      }
      
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
    
    it("should remove story file", function()
      backend:save("delete-file", { id = "delete-file" }, {})
      
      local story_path = backend:get_story_path("delete-file")
      backend:delete("delete-file")
      
      local file = io.open(story_path, "r")
      assert.is_nil(file)
    end)
    
    it("should remove metadata file", function()
      backend:save("delete-meta", { id = "delete-meta" }, {})
      
      local meta_path = backend:get_metadata_path("delete-meta")
      backend:delete("delete-meta")
      
      local file = io.open(meta_path, "r")
      assert.is_nil(file)
    end)
    
    it("should remove from index", function()
      backend:save("index-delete", { id = "index-delete" }, {})
      
      assert.is_not_nil(backend.index["index-delete"])
      
      backend:delete("index-delete")
      
      assert.is_nil(backend.index["index-delete"])
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
      
      -- Verify results have adventure tag
      for _, metadata in ipairs(results) do
        local has_tag = false
        for _, tag in ipairs(metadata.tags) do
          if tag == "adventure" then
            has_tag = true
            break
          end
        end
        assert.is_true(has_tag)
      end
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
      backend:update_metadata("meta-test", { tags = {"new", "tags"} })
      
      local metadata = backend:get_metadata("meta-test")
      assert.equals(2, #metadata.tags)
    end)
    
    it("should update timestamp when metadata updated", function()
      local meta_before = backend:get_metadata("meta-test")
      
      os.execute("sleep 1")
      
      backend:update_metadata("meta-test", { title = "New Title" })
      
      local meta_after = backend:get_metadata("meta-test")
      assert.is_true(meta_after.updated_at > meta_before.updated_at)
    end)
    
    it("should persist metadata to file", function()
      backend:update_metadata("meta-test", { title = "Persisted" })
      
      -- Create new backend instance
      local backend2 = FilesystemBackend.new({ path = test_dir })
      backend2:initialize()
      
      local metadata = backend2:get_metadata("meta-test")
      assert.equals("Persisted", metadata.title)
    end)
    
    it("should return error when updating non-existent story", function()
      local success, err = backend:update_metadata("nonexistent", { title = "Test" })
      assert.is_false(success)
      assert.equals("Story not found", err)
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
    
    it("should remove all story files", function()
      backend:clear()
      
      local lfs = require("lfs")
      local count = 0
      
      for file in lfs.dir(backend.stories_dir) do
        if file:match("%.json$") then
          count = count + 1
        end
      end
      
      assert.equals(0, count)
    end)
    
    it("should remove all metadata files", function()
      backend:clear()
      
      local lfs = require("lfs")
      local count = 0
      
      for file in lfs.dir(backend.metadata_dir) do
        if file:match("%.meta%.json$") then
          count = count + 1
        end
      end
      
      assert.equals(0, count)
    end)
    
    it("should clear index", function()
      backend:clear()
      
      assert.equals(0, #backend:list())
    end)
  end)
  
  describe("Rebuild Index", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should rebuild index from metadata files", function()
      -- Add stories
      backend:save("story-1", { id = "story-1" }, {})
      backend:save("story-2", { id = "story-2" }, {})
      backend:save("story-3", { id = "story-3" }, {})
      
      -- Corrupt index
      backend.index = {}
      
      -- Rebuild
      local count = backend:rebuild_index()
      
      assert.equals(3, count)
      assert.is_true(backend:exists("story-1"))
      assert.is_true(backend:exists("story-2"))
      assert.is_true(backend:exists("story-3"))
    end)
    
    it("should persist rebuilt index", function()
      backend:save("persist-test", { id = "persist-test" }, {})
      
      -- Corrupt and rebuild
      backend.index = {}
      backend:rebuild_index()
      
      -- Create new backend instance
      local backend2 = FilesystemBackend.new({ path = test_dir })
      backend2:initialize()
      
      assert.is_true(backend2:exists("persist-test"))
    end)
    
    it("should handle corrupted metadata files gracefully", function()
      backend:save("valid", { id = "valid" }, {})
      
      -- Create corrupted metadata file
      local bad_meta_path = backend:get_metadata_path("bad")
      local file = io.open(bad_meta_path, "w")
      file:write("invalid json")
      file:close()
      
      -- Rebuild should not fail
      local count = backend:rebuild_index()
      
      -- Should only count valid metadata
      assert.equals(1, count)
    end)
  end)
  
  describe("Atomic Writes", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should use atomic write for stories", function()
      -- This test verifies that temp files are used
      backend:save("atomic-test", { id = "atomic-test" }, {})
      
      -- Temp file should not exist after save
      local temp_path = backend:get_story_path("atomic-test") .. ".tmp"
      local file = io.open(temp_path, "r")
      assert.is_nil(file)
      
      -- Actual file should exist
      local actual_path = backend:get_story_path("atomic-test")
      file = io.open(actual_path, "r")
      assert.is_not_nil(file)
      file:close()
    end)
  end)
  
  describe("Path Methods", function()
    before_each(function()
      backend:initialize()
    end)
    
    it("should generate correct story path", function()
      local path = backend:get_story_path("test-id")
      assert.equals(backend.stories_dir .. "/test-id.json", path)
    end)
    
    it("should generate correct metadata path", function()
      local path = backend:get_metadata_path("test-id")
      assert.equals(backend.metadata_dir .. "/test-id.meta.json", path)
    end)
  end)
  
  describe("Persistence", function()
    it("should persist across backend instances", function()
      backend:initialize()
      backend:save("persist-1", { id = "persist-1", title = "Persistent" }, {})
      
      -- Create new backend with same path
      local backend2 = FilesystemBackend.new({ path = test_dir })
      backend2:initialize()
      
      -- Should load the story
      local loaded = backend2:load("persist-1")
      assert.is_table(loaded)
      assert.equals("Persistent", loaded.title)
      
      backend2:clear()
    end)
    
    it("should isolate different storage paths", function()
      backend:initialize()
      backend:save("path1-story", { id = "path1-story" }, {})
      
      -- Create backend with different path
      local test_dir2 = os.tmpname()
      os.remove(test_dir2)
      local backend2 = FilesystemBackend.new({ path = test_dir2 })
      backend2:initialize()
      
      -- Should not have path1-story
      assert.is_false(backend2:exists("path1-story"))
      
      backend2:clear()
      os.execute("rm -rf " .. test_dir2)
    end)
  end)
end)
