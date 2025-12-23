# A/B Testing Guide

Learn how to run controlled experiments in your interactive fiction to optimize player experience.

## Overview

A/B testing (also called split testing) lets you compare different versions of your story to see which performs better. The whisker-core A/B testing framework provides:

- **Test Definition**: Create tests with multiple variants
- **Consistent Assignment**: Players see the same variant across sessions
- **Exposure Tracking**: Know when players see each variant
- **Conversion Tracking**: Measure outcomes for each variant
- **Statistical Analysis**: Determine if differences are significant

## Quick Start

```lua
local ABTesting = require("whisker.analytics.testing")

-- Initialize
ABTesting.initialize()

-- Define a test
ABTesting.defineTest({
  id = "opening_scene",
  name = "Opening Scene Test",
  variants = {
    { id = "calm", weight = 50 },
    { id = "action", weight = 50 }
  }
})

-- Start the test
ABTesting.startTest("opening_scene")

-- Get variant for player
local variant = ABTesting.getVariant("opening_scene")

-- Use variant
if variant.id == "calm" then
  goToPassage("opening_calm")
else
  goToPassage("opening_action")
end
```

## Defining Tests

### Basic Test Definition

```lua
ABTesting.defineTest({
  id = "opening_scene",           -- Unique identifier
  name = "Opening Scene Test",    -- Human-readable name
  variants = {
    { id = "control", weight = 50 },
    { id = "treatment", weight = 50 }
  }
})
```

### Weighted Variants

Assign different traffic percentages:

```lua
ABTesting.defineTest({
  id = "new_feature",
  variants = {
    { id = "control", weight = 90 },    -- 90% of users
    { id = "treatment", weight = 10 }   -- 10% of users
  }
})
```

### Multiple Variants

Test more than two options:

```lua
ABTesting.defineTest({
  id = "difficulty_test",
  variants = {
    { id = "easy", weight = 33 },
    { id = "medium", weight = 34 },
    { id = "hard", weight = 33 }
  }
})
```

### Advanced Options

```lua
ABTesting.defineTest({
  id = "comprehensive_test",
  name = "Opening Experience",
  description = "Testing different opening sequences for engagement",
  variants = {
    { id = "control_tutorial", name = "With Tutorial", weight = 50 },
    { id = "no_tutorial", name = "Without Tutorial", weight = 50 }
  },
  minSampleSize = 100,      -- Minimum users per variant
  confidenceLevel = 0.95    -- Statistical confidence level
})
```

## Test Lifecycle

### States

| State | Description |
|-------|-------------|
| `draft` | Test defined but not running |
| `active` | Test is running, assigning variants |
| `paused` | Test paused, keeping assignments |
| `completed` | Test finished, assignments locked |
| `archived` | Test archived, no longer visible |

### Managing Test State

```lua
-- Start a draft test
ABTesting.startTest("opening_scene")  -- draft -> active

-- Pause a running test
ABTesting.pauseTest("opening_scene")  -- active -> paused

-- Resume a paused test
ABTesting.startTest("opening_scene")  -- paused -> active

-- Complete a test (lock results)
ABTesting.completeTest("opening_scene")  -- any -> completed

-- Archive a test
ABTesting.archiveTest("opening_scene")  -- any -> archived
```

### Check Test Status

```lua
local test = ABTesting.getTest("opening_scene")
print("Status:", test.status)
print("Created:", test.createdAt)
print("Started:", test.startDate)
```

## Variant Assignment

### How Assignment Works

1. Player requests variant via `getVariant()`
2. System generates deterministic hash from user ID + test ID
3. Hash determines which variant bucket the player falls into
4. Assignment is cached for consistency
5. Exposure event is tracked

### Getting Variants

```lua
-- Get assigned variant
local variant = ABTesting.getVariant("opening_scene")

if variant then
  print("Assigned to:", variant.id)
else
  -- Test not active or doesn't exist
  print("No variant assigned")
end
```

### Consistent Assignment

Same player always gets same variant:

```lua
local v1 = ABTesting.getVariant("opening_scene")
local v2 = ABTesting.getVariant("opening_scene")
-- v1.id == v2.id (always)
```

### Manual Assignment Check

```lua
local userId = "user-123"
local variant = ABTesting.getAssignment("opening_scene", userId)
```

## Tracking Conversions

### What to Track

Track meaningful outcomes:

| Goal | Event | Example |
|------|-------|---------|
| Engagement | Session duration | Player spent 30+ minutes |
| Completion | Story finished | Reached an ending |
| Retention | Return visit | Came back next day |
| Satisfaction | Positive rating | Rated 4+ stars |

### Track Conversion

```lua
-- Track simple conversion
ABTesting.trackConversion("opening_scene", "story_complete")

-- Track conversion with value
ABTesting.trackConversion("opening_scene", "session_duration", 1800000)

-- Track multiple conversion types
ABTesting.trackConversion("opening_scene", "ending_reached", 1)
ABTesting.trackConversion("opening_scene", "rating", 5)
```

### Conversion Examples

```lua
-- When player completes story
function onStoryComplete(endingId)
  ABTesting.trackConversion("opening_scene", "story_complete", 1)

  -- Track which ending
  ABTesting.trackConversion("opening_scene", "ending:" .. endingId, 1)
end

-- When player rates the story
function onRating(rating)
  ABTesting.trackConversion("opening_scene", "rating", rating)
end

-- When session ends
function onSessionEnd(duration)
  ABTesting.trackConversion("opening_scene", "session_duration", duration)
end
```

## Statistical Analysis

### Built-in Statistics

The framework includes statistical functions:

```lua
local Stats = ABTesting.Statistics

-- Calculate mean
local avg = Stats.mean({10, 20, 30, 40, 50})  -- 30

-- Calculate standard deviation
local sd = Stats.stdDev({10, 20, 30, 40, 50})  -- ~15.8

-- Calculate confidence interval
local lower, upper = Stats.confidenceInterval({10, 20, 30, 40, 50})
-- 95% CI for the mean
```

### T-Test for Comparing Variants

```lua
-- Compare conversion rates
local controlValues = {1, 0, 1, 1, 0, 1, 1, 0, 1, 1}  -- 1 = converted
local treatmentValues = {1, 1, 1, 0, 1, 1, 1, 1, 0, 1}

local result = ABTesting.Statistics.tTest(controlValues, treatmentValues)

print("Control mean:", result.meanA)
print("Treatment mean:", result.meanB)
print("T-statistic:", result.tStatistic)
print("P-value:", result.pValue)
print("Significant?", result.significant)
```

### Understanding Results

| P-Value | Interpretation |
|---------|---------------|
| < 0.01 | Very strong evidence of difference |
| < 0.05 | Strong evidence (typically "significant") |
| < 0.10 | Moderate evidence |
| >= 0.10 | Weak or no evidence |

## Best Practices

### 1. Define Clear Hypotheses

Before starting:
- What change are you testing?
- What metric will you measure?
- What improvement do you expect?

```lua
-- Good: Clear hypothesis
-- "The action opening will increase completion rate by 10%"
ABTesting.defineTest({
  id = "opening_action_vs_calm",
  description = "Hypothesis: Action opening increases completion rate",
  -- ...
})
```

### 2. Calculate Sample Size

Determine minimum sample size before starting:

```lua
-- Rule of thumb: ~400 per variant for detecting 5% difference
ABTesting.defineTest({
  id = "my_test",
  minSampleSize = 400,  -- per variant
  -- ...
})
```

### 3. Run Tests Long Enough

- Don't peek at results too early
- Run for consistent time period
- Account for day-of-week effects

### 4. Test One Thing at a Time

```lua
-- Good: Testing one change
ABTesting.defineTest({
  id = "opening_length",
  variants = {
    { id = "short", weight = 50 },  -- 100 words
    { id = "long", weight = 50 }    -- 500 words
  }
})

-- Bad: Testing multiple changes
-- Can't tell which change caused the effect
```

### 5. Segment Carefully

Consider player segments:

```lua
-- Different tests for different platforms
if platform == "mobile" then
  variant = ABTesting.getVariant("mobile_opening")
else
  variant = ABTesting.getVariant("desktop_opening")
end
```

### 6. Document Everything

Keep records of:
- Test hypothesis
- Start and end dates
- Sample sizes
- Results and decisions

## Common Patterns

### Feature Flag Pattern

```lua
function isFeatureEnabled(featureId)
  local variant = ABTesting.getVariant("feature_" .. featureId)
  return variant and variant.id == "enabled"
end

-- Usage
if isFeatureEnabled("new_combat") then
  runNewCombatSystem()
else
  runOldCombatSystem()
end
```

### Progressive Rollout

```lua
-- Start with small percentage
ABTesting.defineTest({
  id = "new_feature",
  variants = {
    { id = "control", weight = 95 },
    { id = "new", weight = 5 }
  }
})

-- Increase over time as confidence grows
-- 5% -> 25% -> 50% -> 100%
```

### Holdout Group

Always keep a control group:

```lua
ABTesting.defineTest({
  id = "all_improvements",
  variants = {
    { id = "control", weight = 10 },    -- 10% see original
    { id = "improved", weight = 90 }     -- 90% see improvements
  }
})
```

## Troubleshooting

### Variant Not Assigned

```lua
local variant = ABTesting.getVariant("my_test")
if not variant then
  -- Check test exists
  local test = ABTesting.getTest("my_test")
  if not test then
    print("Test not defined")
  elseif test.status ~= "active" then
    print("Test not active:", test.status)
  end
end
```

### Inconsistent Variants

If player sees different variants:

1. Check user ID is consistent
2. Verify test wasn't reset
3. Confirm assignments aren't cleared

```lua
-- Clear assignments only for testing
ABTesting.clearAssignments()  -- Don't do in production!
```

### Exposure Not Tracked

Ensure dependencies are set:

```lua
ABTesting.setDependencies({
  consent_manager = ConsentManager,
  collector = Collector
})
```

## Reference

### Test Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique test identifier |
| `name` | string | No | Display name |
| `description` | string | No | Test description |
| `variants` | array | Yes | Array of variants |
| `minSampleSize` | number | No | Min users per variant |
| `confidenceLevel` | number | No | Statistical confidence |

### Variant Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique variant identifier |
| `name` | string | No | Display name |
| `weight` | number | Yes | Traffic weight |

### API Reference

See [API Reference](api_reference.md) for complete function documentation.
