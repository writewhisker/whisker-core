--- Custom Events Example
-- Demonstrates defining and tracking custom event types
-- @module examples.analytics.custom_events

local EventTaxonomy = require("whisker.analytics.event_taxonomy")
local Collector = require("whisker.analytics.collector")
local ConsentManager = require("whisker.analytics.consent_manager")
local Privacy = require("whisker.analytics.privacy")
local BackendRegistry = require("whisker.analytics.backends")

-- Initialize analytics (minimal setup for demo)
local function setup()
  ConsentManager.initialize({ defaultConsentLevel = Privacy.CONSENT_LEVELS.ANALYTICS })
  ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)

  Collector.initialize({ batchSize = 10 })

  BackendRegistry.configure({
    { type = "console", config = { verbose = true } }
  })

  Collector.setBackends(BackendRegistry.getActiveBackends())
  Collector.setDependencies({ consent_manager = ConsentManager })
end

-----------------------------------------------------------
-- Define Custom Event Categories
-----------------------------------------------------------

-- Puzzle system events
EventTaxonomy.registerCustomCategory("puzzle", {
  "started",
  "attempt",
  "hint_used",
  "solved",
  "abandoned"
})

-- Define metadata schemas for puzzle events
EventTaxonomy.registerMetadataSchema("puzzle", "started", {
  puzzleId = "string",
  difficulty = "number?"
})

EventTaxonomy.registerMetadataSchema("puzzle", "attempt", {
  puzzleId = "string",
  attemptNumber = "number",
  answer = "string?"
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

-- Inventory system events
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

-- Achievement system events
EventTaxonomy.registerCustomCategory("achievement", {
  "progress",
  "unlocked"
})

EventTaxonomy.registerMetadataSchema("achievement", "unlocked", {
  achievementId = "string",
  playTime = "number?",
  isSecret = "boolean?"
})

-----------------------------------------------------------
-- Puzzle Manager Class
-----------------------------------------------------------

local PuzzleManager = {}
PuzzleManager.__index = PuzzleManager

function PuzzleManager.new(puzzleId, difficulty)
  local self = setmetatable({}, PuzzleManager)

  self.puzzleId = puzzleId
  self.difficulty = difficulty or 1
  self.attempts = 0
  self.hintsUsed = 0
  self.maxHints = 3
  self.startTime = os.time() * 1000
  self.solved = false

  -- Track puzzle start
  Collector.trackEvent("puzzle", "started", {
    puzzleId = puzzleId,
    difficulty = difficulty
  })

  print(string.format("[Puzzle] Started: %s (difficulty %d)", puzzleId, difficulty))

  return self
end

function PuzzleManager:attempt(answer)
  if self.solved then
    print("[Puzzle] Already solved!")
    return false
  end

  self.attempts = self.attempts + 1

  Collector.trackEvent("puzzle", "attempt", {
    puzzleId = self.puzzleId,
    attemptNumber = self.attempts,
    answer = answer
  })

  print(string.format("[Puzzle] Attempt %d: %s", self.attempts, answer))

  -- Check if correct (demo: "correct" is always right)
  if answer == "correct" then
    self:solve()
    return true
  end

  return false
end

function PuzzleManager:useHint()
  if self.solved then
    print("[Puzzle] Already solved!")
    return nil
  end

  if self.hintsUsed >= self.maxHints then
    print("[Puzzle] No hints remaining!")
    return nil
  end

  self.hintsUsed = self.hintsUsed + 1

  Collector.trackEvent("puzzle", "hint_used", {
    puzzleId = self.puzzleId,
    hintNumber = self.hintsUsed,
    hintsRemaining = self.maxHints - self.hintsUsed
  })

  local hint = string.format("Hint %d: Think carefully...", self.hintsUsed)
  print("[Puzzle] " .. hint)

  return hint
end

function PuzzleManager:solve()
  local timeToSolve = os.time() * 1000 - self.startTime
  self.solved = true

  Collector.trackEvent("puzzle", "solved", {
    puzzleId = self.puzzleId,
    attempts = self.attempts,
    hintsUsed = self.hintsUsed,
    timeToSolve = timeToSolve
  })

  print(string.format(
    "[Puzzle] Solved! Attempts: %d, Hints: %d, Time: %dms",
    self.attempts, self.hintsUsed, timeToSolve
  ))
end

function PuzzleManager:abandon()
  if self.solved then return end

  Collector.trackEvent("puzzle", "abandoned", {
    puzzleId = self.puzzleId,
    attempts = self.attempts,
    lastHint = self.hintsUsed > 0 and self.hintsUsed or nil
  })

  print(string.format(
    "[Puzzle] Abandoned after %d attempts",
    self.attempts
  ))
end

-----------------------------------------------------------
-- Inventory Tracking Functions
-----------------------------------------------------------

local function trackItemFound(itemId, location, hidden)
  Collector.trackEvent("inventory", "item_found", {
    itemId = itemId,
    location = location,
    isHidden = hidden
  })

  print(string.format(
    "[Inventory] Found: %s at %s%s",
    itemId, location, hidden and " (hidden)" or ""
  ))
end

local function trackItemUsed(itemId, target, successful)
  Collector.trackEvent("inventory", "item_used", {
    itemId = itemId,
    usedOn = target,
    successful = successful
  })

  print(string.format(
    "[Inventory] Used %s on %s: %s",
    itemId, target or "nothing", successful and "success" or "failed"
  ))
end

local function trackItemsCombined(item1, item2, result)
  Collector.trackEvent("inventory", "item_combined", {
    item1 = item1,
    item2 = item2,
    result = result
  })

  print(string.format(
    "[Inventory] Combined %s + %s = %s",
    item1, item2, result or "nothing"
  ))
end

-----------------------------------------------------------
-- Achievement Tracking
-----------------------------------------------------------

local function trackAchievement(achievementId, playTime, isSecret)
  Collector.trackEvent("achievement", "unlocked", {
    achievementId = achievementId,
    playTime = playTime,
    isSecret = isSecret
  })

  print(string.format(
    "[Achievement] Unlocked: %s%s",
    achievementId, isSecret and " (SECRET!)" or ""
  ))
end

-----------------------------------------------------------
-- Demo: Simulate gameplay with custom events
-----------------------------------------------------------

local function runDemo()
  print("\n--- Custom Events Demo ---\n")

  setup()

  -- Simulate puzzle gameplay
  print("\n[Scene: The Lighthouse Puzzle]\n")

  local puzzle = PuzzleManager.new("lighthouse_riddle", 3)

  puzzle:attempt("light")
  puzzle:useHint()
  puzzle:attempt("beacon")
  puzzle:useHint()
  puzzle:attempt("correct")  -- This solves it

  -- Simulate inventory interactions
  print("\n[Scene: Exploring the Cave]\n")

  trackItemFound("rusty_key", "cave_entrance", false)
  trackItemFound("ancient_map", "behind_rock", true)
  trackItemUsed("rusty_key", "iron_door", true)
  trackItemsCombined("torn_map_piece", "ancient_map", "complete_map")

  -- Simulate achievement
  print("\n[Achievements]\n")

  trackAchievement("first_puzzle", 300000, false)
  trackAchievement("secret_finder", 600000, true)

  -- Flush events
  print("\n[Flushing events...]\n")
  Collector.flush()

  print("\n--- Demo Complete ---\n")
end

-- Run demo
runDemo()

return {
  PuzzleManager = PuzzleManager,
  trackItemFound = trackItemFound,
  trackItemUsed = trackItemUsed,
  trackItemsCombined = trackItemsCombined,
  trackAchievement = trackAchievement
}
