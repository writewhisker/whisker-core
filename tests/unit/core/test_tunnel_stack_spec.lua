--- Tunnel Stack Unit Tests (GAP-009 and GAP-013)
-- Comprehensive unit tests for the Tunnel Stack functionality
-- @module tests.unit.core.test_tunnel_stack_spec
-- @author Whisker Core Team

describe("Tunnel Stack", function()
  local GameState

  before_each(function()
    GameState = require("lib.whisker.core.game_state")
  end)

  describe("GAP-009: Stack Operations", function()
    it("should push and pop correctly", function()
      local state = GameState.new()

      state:tunnel_push("passage_a")
      state:tunnel_push("passage_b")

      local info = state:tunnel_pop()
      assert.equals("passage_b", info.passage_id)

      info = state:tunnel_pop()
      assert.equals("passage_a", info.passage_id)
    end)

    it("should return error on underflow", function()
      local state = GameState.new()

      local info, err = state:tunnel_pop()

      assert.is_nil(info)
      assert.is_not_nil(err)
      assert.truthy(err:find("underflow"))
    end)

    it("should return error on overflow", function()
      local state = GameState.new()
      state:set_tunnel_limit(3)

      state:tunnel_push("a")
      state:tunnel_push("b")
      state:tunnel_push("c")
      local success, err = state:tunnel_push("d")

      assert.is_false(success)
      assert.truthy(err:find("overflow"))
    end)

    it("should report correct depth", function()
      local state = GameState.new()

      assert.equals(0, state:tunnel_depth())

      state:tunnel_push("a")
      assert.equals(1, state:tunnel_depth())

      state:tunnel_push("b")
      assert.equals(2, state:tunnel_depth())

      state:tunnel_pop()
      assert.equals(1, state:tunnel_depth())
    end)

    it("should check if stack is empty", function()
      local state = GameState.new()

      assert.is_true(state:tunnel_empty())

      state:tunnel_push("a")
      assert.is_false(state:tunnel_empty())

      state:tunnel_pop()
      assert.is_true(state:tunnel_empty())
    end)

    it("should peek without removing", function()
      local state = GameState.new()

      state:tunnel_push("a")
      state:tunnel_push("b")

      local info = state:tunnel_peek()
      assert.equals("b", info.passage_id)

      -- Should still have 2 items
      assert.equals(2, state:tunnel_depth())
    end)

    it("should return nil when peeking empty stack", function()
      local state = GameState.new()

      local info = state:tunnel_peek()
      assert.is_nil(info)
    end)

    it("should clear the stack", function()
      local state = GameState.new()

      state:tunnel_push("a")
      state:tunnel_push("b")
      assert.equals(2, state:tunnel_depth())

      state:tunnel_clear()
      assert.equals(0, state:tunnel_depth())
      assert.is_true(state:tunnel_empty())
    end)

    it("should get the full stack for debugging", function()
      local state = GameState.new()

      state:tunnel_push("a")
      state:tunnel_push("b")

      local stack = state:get_tunnel_stack()
      assert.equals(2, #stack)
      assert.equals("a", stack[1].passage_id)
      assert.equals("b", stack[2].passage_id)
    end)

    it("should set tunnel limit", function()
      local state = GameState.new()
      state:set_tunnel_limit(5)

      for i = 1, 5 do
        local success = state:tunnel_push("passage_" .. i)
        assert.is_true(success)
      end

      local success, err = state:tunnel_push("passage_6")
      assert.is_false(success)
    end)

    it("should store position in tunnel entry", function()
      local state = GameState.new()

      state:tunnel_push("passage_a", 42)

      local info = state:tunnel_pop()
      assert.equals("passage_a", info.passage_id)
      assert.equals(42, info.position)
    end)

    it("should default position to 0", function()
      local state = GameState.new()

      state:tunnel_push("passage_a")

      local info = state:tunnel_pop()
      assert.equals(0, info.position)
    end)

    it("should include timestamp in tunnel entry", function()
      local state = GameState.new()

      state:tunnel_push("passage_a")

      local info = state:tunnel_pop()
      assert.is_number(info.timestamp)
    end)
  end)

  describe("GAP-009: Reset and Initialize", function()
    it("should clear tunnel stack on reset", function()
      local state = GameState.new()

      state:tunnel_push("a")
      state:tunnel_push("b")

      state:reset()

      assert.is_true(state:tunnel_empty())
    end)

    it("should initialize with empty tunnel stack", function()
      local state = GameState.new()
      local mock_story = { metadata = { uuid = "test-uuid" } }

      state:initialize(mock_story)

      assert.is_true(state:tunnel_empty())
    end)
  end)

  describe("GAP-009: History Integration", function()
    it("should include tunnel stack in history snapshots", function()
      local state = GameState.new()

      -- Need to set an initial passage first, then change to trigger push_to_history
      state:set_current_passage("initial_passage")
      state:tunnel_push("passage_a")
      state:set_current_passage("test_passage")

      -- Now undo - this should restore the state from before test_passage
      local snapshot = state:undo()

      assert.is_table(snapshot.tunnel_stack)
    end)

    it("should restore tunnel stack on undo", function()
      local state = GameState.new()

      -- Set initial passage (no history push on first set)
      state:set_current_passage("initial_passage")

      -- Add first tunnel entry
      state:tunnel_push("passage_a")
      -- Change passage - this pushes history with tunnel_stack = [passage_a]
      state:set_current_passage("test_passage_1")

      -- Add second tunnel entry
      state:tunnel_push("passage_b")
      -- Change passage - this pushes history with tunnel_stack = [passage_a, passage_b]
      state:set_current_passage("test_passage_2")

      -- Depth should be 2 now
      assert.equals(2, state:tunnel_depth())

      -- Undo back to test_passage_1 state
      -- This should restore tunnel_stack = [passage_a, passage_b] (state before passage_2)
      state:undo()

      -- After undo, we should be at the state right before test_passage_2
      -- which had both passage_a and passage_b in the stack
      assert.equals(2, state:tunnel_depth())

      -- Let's undo once more to get back to the state before test_passage_1
      state:undo()

      -- Now we should have only passage_a
      assert.equals(1, state:tunnel_depth())
      local info = state:tunnel_peek()
      assert.equals("passage_a", info.passage_id)
    end)
  end)

  describe("GAP-013: Serialization", function()
    it("should serialize empty tunnel stack", function()
      local state = GameState.new()
      local data = state:serialize()

      assert.is_table(data.tunnel_stack)
      assert.equals(0, #data.tunnel_stack)
    end)

    it("should serialize tunnel stack entries", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")
      state:tunnel_push("passage_b")

      local data = state:serialize()

      assert.equals(2, #data.tunnel_stack)
      assert.equals("passage_a", data.tunnel_stack[1].passage_id)
      assert.equals("passage_b", data.tunnel_stack[2].passage_id)
    end)

    it("should include stack limit in serialization", function()
      local state = GameState.new()
      state:set_tunnel_limit(50)

      local data = state:serialize()

      assert.equals(50, data.tunnel_stack_limit)
    end)

    it("should not include timestamp in serialization", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")

      local data = state:serialize()

      assert.is_nil(data.tunnel_stack[1].timestamp)
    end)
  end)

  describe("GAP-013: Deserialization", function()
    it("should restore tunnel stack", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")
      state:tunnel_push("passage_b")

      local data = state:serialize()

      local new_state = GameState.new()
      new_state:deserialize(data)

      assert.equals(2, new_state:tunnel_depth())

      local entry = new_state:tunnel_pop()
      assert.equals("passage_b", entry.passage_id)
    end)

    it("should handle missing tunnel_stack gracefully", function()
      local state = GameState.new()
      local data = { version = state.version }

      local success = state:deserialize(data)

      assert.is_true(success)
      assert.equals(0, state:tunnel_depth())
    end)

    it("should restore stack limit", function()
      local state = GameState.new()
      state:set_tunnel_limit(25)
      local data = state:serialize()

      local new_state = GameState.new()
      new_state:deserialize(data)

      assert.equals(25, new_state.tunnel_stack_limit)
    end)

    it("should default stack limit to 100 if missing", function()
      local state = GameState.new()
      local data = { version = state.version, tunnel_stack = {} }

      state:deserialize(data)

      assert.equals(100, state.tunnel_stack_limit)
    end)

    it("should add timestamp on deserialization", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")
      local data = state:serialize()

      local new_state = GameState.new()
      new_state:deserialize(data)

      local entry = new_state:tunnel_peek()
      assert.is_number(entry.timestamp)
    end)
  end)

  describe("GAP-013: Validation", function()
    it("should validate passage references exist", function()
      local state = GameState.new()
      state:tunnel_push("existing_passage")
      state:tunnel_push("missing_passage")

      local mock_story = {
        get_passage = function(self, id)
          return id == "existing_passage" and {} or nil
        end
      }

      local valid, errors = state:validate_tunnel_stack(mock_story)

      assert.is_false(valid)
      assert.equals(1, #errors)
      assert.truthy(errors[1]:find("missing_passage"))
    end)

    it("should pass validation when all passages exist", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")
      state:tunnel_push("passage_b")

      local mock_story = {
        get_passage = function(self, id)
          return {}  -- All passages exist
        end
      }

      local valid, errors = state:validate_tunnel_stack(mock_story)

      assert.is_true(valid)
      assert.equals(0, #errors)
    end)

    it("should validate empty stack successfully", function()
      local state = GameState.new()

      local mock_story = {
        get_passage = function(self, id) return {} end
      }

      local valid, errors = state:validate_tunnel_stack(mock_story)

      assert.is_true(valid)
    end)

    it("should detect missing passage_id in entry", function()
      local state = GameState.new()
      -- Manually insert invalid entry
      table.insert(state.tunnel_stack, { position = 0 })

      local valid, errors = state:validate_tunnel_stack(nil)

      assert.is_false(valid)
      assert.truthy(errors[1]:find("missing passage_id"))
    end)
  end)

  describe("GAP-013: Round-trip", function()
    it("should preserve tunnel stack across save/load cycle", function()
      local state = GameState.new()
      state:tunnel_push("passage_a")
      state:tunnel_push("passage_b", 10)
      state:tunnel_push("passage_c", 20)

      local data = state:serialize()

      local new_state = GameState.new()
      new_state:deserialize(data)

      assert.equals(3, new_state:tunnel_depth())

      local c = new_state:tunnel_pop()
      assert.equals("passage_c", c.passage_id)
      assert.equals(20, c.position)

      local b = new_state:tunnel_pop()
      assert.equals("passage_b", b.passage_id)
      assert.equals(10, b.position)

      local a = new_state:tunnel_pop()
      assert.equals("passage_a", a.passage_id)
      assert.equals(0, a.position)
    end)
  end)
end)
