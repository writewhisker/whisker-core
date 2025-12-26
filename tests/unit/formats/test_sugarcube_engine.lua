-- Unit Tests for SugarCube Engine
local SugarCubeEngine = require("whisker.formats.sugarcube.engine")

describe("SugarCube Engine", function()
  local engine
  local mock_events

  before_each(function()
    mock_events = {
      emit = function() end
    }
    engine = SugarCubeEngine.new({events = mock_events})
  end)

  describe("new", function()
    it("should create a new engine instance", function()
      assert.is_not_nil(engine)
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)

    it("should work without dependencies", function()
      local e = SugarCubeEngine.new()
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
      local e = SugarCubeEngine.create(mock_container)
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

    it("should find start tagged passage", function()
      local story = {
        passages = {
          {name = "Intro", content = "Welcome", tags = {"start"}}
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

    it("should track visited count", function()
      engine:goto_passage("End")
      engine:goto_passage("Start")
      engine:goto_passage("End")
      assert.equals(2, engine:visited("End"))
      assert.equals(2, engine:visited("Start"))
    end)

    it("should clear temporary variables on passage change", function()
      -- Set up a passage with temporary variable
      engine._temporary["temp"] = 42
      engine:goto_passage("End")
      assert.is_nil(engine._temporary["temp"])
    end)
  end)

  describe("variable handling", function()
    before_each(function()
      local story = {
        passages = {{name = "Start", content = "<<set $score to 100>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
    end)

    it("should process set macro", function()
      engine:get_current_passage()
      assert.equals(100, engine:get_variable("score"))
    end)

    it("should set variable programmatically", function()
      engine:set_variable("name", "Bob")
      assert.equals("Bob", engine:get_variable("name"))
    end)

    it("should get all variables", function()
      engine:set_variable("a", 1)
      engine:set_variable("b", 2)
      local vars = engine:get_variables()
      assert.equals(1, vars.a)
      assert.equals(2, vars.b)
    end)
  end)

  describe("temporary variables", function()
    it("should process temporary set macro", function()
      local story = {
        passages = {{name = "Start", content = "<<set _temp to 'hello'>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:get_current_passage()
      assert.equals("hello", engine._temporary["temp"])
    end)
  end)

  describe("content processing", function()
    it("should process if macro when true", function()
      local story = {
        passages = {{name = "Start", content = "<<set $x to 5>><<if $x > 3>>Big!<</if>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Big!", passage.content)
    end)

    it("should process if macro when false", function()
      local story = {
        passages = {{name = "Start", content = "<<set $x to 1>><<if $x > 3>>Big!<</if>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.is_not.matches("Big!", passage.content)
    end)

    it("should interpolate variables", function()
      local story = {
        passages = {{name = "Start", content = "<<set $name to \"Bob\">>Hello $name!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Hello Bob!", passage.content)
    end)

    it("should process print macro", function()
      local story = {
        passages = {{name = "Start", content = "<<set $x to 42>><<print $x>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("42", passage.content)
    end)

    it("should process shorthand <<= $var>>", function()
      local story = {
        passages = {{name = "Start", content = "<<set $x to 99>><<= $x>>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("99", passage.content)
    end)
  end)

  describe("link extraction", function()
    it("should extract pipe links", function()
      local story = {
        passages = {{name = "Start", content = "[[Go north|North]]", tags = {}}}
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

  describe("visited function in conditions", function()
    it("should evaluate visited condition", function()
      local story = {
        passages = {
          {name = "Start", content = "<<if visited('End')>>Been there<</if>>", tags = {}},
          {name = "End", content = "End", tags = {}}
        }
      }
      engine:load(story)
      engine:start()

      -- Initially End not visited
      local passage = engine:get_current_passage()
      assert.is_not.matches("Been there", passage.content)

      -- Visit End and come back
      engine:goto_passage("End")
      engine:goto_passage("Start")
      passage = engine:get_current_passage()
      assert.matches("Been there", passage.content)
    end)
  end)

  describe("history and navigation", function()
    before_each(function()
      local story = {
        passages = {
          {name = "Start", content = "Begin", tags = {}},
          {name = "Middle", content = "Middle", tags = {}},
          {name = "End", content = "End", tags = {}}
        }
      }
      engine:load(story)
      engine:start()
    end)

    it("should track history", function()
      engine:goto_passage("Middle")
      engine:goto_passage("End")
      local history = engine:get_history()
      assert.equals(3, #history)
      assert.equals("Start", history[1])
      assert.equals("Middle", history[2])
      assert.equals("End", history[3])
    end)

    it("should go back in history", function()
      engine:goto_passage("Middle")
      engine:goto_passage("End")
      local ok = engine:go_back()
      assert.is_true(ok)
      assert.equals("Middle", engine:get_current_passage().name)
    end)

    it("should reject go_back with no history", function()
      local ok, err = engine:go_back()
      assert.is_nil(ok)
      assert.matches("No history", err)
    end)
  end)

  describe("follow_link", function()
    it("should navigate via link", function()
      local story = {
        passages = {
          {name = "Start", content = "[[Go|End]]", tags = {}},
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
      engine:set_variable("x", 1)
      engine:reset()
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
      assert.is_nil(engine:get_variable("x"))
    end)
  end)

  describe("get_metadata", function()
    it("should return engine metadata", function()
      local meta = engine:get_metadata()
      assert.equals("sugarcube", meta.format)
      assert.equals("1.0.0", meta.version)
    end)
  end)
end)
