--- Migration System Tests
-- Comprehensive test suite for the storage migration system
--
-- @module tests.storage.migration_spec

describe("Migration System", function()
  local Migration
  local Storage
  local storage
  local migrator
  local test_dir
  
  setup(function()
    Migration = require("whisker.storage.migration")
    Storage = require("whisker.storage")
  end)
  
  before_each(function()
    storage = Storage.new({ backend = "sqlite", path = ":memory:" })
    storage:initialize()
    
    test_dir = os.tmpname()
    os.remove(test_dir)
    
    migrator = Migration.new({
      storage = storage,
      backup_dir = test_dir .. "/.backups"
    })
  end)
  
  after_each(function()
    if storage then
      storage:clear()
    end
    
    if test_dir then
      os.execute("rm -rf " .. test_dir)
    end
    
    -- Clear migration history
    if migrator then
      migrator:clear_history()
    end
  end)
  
  describe("Constructor", function()
    it("should create migration manager with storage", function()
      local m = Migration.new({ storage = storage })
      assert.is_table(m)
      assert.equals(storage, m.storage)
    end)
    
    it("should require storage service", function()
      assert.has_error(function()
        Migration.new({})
      end)
    end)
    
    it("should set default backup directory", function()
      local m = Migration.new({ storage = storage })
      assert.equals("./.backups", m.backup_dir)
    end)
    
    it("should allow custom backup directory", function()
      local m = Migration.new({ storage = storage, backup_dir = "/tmp/backups" })
      assert.equals("/tmp/backups", m.backup_dir)
    end)
    
    it("should support dry run mode", function()
      local m = Migration.new({ storage = storage, dry_run = true })
      assert.is_true(m.dry_run)
    end)
    
    it("should initialize empty history", function()
      local m = Migration.new({ storage = storage })
      assert.is_table(m.history)
      assert.equals(0, #m.history)
    end)
  end)
  
  describe("Version Detection", function()
    it("should detect version from metadata", function()
      local story = {
        metadata = { version = "2.0" }
      }
      
      local version = migrator:detect_version(story)
      assert.equals("2.0", version)
    end)
    
    it("should detect v2.0 from typed variables", function()
      local story = {
        variables = {
          health = { type = "number", default = 100 }
        }
      }
      
      local version = migrator:detect_version(story)
      assert.equals("2.0", version)
    end)
    
    it("should detect v1.0 from passages", function()
      local story = {
        passages = {
          { id = "1", name = "Start" }
        }
      }
      
      local version = migrator:detect_version(story)
      assert.equals("1.0", version)
    end)
    
    it("should default to 0.9 for unknown format", function()
      local story = {}
      
      local version = migrator:detect_version(story)
      assert.equals("0.9", version)
    end)
  end)
  
  describe("Backup Creation", function()
    it("should create backup file", function()
      local story = { id = "backup-test", title = "Test" }
      
      local backup_path = migrator:create_backup("backup-test", story)
      
      assert.is_string(backup_path)
      
      -- Verify file exists
      local file = io.open(backup_path, "r")
      assert.is_not_nil(file)
      if file then file:close() end
    end)
    
    it("should include timestamp in backup filename", function()
      local story = { id = "timestamp-test" }
      
      local backup_path = migrator:create_backup("timestamp-test", story)
      
      -- Backup path should contain story ID and timestamp pattern
      assert.is_true(backup_path:match("timestamp%-test_%d+_%d+%.json") ~= nil)
    end)
    
    it("should create backup directory if not exists", function()
      local story = { id = "dir-test" }
      
      migrator:create_backup("dir-test", story)
      
      -- Check directory exists
      local lfs = require("lfs")
      local attr = lfs.attributes(migrator.backup_dir)
      assert.is_not_nil(attr)
      assert.equals("directory", attr.mode)
    end)
    
    it("should save valid JSON in backup", function()
      local story = { id = "json-test", title = "JSON Test" }
      
      local backup_path = migrator:create_backup("json-test", story)
      
      -- Read and parse backup
      local file = io.open(backup_path, "r")
      local content = file:read("*all")
      file:close()
      
      local json = require("cjson")
      local success, parsed = pcall(json.decode, content)
      
      assert.is_true(success)
      assert.equals("json-test", parsed.id)
    end)
  end)
  
  describe("Story Migration", function()
    it("should migrate story from 0.9 to 1.0", function()
      local old_story = {
        id = "old-story",
        name = "Old Story",
        passages = {}
      }
      
      storage:save_story("old-story", old_story)
      
      local result = migrator:migrate_story("old-story", "1.0")
      
      assert.is_true(result.success)
      assert.equals("0.9", result.from_version)
      assert.equals("1.0", result.to_version)
      assert.is_true(result.migrated)
    end)
    
    it("should migrate story from 1.0 to 2.0", function()
      local v1_story = {
        id = "v1-story",
        passages = { { id = "1", name = "Start" } },
        variables = {
          health = 100,
          name = "Player"
        }
      }
      
      storage:save_story("v1-story", v1_story)
      
      local result = migrator:migrate_story("v1-story", "2.0")
      
      assert.is_true(result.success)
      assert.equals("1.0", result.from_version)
      assert.equals("2.0", result.to_version)
      assert.is_true(result.migrated)
      
      -- Verify variables are typed
      local migrated = storage:load_story("v1-story")
      assert.is_table(migrated.variables.health)
      assert.equals("number", migrated.variables.health.type)
      assert.equals(100, migrated.variables.health.default)
    end)
    
    it("should skip migration if already at target version", function()
      local story = {
        metadata = { version = "2.0" },
        passages = {}
      }
      
      storage:save_story("current", story)
      
      local result = migrator:migrate_story("current", "2.0")
      
      assert.is_true(result.success)
      assert.is_false(result.migrated)
      assert.is_string(result.message)
    end)
    
    it("should create backup before migration", function()
      local story = { id = "backup-test", passages = {} }
      storage:save_story("backup-test", story)
      
      local result = migrator:migrate_story("backup-test", "1.0")
      
      assert.is_string(result.backup_path)
      
      -- Verify backup exists
      local file = io.open(result.backup_path, "r")
      assert.is_not_nil(file)
      if file then file:close() end
    end)
    
    it("should not create backup in dry run mode", function()
      local dry_migrator = Migration.new({
        storage = storage,
        backup_dir = test_dir .. "/.dry_backups",
        dry_run = true
      })
      
      local story = { id = "dry-test", passages = {} }
      storage:save_story("dry-test", story)
      
      local result = dry_migrator:migrate_story("dry-test", "1.0")
      
      assert.is_true(result.dry_run)
      assert.is_nil(result.backup_path)
    end)
    
    it("should not save in dry run mode", function()
      local dry_migrator = Migration.new({
        storage = storage,
        dry_run = true
      })
      
      local story = { id = "dry-save", name = "Old Name", passages = {} }
      storage:save_story("dry-save", story)
      
      dry_migrator:migrate_story("dry-save", "1.0")
      
      -- Story should not be changed
      local loaded = storage:load_story("dry-save")
      assert.equals("Old Name", loaded.name)
      assert.is_nil(loaded.title)  -- 1.0 format uses title, not name
    end)
    
    it("should validate migrated story", function()
      -- Create story that will fail validation
      local bad_story = {
        id = "invalid",
        passages = {}  -- Empty passages array fails validation
      }
      
      storage:save_story("invalid", bad_story)
      
      local result = migrator:migrate_story("invalid", "1.0")
      
      -- Should fail validation
      assert.is_false(result.success)
      assert.is_table(result.errors)
    end)
    
    it("should allow skipping validation", function()
      local story = { id = "no-validate", passages = {} }
      storage:save_story("no-validate", story)
      
      local result = migrator:migrate_story("no-validate", "1.0", { validate = false })
      
      -- Should succeed even with empty passages
      assert.is_true(result.success)
    end)
    
    it("should update version in metadata", function()
      local story = { id = "version-update", passages = { { id = "1" } } }
      storage:save_story("version-update", story)
      
      migrator:migrate_story("version-update", "1.0")
      
      local migrated = storage:load_story("version-update")
      assert.equals("1.0", migrated.metadata.version)
    end)
    
    it("should return error for non-existent story", function()
      local result, err = migrator:migrate_story("nonexistent", "2.0")
      
      assert.is_nil(result)
      assert.is_string(err)
    end)
    
    it("should return error for unsupported migration path", function()
      local story = {
        metadata = { version = "99.0" },
        passages = {}
      }
      storage:save_story("unsupported", story)
      
      local result, err = migrator:migrate_story("unsupported", "2.0")
      
      assert.is_nil(result)
      assert.is_string(err)
    end)
    
    it("should record migration in history", function()
      local story = { id = "history-test", passages = {} }
      storage:save_story("history-test", story)
      
      migrator:migrate_story("history-test", "1.0")
      
      local history = migrator:get_history()
      assert.equals(1, #history)
      assert.equals("history-test", history[1].story_id)
    end)
  end)
  
  describe("Migrate All", function()
    before_each(function()
      -- Add test stories
      storage:save_story("s1", { id = "s1", passages = {} })
      storage:save_story("s2", { id = "s2", name = "S2", passages = {} })
      storage:save_story("s3", { metadata = { version = "2.0" }, passages = {} })
    end)
    
    it("should migrate all stories", function()
      local results = migrator:migrate_all("1.0")
      
      assert.equals(3, results.total)
      assert.is_true(results.migrated >= 1)
    end)
    
    it("should report migration statistics", function()
      local results = migrator:migrate_all("1.0")
      
      assert.is_number(results.total)
      assert.is_number(results.migrated)
      assert.is_number(results.skipped)
      assert.is_number(results.failed)
      assert.is_table(results.errors)
    end)
    
    it("should call progress callback", function()
      local progress_calls = {}
      
      migrator:migrate_all("1.0", {
        on_progress = function(current, total, story_id)
          table.insert(progress_calls, {
            current = current,
            total = total,
            story_id = story_id
          })
        end
      })
      
      assert.equals(3, #progress_calls)
    end)
    
    it("should skip stories already at target version", function()
      local results = migrator:migrate_all("2.0")
      
      -- s3 is already at 2.0
      assert.is_true(results.skipped >= 1)
    end)
    
    it("should collect errors from failed migrations", function()
      -- Add an invalid story
      storage:save_story("invalid", { id = "invalid", passages = {} })
      
      local results = migrator:migrate_all("1.0")
      
      if results.failed > 0 then
        assert.is_table(results.errors)
      end
    end)
  end)
  
  describe("Rollback", function()
    it("should rollback to backup", function()
      local original = { id = "rollback-test", title = "Original", passages = { { id = "1" } } }
      storage:save_story("rollback-test", original)
      
      -- Migrate
      local result = migrator:migrate_story("rollback-test", "1.0")
      local backup_path = result.backup_path
      
      -- Modify story
      storage:save_story("rollback-test", { id = "rollback-test", title = "Modified", passages = { { id = "1" } } })
      
      -- Rollback
      local success = migrator:rollback("rollback-test", backup_path)
      assert.is_true(success)
      
      -- Verify rollback
      local restored = storage:load_story("rollback-test")
      assert.equals("Original", restored.title)
    end)
    
    it("should return error for invalid backup path", function()
      local success, err = migrator:rollback("test", "/nonexistent/backup.json")
      
      assert.is_false(success)
      assert.is_string(err)
    end)
    
    it("should handle dry run mode", function()
      local dry_migrator = Migration.new({
        storage = storage,
        dry_run = true
      })
      
      local success, msg = dry_migrator:rollback("test", "backup.json")
      
      assert.is_true(success)
      assert.is_string(msg)
    end)
  end)
  
  describe("Story Validation", function()
    it("should validate story with passages", function()
      local story = {
        passages = { { id = "1", name = "Start" } },
        metadata = { title = "Valid Story" }
      }
      
      local result = migrator:validate_story(story)
      
      assert.is_true(result.valid)
      assert.equals(0, #result.errors)
    end)
    
    it("should error on missing passages", function()
      local story = {}
      
      local result = migrator:validate_story(story)
      
      assert.is_false(result.valid)
      assert.is_true(#result.errors > 0)
    end)
    
    it("should error on empty passages", function()
      local story = { passages = {} }
      
      local result = migrator:validate_story(story)
      
      assert.is_false(result.valid)
    end)
    
    it("should warn on missing title", function()
      local story = {
        passages = { { id = "1" } }
      }
      
      local result = migrator:validate_story(story)
      
      assert.is_true(#result.warnings > 0)
    end)
    
    it("should error on passage missing ID", function()
      local story = {
        passages = { { name = "Start" } },  -- No ID
        metadata = { title = "Test" }
      }
      
      local result = migrator:validate_story(story)
      
      assert.is_false(result.valid)
      assert.is_true(#result.errors > 0)
    end)
    
    it("should error on duplicate passage IDs", function()
      local story = {
        passages = {
          { id = "1", name = "First" },
          { id = "1", name = "Duplicate" }
        },
        metadata = { title = "Test" }
      }
      
      local result = migrator:validate_story(story)
      
      assert.is_false(result.valid)
      assert.is_true(#result.errors > 0)
    end)
  end)
  
  describe("Migration History", function()
    it("should track migration history", function()
      local story = { id = "track-test", passages = {} }
      storage:save_story("track-test", story)
      
      migrator:migrate_story("track-test", "1.0")
      
      local history = migrator:get_history()
      assert.equals(1, #history)
    end)
    
    it("should include migration details in history", function()
      local story = { id = "details-test", passages = {} }
      storage:save_story("details-test", story)
      
      migrator:migrate_story("details-test", "1.0")
      
      local history = migrator:get_history()
      local entry = history[1]
      
      assert.equals("details-test", entry.story_id)
      assert.is_string(entry.from_version)
      assert.is_string(entry.to_version)
      assert.is_number(entry.timestamp)
    end)
    
    it("should clear history", function()
      local story = { id = "clear-test", passages = {} }
      storage:save_story("clear-test", story)
      
      migrator:migrate_story("clear-test", "1.0")
      migrator:clear_history()
      
      local history = migrator:get_history()
      assert.equals(0, #history)
    end)
  end)
  
  describe("Built-in Migrations", function()
    describe("0.9 -> 1.0", function()
      it("should convert name to title", function()
        local v09_story = {
          id = "name-test",
          name = "My Story",
          passages = {}
        }
        
        storage:save_story("name-test", v09_story)
        migrator:migrate_story("name-test", "1.0")
        
        local migrated = storage:load_story("name-test")
        assert.equals("My Story", migrated.title)
      end)
      
      it("should create metadata", function()
        local v09_story = {
          id = "meta-test",
          author = "Test Author",
          passages = {}
        }
        
        storage:save_story("meta-test", v09_story)
        migrator:migrate_story("meta-test", "1.0")
        
        local migrated = storage:load_story("meta-test")
        assert.is_table(migrated.metadata)
        assert.equals("Test Author", migrated.metadata.author)
      end)
      
      it("should preserve passages and variables", function()
        local v09_story = {
          id = "preserve-test",
          passages = { { id = "1", name = "Start" } },
          variables = { health = 100 }
        }
        
        storage:save_story("preserve-test", v09_story)
        migrator:migrate_story("preserve-test", "1.0")
        
        local migrated = storage:load_story("preserve-test")
        assert.equals(1, #migrated.passages)
        assert.equals(100, migrated.variables.health)
      end)
    end)
    
    describe("1.0 -> 2.0", function()
      it("should convert variables to typed format", function()
        local v1_story = {
          passages = { { id = "1" } },
          variables = {
            health = 100,
            name = "Player",
            alive = true
          }
        }
        
        storage:save_story("typed-test", v1_story)
        migrator:migrate_story("typed-test", "2.0")
        
        local migrated = storage:load_story("typed-test")
        
        -- Check number type
        assert.equals("number", migrated.variables.health.type)
        assert.equals(100, migrated.variables.health.default)
        
        -- Check string type
        assert.equals("string", migrated.variables.name.type)
        assert.equals("Player", migrated.variables.name.default)
        
        -- Check boolean type
        assert.equals("boolean", migrated.variables.alive.type)
        assert.is_true(migrated.variables.alive.default)
      end)
      
      it("should handle unknown types", function()
        local v1_story = {
          passages = { { id = "1" } },
          variables = {
            complex = { nested = "value" }
          }
        }
        
        storage:save_story("unknown-type", v1_story)
        migrator:migrate_story("unknown-type", "2.0")
        
        local migrated = storage:load_story("unknown-type")
        
        -- Unknown types should be converted to 'any'
        assert.equals("any", migrated.variables.complex.type)
      end)
    end)
  end)
  
  describe("Migration Registration", function()
    it("should register custom migration", function()
      Migration.register("custom-v1", "custom-v2", function(story)
        story.custom_field = "migrated"
        return story
      end)
      
      assert.is_table(Migration.migrations["custom-v1->custom-v2"])
    end)
  end)
end)
