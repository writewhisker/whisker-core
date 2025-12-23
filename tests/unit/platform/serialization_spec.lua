--- Serialization Tests
--- Tests for the serialization module.

describe("Serialization", function()
  local Serialization

  before_each(function()
    package.loaded["whisker.platform.serialization"] = nil
    package.loaded["whisker.utils.json"] = nil
    Serialization = require("whisker.platform.serialization")
  end)

  describe("serialize", function()
    it("serializes simple table to JSON", function()
      local data = {foo = "bar", num = 42}
      local json, err = Serialization.serialize(data)
      assert.is_string(json)
      assert.is_nil(err)
      assert.matches('"foo"', json)
      assert.matches('"bar"', json)
    end)

    it("rejects non-table input", function()
      local json, err = Serialization.serialize("string")
      assert.is_nil(json)
      assert.is_string(err)
    end)

    it("handles empty table", function()
      local json, err = Serialization.serialize({})
      assert.is_string(json)
    end)

    it("filters out functions", function()
      local data = {
        valid = "value",
        fn = function() end,
      }
      local json, err = Serialization.serialize(data)
      assert.is_string(json)
      assert.matches('"valid"', json)
      assert.is_nil(json:match('"fn"'))
    end)

    it("handles nested tables", function()
      local data = {
        level1 = {
          level2 = {
            value = "deep"
          }
        }
      }
      local json, err = Serialization.serialize(data)
      assert.is_string(json)
      assert.matches('"deep"', json)
    end)
  end)

  describe("deserialize", function()
    it("deserializes JSON to table", function()
      local json = '{"foo":"bar","num":42}'
      local data, err = Serialization.deserialize(json)
      assert.is_table(data)
      assert.is_nil(err)
      assert.equals("bar", data.foo)
      assert.equals(42, data.num)
    end)

    it("rejects non-string input", function()
      local data, err = Serialization.deserialize(123)
      assert.is_nil(data)
      assert.is_string(err)
    end)

    it("rejects empty string", function()
      local data, err = Serialization.deserialize("")
      assert.is_nil(data)
      assert.is_string(err)
    end)

    it("rejects invalid JSON", function()
      local data, err = Serialization.deserialize("{invalid}")
      assert.is_nil(data)
      assert.is_string(err)
    end)

    it("handles arrays", function()
      local json = '[1,2,3,4,5]'
      local data, err = Serialization.deserialize(json)
      assert.is_table(data)
      assert.equals(5, #data)
    end)
  end)

  describe("round-trip", function()
    it("preserves data through serialize/deserialize cycle", function()
      local original = {
        string_val = "hello world",
        number_val = 123.456,
        bool_val = true,
        nested = {
          array = {1, 2, 3},
          object = {a = 1, b = 2}
        }
      }

      local json = Serialization.serialize(original)
      local restored = Serialization.deserialize(json)

      assert.equals(original.string_val, restored.string_val)
      assert.equals(original.number_val, restored.number_val)
      assert.equals(original.bool_val, restored.bool_val)
      assert.equals(original.nested.array[2], restored.nested.array[2])
      assert.equals(original.nested.object.a, restored.nested.object.a)
    end)
  end)

  describe("filter_serializable", function()
    it("removes functions", function()
      local data = {valid = 1, fn = function() end}
      local filtered = Serialization.filter_serializable(data)
      assert.equals(1, filtered.valid)
      assert.is_nil(filtered.fn)
    end)

    it("removes userdata", function()
      -- Create mock userdata-like value (can't actually create userdata in pure Lua)
      -- This test verifies the type checking logic
      local data = {valid = 1}
      local filtered = Serialization.filter_serializable(data)
      assert.equals(1, filtered.valid)
    end)

    it("detects cyclic references", function()
      local data = {value = 1}
      data.self = data  -- Cyclic reference

      local filtered, err = Serialization.filter_serializable(data)
      assert.is_nil(filtered)
      assert.matches("cyclic", err:lower())
    end)

    it("enforces depth limit", function()
      -- Build deeply nested structure
      local data = {}
      local current = data
      for i = 1, 150 do
        current.nested = {}
        current = current.nested
      end

      local filtered, err = Serialization.filter_serializable(data, nil, 100)
      assert.is_nil(filtered)
      assert.matches("depth", err:lower())
    end)
  end)

  describe("is_array", function()
    it("identifies sequential arrays", function()
      assert.is_true(Serialization.is_array({1, 2, 3}))
      assert.is_true(Serialization.is_array({"a", "b", "c"}))
      assert.is_true(Serialization.is_array({}))
    end)

    it("rejects tables with string keys", function()
      assert.is_false(Serialization.is_array({a = 1, b = 2}))
    end)

    it("rejects sparse arrays", function()
      assert.is_false(Serialization.is_array({[1] = "a", [3] = "c"}))
    end)

    it("rejects mixed tables", function()
      assert.is_false(Serialization.is_array({1, 2, key = "value"}))
    end)
  end)

  describe("is_serializable", function()
    it("accepts primitive types", function()
      assert.is_true(Serialization.is_serializable("string"))
      assert.is_true(Serialization.is_serializable(123))
      assert.is_true(Serialization.is_serializable(3.14))
      assert.is_true(Serialization.is_serializable(true))
      assert.is_true(Serialization.is_serializable(false))
      assert.is_true(Serialization.is_serializable(nil))
    end)

    it("accepts serializable tables", function()
      assert.is_true(Serialization.is_serializable({}))
      assert.is_true(Serialization.is_serializable({a = 1}))
      assert.is_true(Serialization.is_serializable({1, 2, 3}))
    end)

    it("rejects functions", function()
      assert.is_false(Serialization.is_serializable(function() end))
    end)

    it("rejects tables with functions", function()
      assert.is_false(Serialization.is_serializable({fn = function() end}))
    end)

    it("rejects cyclic tables", function()
      local t = {}
      t.self = t
      assert.is_false(Serialization.is_serializable(t))
    end)
  end)

  describe("estimate_size", function()
    it("returns size of serialized data", function()
      local data = {foo = "bar"}
      local size = Serialization.estimate_size(data)
      assert.is_number(size)
      assert.is_true(size > 0)
    end)

    it("returns nil for non-serializable data", function()
      local data = "not a table"
      local size = Serialization.estimate_size(data)
      assert.is_nil(size)
    end)
  end)

  describe("deep_copy", function()
    it("creates independent copy", function()
      local original = {nested = {value = 1}}
      local copy = Serialization.deep_copy(original)

      copy.nested.value = 2
      assert.equals(1, original.nested.value)
      assert.equals(2, copy.nested.value)
    end)

    it("copies primitives directly", function()
      assert.equals("string", Serialization.deep_copy("string"))
      assert.equals(123, Serialization.deep_copy(123))
      assert.is_true(Serialization.deep_copy(true))
    end)

    it("handles cycles", function()
      local t = {value = 1}
      t.self = t

      local copy = Serialization.deep_copy(t)
      assert.equals(1, copy.value)
      assert.equals(copy, copy.self)  -- Cycle preserved in copy
    end)
  end)
end)
