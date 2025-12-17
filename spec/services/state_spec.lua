-- spec/services/state_spec.lua
-- Unit tests for State service

describe("State Service", function()
  local State

  before_each(function()
    package.loaded["whisker.services.state"] = nil
    State = require("whisker.services.state")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(State._whisker)
      assert.are.equal("State", State._whisker.name)
      assert.is_string(State._whisker.version)
      assert.are.equal("IState", State._whisker.implements)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #State._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with empty state", function()
      local s = State.new()
      assert.is_false(s:has("any_key"))
    end)

    it("should accept event_emitter option", function()
      local emitter = {}
      local s = State.new({event_emitter = emitter})
      assert.are.equal(emitter, s:get_event_emitter())
    end)
  end)

  describe("get/set", function()
    it("should set and get string values", function()
      local s = State.new()
      s:set("name", "Alice")
      assert.are.equal("Alice", s:get("name"))
    end)

    it("should set and get number values", function()
      local s = State.new()
      s:set("health", 100)
      assert.are.equal(100, s:get("health"))
    end)

    it("should set and get boolean values", function()
      local s = State.new()
      s:set("flag", true)
      assert.is_true(s:get("flag"))
    end)

    it("should set and get table values", function()
      local s = State.new()
      local data = {a = 1, b = 2}
      s:set("data", data)
      assert.are.same(data, s:get("data"))
    end)

    it("should return nil for non-existent keys", function()
      local s = State.new()
      assert.is_nil(s:get("nonexistent"))
    end)

    it("should overwrite existing values", function()
      local s = State.new()
      s:set("key", "old")
      s:set("key", "new")
      assert.are.equal("new", s:get("key"))
    end)
  end)

  describe("has", function()
    it("should return true for existing keys", function()
      local s = State.new()
      s:set("exists", "value")
      assert.is_true(s:has("exists"))
    end)

    it("should return false for non-existent keys", function()
      local s = State.new()
      assert.is_false(s:has("missing"))
    end)
  end)

  describe("delete", function()
    it("should delete existing keys", function()
      local s = State.new()
      s:set("key", "value")
      assert.is_true(s:delete("key"))
      assert.is_false(s:has("key"))
    end)

    it("should return false for non-existent keys", function()
      local s = State.new()
      assert.is_false(s:delete("missing"))
    end)
  end)

  describe("keys", function()
    it("should return all keys", function()
      local s = State.new()
      s:set("a", 1)
      s:set("b", 2)
      local keys = s:keys()
      assert.are.equal(2, #keys)
    end)

    it("should return empty array for empty state", function()
      local s = State.new()
      assert.are.equal(0, #s:keys())
    end)
  end)

  describe("values", function()
    it("should return all values", function()
      local s = State.new()
      s:set("a", 1)
      s:set("b", 2)
      local values = s:values()
      assert.are.equal(2, #values)
    end)
  end)

  describe("get_all", function()
    it("should return copy of all data", function()
      local s = State.new()
      s:set("a", 1)
      s:set("b", 2)
      local all = s:get_all()
      assert.are.equal(1, all.a)
      assert.are.equal(2, all.b)
    end)

    it("should return a copy not reference", function()
      local s = State.new()
      s:set("a", 1)
      local all = s:get_all()
      all.a = 999
      assert.are.equal(1, s:get("a"))
    end)
  end)

  describe("clear", function()
    it("should remove all keys", function()
      local s = State.new()
      s:set("a", 1)
      s:set("b", 2)
      s:clear()
      assert.is_false(s:has("a"))
      assert.is_false(s:has("b"))
    end)
  end)

  describe("snapshot/restore", function()
    it("should create a snapshot", function()
      local s = State.new()
      s:set("key", "value")
      local snap = s:snapshot()
      assert.is_table(snap)
      assert.are.equal("value", snap.key)
    end)

    it("should restore from snapshot", function()
      local s = State.new()
      s:set("key", "original")
      local snap = s:snapshot()
      s:set("key", "modified")
      s:restore(snap)
      assert.are.equal("original", s:get("key"))
    end)

    it("should preserve snapshot immutability", function()
      local s = State.new()
      s:set("key", 1)
      local snap = s:snapshot()
      s:set("key", 2)
      s:restore(snap)
      assert.are.equal(1, s:get("key"))
    end)

    it("should handle nested data", function()
      local s = State.new()
      s:set("nested", {a = {b = 1}})
      local snap = s:snapshot()
      s:set("nested", {a = {b = 2}})
      s:restore(snap)
      assert.are.equal(1, s:get("nested").a.b)
    end)
  end)

  describe("event emitter", function()
    it("should set and get event emitter", function()
      local s = State.new()
      local emitter = {}
      s:set_event_emitter(emitter)
      assert.are.equal(emitter, s:get_event_emitter())
    end)

    it("should emit on set", function()
      local s = State.new()
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:set("key", "value")
      assert.are.equal("state:changed", emitted.event)
      assert.are.equal("key", emitted.data.key)
      assert.are.equal("value", emitted.data.new_value)
    end)

    it("should emit on delete", function()
      local s = State.new()
      s:set("key", "value")
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:delete("key")
      assert.are.equal("state:changed", emitted.event)
      assert.is_true(emitted.data.deleted)
    end)

    it("should emit on clear", function()
      local s = State.new()
      s:set("key", "value")
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:clear()
      assert.are.equal("state:cleared", emitted.event)
    end)

    it("should emit on restore", function()
      local s = State.new()
      s:set("key", "value")
      local snap = s:snapshot()
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:restore(snap)
      assert.are.equal("state:restored", emitted.event)
    end)
  end)

  describe("serialize/deserialize", function()
    it("should serialize state", function()
      local s = State.new()
      s:set("key", "value")
      local data = s:serialize()
      assert.is_table(data.data)
      assert.are.equal("value", data.data.key)
    end)

    it("should deserialize state", function()
      local s = State.new()
      s:deserialize({data = {key = "restored"}})
      assert.are.equal("restored", s:get("key"))
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.services.state"] = nil
      local ok, result = pcall(require, "whisker.services.state")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)

-- Contract tests - inline from state_contract.lua
describe("State Contract Tests", function()
  local State = require("whisker.services.state")
  local implementation

  before_each(function()
    implementation = State.new()
  end)

  describe("get/set", function()
    it("should set and get string values", function()
      implementation:set("name", "Alice")
      assert.are.equal("Alice", implementation:get("name"))
    end)

    it("should set and get number values", function()
      implementation:set("health", 100)
      assert.are.equal(100, implementation:get("health"))
    end)

    it("should set and get boolean values", function()
      implementation:set("has_key", true)
      assert.is_true(implementation:get("has_key"))
    end)

    it("should set and get table values", function()
      local inventory = { "sword", "shield" }
      implementation:set("inventory", inventory)
      local result = implementation:get("inventory")
      assert.are.same(inventory, result)
    end)

    it("should return nil for non-existent keys", function()
      assert.is_nil(implementation:get("nonexistent"))
    end)

    it("should overwrite existing values", function()
      implementation:set("score", 10)
      implementation:set("score", 20)
      assert.are.equal(20, implementation:get("score"))
    end)
  end)

  describe("has", function()
    it("should return true for existing keys", function()
      implementation:set("exists", "value")
      assert.is_true(implementation:has("exists"))
    end)

    it("should return false for non-existent keys", function()
      assert.is_false(implementation:has("does_not_exist"))
    end)
  end)

  describe("clear", function()
    it("should remove all keys", function()
      implementation:set("a", 1)
      implementation:set("b", 2)
      implementation:clear()
      assert.is_false(implementation:has("a"))
      assert.is_false(implementation:has("b"))
    end)
  end)

  describe("snapshot/restore", function()
    it("should create a snapshot", function()
      implementation:set("name", "Test")
      local snapshot = implementation:snapshot()
      assert.is_table(snapshot)
    end)

    it("should restore from snapshot", function()
      implementation:set("name", "Alice")
      implementation:set("score", 100)
      local snapshot = implementation:snapshot()
      implementation:set("name", "Bob")
      implementation:set("score", 50)
      implementation:restore(snapshot)
      assert.are.equal("Alice", implementation:get("name"))
      assert.are.equal(100, implementation:get("score"))
    end)

    it("should preserve snapshot immutability", function()
      implementation:set("value", 1)
      local snapshot = implementation:snapshot()
      implementation:set("value", 2)
      implementation:restore(snapshot)
      assert.are.equal(1, implementation:get("value"))
    end)

    it("should round-trip complex state", function()
      local complex_data = {
        nested = { a = 1, b = 2 },
        array = { "one", "two", "three" }
      }
      implementation:set("string_val", "hello")
      implementation:set("number_val", 42)
      implementation:set("bool_val", true)
      implementation:set("complex_val", complex_data)
      local snapshot = implementation:snapshot()
      implementation:clear()
      implementation:restore(snapshot)
      assert.are.equal("hello", implementation:get("string_val"))
      assert.are.equal(42, implementation:get("number_val"))
      assert.is_true(implementation:get("bool_val"))
      assert.are.same(complex_data, implementation:get("complex_val"))
    end)
  end)
end)
