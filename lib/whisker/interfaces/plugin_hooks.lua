--- Plugin Hooks Specification
-- Documents standard hooks available to plugins
-- @module whisker.interfaces.plugin_hooks
-- @author Whisker Core Team
-- @license MIT

local PluginHooks = {}

--- Hook Types
-- Plugins can register handlers for these standard hooks
-- @table HOOK_TYPES
PluginHooks.HOOK_TYPES = {
  -- Story lifecycle hooks
  "story_load",     -- Called when a story is loaded
  "story_start",    -- Called when story playback begins
  "story_end",      -- Called when story ends

  -- Navigation hooks
  "passage_enter",  -- Called when entering a passage
  "passage_exit",   -- Called when leaving a passage

  -- Choice hooks
  "before_choice",  -- Called before a choice is presented
  "after_choice",   -- Called after a choice is made

  -- State hooks
  "state_change",   -- Called when state variables change
  "state_save",     -- Called when state is saved
  "state_load",     -- Called when state is loaded
}

--- Hook fired before a choice is made
-- Can modify the choice, cancel it, or perform side effects
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.choice_index number Index of the choice (1-based)
-- @field context.current_passage table Current passage object
-- @field context.state table Current state
-- @field context.choices table Available choices
-- @return table|nil Modified context to alter behavior, or nil for no change
-- @usage
-- function plugin:before_choice(context)
--   if context.choice_index == 3 then
--     context.choice_index = 1  -- Redirect to first choice
--   end
--   return context
-- end
PluginHooks.before_choice = {
  name = "before_choice",
  context_fields = {"engine", "choice_index", "current_passage", "state", "choices"},
  returns = "table|nil",
  cancelable = true,
}

--- Hook fired after a choice is made
-- Can perform logging, achievements, state updates
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.choice_index number Index of the chosen option
-- @field context.previous_passage table Previous passage object
-- @field context.current_passage table New current passage
-- @field context.state table Current state after choice
-- @usage
-- function plugin:after_choice(context)
--   log("Player chose option " .. context.choice_index)
-- end
PluginHooks.after_choice = {
  name = "after_choice",
  context_fields = {"engine", "choice_index", "previous_passage", "current_passage", "state"},
  returns = nil,
  cancelable = false,
}

--- Hook fired when entering a new passage
-- Can modify passage text, add/remove choices, trigger events
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.passage table The passage being entered
-- @field context.state table Current state
-- @return table|nil Modified context to alter passage
-- @usage
-- function plugin:passage_enter(context)
--   context.passage.text = context.passage.text:gsub("{name}", context.state.player_name)
--   return context
-- end
PluginHooks.passage_enter = {
  name = "passage_enter",
  context_fields = {"engine", "passage", "state"},
  returns = "table|nil",
  cancelable = false,
}

--- Hook fired when exiting a passage
-- Can save state, update progress tracking
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.passage table The passage being exited
-- @field context.state table Current state
-- @usage
-- function plugin:passage_exit(context)
--   context.state:increment_visit_count(context.passage.name)
-- end
PluginHooks.passage_exit = {
  name = "passage_exit",
  context_fields = {"engine", "passage", "state"},
  returns = nil,
  cancelable = false,
}

--- Hook fired when engine state changes
-- Can persist state, validate changes, trigger autosave
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.old_state table State before change
-- @field context.new_state table State after change
-- @field context.change_type string Type of change (set, increment, decrement)
-- @field context.key string The state key that changed
-- @field context.value any The new value
-- @usage
-- function plugin:state_change(context)
--   if context.key == "gold" and context.value > 1000 then
--     trigger_achievement("rich")
--   end
-- end
PluginHooks.state_change = {
  name = "state_change",
  context_fields = {"engine", "old_state", "new_state", "change_type", "key", "value"},
  returns = nil,
  cancelable = false,
}

--- Hook fired when story is loaded
-- Can perform preprocessing, validation, asset loading
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.story_content string|table The raw story content
-- @field context.options table Load options
-- @return table|nil Modified context to alter load
-- @usage
-- function plugin:story_load(context)
--   local assets = extract_assets(context.story_content)
--   preload_assets(assets)
--   return context
-- end
PluginHooks.story_load = {
  name = "story_load",
  context_fields = {"engine", "story_content", "options"},
  returns = "table|nil",
  cancelable = true,
}

--- Hook fired when story starts or restarts
-- Can initialize session data, show intro UI
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.start_passage table The starting passage
-- @field context.is_restart boolean True if this is a restart
-- @usage
-- function plugin:story_start(context)
--   context.state:set("session_start", os.time())
-- end
PluginHooks.story_start = {
  name = "story_start",
  context_fields = {"engine", "start_passage", "is_restart"},
  returns = nil,
  cancelable = false,
}

--- Hook fired when story ends
-- Can show ending UI, compute statistics, cleanup
-- @param context table Hook context
-- @field context.engine table The IEngine instance
-- @field context.ending_passage table The final passage
-- @field context.state table Final state
-- @usage
-- function plugin:story_end(context)
--   local playtime = os.time() - context.state:get("session_start")
--   show_statistics(playtime)
-- end
PluginHooks.story_end = {
  name = "story_end",
  context_fields = {"engine", "ending_passage", "state"},
  returns = nil,
  cancelable = false,
}

--- Validate that a hook name is valid
-- @param name string The hook name to validate
-- @return boolean True if the hook name is valid
function PluginHooks.is_valid_hook(name)
  for _, hook_name in ipairs(PluginHooks.HOOK_TYPES) do
    if hook_name == name then
      return true
    end
  end
  return false
end

--- Get the specification for a hook
-- @param name string The hook name
-- @return table|nil The hook specification, or nil if not found
function PluginHooks.get_spec(name)
  return PluginHooks[name]
end

return PluginHooks
