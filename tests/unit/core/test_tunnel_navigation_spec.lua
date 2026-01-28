--- Tunnel Navigation Unit Tests (GAP-009)
-- Tests for the Engine tunnel_call and tunnel_return methods
-- @module tests.unit.core.test_tunnel_navigation_spec
-- @author Whisker Core Team

describe("Tunnel Navigation", function()
  local Engine
  local GameState

  -- Helper to create a mock story
  local function create_mock_story(passages)
    local passage_map = {}
    for _, p in ipairs(passages) do
      passage_map[p.name] = {
        id = p.name,
        name = p.name,
        content = p.content or ""
      }
    end

    return {
      metadata = { uuid = "test-story" },
      start_passage_name = passages[1] and passages[1].name or "Start",
      get_passage = function(self, id)
        return passage_map[id]
      end
    }
  end

  before_each(function()
    Engine = require("lib.whisker.core.engine")
    GameState = require("lib.whisker.core.game_state")
  end)

  describe("tunnel_call", function()
    it("should push return address and navigate to target", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Helper", content = "In helper" }
      })

      local engine = Engine.new(story, {})
      engine:navigate_to_passage("Start")

      assert.equals("Start", engine.current_passage.id)
      assert.equals(0, engine.game_state:tunnel_depth())

      engine:tunnel_call("Helper")

      assert.equals("Helper", engine.current_passage.id)
      assert.equals(1, engine.game_state:tunnel_depth())

      -- Verify return address is Start
      local return_info = engine.game_state:tunnel_peek()
      assert.equals("Start", return_info.passage_id)
    end)

    it("should return error when no current passage", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" }
      })

      local engine = Engine.new(story, {})
      -- Don't navigate - no current passage

      local result, err = engine:tunnel_call("Helper")

      assert.is_nil(result)
      assert.truthy(err:find("No current passage"))
    end)

    it("should return error on stack overflow", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "A", content = "A" },
        { name = "B", content = "B" },
        { name = "C", content = "C" },
        { name = "D", content = "D" }
      })

      local engine = Engine.new(story, {})
      engine.game_state:set_tunnel_limit(3)
      engine:navigate_to_passage("Start")

      engine:tunnel_call("A")
      engine:tunnel_call("B")
      engine:tunnel_call("C")

      local result, err = engine:tunnel_call("D")

      assert.is_nil(result)
      assert.truthy(err:find("overflow"))
    end)
  end)

  describe("tunnel_return", function()
    it("should pop return address and navigate back", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Helper", content = "In helper" }
      })

      local engine = Engine.new(story, {})
      engine:navigate_to_passage("Start")
      engine:tunnel_call("Helper")

      assert.equals("Helper", engine.current_passage.id)

      engine:tunnel_return()

      assert.equals("Start", engine.current_passage.id)
      assert.equals(0, engine.game_state:tunnel_depth())
    end)

    it("should return error on empty stack with error behavior", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" }
      })

      local engine = Engine.new(story, { tunnel_empty_behavior = "error" })
      engine:navigate_to_passage("Start")

      local result, err = engine:tunnel_return()

      assert.is_nil(result)
      assert.truthy(err:find("underflow"))
    end)

    it("should restart on empty stack with restart behavior", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Other", content = "Other passage" }
      })

      local engine = Engine.new(story, { tunnel_empty_behavior = "restart" })
      engine:navigate_to_passage("Other")

      engine:tunnel_return()

      assert.equals("Start", engine.current_passage.id)
    end)

    it("should stay on current passage with stay behavior", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Other", content = "Other passage" }
      })

      local engine = Engine.new(story, { tunnel_empty_behavior = "stay" })
      engine:navigate_to_passage("Other")

      local result = engine:tunnel_return()

      assert.equals("Other", engine.current_passage.id)
    end)
  end)

  describe("nested tunnels", function()
    it("should handle nested tunnel calls correctly", function()
      local story = create_mock_story({
        { name = "A", content = "A" },
        { name = "B", content = "B" },
        { name = "C", content = "C" }
      })

      local engine = Engine.new(story, {})

      engine:navigate_to_passage("A")
      engine:tunnel_call("B")
      engine:tunnel_call("C")

      assert.equals("C", engine.current_passage.id)
      assert.equals(2, engine.game_state:tunnel_depth())

      engine:tunnel_return()
      assert.equals("B", engine.current_passage.id)
      assert.equals(1, engine.game_state:tunnel_depth())

      engine:tunnel_return()
      assert.equals("A", engine.current_passage.id)
      assert.equals(0, engine.game_state:tunnel_depth())
    end)
  end)

  describe("process_tunnel_operations", function()
    it("should detect tunnel call in content", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" }
      })

      local engine = Engine.new(story, {})
      local content = "Some text -> Helper ->"

      local processed, op = engine:process_tunnel_operations(content)

      assert.equals("Some text", processed)
      assert.is_table(op)
      assert.equals("tunnel_call", op.type)
      assert.equals("Helper", op.target)
    end)

    it("should detect tunnel return in content", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" }
      })

      local engine = Engine.new(story, {})
      local content = "Done with helper <-"

      local processed, op = engine:process_tunnel_operations(content)

      -- The text before tunnel return (may or may not include trailing space)
      assert.truthy(processed:match("^Done with helper"))
      assert.is_table(op)
      assert.equals("tunnel_return", op.type)
    end)

    it("should return nil operation for normal content", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" }
      })

      local engine = Engine.new(story, {})
      local content = "Just normal text without tunnels"

      local processed, op = engine:process_tunnel_operations(content)

      assert.equals(content, processed)
      assert.is_nil(op)
    end)
  end)

  describe("engine state serialization with tunnel stack", function()
    it("should include game_state with tunnel stack in serialization", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Helper", content = "In helper" }
      })

      local engine = Engine.new(story, {})
      engine:navigate_to_passage("Start")
      engine:tunnel_call("Helper")

      local data = engine:serialize_state()

      assert.is_table(data.game_state)
      assert.is_table(data.game_state.tunnel_stack)
      assert.equals(1, #data.game_state.tunnel_stack)
    end)

    it("should restore tunnel stack on deserialization", function()
      local story = create_mock_story({
        { name = "Start", content = "Begin" },
        { name = "Helper", content = "In helper" }
      })

      local engine1 = Engine.new(story, {})
      engine1:navigate_to_passage("Start")
      engine1:tunnel_call("Helper")

      local data = engine1:serialize_state()

      local engine2 = Engine.new(story, {})
      engine2:deserialize_state(data)

      assert.equals(1, engine2.game_state:tunnel_depth())

      -- Should be able to return
      engine2:tunnel_return()
      assert.equals("Start", engine2.current_passage.id)
    end)
  end)
end)

describe("ControlFlow Tunnel Processing", function()
  local ControlFlow

  before_each(function()
    ControlFlow = require("lib.whisker.core.control_flow")
  end)

  describe("process_tunnels", function()
    it("should extract tunnel call from content", function()
      local mock_interpreter = {
        evaluate_condition = function() return true, true end
      }
      local mock_game_state = {
        get = function() return nil end,
        set = function() end
      }

      local cf = ControlFlow.new(mock_interpreter, mock_game_state, {})
      local content = "Before text -> Target -> After text"

      local processed, op = cf:process_tunnels(content)

      assert.equals("Before text ", processed)
      assert.equals("tunnel_call", op.type)
      assert.equals("Target", op.target)
      assert.equals(" After text", op.remaining)
    end)

    it("should extract tunnel return from content", function()
      local mock_interpreter = {}
      local mock_game_state = {}

      local cf = ControlFlow.new(mock_interpreter, mock_game_state, {})
      local content = "Done here <- more stuff"

      local processed, op = cf:process_tunnels(content)

      assert.equals("Done here ", processed)
      assert.equals("tunnel_return", op.type)
      assert.equals(" more stuff", op.remaining)
    end)

    it("should return content unchanged when no tunnel operations", function()
      local mock_interpreter = {}
      local mock_game_state = {}

      local cf = ControlFlow.new(mock_interpreter, mock_game_state, {})
      local content = "Just normal text"

      local processed, op = cf:process_tunnels(content)

      assert.equals(content, processed)
      assert.is_nil(op)
    end)

    it("should handle underscore in passage names", function()
      local mock_interpreter = {}
      local mock_game_state = {}

      local cf = ControlFlow.new(mock_interpreter, mock_game_state, {})
      local content = "Go to -> my_helper_passage ->"

      local processed, op = cf:process_tunnels(content)

      assert.equals("tunnel_call", op.type)
      assert.equals("my_helper_passage", op.target)
    end)
  end)
end)
