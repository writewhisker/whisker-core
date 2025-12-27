-- whisker Special Passages
-- Handles Twine-compatible special passages (StoryInit, Start, etc.)
-- Manages passage lifecycle hooks

local SpecialPassages = {}
SpecialPassages.__index = SpecialPassages

-- Dependencies for DI pattern
SpecialPassages._dependencies = { "event_bus" }

-- Standard special passage names (Twine compatible)
SpecialPassages.NAMES = {
    STORY_DATA = "StoryData",           -- Story metadata (Twine)
    STORY_INIT = "StoryInit",           -- Initialization code (runs once at start)
    START = "Start",                     -- Entry point
    STORY_MENU = "StoryMenu",           -- Menu passage
    PASSAGE_HEADER = "PassageHeader",   -- Runs before each passage display
    PASSAGE_FOOTER = "PassageFooter",   -- Runs after each passage display
    STORY_CAPTION = "StoryCaption",     -- Caption text
    STORY_BANNER = "StoryBanner",       -- Banner text
    PASSAGE_DONE = "PassageDone",       -- After passage rendering complete
    PASSAGE_READY = "PassageReady",     -- Before passage becomes interactive
}

-- Set of all special passage names for quick lookup
local SPECIAL_NAMES_SET = {}
for _, name in pairs(SpecialPassages.NAMES) do
    SPECIAL_NAMES_SET[name] = true
end

--- Create a new SpecialPassages instance via DI container
-- @param deps table Dependencies from container
-- @return SpecialPassages instance
function SpecialPassages.create(deps)
    return SpecialPassages.new(deps)
end

--- Create a new SpecialPassages instance
-- @param deps table Optional dependencies
-- @return SpecialPassages instance
function SpecialPassages.new(deps)
    deps = deps or {}
    local self = setmetatable({}, SpecialPassages)

    self._event_bus = deps.event_bus
    self._story = nil
    self._interpreter = deps.interpreter
    self._game_state = deps.game_state
    self._init_executed = false

    return self
end

-- ============================================================================
-- Story Management
-- ============================================================================

--- Set the story to work with
-- @param story Story The story instance
function SpecialPassages:set_story(story)
    self._story = story
    self._init_executed = false
end

--- Set the interpreter for script execution
-- @param interpreter LuaInterpreter The interpreter instance
function SpecialPassages:set_interpreter(interpreter)
    self._interpreter = interpreter
end

--- Set the game state for script context
-- @param game_state GameState The game state instance
function SpecialPassages:set_game_state(game_state)
    self._game_state = game_state
end

-- ============================================================================
-- Passage Queries
-- ============================================================================

--- Get a special passage by name
-- @param name string The special passage name
-- @return Passage|nil The passage or nil if not found
function SpecialPassages:get(name)
    if not self._story then
        return nil
    end
    return self._story:get_passage(name)
end

--- Check if a special passage exists
-- @param name string The special passage name
-- @return boolean
function SpecialPassages:exists(name)
    return self:get(name) ~= nil
end

--- Check if a passage name is a special passage
-- @param passage_name string The passage name to check
-- @return boolean
function SpecialPassages:is_special(passage_name)
    return SPECIAL_NAMES_SET[passage_name] == true
end

--- Get all special passages that exist in the story
-- @return table Map of name -> passage
function SpecialPassages:get_all_existing()
    local existing = {}
    if not self._story then
        return existing
    end

    for key, name in pairs(SpecialPassages.NAMES) do
        local passage = self._story:get_passage(name)
        if passage then
            existing[key] = passage
        end
    end

    return existing
end

-- ============================================================================
-- Lifecycle Execution
-- ============================================================================

--- Execute StoryInit passage (should only run once at story start)
-- @return boolean, string Success and optional error message
function SpecialPassages:execute_init()
    if self._init_executed then
        return true, nil
    end

    local passage = self:get(SpecialPassages.NAMES.STORY_INIT)
    if not passage then
        self._init_executed = true
        return true, nil
    end

    self:_emit_event("SCRIPT_EXECUTED", {
        passage = SpecialPassages.NAMES.STORY_INIT,
        phase = "story_init",
    })

    local success, err = self:_execute_passage_script(passage)
    if success then
        self._init_executed = true
    end

    return success, err
end

--- Execute PassageHeader (runs before each passage display)
-- @return boolean, string Success and optional error message
function SpecialPassages:execute_header()
    return self:_execute_special(SpecialPassages.NAMES.PASSAGE_HEADER, "header")
end

--- Execute PassageFooter (runs after each passage display)
-- @return boolean, string Success and optional error message
function SpecialPassages:execute_footer()
    return self:_execute_special(SpecialPassages.NAMES.PASSAGE_FOOTER, "footer")
end

--- Execute PassageDone (runs after passage rendering complete)
-- @return boolean, string Success and optional error message
function SpecialPassages:execute_done()
    return self:_execute_special(SpecialPassages.NAMES.PASSAGE_DONE, "done")
end

--- Execute PassageReady (runs before passage becomes interactive)
-- @return boolean, string Success and optional error message
function SpecialPassages:execute_ready()
    return self:_execute_special(SpecialPassages.NAMES.PASSAGE_READY, "ready")
end

--- Get the content of StoryCaption (for display)
-- @return string|nil Caption content or nil
function SpecialPassages:get_caption_content()
    local passage = self:get(SpecialPassages.NAMES.STORY_CAPTION)
    if passage then
        return passage:get_content()
    end
    return nil
end

--- Get the content of StoryBanner (for display)
-- @return string|nil Banner content or nil
function SpecialPassages:get_banner_content()
    local passage = self:get(SpecialPassages.NAMES.STORY_BANNER)
    if passage then
        return passage:get_content()
    end
    return nil
end

--- Get the content of StoryMenu (for display)
-- @return string|nil Menu content or nil
function SpecialPassages:get_menu_content()
    local passage = self:get(SpecialPassages.NAMES.STORY_MENU)
    if passage then
        return passage:get_content()
    end
    return nil
end

-- ============================================================================
-- Start Passage Handling
-- ============================================================================

--- Get the start passage for the story
-- @return Passage|nil The start passage or nil
function SpecialPassages:get_start_passage()
    -- Try explicit Start passage first
    local start = self:get(SpecialPassages.NAMES.START)
    if start then
        return start
    end

    -- Fall back to story's designated start passage
    if self._story and self._story.get_start_passage then
        local start_name = self._story:get_start_passage()
        if start_name then
            return self._story:get_passage(start_name)
        end
    end

    -- Fall back to first non-special passage
    if self._story then
        local passages = self._story:get_all_passages()
        if passages then
            for _, passage in ipairs(passages) do
                local name = passage.name or passage.id
                if not self:is_special(name) then
                    return passage
                end
            end
        end
    end

    return nil
end

--- Get the name of the start passage
-- @return string|nil The start passage name or nil
function SpecialPassages:get_start_passage_name()
    local passage = self:get_start_passage()
    if passage then
        if type(passage.get_name) == "function" then
            return passage:get_name()
        elseif passage.name then
            return passage.name
        end
    end
    return nil
end

--- Validate that a start passage exists
-- @return boolean, string Success and optional error message
function SpecialPassages:validate_start()
    local start = self:get_start_passage()
    if not start then
        return false, "No start passage found. Create a passage named 'Start' or add at least one regular passage."
    end
    return true, nil
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Execute a special passage by name
-- @param name string The passage name
-- @param phase string The execution phase (for logging)
-- @return boolean, string Success and optional error
function SpecialPassages:_execute_special(name, phase)
    local passage = self:get(name)
    if not passage then
        return true, nil  -- Not having the passage is not an error
    end

    self:_emit_event("SCRIPT_EXECUTED", {
        passage = name,
        phase = phase,
    })

    return self:_execute_passage_script(passage)
end

--- Execute a passage's content as script
-- @param passage Passage The passage to execute
-- @return boolean, string Success and optional error
function SpecialPassages:_execute_passage_script(passage)
    local content
    if type(passage.get_content) == "function" then
        content = passage:get_content()
    else
        content = passage.content
    end

    if not content or content == "" then
        return true, nil
    end

    -- If we have an interpreter, use it
    if self._interpreter then
        local success, result = self._interpreter:execute_code(content, self._game_state)
        if not success then
            self:_emit_event("ERROR_OCCURRED", {
                source = "special_passage",
                passage = passage.name or "unknown",
                error = result,
            })
            return false, result
        end
        return true, nil
    end

    -- Without interpreter, we can't execute scripts
    return true, nil
end

--- Emit an event
-- @param event_type string The event type
-- @param data table Event data
function SpecialPassages:_emit_event(event_type, data)
    if self._event_bus then
        self._event_bus:emit(event_type, data)
    end
end

--- Check if StoryInit has been executed
-- @return boolean
function SpecialPassages:is_init_executed()
    return self._init_executed
end

--- Reset init state (for restarting story)
function SpecialPassages:reset()
    self._init_executed = false
end

return SpecialPassages
