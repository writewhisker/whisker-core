--- SpecialPassages Unit Tests
-- Comprehensive unit tests for the SpecialPassages module
-- @module tests.unit.core.test_special_passages_spec
-- @author Whisker Core Team

describe("SpecialPassages", function()
  local SpecialPassages, Story, Passage, EventSystem

  before_each(function()
    SpecialPassages = require("whisker.core.special_passages")
    Story = require("whisker.core.story")
    Passage = require("whisker.core.passage")
    EventSystem = require("whisker.core.event_system")
  end)

  describe("initialization", function()
    it("creates instance without dependencies", function()
      local sp = SpecialPassages.new()

      assert.is_not_nil(sp)
    end)

    it("creates instance with event_bus dependency", function()
      local event_bus = EventSystem.new()
      local sp = SpecialPassages.new({ event_bus = event_bus })

      assert.is_not_nil(sp)
      assert.equals(event_bus, sp._event_bus)
    end)

    it("initializes with no story", function()
      local sp = SpecialPassages.new()

      assert.is_nil(sp._story)
    end)

    it("initializes init_executed as false", function()
      local sp = SpecialPassages.new()

      assert.is_false(sp._init_executed)
    end)

    it("provides create factory method for DI", function()
      assert.is_function(SpecialPassages.create)
    end)

    it("create method returns instance", function()
      local sp = SpecialPassages.create({})

      assert.is_not_nil(sp)
    end)

    it("declares _dependencies for DI", function()
      assert.is_table(SpecialPassages._dependencies)
      assert.equals("event_bus", SpecialPassages._dependencies[1])
    end)
  end)

  describe("NAMES constants", function()
    it("defines StoryData", function()
      assert.equals("StoryData", SpecialPassages.NAMES.STORY_DATA)
    end)

    it("defines StoryInit", function()
      assert.equals("StoryInit", SpecialPassages.NAMES.STORY_INIT)
    end)

    it("defines Start", function()
      assert.equals("Start", SpecialPassages.NAMES.START)
    end)

    it("defines StoryMenu", function()
      assert.equals("StoryMenu", SpecialPassages.NAMES.STORY_MENU)
    end)

    it("defines PassageHeader", function()
      assert.equals("PassageHeader", SpecialPassages.NAMES.PASSAGE_HEADER)
    end)

    it("defines PassageFooter", function()
      assert.equals("PassageFooter", SpecialPassages.NAMES.PASSAGE_FOOTER)
    end)

    it("defines StoryCaption", function()
      assert.equals("StoryCaption", SpecialPassages.NAMES.STORY_CAPTION)
    end)

    it("defines StoryBanner", function()
      assert.equals("StoryBanner", SpecialPassages.NAMES.STORY_BANNER)
    end)

    it("defines PassageDone", function()
      assert.equals("PassageDone", SpecialPassages.NAMES.PASSAGE_DONE)
    end)

    it("defines PassageReady", function()
      assert.equals("PassageReady", SpecialPassages.NAMES.PASSAGE_READY)
    end)
  end)

  describe("set_story", function()
    it("sets the story reference", function()
      local sp = SpecialPassages.new()
      local story = Story.new({ name = "Test" })

      sp:set_story(story)

      assert.equals(story, sp._story)
    end)

    it("resets init_executed when story changes", function()
      local sp = SpecialPassages.new()
      sp._init_executed = true

      sp:set_story(Story.new({ name = "Test" }))

      assert.is_false(sp._init_executed)
    end)
  end)

  describe("set_interpreter", function()
    it("sets the interpreter reference", function()
      local sp = SpecialPassages.new()
      local mock_interpreter = { execute_code = function() end }

      sp:set_interpreter(mock_interpreter)

      assert.equals(mock_interpreter, sp._interpreter)
    end)
  end)

  describe("set_game_state", function()
    it("sets the game state reference", function()
      local sp = SpecialPassages.new()
      local mock_state = { variables = {} }

      sp:set_game_state(mock_state)

      assert.equals(mock_state, sp._game_state)
    end)
  end)

  describe("get", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no story set", function()
      local sp2 = SpecialPassages.new()

      local result = sp2:get("Start")

      assert.is_nil(result)
    end)

    it("returns nil for non-existent passage", function()
      local result = sp:get("NonExistent")

      assert.is_nil(result)
    end)

    it("returns passage when it exists", function()
      local passage = Passage.new({ id = "Start", name = "Start" })
      story:add_passage(passage)

      local result = sp:get("Start")

      assert.equals(passage, result)
    end)
  end)

  describe("exists", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns false when passage does not exist", function()
      assert.is_false(sp:exists("StoryInit"))
    end)

    it("returns true when passage exists", function()
      story:add_passage(Passage.new({ id = "StoryInit", name = "StoryInit" }))

      assert.is_true(sp:exists("StoryInit"))
    end)
  end)

  describe("is_special", function()
    local sp

    before_each(function()
      sp = SpecialPassages.new()
    end)

    it("returns true for Start", function()
      assert.is_true(sp:is_special("Start"))
    end)

    it("returns true for StoryInit", function()
      assert.is_true(sp:is_special("StoryInit"))
    end)

    it("returns true for PassageHeader", function()
      assert.is_true(sp:is_special("PassageHeader"))
    end)

    it("returns true for PassageFooter", function()
      assert.is_true(sp:is_special("PassageFooter"))
    end)

    it("returns false for regular passage name", function()
      assert.is_false(sp:is_special("MyPassage"))
    end)

    it("returns false for empty string", function()
      assert.is_false(sp:is_special(""))
    end)
  end)

  describe("get_all_existing", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns empty table when no special passages", function()
      local result = sp:get_all_existing()

      assert.same({}, result)
    end)

    it("returns only existing special passages", function()
      story:add_passage(Passage.new({ id = "Start", name = "Start" }))
      story:add_passage(Passage.new({ id = "StoryInit", name = "StoryInit" }))
      story:add_passage(Passage.new({ id = "Regular", name = "Regular" }))

      local result = sp:get_all_existing()

      assert.is_not_nil(result.START)
      assert.is_not_nil(result.STORY_INIT)
      assert.is_nil(result.STORY_MENU)  -- Not added
    end)

    it("returns empty when no story set", function()
      local sp2 = SpecialPassages.new()

      local result = sp2:get_all_existing()

      assert.same({}, result)
    end)
  end)

  describe("execute_init", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns true when no StoryInit passage", function()
      local success, err = sp:execute_init()

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("sets init_executed to true", function()
      sp:execute_init()

      assert.is_true(sp._init_executed)
    end)

    it("only executes once", function()
      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = ""
      }))

      sp:execute_init()
      local exec_count = 0
      sp._init_executed = true  -- Already marked

      local success = sp:execute_init()

      assert.is_true(success)
      assert.is_true(sp._init_executed)
    end)

    it("emits SCRIPT_EXECUTED event", function()
      local event_bus = EventSystem.new()
      sp = SpecialPassages.new({ event_bus = event_bus })
      sp:set_story(story)

      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = ""
      }))

      local event_received = nil
      event_bus:on("SCRIPT_EXECUTED", function(event)
        event_received = event
      end)

      sp:execute_init()

      assert.is_not_nil(event_received)
      assert.equals("StoryInit", event_received.data.passage)
      assert.equals("story_init", event_received.data.phase)
    end)
  end)

  describe("execute_header", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns true when no PassageHeader passage", function()
      local success, err = sp:execute_header()

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("emits event when passage exists", function()
      local event_bus = EventSystem.new()
      sp = SpecialPassages.new({ event_bus = event_bus })
      sp:set_story(story)

      story:add_passage(Passage.new({
        id = "PassageHeader",
        name = "PassageHeader",
        content = ""
      }))

      local event_received = nil
      event_bus:on("SCRIPT_EXECUTED", function(event)
        event_received = event
      end)

      sp:execute_header()

      assert.is_not_nil(event_received)
      assert.equals("header", event_received.data.phase)
    end)
  end)

  describe("execute_footer", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns true when no PassageFooter passage", function()
      local success, err = sp:execute_footer()

      assert.is_true(success)
      assert.is_nil(err)
    end)
  end)

  describe("execute_done", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns true when no PassageDone passage", function()
      local success, err = sp:execute_done()

      assert.is_true(success)
      assert.is_nil(err)
    end)
  end)

  describe("execute_ready", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns true when no PassageReady passage", function()
      local success, err = sp:execute_ready()

      assert.is_true(success)
      assert.is_nil(err)
    end)
  end)

  describe("get_caption_content", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no StoryCaption passage", function()
      local result = sp:get_caption_content()

      assert.is_nil(result)
    end)

    it("returns content when passage exists", function()
      local passage = Passage.new({
        id = "StoryCaption",
        name = "StoryCaption",
        content = "Caption text"
      })
      story:add_passage(passage)

      local result = sp:get_caption_content()

      assert.equals("Caption text", result)
    end)
  end)

  describe("get_banner_content", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no StoryBanner passage", function()
      local result = sp:get_banner_content()

      assert.is_nil(result)
    end)

    it("returns content when passage exists", function()
      local passage = Passage.new({
        id = "StoryBanner",
        name = "StoryBanner",
        content = "Banner text"
      })
      story:add_passage(passage)

      local result = sp:get_banner_content()

      assert.equals("Banner text", result)
    end)
  end)

  describe("get_menu_content", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no StoryMenu passage", function()
      local result = sp:get_menu_content()

      assert.is_nil(result)
    end)

    it("returns content when passage exists", function()
      local passage = Passage.new({
        id = "StoryMenu",
        name = "StoryMenu",
        content = "Menu content"
      })
      story:add_passage(passage)

      local result = sp:get_menu_content()

      assert.equals("Menu content", result)
    end)
  end)

  describe("get_start_passage", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no passages", function()
      local result = sp:get_start_passage()

      assert.is_nil(result)
    end)

    it("returns Start passage when it exists", function()
      local start = Passage.new({ id = "Start", name = "Start" })
      story:add_passage(start)

      local result = sp:get_start_passage()

      assert.equals(start, result)
    end)

    it("falls back to story's designated start passage", function()
      local other = Passage.new({ id = "other", name = "Other" })
      story:add_passage(other)
      story:set_start_passage("other")

      local result = sp:get_start_passage()

      assert.equals(other, result)
    end)

    it("falls back to first non-special passage", function()
      local regular = Passage.new({ id = "regular", name = "Regular" })
      story:add_passage(regular)

      local result = sp:get_start_passage()

      assert.equals(regular, result)
    end)

    it("skips special passages when finding fallback", function()
      local init = Passage.new({ id = "StoryInit", name = "StoryInit" })
      local regular = Passage.new({ id = "regular", name = "Regular" })
      story:add_passage(init)
      story:add_passage(regular)

      local result = sp:get_start_passage()

      -- Should return a non-special passage (the regular one)
      assert.is_not_nil(result)
      assert.is_false(sp:is_special(result.name or result.id))
      assert.equals("regular", result.id)
    end)
  end)

  describe("get_start_passage_name", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns nil when no start passage", function()
      local result = sp:get_start_passage_name()

      assert.is_nil(result)
    end)

    it("returns passage name", function()
      local start = Passage.new({ id = "Start", name = "Start" })
      story:add_passage(start)

      local result = sp:get_start_passage_name()

      assert.equals("Start", result)
    end)
  end)

  describe("validate_start", function()
    local sp, story

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)
    end)

    it("returns false when no start passage exists", function()
      local success, err = sp:validate_start()

      assert.is_false(success)
      assert.is_string(err)
    end)

    it("returns true when Start passage exists", function()
      story:add_passage(Passage.new({ id = "Start", name = "Start" }))

      local success, err = sp:validate_start()

      assert.is_true(success)
      assert.is_nil(err)
    end)

    it("returns true with any valid start passage", function()
      story:add_passage(Passage.new({ id = "beginning", name = "Beginning" }))
      story:set_start_passage("beginning")

      local success, err = sp:validate_start()

      assert.is_true(success)
    end)
  end)

  describe("is_init_executed", function()
    it("returns false initially", function()
      local sp = SpecialPassages.new()

      assert.is_false(sp:is_init_executed())
    end)

    it("returns true after execute_init", function()
      local sp = SpecialPassages.new()
      local story = Story.new({ name = "Test" })
      sp:set_story(story)

      sp:execute_init()

      assert.is_true(sp:is_init_executed())
    end)
  end)

  describe("reset", function()
    it("resets init_executed to false", function()
      local sp = SpecialPassages.new()
      sp._init_executed = true

      sp:reset()

      assert.is_false(sp._init_executed)
    end)
  end)

  describe("interpreter integration", function()
    local sp, story, mock_interpreter

    before_each(function()
      sp = SpecialPassages.new()
      story = Story.new({ name = "Test" })
      sp:set_story(story)

      mock_interpreter = {
        execute_code = function(self, code, state)
          if code:find("error") then
            return false, "Script error"
          end
          return true, nil
        end
      }
      sp:set_interpreter(mock_interpreter)
    end)

    it("executes passage content through interpreter", function()
      local executed_code = nil
      mock_interpreter.execute_code = function(self, code, state)
        executed_code = code
        return true, nil
      end

      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = "test = 1"
      }))

      sp:execute_init()

      assert.equals("test = 1", executed_code)
    end)

    it("returns error from interpreter", function()
      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = "error_code"
      }))

      local success, err = sp:execute_init()

      assert.is_false(success)
      assert.equals("Script error", err)
    end)

    it("emits ERROR_OCCURRED on script failure", function()
      local event_bus = EventSystem.new()
      sp = SpecialPassages.new({ event_bus = event_bus })
      sp:set_story(story)
      sp:set_interpreter(mock_interpreter)

      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = "error_code"
      }))

      local error_event = nil
      event_bus:on("ERROR_OCCURRED", function(event)
        error_event = event
      end)

      sp:execute_init()

      assert.is_not_nil(error_event)
      assert.equals("special_passage", error_event.data.source)
    end)
  end)
end)
