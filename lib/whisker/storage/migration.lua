--- Storage Migration System
-- Framework for migrating stories between versions with validation and rollback
--
-- @module whisker.storage.migration
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Migration = require("whisker.storage.migration")
-- local migrator = Migration.new({ storage = storage })
-- migrator:migrate_all()

local Migration = {}
Migration.__index = Migration

--- Migration registry
Migration.migrations = {}

--- Current schema version
Migration.CURRENT_VERSION = "2.0"

--- Register a migration
-- @param from_version string Source version
-- @param to_version string Target version
-- @param migration_fn function Migration function(story) -> migrated_story
function Migration.register(from_version, to_version, migration_fn)
  local key = from_version .. "->" .. to_version
  Migration.migrations[key] = {
    from = from_version,
    to = to_version,
    migrate = migration_fn
  }
end

--- Create new migration manager
-- @param options table Configuration
-- @param options.storage table Storage service instance
-- @param options.backup_dir string Backup directory (optional)
-- @param options.dry_run boolean Dry run mode (default: false)
-- @return Migration New migration manager
function Migration.new(options)
  assert(options.storage, "Storage service required")
  
  local self = setmetatable({}, Migration)
  self.storage = options.storage
  self.backup_dir = options.backup_dir or "./.backups"
  self.dry_run = options.dry_run or false
  self.history = {}
  
  return self
end

--- Detect story version
-- @param story table Story data
-- @return string version Story version
function Migration:detect_version(story)
  -- Check metadata for version
  if story.metadata and story.metadata.version then
    return story.metadata.version
  end
  
  -- Check for v2.0 features
  if story.variables and type(story.variables) == "table" then
    for _, var in pairs(story.variables) do
      if type(var) == "table" and var.type and var.default then
        return "2.0"  -- Has typed variables
      end
    end
  end
  
  -- Check for v1.0 features
  if story.passages and type(story.passages) == "table" then
    return "1.0"
  end
  
  -- Unknown or very old
  return "0.9"
end

--- Create backup of story
-- @param story_id string Story ID
-- @param story table Story data
-- @return string|nil backup_path Path to backup file
-- @return string|nil error Error message if failed
function Migration:create_backup(story_id, story)
  if not self.backup_dir then
    return nil, "Backup directory not configured"
  end
  
  -- Create backup directory
  local lfs = require("lfs")
  lfs.mkdir(self.backup_dir)
  
  -- Generate backup filename with timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local backup_path = string.format("%s/%s_%s.json", self.backup_dir, story_id, timestamp)
  
  -- Write backup
  local json = require("cjson")
  local backup_data = json.encode(story)
  
  local file, err = io.open(backup_path, "w")
  if not file then
    return nil, string.format("Failed to create backup: %s", err)
  end
  
  file:write(backup_data)
  file:close()
  
  return backup_path
end

--- Migrate a single story
-- @param story_id string Story ID
-- @param target_version string Target version (optional, defaults to current)
-- @param options table Migration options
-- @return table|nil result Migration result
-- @return string|nil error Error message if failed
function Migration:migrate_story(story_id, target_version, options)
  options = options or {}
  target_version = target_version or Migration.CURRENT_VERSION
  
  -- Load story
  local story, err = self.storage:load_story(story_id)
  if not story then
    return nil, err
  end
  
  -- Detect current version
  local current_version = self:detect_version(story)
  
  -- Check if migration needed
  if current_version == target_version then
    return {
      success = true,
      story_id = story_id,
      from_version = current_version,
      to_version = target_version,
      migrated = false,
      message = "Already at target version"
    }
  end
  
  -- Create backup if not dry run
  local backup_path
  if not self.dry_run and options.backup ~= false then
    backup_path, err = self:create_backup(story_id, story)
    if not backup_path then
      return nil, err
    end
  end
  
  -- Get migration path
  local migration_key = current_version .. "->" .. target_version
  local migration = Migration.migrations[migration_key]
  
  if not migration then
    return nil, string.format("No migration path from %s to %s", current_version, target_version)
  end
  
  -- Perform migration
  local migrated_story
  local success, result = pcall(migration.migrate, story)
  if not success then
    return nil, string.format("Migration failed: %s", result)
  end
  migrated_story = result
  
  -- Update version in metadata
  migrated_story.metadata = migrated_story.metadata or {}
  migrated_story.metadata.version = target_version
  
  -- Validate migrated story
  if options.validate ~= false then
    local validation = self:validate_story(migrated_story)
    if not validation.valid then
      return {
        success = false,
        story_id = story_id,
        errors = validation.errors,
        warnings = validation.warnings
      }
    end
  end
  
  -- Save migrated story if not dry run
  if not self.dry_run then
    local save_success, save_err = self.storage:save_story(story_id, migrated_story)
    if not save_success then
      return nil, string.format("Failed to save migrated story: %s", save_err)
    end
  end
  
  -- Record in history
  table.insert(self.history, {
    story_id = story_id,
    from_version = current_version,
    to_version = target_version,
    timestamp = os.time(),
    backup_path = backup_path
  })
  
  return {
    success = true,
    story_id = story_id,
    from_version = current_version,
    to_version = target_version,
    migrated = true,
    backup_path = backup_path,
    dry_run = self.dry_run
  }
end

--- Migrate all stories in storage
-- @param target_version string Target version (optional)
-- @param options table Migration options
-- @return table results Migration results
function Migration:migrate_all(target_version, options)
  options = options or {}
  
  local stories = self.storage:list_stories()
  local results = {
    total = #stories,
    migrated = 0,
    skipped = 0,
    failed = 0,
    errors = {}
  }
  
  for i, meta in ipairs(stories) do
    -- Progress callback
    if options.on_progress then
      options.on_progress(i, #stories, meta.id)
    end
    
    local result, err = self:migrate_story(meta.id, target_version, options)
    
    if result and result.success then
      if result.migrated then
        results.migrated = results.migrated + 1
      else
        results.skipped = results.skipped + 1
      end
    else
      results.failed = results.failed + 1
      results.errors[meta.id] = err or "Unknown error"
    end
  end
  
  return results
end

--- Rollback a migration
-- @param story_id string Story ID
-- @param backup_path string Path to backup file
-- @return boolean success
-- @return string|nil error
function Migration:rollback(story_id, backup_path)
  if self.dry_run then
    return true, "Dry run mode, no rollback needed"
  end
  
  -- Read backup
  local file, err = io.open(backup_path, "r")
  if not file then
    return false, string.format("Failed to open backup: %s", err)
  end
  
  local backup_data = file:read("*all")
  file:close()
  
  -- Parse backup
  local json = require("cjson")
  local success, story = pcall(json.decode, backup_data)
  if not success then
    return false, "Failed to parse backup"
  end
  
  -- Restore story
  local save_success, save_err = self.storage:save_story(story_id, story)
  if not save_success then
    return false, string.format("Failed to restore story: %s", save_err)
  end
  
  return true
end

--- Validate migrated story
-- @param story table Story data
-- @return table result Validation result
function Migration:validate_story(story)
  local errors = {}
  local warnings = {}
  
  -- Check required fields
  if not story.passages or #story.passages == 0 then
    table.insert(errors, "Story has no passages")
  end
  
  if not story.metadata or not story.metadata.title then
    table.insert(warnings, "Story has no title")
  end
  
  -- Check passages
  local passage_ids = {}
  for _, passage in ipairs(story.passages or {}) do
    if not passage.id then
      table.insert(errors, "Passage missing ID")
    elseif passage_ids[passage.id] then
      table.insert(errors, string.format("Duplicate passage ID: %s", passage.id))
    else
      passage_ids[passage.id] = true
    end
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings
  }
end

--- Get migration history
-- @return table history Array of migration records
function Migration:get_history()
  return self.history
end

--- Clear migration history
function Migration:clear_history()
  self.history = {}
end

-- Register built-in migrations

--- Migration: 1.0 -> 2.0
-- Converts untyped variables to typed variables
Migration.register("1.0", "2.0", function(story)
  local migrated = {}
  
  -- Copy basic fields
  for k, v in pairs(story) do
    migrated[k] = v
  end
  
  -- Migrate variables to typed format
  if story.variables then
    local typed_variables = {}
    
    for name, value in pairs(story.variables) do
      -- Detect type from value
      local var_type = type(value)
      if var_type == "number" then
        typed_variables[name] = {
          type = "number",
          default = value
        }
      elseif var_type == "boolean" then
        typed_variables[name] = {
          type = "boolean",
          default = value
        }
      elseif var_type == "string" then
        typed_variables[name] = {
          type = "string",
          default = value
        }
      else
        -- Unknown type, store as string
        typed_variables[name] = {
          type = "any",
          default = tostring(value)
        }
      end
    end
    
    migrated.variables = typed_variables
  end
  
  -- Add version metadata
  migrated.metadata = migrated.metadata or {}
  migrated.metadata.version = "2.0"
  
  return migrated
end)

--- Migration: 0.9 -> 1.0
-- Basic structure upgrade
Migration.register("0.9", "1.0", function(story)
  local migrated = {
    id = story.id or string.format("story-%d", os.time()),
    title = story.title or story.name or "Untitled",
    metadata = {
      title = story.title or story.name or "Untitled",
      author = story.author,
      version = "1.0"
    },
    passages = story.passages or {},
    variables = story.variables or {},
    tags = story.tags or {}
  }
  
  return migrated
end)

return Migration
