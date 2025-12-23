--- Achievement Tracker Module
-- Tracks achievement definitions, progress, and unlocks
-- @module plugins.builtin.achievements.tracker
-- @author whisker-core
-- @license MIT

local Tracker = {}
Tracker.__index = Tracker

--- Create new tracker instance
-- @param ctx PluginContext Plugin context
-- @return Tracker
function Tracker.new(ctx)
  local self = setmetatable({}, Tracker)

  self.ctx = ctx
  self.achievements = {}        -- achievement_id -> definition
  self.state = {}               -- achievement_id -> state
  self.tracking_data = {        -- Global tracking
    passages_visited = {},
    passage_count = 0,
    choices_made = 0,
    start_time = nil,
  }

  return self
end

--- Initialize achievement tracking
function Tracker:initialize()
  -- Reset tracking data, keep definitions
  self.tracking_data = {
    passages_visited = {},
    passage_count = 0,
    choices_made = 0,
    start_time = os.time(),
  }

  -- Reset state for all defined achievements
  for id in pairs(self.achievements) do
    if not self.state[id] then
      self.state[id] = {
        unlocked = false,
        progress = 0,
        unlock_time = nil,
        metadata = {},
      }
    end
  end

  if self.ctx and self.ctx.log then
    self.ctx.log.debug("Achievement tracking initialized")
  end
end

--- Define an achievement
-- @param achievement table Achievement definition
-- @return boolean success
-- @return string|nil error
function Tracker:define_achievement(achievement)
  if not achievement then
    return false, "Achievement is nil"
  end

  if not achievement.id then
    return false, "Achievement must have 'id'"
  end

  if not achievement.name then
    return false, "Achievement must have 'name'"
  end

  if not achievement.criteria then
    return false, "Achievement must have 'criteria'"
  end

  -- Set defaults
  achievement.description = achievement.description or ""
  achievement.points = achievement.points or 0
  achievement.secret = achievement.secret or false
  achievement.icon = achievement.icon or "🏆"

  -- Store definition
  self.achievements[achievement.id] = achievement

  -- Initialize state if not exists
  if not self.state[achievement.id] then
    self.state[achievement.id] = {
      unlocked = false,
      progress = 0,
      unlock_time = nil,
      metadata = {},
    }
  end

  if self.ctx and self.ctx.log then
    self.ctx.log.debug(string.format(
      "Defined achievement: %s (%s)",
      achievement.id,
      achievement.name
    ))
  end

  return true
end

--- Track passage visit
-- @param passage_name string
function Tracker:track_passage_visit(passage_name)
  if not self.tracking_data.passages_visited[passage_name] then
    self.tracking_data.passages_visited[passage_name] = true
    self.tracking_data.passage_count = self.tracking_data.passage_count + 1

    if self.ctx and self.ctx.log then
      self.ctx.log.debug(string.format(
        "Tracked passage: %s (total: %d)",
        passage_name,
        self.tracking_data.passage_count
      ))
    end
  end
end

--- Track choice selection
-- @param choice table
function Tracker:track_choice_select(choice)
  self.tracking_data.choices_made = self.tracking_data.choices_made + 1
end

--- Track state changes
-- @param changes table Map of variable -> value
function Tracker:track_state_change(changes)
  -- Can be extended to track specific variable changes
end

--- Check all achievements for completion
function Tracker:check_achievements()
  for achievement_id, achievement in pairs(self.achievements) do
    local state = self.state[achievement_id]

    if not state.unlocked then
      local unlocked, progress = self:evaluate_achievement(achievement)

      state.progress = progress

      if unlocked then
        self:unlock_achievement(achievement_id)
      end
    end
  end
end

--- Evaluate achievement criteria
-- @param achievement table Achievement definition
-- @return boolean unlocked
-- @return number progress (0-1)
function Tracker:evaluate_achievement(achievement)
  local criteria = achievement.criteria
  local criteria_type = criteria.type

  if criteria_type == "passage_visited" then
    local visited = self.tracking_data.passages_visited[criteria.passage] == true
    return visited, visited and 1 or 0

  elseif criteria_type == "passage_count" then
    local count = self.tracking_data.passage_count
    local target = criteria.count or 1
    local progress = math.min(count / target, 1)
    return count >= target, progress

  elseif criteria_type == "choice_count" then
    local count = self.tracking_data.choices_made
    local target = criteria.count or 1
    local progress = math.min(count / target, 1)
    return count >= target, progress

  elseif criteria_type == "variable_threshold" then
    local value = 0
    if self.ctx and self.ctx.state then
      value = self.ctx.state.get(criteria.variable) or 0
    end
    local target = criteria.threshold or 1
    if target == 0 then
      return value >= target, 1
    end
    local progress = math.min(math.max(value / target, 0), 1)
    return value >= target, progress

  elseif criteria_type == "variable_equals" then
    local value = nil
    if self.ctx and self.ctx.state then
      value = self.ctx.state.get(criteria.variable)
    end
    local matches = value == criteria.value
    return matches, matches and 1 or 0

  elseif criteria_type == "custom" then
    if type(criteria.check) == "function" then
      local success, result = pcall(criteria.check, self.ctx, self.tracking_data)
      if success then
        if type(result) == "boolean" then
          return result, result and 1 or 0
        elseif type(result) == "number" then
          return result >= 1, math.min(result, 1)
        end
      end
    end
    return false, 0

  else
    if self.ctx and self.ctx.log then
      self.ctx.log.warn("Unknown criteria type: " .. tostring(criteria_type))
    end
    return false, 0
  end
end

--- Unlock an achievement
-- @param achievement_id string
function Tracker:unlock_achievement(achievement_id)
  local achievement = self.achievements[achievement_id]
  local state = self.state[achievement_id]

  if not achievement or not state then
    return
  end

  if state.unlocked then
    return  -- Already unlocked
  end

  state.unlocked = true
  state.progress = 1
  state.unlock_time = os.time()

  if self.ctx and self.ctx.log then
    self.ctx.log.info(string.format(
      "Achievement unlocked: %s - %s",
      achievement_id,
      achievement.name
    ))
  end

  -- Trigger notification
  self:notify_unlock(achievement)
end

--- Notify about achievement unlock
-- @param achievement table
function Tracker:notify_unlock(achievement)
  -- Can be extended with proper UI notification
  local icon = achievement.icon or "🏆"
  local message = string.format(
    "%s Achievement Unlocked: %s",
    icon,
    achievement.name
  )

  if self.ctx and self.ctx.log then
    self.ctx.log.info(message)
  end
end

--- Force unlock achievement (for testing/cheats)
-- @param achievement_id string
-- @return boolean success
function Tracker:force_unlock(achievement_id)
  if not self.achievements[achievement_id] then
    return false
  end

  self:unlock_achievement(achievement_id)
  return true
end

--- Check if achievement is unlocked
-- @param achievement_id string
-- @return boolean
function Tracker:is_unlocked(achievement_id)
  local state = self.state[achievement_id]
  return state and state.unlocked or false
end

--- Get achievement progress
-- @param achievement_id string
-- @return number (0-1)
function Tracker:get_progress(achievement_id)
  local state = self.state[achievement_id]
  return state and state.progress or 0
end

--- Get achievement definition
-- @param achievement_id string
-- @return table|nil
function Tracker:get_achievement(achievement_id)
  return self.achievements[achievement_id]
end

--- Get all achievements (with state)
-- @return table[] Array of achievement info
function Tracker:get_all_achievements()
  local all = {}

  for achievement_id, achievement in pairs(self.achievements) do
    local state = self.state[achievement_id]

    -- Hide secret achievements until unlocked
    if achievement.secret and not state.unlocked then
      table.insert(all, {
        id = achievement_id,
        name = "???",
        description = "Secret achievement",
        points = achievement.points,
        icon = "❓",
        secret = true,
        unlocked = false,
        progress = 0,
      })
    else
      table.insert(all, {
        id = achievement_id,
        name = achievement.name,
        description = achievement.description,
        points = achievement.points,
        icon = achievement.icon,
        secret = achievement.secret,
        unlocked = state.unlocked,
        progress = state.progress,
        unlock_time = state.unlock_time,
      })
    end
  end

  -- Sort: unlocked first, then by points (descending)
  table.sort(all, function(a, b)
    if a.unlocked ~= b.unlocked then
      return a.unlocked
    end
    return (a.points or 0) > (b.points or 0)
  end)

  return all
end

--- Get only unlocked achievements
-- @return table[]
function Tracker:get_unlocked_achievements()
  local unlocked = {}

  for achievement_id, achievement in pairs(self.achievements) do
    local state = self.state[achievement_id]
    if state.unlocked then
      table.insert(unlocked, {
        id = achievement_id,
        name = achievement.name,
        description = achievement.description,
        points = achievement.points,
        icon = achievement.icon,
        unlock_time = state.unlock_time,
      })
    end
  end

  -- Sort by unlock time (newest first)
  table.sort(unlocked, function(a, b)
    return (a.unlock_time or 0) > (b.unlock_time or 0)
  end)

  return unlocked
end

--- Get achievement statistics
-- @return table
function Tracker:get_statistics()
  local total = 0
  local unlocked = 0
  local points = 0
  local total_points = 0

  for achievement_id, achievement in pairs(self.achievements) do
    total = total + 1
    total_points = total_points + (achievement.points or 0)

    local state = self.state[achievement_id]
    if state and state.unlocked then
      unlocked = unlocked + 1
      points = points + (achievement.points or 0)
    end
  end

  return {
    total = total,
    unlocked = unlocked,
    locked = total - unlocked,
    points = points,
    total_points = total_points,
    completion = total > 0 and (unlocked / total) or 0,
  }
end

--- Clear all achievements and state
function Tracker:clear()
  self.achievements = {}
  self.state = {}
  self.tracking_data = {
    passages_visited = {},
    passage_count = 0,
    choices_made = 0,
    start_time = os.time(),
  }
end

--- Get tracking data (for persistence)
-- @return table
function Tracker:get_tracking_data()
  return self.tracking_data
end

--- Set tracking data (from persistence)
-- @param data table
function Tracker:set_tracking_data(data)
  self.tracking_data = data or {
    passages_visited = {},
    passage_count = 0,
    choices_made = 0,
    start_time = os.time(),
  }
end

return Tracker
