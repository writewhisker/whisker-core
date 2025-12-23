# Troubleshooting Guide

Solutions for common analytics issues in whisker-core.

## Events Not Being Tracked

### Symptom
`trackEvent()` calls aren't appearing in your backend.

### Possible Causes

#### 1. Consent Level is NONE
Events are blocked when consent is not granted.

**Check:**
```lua
local ConsentManager = require("whisker.analytics.consent_manager")
local level = ConsentManager.getConsentLevel()
print("Current consent:", level)  -- 0 = NONE
```

**Fix:**
```lua
local Privacy = require("whisker.analytics.privacy")
ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
```

#### 2. No Backends Configured
Events queue but never export without backends.

**Check:**
```lua
local BackendRegistry = require("whisker.analytics.backends")
local backends = BackendRegistry.getActiveBackends()
print("Active backends:", #backends)
```

**Fix:**
```lua
BackendRegistry.configure({
  { type = "console", config = { verbose = true } }
})
```

#### 3. Events Still Queued
Events batch and export periodically.

**Fix:**
```lua
local Collector = require("whisker.analytics.collector")
Collector.flush()  -- Force immediate export
```

#### 4. Privacy Filter Blocking
Event category may require higher consent level.

**Check:**
```lua
local PrivacyFilter = require("whisker.analytics.privacy_filter")
local result = PrivacyFilter.filter(event, Privacy.CONSENT_LEVELS.ANALYTICS)
print("Filtered:", result == nil)
```

---

## PII Appearing in Events

### Symptom
Personal data (emails, names) shows up in exported events.

### Possible Causes

#### 1. Consent Level is FULL
FULL consent includes all data.

**Check:**
```lua
local level = ConsentManager.getConsentLevel()
print("Consent:", level)  -- 3 = FULL
```

**Fix:**
If you don't want PII, use ANALYTICS level:
```lua
ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
```

#### 2. Custom PII Fields
Your custom metadata may contain PII not in the default list.

**Fix:**
Filter before tracking:
```lua
local function sanitize(metadata)
  local clean = {}
  for k, v in pairs(metadata) do
    if k ~= "playerName" and k ~= "email" then
      clean[k] = v
    end
  end
  return clean
end

Collector.trackEvent("custom", "event", sanitize(myMetadata))
```

---

## A/B Test Not Working

### Symptom
`getVariant()` returns nil.

### Possible Causes

#### 1. Test Not Started
Test must be in "active" state.

**Check:**
```lua
local test = ABTesting.getTest("my_test")
print("Status:", test and test.status or "nil")
```

**Fix:**
```lua
ABTesting.startTest("my_test")
```

#### 2. Test Not Defined
Test ID doesn't exist.

**Check:**
```lua
local test = ABTesting.getTest("my_test")
if not test then
  print("Test not found")
end
```

**Fix:**
```lua
ABTesting.defineTest({
  id = "my_test",
  variants = {
    { id = "a", weight = 50 },
    { id = "b", weight = 50 }
  }
})
```

#### 3. Dependencies Not Set
A/B testing needs consent manager for user IDs.

**Fix:**
```lua
ABTesting.setDependencies({
  consent_manager = ConsentManager,
  collector = Collector
})
```

---

## Variant Not Consistent

### Symptom
Same player sees different variants across sessions.

### Possible Causes

#### 1. User ID Changes
At ANALYTICS consent level, IDs are session-scoped.

**Check:**
```lua
local level = ConsentManager.getConsentLevel()
print("Consent:", level)
-- ANALYTICS (2) = session-scoped IDs
-- FULL (3) = persistent IDs
```

**Fix:**
For consistent A/B tests, require FULL consent:
```lua
if ConsentManager.getConsentLevel() >= Privacy.CONSENT_LEVELS.FULL then
  local variant = ABTesting.getVariant("my_test")
  -- Use variant
end
```

#### 2. Test Was Reset
Clearing assignments causes new assignments.

**Check:**
Don't call `clearAssignments()` in production.

---

## Backend Export Failing

### Symptom
Events queue up but never export successfully.

### Possible Causes

#### 1. Network Error
HTTP backend can't reach endpoint.

**Check:**
```lua
local backend = BackendRegistry.getBackend("http")
local success, err = backend:test()
print("Test:", success, err)
```

**Fix:**
- Verify endpoint URL
- Check network connectivity
- Verify API credentials

#### 2. Backend Misconfigured
Missing required configuration.

**Check:**
```lua
local status = backend:getStatus()
print("Errors:", status.stats.errors)
```

**Fix:**
Verify all required config options:
```lua
BackendRegistry.configure({
  {
    type = "http",
    config = {
      endpoint = "https://...",  -- Required
      headers = { ... }
    }
  }
})
```

#### 3. Rate Limited
Too many requests to external service.

**Fix:**
Increase batch size and flush interval:
```lua
Collector.initialize({
  batchSize = 100,        -- Larger batches
  flushInterval = 60000   -- Less frequent
})
```

---

## Metrics Not Updating

### Symptom
`getAllMetrics()` returns stale data.

### Possible Causes

#### 1. Events Not Added to Metrics
Collector tracks events, but metrics module needs events explicitly added.

**Fix:**
```lua
-- When tracking, also add to metrics
Collector.trackEvent(category, action, metadata)
Metrics.addEvent({
  category = category,
  action = action,
  timestamp = os.time() * 1000,
  sessionId = sessionId,
  metadata = metadata
})
```

#### 2. Cache Not Invalidated
Metrics cache from previous calculation.

**Check:**
Cache is cleared when events are added. If manually clearing:
```lua
Metrics.clear()
```

---

## Memory Usage Growing

### Symptom
Application memory increases over long sessions.

### Possible Causes

#### 1. Event Queue Too Large
Events queuing faster than exporting.

**Check:**
```lua
local status = Collector.getStatus()
print("Queue size:", status.queueSize)
```

**Fix:**
```lua
Collector.initialize({
  maxQueueSize = 1000,  -- Limit queue
  batchSize = 50,       -- Export more often
  flushInterval = 30000
})
```

#### 2. Metrics Events Accumulating
Too many events stored for metrics.

**Fix:**
Export and clear periodically:
```lua
if Metrics.calculateEventCounts().total > 10000 then
  local exported = Metrics.export()
  saveExternally(exported)
  Metrics.clear()
end
```

---

## Debug Mode

Enable verbose logging to diagnose issues:

```lua
-- Console backend with verbose output
BackendRegistry.configure({
  {
    type = "console",
    config = { verbose = true }
  }
})

-- Will print each event as it exports
```

## Getting Help

If you're still stuck:

1. Check the [API Reference](api_reference.md) for correct usage
2. Review [Examples](../../examples/analytics/) for working code
3. Enable debug mode and review output
4. Check your consent and backend configuration

## Quick Diagnostic Script

```lua
local function diagnoseAnalytics()
  local Collector = require("whisker.analytics.collector")
  local ConsentManager = require("whisker.analytics.consent_manager")
  local BackendRegistry = require("whisker.analytics.backends")
  local Privacy = require("whisker.analytics.privacy")

  print("=== Analytics Diagnostic ===")

  -- Check consent
  local consent = ConsentManager.getConsentLevel()
  print(string.format("Consent level: %d (%s)",
    consent,
    consent == 0 and "NONE" or
    consent == 1 and "ESSENTIAL" or
    consent == 2 and "ANALYTICS" or "FULL"
  ))

  if consent == 0 then
    print("  ⚠️  No consent - events will be blocked")
  end

  -- Check backends
  local backends = BackendRegistry.getActiveBackends()
  print(string.format("Active backends: %d", #backends))

  for i, backend in ipairs(backends) do
    print(string.format("  %d. %s", i, backend.name))
    local success, err = backend:test()
    if success then
      print("     ✓ Test passed")
    else
      print("     ✗ Test failed: " .. tostring(err))
    end
  end

  if #backends == 0 then
    print("  ⚠️  No backends - events won't export")
  end

  -- Check collector
  local status = Collector.getStatus()
  print(string.format("Queue size: %d", status.queueSize or 0))
  print(string.format("Events exported: %d", status.eventsExported or 0))

  print("=== End Diagnostic ===")
end

diagnoseAnalytics()
```
