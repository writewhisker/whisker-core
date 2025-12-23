# Whisker-Core Analytics Overview

## Introduction

Whisker-core's analytics system provides privacy-respecting event tracking that helps story creators understand player behavior and improve interactive fiction experiences. The system is built on privacy-first principles: all tracking is opt-in by default, data collection levels are granularly configurable, and users maintain complete control over their data.

## Architecture

The analytics system consists of several interconnected components:

### Event Taxonomy
Defines all trackable events including story lifecycle (start, complete, abandon), passage interactions (view, exit), choice selections, save operations, and custom events defined by story creators.

### Event Collector
Manages event collection pipeline from creation through export. Includes in-memory queuing, batching for efficient export, async processing to avoid blocking story execution, and retry logic for failed exports.

### Privacy Filter
Enforces consent levels and removes personally identifiable information (PII) based on user preferences. Ensures compliance with GDPR, CCPA, and similar privacy regulations.

### Consent Manager
Manages user consent preferences including initial consent dialog, runtime privacy settings, consent state persistence, and retroactive application of consent changes.

### Built-in Metrics
Calculates actionable metrics from events including session duration, completion rate, choice distributions, passage flow, and engagement scores.

### Export Backends
Sends events to analytics destinations through a plugin architecture. Built-in backends include console logging, memory storage, and local storage for offline support.

### A/B Testing Framework
Enables experimentation with story variants including variant assignment, exposure tracking, statistical analysis, and test lifecycle management.

## Key Concepts

### Consent Levels

**NONE (0)**: No analytics tracking whatsoever.

**ESSENTIAL (1)**: Only critical technical events for error recovery and save system reliability.

**ANALYTICS (2)**: Behavioral analytics for story improvement without user identification. Session-scoped tracking with no PII.

**FULL (3)**: Complete analytics including cross-session tracking and third-party integrations.

### Event Structure

All events follow a consistent structure:

```lua
{
  category = "passage",           -- Event category
  action = "view",                -- Specific action
  timestamp = 1638360000000,      -- Unix timestamp (ms)
  sessionId = "uuid",             -- Session identifier
  storyId = "my-story",           -- Story identifier
  metadata = {                    -- Event-specific data
    passageId = "forest_entrance",
    wordCount = 245
  }
}
```

### Privacy by Design

Privacy is built into every component:
- No tracking without consent
- PII removal at lower consent tiers
- Session-scoped IDs for anonymous tracking
- Retroactive consent application
- User-accessible data controls

## Quick Start

### Basic Integration

```lua
local Analytics = require("whisker.analytics")

-- Initialize analytics
Analytics.initialize({
  enabled = true,
  defaultConsentLevel = 0,  -- NONE
  requireConsentOnStart = true
})

-- Track custom event
Analytics.Collector.trackEvent("puzzle", "solved", {
  puzzleId = "lighthouse_riddle",
  attempts = 3,
  timeToSolve = 45000
})
```

### Configure Export Backend

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
```

### Define A/B Test

```lua
local ABTesting = require("whisker.analytics.testing")

ABTesting.defineTest({
  id = "opening_test",
  variants = {
    { id = "calm", weight = 50 },
    { id = "action", weight = 50 }
  }
})

ABTesting.startTest("opening_test")
local variant = ABTesting.getVariant("opening_test")
```

## Next Steps

- Read the [Integration Guide](integration_guide.md) for detailed setup instructions
- Review the [Event Reference](event_reference.md) for available events
- Consult the [Privacy Guide](privacy_guide.md) for compliance requirements
- Explore [Examples](../../examples/analytics/) for common scenarios
