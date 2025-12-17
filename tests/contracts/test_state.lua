-- tests/contracts/test_state.lua
-- Apply IState contract to SimpleState implementation

-- SimpleState adapter that implements IState interface
-- Wraps a plain table with the IState methods
local SimpleState = {}
SimpleState.__index = SimpleState

function SimpleState.new()
  return setmetatable({
    _data = {}
  }, SimpleState)
end

function SimpleState:get(key)
  return self._data[key]
end

function SimpleState:set(key, value)
  self._data[key] = value
end

function SimpleState:has(key)
  return self._data[key] ~= nil
end

function SimpleState:clear()
  self._data = {}
end

function SimpleState:snapshot()
  local copy = {}
  for k, v in pairs(self._data) do
    if type(v) == "table" then
      copy[k] = SimpleState._deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

function SimpleState:restore(snapshot)
  self._data = {}
  for k, v in pairs(snapshot) do
    if type(v) == "table" then
      self._data[k] = SimpleState._deep_copy(v)
    else
      self._data[k] = v
    end
  end
end

function SimpleState._deep_copy(original)
  if type(original) ~= "table" then
    return original
  end
  local copy = {}
  for k, v in pairs(original) do
    if type(v) == "table" then
      copy[k] = SimpleState._deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- IState contract tests
describe("SimpleState (IState Contract)", function()
  local implementation

  before_each(function()
    implementation = SimpleState.new()
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

    it("should isolate unrelated keys", function()
      implementation:set("a", 1)
      implementation:set("b", 2)
      assert.are.equal(1, implementation:get("a"))
      assert.are.equal(2, implementation:get("b"))
      implementation:set("a", 10)
      assert.are.equal(2, implementation:get("b"))
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
      implementation:set("c", 3)

      implementation:clear()

      assert.is_false(implementation:has("a"))
      assert.is_false(implementation:has("b"))
      assert.is_false(implementation:has("c"))
    end)

    it("should allow setting values after clear", function()
      implementation:set("key", "old")
      implementation:clear()
      implementation:set("key", "new")
      assert.are.equal("new", implementation:get("key"))
    end)
  end)

  describe("snapshot/restore", function()
    it("should create a snapshot", function()
      implementation:set("name", "Test")
      implementation:set("score", 100)

      local snapshot = implementation:snapshot()
      assert.is_table(snapshot)
    end)

    it("should restore from snapshot", function()
      -- Set initial state
      implementation:set("name", "Alice")
      implementation:set("score", 100)

      -- Take snapshot
      local snapshot = implementation:snapshot()

      -- Modify state
      implementation:set("name", "Bob")
      implementation:set("score", 50)
      implementation:set("new_key", "value")

      -- Restore
      implementation:restore(snapshot)

      -- Verify restoration
      assert.are.equal("Alice", implementation:get("name"))
      assert.are.equal(100, implementation:get("score"))
    end)

    it("should preserve snapshot immutability", function()
      implementation:set("value", 1)
      local snapshot = implementation:snapshot()

      implementation:set("value", 2)

      -- Original snapshot should not be affected
      -- Verify by restoring and checking
      implementation:restore(snapshot)
      assert.are.equal(1, implementation:get("value"))
    end)

    it("should handle multiple snapshots", function()
      implementation:set("count", 1)
      local snap1 = implementation:snapshot()

      implementation:set("count", 2)
      local snap2 = implementation:snapshot()

      implementation:set("count", 3)

      -- Restore to snap1
      implementation:restore(snap1)
      assert.are.equal(1, implementation:get("count"))

      -- Restore to snap2
      implementation:restore(snap2)
      assert.are.equal(2, implementation:get("count"))
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
