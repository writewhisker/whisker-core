--- State & Save Macros Unit Tests
-- Tests for state persistence and save/load macros
-- @module tests.unit.script.macros.state.test_state_spec

describe("State Macros", function()
  local Macros, State, Context

  setup(function()
    Macros = require("whisker.script.macros")
    State = require("whisker.script.macros.state")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(State.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", State.VERSION)
    end)

    it("exports save system macros", function()
      assert.is_table(State.save_macro)
      assert.is_table(State.load_macro)
      assert.is_table(State.savedgames_macro)
      assert.is_table(State.deletesave_macro)
      assert.is_table(State.saveexists_macro)
      assert.is_table(State.autosave_macro)
    end)

    it("exports persistent state macros", function()
      assert.is_table(State.remember_macro)
      assert.is_table(State.forget_macro)
      assert.is_table(State.recall_macro)
      assert.is_table(State.forgetall_macro)
    end)

    it("exports undo/redo macros", function()
      assert.is_table(State.checkpoint_macro)
      assert.is_table(State.undo_macro)
      assert.is_table(State.redo_macro)
      assert.is_table(State.history_macro)
      assert.is_table(State.canundo_macro)
      assert.is_table(State.canredo_macro)
    end)

    it("exports state management macros", function()
      assert.is_table(State.clearall_macro)
      assert.is_table(State.snapshot_macro)
      assert.is_table(State.restoresnapshot_macro)
    end)

    it("exports state query macros", function()
      assert.is_table(State.vartype_macro)
      assert.is_table(State.hasvar_macro)
      assert.is_table(State.getvars_macro)
      assert.is_table(State.debug_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(State.register_all)
    end)
  end)

  describe("save macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates save data with default slot", function()
      local result = State.save_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("save", result._type)
      assert.equals("auto", result.slot)
    end)

    it("accepts slot and title", function()
      local result = State.save_macro.handler(ctx, { 1, "Chapter 1" })
      assert.equals(1, result.slot)
      assert.equals("Chapter 1", result.title)
    end)

    it("includes timestamp", function()
      local result = State.save_macro.handler(ctx, {})
      assert.is_number(result.timestamp)
    end)

    it("includes state data", function()
      ctx:set("score", 100)
      local result = State.save_macro.handler(ctx, {})
      assert.is_table(result.state)
    end)
  end)

  describe("load macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates load data", function()
      local result = State.load_macro.handler(ctx, { 1 })
      assert.is_table(result)
      assert.equals("load", result._type)
      assert.equals(1, result.slot)
    end)

    it("defaults to auto slot", function()
      local result = State.load_macro.handler(ctx, {})
      assert.equals("auto", result.slot)
    end)

    it("is async", function()
      assert.is_true(State.load_macro.async)
    end)
  end)

  describe("savedgames macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates query data", function()
      local result = State.savedgames_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("savedgames_query", result._type)
      assert.equals("list", result.query)
    end)

    it("is pure", function()
      assert.is_true(State.savedgames_macro.pure)
    end)
  end)

  describe("deletesave macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates delete data", function()
      local result = State.deletesave_macro.handler(ctx, { "slot1" })
      assert.is_table(result)
      assert.equals("delete_save", result._type)
      assert.equals("slot1", result.slot)
    end)

    it("requires slot identifier", function()
      local result, err = State.deletesave_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("saveexists macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates query data", function()
      local result = State.saveexists_macro.handler(ctx, { "auto" })
      assert.is_table(result)
      assert.equals("save_query", result._type)
      assert.equals("exists", result.query)
    end)

    it("is pure", function()
      assert.is_true(State.saveexists_macro.pure)
    end)
  end)

  describe("autosave macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("defaults to save action", function()
      local result = State.autosave_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("autosave", result._type)
      assert.equals("save", result.action)
    end)

    it("accepts config action", function()
      local result = State.autosave_macro.handler(ctx, { "config", { interval = 60 } })
      assert.equals("config", result.action)
    end)

    it("includes state on save action", function()
      local result = State.autosave_macro.handler(ctx, { "save" })
      assert.is_table(result.state)
      assert.is_number(result.timestamp)
    end)
  end)

  describe("remember macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("stores value persistently", function()
      local result = State.remember_macro.handler(ctx, { "highscore", 100 })
      assert.equals(100, result)
      assert.equals(100, ctx:get("_persistent_highscore"))
    end)

    it("strips $ prefix from name", function()
      State.remember_macro.handler(ctx, { "$score", 50 })
      assert.equals(50, ctx:get("_persistent_score"))
    end)
  end)

  describe("forget macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_persistent_test", "value")
    end)

    it("removes remembered value", function()
      local result = State.forget_macro.handler(ctx, { "test" })
      assert.is_true(result)
      assert.is_nil(ctx:get("_persistent_test"))
    end)
  end)

  describe("recall macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_persistent_score", 100)
    end)

    it("retrieves remembered value", function()
      local result = State.recall_macro.handler(ctx, { "score" })
      assert.equals(100, result)
    end)

    it("returns default if not found", function()
      local result = State.recall_macro.handler(ctx, { "nonexistent", 0 })
      assert.equals(0, result)
    end)

    it("is pure", function()
      assert.is_true(State.recall_macro.pure)
    end)
  end)

  describe("forgetall macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_persistent_a", 1)
      ctx:set("_persistent_b", 2)
      ctx:set("regular", 3)
    end)

    it("clears all persistent values", function()
      local result = State.forgetall_macro.handler(ctx, {})
      assert.is_true(result)
      assert.is_nil(ctx:get("_persistent_a"))
      assert.is_nil(ctx:get("_persistent_b"))
    end)

    it("preserves regular values", function()
      State.forgetall_macro.handler(ctx, {})
      assert.equals(3, ctx:get("regular"))
    end)
  end)

  describe("checkpoint macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("score", 100)
    end)

    it("creates checkpoint data", function()
      local result = State.checkpoint_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("checkpoint", result._type)
      assert.is_table(result.state)
      assert.is_number(result.timestamp)
    end)

    it("accepts label", function()
      local result = State.checkpoint_macro.handler(ctx, { "Before battle" })
      assert.equals("Before battle", result.label)
    end)

    it("adds to undo stack", function()
      State.checkpoint_macro.handler(ctx, {})
      local stack = ctx:get("_undo_stack")
      assert.is_table(stack)
      assert.equals(1, #stack)
    end)

    it("clears redo stack", function()
      ctx:set("_redo_stack", { { state = {} } })
      State.checkpoint_macro.handler(ctx, {})
      local redo = ctx:get("_redo_stack")
      assert.equals(0, #redo)
    end)

    it("limits stack size", function()
      ctx:set("_max_checkpoints", 3)
      for i = 1, 5 do
        State.checkpoint_macro.handler(ctx, { "cp" .. i })
      end
      local stack = ctx:get("_undo_stack")
      assert.equals(3, #stack)
    end)
  end)

  describe("undo macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns error when nothing to undo", function()
      local result, err = State.undo_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("pops from undo stack", function()
      ctx:set("_undo_stack", {
        { state = { x = 1 }, timestamp = 1 }
      })
      local result = State.undo_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("undo", result._type)

      local stack = ctx:get("_undo_stack")
      assert.equals(0, #stack)
    end)

    it("pushes to redo stack", function()
      ctx:set("_undo_stack", {
        { state = { x = 1 }, timestamp = 1 }
      })
      State.undo_macro.handler(ctx, {})
      local redo = ctx:get("_redo_stack")
      assert.equals(1, #redo)
    end)

    it("is async", function()
      assert.is_true(State.undo_macro.async)
    end)
  end)

  describe("redo macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns error when nothing to redo", function()
      local result, err = State.redo_macro.handler(ctx, {})
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("pops from redo stack", function()
      ctx:set("_redo_stack", {
        { state = { x = 1 }, timestamp = 1 }
      })
      local result = State.redo_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("redo", result._type)

      local stack = ctx:get("_redo_stack")
      assert.equals(0, #stack)
    end)

    it("pushes to undo stack", function()
      ctx:set("_redo_stack", {
        { state = { x = 1 }, timestamp = 1 }
      })
      State.redo_macro.handler(ctx, {})
      local undo = ctx:get("_undo_stack")
      assert.equals(1, #undo)
    end)
  end)

  describe("history macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_undo_stack", { { label = "a" }, { label = "b" } })
      ctx:set("_redo_stack", { { label = "c" } })
    end)

    it("returns undo history by default", function()
      local result = State.history_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("undo", result.history_type)
      assert.equals(2, result.count)
    end)

    it("returns redo history", function()
      local result = State.history_macro.handler(ctx, { "redo" })
      assert.equals("redo", result.history_type)
      assert.equals(1, result.count)
    end)

    it("is pure", function()
      assert.is_true(State.history_macro.pure)
    end)
  end)

  describe("canundo macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns false when stack empty", function()
      local result = State.canundo_macro.handler(ctx, {})
      assert.is_false(result)
    end)

    it("returns true when stack has items", function()
      ctx:set("_undo_stack", { { state = {} } })
      local result = State.canundo_macro.handler(ctx, {})
      assert.is_true(result)
    end)

    it("is pure", function()
      assert.is_true(State.canundo_macro.pure)
    end)
  end)

  describe("canredo macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns false when stack empty", function()
      local result = State.canredo_macro.handler(ctx, {})
      assert.is_false(result)
    end)

    it("returns true when stack has items", function()
      ctx:set("_redo_stack", { { state = {} } })
      local result = State.canredo_macro.handler(ctx, {})
      assert.is_true(result)
    end)
  end)

  describe("clearall macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("score", 100)
      ctx:set("name", "Alice")
      ctx:set("_internal", "keep")
    end)

    it("clears all non-internal variables", function()
      State.clearall_macro.handler(ctx, {})
      assert.is_nil(ctx:get("score"))
      assert.is_nil(ctx:get("name"))
    end)

    it("preserves internal variables", function()
      State.clearall_macro.handler(ctx, {})
      assert.equals("keep", ctx:get("_internal"))
    end)

    it("preserves specified variables", function()
      State.clearall_macro.handler(ctx, { { "score" } })
      assert.equals(100, ctx:get("score"))
      assert.is_nil(ctx:get("name"))
    end)

    it("handles $ prefix in preserve list", function()
      State.clearall_macro.handler(ctx, { { "$name" } })
      assert.is_nil(ctx:get("score"))
      assert.equals("Alice", ctx:get("name"))
    end)
  end)

  describe("snapshot macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("a", 1)
      ctx:set("b", 2)
      ctx:set("c", 3)
    end)

    it("captures current state", function()
      local result = State.snapshot_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("snapshot", result._type)
      assert.is_table(result.state)
      assert.is_number(result.timestamp)
    end)

    it("accepts label", function()
      local result = State.snapshot_macro.handler(ctx, { "test-snapshot" })
      assert.equals("test-snapshot", result.label)
    end)

    it("filters with array", function()
      local result = State.snapshot_macro.handler(ctx, { "", { "a", "b" } })
      assert.equals(1, result.state.a)
      assert.equals(2, result.state.b)
      assert.is_nil(result.state.c)
    end)

    it("is pure", function()
      assert.is_true(State.snapshot_macro.pure)
    end)
  end)

  describe("restoresnapshot macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("x", 10)
      ctx:set("y", 20)
    end)

    it("restores from snapshot", function()
      local snapshot = {
        _type = "snapshot",
        state = { x = 100, z = 300 }
      }
      State.restoresnapshot_macro.handler(ctx, { snapshot })
      assert.equals(100, ctx:get("x"))
      assert.equals(300, ctx:get("z"))
    end)

    it("clears existing state by default", function()
      local snapshot = {
        _type = "snapshot",
        state = { x = 100 }
      }
      State.restoresnapshot_macro.handler(ctx, { snapshot })
      assert.is_nil(ctx:get("y"))
    end)

    it("merges when merge=true", function()
      local snapshot = {
        _type = "snapshot",
        state = { x = 100 }
      }
      State.restoresnapshot_macro.handler(ctx, { snapshot, true })
      assert.equals(100, ctx:get("x"))
      assert.equals(20, ctx:get("y"))
    end)

    it("rejects invalid snapshot", function()
      local result, err = State.restoresnapshot_macro.handler(ctx, { {} })
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("vartype macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("num", 42)
      ctx:set("str", "hello")
      ctx:set("tbl", {})
      ctx:set("bool", true)
    end)

    it("returns number type", function()
      local result = State.vartype_macro.handler(ctx, { "num" })
      assert.equals("number", result)
    end)

    it("returns string type", function()
      local result = State.vartype_macro.handler(ctx, { "str" })
      assert.equals("string", result)
    end)

    it("returns table type", function()
      local result = State.vartype_macro.handler(ctx, { "tbl" })
      assert.equals("table", result)
    end)

    it("returns boolean type", function()
      local result = State.vartype_macro.handler(ctx, { "bool" })
      assert.equals("boolean", result)
    end)

    it("returns nil for nonexistent", function()
      local result = State.vartype_macro.handler(ctx, { "nonexistent" })
      assert.equals("nil", result)
    end)

    it("strips $ prefix", function()
      local result = State.vartype_macro.handler(ctx, { "$num" })
      assert.equals("number", result)
    end)

    it("is pure", function()
      assert.is_true(State.vartype_macro.pure)
    end)
  end)

  describe("hasvar macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("exists", "value")
    end)

    it("returns true for existing variable", function()
      local result = State.hasvar_macro.handler(ctx, { "exists" })
      assert.is_true(result)
    end)

    it("returns false for nonexistent variable", function()
      local result = State.hasvar_macro.handler(ctx, { "missing" })
      assert.is_false(result)
    end)

    it("strips $ prefix", function()
      local result = State.hasvar_macro.handler(ctx, { "$exists" })
      assert.is_true(result)
    end)

    it("is pure", function()
      assert.is_true(State.hasvar_macro.pure)
    end)
  end)

  describe("getvars macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("score", 100)
      ctx:set("player_name", "Alice")
      ctx:set("player_health", 50)
      ctx:set("_internal", "hidden")
    end)

    it("returns all non-internal variables", function()
      local result = State.getvars_macro.handler(ctx, {})
      assert.is_table(result)
      assert.is_true(#result >= 3)
    end)

    it("excludes internal variables", function()
      local result = State.getvars_macro.handler(ctx, {})
      for _, name in ipairs(result) do
        assert.is_not_true(name:match("^_"))
      end
    end)

    it("filters with pattern", function()
      local result = State.getvars_macro.handler(ctx, { "^player" })
      assert.equals(2, #result)
    end)

    it("returns sorted list", function()
      local result = State.getvars_macro.handler(ctx, {})
      for i = 2, #result do
        assert.is_true(result[i-1] < result[i])
      end
    end)

    it("is pure", function()
      assert.is_true(State.getvars_macro.pure)
    end)
  end)

  describe("debug macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("score", 100)
    end)

    it("returns all state when no target", function()
      local result = State.debug_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("debug", result._type)
      assert.is_table(result.state)
    end)

    it("returns single variable info", function()
      local result = State.debug_macro.handler(ctx, { "$score" })
      assert.equals("score", result.variable)
      assert.equals(100, result.value)
      assert.equals("number", result.type)
    end)

    it("returns direct value info", function()
      local result = State.debug_macro.handler(ctx, { { a = 1 } })
      assert.is_table(result.value)
      assert.equals("table", result.type)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = State.register_all(registry)

      assert.is_true(count >= 22)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      State.register_all(registry)

      assert.is_not_nil(registry:get("save"))
      assert.is_not_nil(registry:get("load"))
      assert.is_not_nil(registry:get("remember"))
      assert.is_not_nil(registry:get("checkpoint"))
      assert.is_not_nil(registry:get("undo"))
      assert.is_not_nil(registry:get("snapshot"))
    end)

    it("macros have data category", function()
      local registry = Registry.new()
      State.register_all(registry)

      local macro = registry:get("save")
      assert.equals("data", macro.category)
    end)
  end)
end)
