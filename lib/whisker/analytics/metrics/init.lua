--- Built-in Metrics for whisker-core Analytics
-- Calculates actionable metrics from collected events
-- @module whisker.analytics.metrics
-- @author Whisker Core Team
-- @license MIT

local Metrics = {}
Metrics.__index = Metrics
Metrics.VERSION = "1.0.0"

--- Metric calculators
Metrics._calculators = {}

--- Cached metrics
Metrics._cache = {}
Metrics._cacheTimestamp = 0
Metrics._cacheTTL = 60000 -- 1 minute cache

--- Events storage (for calculations)
Metrics._events = {}

--- Dependencies
Metrics._deps = {
  collector = nil
}

--- Get current timestamp in milliseconds
local function get_timestamp()
  return os.time() * 1000
end

--- Set dependencies
-- @param deps table Dependencies to inject
function Metrics.setDependencies(deps)
  if deps.collector then
    Metrics._deps.collector = deps.collector
  end
end

--- Initialize metrics system
function Metrics.initialize()
  Metrics._events = {}
  Metrics._cache = {}
  Metrics._cacheTimestamp = 0
end

--- Add event for metrics calculation
-- @param event table The event to add
function Metrics.addEvent(event)
  table.insert(Metrics._events, event)

  -- Invalidate cache
  Metrics._cacheTimestamp = 0
end

--- Get all metrics
-- @return table All calculated metrics
function Metrics.getAllMetrics()
  -- Check cache
  if get_timestamp() - Metrics._cacheTimestamp < Metrics._cacheTTL then
    return Metrics._cache
  end

  -- Calculate all metrics
  local metrics = {
    sessionDuration = Metrics.calculateSessionDuration(),
    completionRate = Metrics.calculateCompletionRate(),
    choiceDistribution = Metrics.calculateChoiceDistribution(),
    passageFlow = Metrics.calculatePassageFlow(),
    engagement = Metrics.calculateEngagement(),
    eventCounts = Metrics.calculateEventCounts()
  }

  -- Cache results
  Metrics._cache = metrics
  Metrics._cacheTimestamp = get_timestamp()

  return metrics
end

--- Calculate session duration metrics
-- @return table Session duration metrics
function Metrics.calculateSessionDuration()
  local sessions = {}
  local currentSession = nil

  for _, event in ipairs(Metrics._events) do
    if event.category == "story" and event.action == "start" then
      currentSession = {
        startTime = event.timestamp,
        endTime = event.timestamp
      }
      sessions[event.sessionId] = currentSession
    elseif sessions[event.sessionId] then
      sessions[event.sessionId].endTime = math.max(
        sessions[event.sessionId].endTime,
        event.timestamp
      )
    end
  end

  -- Calculate durations
  local durations = {}
  for _, session in pairs(sessions) do
    table.insert(durations, session.endTime - session.startTime)
  end

  if #durations == 0 then
    return {
      totalSessions = 0,
      averageDuration = 0,
      minDuration = 0,
      maxDuration = 0,
      totalDuration = 0
    }
  end

  -- Calculate stats
  local total = 0
  local min = durations[1]
  local max = durations[1]

  for _, d in ipairs(durations) do
    total = total + d
    min = math.min(min, d)
    max = math.max(max, d)
  end

  return {
    totalSessions = #durations,
    averageDuration = total / #durations,
    minDuration = min,
    maxDuration = max,
    totalDuration = total
  }
end

--- Calculate completion rate
-- @return table Completion rate metrics
function Metrics.calculateCompletionRate()
  local starts = 0
  local completes = 0
  local abandons = 0

  for _, event in ipairs(Metrics._events) do
    if event.category == "story" then
      if event.action == "start" then
        starts = starts + 1
      elseif event.action == "complete" then
        completes = completes + 1
      elseif event.action == "abandon" then
        abandons = abandons + 1
      end
    end
  end

  local completionRate = 0
  local abandonRate = 0

  if starts > 0 then
    completionRate = completes / starts
    abandonRate = abandons / starts
  end

  return {
    starts = starts,
    completes = completes,
    abandons = abandons,
    completionRate = completionRate,
    abandonRate = abandonRate
  }
end

--- Calculate choice distribution
-- @return table Choice distribution metrics
function Metrics.calculateChoiceDistribution()
  local choices = {}
  local passageChoices = {}

  for _, event in ipairs(Metrics._events) do
    if event.category == "choice" and event.action == "selected" then
      local passageId = event.metadata and event.metadata.passageId
      local choiceId = event.metadata and event.metadata.choiceId

      if passageId and choiceId then
        passageChoices[passageId] = passageChoices[passageId] or {}
        passageChoices[passageId][choiceId] = (passageChoices[passageId][choiceId] or 0) + 1

        choices[choiceId] = (choices[choiceId] or 0) + 1
      end
    end
  end

  -- Calculate total choices
  local totalChoices = 0
  for _, count in pairs(choices) do
    totalChoices = totalChoices + count
  end

  -- Calculate distributions
  local distribution = {}
  for choiceId, count in pairs(choices) do
    distribution[choiceId] = {
      count = count,
      percentage = totalChoices > 0 and (count / totalChoices * 100) or 0
    }
  end

  return {
    totalChoices = totalChoices,
    uniqueChoices = Metrics._tableCount(choices),
    distribution = distribution,
    byPassage = passageChoices
  }
end

--- Calculate passage flow metrics
-- @return table Passage flow metrics
function Metrics.calculatePassageFlow()
  local passageViews = {}
  local transitions = {}
  local previousPassage = nil

  for _, event in ipairs(Metrics._events) do
    if event.category == "passage" and event.action == "view" then
      local passageId = event.metadata and event.metadata.passageId

      if passageId then
        passageViews[passageId] = (passageViews[passageId] or 0) + 1

        -- Track transitions
        if previousPassage then
          local transitionKey = previousPassage .. " -> " .. passageId
          transitions[transitionKey] = (transitions[transitionKey] or 0) + 1
        end
        previousPassage = passageId
      end
    end
  end

  -- Find most viewed passages
  local topPassages = {}
  for passageId, count in pairs(passageViews) do
    table.insert(topPassages, { passageId = passageId, views = count })
  end
  table.sort(topPassages, function(a, b) return a.views > b.views end)

  return {
    totalPassageViews = Metrics._sumTable(passageViews),
    uniquePassages = Metrics._tableCount(passageViews),
    passageViews = passageViews,
    transitions = transitions,
    topPassages = topPassages
  }
end

--- Calculate engagement metrics
-- @return table Engagement metrics
function Metrics.calculateEngagement()
  local passageTimeSpent = {}
  local lastPassageView = {}

  for _, event in ipairs(Metrics._events) do
    if event.category == "passage" then
      local passageId = event.metadata and event.metadata.passageId

      if event.action == "view" and passageId then
        lastPassageView[event.sessionId] = {
          passageId = passageId,
          timestamp = event.timestamp
        }
      elseif event.action == "exit" and passageId then
        local timeOnPassage = event.metadata and event.metadata.timeOnPassage
        if timeOnPassage then
          passageTimeSpent[passageId] = passageTimeSpent[passageId] or { total = 0, count = 0 }
          passageTimeSpent[passageId].total = passageTimeSpent[passageId].total + timeOnPassage
          passageTimeSpent[passageId].count = passageTimeSpent[passageId].count + 1
        end
      end
    end
  end

  -- Calculate average time per passage
  local avgTimePerPassage = {}
  for passageId, data in pairs(passageTimeSpent) do
    avgTimePerPassage[passageId] = data.count > 0 and (data.total / data.count) or 0
  end

  -- Calculate overall engagement score (simplified)
  local totalEvents = #Metrics._events
  local sessionMetrics = Metrics.calculateSessionDuration()
  local completionMetrics = Metrics.calculateCompletionRate()

  local engagementScore = 0
  if sessionMetrics.totalSessions > 0 then
    -- Simple engagement score based on completion rate and event density
    local eventDensity = totalEvents / math.max(sessionMetrics.totalDuration / 1000, 1)
    engagementScore = (completionMetrics.completionRate * 50) + math.min(eventDensity, 50)
  end

  return {
    avgTimePerPassage = avgTimePerPassage,
    totalEvents = totalEvents,
    engagementScore = engagementScore
  }
end

--- Calculate event counts by category and action
-- @return table Event count metrics
function Metrics.calculateEventCounts()
  local byCategory = {}
  local byAction = {}
  local byCategoryAction = {}

  for _, event in ipairs(Metrics._events) do
    byCategory[event.category] = (byCategory[event.category] or 0) + 1
    byAction[event.action] = (byAction[event.action] or 0) + 1

    local key = event.category .. "." .. event.action
    byCategoryAction[key] = (byCategoryAction[key] or 0) + 1
  end

  return {
    total = #Metrics._events,
    byCategory = byCategory,
    byAction = byAction,
    byCategoryAction = byCategoryAction
  }
end

--- Get specific metric
-- @param metricName string The metric name
-- @return table The metric data
function Metrics.getMetric(metricName)
  local all = Metrics.getAllMetrics()
  return all[metricName]
end

--- Export metrics as JSON-compatible table
-- @return table Metrics for export
function Metrics.export()
  return {
    timestamp = get_timestamp(),
    metrics = Metrics.getAllMetrics(),
    eventCount = #Metrics._events
  }
end

--- Clear all events and cache
function Metrics.clear()
  Metrics._events = {}
  Metrics._cache = {}
  Metrics._cacheTimestamp = 0
end

--- Count table entries
-- @param tbl table The table
-- @return number Count
function Metrics._tableCount(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

--- Sum table values
-- @param tbl table The table
-- @return number Sum
function Metrics._sumTable(tbl)
  local sum = 0
  for _, v in pairs(tbl) do
    sum = sum + v
  end
  return sum
end

--- Reset metrics (for testing)
function Metrics.reset()
  Metrics._events = {}
  Metrics._cache = {}
  Metrics._cacheTimestamp = 0
  Metrics._deps.collector = nil
end

return Metrics
