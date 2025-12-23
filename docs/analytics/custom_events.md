# Custom Events Guide

Learn how to define and track custom events specific to your interactive fiction story.

## Overview

While whisker-core provides built-in events for common scenarios (story lifecycle, passages, choices), your story may have unique interactions worth tracking. Custom events let you capture:

- Puzzle attempts and solutions
- Inventory interactions
- Character relationships
- Mini-game scores
- Achievement unlocks
- Custom mechanics

## Defining Custom Events

### Register a Custom Category

```lua
local EventTaxonomy = require("whisker.analytics.event_taxonomy")

-- Register a new category with its actions
EventTaxonomy.registerCustomCategory("puzzle", {
  "attempt",
  "hint_used",
  "solved",
  "abandoned"
})
```

### Define Metadata Schema

Define what metadata each event action expects:

```lua
-- Schema for puzzle.solved events
EventTaxonomy.registerMetadataSchema("puzzle", "solved", {
  puzzleId = "string",       -- Required string
  attempts = "number",       -- Required number
  hintsUsed = "number?",     -- Optional number (note the ?)
  timeToSolve = "number?"    -- Optional number
})

-- Schema for puzzle.attempt events
EventTaxonomy.registerMetadataSchema("puzzle", "attempt", {
  puzzleId = "string",
  attemptNumber = "number",
  answer = "string?"
})
```

### Metadata Types

| Type | Description | Example |
|------|-------------|---------|
| `string` | Text value | `"puzzle_1"` |
| `number` | Numeric value | `42` |
| `boolean` | True/false | `true` |
| `table` | Nested data | `{x=1, y=2}` |
| `string?` | Optional string | `nil` or `"value"` |
| `number?` | Optional number | `nil` or `42` |

## Tracking Custom Events

### Basic Tracking

```lua
local Collector = require("whisker.analytics.collector")

-- Track a custom event
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "lighthouse_riddle",
  attempts = 3,
  hintsUsed = 1,
  timeToSolve = 45000
})
```

### With Validation

Events are validated against their schema:

```lua
-- This will succeed - matches schema
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "riddle_1",
  attempts = 3
})

-- This will log a warning - missing required field
Collector.trackEvent("puzzle", "solved", {
  attempts = 3  -- Missing puzzleId!
})

-- This will log a warning - wrong type
Collector.trackEvent("puzzle", "solved", {
  puzzleId = 123,  -- Should be string!
  attempts = 3
})
```

## Complete Examples

### Puzzle Tracking System

```lua
local EventTaxonomy = require("whisker.analytics.event_taxonomy")
local Collector = require("whisker.analytics.collector")

-- Define puzzle events
EventTaxonomy.registerCustomCategory("puzzle", {
  "started",
  "attempt",
  "hint_used",
  "solved",
  "abandoned"
})

EventTaxonomy.registerMetadataSchema("puzzle", "started", {
  puzzleId = "string",
  difficulty = "number?"
})

EventTaxonomy.registerMetadataSchema("puzzle", "attempt", {
  puzzleId = "string",
  attemptNumber = "number"
})

EventTaxonomy.registerMetadataSchema("puzzle", "hint_used", {
  puzzleId = "string",
  hintNumber = "number",
  hintsRemaining = "number?"
})

EventTaxonomy.registerMetadataSchema("puzzle", "solved", {
  puzzleId = "string",
  attempts = "number",
  hintsUsed = "number",
  timeToSolve = "number"
})

EventTaxonomy.registerMetadataSchema("puzzle", "abandoned", {
  puzzleId = "string",
  attempts = "number",
  lastHint = "number?"
})

-- Puzzle manager class
local PuzzleManager = {}

function PuzzleManager.new(puzzleId, difficulty)
  local self = {
    puzzleId = puzzleId,
    difficulty = difficulty or 1,
    attempts = 0,
    hintsUsed = 0,
    maxHints = 3,
    startTime = os.time() * 1000
  }

  -- Track puzzle start
  Collector.trackEvent("puzzle", "started", {
    puzzleId = puzzleId,
    difficulty = difficulty
  })

  return setmetatable(self, { __index = PuzzleManager })
end

function PuzzleManager:attempt(answer)
  self.attempts = self.attempts + 1

  Collector.trackEvent("puzzle", "attempt", {
    puzzleId = self.puzzleId,
    attemptNumber = self.attempts
  })

  return self:checkAnswer(answer)
end

function PuzzleManager:useHint()
  if self.hintsUsed >= self.maxHints then
    return nil
  end

  self.hintsUsed = self.hintsUsed + 1

  Collector.trackEvent("puzzle", "hint_used", {
    puzzleId = self.puzzleId,
    hintNumber = self.hintsUsed,
    hintsRemaining = self.maxHints - self.hintsUsed
  })

  return self:getHint(self.hintsUsed)
end

function PuzzleManager:solve()
  local timeToSolve = os.time() * 1000 - self.startTime

  Collector.trackEvent("puzzle", "solved", {
    puzzleId = self.puzzleId,
    attempts = self.attempts,
    hintsUsed = self.hintsUsed,
    timeToSolve = timeToSolve
  })
end

function PuzzleManager:abandon()
  Collector.trackEvent("puzzle", "abandoned", {
    puzzleId = self.puzzleId,
    attempts = self.attempts,
    lastHint = self.hintsUsed > 0 and self.hintsUsed or nil
  })
end

return PuzzleManager
```

### Inventory Tracking

```lua
-- Define inventory events
EventTaxonomy.registerCustomCategory("inventory", {
  "item_found",
  "item_used",
  "item_combined",
  "item_discarded"
})

EventTaxonomy.registerMetadataSchema("inventory", "item_found", {
  itemId = "string",
  location = "string",
  isHidden = "boolean?"
})

EventTaxonomy.registerMetadataSchema("inventory", "item_used", {
  itemId = "string",
  usedOn = "string?",
  successful = "boolean"
})

EventTaxonomy.registerMetadataSchema("inventory", "item_combined", {
  item1 = "string",
  item2 = "string",
  result = "string?"
})

-- Usage
function onItemFound(itemId, location, hidden)
  Collector.trackEvent("inventory", "item_found", {
    itemId = itemId,
    location = location,
    isHidden = hidden
  })
end

function onItemUsed(itemId, target, success)
  Collector.trackEvent("inventory", "item_used", {
    itemId = itemId,
    usedOn = target,
    successful = success
  })
end
```

### Character Relationship Tracking

```lua
-- Define relationship events
EventTaxonomy.registerCustomCategory("relationship", {
  "met",
  "improved",
  "damaged",
  "milestone"
})

EventTaxonomy.registerMetadataSchema("relationship", "improved", {
  characterId = "string",
  previousLevel = "number",
  newLevel = "number",
  cause = "string?"
})

EventTaxonomy.registerMetadataSchema("relationship", "milestone", {
  characterId = "string",
  milestoneId = "string",
  level = "number"
})

-- Track relationship changes
function onRelationshipChange(characterId, oldLevel, newLevel, reason)
  if newLevel > oldLevel then
    Collector.trackEvent("relationship", "improved", {
      characterId = characterId,
      previousLevel = oldLevel,
      newLevel = newLevel,
      cause = reason
    })
  else
    Collector.trackEvent("relationship", "damaged", {
      characterId = characterId,
      previousLevel = oldLevel,
      newLevel = newLevel,
      cause = reason
    })
  end

  -- Check for milestones
  if newLevel >= 50 and oldLevel < 50 then
    Collector.trackEvent("relationship", "milestone", {
      characterId = characterId,
      milestoneId = "friend",
      level = newLevel
    })
  end
end
```

### Achievement System

```lua
EventTaxonomy.registerCustomCategory("achievement", {
  "progress",
  "unlocked"
})

EventTaxonomy.registerMetadataSchema("achievement", "progress", {
  achievementId = "string",
  currentProgress = "number",
  targetProgress = "number"
})

EventTaxonomy.registerMetadataSchema("achievement", "unlocked", {
  achievementId = "string",
  playTime = "number?",
  isSecret = "boolean?"
})

-- Track achievement progress
function updateAchievementProgress(achievementId, current, target)
  Collector.trackEvent("achievement", "progress", {
    achievementId = achievementId,
    currentProgress = current,
    targetProgress = target
  })

  if current >= target then
    Collector.trackEvent("achievement", "unlocked", {
      achievementId = achievementId,
      playTime = getPlayTime(),
      isSecret = isSecretAchievement(achievementId)
    })
  end
end
```

## Best Practices

### 1. Use Descriptive IDs

```lua
-- Good: Clear, descriptive IDs
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "lighthouse_crystal_puzzle"
})

-- Bad: Cryptic IDs
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "p42"
})
```

### 2. Include Context

```lua
-- Good: Include relevant context
Collector.trackEvent("inventory", "item_used", {
  itemId = "rusty_key",
  usedOn = "cellar_door",
  location = "abandoned_house",
  successful = true
})

-- Bad: Missing context
Collector.trackEvent("inventory", "item_used", {
  itemId = "rusty_key"
})
```

### 3. Avoid PII

```lua
-- Good: No personal info
Collector.trackEvent("user", "feedback", {
  rating = 5,
  category = "story"
})

-- Bad: Contains PII (will be filtered anyway)
Collector.trackEvent("user", "feedback", {
  rating = 5,
  userEmail = "user@example.com"  -- PII!
})
```

### 4. Use Consistent Naming

```lua
-- Good: Consistent snake_case
{ puzzleId = "...", timeToSolve = 1000, hintsUsed = 2 }

-- Bad: Mixed conventions
{ puzzleID = "...", TimeToSolve = 1000, hints_used = 2 }
```

### 5. Keep Metadata Minimal

```lua
-- Good: Essential data only
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "riddle_1",
  attempts = 3,
  timeToSolve = 45000
})

-- Bad: Excessive data
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "riddle_1",
  attempts = 3,
  timeToSolve = 45000,
  allPreviousGuesses = {...},  -- Too much data
  fullGameState = {...}         -- Excessive
})
```

## Analyzing Custom Events

Custom events flow through the same analytics pipeline:

```lua
local Metrics = require("whisker.analytics.metrics")

-- Add custom event to metrics
Metrics.addEvent({
  category = "puzzle",
  action = "solved",
  timestamp = os.time() * 1000,
  sessionId = "...",
  metadata = {
    puzzleId = "riddle_1",
    attempts = 3
  }
})

-- Get event counts
local counts = Metrics.calculateEventCounts()
print("Total puzzle events:", counts.byCategory.puzzle)
print("Puzzles solved:", counts.byAction.solved)
```

For more complex analysis, export events and analyze externally or build custom metric calculations.
