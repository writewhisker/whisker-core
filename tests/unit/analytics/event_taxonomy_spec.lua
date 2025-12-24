--- Event Taxonomy Tests
-- @module tests.unit.analytics.event_taxonomy_spec
describe("EventTaxonomy", function()
  local EventTaxonomy

  before_each(function()
    package.loaded["whisker.analytics.event_taxonomy"] = nil
    EventTaxonomy = require("whisker.analytics.event_taxonomy")
    EventTaxonomy.resetCustomEvents()
  end)

  describe("CATEGORIES", function()
    it("should define core event categories", function()
      assert.is_table(EventTaxonomy.CATEGORIES.story)
      assert.is_table(EventTaxonomy.CATEGORIES.passage)
      assert.is_table(EventTaxonomy.CATEGORIES.choice)
      assert.is_table(EventTaxonomy.CATEGORIES.save)
      assert.is_table(EventTaxonomy.CATEGORIES.error)
      assert.is_table(EventTaxonomy.CATEGORIES.user)
      assert.is_table(EventTaxonomy.CATEGORIES.test)
    end)

    it("should have correct story actions", function()
      local actions = EventTaxonomy.CATEGORIES.story
      assert.is_true(EventTaxonomy.eventTypeExists("story", "start"))
      assert.is_true(EventTaxonomy.eventTypeExists("story", "resume"))
      assert.is_true(EventTaxonomy.eventTypeExists("story", "complete"))
      assert.is_true(EventTaxonomy.eventTypeExists("story", "abandon"))
      assert.is_true(EventTaxonomy.eventTypeExists("story", "restart"))
    end)

    it("should have correct passage actions", function()
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "view"))
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "exit"))
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "reread"))
    end)

    it("should have correct choice actions", function()
      assert.is_true(EventTaxonomy.eventTypeExists("choice", "presented"))
      assert.is_true(EventTaxonomy.eventTypeExists("choice", "selected"))
      assert.is_true(EventTaxonomy.eventTypeExists("choice", "hover"))
    end)
  end)

  describe("METADATA_SCHEMAS", function()
    it("should define schemas for all core event types", function()
      assert.is_table(EventTaxonomy.getMetadataSchema("story.start"))
      assert.is_table(EventTaxonomy.getMetadataSchema("passage.view"))
      assert.is_table(EventTaxonomy.getMetadataSchema("choice.selected"))
      assert.is_table(EventTaxonomy.getMetadataSchema("save.create"))
      assert.is_table(EventTaxonomy.getMetadataSchema("error.script"))
      assert.is_table(EventTaxonomy.getMetadataSchema("user.consent_change"))
      assert.is_table(EventTaxonomy.getMetadataSchema("test.exposure"))
    end)

    it("should return nil for undefined schemas", function()
      assert.is_nil(EventTaxonomy.getMetadataSchema("unknown.event"))
    end)
  end)

  describe("validateEvent", function()
    it("should validate a correct event", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story",
        storyVersion = "1.0.0",
        metadata = {
          isFirstLaunch = true,
          restoreFromSave = false,
          initialPassage = "opening"
        }
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_true(isValid)
      assert.are.equal(0, #errors)
    end)

    it("should reject event with missing category", function()
      local event = {
        action = "start",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story"
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject event with missing action", function()
      local event = {
        category = "story",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story"
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
    end)

    it("should reject event with missing timestamp", function()
      local event = {
        category = "story",
        action = "start",
        sessionId = "session-123",
        storyId = "my-story"
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
    end)

    it("should reject event with unknown category", function()
      local event = {
        category = "unknown",
        action = "test",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story"
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      local foundCategoryError = false
      for _, err in ipairs(errors) do
        if err:match("Unknown event category") then
          foundCategoryError = true
          break
        end
      end
      assert.is_true(foundCategoryError)
    end)

    it("should reject event with unknown action", function()
      local event = {
        category = "story",
        action = "unknown_action",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story"
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      local foundActionError = false
      for _, err in ipairs(errors) do
        if err:match("Unknown action") then
          foundActionError = true
          break
        end
      end
      assert.is_true(foundActionError)
    end)

    it("should validate metadata types", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story",
        metadata = {
          isFirstLaunch = "not a boolean", -- Should be boolean
          restoreFromSave = false,
          initialPassage = "opening"
        }
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
    end)

    it("should allow optional metadata fields to be missing", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story",
        metadata = {
          passageId = "intro"
          -- other optional fields omitted
        }
      }
      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_true(isValid)
    end)
  end)

  describe("defineCustomEvent", function()
    it("should register a new custom event category", function()
      local success = EventTaxonomy.defineCustomEvent({
        category = "puzzle",
        actions = {"attempt", "solved", "abandoned"},
        metadataSchema = {
          puzzleId = "string",
          attempts = "number?"
        }
      })
      assert.is_true(success)
      assert.is_true(EventTaxonomy.eventTypeExists("puzzle", "attempt"))
      assert.is_true(EventTaxonomy.eventTypeExists("puzzle", "solved"))
      assert.is_true(EventTaxonomy.eventTypeExists("puzzle", "abandoned"))
    end)

    it("should validate custom events after registration", function()
      EventTaxonomy.defineCustomEvent({
        category = "puzzle",
        actions = {"solved"},
        metadataSchema = {
          puzzleId = "string"
        }
      })

      local event = {
        category = "puzzle",
        action = "solved",
        timestamp = 1638360000000,
        sessionId = "session-123",
        storyId = "my-story",
        metadata = {
          puzzleId = "riddle_1"
        }
      }
      local isValid = EventTaxonomy.validateEvent(event)
      assert.is_true(isValid)
    end)

    it("should reject invalid custom event definition", function()
      local success, err = EventTaxonomy.defineCustomEvent({
        category = "test",
        actions = {} -- Empty actions
      })
      assert.is_false(success)
    end)
  end)

  describe("getEventTypes", function()
    it("should return all registered event types", function()
      local types = EventTaxonomy.getEventTypes()
      assert.is_table(types)
      assert.is_true(#types > 0)

      -- Check for expected types
      local hasStoryStart = false
      for _, t in ipairs(types) do
        if t == "story.start" then
          hasStoryStart = true
          break
        end
      end
      assert.is_true(hasStoryStart)
    end)

    it("should return sorted event types", function()
      local types = EventTaxonomy.getEventTypes()
      for i = 2, #types do
        assert.is_true(types[i-1] <= types[i], "Event types should be sorted")
      end
    end)
  end)

  describe("getCategories", function()
    it("should return all categories", function()
      local categories = EventTaxonomy.getCategories()
      assert.is_table(categories)
      assert.is_true(#categories >= 7) -- At least 7 core categories
    end)
  end)

  describe("getActions", function()
    it("should return actions for a valid category", function()
      local actions = EventTaxonomy.getActions("story")
      assert.is_table(actions)
      assert.is_true(#actions > 0)
    end)

    it("should return empty table for invalid category", function()
      local actions = EventTaxonomy.getActions("nonexistent")
      assert.is_table(actions)
      assert.are.equal(0, #actions)
    end)
  end)

  describe("resetCustomEvents", function()
    it("should remove custom events", function()
      EventTaxonomy.defineCustomEvent({
        category = "custom_cat",
        actions = {"custom_action"}
      })
      assert.is_true(EventTaxonomy.eventTypeExists("custom_cat", "custom_action"))

      EventTaxonomy.resetCustomEvents()
      assert.is_false(EventTaxonomy.eventTypeExists("custom_cat", "custom_action"))
    end)

    it("should preserve core categories", function()
      EventTaxonomy.resetCustomEvents()
      assert.is_true(EventTaxonomy.eventTypeExists("story", "start"))
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "view"))
    end)
  end)
end)
