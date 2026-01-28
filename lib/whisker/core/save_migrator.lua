-- lib/whisker/core/save_migrator.lua
-- Save State Migrator for WLS
-- WLS 1.0 GAP-068: Save state versioning with migration support

local SaveMigrator = {}
SaveMigrator.__index = SaveMigrator

-- Current save state version
SaveMigrator.CURRENT_VERSION = "1.0.0"

-- Migration registry: source_version -> { to, migrate }
SaveMigrator.MIGRATIONS = {}

--- Create a new SaveMigrator instance
---@return SaveMigrator
function SaveMigrator.new()
    local self = setmetatable({}, SaveMigrator)
    return self
end

--- Register a migration
---@param from_version string Source version
---@param to_version string Target version
---@param migrate_fn function Migration function(data) -> data, error
function SaveMigrator.register(from_version, to_version, migrate_fn)
    SaveMigrator.MIGRATIONS[from_version] = {
        to = to_version,
        migrate = migrate_fn
    }
end

--- Check if migration is needed
---@param data table Save data
---@return boolean needs_migration
function SaveMigrator:needs_migration(data)
    local version = data.version or "0.0.0"
    return version ~= self.CURRENT_VERSION
end

--- Migrate save data to current version
---@param data table Save data
---@return table|nil migrated_data
---@return string|nil error
function SaveMigrator:migrate(data)
    local version = data.version or "0.0.0"

    if version == self.CURRENT_VERSION then
        return data, nil
    end

    -- Check if version is newer than current (downgrade not supported)
    if self:compare_versions(version, self.CURRENT_VERSION) > 0 then
        return nil, string.format(
            "Save version %s is newer than supported version %s",
            version, self.CURRENT_VERSION
        )
    end

    -- Apply migrations in sequence
    local current_data = self:deep_copy(data)  -- Don't modify original
    local current_version = version
    local max_iterations = 100  -- Safety limit

    for i = 1, max_iterations do
        local migration = self.MIGRATIONS[current_version]
        if not migration then
            -- No more migrations, check if we reached current
            if current_version == self.CURRENT_VERSION then
                return current_data, nil
            end
            -- Try to skip to current (for compatible minor versions)
            if self:is_compatible(current_version) then
                current_data.version = self.CURRENT_VERSION
                return current_data, nil
            end
            return nil, string.format(
                "No migration path from version %s to %s",
                current_version, self.CURRENT_VERSION
            )
        end

        -- Apply migration
        local migrated, err = migration.migrate(current_data)
        if err then
            return nil, string.format(
                "Migration from %s to %s failed: %s",
                current_version, migration.to, err
            )
        end

        current_data = migrated
        current_data.version = migration.to
        current_version = migration.to

        if current_version == self.CURRENT_VERSION then
            break
        end
    end

    return current_data, nil
end

--- Compare two semantic versions
---@param v1 string First version
---@param v2 string Second version
---@return number -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function SaveMigrator:compare_versions(v1, v2)
    local function parse(v)
        local major, minor, patch = v:match("^(%d+)%.(%d+)%.?(%d*)$")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end

    local maj1, min1, pat1 = parse(v1)
    local maj2, min2, pat2 = parse(v2)

    if maj1 ~= maj2 then return maj1 < maj2 and -1 or 1 end
    if min1 ~= min2 then return min1 < min2 and -1 or 1 end
    if pat1 ~= pat2 then return pat1 < pat2 and -1 or 1 end
    return 0
end

--- Check if version is compatible (same major.minor)
---@param version string Version to check
---@return boolean
function SaveMigrator:is_compatible(version)
    local current_major, current_minor = self.CURRENT_VERSION:match("^(%d+)%.(%d+)")
    local save_major, save_minor = version:match("^(%d+)%.(%d+)")
    return current_major == save_major and current_minor == save_minor
end

--- Validate save data integrity
---@param data table Save data
---@return boolean valid
---@return table|nil errors Array of error messages
function SaveMigrator:validate(data)
    local errors = {}

    -- Check required fields
    if not data.version then
        table.insert(errors, "Missing version field")
    end

    -- current_passage can be nil for new/empty game states
    -- (no passage visited yet)

    -- variables can be nil (will default to empty table)
    -- but if present, must be a table
    if data.variables ~= nil and type(data.variables) ~= "table" then
        table.insert(errors, "Invalid variables field type")
    end

    -- Check data types
    if data.tunnel_stack and type(data.tunnel_stack) ~= "table" then
        table.insert(errors, "Invalid tunnel_stack type")
    end

    if data.visited_passages and type(data.visited_passages) ~= "table" then
        table.insert(errors, "Invalid visited_passages type")
    end

    if data.history_stack and type(data.history_stack) ~= "table" then
        table.insert(errors, "Invalid history_stack type")
    end

    -- Validate version format
    if data.version and not data.version:match("^%d+%.%d+%.?%d*$") then
        table.insert(errors, "Invalid version format: " .. tostring(data.version))
    end

    return #errors == 0, errors
end

--- Deep copy a table
---@param original table Table to copy
---@return table Copy
function SaveMigrator:deep_copy(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = self:deep_copy(v)
        else
            copy[k] = v
        end
    end

    return copy
end

--- Get migration path from one version to another
---@param from_version string Starting version
---@param to_version string Target version (default: CURRENT_VERSION)
---@return table|nil Array of version steps
---@return string|nil error
function SaveMigrator:get_migration_path(from_version, to_version)
    to_version = to_version or self.CURRENT_VERSION

    if from_version == to_version then
        return {}, nil
    end

    if self:compare_versions(from_version, to_version) > 0 then
        return nil, "Downgrade not supported"
    end

    local path = { from_version }
    local current = from_version
    local max_iterations = 100

    for i = 1, max_iterations do
        local migration = self.MIGRATIONS[current]
        if not migration then
            if current == to_version then
                return path, nil
            end
            if self:is_compatible(current) then
                table.insert(path, to_version)
                return path, nil
            end
            return nil, "No migration path found"
        end

        table.insert(path, migration.to)
        current = migration.to

        if current == to_version then
            return path, nil
        end
    end

    return nil, "Migration path too long"
end

--- Get list of all registered versions
---@return table Array of version strings
function SaveMigrator:get_registered_versions()
    local versions = { self.CURRENT_VERSION }
    local seen = { [self.CURRENT_VERSION] = true }

    for from_version, migration in pairs(self.MIGRATIONS) do
        if not seen[from_version] then
            table.insert(versions, from_version)
            seen[from_version] = true
        end
        if not seen[migration.to] then
            table.insert(versions, migration.to)
            seen[migration.to] = true
        end
    end

    -- Sort versions
    table.sort(versions, function(a, b)
        return self:compare_versions(a, b) < 0
    end)

    return versions
end

-- ============================================================================
-- Built-in Migrations
-- ============================================================================

-- Migration from 0.9.0 to 1.0.0
SaveMigrator.register("0.9.0", "1.0.0", function(data)
    -- Rename 'visited' to 'visited_passages'
    if data.visited and not data.visited_passages then
        data.visited_passages = data.visited
        data.visited = nil
    end

    -- Add tunnel_stack if missing
    if not data.tunnel_stack then
        data.tunnel_stack = {}
    end

    -- Add selected_choices if missing
    if not data.selected_choices then
        data.selected_choices = {}
    end

    -- Ensure variables is a table
    if type(data.variables) ~= "table" then
        data.variables = {}
    end

    return data, nil
end)

-- Migration from 0.8.0 to 0.9.0
SaveMigrator.register("0.8.0", "0.9.0", function(data)
    -- Add visited tracking if missing
    if not data.visited then
        data.visited = {}
    end

    -- Convert old passage_history to visited counts
    if data.passage_history and type(data.passage_history) == "table" then
        for _, passage_name in ipairs(data.passage_history) do
            if type(passage_name) == "string" then
                data.visited[passage_name] = (data.visited[passage_name] or 0) + 1
            end
        end
    end

    return data, nil
end)

return SaveMigrator
