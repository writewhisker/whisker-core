-- lib/whisker/api/init.lua
-- WLS 1.0 Whisker API
-- Unified namespace with dot-notation access
--
-- Usage:
--   whisker.state.get("gold")
--   whisker.state.set("gold", 100)
--   whisker.passage.current()
--   whisker.passage.go("NextRoom")
--   whisker.history.back()
--   whisker.choice.available()
--
-- Top-level functions:
--   visited("PassageName")
--   random(1, 6)
--   pick("a", "b", "c")
--   print("message")

local state = require("whisker.api.state")
local passage = require("whisker.api.passage")
local history = require("whisker.api.history")
local choice = require("whisker.api.choice")

local Whisker = {
    -- Sub-namespaces (dot notation)
    state = state,
    passage = passage,
    history = history,
    choice = choice,

    -- Internal state
    _initialized = false,
    _game_state = nil,
    _story = nil,
    _engine = nil
}

--- Initialize the Whisker API with context
-- @param game_state GameState The game state instance
-- @param story Story The current story
-- @param engine Engine The engine instance
function Whisker.init(game_state, story, engine)
    Whisker._game_state = game_state
    Whisker._story = story
    Whisker._engine = engine
    Whisker._initialized = true

    -- Initialize sub-modules
    state._init(game_state)
    passage._init(story, game_state, engine)
    history._init(game_state, engine)
    choice._init(engine)
end

--- Reset the API state
function Whisker.reset()
    Whisker._game_state = nil
    Whisker._story = nil
    Whisker._engine = nil
    Whisker._initialized = false
end

--- Check if the API is initialized
-- @return boolean True if initialized
function Whisker.is_initialized()
    return Whisker._initialized
end

-- ============================================
-- Top-Level Functions (WLS 1.0 spec)
-- ============================================

--- Check if a passage has been visited
-- @param passage_id string|nil The passage ID (optional, defaults to current)
-- @return number The visit count (0 if never visited)
function Whisker.visited(passage_id)
    if not Whisker._game_state then
        error("whisker not initialized")
    end
    if passage_id == nil then
        passage_id = Whisker._game_state:get_current_passage()
    end
    return Whisker._game_state:get_visit_count(passage_id)
end

--- Generate a random integer between min and max (inclusive)
-- @param min number The minimum value
-- @param max number The maximum value
-- @return number A random integer in [min, max]
function Whisker.random(min, max)
    if max == nil then
        -- If only one arg, treat as range [1, min]
        max = min
        min = 1
    end
    return math.random(min, max)
end

--- Pick a random item from arguments
-- @param ... vararg Items to choose from
-- @return any A randomly selected item
function Whisker.pick(...)
    local items = {...}
    if #items == 0 then
        return nil
    end
    local index = math.random(1, #items)
    return items[index]
end

--- Print output (for debugging)
-- @param ... vararg Values to print
function Whisker.print(...)
    local args = {...}
    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = tostring(v)
    end
    print(table.concat(parts, "\t"))
end

-- ============================================
-- Deprecation Warnings for Old API
-- ============================================

local _warned = {}

local function warn_deprecated(old_name, new_name)
    if not _warned[old_name] then
        io.stderr:write(string.format(
            "[DEPRECATED] %s is deprecated. Use %s instead.\n",
            old_name, new_name
        ))
        _warned[old_name] = true
    end
end

--- DEPRECATED: Use whisker.state.get instead
function Whisker.get(key)
    warn_deprecated("whisker.get()", "whisker.state.get()")
    return state.get(key)
end

--- DEPRECATED: Use whisker.state.set instead
function Whisker.set(key, value)
    warn_deprecated("whisker.set()", "whisker.state.set()")
    return state.set(key, value)
end

--- DEPRECATED: Use whisker.passage.go instead
function Whisker.goto(passage_id)
    warn_deprecated("whisker.goto()", "whisker.passage.go()")
    return passage.go(passage_id)
end

return Whisker
