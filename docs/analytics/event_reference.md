# Event Reference

Complete reference of all analytics events in whisker-core.

## Event Structure

Every event contains:

| Field | Type | Description |
|-------|------|-------------|
| `category` | string | Event category |
| `action` | string | Specific action within category |
| `timestamp` | number | Unix timestamp in milliseconds |
| `sessionId` | string | Session identifier |
| `storyId` | string | Story identifier |
| `storyVersion` | string | Story version |
| `metadata` | table | Event-specific data |

## Story Events

### story.start

Fired when story begins (first launch or new story).

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `isFirstLaunch` | boolean | No | First time story has been launched |
| `restoreFromSave` | boolean | No | Whether starting from save |
| `initialPassage` | string | No | First passage ID |

**Example:**
```lua
{
  category = "story",
  action = "start",
  metadata = {
    isFirstLaunch = true,
    restoreFromSave = false,
    initialPassage = "opening"
  }
}
```

### story.resume

Fired when story resumes from previous session.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `lastSessionTime` | number | No | Last session timestamp |
| `resumePassage` | string | No | Passage being resumed at |
| `totalSessions` | number | No | Total number of sessions |

### story.complete

Fired when story reaches an ending.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `endingId` | string | No | Identifier of the ending reached |
| `totalTime` | number | No | Total time spent in ms |
| `passagesVisited` | number | No | Number of unique passages visited |
| `choicesMade` | number | No | Total choices made |

### story.abandon

Fired when story is abandoned without completion.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `lastPassage` | string | No | Last visited passage |
| `sessionDuration` | number | No | Duration of current session |
| `progress` | number | No | Estimated progress percentage |

## Passage Events

### passage.view

Fired when passage is displayed to player.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `passageId` | string | Yes | Passage identifier |
| `passageName` | string | No | Passage display name |
| `wordCount` | number | No | Number of words in passage |
| `previousPassage` | string | No | Previous passage ID |
| `transitionType` | string | No | "choice", "automatic", "restart" |
| `estimatedReadTime` | number | No | Estimated read time in ms |

**Example:**
```lua
{
  category = "passage",
  action = "view",
  metadata = {
    passageId = "forest_entrance",
    wordCount = 245,
    previousPassage = "village_gate",
    transitionType = "choice"
  }
}
```

### passage.exit

Fired when player leaves a passage.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `passageId` | string | Yes | Passage identifier |
| `timeOnPassage` | number | No | Time spent on passage in ms |
| `scrollDepth` | number | No | How far player scrolled (0-100) |

## Choice Events

### choice.presented

Fired when choices are shown to player.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `passageId` | string | Yes | Current passage ID |
| `choiceCount` | number | Yes | Number of choices presented |
| `choiceIds` | table | No | Array of choice identifiers |

### choice.selected

Fired when player selects a choice.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `passageId` | string | Yes | Current passage ID |
| `choiceId` | string | Yes | Selected choice identifier |
| `choiceIndex` | number | No | Position of choice (1-indexed) |
| `timeToChoose` | number | No | Time from presentation to selection |
| `totalChoices` | number | No | Total choices available |

**Example:**
```lua
{
  category = "choice",
  action = "selected",
  metadata = {
    passageId = "crossroads",
    choiceId = "go_left",
    choiceIndex = 1,
    timeToChoose = 3500,
    totalChoices = 3
  }
}
```

## Save Events

### save.created

Fired when a save is created.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `saveSlot` | string | Yes | Save slot identifier |
| `isAutoSave` | boolean | No | Whether this is an auto-save |
| `passageId` | string | No | Current passage at save time |

### save.loaded

Fired when a save is loaded.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `saveSlot` | string | Yes | Save slot identifier |
| `saveAge` | number | No | Age of save in ms |

### save.deleted

Fired when a save is deleted.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `saveSlot` | string | Yes | Save slot identifier |

## Error Events

### error.runtime

Fired when a runtime error occurs.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `errorType` | string | Yes | Type/category of error |
| `errorMessage` | string | Yes | Error message |
| `passageId` | string | No | Passage where error occurred |
| `stackTrace` | string | No | Stack trace (if available) |

### error.script

Fired when a script error occurs.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `errorType` | string | Yes | Type of script error |
| `errorMessage` | string | Yes | Error message |
| `lineNumber` | number | No | Line number in script |
| `scriptContext` | string | No | Context where error occurred |

## User Events

### user.feedback

Fired when user provides feedback.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `rating` | number | No | Numerical rating |
| `category` | string | No | Feedback category |

**Note:** The `feedbackText` field is automatically redacted by the privacy filter.

## Test Events

### test.exposure

Fired when user is exposed to an A/B test variant.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `testId` | string | Yes | Test identifier |
| `testName` | string | No | Human-readable test name |
| `variantId` | string | Yes | Assigned variant ID |
| `variantName` | string | No | Human-readable variant name |

### test.conversion

Fired when a conversion event occurs for an A/B test.

**Metadata:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `testId` | string | Yes | Test identifier |
| `variantId` | string | Yes | User's variant ID |
| `conversionType` | string | Yes | Type of conversion |
| `value` | number | No | Conversion value |

## Custom Events

Story creators can define custom events using the event taxonomy:

```lua
local EventTaxonomy = require("whisker.analytics.event_taxonomy")

-- Register custom category
EventTaxonomy.registerCustomCategory("puzzle", {
  "attempt",
  "hint_used",
  "solved",
  "abandoned"
})

-- Register metadata schema
EventTaxonomy.registerMetadataSchema("puzzle", "solved", {
  puzzleId = "string",
  attempts = "number",
  hintsUsed = "number",
  timeToSolve = "number"
})
```

See [Custom Events Guide](custom_events.md) for details.

## Event Categories Summary

| Category | Actions | Description |
|----------|---------|-------------|
| `story` | start, resume, complete, abandon | Story lifecycle events |
| `passage` | view, exit | Passage navigation events |
| `choice` | presented, selected | Choice interaction events |
| `save` | created, loaded, deleted | Save system events |
| `error` | runtime, script | Error tracking events |
| `user` | feedback | User interaction events |
| `test` | exposure, conversion | A/B testing events |
