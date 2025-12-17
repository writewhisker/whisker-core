-- spec/formats/ink/engine_spec.lua
-- Tests for InkEngine IEngine implementation

describe("InkEngine", function()
  local InkEngine
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.vendor%.tinta") then
        package.loaded[k] = nil
      end
    end
    -- Clear tinta globals
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    InkEngine = require("whisker.formats.ink.engine")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkEngine._whisker)
      assert.are.equal("InkEngine", InkEngine._whisker.name)
      assert.are.equal("IEngine", InkEngine._whisker.implements)
    end)

    it("should have version", function()
      assert.is_string(InkEngine._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("engine.ink", InkEngine._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local engine = InkEngine.new()
      assert.is_table(engine)
    end)

    it("should accept options", function()
      local emitter = { emit = function() end }
      local engine = InkEngine.new({ event_emitter = emitter })
      assert.is_table(engine)
    end)
  end)

  describe("load", function()
    it("should load from InkStory wrapper", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.is_true(engine:is_loaded())
    end)

    it("should load from raw story data", function()
      local engine = InkEngine.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello, World!\n", "done", {["#n"] = "g-0"}},
        listDefs = {}
      }

      engine:load(data)
      assert.is_true(engine:is_loaded())
    end)

    it("should error on invalid story", function()
      local engine = InkEngine.new()

      assert.has_error(function()
        engine:load("not a story")
      end)
    end)

    it("should error on missing inkVersion", function()
      local engine = InkEngine.new()

      assert.has_error(function()
        engine:load({ root = {} })
      end)
    end)

    it("should emit load event", function()
      local emitted = false
      local emitter = {
        emit = function(self, event, data)
          if event == "ink.engine.loaded" then
            emitted = true
          end
        end
      }
      local engine = InkEngine.new({ event_emitter = emitter })
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.is_true(emitted)
    end)

    it("should reset state on new load", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()
      assert.is_true(engine:is_started())

      -- Load new story
      engine:load(story)
      assert.is_false(engine:is_started())
    end)
  end)

  describe("start", function()
    it("should start the story", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      assert.is_true(engine:is_started())
    end)

    it("should error without loaded story", function()
      local engine = InkEngine.new()

      assert.has_error(function()
        engine:start()
      end)
    end)

    it("should emit start event", function()
      local emitted = false
      local emitter = {
        emit = function(self, event, data)
          if event == "ink.engine.started" then
            emitted = true
          end
        end
      }
      local engine = InkEngine.new({ event_emitter = emitter })
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()
      assert.is_true(emitted)
    end)

    it("should process initial content", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local text = engine:get_current_text()
      assert.truthy(text:match("Hello"))
    end)
  end)

  describe("can_continue", function()
    it("should return false before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.is_false(engine:can_continue())
    end)

    it("should return false at story end", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      -- minimal.json is a simple story that ends after the greeting
      assert.is_false(engine:can_continue())
    end)
  end)

  describe("get_current_text", function()
    it("should return empty before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.are.equal("", engine:get_current_text())
    end)

    it("should return story text after start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local text = engine:get_current_text()
      assert.truthy(text:match("Hello"))
    end)
  end)

  describe("get_current_tags", function()
    it("should return empty array by default", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local tags = engine:get_current_tags()
      assert.is_table(tags)
    end)
  end)

  describe("get_current_passage", function()
    it("should return nil before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.is_nil(engine:get_current_passage())
    end)

    it("should return passage-like object after start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local passage = engine:get_current_passage()
      assert.is_table(passage)
      assert.is_string(passage.content)
      assert.is_table(passage.tags)
    end)
  end)

  describe("get_available_choices", function()
    it("should return empty array at story end", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local choices = engine:get_available_choices()
      assert.is_table(choices)
      assert.are.equal(0, #choices)
    end)

    it("should return empty before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)

      local choices = engine:get_available_choices()
      assert.is_table(choices)
      assert.are.equal(0, #choices)
    end)
  end)

  describe("has_ended", function()
    it("should return false before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.is_false(engine:has_ended())
    end)

    it("should return true at story end", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      -- minimal.json ends after the greeting
      assert.is_true(engine:has_ended())
    end)
  end)

  describe("reset", function()
    it("should reset engine state", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()
      assert.is_true(engine:is_started())

      engine:reset()
      assert.is_false(engine:is_started())
      assert.are.equal("", engine:get_current_text())
    end)
  end)

  describe("set_event_emitter", function()
    it("should set event emitter", function()
      local engine = InkEngine.new()
      local emitter = { emit = function() end }

      engine:set_event_emitter(emitter)
      -- Should not error
    end)
  end)

  describe("get_story", function()
    it("should return nil before load", function()
      local engine = InkEngine.new()
      assert.is_nil(engine:get_story())
    end)

    it("should return InkStory after load", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      assert.are.equal(story, engine:get_story())
    end)
  end)

  describe("IEngine interface", function()
    it("should implement required methods", function()
      local engine = InkEngine.new()

      -- Required by IEngine
      assert.is_function(engine.load)
      assert.is_function(engine.start)
      assert.is_function(engine.get_current_passage)
      assert.is_function(engine.get_available_choices)
      assert.is_function(engine.make_choice)
      assert.is_function(engine.can_continue)
    end)

    it("should implement optional methods", function()
      local engine = InkEngine.new()

      -- Optional
      assert.is_function(engine.reset)
    end)
  end)
end)
