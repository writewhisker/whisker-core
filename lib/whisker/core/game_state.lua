-- src/core/game_state.lua
-- Complete state management with undo/redo, inventory, and serialization
-- GAP-017: Integrated seeded random number generation

local Random = require("lib.whisker.core.random")

local GameState = {}
GameState.__index = GameState

-- Dependencies for DI pattern (none for GameState - it's a leaf module)
GameState._dependencies = {}

--- Create a new GameState instance via DI container
-- @param deps table|nil Dependencies from container (optional for GameState)
-- @return function Factory function that creates GameState instances
function GameState.create(deps)
  -- Return a factory function that creates game states
  return function(options)
    local game_state = GameState.new()
    if options and options.max_history then
      game_state.max_history = options.max_history
    end
    return game_state
  end
end

function GameState.new(deps)
  deps = deps or {}
    local instance = {
        -- Core state
        variables = {},           -- Story-scoped variables ($var)
        temp_variables = {},      -- Temporary variables (_var) - cleared on passage change
        current_passage = nil,
        visited_passages = {},
        choice_history = {},
        selected_choices = {},    -- WLS 1.0: Track selected once-only choices by ID

        -- WLS 1.0 Gap 3: Collection types
        lists = {},               -- LIST declarations: { name = { values = {...}, active = {...} } }
        arrays = {},              -- ARRAY declarations: { name = [...] }
        maps = {},                -- MAP declarations: { name = {...} }

        -- WLS 1.0 GAP-009: Tunnel stack for -> Target -> and <- navigation
        tunnel_stack = {},
        tunnel_stack_limit = 100,  -- Configurable depth limit

        -- WLS 1.0 GAP-017: Seeded random number generator
        random = Random.new(),
        random_seed = nil,  -- User-specified seed (stored for serialization)

        -- Undo system
        history_stack = {},
        max_history = 10,

        -- Metadata
        story_id = nil,
        start_time = nil,
        save_time = nil,
        version = "1.0.0"
    }

    setmetatable(instance, GameState)
    return instance
end

function GameState:initialize(story)
    self.story_id = story.metadata and story.metadata.uuid or story.metadata and story.metadata.ifid or nil
    self.start_time = os.time()
    self.variables = {}
    self.temp_variables = {}  -- WLS 1.0: Clear temp variables on init
    self.current_passage = nil
    self.visited_passages = {}
    self.choice_history = {}
    self.selected_choices = {}  -- WLS 1.0: Reset selected once-only choices
    self.history_stack = {}

    -- WLS 1.0 Gap 3: Reset collections
    self.lists = {}
    self.arrays = {}
    self.maps = {}

    -- WLS 1.0 GAP-009: Reset tunnel stack on init
    self.tunnel_stack = {}
    self.tunnel_stack_limit = self.tunnel_stack_limit or 100

    -- Initialize default variables from story
    if story.variables then
        for k, v in pairs(story.variables) do
            self.variables[k] = v
        end
    end

    -- WLS 1.0 Gap 3: Initialize LIST declarations
    if story.lists then
        for name, list_data in pairs(story.lists) do
            -- list_data = { values = {...}, active = {...} } or from parser
            local values = {}
            local active = {}
            if list_data.values then
                for _, v in ipairs(list_data.values) do
                    if type(v) == "table" then
                        -- Parser format: { value = "name", active = true/false }
                        table.insert(values, v.value)
                        if v.active then
                            active[v.value] = true
                        end
                    else
                        table.insert(values, v)
                    end
                end
            end
            self.lists[name] = { values = values, active = active }
        end
    end

    -- WLS 1.0 Gap 3: Initialize ARRAY declarations
    if story.arrays then
        for name, array_data in pairs(story.arrays) do
            local elements = {}
            if array_data.elements then
                for _, elem in ipairs(array_data.elements) do
                    if type(elem) == "table" and elem.value ~= nil then
                        -- Parser format: { index = n, value = expr }
                        local idx = elem.index or (#elements + 1)
                        elements[idx + 1] = elem.value  -- Lua 1-based, WLS 0-based
                    else
                        table.insert(elements, elem)
                    end
                end
            end
            self.arrays[name] = elements
        end
    end

    -- WLS 1.0 Gap 3: Initialize MAP declarations
    if story.maps then
        for name, map_data in pairs(story.maps) do
            local entries = {}
            if map_data.entries then
                for _, entry in ipairs(map_data.entries) do
                    if type(entry) == "table" and entry.key then
                        entries[entry.key] = entry.value
                    end
                end
            end
            self.maps[name] = entries
        end
    end
end

function GameState:set_current_passage(passage_id)
    -- Save current state to history before changing
    if self.current_passage then
        self:push_to_history()
    end

    -- WLS 1.0: Clear temporary variables on passage change
    self.temp_variables = {}

    -- Update current passage
    self.current_passage = passage_id

    -- Track visit
    if not self.visited_passages[passage_id] then
        self.visited_passages[passage_id] = 0
    end
    self.visited_passages[passage_id] = self.visited_passages[passage_id] + 1
end

function GameState:get_current_passage()
    return self.current_passage
end

function GameState:get_visit_count(passage_id)
    return self.visited_passages[passage_id] or 0
end

function GameState:has_visited(passage_id)
    return self.visited_passages[passage_id] ~= nil
end

function GameState:set(key, value)
    local old_value = self.variables[key]
    self.variables[key] = value
    return old_value
end

function GameState:get(key, default_value)
    local value = self.variables[key]
    if value == nil then
        return default_value
    end
    return value
end

-- WLS 1.0: Temporary variable methods (_var scope)

--- Set a temporary variable (cleared on passage change)
---@param key string Variable name (without _ prefix)
---@param value any The value to set
---@return any|nil old_value, string|nil error
function GameState:set_temp(key, value)
    -- WLS 1.0: Check for shadowing - temp cannot shadow story variable
    if self.variables[key] ~= nil then
        return nil, "Cannot shadow story variable $" .. key .. " with temporary variable _" .. key
    end
    local old_value = self.temp_variables[key]
    self.temp_variables[key] = value
    return old_value
end

--- Get a temporary variable
---@param key string Variable name (without _ prefix)
---@param default_value any Optional default value
---@return any
function GameState:get_temp(key, default_value)
    local value = self.temp_variables[key]
    if value == nil then
        return default_value
    end
    return value
end

--- Check if a temporary variable exists
---@param key string Variable name (without _ prefix)
---@return boolean
function GameState:has_temp(key)
    return self.temp_variables[key] ~= nil
end

--- Delete a temporary variable
---@param key string Variable name (without _ prefix)
---@return any old_value
function GameState:delete_temp(key)
    local old_value = self.temp_variables[key]
    self.temp_variables[key] = nil
    return old_value
end

--- Get all temporary variables
---@return table
function GameState:get_all_temp_variables()
    return self.temp_variables
end

-- ============================================================================
-- WLS 1.0 Gap 3: LIST Operations
-- ============================================================================

--- Get a list by name
---@param name string List name
---@return table|nil { values = {...}, active = {...} }
function GameState:get_list(name)
    return self.lists[name]
end

--- Check if a list exists
---@param name string List name
---@return boolean
function GameState:has_list(name)
    return self.lists[name] ~= nil
end

--- Get the possible values in a list
---@param name string List name
---@return table|nil Array of value names
function GameState:get_list_values(name)
    local list = self.lists[name]
    if list then
        return list.values
    end
    return nil
end

--- Get the active values in a list
---@param name string List name
---@return table Array of active value names
function GameState:get_list_active(name)
    local list = self.lists[name]
    if not list then return {} end
    local result = {}
    for value, is_active in pairs(list.active) do
        if is_active then
            table.insert(result, value)
        end
    end
    return result
end

--- Check if a value is active in a list
---@param list_name string List name
---@param value string Value to check
---@return boolean
function GameState:list_contains(list_name, value)
    local list = self.lists[list_name]
    if not list then return false end
    return list.active[value] == true
end

--- Add (activate) a value in a list
---@param list_name string List name
---@param value string Value to activate
---@return boolean success
function GameState:list_add(list_name, value)
    local list = self.lists[list_name]
    if not list then return false end
    -- Verify value is in the list's possible values
    local valid = false
    for _, v in ipairs(list.values) do
        if v == value then valid = true break end
    end
    if not valid then return false end
    list.active[value] = true
    return true
end

--- Remove (deactivate) a value from a list
---@param list_name string List name
---@param value string Value to deactivate
---@return boolean success
function GameState:list_remove(list_name, value)
    local list = self.lists[list_name]
    if not list then return false end
    list.active[value] = nil
    return true
end

--- Toggle a value in a list
---@param list_name string List name
---@param value string Value to toggle
---@return boolean new_state
function GameState:list_toggle(list_name, value)
    local list = self.lists[list_name]
    if not list then return false end
    if list.active[value] then
        list.active[value] = nil
        return false
    else
        list.active[value] = true
        return true
    end
end

--- Set the entire list state
---@param name string List name
---@param active_values table Array of active value names
function GameState:set_list_active(name, active_values)
    local list = self.lists[name]
    if not list then return end
    list.active = {}
    for _, v in ipairs(active_values) do
        list.active[v] = true
    end
end

--- Get count of active values in a list
---@param name string List name
---@return number
function GameState:list_count(name)
    local list = self.lists[name]
    if not list then return 0 end
    local count = 0
    for _, is_active in pairs(list.active) do
        if is_active then count = count + 1 end
    end
    return count
end

-- ============================================================================
-- WLS 1.0 Gap 3: ARRAY Operations
-- ============================================================================

--- Get an array by name
---@param name string Array name
---@return table|nil
function GameState:get_array(name)
    return self.arrays[name]
end

--- Check if an array exists
---@param name string Array name
---@return boolean
function GameState:has_array(name)
    return self.arrays[name] ~= nil
end

--- Get array element by index (0-based WLS index)
---@param name string Array name
---@param index number 0-based index
---@return any|nil
function GameState:array_get(name, index)
    local arr = self.arrays[name]
    if not arr then return nil end
    return arr[index + 1]  -- Convert 0-based to 1-based
end

--- Set array element by index (0-based WLS index)
---@param name string Array name
---@param index number 0-based index
---@param value any Value to set
---@return boolean success
function GameState:array_set(name, index, value)
    local arr = self.arrays[name]
    if not arr then return false end
    arr[index + 1] = value  -- Convert 0-based to 1-based
    return true
end

--- Get array length
---@param name string Array name
---@return number
function GameState:array_length(name)
    local arr = self.arrays[name]
    if not arr then return 0 end
    return #arr
end

--- Append value to array
---@param name string Array name
---@param value any Value to append
---@return number new_length
function GameState:array_push(name, value)
    local arr = self.arrays[name]
    if not arr then return 0 end
    table.insert(arr, value)
    return #arr
end

--- Remove and return last element
---@param name string Array name
---@return any|nil
function GameState:array_pop(name)
    local arr = self.arrays[name]
    if not arr or #arr == 0 then return nil end
    return table.remove(arr)
end

--- Insert value at index (0-based)
---@param name string Array name
---@param index number 0-based index
---@param value any Value to insert
function GameState:array_insert(name, index, value)
    local arr = self.arrays[name]
    if not arr then return end
    table.insert(arr, index + 1, value)
end

--- Remove value at index (0-based)
---@param name string Array name
---@param index number 0-based index
---@return any|nil removed value
function GameState:array_remove(name, index)
    local arr = self.arrays[name]
    if not arr then return nil end
    return table.remove(arr, index + 1)
end

--- Check if array contains value
---@param name string Array name
---@param value any Value to find
---@return boolean
function GameState:array_contains(name, value)
    local arr = self.arrays[name]
    if not arr then return false end
    for _, v in ipairs(arr) do
        if v == value then return true end
    end
    return false
end

--- Find index of value in array (returns 0-based, or -1 if not found)
---@param name string Array name
---@param value any Value to find
---@return number 0-based index or -1
function GameState:array_index_of(name, value)
    local arr = self.arrays[name]
    if not arr then return -1 end
    for i, v in ipairs(arr) do
        if v == value then return i - 1 end  -- Convert to 0-based
    end
    return -1
end

-- ============================================================================
-- WLS 1.0 Gap 3: MAP Operations
-- ============================================================================

--- Get a map by name
---@param name string Map name
---@return table|nil
function GameState:get_map(name)
    return self.maps[name]
end

--- Check if a map exists
---@param name string Map name
---@return boolean
function GameState:has_map(name)
    return self.maps[name] ~= nil
end

--- Get map value by key
---@param name string Map name
---@param key string Key
---@return any|nil
function GameState:map_get(name, key)
    local map = self.maps[name]
    if not map then return nil end
    return map[key]
end

--- Set map value by key
---@param name string Map name
---@param key string Key
---@param value any Value
function GameState:map_set(name, key, value)
    local map = self.maps[name]
    if not map then return end
    map[key] = value
end

--- Check if map has key
---@param name string Map name
---@param key string Key
---@return boolean
function GameState:map_has(name, key)
    local map = self.maps[name]
    if not map then return false end
    return map[key] ~= nil
end

--- Delete key from map
---@param name string Map name
---@param key string Key to delete
---@return any|nil old_value
function GameState:map_delete(name, key)
    local map = self.maps[name]
    if not map then return nil end
    local old = map[key]
    map[key] = nil
    return old
end

--- Get all keys in map
---@param name string Map name
---@return table Array of keys
function GameState:map_keys(name)
    local map = self.maps[name]
    if not map then return {} end
    local keys = {}
    for k, _ in pairs(map) do
        table.insert(keys, k)
    end
    return keys
end

--- Get all values in map
---@param name string Map name
---@return table Array of values
function GameState:map_values(name)
    local map = self.maps[name]
    if not map then return {} end
    local values = {}
    for _, v in pairs(map) do
        table.insert(values, v)
    end
    return values
end

--- Get count of entries in map
---@param name string Map name
---@return number
function GameState:map_size(name)
    local map = self.maps[name]
    if not map then return 0 end
    local count = 0
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

--- Get all collections (for debugging/serialization)
---@return table { lists = {...}, arrays = {...}, maps = {...} }
function GameState:get_all_collections()
    return {
        lists = self.lists,
        arrays = self.arrays,
        maps = self.maps
    }
end

-- WLS 1.0: Once-only choice tracking

--- Mark a choice as selected (for once-only choices)
---@param choice_id string The choice ID
function GameState:mark_choice_selected(choice_id)
    self.selected_choices[choice_id] = true
end

--- Check if a choice has been selected
---@param choice_id string The choice ID
---@return boolean
function GameState:is_choice_selected(choice_id)
    return self.selected_choices[choice_id] == true
end

--- Clear the selected state for a choice
---@param choice_id string The choice ID
function GameState:clear_choice_selected(choice_id)
    self.selected_choices[choice_id] = nil
end

--- Get all selected choice IDs
---@return table
function GameState:get_all_selected_choices()
    local ids = {}
    for id, _ in pairs(self.selected_choices) do
        table.insert(ids, id)
    end
    return ids
end

--- Clear all selected choices (on story restart)
function GameState:clear_all_selected_choices()
    self.selected_choices = {}
end

-- ============================================================================
-- WLS 1.0 GAP-009: Tunnel Stack Operations
-- ============================================================================

--- Push a return address onto the tunnel stack
---@param passage_id string The passage to return to
---@param position number|nil Optional position within passage
---@return boolean success
---@return string|nil error
function GameState:tunnel_push(passage_id, position)
    -- Check stack limit
    if #self.tunnel_stack >= self.tunnel_stack_limit then
        return false, string.format(
            "Tunnel stack overflow: maximum depth %d exceeded",
            self.tunnel_stack_limit
        )
    end

    table.insert(self.tunnel_stack, {
        passage_id = passage_id,
        position = position or 0,
        timestamp = os.time()
    })

    return true
end

--- Pop a return address from the tunnel stack
---@return table|nil return_info { passage_id, position }
---@return string|nil error
function GameState:tunnel_pop()
    if #self.tunnel_stack == 0 then
        return nil, "Tunnel stack underflow: no return address available"
    end

    return table.remove(self.tunnel_stack)
end

--- Peek at the top of the tunnel stack without popping
---@return table|nil return_info
function GameState:tunnel_peek()
    if #self.tunnel_stack == 0 then
        return nil
    end
    return self.tunnel_stack[#self.tunnel_stack]
end

--- Get current tunnel stack depth
---@return number
function GameState:tunnel_depth()
    return #self.tunnel_stack
end

--- Check if tunnel stack is empty
---@return boolean
function GameState:tunnel_empty()
    return #self.tunnel_stack == 0
end

--- Clear the tunnel stack (for restart)
function GameState:tunnel_clear()
    self.tunnel_stack = {}
end

--- Set the tunnel stack limit
---@param limit number
function GameState:set_tunnel_limit(limit)
    self.tunnel_stack_limit = limit
end

--- Get the full tunnel stack (for debugging/serialization)
---@return table
function GameState:get_tunnel_stack()
    return self.tunnel_stack
end

-- ============================================================================
-- WLS 1.0 GAP-017: Seeded Random Number Generation
-- ============================================================================

--- Initialize random seed
---@param seed number|string|nil Custom seed, or nil for auto
---@param story_ifid string|nil Story IFID for default seed
function GameState:init_random(seed, story_ifid)
    if seed then
        self.random_seed = seed
        self.random:set_seed(seed)
    elseif story_ifid then
        -- Default: hash of IFID + start time
        local default_seed = story_ifid .. "_" .. tostring(self.start_time or os.time())
        self.random_seed = default_seed
        self.random:set_seed(default_seed)
    else
        -- Fallback: current time
        self.random:set_seed(os.time())
    end
end

--- Get random number (0-1)
---@return number
function GameState:random_next()
    return self.random:next()
end

--- Get random integer in range [min, max]
---@param min number
---@param max number
---@return number
function GameState:random_int(min, max)
    return self.random:int(min, max)
end

--- Get random float in range [min, max)
---@param min number
---@param max number
---@return number
function GameState:random_float(min, max)
    return self.random:float(min, max)
end

--- Pick random element from list
---@param list table
---@return any
function GameState:random_pick(list)
    return self.random:pick(list)
end

--- Shuffle array in place
---@param array table
---@return table same array, shuffled
function GameState:random_shuffle(array)
    return self.random:shuffle(array)
end

--- Roll dice (e.g., 2d6)
---@param count number Number of dice
---@param sides number Number of sides per die
---@return number Total
function GameState:random_dice(count, sides)
    return self.random:dice(count, sides)
end

--- Get random boolean with given probability
---@param probability number Probability of true (0-1), default 0.5
---@return boolean
function GameState:random_bool(probability)
    return self.random:bool(probability)
end

--- Get the random generator instance (for advanced usage)
---@return Random
function GameState:get_random()
    return self.random
end

--- Get the random state for serialization
---@return table
function GameState:get_random_state()
    return {
        seed = self.random_seed,
        state = self.random:get_state()
    }
end

--- Restore random state from serialization
---@param data table
function GameState:set_random_state(data)
    if data then
        self.random_seed = data.seed
        if data.state then
            self.random:set_state(data.state)
        end
    end
end

function GameState:increment(key, amount)
    amount = amount or 1
    local current = self:get(key, 0)
    if type(current) == "number" then
        self:set(key, current + amount)
        return current + amount
    end
    return nil
end

function GameState:decrement(key, amount)
    amount = amount or 1
    return self:increment(key, -amount)
end

function GameState:delete(key)
    local old_value = self.variables[key]
    self.variables[key] = nil
    return old_value
end

function GameState:has(key)
    return self.variables[key] ~= nil
end

function GameState:get_all_variables()
    return self.variables
end

-- Aliases for compatibility with debugger
function GameState:get_variable(key, default_value)
    return self:get(key, default_value)
end

function GameState:set_variable(key, value)
    return self:set(key, value)
end

function GameState:push_to_history()
    -- Create snapshot of current state
    local snapshot = {
        current_passage = self.current_passage,
        variables = self:clone_table(self.variables),
        visited_passages = self:clone_table(self.visited_passages),
        -- WLS 1.0 Gap 3: Include collections in snapshot
        lists = self:clone_table(self.lists),
        arrays = self:clone_table(self.arrays),
        maps = self:clone_table(self.maps),
        -- WLS 1.0 GAP-009: Include tunnel stack in snapshot
        tunnel_stack = self:clone_table(self.tunnel_stack),
        timestamp = os.time()
    }

    table.insert(self.history_stack, snapshot)

    -- Trim history if too large
    while #self.history_stack > self.max_history do
        table.remove(self.history_stack, 1)
    end
end

function GameState:can_undo()
    return #self.history_stack > 0
end

function GameState:undo()
    if not self:can_undo() then
        return nil
    end

    local snapshot = table.remove(self.history_stack)

    -- Restore state from snapshot
    self.current_passage = snapshot.current_passage
    self.variables = self:clone_table(snapshot.variables)
    self.visited_passages = self:clone_table(snapshot.visited_passages)
    -- WLS 1.0 Gap 3: Restore collections from snapshot
    self.lists = self:clone_table(snapshot.lists or {})
    self.arrays = self:clone_table(snapshot.arrays or {})
    self.maps = self:clone_table(snapshot.maps or {})
    -- WLS 1.0 GAP-009: Restore tunnel stack from snapshot
    self.tunnel_stack = self:clone_table(snapshot.tunnel_stack or {})

    return snapshot
end

function GameState:clone_table(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = self:clone_table(v)
        else
            copy[k] = v
        end
    end

    return copy
end

function GameState:serialize()
    local data = {
        version = self.version,
        story_id = self.story_id,
        start_time = self.start_time,
        save_time = os.time(),
        current_passage = self.current_passage,
        variables = self.variables,
        visited_passages = self.visited_passages,
        choice_history = self.choice_history,
        selected_choices = self.selected_choices,  -- WLS 1.0: Persist selected once-only choices
        -- WLS 1.0 Gap 3: Persist collections
        lists = self.lists,
        arrays = self.arrays,
        maps = self.maps,
        -- WLS 1.0 GAP-013: Persist tunnel stack for save state
        tunnel_stack = self:serialize_tunnel_stack(),
        tunnel_stack_limit = self.tunnel_stack_limit,
        -- WLS 1.0 GAP-017: Persist random state
        random_state = self:get_random_state()
    }

    return data
end

--- Serialize tunnel stack for save state (GAP-013)
---@return table
function GameState:serialize_tunnel_stack()
    local stack = {}
    for _, entry in ipairs(self.tunnel_stack) do
        table.insert(stack, {
            passage_id = entry.passage_id,
            position = entry.position or 0
            -- Omit timestamp to reduce save size
        })
    end
    return stack
end

--- GAP-068: Deserialize with migration support
function GameState:deserialize(data)
    -- Try to load SaveMigrator for version migration
    local success_load, SaveMigrator = pcall(require, "lib.whisker.core.save_migrator")

    if success_load and SaveMigrator then
        local migrator = SaveMigrator.new()

        -- Migrate if needed
        if migrator:needs_migration(data) then
            local migrated, err = migrator:migrate(data)
            if err then
                return false, "Migration failed: " .. err
            end
            data = migrated
        end

        -- Validate
        local valid, errors = migrator:validate(data)
        if not valid then
            return false, "Invalid save data: " .. table.concat(errors, "; ")
        end
    else
        -- Fallback: simple version check if SaveMigrator not available
        if not data or data.version ~= self.version then
            return false, "Incompatible save data version"
        end
    end

    self.version = data.version or self.version
    self.story_id = data.story_id
    self.start_time = data.start_time
    self.save_time = data.save_time
    self.current_passage = data.current_passage
    self.variables = data.variables or {}
    self.temp_variables = {}  -- WLS 1.0: Temp variables are NOT persisted
    self.visited_passages = data.visited_passages or {}
    self.choice_history = data.choice_history or {}
    self.selected_choices = data.selected_choices or {}  -- WLS 1.0: Restore selected choices
    self.history_stack = {}
    -- WLS 1.0 Gap 3: Restore collections
    self.lists = data.lists or {}
    self.arrays = data.arrays or {}
    self.maps = data.maps or {}
    -- WLS 1.0 GAP-013: Restore tunnel stack from save state
    self.tunnel_stack = self:deserialize_tunnel_stack(data.tunnel_stack)
    self.tunnel_stack_limit = data.tunnel_stack_limit or 100
    -- WLS 1.0 GAP-017: Restore random state
    if data.random_state then
        self:set_random_state(data.random_state)
    end

    return true
end

--- Deserialize tunnel stack from save state (GAP-013)
---@param stack_data table
---@return table
function GameState:deserialize_tunnel_stack(stack_data)
    if not stack_data then
        return {}
    end

    local stack = {}
    for _, entry in ipairs(stack_data) do
        table.insert(stack, {
            passage_id = entry.passage_id,
            position = entry.position or 0,
            timestamp = os.time()  -- Reset timestamp on load
        })
    end
    return stack
end

--- Validate tunnel stack after loading (GAP-013)
---@param story table The story object
---@return boolean valid
---@return table|nil errors
function GameState:validate_tunnel_stack(story)
    local errors = {}

    for i, entry in ipairs(self.tunnel_stack) do
        if not entry.passage_id then
            table.insert(errors, string.format(
                "Tunnel stack entry %d missing passage_id",
                i
            ))
        elseif story and story.get_passage then
            local passage = story:get_passage(entry.passage_id)
            if not passage then
                table.insert(errors, string.format(
                    "Tunnel stack entry %d references unknown passage: %s",
                    i, entry.passage_id
                ))
            end
        end
    end

    return #errors == 0, errors
end

function GameState:reset()
    self.variables = {}
    self.temp_variables = {}  -- WLS 1.0: Clear temp variables on reset
    self.current_passage = nil
    self.visited_passages = {}
    self.choice_history = {}
    self.selected_choices = {}  -- WLS 1.0: Clear selected choices on reset
    self.history_stack = {}
    self.start_time = os.time()
    -- WLS 1.0 Gap 3: Clear collections on reset
    self.lists = {}
    self.arrays = {}
    self.maps = {}
    -- WLS 1.0 GAP-009: Clear tunnel stack on reset
    self.tunnel_stack = {}
end

return GameState
