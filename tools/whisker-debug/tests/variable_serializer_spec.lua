-- Tests for variable_serializer.lua
package.path = "./tools/whisker-debug/?.lua;./tools/whisker-debug/?/init.lua;" .. package.path

describe("VariableSerializer", function()
  local VariableSerializer

  before_each(function()
    package.loaded["lib.variable_serializer"] = nil
    package.loaded["lib.interfaces"] = nil
    VariableSerializer = require("lib.variable_serializer")
  end)

  describe("new", function()
    it("creates a new instance", function()
      local serializer = VariableSerializer.new()
      assert.is_not_nil(serializer)
    end)
  end)

  describe("serialize", function()
    it("serializes nil", function()
      local serializer = VariableSerializer.new()
      local var = serializer:serialize("x", nil)

      assert.equals("x", var.name)
      assert.equals("nil", var.value)
      assert.equals("nil", var.type)
      assert.equals(0, var.variablesReference)
    end)

    it("serializes boolean", function()
      local serializer = VariableSerializer.new()

      local var_true = serializer:serialize("flag", true)
      assert.equals("true", var_true.value)
      assert.equals("boolean", var_true.type)

      local var_false = serializer:serialize("flag", false)
      assert.equals("false", var_false.value)
    end)

    it("serializes number", function()
      local serializer = VariableSerializer.new()

      local var_int = serializer:serialize("count", 42)
      assert.equals("42", var_int.value)
      assert.equals("number", var_int.type)

      local var_float = serializer:serialize("pi", 3.14)
      assert.equals("3.14", var_float.value)
    end)

    it("serializes string with quotes", function()
      local serializer = VariableSerializer.new()
      local var = serializer:serialize("name", "hello")

      assert.equals('"hello"', var.value)
      assert.equals("string", var.type)
    end)

    it("escapes special characters in strings", function()
      local serializer = VariableSerializer.new()

      local var = serializer:serialize("text", 'line1\nline2')
      assert.matches("\\n", var.value)
    end)

    it("serializes table with count", function()
      local serializer = VariableSerializer.new()
      local var = serializer:serialize("inventory", {"sword", "shield"})

      assert.equals("table[2]", var.value)
      assert.equals("table", var.type)
      assert.is_true(var.variablesReference > 0)
    end)

    it("serializes function", function()
      local serializer = VariableSerializer.new()
      local var = serializer:serialize("callback", function() end)

      assert.equals("function", var.value)
      assert.equals("function", var.type)
    end)
  end)

  describe("get_variables", function()
    it("returns empty for invalid reference", function()
      local serializer = VariableSerializer.new()
      local vars = serializer:get_variables(9999)

      assert.equals(0, #vars)
    end)

    it("returns array elements with indexes", function()
      local serializer = VariableSerializer.new()
      local arr = {"apple", "banana", "cherry"}
      local ref = serializer:register_container(arr)

      local vars = serializer:get_variables(ref)

      assert.equals(3, #vars)
      assert.equals("[1]", vars[1].name)
      assert.equals('"apple"', vars[1].value)
    end)

    it("returns named keys", function()
      local serializer = VariableSerializer.new()
      local obj = {name = "Player", health = 100}
      local ref = serializer:register_container(obj)

      local vars = serializer:get_variables(ref)

      -- Should be sorted by name
      local names = {}
      for _, v in ipairs(vars) do
        table.insert(names, v.name)
      end

      assert.is_true(#vars == 2)
      -- Check both keys exist
      local has_health = false
      local has_name = false
      for _, n in ipairs(names) do
        if n == "health" then has_health = true end
        if n == "name" then has_name = true end
      end
      assert.is_true(has_health)
      assert.is_true(has_name)
    end)

    it("handles nested tables", function()
      local serializer = VariableSerializer.new()
      local obj = {
        player = {name = "Hero", health = 100}
      }
      local ref = serializer:register_container(obj)

      local vars = serializer:get_variables(ref)
      assert.equals(1, #vars)
      assert.equals("player", vars[1].name)
      assert.equals("table", vars[1].type)
      assert.is_true(vars[1].variablesReference > 0)

      -- Get nested
      local nested = serializer:get_variables(vars[1].variablesReference)
      assert.equals(2, #nested)
    end)
  end)

  describe("evaluate", function()
    it("evaluates simple expressions", function()
      local serializer = VariableSerializer.new()

      local ok, result = serializer:evaluate("1 + 2", {})
      assert.is_true(ok)
      assert.equals(3, result)
    end)

    it("uses context variables", function()
      local serializer = VariableSerializer.new()

      local ok, result = serializer:evaluate("x * 2", {x = 5})
      assert.is_true(ok)
      assert.equals(10, result)
    end)

    it("returns error for invalid syntax", function()
      local serializer = VariableSerializer.new()

      local ok, err = serializer:evaluate("invalid +++", {})
      assert.is_false(ok)
      assert.matches("Syntax error", err)
    end)

    it("returns error for runtime error", function()
      local serializer = VariableSerializer.new()

      local ok, err = serializer:evaluate("undefined_var.field", {})
      assert.is_false(ok)
      assert.matches("Runtime error", err)
    end)
  end)

  describe("clear", function()
    it("removes all containers", function()
      local serializer = VariableSerializer.new()
      local ref = serializer:register_container({1, 2, 3})

      serializer:clear()

      local container = serializer:get_container(ref)
      assert.is_nil(container)
    end)
  end)
end)
