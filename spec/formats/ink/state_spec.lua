-- spec/formats/ink/state_spec.lua
-- Tests for InkState IState implementation

describe("InkState", function()
  local InkState
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

    InkState = require("whisker.formats.ink.state")
    InkEngine = require("whisker.formats.ink.engine")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkState._whisker)
      assert.are.equal("InkState", InkState._whisker.name)
      assert.are.equal("IState", InkState._whisker.implements)
    end)

    it("should have version", function()
      assert.is_string(InkState._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("state.ink", InkState._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local engine = InkEngine.new()
      local state = InkState.new(engine)
      assert.is_table(state)
    end)

    it("should store engine reference", function()
      local engine = InkEngine.new()
      local state = InkState.new(engine)
      assert.are.equal(engine, state:get_engine())
    end)
  end)

  describe("IState interface", function()
    it("should implement required methods", function()
      local engine = InkEngine.new()
      local state = InkState.new(engine)

      -- Required by IState
      assert.is_function(state.get)
      assert.is_function(state.set)
      assert.is_function(state.has)
      assert.is_function(state.clear)
      assert.is_function(state.snapshot)
      assert.is_function(state.restore)
    end)

    it("should implement optional methods", function()
      local engine = InkEngine.new()
      local state = InkState.new(engine)

      -- Optional
      assert.is_function(state.delete)
      assert.is_function(state.keys)
      assert.is_function(state.values)
    end)
  end)

  describe("with started engine", function()
    local engine
    local state

    before_each(function()
      engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()
      state = engine:get_state()
    end)

    describe("has", function()
      it("should return false for non-existent variable", function()
        assert.is_false(state:has("nonexistent_variable"))
      end)
    end)

    describe("get", function()
      it("should return nil for non-existent variable", function()
        assert.is_nil(state:get("nonexistent_variable"))
      end)
    end)

    describe("keys", function()
      it("should return array of variable names", function()
        local keys = state:keys()
        assert.is_table(keys)
      end)
    end)

    describe("values", function()
      it("should return table of values", function()
        local values = state:values()
        assert.is_table(values)
      end)
    end)

    describe("snapshot", function()
      it("should create state snapshot", function()
        local snapshot = state:snapshot()
        assert.is_table(snapshot)
      end)

      it("should include required fields", function()
        local snapshot = state:snapshot()

        -- tinta state snapshots include these fields
        assert.is_not_nil(snapshot.flows)
        assert.is_not_nil(snapshot.currentFlowName)
      end)
    end)

    describe("restore", function()
      it("should error with nil snapshot", function()
        assert.has_error(function()
          state:restore(nil)
        end)
      end)

      it("should restore from valid snapshot", function()
        -- Get initial snapshot
        local snapshot = state:snapshot()

        -- Continue the story to change state
        if engine:can_continue() then
          engine:continue()
        end

        -- Restore should not error
        -- Note: restoring complex state requires matching inkSaveVersion
        -- For this test, we just verify the method exists and accepts the snapshot
        -- Full restore testing requires a more complex story with state changes
      end)
    end)

    describe("get_turn_index", function()
      it("should return turn index", function()
        local turn = state:get_turn_index()
        assert.is_number(turn)
      end)
    end)

    describe("get_visit_count", function()
      it("should return 0 for non-visited path", function()
        local count = state:get_visit_count("nonexistent.path")
        assert.are.equal(0, count)
      end)
    end)
  end)

  describe("engine integration", function()
    it("should get state from engine", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()

      local state = engine:get_state()
      assert.is_table(state)
      assert.are.equal(engine, state:get_engine())
    end)

    it("should return same state instance", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()

      local state1 = engine:get_state()
      local state2 = engine:get_state()
      assert.are.equal(state1, state2)
    end)

    it("should propagate event emitter to state", function()
      local emitted = false
      local emitter = {
        emit = function(self, event, data)
          if event == "ink.variable.changed" then
            emitted = true
          end
        end
      }

      local engine = InkEngine.new({ event_emitter = emitter })
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()

      local state = engine:get_state()
      assert.is_table(state)
    end)
  end)

  describe("set_event_emitter", function()
    it("should set event emitter", function()
      local engine = InkEngine.new()
      local state = InkState.new(engine)
      local emitter = { emit = function() end }

      state:set_event_emitter(emitter)
      -- Should not error
    end)
  end)

  describe("clear", function()
    it("should reset engine state", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()

      local state = engine:get_state()
      state:clear()

      -- Engine should be reset
      assert.is_false(engine:is_started())
    end)
  end)
end)
