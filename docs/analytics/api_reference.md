# Analytics API Reference

Complete API documentation for whisker-core analytics.

## Modules

- [Event Taxonomy](#event-taxonomy)
- [Event Builder](#event-builder)
- [Collector](#collector)
- [Privacy](#privacy)
- [Privacy Filter](#privacy-filter)
- [Consent Manager](#consent-manager)
- [Metrics](#metrics)
- [Backend Registry](#backend-registry)
- [A/B Testing](#ab-testing)

---

## Event Taxonomy

```lua
local EventTaxonomy = require("whisker.analytics.event_taxonomy")
```

Defines valid event categories, actions, and metadata schemas.

### Constants

#### `EventTaxonomy.CATEGORIES`
Table of valid categories and their actions.

```lua
{
  story = { "start", "resume", "complete", "abandon" },
  passage = { "view", "exit" },
  choice = { "presented", "selected" },
  save = { "created", "loaded", "deleted" },
  error = { "runtime", "script" },
  user = { "feedback" },
  test = { "exposure", "conversion" }
}
```

### Functions

#### `eventTypeExists(category, action)`
Check if event type is valid.

**Parameters:**
- `category` (string): Event category
- `action` (string): Event action

**Returns:** boolean

#### `validateMetadata(category, action, metadata)`
Validate metadata against schema.

**Parameters:**
- `category` (string): Event category
- `action` (string): Event action
- `metadata` (table): Metadata to validate

**Returns:** boolean, table (errors)

#### `getMetadataSchema(category, action)`
Get schema for event type.

**Returns:** table or nil

#### `registerCustomCategory(category, actions)`
Register a custom category.

**Parameters:**
- `category` (string): Category name
- `actions` (table): Array of action strings

#### `registerMetadataSchema(category, action, schema)`
Register metadata schema.

**Parameters:**
- `category` (string): Event category
- `action` (string): Event action
- `schema` (table): Field definitions

---

## Event Builder

```lua
local EventBuilder = require("whisker.analytics.event_builder")
```

Creates well-formed event objects.

### Functions

#### `createEvent(category, action, metadata)`
Create a generic event.

**Parameters:**
- `category` (string): Event category
- `action` (string): Event action
- `metadata` (table, optional): Event metadata

**Returns:** table (event object)

#### `storyStart(options)`
Create story start event.

**Parameters:**
- `options.storyId` (string)
- `options.storyVersion` (string, optional)
- `options.isFirstLaunch` (boolean, optional)
- `options.restoreFromSave` (boolean, optional)
- `options.initialPassage` (string, optional)

#### `storyComplete(options)`
Create story complete event.

#### `storyAbandon(options)`
Create story abandon event.

#### `passageView(options)`
Create passage view event.

**Parameters:**
- `options.passageId` (string, required)
- `options.passageName` (string, optional)
- `options.wordCount` (number, optional)
- `options.previousPassage` (string, optional)
- `options.transitionType` (string, optional)

#### `passageExit(options)`
Create passage exit event.

#### `choiceSelected(options)`
Create choice selected event.

**Parameters:**
- `options.passageId` (string, required)
- `options.choiceId` (string, required)
- `options.choiceIndex` (number, optional)
- `options.timeToChoose` (number, optional)

#### `setContext(context)`
Set default context for all events.

**Parameters:**
- `context.storyId` (string)
- `context.storyVersion` (string)
- `context.sessionId` (string)

---

## Collector

```lua
local Collector = require("whisker.analytics.collector")
```

Manages event collection and export.

### Functions

#### `initialize(config)`
Initialize the collector.

**Parameters:**
- `config.batchSize` (number): Events per batch (default: 50)
- `config.flushInterval` (number): Flush interval in ms (default: 30000)
- `config.maxQueueSize` (number): Max queued events (default: 1000)
- `config.maxRetries` (number): Export retry count (default: 3)

#### `trackEvent(category, action, metadata)`
Track an event.

**Parameters:**
- `category` (string): Event category
- `action` (string): Event action
- `metadata` (table, optional): Event metadata

**Returns:** boolean (success)

#### `flush()`
Force immediate export of queued events.

#### `setBackends(backends)`
Set export backends.

**Parameters:**
- `backends` (table): Array of backend instances

#### `setDependencies(deps)`
Set dependencies.

**Parameters:**
- `deps.privacy_filter` (PrivacyFilter)
- `deps.consent_manager` (ConsentManager)

#### `getStatus()`
Get collector status.

**Returns:**
```lua
{
  queueSize = number,
  eventsExported = number,
  batchesExported = number,
  errors = number
}
```

#### `reset()`
Reset collector state.

---

## Privacy

```lua
local Privacy = require("whisker.analytics.privacy")
```

Privacy constants and utilities.

### Constants

#### `Privacy.CONSENT_LEVELS`
```lua
{
  NONE = 0,       -- No tracking
  ESSENTIAL = 1,  -- Technical only
  ANALYTICS = 2,  -- Anonymous behavior
  FULL = 3        -- All features
}
```

#### `Privacy.CONSENT_DESCRIPTIONS`
Human-readable descriptions for each level.

### Functions

#### `getConsentDescription(level)`
Get description for consent level.

**Parameters:**
- `level` (number): Consent level

**Returns:** string

#### `getConsentName(level)`
Get name for consent level.

**Returns:** string ("NONE", "ESSENTIAL", "ANALYTICS", "FULL")

---

## Privacy Filter

```lua
local PrivacyFilter = require("whisker.analytics.privacy_filter")
```

Filters events based on consent.

### Constants

#### `PrivacyFilter.PII_FIELDS`
Fields considered personally identifiable:
```lua
{ "userId", "userName", "userEmail", "ipAddress", "deviceId", "saveName", "feedbackText" }
```

### Functions

#### `filter(event, consentLevel)`
Filter event based on consent.

**Parameters:**
- `event` (table): Event to filter
- `consentLevel` (number): Current consent level

**Returns:** table (filtered event) or nil (blocked)

#### `setEnabled(enabled)`
Enable/disable filtering.

#### `isEnabled()`
Check if filtering is enabled.

**Returns:** boolean

---

## Consent Manager

```lua
local ConsentManager = require("whisker.analytics.consent_manager")
```

Manages user consent state.

### Functions

#### `initialize(config)`
Initialize consent manager.

**Parameters:**
- `config.defaultConsentLevel` (number)
- `config.storageKey` (string)
- `config.storage` (table, optional): Storage interface

#### `getConsentLevel()`
Get current consent level.

**Returns:** number

#### `setConsentLevel(level)`
Set consent level.

**Parameters:**
- `level` (number): New consent level

**Returns:** boolean (success)

#### `hasConsent()`
Check if consent has been set.

**Returns:** boolean

#### `getUserId()`
Get user ID (respects consent level).

**Returns:** string or nil

#### `getSessionId()`
Get session ID.

**Returns:** string

#### `exportUserData()`
Export all user data.

**Returns:** table

#### `deleteUserData()`
Delete all user data.

#### `reset()`
Reset consent manager.

---

## Metrics

```lua
local Metrics = require("whisker.analytics.metrics")
```

Calculate analytics metrics.

### Functions

#### `initialize()`
Initialize metrics module.

#### `addEvent(event)`
Add event for calculation.

**Parameters:**
- `event` (table): Event object

#### `calculateSessionDuration()`
Calculate session duration metrics.

**Returns:** See [Metrics Reference](metrics_reference.md#session-duration)

#### `calculateCompletionRate()`
Calculate completion rate metrics.

**Returns:** See [Metrics Reference](metrics_reference.md#completion-rate)

#### `calculateChoiceDistribution()`
Calculate choice distribution metrics.

**Returns:** See [Metrics Reference](metrics_reference.md#choice-distribution)

#### `calculatePassageFlow()`
Calculate passage flow metrics.

**Returns:** See [Metrics Reference](metrics_reference.md#passage-flow)

#### `calculateEngagement()`
Calculate engagement metrics.

**Returns:** See [Metrics Reference](metrics_reference.md#engagement)

#### `calculateEventCounts()`
Calculate event counts.

**Returns:** See [Metrics Reference](metrics_reference.md#event-counts)

#### `getAllMetrics()`
Get all metrics.

**Returns:** table with all metric types

#### `getMetric(name)`
Get specific metric.

**Parameters:**
- `name` (string): Metric name

**Returns:** table

#### `export()`
Export metrics with metadata.

**Returns:**
```lua
{
  timestamp = number,
  eventCount = number,
  metrics = table
}
```

#### `clear()`
Clear events and cache.

#### `reset()`
Full reset.

---

## Backend Registry

```lua
local BackendRegistry = require("whisker.analytics.backends")
```

Manages export backends.

### Functions

#### `registerBackendType(name, factory)`
Register a backend type.

**Parameters:**
- `name` (string): Backend type name
- `factory` (table): Factory with `create(config)` method

#### `createBackend(type, config)`
Create backend instance.

**Parameters:**
- `type` (string): Backend type
- `config` (table): Backend configuration

**Returns:** table (backend), string (error)

#### `addBackend(backend)`
Add backend to active list.

#### `configure(backends)`
Configure multiple backends.

**Parameters:**
- `backends` (table): Array of `{type, config}` tables

#### `getActiveBackends()`
Get active backends.

**Returns:** table (array of backends)

#### `getBackend(name)`
Get backend by name.

**Returns:** table or nil

#### `getBackendTypes()`
Get registered backend types.

**Returns:** table (array of names)

#### `shutdownAll()`
Shutdown all backends.

#### `testAll()`
Test all backends.

**Returns:** table (array of results)

#### `reset()`
Reset registry.

---

## A/B Testing

```lua
local ABTesting = require("whisker.analytics.testing")
```

A/B testing framework.

### Functions

#### `initialize()`
Initialize A/B testing.

#### `setDependencies(deps)`
Set dependencies.

**Parameters:**
- `deps.consent_manager` (ConsentManager)
- `deps.collector` (Collector)

#### `defineTest(definition)`
Define a new test.

**Parameters:**
```lua
{
  id = "string",              -- Required
  name = "string",            -- Optional
  description = "string",     -- Optional
  variants = {                -- Required
    { id = "string", weight = number, name = "string?" },
    ...
  },
  minSampleSize = number,     -- Optional (default: 100)
  confidenceLevel = number    -- Optional (default: 0.95)
}
```

**Returns:** table (test), string (error)

#### `getTest(testId)`
Get test by ID.

**Returns:** table or nil

#### `getAllTests()`
Get all tests.

**Returns:** table

#### `getActiveTests()`
Get active tests.

**Returns:** table (array)

#### `startTest(testId)`
Start a test.

**Returns:** boolean, string (error)

#### `pauseTest(testId)`
Pause a test.

**Returns:** boolean, string (error)

#### `completeTest(testId)`
Complete a test.

**Returns:** boolean, string (error)

#### `archiveTest(testId)`
Archive a test.

**Returns:** boolean, string (error)

#### `deleteTest(testId)`
Delete a test.

#### `getVariant(testId)`
Get variant for current user.

**Returns:** table (variant) or nil

#### `getAssignment(testId, userId)`
Get assignment for specific user.

**Returns:** table or nil

#### `trackConversion(testId, conversionType, value)`
Track a conversion.

**Parameters:**
- `testId` (string): Test ID
- `conversionType` (string): Type of conversion
- `value` (number, optional): Conversion value

#### `clearAssignments()`
Clear all assignments (testing only).

#### `reset()`
Reset A/B testing.

### Statistics

#### `ABTesting.Statistics.mean(values)`
Calculate mean.

**Returns:** number

#### `ABTesting.Statistics.stdDev(values)`
Calculate standard deviation.

**Returns:** number

#### `ABTesting.Statistics.confidenceInterval(values, level)`
Calculate confidence interval.

**Returns:** number, number (lower, upper)

#### `ABTesting.Statistics.tTest(valuesA, valuesB)`
Perform t-test.

**Returns:**
```lua
{
  meanA = number,
  meanB = number,
  tStatistic = number,
  degreesOfFreedom = number,
  pValue = number,
  significant = boolean
}
```
