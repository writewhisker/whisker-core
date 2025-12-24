-- src/core/engine.lua
-- Story engine with navigation (75% complete - missing visual/audio)

local Engine = {}
Engine.__index = Engine

-- Dependencies for DI pattern
Engine._dependencies = {"story_factory", "game_state_factory", "lua_interpreter_factory", "event_bus"}

-- Cached factories for backward compatibility (lazy loaded)
local _story_factory_cache = nil
local _game_state_factory_cache = nil
local _interpreter_factory_cache = nil

--- Get the story factory (supports both DI and backward compatibility)
local function get_story_factory(deps)
  if deps and deps.story_factory then
    return deps.story_factory
  end
  if not _story_factory_cache then
    local StoryFactory = require("whisker.core.factories.story_factory")
    _story_factory_cache = StoryFactory.new()
  end
  return _story_factory_cache
end

--- Get the game state factory
local function get_game_state_factory(deps)
  if deps and deps.game_state_factory then
    return deps.game_state_factory
  end
  if not _game_state_factory_cache then
    local GameStateFactory = require("whisker.core.factories.game_state_factory")
    _game_state_factory_cache = GameStateFactory.new()
  end
  return _game_state_factory_cache
end

--- Get the lua interpreter factory
local function get_interpreter_factory(deps)
  if deps and deps.lua_interpreter_factory then
    return deps.lua_interpreter_factory
  end
  if not _interpreter_factory_cache then
    local InterpreterFactory = require("whisker.core.factories.lua_interpreter_factory")
    _interpreter_factory_cache = InterpreterFactory.new()
  end
  return _interpreter_factory_cache
end

--- Create a new Engine instance via DI container
-- @param deps table Dependencies from container
-- @return function Factory function that creates Engine instances
function Engine.create(deps)
  local story_factory = get_story_factory(deps)
  local game_state_factory = get_game_state_factory(deps)
  local interpreter_factory = get_interpreter_factory(deps)
  local event_bus = deps and deps.event_bus or nil
  -- Return a factory function
  return function(story, game_state, config)
    return Engine.new(story, game_state, config, {
      story_factory = story_factory,
      game_state_factory = game_state_factory,
      lua_interpreter_factory = interpreter_factory,
      event_bus = event_bus
    })
  end
end

function Engine.new(story, game_state, config, deps)
    deps = deps or {}

    local instance = {
        config = config or {},
        current_story = nil,
        game_state = game_state,
        interpreter = nil,
        current_content = nil,
        is_running = false,
        performance_stats = {
            story_start_time = nil,
            passages_visited = 0,
            choices_made = 0
        },
        -- Store factories for DI
        _story_factory = deps.story_factory,
        _game_state_factory = deps.game_state_factory,
        _interpreter_factory = deps.lua_interpreter_factory,
        _event_bus = deps.event_bus
    }

    setmetatable(instance, Engine)

    -- Get factories (use injected or fallback)
    local story_factory = get_story_factory(deps)
    local game_state_factory = get_game_state_factory(deps)
    local interpreter_factory = get_interpreter_factory(deps)

    -- Ensure story has proper metatable (handles deserialized stories)
    if story and type(story) == "table" then
        local Story = require("whisker.core.story")
        -- Check if story has Story metatable
        if getmetatable(story) ~= Story then
            -- Restore metatable if missing using factory
            instance.current_story = story_factory:restore_metatable(story)
        else
            instance.current_story = story
        end
    else
        instance.current_story = story
    end

    -- Initialize game state if not provided
    if not instance.game_state then
        instance.game_state = game_state_factory:create()
    end

    -- Initialize interpreter
    if not instance.interpreter then
        instance.interpreter = interpreter_factory:create()
    end

    return instance
end

function Engine:load_story(story)
    -- Get factories
    local story_factory = self._story_factory or get_story_factory()
    local game_state_factory = self._game_state_factory or get_game_state_factory()
    local interpreter_factory = self._interpreter_factory or get_interpreter_factory()

    -- Ensure story has proper metatable (handles deserialized stories)
    if story and type(story) == "table" then
        local Story = require("whisker.core.story")
        -- Check if story has Story metatable
        if getmetatable(story) ~= Story then
            -- Restore metatable if missing using factory
            self.current_story = story_factory:restore_metatable(story)
        else
            self.current_story = story
        end
    else
        self.current_story = story
    end

    -- Initialize game state if not provided
    if not self.game_state then
        self.game_state = game_state_factory:create()
    end

    -- Initialize interpreter if not provided
    if not self.interpreter then
        self.interpreter = interpreter_factory:create()
    end

    return true
end

function Engine:start_story(starting_passage_id)
    if not self.current_story then
        error("No story loaded")
    end

    -- Initialize game state
    self.game_state:initialize(self.current_story)

    -- Determine starting passage
    local start_passage
    if starting_passage_id then
        start_passage = starting_passage_id
    elseif self.current_story and self.current_story.get_start_passage then
        start_passage = self.current_story:get_start_passage()
    else
        -- Fallback: try to get from start_passage field directly
        start_passage = self.current_story.start_passage
    end

    if not start_passage then
        error("No starting passage found")
    end

    -- Track start time
    self.performance_stats.story_start_time = os.time()
    self.is_running = true

    -- Navigate to first passage
    return self:navigate_to_passage(start_passage)
end

function Engine:navigate_to_passage(passage_id)
    if not self.is_running then
        error("Story is not running")
    end

    -- Get passage
    local passage = self.current_story:get_passage(passage_id)
    if not passage then
        error("Passage not found: " .. tostring(passage_id))
    end

    -- Execute passage entry hook
    if passage.on_enter_script then
        self:execute_passage_code(passage.on_enter_script, "on_enter")
    end

    -- Update game state
    self.game_state:set_current_passage(passage_id)
    self.performance_stats.passages_visited = self.performance_stats.passages_visited + 1

    -- Render passage content
    local rendered_content = self:render_passage_content(passage)

    -- Get available choices
    local available_choices = self:get_available_choices(passage)

    -- Store current content
    self.current_content = {
        passage_id = passage_id,
        passage = passage,
        content = rendered_content,
        choices = available_choices,
        can_undo = self.game_state:can_undo(),
        metadata = {
            visit_count = self.game_state:get_visit_count(passage_id),
            is_first_visit = self.game_state:get_visit_count(passage_id) == 1
        }
    }

    return self.current_content
end

function Engine:make_choice(choice_index)
    if not self.current_content or not self.current_content.choices then
        error("No choices available")
    end

    local choices = self.current_content.choices
    if choice_index < 1 or choice_index > #choices then
        error("Invalid choice index: " .. tostring(choice_index))
    end

    local choice = choices[choice_index]

    -- Execute choice action if present
    if choice:has_action() then
        self:execute_passage_code(choice:get_action(), "choice_action")
    end

    -- Track choice made
    self.performance_stats.choices_made = self.performance_stats.choices_made + 1

    -- Navigate to target passage
    return self:navigate_to_passage(choice:get_target())
end

function Engine:render_passage_content(passage)
    local content = passage:get_content()

    -- Process embedded Lua expressions {{...}}
    -- But skip template directives ({{#if}}, {{else}}, {{/if}}, etc.)
    content = content:gsub("{{%s*([^#/%s].-)}}", function(code)
        -- Skip template keywords
        if code:match("^%s*else%s*$") or code:match("^%s*each%s") then
            return "{{" .. code .. "}}"
        end

        local success, result = self.interpreter:evaluate_expression(code, self.game_state)
        if success then
            return tostring(result)
        else
            return "{{ERROR: " .. tostring(result) .. "}}"
        end
    end)

    return content
end

function Engine:get_available_choices(passage)
    local available = {}

    for _, choice in ipairs(passage:get_choices()) do
        -- Check if choice condition is met
        local is_available = true

        if choice:has_condition() then
            local success, result = self.interpreter:evaluate_condition(
                choice:get_condition(),
                self.game_state
            )

            if success then
                is_available = result
            else
                -- If condition evaluation fails, hide the choice
                is_available = false
            end
        end

        if is_available then
            table.insert(available, choice)
        end
    end

    return available
end

function Engine:execute_passage_code(code, context)
    if not code or code == "" then
        return true, nil
    end

    local success, result, details = self.interpreter:execute_code(code, self.game_state)

    if not success then
        -- Log error but don't crash
        print("Error in " .. context .. ": " .. tostring(result))
        return false, result
    end

    return true, result
end

function Engine:undo()
    if not self.game_state:can_undo() then
        return false, "No undo available"
    end

    local snapshot = self.game_state:undo()

    if snapshot and snapshot.current_passage then
        return self:navigate_to_passage(snapshot.current_passage)
    end

    return false, "Undo failed"
end

function Engine:restart()
    if not self.current_story then
        return false, "No story loaded"
    end

    self.game_state:reset()
    return self:start_story()
end

function Engine:get_current_content()
    return self.current_content
end

function Engine:get_game_state()
    return self.game_state
end

function Engine:get_all_variables()
    return self.game_state:get_all_variables()
end

function Engine:get_performance_stats()
    return self.performance_stats
end

function Engine:is_story_running()
    return self.is_running
end

function Engine:stop_story()
    self.is_running = false
    self.current_content = nil
end

return Engine
