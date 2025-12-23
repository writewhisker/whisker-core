--- Unit tests for Event Builder
-- @module tests.analytics.event_builder_spec

describe("EventBuilder", function()
  local EventBuilder
  local EventTaxonomy

  before_each(function()
    package.loaded["whisker.analytics.event_builder"] = nil
    package.loaded["whisker.analytics.event_taxonomy"] = nil
    EventBuilder = require("whisker.analytics.event_builder")
    EventTaxonomy = require("whisker.analytics.event_taxonomy")
    EventBuilder.reset()
  end)

  describe("initialize()", function()
    it("should initialize with default config", function()
      EventBuilder.initialize()
      assert.is_not_nil(EventBuilder.getSessionId())
    end)

    it("should initialize with custom config", function()
      EventBuilder.initialize({
        storyId = "test-story",
        storyVersion = "2.0.0",
        storyTitle = "Test Story"
      })

      local event = EventBuilder.createBaseEvent("story", "start", {})
      assert.are.equal("test-story", event.storyId)
      assert.are.equal("2.0.0", event.storyVersion)
      assert.are.equal("Test Story", event.storyTitle)
    end)

    it("should generate session ID on initialize", function()
      EventBuilder.initialize()
      local sessionId = EventBuilder.getSessionId()
      assert.is_string(sessionId)
      assert.is_true(#sessionId > 0)
    end)
  end)

  describe("getSessionId()", function()
    it("should return consistent session ID", function()
      EventBuilder.initialize()
      local id1 = EventBuilder.getSessionId()
      local id2 = EventBuilder.getSessionId()
      assert.are.equal(id1, id2)
    end)

    it("should generate ID if not initialized", function()
      local id = EventBuilder.getSessionId()
      assert.is_string(id)
      assert.is_true(#id > 0)
    end)
  end)

  describe("startNewSession()", function()
    it("should generate new session ID", function()
      EventBuilder.initialize()
      local id1 = EventBuilder.getSessionId()
      local id2 = EventBuilder.startNewSession()
      assert.are_not.equal(id1, id2)
    end)

    it("should update session start time", function()
      EventBuilder.initialize()
      local startTime1 = EventBuilder.getSessionStartTime()
      -- Small delay to ensure time difference
      EventBuilder.startNewSession()
      local startTime2 = EventBuilder.getSessionStartTime()
      assert.is_true(startTime2 >= startTime1)
    end)
  end)

  describe("setDependencies()", function()
    it("should set event_taxonomy dependency", function()
      EventBuilder.setDependencies({
        event_taxonomy = EventTaxonomy
      })

      -- Should use taxonomy for validation
      local event, errors = EventBuilder.buildEvent("invalid", "invalid", {})
      assert.is_nil(event)
      assert.is_not_nil(errors)
    end)

    it("should set consent_manager dependency", function()
      local mockConsentManager = {
        getConsentLevel = function() return 3 end,
        getUserId = function() return "test-user-id" end
      }

      EventBuilder.setDependencies({
        consent_manager = mockConsentManager
      })

      assert.are.equal(3, EventBuilder.getConsentLevel())
      assert.are.equal("test-user-id", EventBuilder.getUserId())
    end)
  end)

  describe("createBaseEvent()", function()
    it("should create event with required fields", function()
      EventBuilder.initialize({ storyId = "test-story" })
      local event = EventBuilder.createBaseEvent("story", "start", {})

      assert.are.equal("story", event.category)
      assert.are.equal("start", event.action)
      assert.is_number(event.timestamp)
      assert.is_string(event.sessionId)
      assert.are.equal("test-story", event.storyId)
    end)

    it("should include metadata", function()
      EventBuilder.initialize()
      local event = EventBuilder.createBaseEvent("story", "start", {
        isFirstLaunch = true,
        initialPassage = "opening"
      })

      assert.is_true(event.metadata.isFirstLaunch)
      assert.are.equal("opening", event.metadata.initialPassage)
    end)

    it("should deep copy metadata", function()
      EventBuilder.initialize()
      local metadata = { nested = { value = 1 } }
      local event = EventBuilder.createBaseEvent("story", "start", metadata)

      metadata.nested.value = 2
      assert.are.equal(1, event.metadata.nested.value)
    end)

    it("should not include userId at lower consent levels", function()
      local mockConsentManager = {
        getConsentLevel = function() return 2 end,
        getUserId = function() return "test-user" end
      }

      EventBuilder.setDependencies({ consent_manager = mockConsentManager })
      EventBuilder.initialize()

      local event = EventBuilder.createBaseEvent("story", "start", {})
      assert.is_nil(event.userId)
    end)

    it("should include userId at FULL consent level", function()
      local mockConsentManager = {
        getConsentLevel = function() return 3 end,
        getUserId = function() return "test-user" end
      }

      EventBuilder.setDependencies({ consent_manager = mockConsentManager })
      EventBuilder.initialize()

      local event = EventBuilder.createBaseEvent("story", "start", {})
      assert.are.equal("test-user", event.userId)
    end)
  end)

  describe("buildEvent()", function()
    it("should build and validate event", function()
      EventBuilder.setDependencies({ event_taxonomy = EventTaxonomy })
      EventBuilder.initialize({ storyId = "test-story" })

      local event, errors = EventBuilder.buildEvent("story", "start", {
        isFirstLaunch = true,
        restoreFromSave = false,
        initialPassage = "opening"
      })

      assert.is_not_nil(event)
      assert.is_nil(errors)
      assert.are.equal("story", event.category)
    end)

    it("should return errors for invalid event", function()
      EventBuilder.setDependencies({ event_taxonomy = EventTaxonomy })
      EventBuilder.initialize({ storyId = "test-story" })

      local event, errors = EventBuilder.buildEvent("invalid_category", "invalid_action", {})

      assert.is_nil(event)
      assert.is_not_nil(errors)
      assert.is_true(#errors > 0)
    end)
  end)

  describe("buildEventFast()", function()
    it("should build event without validation", function()
      EventBuilder.initialize({ storyId = "test-story" })

      local event = EventBuilder.buildEventFast("invalid_category", "invalid_action", {})

      assert.is_not_nil(event)
      assert.are.equal("invalid_category", event.category)
    end)
  end)

  describe("convenience builders", function()
    before_each(function()
      EventBuilder.initialize({ storyId = "test-story" })
    end)

    describe("storyStart()", function()
      it("should create story.start event", function()
        local event = EventBuilder.storyStart({ initialPassage = "opening" })
        assert.are.equal("story", event.category)
        assert.are.equal("start", event.action)
        assert.are.equal("opening", event.metadata.initialPassage)
      end)

      it("should set defaults for missing fields", function()
        local event = EventBuilder.storyStart()
        assert.is_false(event.metadata.isFirstLaunch)
        assert.is_false(event.metadata.restoreFromSave)
      end)
    end)

    describe("storyResume()", function()
      it("should create story.resume event", function()
        local event = EventBuilder.storyResume({ resumePassage = "chapter_2" })
        assert.are.equal("story", event.category)
        assert.are.equal("resume", event.action)
        assert.are.equal("chapter_2", event.metadata.resumePassage)
      end)
    end)

    describe("storyComplete()", function()
      it("should create story.complete event", function()
        local event = EventBuilder.storyComplete({ completionPassage = "ending" })
        assert.are.equal("story", event.category)
        assert.are.equal("complete", event.action)
        assert.are.equal("ending", event.metadata.completionPassage)
      end)
    end)

    describe("storyAbandon()", function()
      it("should create story.abandon event", function()
        local event = EventBuilder.storyAbandon({ lastPassage = "chapter_5" })
        assert.are.equal("story", event.category)
        assert.are.equal("abandon", event.action)
        assert.are.equal("chapter_5", event.metadata.lastPassage)
      end)
    end)

    describe("storyRestart()", function()
      it("should create story.restart event", function()
        local event = EventBuilder.storyRestart({ restartReason = "new_game" })
        assert.are.equal("story", event.category)
        assert.are.equal("restart", event.action)
        assert.are.equal("new_game", event.metadata.restartReason)
      end)
    end)

    describe("passageView()", function()
      it("should create passage.view event", function()
        local event = EventBuilder.passageView("forest", "Forest Path", { wordCount = 150 })
        assert.are.equal("passage", event.category)
        assert.are.equal("view", event.action)
        assert.are.equal("forest", event.metadata.passageId)
        assert.are.equal("Forest Path", event.metadata.passageName)
        assert.are.equal(150, event.metadata.wordCount)
      end)
    end)

    describe("passageExit()", function()
      it("should create passage.exit event", function()
        local event = EventBuilder.passageExit("forest", 5000, { exitVia = "choice" })
        assert.are.equal("passage", event.category)
        assert.are.equal("exit", event.action)
        assert.are.equal("forest", event.metadata.passageId)
        assert.are.equal(5000, event.metadata.timeOnPassage)
        assert.are.equal("choice", event.metadata.exitVia)
      end)
    end)

    describe("choicePresented()", function()
      it("should create choice.presented event", function()
        local event = EventBuilder.choicePresented("forest", 3, { choiceIds = {"a", "b", "c"} })
        assert.are.equal("choice", event.category)
        assert.are.equal("presented", event.action)
        assert.are.equal("forest", event.metadata.passageId)
        assert.are.equal(3, event.metadata.choiceCount)
      end)
    end)

    describe("choiceSelected()", function()
      it("should create choice.selected event", function()
        local event = EventBuilder.choiceSelected("forest", "choice_a", { timeToDecide = 2000 })
        assert.are.equal("choice", event.category)
        assert.are.equal("selected", event.action)
        assert.are.equal("forest", event.metadata.passageId)
        assert.are.equal("choice_a", event.metadata.choiceId)
        assert.are.equal(2000, event.metadata.timeToDecide)
      end)
    end)

    describe("saveCreate()", function()
      it("should create save.create event", function()
        local event = EventBuilder.saveCreate("save_1", "forest", { saveName = "My Save" })
        assert.are.equal("save", event.category)
        assert.are.equal("create", event.action)
        assert.are.equal("save_1", event.metadata.saveId)
        assert.are.equal("forest", event.metadata.currentPassage)
      end)
    end)

    describe("saveLoad()", function()
      it("should create save.load event", function()
        local event = EventBuilder.saveLoad("save_1", "forest")
        assert.are.equal("save", event.category)
        assert.are.equal("load", event.action)
        assert.are.equal("save_1", event.metadata.saveId)
        assert.are.equal("forest", event.metadata.loadedPassage)
      end)
    end)

    describe("errorScript()", function()
      it("should create error.script event", function()
        local event = EventBuilder.errorScript("runtime", "Undefined variable", "error", { passageId = "forest" })
        assert.are.equal("error", event.category)
        assert.are.equal("script", event.action)
        assert.are.equal("runtime", event.metadata.errorType)
        assert.are.equal("Undefined variable", event.metadata.errorMessage)
        assert.are.equal("error", event.metadata.severity)
      end)
    end)

    describe("consentChange()", function()
      it("should create user.consent_change event", function()
        local event = EventBuilder.consentChange(0, 2, { changedVia = "settings" })
        assert.are.equal("user", event.category)
        assert.are.equal("consent_change", event.action)
        assert.are.equal(0, event.metadata.previousLevel)
        assert.are.equal(2, event.metadata.newLevel)
      end)
    end)

    describe("testExposure()", function()
      it("should create test.exposure event", function()
        local event = EventBuilder.testExposure("opening_test", "variant_a")
        assert.are.equal("test", event.category)
        assert.are.equal("exposure", event.action)
        assert.are.equal("opening_test", event.metadata.testId)
        assert.are.equal("variant_a", event.metadata.variantId)
      end)
    end)

    describe("testConversion()", function()
      it("should create test.conversion event", function()
        local event = EventBuilder.testConversion("opening_test", "variant_a", "story_complete", { value = 1 })
        assert.are.equal("test", event.category)
        assert.are.equal("conversion", event.action)
        assert.are.equal("opening_test", event.metadata.testId)
        assert.are.equal("variant_a", event.metadata.variantId)
        assert.are.equal("story_complete", event.metadata.conversionType)
      end)
    end)
  end)

  describe("reset()", function()
    it("should reset session state", function()
      EventBuilder.initialize({ storyId = "test-story" })
      local sessionId = EventBuilder.getSessionId()

      EventBuilder.reset()

      local newSessionId = EventBuilder.getSessionId()
      assert.are_not.equal(sessionId, newSessionId)
    end)

    it("should reset config to defaults", function()
      EventBuilder.initialize({ storyId = "custom-story" })
      EventBuilder.reset()

      local event = EventBuilder.createBaseEvent("story", "start", {})
      assert.are.equal("unknown", event.storyId)
    end)
  end)
end)
