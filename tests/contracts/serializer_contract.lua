--- Serializer Contract Tests
-- Contract tests for ISerializer implementations
-- @module tests.contracts.serializer_contract
-- @author Whisker Core Team
-- @license MIT

local SerializerContract = {}

--- Run contract tests against a serializer implementation
-- @param implementation_factory function Factory that creates serializer instances
function SerializerContract.run_contract_tests(implementation_factory)
  local serializer

  before_each(function()
    serializer = implementation_factory()
  end)

  describe("ISerializer Contract", function()

    describe("metadata", function()
      it("has a name property", function()
        local name = serializer.name or serializer:get_name()
        assert.is_string(name)
        assert.is_true(#name > 0, "Serializer name must not be empty")
      end)
    end)

    describe("serialize", function()
      it("returns string for table", function()
        local result = serializer:serialize({ key = "value" })
        assert.is_string(result)
      end)

      it("returns string for number", function()
        local result = serializer:serialize(42)
        assert.is_string(result)
      end)

      it("returns string for string", function()
        local result = serializer:serialize("hello")
        assert.is_string(result)
      end)

      it("returns string for boolean", function()
        local result = serializer:serialize(true)
        assert.is_string(result)
      end)

      it("returns string for empty table", function()
        local result = serializer:serialize({})
        assert.is_string(result)
      end)

      it("returns non-empty string for non-empty data", function()
        local result = serializer:serialize({ key = "value" })
        assert.is_true(#result > 0)
      end)
    end)

    describe("deserialize", function()
      it("throws on invalid string", function()
        assert.has_error(function()
          serializer:deserialize("not valid serialized data!@#$%^&*()")
        end)
      end)

      it("throws on empty string", function()
        assert.has_error(function()
          serializer:deserialize("")
        end)
      end)

      it("provides descriptive error messages", function()
        local success, err = pcall(function()
          serializer:deserialize("invalid")
        end)

        assert.is_false(success)
        assert.is_string(err)
        assert.is_true(#err > 5, "Error message too short")
      end)
    end)

    describe("round-trip preservation", function()
      local function test_roundtrip(value, description)
        it("preserves " .. description, function()
          local serialized = serializer:serialize(value)
          local deserialized = serializer:deserialize(serialized)
          assert.same(value, deserialized)
        end)
      end

      -- Numbers
      test_roundtrip(0, "zero")
      test_roundtrip(1, "one")
      test_roundtrip(42, "positive integer")
      test_roundtrip(-100, "negative integer")
      test_roundtrip(3.14159, "positive float")
      test_roundtrip(-2.71828, "negative float")
      test_roundtrip(1e10, "large number")

      -- Strings
      test_roundtrip("", "empty string")
      test_roundtrip("hello", "simple string")
      test_roundtrip("hello world", "string with space")
      test_roundtrip("hello\nworld", "string with newline")
      test_roundtrip("hello\tworld", "string with tab")
      test_roundtrip('hello "world"', "string with quotes")

      -- Booleans
      test_roundtrip(true, "true")
      test_roundtrip(false, "false")

      -- Tables
      test_roundtrip({}, "empty table")
      test_roundtrip({ a = 1 }, "simple table")
      test_roundtrip({ a = 1, b = 2, c = 3 }, "flat table")
      test_roundtrip({ a = { b = { c = 3 } } }, "nested table")
      test_roundtrip({ 1, 2, 3, 4, 5 }, "simple array")
      test_roundtrip({ { 1, 2 }, { 3, 4 } }, "nested array")
      test_roundtrip({ a = 1, b = "two", c = true, d = { nested = 4 } }, "complex table")
    end)

    describe("multiple serializations", function()
      it("produces consistent deserialize output", function()
        local data = { a = 1, b = 2 }

        local s1 = serializer:serialize(data)
        local s2 = serializer:serialize(data)

        -- Some serializers may produce different key ordering
        -- but deserialization should yield same data
        assert.same(
          serializer:deserialize(s1),
          serializer:deserialize(s2)
        )
      end)

      it("handles multiple deserializations", function()
        local data = { key = "value" }
        local serialized = serializer:serialize(data)

        local d1 = serializer:deserialize(serialized)
        local d2 = serializer:deserialize(serialized)

        assert.same(d1, d2)
        assert.same(data, d1)
      end)
    end)

    describe("independence", function()
      it("deserialized data is independent copy", function()
        local original = { nested = { value = 1 } }
        local serialized = serializer:serialize(original)
        local deserialized = serializer:deserialize(serialized)

        -- Modify deserialized
        deserialized.nested.value = 99

        -- Original should be unchanged
        assert.equals(1, original.nested.value)
      end)
    end)
  end)
end

return SerializerContract
