-- whisker/core/story.lua
-- Story data structure and management
-- Container for passages, variables, and story metadata

local Story = {}
Story.__index = Story

-- Module metadata for container auto-registration
Story._whisker = {
  name = "Story",
  version = "2.0.0",
  description = "Story data structure and container for passages",
  depends = {},
  capability = "core.story"
}

-- Helper function: Detect if variables are in typed format (v2.0)
local function is_typed_variable_format(var_data)
    if type(var_data) ~= "table" then
        return false
    end
    -- Check if it has 'type' and 'default' fields
    return var_data.type ~= nil and var_data.default ~= nil
end

-- Helper function: Convert v1.0 variables to v2.0 typed format
local function migrate_variables_to_typed(variables)
    local typed_vars = {}
    for name, value in pairs(variables) do
        if is_typed_variable_format(value) then
            -- Already typed, keep as-is
            typed_vars[name] = value
        else
            -- Convert to typed format
            typed_vars[name] = {
                type = type(value),
                default = value
            }
        end
    end
    return typed_vars
end

-- Helper function: Convert v2.0 typed variables to v1.0 simple format
local function variables_to_simple(variables)
    local simple_vars = {}
    for name, value in pairs(variables) do
        if is_typed_variable_format(value) then
            -- Extract default value
            simple_vars[name] = value.default
        else
            -- Already simple, keep as-is
            simple_vars[name] = value
        end
    end
    return simple_vars
end

function Story.new(options)
    options = options or {}
    local instance = {
        metadata = {
            uuid = options.uuid or nil,
            name = options.title or options.name or "",
            author = options.author or "",
            version = options.version or "1.0.0",
            created = options.created or nil,
            modified = options.modified or nil,
            ifid = options.ifid or nil,
            format = options.format or "whisker",
            format_version = options.format_version or "1.0.0"
        },
        variables = options.variables or {},
        passages = options.passages or {},
        start_passage = options.start_passage or nil,
        stylesheets = options.stylesheets or {},
        scripts = options.scripts or {},
        assets = options.assets or {},
        tags = options.tags or {},  -- Story-level tags
        settings = options.settings or {},  -- Story-level settings
        _event_emitter = nil  -- Optional event emitter for structural changes
    }

    setmetatable(instance, Story)
    return instance
end

-- Set an event emitter for structural change notifications
-- @param emitter table|nil - Object with emit(event_name, data) method, or nil to disable
function Story:set_event_emitter(emitter)
    self._event_emitter = emitter
end

-- Get the current event emitter
function Story:get_event_emitter()
    return self._event_emitter
end

-- Internal: emit an event if emitter is set
local function emit_event(self, event_name, data)
    if self._event_emitter and self._event_emitter.emit then
        self._event_emitter:emit(event_name, data)
    end
end

function Story:set_metadata(key, value)
    self.metadata[key] = value
end

function Story:get_metadata(key)
    return self.metadata[key]
end

function Story:add_passage(passage)
    if not passage or not passage.id then
        error("Invalid passage: missing id")
    end

    local is_new = self.passages[passage.id] == nil
    self.passages[passage.id] = passage

    emit_event(self, "story:passage_added", {
        story = self,
        passage = passage,
        is_new = is_new
    })
end

function Story:get_passage(passage_id)
    return self.passages[passage_id]
end

function Story:remove_passage(passage_id)
    local passage = self.passages[passage_id]
    if passage then
        self.passages[passage_id] = nil
        emit_event(self, "story:passage_removed", {
            story = self,
            passage_id = passage_id,
            passage = passage
        })
    end
end

function Story:get_all_passages()
    local list = {}
    for id, passage in pairs(self.passages) do
        table.insert(list, passage)
    end
    return list
end

function Story:set_start_passage(passage_id)
    if not self.passages[passage_id] then
        error("Cannot set start passage: passage '" .. passage_id .. "' does not exist")
    end
    local old_start = self.start_passage
    self.start_passage = passage_id

    emit_event(self, "story:start_changed", {
        story = self,
        old_start = old_start,
        new_start = passage_id
    })
end

function Story:get_start_passage()
    if self.start_passage then
        return self.start_passage
    end
    -- Return the first passage if no start passage set
    if self.passages then
        for id, _ in pairs(self.passages) do
            return id
        end
    end
    return nil
end

function Story:set_variable(key, value)
    local old_value = self.variables[key]
    self.variables[key] = value

    emit_event(self, "story:variable_changed", {
        story = self,
        key = key,
        old_value = old_value,
        new_value = value
    })
end

function Story:get_variable(key)
    return self.variables[key]
end

-- NEW: Get variable value (handles both v1.0 and v2.0 formats)
function Story:get_variable_value(key)
    local var = self.variables[key]
    if is_typed_variable_format(var) then
        return var.default
    else
        return var
    end
end

-- NEW: Set variable in typed format (v2.0)
function Story:set_typed_variable(key, var_type, default_value)
    self.variables[key] = {
        type = var_type,
        default = default_value
    }
end

-- NEW: Migrate variables to typed format (v2.0)
function Story:migrate_variables_to_typed()
    self.variables = migrate_variables_to_typed(self.variables)
end

-- NEW: Convert variables to simple format (v1.0)
function Story:variables_to_simple()
    return variables_to_simple(self.variables)
end

function Story:add_stylesheet(css_code)
    table.insert(self.stylesheets, css_code)
end

function Story:add_script(script_code)
    table.insert(self.scripts, script_code)
end

-- Asset management methods
function Story:add_asset(asset)
    if not asset or not asset.id then
        error("Invalid asset: missing id")
    end
    self.assets[asset.id] = asset
end

function Story:get_asset(asset_id)
    return self.assets[asset_id]
end

function Story:remove_asset(asset_id)
    self.assets[asset_id] = nil
end

function Story:list_assets()
    local list = {}
    for id, asset in pairs(self.assets) do
        table.insert(list, asset)
    end
    return list
end

function Story:has_asset(asset_id)
    return self.assets[asset_id] ~= nil
end

function Story:get_asset_references(asset_id)
    local references = {}
    local pattern = "asset://" .. asset_id

    -- Search all passages for references
    for id, passage in pairs(self.passages) do
        -- Check passage content
        if passage.content and string.find(passage.content, pattern, 1, true) then
            table.insert(references, {
                type = "passage_content",
                passage_id = id,
                passage_name = passage.name
            })
        end

        -- Check on_enter_script
        if passage.on_enter_script and string.find(passage.on_enter_script, pattern, 1, true) then
            table.insert(references, {
                type = "on_enter_script",
                passage_id = id,
                passage_name = passage.name
            })
        end

        -- Check on_exit_script
        if passage.on_exit_script and string.find(passage.on_exit_script, pattern, 1, true) then
            table.insert(references, {
                type = "on_exit_script",
                passage_id = id,
                passage_name = passage.name
            })
        end
    end

    return references
end

-- Story-level tag management methods
function Story:add_tag(tag)
    if not tag or tag == "" then
        error("Invalid tag: tag cannot be empty")
    end
    -- Use tag as both key and value for easy lookup
    self.tags[tag] = true
end

function Story:remove_tag(tag)
    self.tags[tag] = nil
end

function Story:has_tag(tag)
    return self.tags[tag] ~= nil
end

function Story:get_all_tags()
    local tag_list = {}
    for tag, _ in pairs(self.tags) do
        table.insert(tag_list, tag)
    end
    -- Sort for consistent ordering
    table.sort(tag_list)
    return tag_list
end

function Story:clear_tags()
    self.tags = {}
end

-- Story-level settings management methods
function Story:set_setting(key, value)
    if not key or key == "" then
        error("Invalid setting key: key cannot be empty")
    end
    self.settings[key] = value
end

function Story:get_setting(key, default)
    local value = self.settings[key]
    if value ~= nil then
        return value
    end
    return default
end

function Story:has_setting(key)
    return self.settings[key] ~= nil
end

function Story:delete_setting(key)
    if self.settings[key] ~= nil then
        self.settings[key] = nil
        return true
    end
    return false
end

function Story:get_all_settings()
    local copy = {}
    for k, v in pairs(self.settings) do
        copy[k] = v
    end
    return copy
end

function Story:clear_settings()
    self.settings = {}
end

-- Variable usage tracking
function Story:get_variable_usage(variable_name)
    local usage = {}

    -- Search all passages for variable references
    for id, passage in pairs(self.passages) do
        local found_in_passage = false
        local locations = {}

        -- Check passage content
        if passage.content and string.find(passage.content, variable_name, 1, true) then
            table.insert(locations, "content")
            found_in_passage = true
        end

        -- Check on_enter_script
        if passage.on_enter_script and string.find(passage.on_enter_script, variable_name, 1, true) then
            table.insert(locations, "on_enter_script")
            found_in_passage = true
        end

        -- Check on_exit_script
        if passage.on_exit_script and string.find(passage.on_exit_script, variable_name, 1, true) then
            table.insert(locations, "on_exit_script")
            found_in_passage = true
        end

        -- Check choices
        for _, choice in ipairs(passage.choices) do
            if choice.condition and string.find(choice.condition, variable_name, 1, true) then
                table.insert(locations, "choice_condition")
                found_in_passage = true
            end
            if choice.action and string.find(choice.action, variable_name, 1, true) then
                table.insert(locations, "choice_action")
                found_in_passage = true
            end
        end

        if found_in_passage then
            table.insert(usage, {
                passage_id = id,
                passage_name = passage.name,
                locations = locations
            })
        end
    end

    return usage
end

function Story:get_all_variable_usage()
    local usage_map = {}

    for variable_name, _ in pairs(self.variables) do
        usage_map[variable_name] = self:get_variable_usage(variable_name)
    end

    return usage_map
end

function Story:get_unused_variables()
    local unused = {}

    for variable_name, _ in pairs(self.variables) do
        local usage = self:get_variable_usage(variable_name)
        if #usage == 0 then
            table.insert(unused, variable_name)
        end
    end

    -- Sort for consistent ordering
    table.sort(unused)
    return unused
end

function Story:validate()
    -- Check required metadata
    if not self.metadata.name or self.metadata.name == "" then
        return false, "Story name is required"
    end

    -- Check start passage
    if not self.start_passage then
        return false, "Start passage must be set"
    end

    if not self.passages[self.start_passage] then
        return false, "Start passage does not exist"
    end

    -- Check that all passages are valid
    for id, passage in pairs(self.passages) do
        local valid, err = passage:validate()
        if not valid then
            return false, "Passage '" .. id .. "': " .. err
        end
    end

    return true
end

function Story:serialize()
    return {
        metadata = self.metadata,
        variables = self.variables,
        passages = self.passages,
        start_passage = self.start_passage,
        stylesheets = self.stylesheets,
        scripts = self.scripts,
        assets = self.assets,
        tags = self.tags,
        settings = self.settings
    }
end

-- Deserialization - restores from plain table
-- @param data table - Plain data table
-- @param passage_restorer function|nil - Optional function to restore passage metatables
function Story:deserialize(data, passage_restorer)
    self.metadata = data.metadata or self.metadata
    self.variables = data.variables or {}
    self.passages = data.passages or {}
    self.start_passage = data.start_passage
    self.stylesheets = data.stylesheets or {}
    self.scripts = data.scripts or {}
    self.assets = data.assets or {}
    self.tags = data.tags or {}
    self.settings = data.settings or {}

    -- Restore metatables for passage objects if needed
    if self.passages and passage_restorer then
        for id, passage in pairs(self.passages) do
            if type(passage) == "table" and not getmetatable(passage) then
                self.passages[id] = passage_restorer(passage)
            end
        end
    end
end

-- Static method to restore metatable to a table
-- @param data table - Plain data table
-- @param passage_restorer function|nil - Optional function to restore passage metatables
function Story.restore_metatable(data, passage_restorer)
    if not data or type(data) ~= "table" then
        return nil
    end

    -- If already has Story metatable, return as-is
    if getmetatable(data) == Story then
        return data
    end

    -- Set the Story metatable
    setmetatable(data, Story)

    -- Restore metatables for nested objects (passages)
    if data.passages and passage_restorer then
        for id, passage in pairs(data.passages) do
            if type(passage) == "table" and not getmetatable(passage) then
                data.passages[id] = passage_restorer(passage)
            end
        end
    end

    return data
end

-- Static method to create from plain table (useful for deserialization)
-- @param data table - Plain data table
-- @param passage_restorer function|nil - Optional function to restore passage metatables
function Story.from_table(data, passage_restorer)
    if not data then
        return nil
    end

    -- Create a new instance
    local instance = Story.new({
        uuid = data.metadata and data.metadata.uuid,
        title = data.metadata and data.metadata.name,
        author = data.metadata and data.metadata.author,
        version = data.metadata and data.metadata.version,
        created = data.metadata and data.metadata.created,
        modified = data.metadata and data.metadata.modified,
        ifid = data.metadata and data.metadata.ifid,
        format = data.metadata and data.metadata.format,
        format_version = data.metadata and data.metadata.format_version
    })

    -- Copy over the rest of the data
    instance.variables = data.variables or {}
    instance.start_passage = data.start_passage
    instance.stylesheets = data.stylesheets or {}
    instance.scripts = data.scripts or {}
    instance.assets = data.assets or {}
    instance.tags = data.tags or {}
    instance.settings = data.settings or {}

    -- Restore passages with proper metatables
    if data.passages and passage_restorer then
        for id, passage_data in pairs(data.passages) do
            if type(passage_data) == "table" then
                instance.passages[id] = passage_restorer(passage_data)
            end
        end
    elseif data.passages then
        -- Just copy passages without restoration
        for id, passage_data in pairs(data.passages) do
            instance.passages[id] = passage_data
        end
    end

    return instance
end

return Story
