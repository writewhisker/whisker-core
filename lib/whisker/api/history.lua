-- lib/whisker/api/history.lua
-- WLS 1.0 whisker.history API module
-- Provides dot-notation access to navigation history

local History = {}

-- Private references (set by init)
local _game_state = nil
local _engine = nil

--- Initialize the history module
-- @param game_state GameState The game state
-- @param engine Engine The engine instance
function History._init(game_state, engine)
    _game_state = game_state
    _engine = engine
end

--- Go back to the previous passage
-- @return boolean True if back navigation succeeded
function History.back()
    if not _engine then
        error("whisker.history.back requires engine context")
    end
    -- Mark for deferred back navigation
    History._pending_back = true
    return _game_state:can_undo()
end

--- Check if back navigation is possible
-- @return boolean True if can go back
function History.canBack()
    if not _game_state then
        error("whisker.history not initialized")
    end
    return _game_state:can_undo()
end

--- Get the list of visited passage IDs
-- @return table Array of passage IDs in visit order
function History.list()
    if not _game_state then
        error("whisker.history not initialized")
    end
    local passages = {}
    for id, count in pairs(_game_state.visited_passages or {}) do
        if count > 0 then
            table.insert(passages, id)
        end
    end
    return passages
end

--- Get the count of unique passages visited
-- @return number Number of unique passages visited
function History.count()
    if not _game_state then
        error("whisker.history not initialized")
    end
    local count = 0
    for _, visits in pairs(_game_state.visited_passages or {}) do
        if visits > 0 then
            count = count + 1
        end
    end
    return count
end

--- Check if a specific passage is in history
-- @param id string The passage ID
-- @return boolean True if passage has been visited
function History.contains(id)
    if not _game_state then
        error("whisker.history not initialized")
    end
    return _game_state:has_visited(id)
end

--- Clear navigation history
function History.clear()
    if not _game_state then
        error("whisker.history not initialized")
    end
    _game_state.history_stack = {}
end

return History
