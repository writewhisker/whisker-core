-- lib/whisker/api/passage.lua
-- WLS 1.0 whisker.passage API module
-- Provides dot-notation access to passage information and navigation

local Passage = {}

-- Private references (set by init)
local _story = nil
local _game_state = nil
local _engine = nil

--- Initialize the passage module
-- @param story Story The current story
-- @param game_state GameState The game state
-- @param engine Engine The engine instance (for navigation)
function Passage._init(story, game_state, engine)
    _story = story
    _game_state = game_state
    _engine = engine
end

--- Get the current passage
-- @return table The current passage object, or nil
function Passage.current()
    if not _game_state then
        error("whisker.passage not initialized")
    end
    local passage_id = _game_state:get_current_passage()
    if not passage_id or not _story then
        return nil
    end
    return _story:get_passage(passage_id)
end

--- Get a passage by ID
-- @param id string The passage ID
-- @return table The passage object, or nil if not found
function Passage.get(id)
    if not _story then
        error("whisker.passage not initialized")
    end
    return _story:get_passage(id)
end

--- Navigate to a passage
-- @param id string The passage ID to navigate to
-- @return boolean True if navigation succeeded
function Passage.go(id)
    if not _engine then
        error("whisker.passage.go requires engine context")
    end
    -- Store target for deferred navigation (engine will process it)
    Passage._pending_navigation = id
    return true
end

--- Check if a passage exists
-- @param id string The passage ID
-- @return boolean True if passage exists
function Passage.exists(id)
    if not _story then
        error("whisker.passage not initialized")
    end
    return _story:get_passage(id) ~= nil
end

--- Get all passage IDs
-- @return table Array of passage IDs
function Passage.all()
    if not _story then
        error("whisker.passage not initialized")
    end
    local ids = {}
    local passages = _story:get_all_passages()
    for id, _ in pairs(passages) do
        table.insert(ids, id)
    end
    return ids
end

--- Get passages with a specific tag
-- @param tag string The tag to filter by
-- @return table Array of passage IDs with the tag
function Passage.tags(tag)
    if not _story then
        error("whisker.passage not initialized")
    end
    local matching = {}
    local passages = _story:get_all_passages()
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

return Passage
