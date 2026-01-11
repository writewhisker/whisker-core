--- Test suite for storage backend interface
-- Tests the validation and contract enforcement of the backend interface

describe("Storage Backend Interface", function()
  local Backend
  
  before_each(function()
    -- Remove from cache to get fresh module
    package.loaded["whisker.storage.interfaces.backend"] = nil
    Backend = require("whisker.storage.interfaces.backend")
  end)
  
  describe("constructor", function()
    it("should create instance with valid implementation", function()
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      
      local backend = Backend.new(impl)
      assert.is_not_nil(backend)
      assert.is_table(backend)
    end)
    
    it("should reject non-table implementation", function()
      assert.has_error(function()
        Backend.new("not a table")
      end, "Backend implementation must be a table")
    end)
    
    it("should reject implementation missing required methods", function()
      local impl = {
        initialize = function() end,
        save = function() end
        -- missing other required methods
      }
      
      assert.has_error(function()
        Backend.new(impl)
      end)
    end)
    
    it("should list all required methods", function()
      assert.is_table(Backend.REQUIRED_METHODS)
      assert.is_true(#Backend.REQUIRED_METHODS > 0)
      
      -- Check for key methods
      local has_save = false
      local has_load = false
      for _, method in ipairs(Backend.REQUIRED_METHODS) do
        if method == "save" then has_save = true end
        if method == "load" then has_load = true end
      end
      assert.is_true(has_save)
      assert.is_true(has_load)
    end)
  end)
  
  describe("has_method", function()
    local backend
    
    before_each(function()
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end,
        -- Optional method
        save_preference = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should return true for implemented optional methods", function()
      assert.is_true(backend:has_method("save_preference"))
    end)
    
    it("should return false for unimplemented optional methods", function()
      assert.is_false(backend:has_method("load_preference"))
    end)
    
    it("should return true for required methods", function()
      assert.is_true(backend:has_method("save"))
      assert.is_true(backend:has_method("load"))
    end)
  end)
  
  describe("save", function()
    local backend
    
    before_each(function()
      local impl = {
        initialize = function() return true end,
        save = function(self, key, data, metadata) 
          return true, nil
        end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should save with valid parameters", function()
      local success, err = backend:save("key-1", {title = "Test"}, {tags = {"test"}})
      assert.is_true(success)
      assert.is_nil(err)
    end)
    
    it("should reject empty key", function()
      assert.has_error(function()
        backend:save("", {title = "Test"})
      end)
    end)
    
    it("should reject nil key", function()
      assert.has_error(function()
        backend:save(nil, {title = "Test"})
      end)
    end)
    
    it("should reject non-table data", function()
      assert.has_error(function()
        backend:save("key-1", "not a table")
      end)
    end)
    
    it("should allow nil metadata (uses empty table)", function()
      local success = backend:save("key-1", {title = "Test"})
      assert.is_true(success)
    end)
  end)
  
  describe("load", function()
    local backend, test_data
    
    before_each(function()
      test_data = {title = "Test Story", passages = {}}
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function(self, key)
          if key == "existing" then
            return test_data, nil
          else
            return nil, "Not found"
          end
        end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should load existing story", function()
      local data, err = backend:load("existing")
      assert.are.same(test_data, data)
      assert.is_nil(err)
    end)
    
    it("should return nil for non-existent story", function()
      local data, err = backend:load("non-existent")
      assert.is_nil(data)
      assert.is_not_nil(err)
    end)
    
    it("should reject empty key", function()
      assert.has_error(function()
        backend:load("")
      end)
    end)
  end)
  
  describe("delete", function()
    local backend
    
    before_each(function()
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function(self, key)
          if key == "existing" then
            return true, nil
          else
            return false, "Not found"
          end
        end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should delete existing story", function()
      local success, err = backend:delete("existing")
      assert.is_true(success)
      assert.is_nil(err)
    end)
    
    it("should return false for non-existent story", function()
      local success, err = backend:delete("non-existent")
      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)
  
  describe("list", function()
    local backend, test_stories
    
    before_each(function()
      test_stories = {
        {id = "story-1", title = "Story 1"},
        {id = "story-2", title = "Story 2"}
      }
      
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function(self, filter)
          if filter and filter.limit then
            return {test_stories[1]}, nil
          end
          return test_stories, nil
        end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should list all stories", function()
      local stories, err = backend:list()
      assert.are.same(test_stories, stories)
      assert.is_nil(err)
    end)
    
    it("should respect filter options", function()
      local stories, err = backend:list({limit = 1})
      assert.equal(1, #stories)
    end)
    
    it("should handle empty filter", function()
      local stories, err = backend:list({})
      assert.are.same(test_stories, stories)
    end)
  end)
  
  describe("exists", function()
    local backend
    
    before_each(function()
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function(self, key)
          return key == "existing", nil
        end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should return true for existing story", function()
      local exists = backend:exists("existing")
      assert.is_true(exists)
    end)
    
    it("should return false for non-existent story", function()
      local exists = backend:exists("non-existent")
      assert.is_false(exists)
    end)
  end)
  
  describe("optional methods", function()
    it("should handle missing optional methods gracefully", function()
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
        -- No optional methods
      }
      
      local backend = Backend.new(impl)
      
      -- Should return error for unimplemented optional methods
      local success, err = backend:save_preference("key", {value = "test"})
      assert.is_false(success)
      assert.is_not_nil(err)
      assert.matches("does not support", err)
    end)
    
    it("should call optional methods when implemented", function()
      local called = false
      
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function() return {} end,
        update_metadata = function() return true end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end,
        save_preference = function(self, key, entry)
          called = true
          return true
        end
      }
      
      local backend = Backend.new(impl)
      backend:save_preference("key", {value = "test"})
      assert.is_true(called)
    end)
  end)
  
  describe("metadata operations", function()
    local backend
    
    before_each(function()
      local metadata_store = {}
      
      local impl = {
        initialize = function() return true end,
        save = function() return true end,
        load = function() return {} end,
        delete = function() return true end,
        list = function() return {} end,
        exists = function() return false end,
        get_metadata = function(self, key)
          return metadata_store[key] or {id = key, title = "Unknown"}, nil
        end,
        update_metadata = function(self, key, metadata)
          metadata_store[key] = metadata_store[key] or {}
          for k, v in pairs(metadata) do
            metadata_store[key][k] = v
          end
          return true, nil
        end,
        export = function() return "" end,
        import_data = function() return "id" end,
        get_storage_usage = function() return 0 end,
        clear = function() return true end
      }
      backend = Backend.new(impl)
    end)
    
    it("should get metadata", function()
      local meta = backend:get_metadata("test-1")
      assert.is_table(meta)
      assert.equal("test-1", meta.id)
    end)
    
    it("should update metadata", function()
      backend:update_metadata("test-1", {title = "New Title"})
      local meta = backend:get_metadata("test-1")
      assert.equal("New Title", meta.title)
    end)
  end)
end)
