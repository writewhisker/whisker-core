-- lib/whisker/api/state.lua
-- WLS 1.0 whisker.state API module
-- Provides dot-notation access to story state variables

local State = {}

-- Private reference to game state (set by init)
local _game_state = nil

--- Initialize the state module with a GameState instance
-- @param game_state GameState The game state to wrap
function State._init(game_state)
    _game_state = game_state
end

--- Get the value of a story variable
-- @param key string The variable name
-- @return any The variable value, or nil if not set
function State.get(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:get(key)
end

--- Set the value of a story variable
-- @param key string The variable name
-- @param value any The value to set
-- @return any The previous value
function State.set(key, value)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:set(key, value)
end

--- Check if a variable exists
-- @param key string The variable name
-- @return boolean True if variable exists
function State.has(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:has(key)
end

--- Delete a variable
-- @param key string The variable name
-- @return any The deleted value
function State.delete(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:delete(key)
end

--- Get all story variables
-- @return table All variables as key-value pairs
function State.all()
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:get_all_variables()
end

--- Reset all story variables
function State.reset()
    if not _game_state then
        error("whisker.state not initialized")
    end
    _game_state:reset()
end

-- WLS 1.0: Temporary variable methods (_var scope)

--- Get a temporary variable (passage-scoped)
-- @param key string The variable name (without _ prefix)
-- @return any The variable value, or nil if not set
function State.get_temp(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:get_temp(key)
end

--- Set a temporary variable (passage-scoped, cleared on passage change)
-- @param key string The variable name (without _ prefix)
-- @param value any The value to set
-- @return any The previous value, or nil with error on shadowing
function State.set_temp(key, value)
    if not _game_state then
        error("whisker.state not initialized")
    end
    local old_value, err = _game_state:set_temp(key, value)
    if err then
        error(err)
    end
    return old_value
end

--- Check if a temporary variable exists
-- @param key string The variable name (without _ prefix)
-- @return boolean True if variable exists
function State.has_temp(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:has_temp(key)
end

--- Delete a temporary variable
-- @param key string The variable name (without _ prefix)
-- @return any The deleted value
function State.delete_temp(key)
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:delete_temp(key)
end

--- Get all temporary variables
-- @return table All temp variables as key-value pairs
function State.all_temp()
    if not _game_state then
        error("whisker.state not initialized")
    end
    return _game_state:get_all_temp_variables()
end

return State
