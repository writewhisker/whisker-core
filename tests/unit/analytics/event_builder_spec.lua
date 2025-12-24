--- Event Builder Tests
-- @module tests.unit.analytics.event_builder_spec
describe("EventBuilder", function()
  local EventBuilder
  local EventTaxonomy

  before_each(function()
    package.loaded["whisker.analytics.event_builder"] = nil
    package.loaded["whisker.analytics.event_taxonomy"] = nil

    EventBuilder = require("whisker.analytics.event_builder")
    EventTaxonomy = require("whisker.analytics.event_taxonomy")

    EventBuilder.reset()
    EventBuilder.initialize({
      storyId = "test-story",
      storyVersion = "1.0.0",
      storyTitle = "Test Story"
    })
    EventBuilder.setDependencies({
      event_taxonomy = EventTaxonomy
    })
  end)

  describe("initialize", function()
    it("should set story configuration", function()
      EventBuilder.initialize({
        storyId = "my-story",
        storyVersion = "2.0.0",
        storyTitle = "My Story"
      })

      local event = EventBuilder.storyStart()
      assert.are.equal("my-story", event.storyId)
      assert.are.equal("2.0.0", event.storyVersion)
      assert.are.equal("My Story", event.storyTitle)
    end)

    it("should create a new session", function()
      EventBuilder.initialize({})
      local sessionId = EventBuilder.getSessionId()
      assert.is_string(sessionId)
      assert.is_true(#sessionId > 0)
    end)
  end)

  describe("getSessionId", function()
    it("should return a valid UUID format", function()
      local sessionId = EventBuilder.getSessionId()
      assert.is_string(sessionId)
      -- UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      assert.is_true(sessionId:match("^%x+%-%x+%-4%x+%-[89ab]%x+%-%x+$") ~= nil or
                     sessionId:match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil)
    end)

    it("should return consistent session ID within same session", function()
      local id1 = EventBuilder.getSessionId()
      local id2 = EventBuilder.getSessionId()
      assert.are.equal(id1, id2)
    end)
  end)

  describe("startNewSession", function()
    it("should generate a new session ID", function()
      local oldId = EventBuilder.getSessionId()
      local newId = EventBuilder.startNewSession()
      assert.is_string(newId)
      assert.are_not.equal(oldId, newId)
    end)
  end)

  describe("createBaseEvent", function()
    it("should create event with all required fields", function()
      local event = EventBuilder.createBaseEvent("story", "start", {})

      assert.are.equal("story", event.category)
      assert.are.equal("start", event.action)
      assert.is_number(event.timestamp)
      assert.is_string(event.sessionId)
      assert.are.equal("test-story", event.storyId)
      assert.is_table(event.metadata)
    end)

    it("should include timestamp in milliseconds", function()
      local before = os.time() * 1000
      local event = EventBuilder.createBaseEvent("story", "start", {})
      local after = os.time() * 1000 + 1000 -- +1 second tolerance

      assert.is_true(event.timestamp >= before - 1000)
      assert.is_true(event.timestamp <= after)
    end)

    it("should deep copy metadata", function()
      local metadata = {
        nested = { value = 1 }
      }
      local event = EventBuilder.createBaseEvent("story", "start", metadata)

      -- Modify original
      metadata.nested.value = 2

      -- Event should still have original value
      assert.are.equal(1, event.metadata.nested.value)
    end)
  end)

  describe("buildEvent", function()
    it("should build and validate event", function()
      local event, errors = EventBuilder.buildEvent("story", "start", {
        isFirstLaunch = true,
        restoreFromSave = false,
        initialPassage = "intro"
      })

      assert.is_table(event)
      assert.is_nil(errors)
    end)

    it("should return errors for invalid metadata", function()
      local event, errors = EventBuilder.buildEvent("story", "start", {
        isFirstLaunch = "not a boolean" -- Should be boolean
      })

      assert.is_nil(event)
      assert.is_table(errors)
      assert.is_true(#errors > 0)
    end)
  end)

  describe("buildEventFast", function()
    it("should build event without validation", function()
      local event = EventBuilder.buildEventFast("story", "start", {
        isFirstLaunch = "invalid" -- Would fail validation
      })

      assert.is_table(event)
      assert.are.equal("story", event.category)
    end)
  end)

  -- Test convenience builders
  describe("convenience builders", function()
    describe("storyStart", function()
      it("should create story.start event with defaults", function()
        local event = EventBuilder.storyStart()
        assert.are.equal("story", event.category)
        assert.are.equal("start", event.action)
        assert.are.equal(false, event.metadata.isFirstLaunch)
        assert.are.equal(false, event.metadata.restoreFromSave)
      end)

      it("should allow overriding defaults", function()
        local event = EventBuilder.storyStart({
          isFirstLaunch = true,
          initialPassage = "opening"
        })
        assert.are.equal(true, event.metadata.isFirstLaunch)
        assert.are.equal("opening", event.metadata.initialPassage)
      end)
    end)

    describe("storyComplete", function()
      it("should create story.complete event", function()
        local event = EventBuilder.storyComplete({
          completionPassage = "ending"
        })
        assert.are.equal("story", event.category)
        assert.are.equal("complete", event.action)
        assert.are.equal("ending", event.metadata.completionPassage)
      end)
    end)

    describe("passageView", function()
      it("should create passage.view event", function()
        local event = EventBuilder.passageView("intro", "Introduction")
        assert.are.equal("passage", event.category)
        assert.are.equal("view", event.action)
        assert.are.equal("intro", event.metadata.passageId)
        assert.are.equal("Introduction", event.metadata.passageName)
      end)
    end)

    describe("passageExit", function()
      it("should create passage.exit event", function()
        local event = EventBuilder.passageExit("intro", 5000)
        assert.are.equal("passage", event.category)
        assert.are.equal("exit", event.action)
        assert.are.equal("intro", event.metadata.passageId)
        assert.are.equal(5000, event.metadata.timeOnPassage)
      end)
    end)

    describe("choicePresented", function()
      it("should create choice.presented event", function()
        local event = EventBuilder.choicePresented("crossroads", 3)
        assert.are.equal("choice", event.category)
        assert.are.equal("presented", event.action)
        assert.are.equal("crossroads", event.metadata.passageId)
        assert.are.equal(3, event.metadata.choiceCount)
      end)
    end)

    describe("choiceSelected", function()
      it("should create choice.selected event", function()
        local event = EventBuilder.choiceSelected("crossroads", "choice_1")
        assert.are.equal("choice", event.category)
        assert.are.equal("selected", event.action)
        assert.are.equal("crossroads", event.metadata.passageId)
        assert.are.equal("choice_1", event.metadata.choiceId)
      end)
    end)

    describe("saveCreate", function()
      it("should create save.create event", function()
        local event = EventBuilder.saveCreate("save-001", "chapter_2")
        assert.are.equal("save", event.category)
        assert.are.equal("create", event.action)
        assert.are.equal("save-001", event.metadata.saveId)
        assert.are.equal("chapter_2", event.metadata.currentPassage)
      end)
    end)

    describe("saveLoad", function()
      it("should create save.load event", function()
        local event = EventBuilder.saveLoad("save-001", "chapter_2")
        assert.are.equal("save", event.category)
        assert.are.equal("load", event.action)
        assert.are.equal("save-001", event.metadata.saveId)
        assert.are.equal("chapter_2", event.metadata.loadedPassage)
      end)
    end)

    describe("errorScript", function()
      it("should create error.script event", function()
        local event = EventBuilder.errorScript(
          "RuntimeError",
          "Variable not found",
          "error"
        )
        assert.are.equal("error", event.category)
        assert.are.equal("script", event.action)
        assert.are.equal("RuntimeError", event.metadata.errorType)
        assert.are.equal("Variable not found", event.metadata.errorMessage)
        assert.are.equal("error", event.metadata.severity)
      end)
    end)

    describe("consentChange", function()
      it("should create user.consent_change event", function()
        local event = EventBuilder.consentChange(0, 2)
        assert.are.equal("user", event.category)
        assert.are.equal("consent_change", event.action)
        assert.are.equal(0, event.metadata.previousLevel)
        assert.are.equal(2, event.metadata.newLevel)
      end)
    end)

    describe("testExposure", function()
      it("should create test.exposure event", function()
        local event = EventBuilder.testExposure("test-001", "variant-A")
        assert.are.equal("test", event.category)
        assert.are.equal("exposure", event.action)
        assert.are.equal("test-001", event.metadata.testId)
        assert.are.equal("variant-A", event.metadata.variantId)
      end)
    end)

    describe("testConversion", function()
      it("should create test.conversion event", function()
        local event = EventBuilder.testConversion(
          "test-001",
          "variant-A",
          "purchase"
        )
        assert.are.equal("test", event.category)
        assert.are.equal("conversion", event.action)
        assert.are.equal("test-001", event.metadata.testId)
        assert.are.equal("variant-A", event.metadata.variantId)
        assert.are.equal("purchase", event.metadata.conversionType)
      end)
    end)
  end)

  describe("reset", function()
    it("should reset all state", function()
      local oldSessionId = EventBuilder.getSessionId()

      EventBuilder.reset()
      EventBuilder.initialize({})

      local newSessionId = EventBuilder.getSessionId()
      assert.are_not.equal(oldSessionId, newSessionId)
    end)
  end)
end)
