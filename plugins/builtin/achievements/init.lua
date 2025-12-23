--- Achievements Plugin
-- Trophy/achievement system for interactive fiction stories
-- @module plugins.builtin.achievements
-- @author whisker-core
-- @license MIT

local Tracker = require("plugins.builtin.achievements.tracker")

-- Plugin internal state
local achievements_plugin = {
  _tracker = nil,
  _ctx = nil,
}

-- Plugin definition
return {
  name = "achievements",
  version = "1.0.0",
  _trusted = true,

  author = "whisker-core",
  description = "Achievement/trophy system for stories",
  license = "MIT",

  dependencies = {
    core = "^1.0.0",
  },

  capabilities = {
    "state:read",
    "persistence:read",
    "persistence:write",
  },

  -- Lifecycle hooks
  on_init = function(ctx)
    achievements_plugin._ctx = ctx
    achievements_plugin._tracker = Tracker.new(ctx)
    ctx.log.debug("Achievements plugin initialized")
  end,

  on_enable = function(ctx)
    ctx.log.debug("Achievements plugin enabled")
  end,

  on_disable = function(ctx)
    ctx.log.debug("Achievements plugin disabled")
  end,

  on_destroy = function(ctx)
    achievements_plugin._tracker = nil
    achievements_plugin._ctx = nil
  end,

  -- Story event hooks
  hooks = {
    on_story_start = function(ctx)
      if achievements_plugin._tracker then
        achievements_plugin._tracker:initialize()
      end
    end,

    on_story_reset = function(ctx)
      if achievements_plugin._tracker then
        achievements_plugin._tracker:initialize()
      end
    end,

    on_passage_enter = function(ctx, passage)
      if achievements_plugin._tracker and passage then
        local passage_name = passage.name or passage.id or tostring(passage)
        achievements_plugin._tracker:track_passage_visit(passage_name)
        achievements_plugin._tracker:check_achievements()
      end
    end,

    on_choice_select = function(ctx, choice)
      if achievements_plugin._tracker then
        achievements_plugin._tracker:track_choice_select(choice)
        achievements_plugin._tracker:check_achievements()
      end
    end,

    on_state_change = function(ctx, changes)
      if achievements_plugin._tracker then
        achievements_plugin._tracker:track_state_change(changes)
        achievements_plugin._tracker:check_achievements()
      end
    end,

    on_save = function(save_data, ctx)
      if achievements_plugin._tracker then
        save_data.achievements = {
          achievements = achievements_plugin._tracker.achievements,
          state = achievements_plugin._tracker.state,
          tracking_data = achievements_plugin._tracker:get_tracking_data(),
        }
      end
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.achievements and achievements_plugin._tracker then
        achievements_plugin._tracker.achievements = save_data.achievements.achievements or {}
        achievements_plugin._tracker.state = save_data.achievements.state or {}
        achievements_plugin._tracker:set_tracking_data(save_data.achievements.tracking_data)
      end
      return save_data
    end,
  },

  -- Public API
  api = {
    --- Define an achievement
    -- @param achievement table Achievement definition
    -- @return boolean success
    -- @return string|nil error
    define_achievement = function(achievement)
      if not achievements_plugin._tracker then
        return false, "Achievements not initialized"
      end
      return achievements_plugin._tracker:define_achievement(achievement)
    end,

    --- Check if achievement is unlocked
    -- @param achievement_id string
    -- @return boolean
    is_unlocked = function(achievement_id)
      if not achievements_plugin._tracker then
        return false
      end
      return achievements_plugin._tracker:is_unlocked(achievement_id)
    end,

    --- Get achievement progress
    -- @param achievement_id string
    -- @return number (0-1)
    get_progress = function(achievement_id)
      if not achievements_plugin._tracker then
        return 0
      end
      return achievements_plugin._tracker:get_progress(achievement_id)
    end,

    --- Get achievement definition
    -- @param achievement_id string
    -- @return table|nil
    get_achievement = function(achievement_id)
      if not achievements_plugin._tracker then
        return nil
      end
      return achievements_plugin._tracker:get_achievement(achievement_id)
    end,

    --- Get all achievements (with current state)
    -- @return table[]
    get_all_achievements = function()
      if not achievements_plugin._tracker then
        return {}
      end
      return achievements_plugin._tracker:get_all_achievements()
    end,

    --- Get only unlocked achievements
    -- @return table[]
    get_unlocked_achievements = function()
      if not achievements_plugin._tracker then
        return {}
      end
      return achievements_plugin._tracker:get_unlocked_achievements()
    end,

    --- Get achievement statistics
    -- @return table {total, unlocked, locked, points, total_points, completion}
    get_statistics = function()
      if not achievements_plugin._tracker then
        return {total = 0, unlocked = 0, locked = 0, points = 0, total_points = 0, completion = 0}
      end
      return achievements_plugin._tracker:get_statistics()
    end,

    --- Force check all achievements
    check_achievements = function()
      if achievements_plugin._tracker then
        achievements_plugin._tracker:check_achievements()
      end
    end,

    --- Force unlock an achievement (for testing/debug)
    -- @param achievement_id string
    -- @return boolean success
    force_unlock = function(achievement_id)
      if not achievements_plugin._tracker then
        return false
      end
      return achievements_plugin._tracker:force_unlock(achievement_id)
    end,

    --- Clear all achievements
    clear = function()
      if achievements_plugin._tracker then
        achievements_plugin._tracker:clear()
      end
    end,
  },
}
