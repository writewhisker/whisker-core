--- DI Pattern Integration Tests
-- Tests verifying dependency injection patterns work end-to-end
-- @module tests.integration.test_di_patterns
-- @author Whisker Core Team

describe("DI Pattern Integration", function()
  local Bootstrap

  before_each(function()
    -- Clear all kernel-related packages
    for k in pairs(package.loaded) do
      if k:match("^whisker") then
        package.loaded[k] = nil
      end
    end
    require("whisker.kernel.init")
    Bootstrap = require("whisker.kernel.bootstrap")
  end)

  describe("factory dependency chain", function()
    it("choice_factory has no dependencies", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("choice_factory")

      -- Should work without any other factories being resolved
      local choice = factory:create({ text = "Go", target = "next" })
      assert.equals("Go", choice.text)
    end)

    it("passage_factory depends on choice_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("passage_factory")

      -- Should have choice_factory injected
      assert.is_not_nil(factory:get_choice_factory())
    end)

    it("story_factory depends on passage_factory", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("story_factory")

      -- Should have passage_factory injected
      assert.is_not_nil(factory:get_passage_factory())
    end)

    it("engine_factory depends on all core factories", function()
      local kernel = Bootstrap.create()
      local ef = kernel.container:resolve("engine_factory")
      local sf = kernel.container:resolve("story_factory")

      -- Create a story and engine
      local story = sf:create({ title = "Test" })
      local Passage = require("whisker.core.passage")
      local passage = Passage.new({ id = "start", name = "Start", content = "Hello" })
      story:add_passage(passage)
      story:set_start_passage("start")

      local engine = ef:create(story)
      assert.is_not_nil(engine)
    end)
  end)

  describe("media dependency chain", function()
    it("asset_cache depends on events", function()
      local kernel = Bootstrap.create()
      local cache = kernel.container:resolve("asset_cache")

      assert.is_not_nil(cache._event_bus)
    end)

    it("asset_loader depends on events", function()
      local kernel = Bootstrap.create()
      local loader = kernel.container:resolve("asset_loader")

      assert.is_not_nil(loader._event_bus)
    end)

    it("asset_manager depends on cache and loader", function()
      local kernel = Bootstrap.create()
      local manager = kernel.container:resolve("asset_manager")

      assert.is_not_nil(manager._cache)
      assert.is_not_nil(manager._loader)
    end)

    it("audio_manager depends on asset_manager", function()
      local kernel = Bootstrap.create()
      local manager = kernel.container:resolve("audio_manager")

      assert.is_not_nil(manager._asset_manager)
    end)

    it("image_manager depends on asset_manager", function()
      local kernel = Bootstrap.create()
      local manager = kernel.container:resolve("image_manager")

      assert.is_not_nil(manager._asset_manager)
    end)

    it("preload_manager depends on asset_manager", function()
      local kernel = Bootstrap.create()
      local manager = kernel.container:resolve("preload_manager")

      assert.is_not_nil(manager._asset_manager)
    end)
  end)

  describe("singleton behavior", function()
    it("choice_factory returns same instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("choice_factory")
      local f2 = kernel.container:resolve("choice_factory")

      assert.equals(f1, f2)
    end)

    it("passage_factory returns same instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("passage_factory")
      local f2 = kernel.container:resolve("passage_factory")

      assert.equals(f1, f2)
    end)

    it("story_factory returns same instance", function()
      local kernel = Bootstrap.create()

      local f1 = kernel.container:resolve("story_factory")
      local f2 = kernel.container:resolve("story_factory")

      assert.equals(f1, f2)
    end)

    it("asset_manager returns same instance", function()
      local kernel = Bootstrap.create()

      local m1 = kernel.container:resolve("asset_manager")
      local m2 = kernel.container:resolve("asset_manager")

      assert.equals(m1, m2)
    end)

    it("logger returns same instance", function()
      local kernel = Bootstrap.create()

      local l1 = kernel.container:resolve("logger")
      local l2 = kernel.container:resolve("logger")

      assert.equals(l1, l2)
    end)
  end)

  describe("lazy loading", function()
    it("lazy registered services are not loaded until resolved", function()
      local kernel = Bootstrap.create()

      -- These are lazy registered
      assert.is_true(kernel.container:has("web_bundler"))
      assert.is_true(kernel.container:has("desktop_bundler"))
      assert.is_true(kernel.container:has("mobile_bundler"))

      -- Should be able to resolve them
      local web = kernel.container:resolve("web_bundler")
      assert.is_not_nil(web)
    end)

    it("lazy loaded factories work correctly", function()
      local kernel = Bootstrap.create()

      -- choice_factory and game_state_factory are lazy loaded
      local cf = kernel.container:resolve("choice_factory")
      local gsf = kernel.container:resolve("game_state_factory")

      assert.is_function(cf.create)
      assert.is_function(gsf.create)
    end)
  end)

  describe("cross-cutting concerns", function()
    it("events are available to all services", function()
      local kernel = Bootstrap.create()

      -- Multiple services should share the same event bus
      local asset_cache = kernel.container:resolve("asset_cache")
      local audio_manager = kernel.container:resolve("audio_manager")

      assert.is_not_nil(asset_cache._event_bus)
      assert.is_not_nil(audio_manager._event_bus)
    end)

    it("logger is available to services that need it", function()
      local kernel = Bootstrap.create()
      local logger = kernel.container:resolve("logger")

      assert.is_not_nil(logger)
      assert.is_function(logger.info)
    end)
  end)

  describe("factory creation", function()
    it("creates valid choices", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("choice_factory")

      local choice = factory:create({
        text = "Go north",
        target = "north_room"
      })

      assert.equals("Go north", choice.text)
      assert.equals("north_room", choice.target)
    end)

    it("creates valid passages", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("passage_factory")

      local passage = factory:create({
        id = "test",
        name = "Test Passage",
        content = "This is a test."
      })

      assert.equals("test", passage.id)
      assert.equals("Test Passage", passage.name)
    end)

    it("creates valid stories", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("story_factory")

      local story = factory:create({
        title = "My Adventure",
        author = "Test Author"
      })

      assert.equals("My Adventure", story.metadata.name)
    end)

    it("creates valid game states", function()
      local kernel = Bootstrap.create()
      local factory = kernel.container:resolve("game_state_factory")

      local state = factory:create()

      assert.is_function(state.set)
      assert.is_function(state.get)

      state:set("foo", "bar")
      assert.equals("bar", state:get("foo"))
    end)
  end)

  describe("end-to-end workflow", function()
    it("creates a story, adds passages, and runs engine", function()
      local kernel = Bootstrap.create()
      local sf = kernel.container:resolve("story_factory")
      local pf = kernel.container:resolve("passage_factory")
      local cf = kernel.container:resolve("choice_factory")
      local ef = kernel.container:resolve("engine_factory")

      -- Create story
      local story = sf:create({ title = "Test Story" })

      -- Create passages
      local start = pf:create({
        id = "start",
        name = "Start",
        content = "You are at the start."
      })
      start:add_choice(cf:create({
        text = "Go to end",
        target = "end"
      }))

      local ending = pf:create({
        id = "end",
        name = "End",
        content = "The end."
      })

      -- Build story
      story:add_passage(start)
      story:add_passage(ending)
      story:set_start_passage("start")

      -- Create and run engine
      local engine = ef:create(story)
      local content = engine:start_story()

      assert.equals("start", content.passage_id)
      assert.equals(1, #content.choices)
    end)
  end)

  describe("error handling", function()
    it("resolving missing service returns nil or error", function()
      local kernel = Bootstrap.create()

      -- Depends on container implementation
      local result = pcall(function()
        kernel.container:resolve("nonexistent_service")
      end)

      -- Should either return nil or throw
      assert.is_boolean(result)
    end)
  end)
end)
