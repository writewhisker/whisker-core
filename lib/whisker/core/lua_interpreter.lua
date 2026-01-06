-- src/runtime/interpreter.lua
-- Secure Lua sandbox with instruction counting

local compat = require("whisker.compat")

local LuaInterpreter = {}
LuaInterpreter.__index = LuaInterpreter

-- Dependencies for DI pattern (none for LuaInterpreter - it's a leaf module)
LuaInterpreter._dependencies = {}

--- Create a new LuaInterpreter instance via DI container
-- @param deps table|nil Dependencies from container (optional for LuaInterpreter)
-- @return function Factory function that creates LuaInterpreter instances
function LuaInterpreter.create(deps)
  -- Return a factory function that creates interpreters
  return function(config)
    return LuaInterpreter.new(config)
  end
end

function LuaInterpreter.new(config)
    config = config or {}
    local instance = {
        config = config,
        sandbox_env = nil,
        instruction_count = 0,
        max_instructions = config.max_instructions or 10000,
        start_time = 0,
        timeout = config.timeout or 5000 -- milliseconds
    }

    setmetatable(instance, LuaInterpreter)
    instance:create_sandbox()
    return instance
end

function LuaInterpreter:create_sandbox()
    -- Start with empty environment
    self.sandbox_env = {}

    -- Add safe global functions
    self.sandbox_env._G = self.sandbox_env
    self.sandbox_env._VERSION = _VERSION

    -- Safe basic functions
    self.sandbox_env.assert = assert
    self.sandbox_env.error = error
    self.sandbox_env.ipairs = ipairs
    self.sandbox_env.next = next
    self.sandbox_env.pairs = pairs
    self.sandbox_env.pcall = pcall
    self.sandbox_env.select = select
    self.sandbox_env.tonumber = tonumber
    self.sandbox_env.tostring = tostring
    self.sandbox_env.type = type
    self.sandbox_env.unpack = compat.unpack

    -- Safe string library
    self.sandbox_env.string = {
        byte = string.byte,
        char = string.char,
        find = string.find,
        format = string.format,
        gmatch = string.gmatch,
        gsub = string.gsub,
        len = string.len,
        lower = string.lower,
        match = string.match,
        rep = function(s, n)
            if n > 1000 then error("String repetition limit exceeded") end
            return string.rep(s, n)
        end,
        reverse = string.reverse,
        sub = string.sub,
        upper = string.upper
    }

    -- Safe table library
    self.sandbox_env.table = {
        concat = table.concat,
        insert = table.insert,
        remove = table.remove,
        sort = table.sort
    }

    -- Safe math library
    self.sandbox_env.math = {
        abs = math.abs,
        acos = math.acos,
        asin = math.asin,
        atan = math.atan,
        ceil = math.ceil,
        cos = math.cos,
        deg = math.deg,
        exp = math.exp,
        floor = math.floor,
        huge = math.huge,
        log = math.log,
        max = math.max,
        min = math.min,
        pi = math.pi,
        rad = math.rad,
        random = math.random,
        sin = math.sin,
        sqrt = math.sqrt,
        tan = math.tan
    }

    -- Block dangerous functions
    self.sandbox_env.dofile = nil
    self.sandbox_env.loadfile = nil
    self.sandbox_env.require = nil
    self.sandbox_env.load = nil
    self.sandbox_env.loadstring = nil
    self.sandbox_env.io = nil
    self.sandbox_env.os = {time = os.time, clock = os.clock}
    self.sandbox_env.package = nil
    self.sandbox_env.debug = nil
end

--- Create the WLS 1.0 whisker API for story scripts
-- Uses dot notation: whisker.state.get(), whisker.passage.current(), etc.
function LuaInterpreter:create_story_api(game_state, context)
    local story = context and context.story or nil
    local engine = context and context.engine or nil

    -- WLS 1.0 whisker namespace with dot notation
    local whisker = {
        -- whisker.state module
        state = {
            get = function(key)
                return game_state:get(key)
            end,
            set = function(key, value)
                return game_state:set(key, value)
            end,
            has = function(key)
                return game_state:has(key)
            end,
            delete = function(key)
                return game_state:delete(key)
            end,
            all = function()
                return game_state:get_all_variables()
            end,
            reset = function()
                game_state:reset()
            end,
            -- WLS 1.0: Temporary variable methods (_var scope)
            get_temp = function(key)
                return game_state:get_temp(key)
            end,
            set_temp = function(key, value)
                local old, err = game_state:set_temp(key, value)
                if err then
                    error(err)
                end
                return old
            end,
            has_temp = function(key)
                return game_state:has_temp(key)
            end,
            delete_temp = function(key)
                return game_state:delete_temp(key)
            end,
            all_temp = function()
                return game_state:get_all_temp_variables()
            end,

            -- ============================================
            -- WLS 1.0 Gap 3: LIST Operations
            -- ============================================

            -- Get list data: { values = {...}, active = {...} }
            get_list = function(name)
                return game_state:get_list(name)
            end,
            -- Check if list exists
            has_list = function(name)
                return game_state:has_list(name)
            end,
            -- Get possible values in a list
            list_values = function(name)
                return game_state:get_list_values(name)
            end,
            -- Get active values in a list
            list_active = function(name)
                return game_state:get_list_active(name)
            end,
            -- Check if value is active in list (contains check)
            list_contains = function(list_name, value)
                return game_state:list_contains(list_name, value)
            end,
            -- Add/activate value in list
            list_add = function(list_name, value)
                return game_state:list_add(list_name, value)
            end,
            -- Remove/deactivate value from list
            list_remove = function(list_name, value)
                return game_state:list_remove(list_name, value)
            end,
            -- Toggle value in list
            list_toggle = function(list_name, value)
                return game_state:list_toggle(list_name, value)
            end,
            -- Get count of active values
            list_count = function(name)
                return game_state:list_count(name)
            end,

            -- ============================================
            -- WLS 1.0 Gap 3: ARRAY Operations
            -- ============================================

            -- Get array by name
            get_array = function(name)
                return game_state:get_array(name)
            end,
            -- Check if array exists
            has_array = function(name)
                return game_state:has_array(name)
            end,
            -- Get array element (0-based index)
            array_get = function(name, index)
                return game_state:array_get(name, index)
            end,
            -- Set array element (0-based index)
            array_set = function(name, index, value)
                return game_state:array_set(name, index, value)
            end,
            -- Get array length
            array_length = function(name)
                return game_state:array_length(name)
            end,
            -- Append to array
            array_push = function(name, value)
                return game_state:array_push(name, value)
            end,
            -- Pop from array
            array_pop = function(name)
                return game_state:array_pop(name)
            end,
            -- Insert at index
            array_insert = function(name, index, value)
                return game_state:array_insert(name, index, value)
            end,
            -- Remove at index
            array_remove = function(name, index)
                return game_state:array_remove(name, index)
            end,
            -- Check if array contains value
            array_contains = function(name, value)
                return game_state:array_contains(name, value)
            end,
            -- Find index of value (returns 0-based, -1 if not found)
            array_index_of = function(name, value)
                return game_state:array_index_of(name, value)
            end,

            -- ============================================
            -- WLS 1.0 Gap 3: MAP Operations
            -- ============================================

            -- Get map by name
            get_map = function(name)
                return game_state:get_map(name)
            end,
            -- Check if map exists
            has_map = function(name)
                return game_state:has_map(name)
            end,
            -- Get map value by key
            map_get = function(name, key)
                return game_state:map_get(name, key)
            end,
            -- Set map value by key
            map_set = function(name, key, value)
                return game_state:map_set(name, key, value)
            end,
            -- Check if map has key
            map_has = function(name, key)
                return game_state:map_has(name, key)
            end,
            -- Delete key from map
            map_delete = function(name, key)
                return game_state:map_delete(name, key)
            end,
            -- Get all keys in map
            map_keys = function(name)
                return game_state:map_keys(name)
            end,
            -- Get all values in map
            map_values = function(name)
                return game_state:map_values(name)
            end,
            -- Get entry count in map
            map_size = function(name)
                return game_state:map_size(name)
            end,

            -- Get all collections (for debugging)
            all_collections = function()
                return game_state:get_all_collections()
            end
        },

        -- whisker.passage module
        passage = {
            current = function()
                local passage_id = game_state:get_current_passage()
                if not passage_id or not story then
                    return nil
                end
                return story:get_passage(passage_id)
            end,
            get = function(id)
                if not story then return nil end
                return story:get_passage(id)
            end,
            go = function(id)
                -- Store target for deferred navigation
                if context then
                    context._pending_navigation = id
                end
                return true
            end,
            exists = function(id)
                if not story then return false end
                return story:get_passage(id) ~= nil
            end,
            all = function()
                if not story then return {} end
                local ids = {}
                local passages = story:get_all_passages()
                for id, _ in pairs(passages) do
                    table.insert(ids, id)
                end
                return ids
            end,
            tags = function(tag)
                if not story then return {} end
                local matching = {}
                local passages = story:get_all_passages()
                for id, passage in pairs(passages) do
                    local passage_tags = passage.tags or {}
                    for _, t in ipairs(passage_tags) do
                        if t == tag then
                            table.insert(matching, id)
                            break
                        end
                    end
                end
                return matching
            end
        },

        -- whisker.history module
        history = {
            back = function()
                if context then
                    context._pending_back = true
                end
                return game_state:can_undo()
            end,
            canBack = function()
                return game_state:can_undo()
            end,
            list = function()
                local passages = {}
                for id, count in pairs(game_state.visited_passages or {}) do
                    if count > 0 then
                        table.insert(passages, id)
                    end
                end
                return passages
            end,
            count = function()
                local count = 0
                for _, visits in pairs(game_state.visited_passages or {}) do
                    if visits > 0 then
                        count = count + 1
                    end
                end
                return count
            end,
            contains = function(id)
                return game_state:has_visited(id)
            end,
            clear = function()
                game_state.history_stack = {}
            end
        },

        -- whisker.choice module
        choice = {
            available = function()
                if not engine then return {} end
                local content = engine:get_current_content()
                if not content or not content.choices then
                    return {}
                end
                return content.choices
            end,
            select = function(index)
                if context then
                    context._pending_choice = index
                end
                return true
            end,
            count = function()
                if not engine then return 0 end
                local content = engine:get_current_content()
                if not content or not content.choices then
                    return 0
                end
                return #content.choices
            end
        }
    }

    -- Top-level WLS 1.0 functions
    local api = {
        whisker = whisker,

        -- visited(passage?) - check if passage visited, returns visit count
        visited = function(passage_id)
            if passage_id == nil then
                passage_id = game_state:get_current_passage()
            end
            return game_state:get_visit_count(passage_id)
        end,

        -- random(min, max) - generate random integer
        random = function(min, max)
            if max == nil then
                max = min
                min = 1
            end
            return math.random(min, max)
        end,

        -- pick(...) - pick random from arguments
        pick = function(...)
            local items = {...}
            if #items == 0 then return nil end
            return items[math.random(1, #items)]
        end,

        -- print(...) - output (already in sandbox, but kept for consistency)
        -- Note: print is already added to sandbox_env

        -- DEPRECATED: Legacy API for backward compatibility
        -- These produce deprecation warnings
        get = function(key, default)
            return game_state:get(key, default)
        end,
        set = function(key, value)
            return game_state:set(key, value)
        end,
        inc = function(key, amount)
            return game_state:increment(key, amount)
        end,
        dec = function(key, amount)
            return game_state:decrement(key, amount)
        end,
        del = function(key)
            return game_state:delete(key)
        end,
        has = function(key)
            return game_state:has(key)
        end,
        visit_count = function(passage_id)
            return game_state:get_visit_count(passage_id)
        end,

        -- Story context access (if provided)
        story = story
    }

    return api
end

function LuaInterpreter:setup_instruction_counting(chunk)
    self.instruction_count = 0
    self.start_time = os.clock()

    -- Set debug hook for instruction counting
    debug.sethook(function()
        self.instruction_count = self.instruction_count + 1

        -- Check instruction limit
        if self.instruction_count > self.max_instructions then
            error("Instruction limit exceeded")
        end

        -- Check timeout
        local elapsed = (os.clock() - self.start_time) * 1000
        if elapsed > self.timeout then
            error("Execution timeout")
        end
    end, "", 100) -- Check every 100 instructions

    return chunk
end

function LuaInterpreter:teardown_instruction_counting()
    debug.sethook() -- Remove hook
end

function LuaInterpreter:execute_code(code, game_state, context)
    if not code or code == "" then
        return true, nil, nil
    end

    -- Compile the code
    local chunk, compile_error = compat.load(code, "story_code", "t", self.sandbox_env)

    if not chunk then
        return false, "Compilation error: " .. tostring(compile_error), {
            type = "compilation",
            code = code
        }
    end

    -- Add story API to sandbox environment
    local story_api = self:create_story_api(game_state, context)
    for k, v in pairs(story_api) do
        self.sandbox_env[k] = v
    end

    -- Set up instruction counting
    chunk = self:setup_instruction_counting(chunk)

    -- Execute the code
    local success, result = pcall(chunk)

    -- Clean up
    self:teardown_instruction_counting()

    if not success then
        return false, "Execution error: " .. tostring(result), {
            type = "execution",
            code = code,
            instruction_count = self.instruction_count
        }
    end

    return true, result, {
        instruction_count = self.instruction_count,
        execution_time = (os.clock() - self.start_time) * 1000
    }
end

function LuaInterpreter:evaluate_condition(condition_code, game_state, context)
    -- Make game state variables directly accessible in sandbox
    if game_state then
        -- Story variables (accessible as varName)
        for k, v in pairs(game_state.variables or {}) do
            self.sandbox_env[k] = v
        end
        -- WLS 1.0: Temp variables (accessible as _varName)
        for k, v in pairs(game_state.temp_variables or {}) do
            self.sandbox_env["_" .. k] = v
        end
        -- WLS 1.0 Gap 3: Lists (accessible as listName - returns active values table)
        for name, list in pairs(game_state.lists or {}) do
            -- Expose list as a table that can be checked for membership
            self.sandbox_env[name] = list.active
        end
        -- WLS 1.0 Gap 3: Arrays (accessible as arrayName)
        for name, arr in pairs(game_state.arrays or {}) do
            self.sandbox_env[name] = arr
        end
        -- WLS 1.0 Gap 3: Maps (accessible as mapName)
        for name, map in pairs(game_state.maps or {}) do
            self.sandbox_env[name] = map
        end
    end

    -- Wrap condition in return statement
    local code = "return (" .. condition_code .. ")"

    local success, result, details = self:execute_code(code, game_state, context)

    -- Clean up direct variable access
    if game_state then
        for k, _ in pairs(game_state.variables or {}) do
            self.sandbox_env[k] = nil
        end
        for k, _ in pairs(game_state.temp_variables or {}) do
            self.sandbox_env["_" .. k] = nil
        end
        for name, _ in pairs(game_state.lists or {}) do
            self.sandbox_env[name] = nil
        end
        for name, _ in pairs(game_state.arrays or {}) do
            self.sandbox_env[name] = nil
        end
        for name, _ in pairs(game_state.maps or {}) do
            self.sandbox_env[name] = nil
        end
    end

    if not success then
        return false, result, details
    end

    -- Ensure result is boolean
    return true, result and true or false, details
end

function LuaInterpreter:evaluate_expression(expression_code, game_state, context)
    -- Make game state variables directly accessible in sandbox
    if game_state then
        -- Story variables (accessible as varName)
        for k, v in pairs(game_state.variables or {}) do
            self.sandbox_env[k] = v
        end
        -- WLS 1.0: Temp variables (accessible as _varName)
        for k, v in pairs(game_state.temp_variables or {}) do
            self.sandbox_env["_" .. k] = v
        end
        -- WLS 1.0 Gap 3: Lists (accessible as listName - returns active values table)
        for name, list in pairs(game_state.lists or {}) do
            self.sandbox_env[name] = list.active
        end
        -- WLS 1.0 Gap 3: Arrays (accessible as arrayName)
        for name, arr in pairs(game_state.arrays or {}) do
            self.sandbox_env[name] = arr
        end
        -- WLS 1.0 Gap 3: Maps (accessible as mapName)
        for name, map in pairs(game_state.maps or {}) do
            self.sandbox_env[name] = map
        end
    end

    -- Wrap expression in return statement
    local code = "return (" .. expression_code .. ")"

    local success, result, details = self:execute_code(code, game_state, context)

    -- Clean up direct variable access
    if game_state then
        for k, _ in pairs(game_state.variables or {}) do
            self.sandbox_env[k] = nil
        end
        for k, _ in pairs(game_state.temp_variables or {}) do
            self.sandbox_env["_" .. k] = nil
        end
        for name, _ in pairs(game_state.lists or {}) do
            self.sandbox_env[name] = nil
        end
        for name, _ in pairs(game_state.arrays or {}) do
            self.sandbox_env[name] = nil
        end
        for name, _ in pairs(game_state.maps or {}) do
            self.sandbox_env[name] = nil
        end
    end

    return success, result, details
end

function LuaInterpreter:get_instruction_count()
    return self.instruction_count
end

function LuaInterpreter:reset_counters()
    self.instruction_count = 0
    self.start_time = 0
end

return LuaInterpreter
