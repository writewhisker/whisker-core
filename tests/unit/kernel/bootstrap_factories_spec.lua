--- Bootstrap Factories Integration Tests
-- Tests for the factory wiring in Bootstrap
-- @module tests.unit.kernel.bootstrap_factories_spec
-- @author Whisker Core Team

describe("Bootstrap factory wiring", function()
  local Bootstrap

  before_each(function()
    -- Clear package cache to ensure fresh state
    package.loaded["whisker.kernel.bootstrap"] = nil
    package.loaded["whisker.kernel.init"] = nil
    Bootstrap = require("whisker.kernel.bootstrap")
  end)

  describe("factory registration", function()
    it("registers choice_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("choice_factory"))
    end)

    it("registers passage_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("passage_factory"))
    end)

    it("registers story_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("story_factory"))
    end)

    it("registers game_state_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("game_state_factory"))
    end)

    it("registers lua_interpreter_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("lua_interpreter_factory"))
    end)

    it("registers engine_factory", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("engine_factory"))
    end)

    it("registers event_bus alias", function()
      local kernel = Bootstrap.create()

      assert.is_true(kernel.container:has("event_bus"))
      -- Both events and event_bus should resolve to an event bus instance
      local event_bus = kernel.container:resolve("event_bus")
      assert.is_function(event_bus.emit)
      assert.is_function(event_bus.on)
    end)
  end)

  describe("factory resolution", function()
    it("resolves choice_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("choice_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("resolves passage_factory with choice_factory injected", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("passage_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
      assert.is_not_nil(factory:get_choice_factory())
    end)

    it("resolves story_factory with passage_factory injected", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("story_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
      assert.is_not_nil(factory:get_passage_factory())
    end)

    it("resolves game_state_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("game_state_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("resolves lua_interpreter_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("lua_interpreter_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)

    it("resolves engine_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("engine_factory")

      assert.is_not_nil(factory)
      assert.is_function(factory.create)
    end)
  end)

  describe("factory usage", function()
    it("creates choices via factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("choice_factory")

      local choice = factory:create({ text = "Go", target = "next" })

      assert.equals("Go", choice.text)
    end)

    it("creates passages via factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("passage_factory")

      local passage = factory:create({ id = "test", name = "Test" })

      assert.equals("test", passage.id)
    end)

    it("creates stories via factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("story_factory")

      local story = factory:create({ title = "My Story" })

      assert.equals("My Story", story.metadata.name)
    end)

    it("creates game states via factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("game_state_factory")

      local state = factory:create()

      assert.is_function(state.set)
      assert.is_function(state.get)
    end)

    it("creates interpreters via factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("lua_interpreter_factory")

      local interpreter = factory:create()

      assert.is_function(interpreter.execute_code)
    end)

    it("creates engines via factory", function()
      local kernel = Bootstrap.create()
      local engine_factory = kernel.container:resolve("engine_factory")
      local story_factory = kernel.container:resolve("story_factory")

      local story = story_factory:create({ title = "Test" })
      local engine = engine_factory:create(story)

      assert.is_function(engine.start_story)
    end)
  end)

  describe("dependency chain", function()
    it("passage factory uses choice factory", function()
      local kernel = Bootstrap.create()
      local pf = kernel.container:resolve("passage_factory")

      -- Create passage with choices
      local data = {
        id = "test",
        name = "Test",
        choices = {
          { text = "A", target_passage = "a" }
        }
      }
      local passage = pf:from_table(data)

      -- Choice should have methods (metatable restored)
      assert.is_function(passage.choices[1].validate)
    end)

    it("story factory uses passage factory", function()
      local kernel = Bootstrap.create()
      local sf = kernel.container:resolve("story_factory")

      -- Create story with passages
      local data = {
        metadata = { name = "Test" },
        passages = {
          start = { id = "start", name = "Start" }
        }
      }
      local story = sf:from_table(data)

      -- Passage should have methods (metatable restored)
      assert.is_function(story.passages.start.validate)
    end)

    it("engine uses all factories correctly", function()
      local kernel = Bootstrap.create()
      local ef = kernel.container:resolve("engine_factory")
      local sf = kernel.container:resolve("story_factory")

      -- Create a minimal story
      local story = sf:create({ title = "Test" })
      local Passage = require("whisker.core.passage")
      local passage = Passage.new({ id = "start", name = "Start", content = "Hello" })
      story:add_passage(passage)
      story:set_start_passage("start")

      -- Create engine
      local engine = ef:create(story)

      -- Should be able to start
      local content = engine:start_story()
      assert.equals("start", content.passage_id)
    end)
  end)

  describe("singleton behavior", function()
    it("returns same choice_factory instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("choice_factory")
      local f2 = kernel.container:resolve("choice_factory")

      assert.equals(f1, f2)
    end)

    it("returns same passage_factory instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("passage_factory")
      local f2 = kernel.container:resolve("passage_factory")

      assert.equals(f1, f2)
    end)

    it("returns same story_factory instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("story_factory")
      local f2 = kernel.container:resolve("story_factory")

      assert.equals(f1, f2)
    end)
  end)
end)
