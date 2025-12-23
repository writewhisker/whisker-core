--- StateManager Unit Tests
-- @module tests.unit.services.state_spec
-- @author Whisker Core Team

describe("StateManager", function()
  local StateManager
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    StateManager = require("whisker.services.state")
  end)

  describe("initialization", function()
    it("creates state manager without container", function()
      local state = StateManager.new(nil)
      assert.is_not_nil(state)
    end)

    it("creates state manager with container", function()
      local container = TestContainer.create()
      local state = StateManager.new(container)
      assert.is_not_nil(state)
    end)
  end)

  describe("get/set operations", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("sets and gets a value", function()
      state:set("key", "value")
      assert.equals("value", state:get("key"))
    end)

    it("returns nil for nonexistent key", function()
      assert.is_nil(state:get("nonexistent"))
    end)

    it("overwrites existing value", function()
      state:set("key", "first")
      state:set("key", "second")
      assert.equals("second", state:get("key"))
    end)

    it("handles different value types", function()
      state:set("string", "hello")
      state:set("number", 42)
      state:set("boolean", true)
      state:set("table", { a = 1 })

      assert.equals("hello", state:get("string"))
      assert.equals(42, state:get("number"))
      assert.equals(true, state:get("boolean"))
      assert.same({ a = 1 }, state:get("table"))
    end)
  end)

  describe("has operation", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("returns true for existing key", function()
      state:set("key", "value")
      assert.is_true(state:has("key"))
    end)

    it("returns false for nonexistent key", function()
      assert.is_false(state:has("nonexistent"))
    end)

    it("returns true even for nil value explicitly set", function()
      -- Note: setting nil effectively deletes the key
      state:set("key", nil)
      assert.is_false(state:has("key"))
    end)
  end)

  describe("delete operation", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("deletes existing key", function()
      state:set("key", "value")
      local result = state:delete("key")
      assert.is_true(result)
      assert.is_nil(state:get("key"))
    end)

    it("returns false for nonexistent key", function()
      local result = state:delete("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("clear operation", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("clears all state", function()
      state:set("key1", "value1")
      state:set("key2", "value2")
      state:clear()

      assert.is_nil(state:get("key1"))
      assert.is_nil(state:get("key2"))
      assert.equals(0, state:count())
    end)
  end)

  describe("snapshot and restore", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("creates a snapshot", function()
      state:set("key1", "value1")
      state:set("key2", 42)

      local snapshot = state:snapshot()

      assert.equals("value1", snapshot.key1)
      assert.equals(42, snapshot.key2)
    end)

    it("restores from a snapshot", function()
      state:set("key1", "value1")
      local snapshot = state:snapshot()

      state:clear()
      state:set("key2", "value2")

      state:restore(snapshot)

      assert.equals("value1", state:get("key1"))
      assert.is_nil(state:get("key2"))
    end)

    it("restores from nil snapshot", function()
      state:set("key", "value")
      state:restore(nil)
      assert.equals(0, state:count())
    end)
  end)

  describe("keys operation", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("returns all keys", function()
      state:set("a", 1)
      state:set("b", 2)
      state:set("c", 3)

      local keys = state:keys()
      table.sort(keys)

      assert.equals(3, #keys)
      assert.same({"a", "b", "c"}, keys)
    end)

    it("returns empty table when no keys", function()
      local keys = state:keys()
      assert.same({}, keys)
    end)
  end)

  describe("count operation", function()
    local state

    before_each(function()
      state = StateManager.new(nil)
    end)

    it("returns correct count", function()
      assert.equals(0, state:count())
      state:set("a", 1)
      assert.equals(1, state:count())
      state:set("b", 2)
      assert.equals(2, state:count())
      state:delete("a")
      assert.equals(1, state:count())
    end)
  end)

  describe("event emission", function()
    local state, events, emitted

    before_each(function()
      local container = TestContainer.create()
      events = container:resolve("events")
      state = StateManager.new(container)
      emitted = {}

      events:on("state:*", function(data)
        table.insert(emitted, data)
      end)
    end)

    it("emits state:changed when value set", function()
      state:set("key", "value")

      assert.equals(1, #emitted)
      assert.equals("key", emitted[1].key)
      assert.equals("value", emitted[1].new_value)
    end)

    it("emits state:deleted when value deleted", function()
      state:set("key", "value")
      emitted = {}

      state:delete("key")

      assert.equals(1, #emitted)
      assert.equals("key", emitted[1].key)
      assert.equals("value", emitted[1].old_value)
    end)

    it("emits state:cleared when cleared", function()
      state:set("key", "value")
      emitted = {}

      state:clear()

      assert.equals(1, #emitted)
      assert.is_not_nil(emitted[1].timestamp)
    end)

    it("emits state:restored when restored", function()
      local snapshot = { key = "value" }
      state:restore(snapshot)

      assert.equals(1, #emitted)
      assert.is_not_nil(emitted[1].keys)
    end)
  end)

  describe("destroy", function()
    it("cleans up state", function()
      local state = StateManager.new(nil)
      state:set("key", "value")
      state:destroy()

      assert.equals(0, state:count())
    end)
  end)
end)
