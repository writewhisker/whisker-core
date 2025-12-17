-- spec/services/conditions_spec.lua
-- Unit tests for ConditionEvaluator service

describe("ConditionEvaluator", function()
  local ConditionEvaluator

  before_each(function()
    package.loaded["whisker.services.conditions"] = nil
    ConditionEvaluator = require("whisker.services.conditions")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(ConditionEvaluator._whisker)
      assert.are.equal("ConditionEvaluator", ConditionEvaluator._whisker.name)
      assert.is_string(ConditionEvaluator._whisker.version)
      assert.are.equal("IConditionEvaluator", ConditionEvaluator._whisker.implements)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #ConditionEvaluator._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with default operators", function()
      local e = ConditionEvaluator.new()
      assert.is_table(e._operators)
      assert.is_function(e._operators["=="])
    end)

    it("should accept state option", function()
      local state = {}
      local e = ConditionEvaluator.new({state = state})
      assert.are.equal(state, e:get_state_service())
    end)
  end)

  describe("evaluate - nil/empty", function()
    it("should return true for nil", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate(nil))
    end)

    it("should return true for empty string", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate(""))
    end)

    it("should pass through boolean", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate(true))
      assert.is_false(e:evaluate(false))
    end)
  end)

  describe("evaluate - equality operators", function()
    it("should evaluate == with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health == 100", {health = 100}))
      assert.is_false(e:evaluate("health == 100", {health = 50}))
    end)

    it("should evaluate != with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health != 100", {health = 50}))
      assert.is_false(e:evaluate("health != 100", {health = 100}))
    end)

    it("should evaluate ~= (Lua style)", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health ~= 100", {health = 50}))
    end)
  end)

  describe("evaluate - comparison operators", function()
    it("should evaluate > with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health > 50", {health = 100}))
      assert.is_false(e:evaluate("health > 50", {health = 50}))
    end)

    it("should evaluate < with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health < 100", {health = 50}))
      assert.is_false(e:evaluate("health < 100", {health = 100}))
    end)

    it("should evaluate >= with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health >= 50", {health = 50}))
      assert.is_true(e:evaluate("health >= 50", {health = 100}))
      assert.is_false(e:evaluate("health >= 50", {health = 25}))
    end)

    it("should evaluate <= with context", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("health <= 100", {health = 100}))
      assert.is_true(e:evaluate("health <= 100", {health = 50}))
      assert.is_false(e:evaluate("health <= 100", {health = 150}))
    end)
  end)

  describe("evaluate - boolean literals", function()
    it("should parse true literal", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("has_key == true", {has_key = true}))
    end)

    it("should parse false literal", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("has_key == false", {has_key = false}))
    end)
  end)

  describe("evaluate - string literals", function()
    it("should parse single-quoted strings", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("name == 'Alice'", {name = "Alice"}))
    end)

    it("should parse double-quoted strings", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate('name == "Bob"', {name = "Bob"}))
    end)
  end)

  describe("evaluate - simple variable", function()
    it("should return true for truthy variable", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("has_key", {has_key = true}))
      assert.is_true(e:evaluate("count", {count = 1}))
      assert.is_true(e:evaluate("name", {name = "test"}))
    end)

    it("should return false for falsy variable", function()
      local e = ConditionEvaluator.new()
      assert.is_false(e:evaluate("has_key", {has_key = false}))
      assert.is_false(e:evaluate("count", {count = 0}))
      assert.is_false(e:evaluate("name", {name = ""}))
      assert.is_falsy(e:evaluate("missing", {}))  -- nil is falsy
    end)
  end)

  describe("evaluate - not operator", function()
    it("should negate with 'not' keyword", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("not has_key", {has_key = false}))
      assert.is_false(e:evaluate("not has_key", {has_key = true}))
    end)

    it("should negate with '!' operator", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("!has_key", {has_key = false}))
      assert.is_false(e:evaluate("!has_key", {has_key = true}))
    end)

    it("should negate comparisons", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("not health > 100", {health = 50}))
    end)
  end)

  describe("evaluate - and operator", function()
    it("should evaluate 'and' expression", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("has_key and has_sword", {has_key = true, has_sword = true}))
      assert.is_false(e:evaluate("has_key and has_sword", {has_key = true, has_sword = false}))
      assert.is_false(e:evaluate("has_key and has_sword", {has_key = false, has_sword = true}))
    end)
  end)

  describe("evaluate - or operator", function()
    it("should evaluate 'or' expression", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate("has_key or has_sword", {has_key = true, has_sword = false}))
      assert.is_true(e:evaluate("has_key or has_sword", {has_key = false, has_sword = true}))
      assert.is_false(e:evaluate("has_key or has_sword", {has_key = false, has_sword = false}))
    end)
  end)

  describe("evaluate - table conditions", function()
    it("should evaluate simple table condition", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate({var = "health", op = ">", value = 50}, {health = 100}))
      assert.is_false(e:evaluate({var = "health", op = ">", value = 50}, {health = 25}))
    end)

    it("should evaluate with left/right syntax", function()
      local e = ConditionEvaluator.new()
      assert.is_true(e:evaluate({left = "health", op = ">=", right = 50}, {health = 50}))
    end)

    it("should evaluate 'all' (AND)", function()
      local e = ConditionEvaluator.new()
      local cond = {
        all = {
          {var = "health", op = ">", value = 0},
          {var = "has_key", op = "==", value = true}
        }
      }
      assert.is_true(e:evaluate(cond, {health = 100, has_key = true}))
      assert.is_false(e:evaluate(cond, {health = 100, has_key = false}))
    end)

    it("should evaluate 'any' (OR)", function()
      local e = ConditionEvaluator.new()
      local cond = {
        any = {
          {var = "has_key", op = "==", value = true},
          {var = "has_sword", op = "==", value = true}
        }
      }
      assert.is_true(e:evaluate(cond, {has_key = true, has_sword = false}))
      assert.is_false(e:evaluate(cond, {has_key = false, has_sword = false}))
    end)

    it("should evaluate 'not' wrapper", function()
      local e = ConditionEvaluator.new()
      local cond = {["not"] = {var = "has_key", op = "==", value = true}}
      assert.is_true(e:evaluate(cond, {has_key = false}))
      assert.is_false(e:evaluate(cond, {has_key = true}))
    end)
  end)

  describe("resolve_variable", function()
    it("should resolve from context", function()
      local e = ConditionEvaluator.new()
      assert.are.equal(100, e:resolve_variable("health", {health = 100}))
    end)

    it("should resolve from context.state", function()
      local e = ConditionEvaluator.new()
      assert.are.equal(100, e:resolve_variable("health", {state = {health = 100}}))
    end)

    it("should resolve from context.state with get method", function()
      local e = ConditionEvaluator.new()
      local state = {
        _data = {health = 100},
        get = function(self, key) return self._data[key] end
      }
      assert.are.equal(100, e:resolve_variable("health", {state = state}))
    end)

    it("should resolve from state service", function()
      local state = {
        _data = {health = 100},
        get = function(self, key) return self._data[key] end
      }
      local e = ConditionEvaluator.new({state = state})
      assert.are.equal(100, e:resolve_variable("health", {}))
    end)
  end)

  describe("register_operator", function()
    it("should register custom operator", function()
      local e = ConditionEvaluator.new()
      e:register_operator("contains", function(a, b)
        return type(a) == "string" and a:find(b, 1, true) ~= nil
      end)
      -- Custom operators work with table conditions
      assert.is_true(e:evaluate({var = "name", op = "contains", value = "Al"}, {name = "Alice"}))
    end)
  end)

  describe("register_function", function()
    it("should register custom function", function()
      local e = ConditionEvaluator.new()
      e:register_function("length", function(s)
        return #s
      end)
      assert.is_function(e._functions.length)
    end)
  end)

  describe("dependency injection", function()
    it("should set state service", function()
      local e = ConditionEvaluator.new()
      local state = {}
      e:set_state_service(state)
      assert.are.equal(state, e:get_state_service())
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.services.conditions"] = nil
      local ok, result = pcall(require, "whisker.services.conditions")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
