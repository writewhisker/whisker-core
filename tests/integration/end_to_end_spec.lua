--- End-to-End Integration Tests
-- Comprehensive integration tests for whisker-core Phase 1
-- @module tests.integration.end_to_end_spec
-- @author Whisker Core Team

describe("End-to-End Integration", function()
  local Container, EventBus
  local Story, Passage, Choice
  local MockFactory

  setup(function()
    -- Load required modules
    Container = require("whisker.kernel.container")
    EventBus = require("whisker.kernel.events")
    Story = require("whisker.core.story")
    Passage = require("whisker.core.passage")
    Choice = require("whisker.core.choice")
    MockFactory = require("tests.mocks.mock_factory")
  end)

  describe("Container and DI integration", function()
    it("resolves singleton services correctly", function()
      local container = Container.new()
      container:register("events", EventBus, { singleton = true })

      local events1 = container:resolve("events")
      local events2 = container:resolve("events")

      assert.equals(events1, events2)
    end)

    it("creates transient instances", function()
      local container = Container.new()
      container:register("events", EventBus, { singleton = false })

      local events1 = container:resolve("events")
      local events2 = container:resolve("events")

      assert.not_equals(events1, events2)
    end)
  end)

  describe("Event bus integration", function()
    it("propagates events between subscribers", function()
      local events = EventBus.new()
      local received = {}

      events:on("test:event", function(data)
        table.insert(received, data)
      end)

      events:emit("test:event", { value = 1 })
      events:emit("test:event", { value = 2 })

      assert.equals(2, #received)
      assert.equals(1, received[1].value)
      assert.equals(2, received[2].value)
    end)

    it("supports wildcard subscriptions", function()
      local events = EventBus.new()
      local received = {}

      events:on("test:*", function(data)
        table.insert(received, data.event or "unknown")
      end)

      events:emit("test:one", { event = "one" })
      events:emit("test:two", { event = "two" })
      events:emit("other:event", { event = "other" })

      assert.equals(2, #received)
    end)
  end)

  describe("Story data model integration", function()
    local story

    before_each(function()
      story = Story.new({ title = "Integration Test" })
    end)

    it("manages passages correctly", function()
      local p1 = Passage.new({ id = "start", name = "Start" })
      local p2 = Passage.new({ id = "middle", name = "Middle" })
      local p3 = Passage.new({ id = "end", name = "End" })

      story:add_passage(p1)
      story:add_passage(p2)
      story:add_passage(p3)
      story:set_start_passage("start")

      assert.equals(3, #story:get_all_passages())
      assert.equals("start", story:get_start_passage())
    end)

    it("validates story structure", function()
      local passage = Passage.new({ id = "start", name = "Start" })
      story:add_passage(passage)
      story:set_start_passage("start")

      local valid, err = story:validate()
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("tracks variables", function()
      story:set_variable("player_name", "Alice")
      story:set_variable("score", 0)

      assert.equals("Alice", story:get_variable("player_name"))
      assert.equals(0, story:get_variable("score"))
    end)
  end)

  describe("Mock factory integration", function()
    it("creates mock state service", function()
      local state = MockFactory.create_state()

      state:set("key", "value")
      assert.equals("value", state:get("key"))
      assert.is_true(state:has("key"))

      state:delete("key")
      assert.is_false(state:has("key"))
    end)

    it("creates mock logger", function()
      local logger = MockFactory.create_logger()

      logger:info("Test message")
      logger:error("Error message")

      local logs = logger:get_logs()
      assert.equals(2, #logs)

      local errors = logger:get_logs("error")
      assert.equals(1, #errors)
    end)

    it("creates mock variables service", function()
      local events = EventBus.new()
      local vars = MockFactory.create_variables(events)

      local changed = false
      events:on("variable:changed", function()
        changed = true
      end)

      vars:set("test", 123)

      assert.equals(123, vars:get("test"))
      assert.is_true(changed)
    end)

    it("creates mock history service", function()
      local history = MockFactory.create_history()

      history:push({ passage_id = "p1" })
      history:push({ passage_id = "p2" })
      history:push({ passage_id = "p3" })

      assert.equals(3, history:depth())
      assert.is_true(history:can_go_back())

      local prev = history:go_back()
      assert.equals("p2", prev.passage_id)
      assert.equals(2, history:depth())
    end)

    it("creates mock persistence service", function()
      local persistence = MockFactory.create_persistence()

      local saved = persistence:save("slot1", { description = "Test" })
      assert.is_true(saved)

      local loaded = persistence:load("slot1")
      assert.is_true(loaded)

      local saves = persistence:list_saves()
      assert.equals(1, #saves)

      local metadata = persistence:get_metadata("slot1")
      assert.equals("Test", metadata.description)

      persistence:delete("slot1")
      assert.is_false(persistence:load("slot1"))
    end)

    it("creates spies for tracking calls", function()
      local spy_fn, tracker = MockFactory.spy(function(x)
        return x * 2
      end)

      local result1 = spy_fn(5)
      local result2 = spy_fn(10)

      assert.equals(10, result1)
      assert.equals(20, result2)
      assert.equals(2, tracker.call_count)
    end)
  end)

  describe("Passage and choice integration", function()
    it("builds passage with choices", function()
      local passage = Passage.new({
        id = "crossroads",
        name = "Crossroads",
        content = "You stand at a crossroads."
      })

      local left = Choice.new({
        text = "Go left",
        target = "forest"
      })

      local right = Choice.new({
        text = "Go right",
        target = "mountain"
      })

      passage:add_choice(left)
      passage:add_choice(right)

      assert.equals(2, #passage.choices)
      assert.equals("forest", passage.choices[1].target)
      assert.equals("mountain", passage.choices[2].target)
    end)

    it("supports conditional choices", function()
      local choice = Choice.new({
        text = "Open the door",
        target = "inside",
        condition = "has_key == true"
      })

      assert.equals("has_key == true", choice.condition)
    end)
  end)

  describe("Complete story workflow", function()
    it("creates and validates a full story", function()
      local story = Story.new({ title = "Adventure" })

      -- Create passages
      local start = Passage.new({ id = "start", name = "Beginning" })
      start.content = "Your adventure begins."
      start:add_choice(Choice.new({ text = "Continue", target = "middle" }))

      local middle = Passage.new({ id = "middle", name = "Journey" })
      middle.content = "You continue your journey."
      middle:add_choice(Choice.new({ text = "Finish", target = "end" }))

      local ending = Passage.new({ id = "end", name = "End" })
      ending.content = "The end."

      -- Build story
      story:add_passage(start)
      story:add_passage(middle)
      story:add_passage(ending)
      story:set_start_passage("start")

      -- Set variables
      story:set_variable("score", 0)
      story:set_variable("visited", {})

      -- Validate
      local valid, err = story:validate()
      assert.is_true(valid, err or "")

      -- Serialize round-trip
      local data = story:serialize()
      local restored = Story.new()
      restored:deserialize(data)

      assert.equals("Adventure", restored.metadata.name)
      assert.equals(3, #restored:get_all_passages())
    end)
  end)

  describe("Error handling integration", function()
    it("handles missing passage reference gracefully", function()
      local story = Story.new({ title = "Test" })
      local passage = Passage.new({ id = "start", name = "Start" })
      passage:add_choice(Choice.new({ text = "Go", target = "nonexistent" }))
      story:add_passage(passage)
      story:set_start_passage("start")

      -- Story validates but engine would catch missing target
      local valid = story:validate()
      assert.is_true(valid)
    end)

    it("container throws on unregistered service", function()
      local container = Container.new()

      assert.has_error(function()
        container:resolve("nonexistent")
      end)
    end)
  end)
end)
