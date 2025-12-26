-- Unit Tests for Harlowe Engine
local HarloweEngine = require("whisker.formats.harlowe.engine")

describe("Harlowe Engine", function()
  local engine
  local mock_events

  before_each(function()
    mock_events = {
      emit = function() end
    }
    engine = HarloweEngine.new({events = mock_events})
  end)

  describe("new", function()
    it("should create a new engine instance", function()
      assert.is_not_nil(engine)
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)

    it("should work without dependencies", function()
      local e = HarloweEngine.new()
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
      local e = HarloweEngine.create(mock_container)
      assert.is_not_nil(e)
    end)

    it("should handle nil container", function()
      local e = HarloweEngine.create(nil)
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

    it("should find Start passage", function()
      local story = {
        passages = {
          {name = "Other", content = "A", tags = {}},
          {name = "Start", content = "B", tags = {}}
        }
      }
      engine:load(story)
      -- Start method will use the Start passage
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals("Start", passage.name)
    end)

    it("should find startup tagged passage", function()
      local story = {
        passages = {
          {name = "Intro", content = "Welcome", tags = {"startup"}}
        }
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals("Intro", passage.name)
    end)
  end)

  describe("start", function()
    it("should start a loaded story", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      local ok, err = engine:start()
      assert.is_true(ok)
      assert.is_nil(err)
      assert.is_true(engine:is_started())
    end)

    it("should reject starting without loading", function()
      local ok, err = engine:start()
      assert.is_nil(ok)
      assert.matches("No story loaded", err)
    end)

    it("should reject starting twice", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local ok, err = engine:start()
      assert.is_nil(ok)
      assert.matches("already started", err)
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

    it("should reject navigation to non-existent passage", function()
      local ok, err = engine:goto_passage("NonExistent")
      assert.is_nil(ok)
      assert.matches("not found", err)
    end)

    it("should track history", function()
      engine:goto_passage("End")
      local history = engine:get_history()
      assert.equals(2, #history)
      assert.equals("Start", history[1])
      assert.equals("End", history[2])
    end)
  end)

  describe("variable handling", function()
    before_each(function()
      local story = {
        passages = {{name = "Start", content = "(set: $score to 100)", tags = {}}}
      }
      engine:load(story)
      engine:start()
    end)

    it("should process set macro", function()
      engine:get_current_passage()  -- Triggers processing
      assert.equals(100, engine:get_variable("score"))
    end)

    it("should set variable programmatically", function()
      engine:set_variable("name", "Alice")
      assert.equals("Alice", engine:get_variable("name"))
    end)

    it("should get all variables", function()
      engine:set_variable("a", 1)
      engine:set_variable("b", 2)
      local vars = engine:get_variables()
      assert.equals(1, vars.a)
      assert.equals(2, vars.b)
    end)
  end)

  describe("content processing", function()
    it("should process if macro when true", function()
      local story = {
        passages = {{name = "Start", content = "(set: $x to 5)(if: $x > 3)[Big!]", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Big!", passage.content)
    end)

    it("should process if macro when false", function()
      local story = {
        passages = {{name = "Start", content = "(set: $x to 1)(if: $x > 3)[Big!]", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not.matches("Big!", passage.content)
    end)

    it("should interpolate variables", function()
      local story = {
        passages = {{name = "Start", content = "(set: $name to \"Alice\")Hello $name!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Hello Alice!", passage.content)
    end)

    it("should process print macro", function()
      local story = {
        passages = {{name = "Start", content = "(set: $x to 42)(print: $x)", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("42", passage.content)
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
      assert.equals("harlowe", meta.format)
      assert.equals("1.0.0", meta.version)
      assert.is_false(meta.loaded)
    end)
  end)
end)
