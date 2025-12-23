# Analytics Integration Guide

Complete guide to integrating analytics into your whisker-core story.

## Installation

Analytics is built into whisker-core. No additional installation required.

## Basic Setup

### Step 1: Initialize Analytics

```lua
local Privacy = require("whisker.analytics.privacy")
local ConsentManager = require("whisker.analytics.consent_manager")
local Collector = require("whisker.analytics.collector")

-- Initialize consent manager
ConsentManager.initialize({
  defaultConsentLevel = Privacy.CONSENT_LEVELS.NONE,
  storageKey = "whisker_consent"
})

-- Initialize collector
Collector.initialize({
  batchSize = 50,
  flushInterval = 30000,
  maxQueueSize = 1000
})
```

### Step 2: Configure Export Backends

Choose where to send analytics data:

```lua
local BackendRegistry = require("whisker.analytics.backends")

BackendRegistry.configure({
  {
    type = "console",
    config = { verbose = true }
  },
  {
    type = "memory",
    config = {}
  }
})

-- Connect backends to collector
Collector.setBackends(BackendRegistry.getActiveBackends())
```

### Step 3: Show Consent Dialog (Optional)

If you require consent on start:

```lua
-- Check if consent has been set
if not ConsentManager.hasConsent() then
  -- Show your consent UI
  showConsentDialog()
end
```

## Tracking Events

### Automatic Tracking

Many events can be tracked automatically by integrating with story lifecycle:

```lua
local EventBuilder = require("whisker.analytics.event_builder")

-- When story starts
function onStoryStart(storyId, isFirstLaunch)
  local event = EventBuilder.storyStart({
    storyId = storyId,
    isFirstLaunch = isFirstLaunch
  })
  Collector.trackEvent(event.category, event.action, event.metadata)
end

-- When passage is viewed
function onPassageView(passageId, previousPassage)
  local event = EventBuilder.passageView({
    passageId = passageId,
    previousPassage = previousPassage,
    wordCount = getPassageWordCount(passageId)
  })
  Collector.trackEvent(event.category, event.action, event.metadata)
end

-- When choice is selected
function onChoiceSelected(passageId, choiceId, choiceIndex)
  local event = EventBuilder.choiceSelected({
    passageId = passageId,
    choiceId = choiceId,
    choiceIndex = choiceIndex
  })
  Collector.trackEvent(event.category, event.action, event.metadata)
end
```

### Custom Events

Track custom events specific to your story:

```lua
-- Track puzzle solve
Collector.trackEvent("puzzle", "solved", {
  puzzleId = "lighthouse_riddle",
  attempts = 3,
  hintsUsed = 1,
  timeToSolve = 45000
})

-- Track item collection
Collector.trackEvent("inventory", "item_collected", {
  itemId = "golden_key",
  location = "treasure_room"
})

-- Track achievement
Collector.trackEvent("achievement", "unlocked", {
  achievementId = "first_ending",
  playTime = 3600000
})
```

## Metrics

### View Built-in Metrics

```lua
local Metrics = require("whisker.analytics.metrics")

-- Initialize metrics
Metrics.initialize()

-- Add events for calculation
Metrics.addEvent(event)

-- Get all metrics
local allMetrics = Metrics.getAllMetrics()

print("Completion rate:", allMetrics.completionRate.completionRate)
print("Average session:", allMetrics.sessionDuration.averageDuration)
print("Total events:", allMetrics.eventCounts.total)
```

### Available Metrics

| Metric | Description |
|--------|-------------|
| `sessionDuration` | Session length statistics |
| `completionRate` | Story completion percentage |
| `choiceDistribution` | Which choices are popular |
| `passageFlow` | Passage navigation patterns |
| `engagement` | Overall engagement score |
| `eventCounts` | Event counts by category/action |

### Export Metrics

```lua
-- Export all metrics
local exported = Metrics.export()
-- Returns: { timestamp, metrics, eventCount }
```

## A/B Testing

See [A/B Testing Guide](ab_testing_guide.md) for complete tutorial.

### Quick Example

```lua
local ABTesting = require("whisker.analytics.testing")

-- Initialize
ABTesting.initialize()
ABTesting.setDependencies({
  consent_manager = ConsentManager,
  collector = Collector
})

-- Define test
ABTesting.defineTest({
  id = "opening_test",
  variants = {
    { id = "calm", weight = 50 },
    { id = "action", weight = 50 }
  }
})

-- Start test
ABTesting.startTest("opening_test")

-- Get variant for player
local variant = ABTesting.getVariant("opening_test")

-- Use variant
if variant and variant.id == "calm" then
  goToPassage("opening_calm")
else
  goToPassage("opening_action")
end
```

## Privacy Settings

Provide players access to privacy settings:

```lua
-- Change consent level
ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)

-- Get current consent
local level = ConsentManager.getConsentLevel()

-- Export user data
local data = ConsentManager.exportUserData()

-- Delete user data
ConsentManager.deleteUserData()
```

## Testing

### Debug Mode

Enable console logging for debugging:

```lua
BackendRegistry.configure({
  {
    type = "console",
    config = { verbose = true }
  }
})
```

### Memory Backend for Testing

Use memory backend in unit tests:

```lua
BackendRegistry.configure({
  {
    type = "memory",
    config = {}
  }
})

-- Track some events
Collector.trackEvent("test", "event", {})
Collector.flush()

-- Get events from memory backend
local backend = BackendRegistry.getBackend("memory")
local events = backend:getEvents()

assert(#events == 1)
assert(events[1].action == "event")
```

### Offline Testing

Use local storage backend for offline development:

```lua
BackendRegistry.configure({
  {
    type = "local-storage",
    config = {
      storageKey = "dev_analytics",
      maxEvents = 1000
    }
  }
})
```

## Production Deployment

### Security

- **Store API keys securely:** Use environment variables, not code
- **Validate backend configs:** Test connectivity before deployment
- **Monitor error rates:** Set up alerts for backend failures

### Performance

- **Tune batch size:** Larger batches = fewer requests, more latency
- **Adjust flush interval:** Shorter = more real-time, more overhead
- **Limit queue size:** Prevent memory issues on long-running sessions

```lua
Collector.initialize({
  batchSize = 100,      -- Export in batches of 100
  flushInterval = 60000, -- Flush every minute
  maxQueueSize = 5000,   -- Keep max 5000 events queued
  maxRetries = 3         -- Retry failed exports 3 times
})
```

### Privacy

- **Review consent flow:** Test on real users
- **Audit event data:** Verify no PII leaks
- **Document retention:** Specify how long data is kept

## Common Patterns

### Track Time on Passage

```lua
local passageStartTime

function onPassageEnter(passageId)
  passageStartTime = os.time() * 1000
  -- Track view event
end

function onPassageExit(passageId)
  local timeOnPassage = os.time() * 1000 - passageStartTime
  Collector.trackEvent("passage", "exit", {
    passageId = passageId,
    timeOnPassage = timeOnPassage
  })
end
```

### Track Session

```lua
local sessionStartTime

function onSessionStart()
  sessionStartTime = os.time() * 1000
  Collector.trackEvent("story", "start", {})
end

function onSessionEnd()
  local duration = os.time() * 1000 - sessionStartTime
  Collector.trackEvent("story", "complete", {
    totalTime = duration
  })
  Collector.flush()  -- Ensure events are sent
end
```

### Track with Retry

```lua
-- Collector handles retries automatically
-- Configure max retries:
Collector.initialize({
  maxRetries = 3,
  retryDelay = 1000  -- Wait 1s between retries
})
```

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues.

### Quick Checks

1. **Events not appearing?**
   - Check consent level is not NONE
   - Verify backends are configured
   - Call `Collector.flush()` to force export

2. **PII in events?**
   - Verify consent level (ANALYTICS filters PII)
   - Check PrivacyFilter is enabled

3. **A/B test not working?**
   - Ensure test is started (`startTest`)
   - Check test status is "active"
   - Verify dependencies are set
