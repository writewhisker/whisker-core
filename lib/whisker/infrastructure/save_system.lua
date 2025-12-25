-- src/system/save_system.lua
-- Save and load functionality for game state

local SaveSystem = {}
SaveSystem._dependencies = {}
SaveSystem.__index = SaveSystem

--- Create a new SaveSystem instance
-- @param config table Configuration options
-- @param dependencies table Dependencies (json_codec, story_factory, game_state_factory, file_utils)
function SaveSystem.new(config, dependencies)
    config = config or {}
    dependencies = dependencies or {}

    local instance = {
        config = config,
        save_dir = config.save_dir or "saves",
        max_save_slots = config.max_save_slots or 5,
        auto_save_slot = "autosave",
        quick_save_slot = "quicksave",
        -- Dependencies
        _json_codec = dependencies.json_codec,
        _story_factory = dependencies.story_factory,
        _game_state_factory = dependencies.game_state_factory,
        _file_utils = dependencies.file_utils,
    }

    setmetatable(instance, SaveSystem)
    instance:_init_dependencies()
    return instance
end

--- Initialize dependencies (lazy load if not injected)
function SaveSystem:_init_dependencies()
    if not self._json_codec then
        local ok, json = pcall(require, "whisker.utils.json")
        if ok then self._json_codec = json end
    end
    if not self._story_factory then
        local ok, StoryFactory = pcall(require, "whisker.core.factories.story_factory")
        if ok then self._story_factory = StoryFactory.new() end
    end
    if not self._game_state_factory then
        local ok, GameStateFactory = pcall(require, "whisker.core.factories.game_state_factory")
        if ok then self._game_state_factory = GameStateFactory.new() end
    end
    if not self._file_utils then
        local ok, file_utils = pcall(require, "whisker.utils.file_utils")
        if ok then self._file_utils = file_utils end
    end
end

function SaveSystem:save_game(slot_name, game_state, story_data)
    if not slot_name or slot_name == "" then
        return false, "Slot name is required"
    end

    if not game_state then
        return false, "Game state is required"
    end

    -- Create save data
    local save_data = {
        metadata = {
            slot_name = slot_name,
            timestamp = os.time(),
            date = os.date("%Y-%m-%d %H:%M:%S"),
            version = "1.0.0"
        },

        game_state = self:serialize_game_state(game_state),

        story_info = story_data and {
            id = story_data.id,
            name = story_data.name,
            version = story_data.version
        } or {}
    }

    -- Convert to JSON
    local json_data = self._json_codec.encode(save_data)

    -- Write to file (platform-specific implementation)
    local success, err = self:write_save_file(slot_name, json_data)

    if not success then
        return false, err
    end

    return true
end

function SaveSystem:load_game(slot_name)
    if not slot_name or slot_name == "" then
        return nil, "Slot name is required"
    end

    -- Read save file
    local json_data, err = self:read_save_file(slot_name)

    if not json_data then
        return nil, err
    end

    -- Parse JSON
    local save_data = self._json_codec.decode(json_data)

    if not save_data then
        return nil, "Failed to parse save data"
    end

    -- Deserialize game state (with metatable restoration)
    local game_state = self:deserialize_game_state(save_data.game_state)

    -- Restore story data if present (with metatable restoration)
    local story = nil
    if save_data.story_data and self._story_factory then
        story = self._story_factory:from_table(save_data.story_data)
    end

    return {
        game_state = game_state,
        story = story,
        metadata = save_data.metadata,
        story_info = save_data.story_info
    }
end

function SaveSystem:serialize_game_state(game_state)
    return {
        current_passage = game_state.current_passage,
        variables = game_state.variables,
        visited_passages = game_state.visited_passages,
        choice_history = game_state.choice_history,
        history_stack = game_state.history_stack,
        start_time = game_state.start_time,
        version = game_state.version
    }
end

function SaveSystem:deserialize_game_state(data)
    local game_state
    if self._game_state_factory then
        game_state = self._game_state_factory:create()
    else
        -- Fallback if factory not available
        local GameState = require("whisker.core.game_state")
        game_state = GameState.new()
    end

    game_state.current_passage = data.current_passage
    game_state.variables = data.variables or {}
    game_state.visited_passages = data.visited_passages or {}
    game_state.choice_history = data.choice_history or {}
    game_state.history_stack = data.history_stack or {}
    game_state.start_time = data.start_time
    game_state.version = data.version or "1.0.0"

    return game_state
end

function SaveSystem:list_saves()
    -- Platform-specific implementation
    local saves = {}

    for i = 1, self.max_save_slots do
        local slot_name = "slot_" .. i
        local metadata = self:get_save_metadata(slot_name)

        if metadata then
            table.insert(saves, metadata)
        end
    end

    -- Check auto-save
    local auto_metadata = self:get_save_metadata(self.auto_save_slot)
    if auto_metadata then
        table.insert(saves, auto_metadata)
    end

    -- Check quick-save
    local quick_metadata = self:get_save_metadata(self.quick_save_slot)
    if quick_metadata then
        table.insert(saves, quick_metadata)
    end

    return saves
end

function SaveSystem:get_save_metadata(slot_name)
    local json_data, err = self:read_save_file(slot_name)

    if not json_data then
        return nil
    end

    local save_data = self._json_codec.decode(json_data)

    if save_data and save_data.metadata then
        return save_data.metadata
    end

    return nil
end

function SaveSystem:delete_save(slot_name)
    if not slot_name or slot_name == "" then
        return false, "Slot name is required"
    end

    return self:delete_save_file(slot_name)
end

function SaveSystem:auto_save(game_state, story_data)
    return self:save_game(self.auto_save_slot, game_state, story_data)
end

function SaveSystem:quick_save(game_state, story_data)
    return self:save_game(self.quick_save_slot, game_state, story_data)
end

function SaveSystem:quick_load()
    return self:load_game(self.quick_save_slot)
end

-- Platform-specific file operations
function SaveSystem:write_save_file(slot_name, data)
    local filename = self.save_dir .. "/" .. slot_name .. ".sav"
    return self._file_utils.write_file(filename, data)
end

function SaveSystem:read_save_file(slot_name)
    local filename = self.save_dir .. "/" .. slot_name .. ".sav"
    return self._file_utils.read_file(filename)
end

function SaveSystem:delete_save_file(slot_name)
    local filename = self.save_dir .. "/" .. slot_name .. ".sav"
    return self._file_utils.delete_file(filename)
end

return SaveSystem
