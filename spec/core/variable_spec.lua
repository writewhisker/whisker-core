-- spec/core/variable_spec.lua
-- Unit tests for Variable module

describe("Variable", function()
  local Variable

  before_each(function()
    package.loaded["whisker.core.variable"] = nil
    Variable = require("whisker.core.variable")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Variable._whisker)
      assert.are.equal("Variable", Variable._whisker.name)
      assert.is_string(Variable._whisker.version)
      assert.is_table(Variable._whisker.depends)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #Variable._whisker.depends)
    end)

    it("should have TYPES constant", function()
      assert.is_table(Variable.TYPES)
      assert.are.equal("string", Variable.TYPES.string)
      assert.are.equal("number", Variable.TYPES.number)
      assert.are.equal("boolean", Variable.TYPES.boolean)
      assert.are.equal("table", Variable.TYPES.table)
    end)
  end)

  describe("new", function()
    it("should create with options table", function()
      local v = Variable.new({
        name = "score",
        type = "number",
        default = 0
      })
      assert.are.equal("score", v:get_name())
      assert.are.equal("number", v:get_type())
      assert.are.equal(0, v:get_default())
    end)

    it("should create with positional arguments", function()
      local v = Variable.new("health", "number", 100)
      assert.are.equal("health", v:get_name())
      assert.are.equal("number", v:get_type())
      assert.are.equal(100, v:get_default())
    end)

    it("should default to string type", function()
      local v = Variable.new({name = "test"})
      assert.are.equal("string", v:get_type())
    end)

    it("should auto-detect type from default value", function()
      local v = Variable.new({name = "count", default = 42})
      assert.are.equal("number", v:get_type())
    end)

    it("should auto-detect boolean type", function()
      local v = Variable.new({name = "flag", default = true})
      assert.are.equal("boolean", v:get_type())
    end)

    it("should auto-detect table type", function()
      local v = Variable.new({name = "items", default = {}})
      assert.are.equal("table", v:get_type())
    end)

    it("should accept description", function()
      local v = Variable.new({
        name = "test",
        description = "A test variable"
      })
      assert.are.equal("A test variable", v:get_description())
    end)

    it("should set defaults", function()
      local v = Variable.new({name = "test"})
      assert.is_nil(v.default)
      assert.is_nil(v.description)
      assert.are.same({}, v.metadata)
    end)
  end)

  describe("name", function()
    it("should set and get name", function()
      local v = Variable.new({name = "old"})
      v:set_name("new_name")
      assert.are.equal("new_name", v:get_name())
    end)
  end)

  describe("type", function()
    it("should set and get type", function()
      local v = Variable.new({name = "test"})
      v:set_type("number")
      assert.are.equal("number", v:get_type())
    end)

    it("should not set invalid type", function()
      local v = Variable.new({name = "test", type = "string"})
      v:set_type("invalid")
      assert.are.equal("string", v:get_type())
    end)
  end)

  describe("default", function()
    it("should set and get default", function()
      local v = Variable.new({name = "test"})
      v:set_default("hello")
      assert.are.equal("hello", v:get_default())
    end)
  end)

  describe("description", function()
    it("should set and get description", function()
      local v = Variable.new({name = "test"})
      v:set_description("My description")
      assert.are.equal("My description", v:get_description())
    end)
  end)

  describe("validate_value", function()
    it("should accept nil for any type", function()
      local v = Variable.new({name = "test", type = "number"})
      local valid, _ = v:validate_value(nil)
      assert.is_true(valid)
    end)

    it("should accept matching type", function()
      local v = Variable.new({name = "test", type = "number"})
      local valid, _ = v:validate_value(42)
      assert.is_true(valid)
    end)

    it("should reject mismatched type", function()
      local v = Variable.new({name = "test", type = "number"})
      local valid, err = v:validate_value("not a number")
      assert.is_false(valid)
      assert.is_truthy(err:match("Expected number"))
    end)

    it("should validate string type", function()
      local v = Variable.new({name = "test", type = "string"})
      assert.is_true(v:is_valid("hello"))
      assert.is_false(v:is_valid(123))
    end)

    it("should validate boolean type", function()
      local v = Variable.new({name = "test", type = "boolean"})
      assert.is_true(v:is_valid(true))
      assert.is_true(v:is_valid(false))
      assert.is_false(v:is_valid("true"))
    end)

    it("should validate table type", function()
      local v = Variable.new({name = "test", type = "table"})
      assert.is_true(v:is_valid({a = 1}))
      assert.is_false(v:is_valid("{}"))
    end)
  end)

  describe("metadata", function()
    it("should set and get metadata", function()
      local v = Variable.new({name = "test"})
      v:set_metadata("category", "player")
      assert.are.equal("player", v:get_metadata("category"))
    end)

    it("should return default for missing metadata", function()
      local v = Variable.new({name = "test"})
      assert.are.equal("default", v:get_metadata("missing", "default"))
    end)

    it("should check for metadata existence", function()
      local v = Variable.new({name = "test"})
      v:set_metadata("exists", "value")
      assert.is_true(v:has_metadata("exists"))
      assert.is_false(v:has_metadata("missing"))
    end)

    it("should delete metadata", function()
      local v = Variable.new({name = "test"})
      v:set_metadata("key", "value")
      assert.is_true(v:delete_metadata("key"))
      assert.is_false(v:has_metadata("key"))
    end)

    it("should return false when deleting non-existent metadata", function()
      local v = Variable.new({name = "test"})
      assert.is_false(v:delete_metadata("nonexistent"))
    end)

    it("should clear all metadata", function()
      local v = Variable.new({name = "test"})
      v:set_metadata("a", 1)
      v:set_metadata("b", 2)
      v:clear_metadata()
      assert.is_false(v:has_metadata("a"))
      assert.is_false(v:has_metadata("b"))
    end)

    it("should return copy of all metadata", function()
      local v = Variable.new({name = "test"})
      v:set_metadata("key", "value")
      local all = v:get_all_metadata()
      assert.are.equal("value", all.key)
      all.key = "modified"
      assert.are.equal("value", v:get_metadata("key"))
    end)
  end)

  describe("validate", function()
    it("should pass for valid variable", function()
      local v = Variable.new({name = "score", type = "number", default = 0})
      local valid, err = v:validate()
      assert.is_true(valid)
    end)

    it("should fail for empty name", function()
      local v = Variable.new({name = "", type = "number"})
      local valid, err = v:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("name"))
    end)

    it("should fail for invalid type", function()
      local v = Variable.new({name = "test"})
      v.var_type = "invalid_type"
      local valid, err = v:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("Invalid variable type"))
    end)

    it("should fail if default value doesn't match type", function()
      local v = Variable.new({name = "test", type = "number"})
      v.default = "not a number"
      local valid, err = v:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("Default value"))
    end)
  end)

  describe("serialize", function()
    it("should return plain table", function()
      local v = Variable.new({
        name = "score",
        type = "number",
        default = 100,
        description = "Player score"
      })
      local data = v:serialize()
      assert.are.equal("score", data.name)
      assert.are.equal("number", data.type)
      assert.are.equal(100, data.default)
      assert.are.equal("Player score", data.description)
    end)
  end)

  describe("deserialize", function()
    it("should restore variable from data", function()
      local v = Variable.new({name = "temp"})
      v:deserialize({
        name = "restored",
        type = "boolean",
        default = true
      })
      assert.are.equal("restored", v:get_name())
      assert.are.equal("boolean", v:get_type())
      assert.are.equal(true, v:get_default())
    end)

    it("should handle var_type alias", function()
      local v = Variable.new({name = "temp"})
      v:deserialize({name = "test", var_type = "number"})
      assert.are.equal("number", v:get_type())
    end)
  end)

  describe("restore_metatable", function()
    it("should restore metatable to plain table", function()
      local data = {name = "test", type = "string"}
      local restored = Variable.restore_metatable(data)
      assert.are.equal(Variable, getmetatable(restored))
      assert.are.equal("test", restored:get_name())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Variable.restore_metatable(nil))
    end)

    it("should return as-is if already has metatable", function()
      local v = Variable.new({name = "test"})
      local restored = Variable.restore_metatable(v)
      assert.are.equal(v, restored)
    end)

    it("should normalize type field name", function()
      local data = {name = "test", type = "number"}
      local restored = Variable.restore_metatable(data)
      assert.are.equal("number", restored.var_type)
    end)
  end)

  describe("from_table", function()
    it("should create new variable from table", function()
      local v = Variable.from_table({
        name = "from_table",
        type = "number",
        default = 42
      })
      assert.are.equal(Variable, getmetatable(v))
      assert.are.equal("from_table", v:get_name())
      assert.are.equal("number", v:get_type())
      assert.are.equal(42, v:get_default())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Variable.from_table(nil))
    end)

    it("should handle var_type alias", function()
      local v = Variable.from_table({name = "test", var_type = "boolean"})
      assert.are.equal("boolean", v:get_type())
    end)
  end)

  describe("is_typed_format", function()
    it("should return true for typed format", function()
      assert.is_true(Variable.is_typed_format({type = "number", default = 0}))
    end)

    it("should return false for simple value", function()
      assert.is_false(Variable.is_typed_format(42))
      assert.is_false(Variable.is_typed_format("hello"))
    end)

    it("should return false for table without type", function()
      assert.is_false(Variable.is_typed_format({default = 0}))
    end)

    it("should return false for table without default", function()
      assert.is_false(Variable.is_typed_format({type = "number"}))
    end)
  end)

  describe("from_value", function()
    it("should create variable from string value", function()
      local v = Variable.from_value("name", "hello")
      assert.are.equal("name", v:get_name())
      assert.are.equal("string", v:get_type())
      assert.are.equal("hello", v:get_default())
    end)

    it("should create variable from number value", function()
      local v = Variable.from_value("count", 42)
      assert.are.equal("number", v:get_type())
      assert.are.equal(42, v:get_default())
    end)

    it("should create variable from boolean value", function()
      local v = Variable.from_value("flag", true)
      assert.are.equal("boolean", v:get_type())
      assert.are.equal(true, v:get_default())
    end)

    it("should create variable from table value", function()
      local v = Variable.from_value("items", {1, 2, 3})
      assert.are.equal("table", v:get_type())
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.core.variable"] = nil
      local ok, result = pcall(require, "whisker.core.variable")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
