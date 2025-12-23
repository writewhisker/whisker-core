--- A/B Test Setup Example
-- Demonstrates setting up and running A/B tests
-- @module examples.analytics.ab_test_setup

local ABTesting = require("whisker.analytics.testing")
local ConsentManager = require("whisker.analytics.consent_manager")
local Collector = require("whisker.analytics.collector")
local BackendRegistry = require("whisker.analytics.backends")
local Privacy = require("whisker.analytics.privacy")

-----------------------------------------------------------
-- Initialize Analytics System
-----------------------------------------------------------

local function setup()
  -- Initialize consent manager
  ConsentManager.initialize({
    defaultConsentLevel = Privacy.CONSENT_LEVELS.FULL
  })
  ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)

  -- Initialize collector
  Collector.initialize({ batchSize = 10 })

  -- Configure backend
  BackendRegistry.configure({
    { type = "memory", config = {} }
  })

  Collector.setBackends(BackendRegistry.getActiveBackends())
  Collector.setDependencies({ consent_manager = ConsentManager })

  -- Initialize A/B testing
  ABTesting.initialize()
  ABTesting.setDependencies({
    consent_manager = ConsentManager,
    collector = Collector
  })

  print("[Setup] Analytics and A/B testing initialized")
end

-----------------------------------------------------------
-- Define Tests
-----------------------------------------------------------

local function defineTests()
  print("\n[Tests] Defining A/B tests...\n")

  -- Test 1: Opening Scene
  -- Compare calm vs action-packed opening
  local openingTest = ABTesting.defineTest({
    id = "opening_scene_test",
    name = "Opening Scene Comparison",
    description = "Testing action-packed vs. calm opening for engagement",
    variants = {
      {
        id = "control_calm",
        name = "Calm Opening",
        weight = 50
      },
      {
        id = "treatment_action",
        name = "Action Opening",
        weight = 50
      }
    },
    minSampleSize = 100,
    confidenceLevel = 0.95
  })

  if openingTest then
    print("[Tests] Defined: opening_scene_test")
    print("  Variants: control_calm (50%), treatment_action (50%)")
  end

  -- Test 2: Tutorial Length
  -- Compare short, medium, and long tutorials
  local tutorialTest = ABTesting.defineTest({
    id = "tutorial_length_test",
    name = "Tutorial Length Test",
    variants = {
      { id = "short", name = "Short Tutorial (5 min)", weight = 33 },
      { id = "medium", name = "Medium Tutorial (10 min)", weight = 34 },
      { id = "long", name = "Long Tutorial (20 min)", weight = 33 }
    }
  })

  if tutorialTest then
    print("[Tests] Defined: tutorial_length_test")
    print("  Variants: short (33%), medium (34%), long (33%)")
  end

  -- Test 3: New Feature Rollout
  -- Progressive rollout of new combat system
  local featureTest = ABTesting.defineTest({
    id = "new_combat_rollout",
    name = "New Combat System Rollout",
    variants = {
      { id = "control", name = "Original Combat", weight = 90 },
      { id = "new_combat", name = "New Combat System", weight = 10 }
    }
  })

  if featureTest then
    print("[Tests] Defined: new_combat_rollout")
    print("  Variants: control (90%), new_combat (10%)")
  end
end

-----------------------------------------------------------
-- Manage Test Lifecycle
-----------------------------------------------------------

local function manageTestLifecycle()
  print("\n[Lifecycle] Managing test states...\n")

  -- Start the opening scene test
  local success = ABTesting.startTest("opening_scene_test")
  print(string.format("[Lifecycle] Start opening_scene_test: %s",
    success and "OK" or "FAILED"))

  -- Check test status
  local test = ABTesting.getTest("opening_scene_test")
  print(string.format("[Lifecycle] Test status: %s", test.status))

  -- Get all active tests
  local active = ABTesting.getActiveTests()
  print(string.format("[Lifecycle] Active tests: %d", #active))
end

-----------------------------------------------------------
-- Variant Assignment and Usage
-----------------------------------------------------------

local function demonstrateVariantAssignment()
  print("\n[Variants] Demonstrating variant assignment...\n")

  -- Get variant for opening test
  local variant = ABTesting.getVariant("opening_scene_test")

  if variant then
    print(string.format("[Variants] Assigned to: %s (%s)",
      variant.id, variant.name or variant.id))

    -- Demonstrate consistent assignment
    local variant2 = ABTesting.getVariant("opening_scene_test")
    print(string.format("[Variants] Second call: %s (should be same)",
      variant2.id))

    -- Use variant to determine behavior
    if variant.id == "control_calm" then
      print("[Story] Showing calm opening...")
      -- goToPassage("opening_calm")
    else
      print("[Story] Showing action opening...")
      -- goToPassage("opening_action")
    end
  else
    print("[Variants] No variant assigned (test not active?)")
  end
end

-----------------------------------------------------------
-- Track Conversions
-----------------------------------------------------------

local function demonstrateConversionTracking()
  print("\n[Conversions] Tracking conversions...\n")

  -- Simulate player completing the story
  print("[Story] Player completed story!")
  ABTesting.trackConversion("opening_scene_test", "story_complete", 1)
  print("[Conversions] Tracked: story_complete")

  -- Simulate rating
  print("[Story] Player rated 5 stars!")
  ABTesting.trackConversion("opening_scene_test", "rating", 5)
  print("[Conversions] Tracked: rating = 5")

  -- Simulate session duration
  local sessionDuration = 1800000  -- 30 minutes in ms
  ABTesting.trackConversion("opening_scene_test", "session_duration", sessionDuration)
  print(string.format("[Conversions] Tracked: session_duration = %d ms", sessionDuration))
end

-----------------------------------------------------------
-- Statistical Analysis
-----------------------------------------------------------

local function demonstrateStatistics()
  print("\n[Statistics] Demonstrating statistical analysis...\n")

  local Stats = ABTesting.Statistics

  -- Sample data (would come from actual conversions)
  local controlCompletions = {1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1}
  local treatmentCompletions = {1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1}

  -- Calculate means
  local controlMean = Stats.mean(controlCompletions)
  local treatmentMean = Stats.mean(treatmentCompletions)

  print(string.format("[Statistics] Control completion rate: %.1f%%",
    controlMean * 100))
  print(string.format("[Statistics] Treatment completion rate: %.1f%%",
    treatmentMean * 100))

  -- Calculate confidence intervals
  local controlLower, controlUpper = Stats.confidenceInterval(controlCompletions)
  local treatmentLower, treatmentUpper = Stats.confidenceInterval(treatmentCompletions)

  print(string.format("[Statistics] Control 95%% CI: [%.1f%%, %.1f%%]",
    controlLower * 100, controlUpper * 100))
  print(string.format("[Statistics] Treatment 95%% CI: [%.1f%%, %.1f%%]",
    treatmentLower * 100, treatmentUpper * 100))

  -- Perform t-test
  local result = Stats.tTest(controlCompletions, treatmentCompletions)

  if result then
    print("\n[Statistics] T-Test Results:")
    print(string.format("  Mean difference: %.1f%%",
      (result.meanB - result.meanA) * 100))
    print(string.format("  T-statistic: %.3f", result.tStatistic))
    print(string.format("  P-value: %.4f", result.pValue))
    print(string.format("  Significant (p < 0.05): %s",
      result.significant and "YES" or "NO"))

    if result.significant then
      print("\n[Statistics] CONCLUSION: Treatment variant shows ")
      print("  statistically significant improvement!")
    else
      print("\n[Statistics] CONCLUSION: No significant difference detected.")
      print("  Consider running test longer for more data.")
    end
  end
end

-----------------------------------------------------------
-- Feature Flag Pattern
-----------------------------------------------------------

local function demonstrateFeatureFlag()
  print("\n[Feature Flags] Demonstrating feature flag pattern...\n")

  -- Start the feature rollout test
  ABTesting.startTest("new_combat_rollout")

  -- Feature flag function
  local function isFeatureEnabled(featureId)
    local variant = ABTesting.getVariant("new_combat_rollout")
    return variant and variant.id == "new_combat"
  end

  -- Use feature flag
  if isFeatureEnabled("new_combat") then
    print("[Feature Flags] New combat system ENABLED for this user")
    -- useNewCombatSystem()
  else
    print("[Feature Flags] Using original combat system")
    -- useOriginalCombatSystem()
  end
end

-----------------------------------------------------------
-- Complete Test
-----------------------------------------------------------

local function completeTest()
  print("\n[Complete] Completing test...\n")

  -- Complete the opening scene test
  local success = ABTesting.completeTest("opening_scene_test")
  print(string.format("[Complete] Completed opening_scene_test: %s",
    success and "OK" or "FAILED"))

  local test = ABTesting.getTest("opening_scene_test")
  print(string.format("[Complete] Final status: %s", test.status))
  print(string.format("[Complete] End date: %d", test.endDate))

  -- Variants are still accessible for existing users
  local variant = ABTesting.getVariant("opening_scene_test")
  print(string.format("[Complete] Still assigned to: %s",
    variant and variant.id or "none"))
end

-----------------------------------------------------------
-- Run Full Demo
-----------------------------------------------------------

local function runDemo()
  print("\n========================================")
  print("         A/B Testing Demo")
  print("========================================")

  setup()
  defineTests()
  manageTestLifecycle()
  demonstrateVariantAssignment()
  demonstrateConversionTracking()
  demonstrateStatistics()
  demonstrateFeatureFlag()
  completeTest()

  -- Flush events
  Collector.flush()

  -- Show tracked events
  local backend = BackendRegistry.getBackend("memory")
  if backend then
    local events = backend:getEvents()
    print(string.format("\n[Summary] Total events tracked: %d", #events))
    for i, event in ipairs(events) do
      print(string.format("  %d. %s.%s", i, event.category, event.action))
    end
  end

  -- Cleanup
  ABTesting.reset()
  BackendRegistry.shutdownAll()

  print("\n========================================")
  print("           Demo Complete")
  print("========================================\n")
end

-- Run demo
runDemo()

return {
  setup = setup,
  defineTests = defineTests,
  demonstrateVariantAssignment = demonstrateVariantAssignment,
  demonstrateConversionTracking = demonstrateConversionTracking,
  demonstrateStatistics = demonstrateStatistics,
  demonstrateFeatureFlag = demonstrateFeatureFlag
}
