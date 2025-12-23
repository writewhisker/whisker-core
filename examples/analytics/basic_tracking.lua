--- Basic Analytics Integration Example
-- Demonstrates simple event tracking setup
-- @module examples.analytics.basic_tracking

-- Import required modules
local Privacy = require("whisker.analytics.privacy")
local ConsentManager = require("whisker.analytics.consent_manager")
local Collector = require("whisker.analytics.collector")
local BackendRegistry = require("whisker.analytics.backends")
local EventBuilder = require("whisker.analytics.event_builder")
local Metrics = require("whisker.analytics.metrics")

-- Initialize analytics system
local function initializeAnalytics()
  -- Initialize consent manager with default settings
  ConsentManager.initialize({
    defaultConsentLevel = Privacy.CONSENT_LEVELS.NONE,
    storageKey = "whisker_analytics_consent"
  })

  -- Initialize collector
  Collector.initialize({
    batchSize = 50,
    flushInterval = 30000,  -- 30 seconds
    maxQueueSize = 1000
  })

  -- Configure backends (console for development)
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

  -- Connect collector to backends
  Collector.setBackends(BackendRegistry.getActiveBackends())

  -- Set dependencies
  Collector.setDependencies({
    consent_manager = ConsentManager
  })

  -- Initialize metrics
  Metrics.initialize()

  print("Analytics initialized!")
end

-- Set up event context for the story
local function setupStoryContext(storyId, storyVersion)
  EventBuilder.setContext({
    storyId = storyId,
    storyVersion = storyVersion,
    sessionId = ConsentManager.getSessionId()
  })
end

-- Handle consent (in real app, show UI)
local function handleConsent()
  -- For demo, set to ANALYTICS level
  ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
  print("Consent set to ANALYTICS")
end

-- Track story start
local function onStoryStart(storyId)
  local event = EventBuilder.storyStart({
    storyId = storyId,
    isFirstLaunch = true,
    initialPassage = "opening"
  })

  Collector.trackEvent(event.category, event.action, event.metadata)
  Metrics.addEvent(event)

  print("Tracked: story.start")
end

-- Track passage view
local function onPassageView(passageId, previousPassage)
  local event = EventBuilder.passageView({
    passageId = passageId,
    previousPassage = previousPassage,
    wordCount = 150  -- Would calculate from passage content
  })

  Collector.trackEvent(event.category, event.action, event.metadata)
  Metrics.addEvent(event)

  print("Tracked: passage.view - " .. passageId)
end

-- Track choice selection
local function onChoiceSelected(passageId, choiceId, choiceIndex)
  local event = EventBuilder.choiceSelected({
    passageId = passageId,
    choiceId = choiceId,
    choiceIndex = choiceIndex,
    timeToChoose = 3500  -- Would measure actual time
  })

  Collector.trackEvent(event.category, event.action, event.metadata)
  Metrics.addEvent(event)

  print("Tracked: choice.selected - " .. choiceId)
end

-- Track custom event (e.g., finding an item)
local function onItemFound(itemId, location)
  Collector.trackEvent("inventory", "item_found", {
    itemId = itemId,
    location = location,
    timestamp = os.time() * 1000
  })

  print("Tracked: inventory.item_found - " .. itemId)
end

-- Get current metrics
local function showStats()
  local metrics = Metrics.getAllMetrics()

  print("\n=== Analytics Summary ===")
  print(string.format("Total events: %d", metrics.eventCounts.total))
  print(string.format("Sessions: %d", metrics.sessionDuration.totalSessions))
  print(string.format("Completion rate: %.1f%%",
    metrics.completionRate.completionRate * 100))
  print(string.format("Engagement score: %.0f/100",
    metrics.engagement.engagementScore))
  print("========================\n")
end

-- Flush events on session end
local function onSessionEnd()
  Collector.flush()
  print("Events flushed to backends")
end

-- Demo: Simulate a short play session
local function runDemo()
  print("\n--- Basic Analytics Demo ---\n")

  -- Setup
  initializeAnalytics()
  handleConsent()
  setupStoryContext("demo-story", "1.0.0")

  -- Simulate gameplay
  onStoryStart("demo-story")
  onPassageView("opening", nil)
  onPassageView("forest_entrance", "opening")
  onChoiceSelected("forest_entrance", "go_left", 1)
  onPassageView("dark_cave", "forest_entrance")
  onItemFound("torch", "dark_cave")
  onChoiceSelected("dark_cave", "light_torch", 1)

  -- Show stats
  showStats()

  -- End session
  onSessionEnd()

  print("--- Demo Complete ---\n")
end

-- Run demo if executed directly
runDemo()

return {
  initializeAnalytics = initializeAnalytics,
  setupStoryContext = setupStoryContext,
  handleConsent = handleConsent,
  onStoryStart = onStoryStart,
  onPassageView = onPassageView,
  onChoiceSelected = onChoiceSelected,
  onItemFound = onItemFound,
  showStats = showStats,
  onSessionEnd = onSessionEnd
}
