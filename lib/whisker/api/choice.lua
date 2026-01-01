-- lib/whisker/api/choice.lua
-- WLS 1.0 whisker.choice API module
-- Provides dot-notation access to available choices

local Choice = {}

-- Private references (set by init)
local _engine = nil

--- Initialize the choice module
-- @param engine Engine The engine instance
function Choice._init(engine)
    _engine = engine
end

--- Get available choices for the current passage
-- @return table Array of available choice objects
function Choice.available()
    if not _engine then
        error("whisker.choice not initialized")
    end
    local content = _engine:get_current_content()
    if not content or not content.choices then
        return {}
    end
    return content.choices
end

--- Select a choice by index (1-based)
-- @param index number The choice index (1-based)
-- @return boolean True if selection succeeded
function Choice.select(index)
    if not _engine then
        error("whisker.choice.select requires engine context")
    end
    -- Store pending selection for deferred processing
    Choice._pending_selection = index
    return true
end

--- Get the count of available choices
-- @return number Number of available choices
function Choice.count()
    if not _engine then
        error("whisker.choice not initialized")
    end
    local content = _engine:get_current_content()
    if not content or not content.choices then
        return 0
    end
    return #content.choices
end

return Choice
