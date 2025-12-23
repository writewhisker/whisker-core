--- Story Hooks Integration
-- Integration layer between hook system and story runtime components
-- @module whisker.plugin.story_hooks
-- @author Whisker Core Team
-- @license MIT

local HookTypes = require("whisker.plugin.hook_types")

local StoryHooks = {}
StoryHooks.__index = StoryHooks

--- Create a new story hooks integration
-- @param hook_manager HookManager instance
-- @param state_manager StateManager instance (optional)
-- @return StoryHooks
function StoryHooks.new(hook_manager, state_manager)
  assert(hook_manager, "HookManager is required")

  local self = setmetatable({}, StoryHooks)

  self._hook_manager = hook_manager
  self._state_manager = state_manager
  self._current_passage = nil
  self._performance_tracking = false
  self._slow_threshold_ms = 10

  return self
end

--- Set state manager (can be set after construction)
-- @param state_manager table
function StoryHooks:set_state_manager(state_manager)
  self._state_manager = state_manager
end

--- Enable/disable performance tracking
-- @param enabled boolean
-- @param threshold_ms number|nil Slow hook threshold in milliseconds
function StoryHooks:set_performance_tracking(enabled, threshold_ms)
  self._performance_tracking = enabled
  if threshold_ms then
    self._slow_threshold_ms = threshold_ms
  end
end

--- Create context for hook invocation
-- @param additional table|nil Additional context data
-- @return table Context object
function StoryHooks:_create_context(additional)
  local ctx = {
    state = self._state_manager,
    current_passage = self._current_passage,
  }

  if additional then
    for k, v in pairs(additional) do
      ctx[k] = v
    end
  end

  return ctx
end

--- Call hooks with performance tracking
-- @param event string Hook event name
-- @param ... any Arguments to pass
-- @return any, table value (for transform), results
function StoryHooks:_call(event, ...)
  local start_time
  if self._performance_tracking then
    start_time = os.clock()
  end

  local value, results

  if HookTypes.is_transform_hook(event) then
    value, results = self._hook_manager:transform(event, ...)
  else
    value = nil
    results = self._hook_manager:trigger(event, ...)
  end

  if self._performance_tracking and start_time then
    local duration_ms = (os.clock() - start_time) * 1000
    if duration_ms > self._slow_threshold_ms then
      print(string.format(
        "[WARN] Slow hook execution: %s took %.2fms",
        event,
        duration_ms
      ))
    end
  end

  return value, results
end

-- =============================================================================
-- Story Lifecycle Hooks
-- =============================================================================

--- Fire on_story_start hook
-- @return table results Hook execution results
function StoryHooks:story_start()
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.STORY.START, ctx)
  return results
end

--- Fire on_story_end hook
-- @return table results
function StoryHooks:story_end()
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.STORY.END, ctx)
  return results
end

--- Fire on_story_reset hook
-- @return table results
function StoryHooks:story_reset()
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.STORY.RESET, ctx)
  return results
end

-- =============================================================================
-- Passage Navigation Hooks
-- =============================================================================

--- Fire on_passage_enter hook
-- @param passage table Passage being entered
-- @return table results
function StoryHooks:passage_enter(passage)
  self._current_passage = passage
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.PASSAGE.ENTER, ctx, passage)
  return results
end

--- Fire on_passage_exit hook
-- @param passage table Passage being exited
-- @return table results
function StoryHooks:passage_exit(passage)
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.PASSAGE.EXIT, ctx, passage)
  return results
end

--- Fire on_passage_render transform hook
-- @param html string Rendered HTML
-- @param passage table Passage being rendered
-- @return string Transformed HTML
-- @return table results
function StoryHooks:passage_render(html, passage)
  local ctx = self:_create_context()
  return self:_call(HookTypes.PASSAGE.RENDER, html, ctx, passage)
end

-- =============================================================================
-- Choice Handling Hooks
-- =============================================================================

--- Fire on_choice_present transform hook
-- @param choices table[] Raw choice list
-- @return table[] Transformed choices
-- @return table results
function StoryHooks:choice_present(choices)
  local ctx = self:_create_context()
  return self:_call(HookTypes.CHOICE.PRESENT, choices, ctx)
end

--- Fire on_choice_select observer hook
-- @param choice table Selected choice
-- @return table results
function StoryHooks:choice_select(choice)
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.CHOICE.SELECT, ctx, choice)
  return results
end

--- Fire on_choice_evaluate transform hook
-- @param result any Condition evaluation result
-- @param choice table Choice being evaluated
-- @return any Transformed result
-- @return table results
function StoryHooks:choice_evaluate(result, choice)
  local ctx = self:_create_context()
  return self:_call(HookTypes.CHOICE.EVALUATE, result, ctx, choice)
end

-- =============================================================================
-- Variable Management Hooks
-- =============================================================================

--- Fire on_variable_set transform hook
-- @param value any Value being set
-- @param name string Variable name
-- @return any Transformed value
-- @return table results
function StoryHooks:variable_set(value, name)
  local ctx = self:_create_context()
  return self:_call(HookTypes.VARIABLE.SET, value, ctx, name)
end

--- Fire on_variable_get transform hook
-- @param value any Current value
-- @param name string Variable name
-- @return any Transformed value
-- @return table results
function StoryHooks:variable_get(value, name)
  local ctx = self:_create_context()
  return self:_call(HookTypes.VARIABLE.GET, value, ctx, name)
end

--- Fire on_state_change observer hook
-- @param changes table Map of variable name -> new value
-- @return table results
function StoryHooks:state_change(changes)
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.VARIABLE.CHANGE, ctx, changes)
  return results
end

-- =============================================================================
-- Persistence Hooks
-- =============================================================================

--- Fire on_save transform hook
-- @param save_data table Save data being created
-- @return table Transformed save data
-- @return table results
function StoryHooks:on_save(save_data)
  local ctx = self:_create_context()
  return self:_call(HookTypes.PERSISTENCE.SAVE, save_data, ctx)
end

--- Fire on_load transform hook
-- @param save_data table Save data being loaded
-- @return table Transformed save data
-- @return table results
function StoryHooks:on_load(save_data)
  local ctx = self:_create_context()
  return self:_call(HookTypes.PERSISTENCE.LOAD, save_data, ctx)
end

--- Fire on_save_list transform hook
-- @param saves table[] List of save file info
-- @return table[] Transformed save list
-- @return table results
function StoryHooks:on_save_list(saves)
  local ctx = self:_create_context()
  return self:_call(HookTypes.PERSISTENCE.SAVE_LIST, saves, ctx)
end

-- =============================================================================
-- Error Hooks
-- =============================================================================

--- Fire on_error observer hook
-- @param error_info table Error information {message, stack, context}
-- @return table results
function StoryHooks:on_error(error_info)
  local ctx = self:_create_context()
  local _, results = self:_call(HookTypes.ERROR.ERROR, ctx, error_info)
  return results
end

-- =============================================================================
-- Utility Methods
-- =============================================================================

--- Get the underlying hook manager
-- @return HookManager
function StoryHooks:get_hook_manager()
  return self._hook_manager
end

--- Get current passage
-- @return table|nil
function StoryHooks:get_current_passage()
  return self._current_passage
end

--- Set current passage (for external navigation)
-- @param passage table|nil
function StoryHooks:set_current_passage(passage)
  self._current_passage = passage
end

--- Check if any hooks are registered for an event
-- @param event string Event name
-- @return boolean
function StoryHooks:has_hooks(event)
  return self._hook_manager:get_hook_count(event) > 0
end

--- Get hook statistics
-- @return table Statistics
function StoryHooks:get_statistics()
  local events = HookTypes.get_all_events()
  local stats = {
    total_hooks = self._hook_manager:get_total_hook_count(),
    events_with_hooks = 0,
    hooks_by_event = {},
  }

  for _, event in ipairs(events) do
    local count = self._hook_manager:get_hook_count(event)
    if count > 0 then
      stats.events_with_hooks = stats.events_with_hooks + 1
      stats.hooks_by_event[event] = count
    end
  end

  return stats
end

return StoryHooks
