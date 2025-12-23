--- Unit tests for Event Taxonomy
-- @module tests.analytics.event_taxonomy_spec

describe("EventTaxonomy", function()
  local EventTaxonomy

  before_each(function()
    package.loaded["whisker.analytics.event_taxonomy"] = nil
    EventTaxonomy = require("whisker.analytics.event_taxonomy")
    EventTaxonomy.resetCustomEvents()
  end)

  describe("CATEGORIES", function()
    it("should have story category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.story)
      assert.is_true(#EventTaxonomy.CATEGORIES.story > 0)
    end)

    it("should have passage category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.passage)
      assert.is_true(#EventTaxonomy.CATEGORIES.passage > 0)
    end)

    it("should have choice category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.choice)
      assert.is_true(#EventTaxonomy.CATEGORIES.choice > 0)
    end)

    it("should have save category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.save)
      assert.is_true(#EventTaxonomy.CATEGORIES.save > 0)
    end)

    it("should have error category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.error)
      assert.is_true(#EventTaxonomy.CATEGORIES.error > 0)
    end)

    it("should have user category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.user)
      assert.is_true(#EventTaxonomy.CATEGORIES.user > 0)
    end)

    it("should have test category", function()
      assert.is_not_nil(EventTaxonomy.CATEGORIES.test)
      assert.is_true(#EventTaxonomy.CATEGORIES.test > 0)
    end)
  end)

  describe("METADATA_SCHEMAS", function()
    it("should have schema for story.start", function()
      local schema = EventTaxonomy.METADATA_SCHEMAS["story.start"]
      assert.is_not_nil(schema)
      assert.is_not_nil(schema.isFirstLaunch)
      assert.is_not_nil(schema.restoreFromSave)
      assert.is_not_nil(schema.initialPassage)
    end)

    it("should have schema for passage.view", function()
      local schema = EventTaxonomy.METADATA_SCHEMAS["passage.view"]
      assert.is_not_nil(schema)
      assert.is_not_nil(schema.passageId)
    end)

    it("should have schema for choice.selected", function()
      local schema = EventTaxonomy.METADATA_SCHEMAS["choice.selected"]
      assert.is_not_nil(schema)
      assert.is_not_nil(schema.passageId)
      assert.is_not_nil(schema.choiceId)
    end)

    it("should have schema for error.script", function()
      local schema = EventTaxonomy.METADATA_SCHEMAS["error.script"]
      assert.is_not_nil(schema)
      assert.is_not_nil(schema.errorType)
      assert.is_not_nil(schema.errorMessage)
      assert.is_not_nil(schema.severity)
    end)

    it("should have schema for test.exposure", function()
      local schema = EventTaxonomy.METADATA_SCHEMAS["test.exposure"]
      assert.is_not_nil(schema)
      assert.is_not_nil(schema.testId)
      assert.is_not_nil(schema.variantId)
    end)
  end)

  describe("validateEvent()", function()
    it("should validate a well-formed event", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story",
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

    it("should reject event missing category", function()
      local event = {
        action = "start",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject event missing action", function()
      local event = {
        category = "story",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject event missing timestamp", function()
      local event = {
        category = "story",
        action = "start",
        sessionId = "test-session-123",
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject event missing sessionId", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = os.time() * 1000,
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject event missing storyId", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject unknown category", function()
      local event = {
        category = "unknown_category",
        action = "start",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should reject unknown action", function()
      local event = {
        category = "story",
        action = "unknown_action",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story"
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should validate metadata types", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story",
        metadata = {
          isFirstLaunch = "not a boolean", -- Should be boolean
          restoreFromSave = false,
          initialPassage = "opening"
        }
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_false(isValid)
      assert.is_true(#errors > 0)
    end)

    it("should allow optional metadata fields to be missing", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = os.time() * 1000,
        sessionId = "test-session-123",
        storyId = "test-story",
        metadata = {
          passageId = "test-passage"
          -- passageName is optional
        }
      }

      local isValid, errors = EventTaxonomy.validateEvent(event)
      assert.is_true(isValid)
      assert.are.equal(0, #errors)
    end)
  end)

  describe("defineCustomEvent()", function()
    it("should define a new custom event", function()
      local success = EventTaxonomy.defineCustomEvent({
        category = "puzzle",
        actions = {"attempt", "solved", "abandoned"},
        metadataSchema = {
          puzzleId = "string",
          attempts = "number?"
        }
      })

      assert.is_true(success)
      assert.is_not_nil(EventTaxonomy.CATEGORIES.puzzle)
      assert.are.equal(3, #EventTaxonomy.CATEGORIES.puzzle)
    end)

    it("should add actions to existing category", function()
      local success = EventTaxonomy.defineCustomEvent({
        category = "story",
        actions = {"custom_action"}
      })

      assert.is_true(success)
      assert.is_true(EventTaxonomy.eventTypeExists("story", "custom_action"))
    end)

    it("should reject definition without category", function()
      local success, err = EventTaxonomy.defineCustomEvent({
        actions = {"attempt"}
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should reject definition without actions", function()
      local success, err = EventTaxonomy.defineCustomEvent({
        category = "puzzle"
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should reject definition with empty actions", function()
      local success, err = EventTaxonomy.defineCustomEvent({
        category = "puzzle",
        actions = {}
      })

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should register metadata schema for custom events", function()
      EventTaxonomy.defineCustomEvent({
        category = "puzzle",
        actions = {"solved"},
        metadataSchema = {
          puzzleId = "string",
          timeToSolve = "number"
        }
      })

      local schema = EventTaxonomy.getMetadataSchema("puzzle.solved")
      assert.is_not_nil(schema)
      assert.are.equal("string", schema.puzzleId)
      assert.are.equal("number", schema.timeToSolve)
    end)
  end)

  describe("getEventTypes()", function()
    it("should return all event types", function()
      local types = EventTaxonomy.getEventTypes()
      assert.is_true(#types > 0)
    end)

    it("should include story.start", function()
      local types = EventTaxonomy.getEventTypes()
      local found = false
      for _, t in ipairs(types) do
        if t == "story.start" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should return sorted types", function()
      local types = EventTaxonomy.getEventTypes()
      for i = 2, #types do
        assert.is_true(types[i-1] <= types[i])
      end
    end)
  end)

  describe("eventTypeExists()", function()
    it("should return true for existing event type", function()
      assert.is_true(EventTaxonomy.eventTypeExists("story", "start"))
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "view"))
      assert.is_true(EventTaxonomy.eventTypeExists("choice", "selected"))
    end)

    it("should return false for non-existing event type", function()
      assert.is_false(EventTaxonomy.eventTypeExists("unknown", "action"))
      assert.is_false(EventTaxonomy.eventTypeExists("story", "unknown"))
    end)
  end)

  describe("getCategories()", function()
    it("should return all categories", function()
      local categories = EventTaxonomy.getCategories()
      assert.is_true(#categories >= 7) -- story, passage, choice, save, error, user, test
    end)

    it("should return sorted categories", function()
      local categories = EventTaxonomy.getCategories()
      for i = 2, #categories do
        assert.is_true(categories[i-1] <= categories[i])
      end
    end)
  end)

  describe("getActions()", function()
    it("should return actions for existing category", function()
      local actions = EventTaxonomy.getActions("story")
      assert.is_true(#actions >= 5) -- start, resume, complete, abandon, restart
    end)

    it("should return empty array for non-existing category", function()
      local actions = EventTaxonomy.getActions("nonexistent")
      assert.are.equal(0, #actions)
    end)
  end)

  describe("getMetadataSchema()", function()
    it("should return schema for known event type", function()
      local schema = EventTaxonomy.getMetadataSchema("story.start")
      assert.is_not_nil(schema)
      assert.is_table(schema)
    end)

    it("should return nil for unknown event type", function()
      local schema = EventTaxonomy.getMetadataSchema("unknown.type")
      assert.is_nil(schema)
    end)
  end)

  describe("resetCustomEvents()", function()
    it("should remove custom events", function()
      EventTaxonomy.defineCustomEvent({
        category = "custom_category",
        actions = {"custom_action"}
      })

      assert.is_true(EventTaxonomy.eventTypeExists("custom_category", "custom_action"))

      EventTaxonomy.resetCustomEvents()

      assert.is_false(EventTaxonomy.eventTypeExists("custom_category", "custom_action"))
    end)

    it("should preserve core categories", function()
      EventTaxonomy.resetCustomEvents()

      assert.is_true(EventTaxonomy.eventTypeExists("story", "start"))
      assert.is_true(EventTaxonomy.eventTypeExists("passage", "view"))
      assert.is_true(EventTaxonomy.eventTypeExists("choice", "selected"))
    end)
  end)
end)
