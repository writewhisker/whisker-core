--- Hook Types
-- Hook event type definitions and constants
-- @module whisker.plugin.hook_types
-- @author Whisker Core Team
-- @license MIT

local HookTypes = {}

--- Hook execution modes
-- @table MODE
HookTypes.MODE = {
  OBSERVER = "observer",    -- Side effects only, returns ignored
  TRANSFORM = "transform",  -- Modify data, returns used
}

--- Story lifecycle hooks
-- @table STORY
HookTypes.STORY = {
  START = "on_story_start",      -- mode: observer, args: (ctx)
  END = "on_story_end",          -- mode: observer, args: (ctx)
  RESET = "on_story_reset",      -- mode: observer, args: (ctx)
}

--- Passage navigation hooks
-- @table PASSAGE
HookTypes.PASSAGE = {
  ENTER = "on_passage_enter",    -- mode: observer, args: (ctx, passage)
  EXIT = "on_passage_exit",      -- mode: observer, args: (ctx, passage)
  RENDER = "on_passage_render",  -- mode: transform, args: (html, ctx, passage)
}

--- Choice handling hooks
-- @table CHOICE
HookTypes.CHOICE = {
  PRESENT = "on_choice_present", -- mode: transform, args: (choices, ctx)
  SELECT = "on_choice_select",   -- mode: observer, args: (ctx, choice)
  EVALUATE = "on_choice_evaluate", -- mode: transform, args: (result, ctx, choice)
}

--- Variable management hooks
-- @table VARIABLE
HookTypes.VARIABLE = {
  SET = "on_variable_set",       -- mode: transform, args: (value, ctx, name)
  GET = "on_variable_get",       -- mode: transform, args: (value, ctx, name)
  CHANGE = "on_state_change",    -- mode: observer, args: (ctx, changes)
}

--- Persistence hooks
-- @table PERSISTENCE
HookTypes.PERSISTENCE = {
  SAVE = "on_save",              -- mode: transform, args: (save_data, ctx)
  LOAD = "on_load",              -- mode: transform, args: (save_data, ctx)
  SAVE_LIST = "on_save_list",    -- mode: transform, args: (saves, ctx)
}

--- Error handling hooks
-- @table ERROR
HookTypes.ERROR = {
  ERROR = "on_error",            -- mode: observer, args: (ctx, error_info)
}

--- All hook events indexed by name
-- @table ALL_EVENTS
HookTypes.ALL_EVENTS = {
  -- Story lifecycle
  on_story_start = { mode = HookTypes.MODE.OBSERVER, category = "story" },
  on_story_end = { mode = HookTypes.MODE.OBSERVER, category = "story" },
  on_story_reset = { mode = HookTypes.MODE.OBSERVER, category = "story" },
  -- Passage navigation
  on_passage_enter = { mode = HookTypes.MODE.OBSERVER, category = "passage" },
  on_passage_exit = { mode = HookTypes.MODE.OBSERVER, category = "passage" },
  on_passage_render = { mode = HookTypes.MODE.TRANSFORM, category = "passage" },
  -- Choice handling
  on_choice_present = { mode = HookTypes.MODE.TRANSFORM, category = "choice" },
  on_choice_select = { mode = HookTypes.MODE.OBSERVER, category = "choice" },
  on_choice_evaluate = { mode = HookTypes.MODE.TRANSFORM, category = "choice" },
  -- Variable management
  on_variable_set = { mode = HookTypes.MODE.TRANSFORM, category = "variable" },
  on_variable_get = { mode = HookTypes.MODE.TRANSFORM, category = "variable" },
  on_state_change = { mode = HookTypes.MODE.OBSERVER, category = "variable" },
  -- Persistence
  on_save = { mode = HookTypes.MODE.TRANSFORM, category = "persistence" },
  on_load = { mode = HookTypes.MODE.TRANSFORM, category = "persistence" },
  on_save_list = { mode = HookTypes.MODE.TRANSFORM, category = "persistence" },
  -- Error
  on_error = { mode = HookTypes.MODE.OBSERVER, category = "error" },
}

--- Get all hook event names
-- @return string[] Array of event names
function HookTypes.get_all_events()
  local events = {}
  for event in pairs(HookTypes.ALL_EVENTS) do
    table.insert(events, event)
  end
  table.sort(events)
  return events
end

--- Get hook mode (observer or transform)
-- @param event string Hook event name
-- @return string|nil mode Hook mode or nil if unknown event
function HookTypes.get_mode(event)
  local info = HookTypes.ALL_EVENTS[event]
  if info then
    return info.mode
  end
  return nil
end

--- Get hook category
-- @param event string Hook event name
-- @return string|nil category Hook category or nil if unknown event
function HookTypes.get_category(event)
  local info = HookTypes.ALL_EVENTS[event]
  if info then
    return info.category
  end
  return nil
end

--- Check if event is a transform hook
-- @param event string Hook event name
-- @return boolean True if transform hook
function HookTypes.is_transform_hook(event)
  return HookTypes.get_mode(event) == HookTypes.MODE.TRANSFORM
end

--- Check if event is an observer hook
-- @param event string Hook event name
-- @return boolean True if observer hook
function HookTypes.is_observer_hook(event)
  return HookTypes.get_mode(event) == HookTypes.MODE.OBSERVER
end

--- Check if event is a known hook type
-- @param event string Hook event name
-- @return boolean True if known hook
function HookTypes.is_known_event(event)
  return HookTypes.ALL_EVENTS[event] ~= nil
end

--- Get events by category
-- @param category string Category name
-- @return string[] Array of event names in category
function HookTypes.get_events_by_category(category)
  local events = {}
  for event, info in pairs(HookTypes.ALL_EVENTS) do
    if info.category == category then
      table.insert(events, event)
    end
  end
  table.sort(events)
  return events
end

--- Get all categories
-- @return string[] Array of category names
function HookTypes.get_categories()
  local categories = {}
  local seen = {}
  for _, info in pairs(HookTypes.ALL_EVENTS) do
    if not seen[info.category] then
      seen[info.category] = true
      table.insert(categories, info.category)
    end
  end
  table.sort(categories)
  return categories
end

return HookTypes
