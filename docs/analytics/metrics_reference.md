# Metrics Reference

Complete reference for built-in analytics metrics in whisker-core.

## Overview

The metrics module calculates actionable insights from raw analytics events. Metrics are computed on-demand and cached for performance.

```lua
local Metrics = require("whisker.analytics.metrics")

Metrics.initialize()
Metrics.addEvent(event)  -- Add events for calculation
local all = Metrics.getAllMetrics()  -- Get all metrics
```

## Session Duration

Tracks how long players spend in your story.

### Function
```lua
local metrics = Metrics.calculateSessionDuration()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `totalSessions` | number | Number of sessions |
| `totalDuration` | number | Total time across all sessions (ms) |
| `averageDuration` | number | Average session length (ms) |
| `minDuration` | number | Shortest session (ms) |
| `maxDuration` | number | Longest session (ms) |

### How It's Calculated

- Sessions are identified by unique `sessionId`
- Duration = last event timestamp - first event timestamp per session

### Example
```lua
local duration = Metrics.calculateSessionDuration()

print(string.format(
  "Average session: %.1f minutes",
  duration.averageDuration / 60000
))
```

## Completion Rate

Measures how many players finish your story.

### Function
```lua
local metrics = Metrics.calculateCompletionRate()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `starts` | number | Number of `story.start` events |
| `completes` | number | Number of `story.complete` events |
| `abandons` | number | Number of `story.abandon` events |
| `completionRate` | number | Ratio of completes to starts (0-1) |
| `abandonRate` | number | Ratio of abandons to starts (0-1) |

### How It's Calculated

- Counts story lifecycle events
- `completionRate = completes / starts`
- `abandonRate = abandons / starts`

### Example
```lua
local completion = Metrics.calculateCompletionRate()

print(string.format(
  "Completion: %.1f%% (%d/%d)",
  completion.completionRate * 100,
  completion.completes,
  completion.starts
))

if completion.abandonRate > 0.5 then
  print("Warning: High abandon rate!")
end
```

## Choice Distribution

Analyzes which choices players select.

### Function
```lua
local metrics = Metrics.calculateChoiceDistribution()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `totalChoices` | number | Total choice selections |
| `uniqueChoices` | number | Number of unique choices |
| `distribution` | table | Count and percentage per choice |
| `byPassage` | table | Choices grouped by passage |

### Distribution Entry
Each entry in `distribution`:
| Field | Type | Description |
|-------|------|-------------|
| `count` | number | Times this choice was selected |
| `percentage` | number | Percentage of total (0-100) |

### How It's Calculated

- Counts `choice.selected` events
- Groups by `choiceId` in metadata
- Also groups by `passageId` for context

### Example
```lua
local choices = Metrics.calculateChoiceDistribution()

print("Most popular choices:")
for choiceId, data in pairs(choices.distribution) do
  print(string.format(
    "  %s: %d selections (%.1f%%)",
    choiceId, data.count, data.percentage
  ))
end

-- Choices at specific passage
local crossroads = choices.byPassage.crossroads
if crossroads then
  print("\nAt crossroads:")
  for choiceId, count in pairs(crossroads) do
    print("  " .. choiceId .. ": " .. count)
  end
end
```

## Passage Flow

Tracks how players navigate through passages.

### Function
```lua
local metrics = Metrics.calculatePassageFlow()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `totalPassageViews` | number | Total passage view events |
| `uniquePassages` | number | Number of unique passages |
| `passageViews` | table | View count per passage |
| `transitions` | table | Count of A -> B transitions |
| `topPassages` | array | Most viewed passages (sorted) |

### Top Passages Entry
Each entry in `topPassages`:
| Field | Type | Description |
|-------|------|-------------|
| `passageId` | string | Passage identifier |
| `views` | number | Number of views |

### How It's Calculated

- Counts `passage.view` events
- Tracks previous passage to current passage transitions
- Sorted by view count descending

### Example
```lua
local flow = Metrics.calculatePassageFlow()

print("Top 5 passages:")
for i = 1, math.min(5, #flow.topPassages) do
  local p = flow.topPassages[i]
  print(string.format("  %d. %s (%d views)", i, p.passageId, p.views))
end

print("\nCommon paths:")
for path, count in pairs(flow.transitions) do
  if count > 10 then
    print("  " .. path .. ": " .. count)
  end
end
```

## Engagement

Calculates overall player engagement.

### Function
```lua
local metrics = Metrics.calculateEngagement()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `totalEvents` | number | Total events tracked |
| `uniqueSessions` | number | Number of unique sessions |
| `eventsPerSession` | number | Average events per session |
| `avgTimePerPassage` | table | Time spent per passage (ms) |
| `engagementScore` | number | Composite engagement score (0-100) |

### How It's Calculated

- Engagement score combines:
  - Event frequency
  - Session duration
  - Passage completion
  - Choice interaction

### Example
```lua
local engagement = Metrics.calculateEngagement()

print(string.format(
  "Engagement score: %.0f/100",
  engagement.engagementScore
))

print("\nTime per passage:")
for passageId, avgTime in pairs(engagement.avgTimePerPassage) do
  print(string.format(
    "  %s: %.1f seconds",
    passageId, avgTime / 1000
  ))
end
```

## Event Counts

Provides raw counts of events.

### Function
```lua
local metrics = Metrics.calculateEventCounts()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `total` | number | Total event count |
| `byCategory` | table | Count per category |
| `byAction` | table | Count per action |
| `byCategoryAction` | table | Count per category.action |

### Example
```lua
local counts = Metrics.calculateEventCounts()

print("Event counts:")
print("  Total:", counts.total)
print("\nBy category:")
for category, count in pairs(counts.byCategory) do
  print(string.format("  %s: %d", category, count))
end

print("\nBy action:")
for action, count in pairs(counts.byAction) do
  print(string.format("  %s: %d", action, count))
end
```

## Aggregated Metrics

Get all metrics at once.

### Function
```lua
local metrics = Metrics.getAllMetrics()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `sessionDuration` | table | Session duration metrics |
| `completionRate` | table | Completion rate metrics |
| `choiceDistribution` | table | Choice distribution metrics |
| `passageFlow` | table | Passage flow metrics |
| `engagement` | table | Engagement metrics |
| `eventCounts` | table | Event count metrics |

### Example
```lua
local all = Metrics.getAllMetrics()

print("=== Story Analytics Report ===")
print(string.format(
  "Sessions: %d (avg %.1f min)",
  all.sessionDuration.totalSessions,
  all.sessionDuration.averageDuration / 60000
))
print(string.format(
  "Completion: %.1f%%",
  all.completionRate.completionRate * 100
))
print(string.format(
  "Engagement: %.0f/100",
  all.engagement.engagementScore
))
print(string.format(
  "Events tracked: %d",
  all.eventCounts.total
))
```

## Specific Metrics

Get a single metric by name.

### Function
```lua
local metric = Metrics.getMetric(name)
```

### Available Names
- `"sessionDuration"`
- `"completionRate"`
- `"choiceDistribution"`
- `"passageFlow"`
- `"engagement"`
- `"eventCounts"`

### Example
```lua
local completion = Metrics.getMetric("completionRate")
print("Completion rate:", completion.completionRate)
```

## Export

Export metrics with metadata.

### Function
```lua
local exported = Metrics.export()
```

### Returns
| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | number | Export timestamp (ms) |
| `eventCount` | number | Number of events analyzed |
| `metrics` | table | All calculated metrics |

### Example
```lua
local exported = Metrics.export()

-- Convert to JSON for external analysis
local json = require("json")
local jsonStr = json.encode(exported)

-- Save to file
local f = io.open("metrics.json", "w")
f:write(jsonStr)
f:close()
```

## Clear and Reset

### Clear Events
```lua
Metrics.clear()  -- Clear events and cache
```

### Reset Module
```lua
Metrics.reset()  -- Full reset
```

## Performance Considerations

- Metrics are cached after first calculation
- Cache is invalidated when events are added
- For large event sets, consider:
  - Periodic export and clear
  - Sampling for real-time metrics
  - Pre-aggregation on export

```lua
-- Export and clear periodically
if Metrics.calculateEventCounts().total > 10000 then
  local exported = Metrics.export()
  saveToStorage(exported)
  Metrics.clear()
end
```
