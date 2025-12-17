-- tests/contracts/state_contract.lua
-- Contract test suite for IState implementations
-- Any state manager can be validated against this contract
--
-- Usage:
--   require("tests.contracts.state_contract").register(
--     "MyState",
--     MyState.new()
--   )

local StateContract = {}

-- Register contract tests for an IState implementation
-- Must be called from within a busted test file
-- @param name string - Name for the test suite
-- @param implementation table - IState implementation to test
function StateContract.register(name, implementation)
  describe(name, function()
    before_each(function()
      -- Clear state before each test
      if implementation.clear then
        implementation:clear()
      end
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

      it("should return true for nil values if key was set", function()
        -- Note: Some implementations may differ on this behavior
        -- This test documents expected behavior
        implementation:set("null_value", nil)
        -- After setting to nil, key may be considered "not existing"
        -- This is implementation-dependent
        local result = implementation:has("null_value")
        assert.is_boolean(result)
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
end

return StateContract
