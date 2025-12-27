--- Data Macros Unit Tests
-- Tests for data manipulation macros: variables, arrays, datamaps, type conversion
-- @module tests.unit.script.macros.data.test_data_spec

describe("Data Macros", function()
  local Macros, Data, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Data = require("whisker.script.macros.data")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Data.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Data.VERSION)
    end)

    it("exports all data macros", function()
      -- Variable assignment
      assert.is_table(Data.set_macro)
      assert.is_table(Data.unset_macro)
      assert.is_table(Data.let_macro)
      assert.is_table(Data.move_macro)

      -- Arithmetic
      assert.is_table(Data.increment_macro)
      assert.is_table(Data.decrement_macro)
      assert.is_table(Data.multiply_macro)
      assert.is_table(Data.divide_macro)

      -- Arrays
      assert.is_table(Data.array_macro)
      assert.is_table(Data.push_macro)
      assert.is_table(Data.pop_macro)
      assert.is_table(Data.unshift_macro)
      assert.is_table(Data.shift_macro)
      assert.is_table(Data.slice_macro)
      assert.is_table(Data.contains_macro)
      assert.is_table(Data.length_macro)

      -- Datamaps
      assert.is_table(Data.datamap_macro)
      assert.is_table(Data.get_macro)
      assert.is_table(Data.put_macro)
      assert.is_table(Data.keys_macro)
      assert.is_table(Data.values_macro)
      assert.is_table(Data.has_macro)
      assert.is_table(Data.merge_macro)

      -- Type conversion
      assert.is_table(Data.num_macro)
      assert.is_table(Data.str_macro)
      assert.is_table(Data.bool_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Data.register_all)
    end)
  end)

  -- ============================================================================
  -- Variable Assignment Macros
  -- ============================================================================

  describe("set macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("has proper macro definition structure", function()
      assert.is_function(Data.set_macro.handler)
      assert.equals("data", Data.set_macro.category)
    end)

    it("sets variable by name", function()
      Data.set_macro.handler(ctx, { "score", 100 })
      assert.equals(100, ctx:get("score"))
    end)

    it("strips $ prefix from variable name", function()
      Data.set_macro.handler(ctx, { "$playerName", "Alice" })
      assert.equals("Alice", ctx:get("playerName"))
    end)

    it("returns the assigned value", function()
      local result = Data.set_macro.handler(ctx, { "value", 42 })
      assert.equals(42, result)
    end)

    it("handles variable object", function()
      local var = { _is_variable = true, name = "health" }
      Data.set_macro.handler(ctx, { var, 100 })
      assert.equals(100, ctx:get("health"))
    end)

    it("returns nil for invalid name", function()
      local result, err = Data.set_macro.handler(ctx, { 123, "value" })
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it("has 'put' alias", function()
      local aliases = Data.set_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("unset macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("toDelete", "value")
    end)

    it("removes variable", function()
      Data.unset_macro.handler(ctx, { "toDelete" })
      assert.is_nil(ctx:get("toDelete"))
    end)

    it("strips $ prefix", function()
      Data.unset_macro.handler(ctx, { "$toDelete" })
      assert.is_nil(ctx:get("toDelete"))
    end)

    it("returns true on success", function()
      local result = Data.unset_macro.handler(ctx, { "toDelete" })
      assert.is_true(result)
    end)

    it("handles variable object", function()
      local var = { _is_variable = true, name = "toDelete" }
      Data.unset_macro.handler(ctx, { var })
      assert.is_nil(ctx:get("toDelete"))
    end)

    it("has 'delete' alias", function()
      local aliases = Data.unset_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("let macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates temporary variable", function()
      Data.let_macro.handler(ctx, { "temp", "value" })
      assert.equals("value", ctx:get("temp"))
    end)

    it("strips $ prefix", function()
      Data.let_macro.handler(ctx, { "$temp", 42 })
      assert.equals(42, ctx:get("temp"))
    end)

    it("strips _ prefix", function()
      Data.let_macro.handler(ctx, { "_local", "local value" })
      assert.equals("local value", ctx:get("local"))
    end)

    it("returns the assigned value", function()
      local result = Data.let_macro.handler(ctx, { "x", 99 })
      assert.equals(99, result)
    end)
  end)

  describe("move macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("source", "moved value")
    end)

    it("moves value from source to target", function()
      Data.move_macro.handler(ctx, { "target", "source" })
      assert.equals("moved value", ctx:get("target"))
      assert.is_nil(ctx:get("source"))
    end)

    it("strips $ prefix from both", function()
      Data.move_macro.handler(ctx, { "$dest", "$source" })
      assert.equals("moved value", ctx:get("dest"))
    end)

    it("returns the moved value", function()
      local result = Data.move_macro.handler(ctx, { "target", "source" })
      assert.equals("moved value", result)
    end)
  end)

  -- ============================================================================
  -- Arithmetic Macros
  -- ============================================================================

  describe("increment macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("count", 10)
    end)

    it("increments by 1 by default", function()
      Data.increment_macro.handler(ctx, { "count" })
      assert.equals(11, ctx:get("count"))
    end)

    it("increments by specified amount", function()
      Data.increment_macro.handler(ctx, { "count", 5 })
      assert.equals(15, ctx:get("count"))
    end)

    it("handles unset variable as 0", function()
      Data.increment_macro.handler(ctx, { "newVar" })
      assert.equals(1, ctx:get("newVar"))
    end)

    it("strips $ prefix", function()
      Data.increment_macro.handler(ctx, { "$count", 3 })
      assert.equals(13, ctx:get("count"))
    end)

    it("returns new value", function()
      local result = Data.increment_macro.handler(ctx, { "count", 10 })
      assert.equals(20, result)
    end)

    it("has 'add' alias", function()
      local aliases = Data.increment_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("decrement macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("health", 100)
    end)

    it("decrements by 1 by default", function()
      Data.decrement_macro.handler(ctx, { "health" })
      assert.equals(99, ctx:get("health"))
    end)

    it("decrements by specified amount", function()
      Data.decrement_macro.handler(ctx, { "health", 25 })
      assert.equals(75, ctx:get("health"))
    end)

    it("can go negative", function()
      Data.decrement_macro.handler(ctx, { "health", 150 })
      assert.equals(-50, ctx:get("health"))
    end)

    it("returns new value", function()
      local result = Data.decrement_macro.handler(ctx, { "health", 10 })
      assert.equals(90, result)
    end)

    it("has 'subtract' alias", function()
      local aliases = Data.decrement_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("multiply macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("value", 10)
    end)

    it("multiplies variable by factor", function()
      Data.multiply_macro.handler(ctx, { "value", 5 })
      assert.equals(50, ctx:get("value"))
    end)

    it("handles zero", function()
      Data.multiply_macro.handler(ctx, { "value", 0 })
      assert.equals(0, ctx:get("value"))
    end)

    it("handles negative factor", function()
      Data.multiply_macro.handler(ctx, { "value", -2 })
      assert.equals(-20, ctx:get("value"))
    end)

    it("returns new value", function()
      local result = Data.multiply_macro.handler(ctx, { "value", 3 })
      assert.equals(30, result)
    end)
  end)

  describe("divide macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("total", 100)
    end)

    it("divides variable by divisor", function()
      Data.divide_macro.handler(ctx, { "total", 4 })
      assert.equals(25, ctx:get("total"))
    end)

    it("returns error for division by zero", function()
      local result, err = Data.divide_macro.handler(ctx, { "total", 0 })
      assert.is_nil(result)
      assert.equals("Division by zero", err)
    end)

    it("handles fractional results", function()
      Data.divide_macro.handler(ctx, { "total", 3 })
      local val = ctx:get("total")
      assert.is_true(val > 33 and val < 34)
    end)

    it("returns new value", function()
      local result = Data.divide_macro.handler(ctx, { "total", 10 })
      assert.equals(10, result)
    end)
  end)

  -- ============================================================================
  -- Array Macros
  -- ============================================================================

  describe("array macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates array from values", function()
      local result = Data.array_macro.handler(ctx, { 1, 2, 3 })
      assert.is_table(result)
      assert.equals(3, #result)
      assert.equals(1, result[1])
      assert.equals(2, result[2])
      assert.equals(3, result[3])
    end)

    it("creates empty array", function()
      local result = Data.array_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("handles mixed types", function()
      local result = Data.array_macro.handler(ctx, { "a", 1, true, nil })
      assert.equals("a", result[1])
      assert.equals(1, result[2])
      assert.is_true(result[3])
    end)

    it("has 'a' alias", function()
      local aliases = Data.array_macro.aliases
      assert.is_table(aliases)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.array_macro.pure)
    end)

    it("is Harlowe format", function()
      assert.equals("harlowe", Data.array_macro.format)
    end)
  end)

  describe("push macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("items", { "a", "b" })
    end)

    it("adds item to end of array", function()
      Data.push_macro.handler(ctx, { "items", "c" })
      local arr = ctx:get("items")
      assert.equals(3, #arr)
      assert.equals("c", arr[3])
    end)

    it("creates array if doesn't exist", function()
      Data.push_macro.handler(ctx, { "newArr", "first" })
      local arr = ctx:get("newArr")
      assert.is_table(arr)
      assert.equals(1, #arr)
    end)

    it("converts non-array to array", function()
      ctx:set("notArr", "single")
      Data.push_macro.handler(ctx, { "notArr", "second" })
      local arr = ctx:get("notArr")
      assert.equals(2, #arr)
    end)

    it("returns updated array", function()
      local result = Data.push_macro.handler(ctx, { "items", "new" })
      assert.is_table(result)
      assert.equals(3, #result)
    end)

    it("has 'append' alias", function()
      local aliases = Data.push_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("pop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("stack", { "a", "b", "c" })
    end)

    it("removes and returns last item", function()
      local result = Data.pop_macro.handler(ctx, { "stack" })
      assert.equals("c", result)
      local arr = ctx:get("stack")
      assert.equals(2, #arr)
    end)

    it("returns nil for empty array", function()
      ctx:set("empty", {})
      local result = Data.pop_macro.handler(ctx, { "empty" })
      assert.is_nil(result)
    end)

    it("returns nil for non-array", function()
      ctx:set("str", "not an array")
      local result = Data.pop_macro.handler(ctx, { "str" })
      assert.is_nil(result)
    end)
  end)

  describe("unshift macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("queue", { "b", "c" })
    end)

    it("adds item to beginning", function()
      Data.unshift_macro.handler(ctx, { "queue", "a" })
      local arr = ctx:get("queue")
      assert.equals(3, #arr)
      assert.equals("a", arr[1])
    end)

    it("creates array if doesn't exist", function()
      Data.unshift_macro.handler(ctx, { "newQ", "first" })
      local arr = ctx:get("newQ")
      assert.equals(1, #arr)
      assert.equals("first", arr[1])
    end)

    it("has 'prepend' alias", function()
      local aliases = Data.unshift_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("shift macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("queue", { "first", "second", "third" })
    end)

    it("removes and returns first item", function()
      local result = Data.shift_macro.handler(ctx, { "queue" })
      assert.equals("first", result)
      local arr = ctx:get("queue")
      assert.equals(2, #arr)
      assert.equals("second", arr[1])
    end)

    it("returns nil for empty array", function()
      ctx:set("empty", {})
      local result = Data.shift_macro.handler(ctx, { "empty" })
      assert.is_nil(result)
    end)
  end)

  describe("slice macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("slices array from start to end", function()
      local result = Data.slice_macro.handler(ctx, { { 1, 2, 3, 4, 5 }, 2, 4 })
      assert.equals(3, #result)
      assert.equals(2, result[1])
      assert.equals(3, result[2])
      assert.equals(4, result[3])
    end)

    it("defaults to full array", function()
      local arr = { "a", "b", "c" }
      local result = Data.slice_macro.handler(ctx, { arr })
      assert.equals(3, #result)
    end)

    it("handles variable name", function()
      ctx:set("arr", { 10, 20, 30 })
      local result = Data.slice_macro.handler(ctx, { "$arr", 1, 2 })
      assert.equals(2, #result)
    end)

    it("returns empty array for non-array", function()
      local result = Data.slice_macro.handler(ctx, { "not an array" })
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.slice_macro.pure)
    end)
  end)

  describe("contains macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns true if array contains value", function()
      local result = Data.contains_macro.handler(ctx, { { "a", "b", "c" }, "b" })
      assert.is_true(result)
    end)

    it("returns false if array does not contain value", function()
      local result = Data.contains_macro.handler(ctx, { { "a", "b", "c" }, "x" })
      assert.is_false(result)
    end)

    it("handles variable name", function()
      ctx:set("list", { 1, 2, 3 })
      local result = Data.contains_macro.handler(ctx, { "$list", 2 })
      assert.is_true(result)
    end)

    it("returns false for non-array", function()
      local result = Data.contains_macro.handler(ctx, { "string", "s" })
      assert.is_false(result)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.contains_macro.pure)
    end)

    it("is Harlowe format", function()
      assert.equals("harlowe", Data.contains_macro.format)
    end)
  end)

  describe("length macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns array length", function()
      local result = Data.length_macro.handler(ctx, { { 1, 2, 3, 4 } })
      assert.equals(4, result)
    end)

    it("returns string length", function()
      local result = Data.length_macro.handler(ctx, { "hello" })
      assert.equals(5, result)
    end)

    it("handles variable reference", function()
      ctx:set("items", { "a", "b", "c" })
      local result = Data.length_macro.handler(ctx, { "$items" })
      assert.equals(3, result)
    end)

    it("returns 0 for other types", function()
      local result = Data.length_macro.handler(ctx, { 123 })
      assert.equals(0, result)
    end)

    it("has 'count' alias", function()
      local aliases = Data.length_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  -- ============================================================================
  -- Datamap Macros
  -- ============================================================================

  describe("datamap macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates datamap from key-value pairs", function()
      local result = Data.datamap_macro.handler(ctx, { "name", "Alice", "age", 30 })
      assert.is_table(result)
      assert.equals("Alice", result["name"])
      assert.equals(30, result["age"])
    end)

    it("creates empty datamap", function()
      local result = Data.datamap_macro.handler(ctx, {})
      assert.is_table(result)
    end)

    it("converts keys to strings", function()
      local result = Data.datamap_macro.handler(ctx, { 1, "one", 2, "two" })
      assert.equals("one", result["1"])
      assert.equals("two", result["2"])
    end)

    it("has 'dm', 'map', 'object' aliases", function()
      local aliases = Data.datamap_macro.aliases
      assert.is_table(aliases)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.datamap_macro.pure)
    end)

    it("is Harlowe format", function()
      assert.equals("harlowe", Data.datamap_macro.format)
    end)
  end)

  describe("get macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("gets value from datamap", function()
      local map = { name = "Bob", score = 100 }
      local result = Data.get_macro.handler(ctx, { map, "name" })
      assert.equals("Bob", result)
    end)

    it("returns nil for missing key", function()
      local map = { name = "Bob" }
      local result = Data.get_macro.handler(ctx, { map, "missing" })
      assert.is_nil(result)
    end)

    it("handles variable reference", function()
      ctx:set("player", { health = 100 })
      local result = Data.get_macro.handler(ctx, { "$player", "health" })
      assert.equals(100, result)
    end)

    it("returns nil for non-table", function()
      local result = Data.get_macro.handler(ctx, { "string", "key" })
      assert.is_nil(result)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.get_macro.pure)
    end)
  end)

  describe("put macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("player", { name = "Alice" })
    end)

    it("sets value in datamap", function()
      Data.put_macro.handler(ctx, { "player", "score", 50 })
      local player = ctx:get("player")
      assert.equals(50, player["score"])
    end)

    it("creates datamap if doesn't exist", function()
      Data.put_macro.handler(ctx, { "newMap", "key", "value" })
      local map = ctx:get("newMap")
      assert.is_table(map)
      assert.equals("value", map["key"])
    end)

    it("converts key to string", function()
      Data.put_macro.handler(ctx, { "player", 1, "first" })
      local player = ctx:get("player")
      assert.equals("first", player["1"])
    end)

    it("returns updated map", function()
      local result = Data.put_macro.handler(ctx, { "player", "health", 100 })
      assert.is_table(result)
      assert.equals(100, result["health"])
    end)
  end)

  describe("keys macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns all keys from datamap", function()
      local map = { a = 1, b = 2, c = 3 }
      local result = Data.keys_macro.handler(ctx, { map })
      assert.is_table(result)
      assert.equals(3, #result)
    end)

    it("returns sorted keys", function()
      local map = { c = 3, a = 1, b = 2 }
      local result = Data.keys_macro.handler(ctx, { map })
      assert.equals("a", result[1])
      assert.equals("b", result[2])
      assert.equals("c", result[3])
    end)

    it("handles variable reference", function()
      ctx:set("data", { x = 1, y = 2 })
      local result = Data.keys_macro.handler(ctx, { "$data" })
      assert.equals(2, #result)
    end)

    it("returns empty array for non-table", function()
      local result = Data.keys_macro.handler(ctx, { "string" })
      assert.is_table(result)
      assert.equals(0, #result)
    end)
  end)

  describe("values macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns all values from datamap", function()
      local map = { a = 1, b = 2 }
      local result = Data.values_macro.handler(ctx, { map })
      assert.is_table(result)
      assert.equals(2, #result)
    end)

    it("handles variable reference", function()
      ctx:set("data", { x = 10 })
      local result = Data.values_macro.handler(ctx, { "$data" })
      assert.equals(1, #result)
      assert.equals(10, result[1])
    end)

    it("returns empty array for non-table", function()
      local result = Data.values_macro.handler(ctx, { 123 })
      assert.is_table(result)
      assert.equals(0, #result)
    end)
  end)

  describe("has macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns true if key exists", function()
      local map = { name = "test" }
      local result = Data.has_macro.handler(ctx, { map, "name" })
      assert.is_true(result)
    end)

    it("returns false if key doesn't exist", function()
      local map = { name = "test" }
      local result = Data.has_macro.handler(ctx, { map, "missing" })
      assert.is_false(result)
    end)

    it("handles variable reference", function()
      ctx:set("obj", { key = "value" })
      local result = Data.has_macro.handler(ctx, { "$obj", "key" })
      assert.is_true(result)
    end)

    it("returns false for non-table", function()
      local result = Data.has_macro.handler(ctx, { "string", "key" })
      assert.is_false(result)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.has_macro.pure)
    end)
  end)

  describe("merge macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("merges multiple datamaps", function()
      local m1 = { a = 1 }
      local m2 = { b = 2 }
      local result = Data.merge_macro.handler(ctx, { m1, m2 })
      assert.equals(1, result.a)
      assert.equals(2, result.b)
    end)

    it("later values override earlier", function()
      local m1 = { a = 1 }
      local m2 = { a = 2 }
      local result = Data.merge_macro.handler(ctx, { m1, m2 })
      assert.equals(2, result.a)
    end)

    it("handles variable references", function()
      ctx:set("base", { x = 1 })
      ctx:set("ext", { y = 2 })
      local result = Data.merge_macro.handler(ctx, { "$base", "$ext" })
      assert.equals(1, result.x)
      assert.equals(2, result.y)
    end)

    it("ignores non-table values", function()
      local m1 = { a = 1 }
      local result = Data.merge_macro.handler(ctx, { m1, "string", 123 })
      assert.equals(1, result.a)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.merge_macro.pure)
    end)
  end)

  -- ============================================================================
  -- Type Conversion Macros
  -- ============================================================================

  describe("num macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("converts string to number", function()
      local result = Data.num_macro.handler(ctx, { "42" })
      assert.equals(42, result)
    end)

    it("converts float string", function()
      local result = Data.num_macro.handler(ctx, { "3.14" })
      assert.is_true(result > 3.13 and result < 3.15)
    end)

    it("returns nil for non-numeric string", function()
      local result = Data.num_macro.handler(ctx, { "hello" })
      assert.is_nil(result)
    end)

    it("passes through numbers", function()
      local result = Data.num_macro.handler(ctx, { 100 })
      assert.equals(100, result)
    end)

    it("has 'number' and 'int' aliases", function()
      local aliases = Data.num_macro.aliases
      assert.is_table(aliases)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.num_macro.pure)
    end)

    it("is Harlowe format", function()
      assert.equals("harlowe", Data.num_macro.format)
    end)
  end)

  describe("str macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("converts number to string", function()
      local result = Data.str_macro.handler(ctx, { 42 })
      assert.equals("42", result)
    end)

    it("converts boolean to string", function()
      local result = Data.str_macro.handler(ctx, { true })
      assert.equals("true", result)
    end)

    it("converts nil to string", function()
      local result = Data.str_macro.handler(ctx, { nil })
      assert.equals("nil", result)
    end)

    it("passes through strings", function()
      local result = Data.str_macro.handler(ctx, { "hello" })
      assert.equals("hello", result)
    end)

    it("has 'string' and 'text' aliases", function()
      local aliases = Data.str_macro.aliases
      assert.is_table(aliases)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.str_macro.pure)
    end)
  end)

  describe("bool macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("converts truthy values to true", function()
      assert.is_true(Data.bool_macro.handler(ctx, { 1 }))
      assert.is_true(Data.bool_macro.handler(ctx, { "text" }))
      assert.is_true(Data.bool_macro.handler(ctx, { {} }))
      assert.is_true(Data.bool_macro.handler(ctx, { true }))
    end)

    it("converts falsy values to false", function()
      assert.is_false(Data.bool_macro.handler(ctx, { nil }))
      assert.is_false(Data.bool_macro.handler(ctx, { false }))
      assert.is_false(Data.bool_macro.handler(ctx, { 0 }))
      assert.is_false(Data.bool_macro.handler(ctx, { "" }))
    end)

    it("has 'boolean' alias", function()
      local aliases = Data.bool_macro.aliases
      assert.is_table(aliases)
    end)

    it("is marked as pure", function()
      assert.is_true(Data.bool_macro.pure)
    end)
  end)

  -- ============================================================================
  -- Registration
  -- ============================================================================

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros with registry", function()
      local registry = Registry.new()
      local count = Data.register_all(registry)

      assert.is_true(count >= 25)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Data.register_all(registry)

      -- Variable macros
      assert.is_not_nil(registry:get("set"))
      assert.is_not_nil(registry:get("unset"))
      assert.is_not_nil(registry:get("let"))
      assert.is_not_nil(registry:get("move"))

      -- Arithmetic macros
      assert.is_not_nil(registry:get("increment"))
      assert.is_not_nil(registry:get("decrement"))
      assert.is_not_nil(registry:get("multiply"))
      assert.is_not_nil(registry:get("divide"))

      -- Array macros
      assert.is_not_nil(registry:get("array"))
      assert.is_not_nil(registry:get("push"))
      assert.is_not_nil(registry:get("pop"))
      assert.is_not_nil(registry:get("slice"))
      assert.is_not_nil(registry:get("contains"))
      assert.is_not_nil(registry:get("length"))

      -- Datamap macros
      assert.is_not_nil(registry:get("datamap"))
      assert.is_not_nil(registry:get("get"))
      assert.is_not_nil(registry:get("keys"))
      assert.is_not_nil(registry:get("values"))
      assert.is_not_nil(registry:get("has"))
      assert.is_not_nil(registry:get("merge"))

      -- Type conversion
      assert.is_not_nil(registry:get("num"))
      assert.is_not_nil(registry:get("str"))
      assert.is_not_nil(registry:get("bool"))
    end)

    it("all registered macros have data category", function()
      local registry = Registry.new()
      Data.register_all(registry)

      local names = { "set", "array", "datamap", "num" }
      for _, name in ipairs(names) do
        local macro = registry:get(name)
        assert.equals("data", macro.category)
      end
    end)
  end)

  -- ============================================================================
  -- Integration Scenarios
  -- ============================================================================

  describe("integration scenarios", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("array manipulation workflow", function()
      -- Create array
      local arr = Data.array_macro.handler(ctx, { 1, 2, 3 })
      ctx:set("numbers", arr)

      -- Push new item
      Data.push_macro.handler(ctx, { "numbers", 4 })

      -- Check contains
      assert.is_true(Data.contains_macro.handler(ctx, { "$numbers", 4 }))

      -- Get length
      assert.equals(4, Data.length_macro.handler(ctx, { "$numbers" }))

      -- Pop last
      local popped = Data.pop_macro.handler(ctx, { "numbers" })
      assert.equals(4, popped)
      assert.equals(3, Data.length_macro.handler(ctx, { "$numbers" }))
    end)

    it("datamap manipulation workflow", function()
      -- Create datamap
      local player = Data.datamap_macro.handler(ctx, { "name", "Hero", "level", 1 })
      ctx:set("player", player)

      -- Add new property
      Data.put_macro.handler(ctx, { "player", "health", 100 })

      -- Check has
      assert.is_true(Data.has_macro.handler(ctx, { "$player", "health" }))

      -- Get value
      assert.equals(100, Data.get_macro.handler(ctx, { "$player", "health" }))

      -- Get keys
      local keys = Data.keys_macro.handler(ctx, { "$player" })
      assert.equals(3, #keys)
    end)

    it("arithmetic workflow", function()
      Data.set_macro.handler(ctx, { "score", 0 })

      Data.increment_macro.handler(ctx, { "score", 10 })
      assert.equals(10, ctx:get("score"))

      Data.multiply_macro.handler(ctx, { "score", 2 })
      assert.equals(20, ctx:get("score"))

      Data.decrement_macro.handler(ctx, { "score", 5 })
      assert.equals(15, ctx:get("score"))

      Data.divide_macro.handler(ctx, { "score", 3 })
      assert.equals(5, ctx:get("score"))
    end)
  end)
end)
