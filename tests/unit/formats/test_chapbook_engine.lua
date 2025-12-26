-- Unit Tests for Chapbook Engine
local ChapbookEngine = require("whisker.formats.chapbook.engine")

describe("Chapbook Engine", function()
  local engine
  local mock_events

  before_each(function()
    mock_events = {
      emit = function() end
    }
    engine = ChapbookEngine.new({events = mock_events})
  end)

  describe("new", function()
    it("should create a new engine instance", function()
      assert.is_not_nil(engine)
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)

    it("should work without dependencies", function()
      local e = ChapbookEngine.new()
      assert.is_not_nil(e)
    end)
  end)

  describe("create", function()
    it("should create engine via container pattern", function()
      local mock_container = {
        has = function(_, name)
          return name == "events"
        end,
        resolve = function(_, name)
          if name == "events" then return mock_events end
        end
      }
      local e = ChapbookEngine.create(mock_container)
      assert.is_not_nil(e)
    end)
  end)

  describe("load", function()
    it("should load a valid story", function()
      local story = {
        passages = {
          {name = "Start", content = "Hello world", tags = {}}
        }
      }
      local ok, err = engine:load(story)
      assert.is_true(ok)
      assert.is_nil(err)
      assert.is_true(engine:is_loaded())
    end)

    it("should reject loading twice", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      local ok, err = engine:load(story)
      assert.is_nil(ok)
      assert.matches("already loaded", err)
    end)

    it("should reject invalid story", function()
      local ok, err = engine:load({})
      assert.is_nil(ok)
      assert.matches("no passages", err)
    end)
  end)

  describe("start", function()
    it("should start a loaded story", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      local ok = engine:start()
      assert.is_true(ok)
      assert.is_true(engine:is_started())
    end)

    it("should reject starting without loading", function()
      local ok, err = engine:start()
      assert.is_nil(ok)
      assert.matches("No story loaded", err)
    end)
  end)

  describe("goto_passage", function()
    before_each(function()
      local story = {
        passages = {
          {name = "Start", content = "Begin", tags = {}},
          {name = "End", content = "Finish", tags = {}}
        }
      }
      engine:load(story)
      engine:start()
    end)

    it("should navigate to a passage", function()
      local ok = engine:goto_passage("End")
      assert.is_true(ok)
      local passage = engine:get_current_passage()
      assert.equals("End", passage.name)
    end)

    it("should track history", function()
      engine:goto_passage("End")
      local history = engine:get_history()
      assert.equals(2, #history)
    end)
  end)

  describe("vars section processing", function()
    it("should process vars section", function()
      local story = {
        passages = {{name = "Start", content = "score: 100\nname: Alice\n--\nHello!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:get_current_passage()
      assert.equals(100, engine:get_variable("score"))
      assert.equals("Alice", engine:get_variable("name"))
    end)

    it("should return text section only", function()
      local story = {
        passages = {{name = "Start", content = "score: 100\n--\nHello world!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Hello world!", passage.content)
      assert.is_not.matches("score:", passage.content)
    end)
  end)

  describe("variable handling", function()
    it("should set variable programmatically", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:set_variable("name", "Carol")
      assert.equals("Carol", engine:get_variable("name"))
    end)

    it("should get all variables", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:set_variable("a", 1)
      engine:set_variable("b", 2)
      local vars = engine:get_variables()
      assert.equals(1, vars.a)
      assert.equals(2, vars.b)
    end)
  end)

  describe("content processing", function()
    it("should interpolate variables with {var}", function()
      local story = {
        passages = {{name = "Start", content = "name: Alice\n--\nHello {name}!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Hello Alice!", passage.content)
    end)

    it("should process [if condition] modifier when true", function()
      local story = {
        passages = {{name = "Start", content = "score: 10\n--\n[if score > 5]High score!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("High score!", passage.content)
    end)

    it("should process [if condition] modifier when false", function()
      local story = {
        passages = {{name = "Start", content = "score: 1\n--\n[if score > 5]High score!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not.matches("High score!", passage.content)
    end)

    it("should process [unless condition] modifier when true", function()
      local story = {
        passages = {{name = "Start", content = "visited: true\n--\n[unless visited]First time!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not.matches("First time!", passage.content)
    end)

    it("should process [unless condition] modifier when false", function()
      local story = {
        passages = {{name = "Start", content = "visited: false\n--\n[unless visited]First time!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("First time!", passage.content)
    end)

    it("should remove [cont'd] modifier", function()
      local story = {
        passages = {{name = "Start", content = "[cont'd]Continuing...", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Continuing...", passage.content)
      assert.is_not.matches("%[cont'd%]", passage.content)
    end)
  end)

  describe("link extraction", function()
    it("should extract arrow links", function()
      local story = {
        passages = {{name = "Start", content = "[[Go north->North]]", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals(1, #passage.links)
      assert.equals("Go north", passage.links[1].text)
      assert.equals("North", passage.links[1].target)
    end)

    it("should extract simple links", function()
      local story = {
        passages = {{name = "Start", content = "[[North]]", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals(1, #passage.links)
      assert.equals("North", passage.links[1].target)
    end)
  end)

  describe("follow_link", function()
    it("should navigate via link", function()
      local story = {
        passages = {
          {name = "Start", content = "[[Go->End]]", tags = {}},
          {name = "End", content = "Done", tags = {}}
        }
      }
      engine:load(story)
      engine:start()
      local ok = engine:follow_link("End")
      assert.is_true(ok)
      assert.equals("End", engine:get_current_passage().name)
    end)
  end)

  describe("end_story", function()
    it("should mark story as ended", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:end_story()
      assert.is_true(engine:has_ended())
    end)
  end)

  describe("reset", function()
    it("should reset engine state", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:reset()
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)
  end)

  describe("get_metadata", function()
    it("should return engine metadata", function()
      local meta = engine:get_metadata()
      assert.equals("chapbook", meta.format)
      assert.equals("1.0.0", meta.version)
    end)
  end)
end)
