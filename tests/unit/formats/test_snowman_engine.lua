-- Unit Tests for Snowman Engine
local SnowmanEngine = require("whisker.formats.snowman.engine")

describe("Snowman Engine", function()
  local engine
  local mock_events

  before_each(function()
    mock_events = {
      emit = function() end
    }
    engine = SnowmanEngine.new({events = mock_events})
  end)

  describe("new", function()
    it("should create a new engine instance", function()
      assert.is_not_nil(engine)
      assert.is_false(engine:is_loaded())
      assert.is_false(engine:is_started())
    end)

    it("should work without dependencies", function()
      local e = SnowmanEngine.new()
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
      local e = SnowmanEngine.create(mock_container)
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

  describe("variable handling", function()
    it("should process <% code %> blocks", function()
      local story = {
        passages = {{name = "Start", content = "<% s.score = 100; %>Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:get_current_passage()
      assert.equals(100, engine:get_variable("score"))
    end)

    it("should set variable programmatically", function()
      local story = {
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      engine:load(story)
      engine:start()
      engine:set_variable("name", "Dave")
      assert.equals("Dave", engine:get_variable("name"))
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
    it("should process <%= expr %> blocks", function()
      local story = {
        passages = {{name = "Start", content = "<% s.x = 42; %><%= s.x %>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("42", passage.content)
    end)

    it("should process ${expr} interpolation", function()
      local story = {
        passages = {{name = "Start", content = "<% s.name = 'Eve'; %>Hello ${s.name}!", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("Hello Eve!", passage.content)
    end)

    it("should remove <% code %> from output", function()
      local story = {
        passages = {{name = "Start", content = "<% s.x = 1; %>Text", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals("Text", passage.content)
    end)

    it("should handle arithmetic expressions", function()
      local story = {
        passages = {{name = "Start", content = "<% s.x = 10; %><%= s.x + 5 %>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("15", passage.content)
    end)

    it("should handle ternary expressions", function()
      local story = {
        passages = {{name = "Start", content = "<% s.flag = true; %><%= s.flag ? 'yes' : 'no' %>", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.matches("yes", passage.content)
    end)
  end)

  describe("link extraction", function()
    it("should extract markdown-style links", function()
      local story = {
        passages = {{name = "Start", content = "[Go north](North)", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals(1, #passage.links)
      assert.equals("Go north", passage.links[1].text)
      assert.equals("North", passage.links[1].target)
    end)

    it("should extract simple bracket links", function()
      local story = {
        passages = {{name = "Start", content = "[[North]]", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals(1, #passage.links)
      assert.equals("North", passage.links[1].target)
    end)

    it("should skip external URLs", function()
      local story = {
        passages = {{name = "Start", content = "[Link](https://example.com)", tags = {}}}
      }
      engine:load(story)
      engine:start()
      local passage = engine:get_current_passage()
      assert.equals(0, #passage.links)
    end)
  end)

  describe("follow_link", function()
    it("should navigate via link", function()
      local story = {
        passages = {
          {name = "Start", content = "[Go](End)", tags = {}},
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
      assert.equals("snowman", meta.format)
      assert.equals("1.0.0", meta.version)
    end)
  end)
end)
