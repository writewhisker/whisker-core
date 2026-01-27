-- tests/validation/test_expression_checker.lua
-- WLS 1.0.0 GAP-015: Expression Errors Tests
-- Tests type checking and error detection in expressions

describe("Expression Checker (GAP-015)", function()
  local ExpressionChecker = require("lib.whisker.validation.expression_checker")

  describe("type checking", function()
    local checker

    before_each(function()
      checker = ExpressionChecker.new({})
    end)

    describe("WLS-EXP-001: Type mismatch", function()

      it("should detect arithmetic on string", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "+",
          left = { type = "literal", value = "hello", value_type = "string" },
          right = { type = "literal", value = 5, value_type = "number" },
        })
        assert.is_true(#diagnostics > 0)
        assert.equals("WLS-EXP-001", diagnostics[1].code)
      end)

      it("should not flag arithmetic on numbers", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "+",
          left = { type = "literal", value = 10, value_type = "number" },
          right = { type = "literal", value = 5, value_type = "number" },
        })
        assert.equals(0, #diagnostics)
      end)

      it("should warn on comparing different types", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "==",
          left = { type = "literal", value = "5", value_type = "string" },
          right = { type = "literal", value = 5, value_type = "number" },
        })
        assert.is_true(#diagnostics > 0)
        local found_type_warn = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-001" then
            found_type_warn = true
            break
          end
        end
        assert.is_true(found_type_warn)
      end)

    end)

    describe("WLS-EXP-002: Invalid operator", function()

      it("should detect invalid concatenation on boolean", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "..",
          left = { type = "literal", value = true, value_type = "boolean" },
          right = { type = "literal", value = "text", value_type = "string" },
        })
        assert.is_true(#diagnostics > 0)
        assert.equals("WLS-EXP-002", diagnostics[1].code)
      end)

      it("should allow string concatenation", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "..",
          left = { type = "literal", value = "hello", value_type = "string" },
          right = { type = "literal", value = " world", value_type = "string" },
        })
        assert.equals(0, #diagnostics)
      end)

      it("should allow string and number concatenation", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "..",
          left = { type = "literal", value = "count: ", value_type = "string" },
          right = { type = "literal", value = 42, value_type = "number" },
        })
        assert.equals(0, #diagnostics)
      end)

    end)

    describe("WLS-EXP-003: Division by zero", function()

      it("should detect division by zero literal", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "/",
          left = { type = "literal", value = 10, value_type = "number" },
          right = { type = "literal", value = 0, value_type = "number" },
        })
        assert.is_true(#diagnostics > 0)
        local found_div_zero = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-003" then
            found_div_zero = true
            break
          end
        end
        assert.is_true(found_div_zero)
      end)

      it("should not flag division by non-zero", function()
        local diagnostics = checker:check({
          type = "binary_expression",
          operator = "/",
          left = { type = "literal", value = 10, value_type = "number" },
          right = { type = "literal", value = 2, value_type = "number" },
        })
        -- Should not have div-by-zero error
        local has_div_zero = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-003" then
            has_div_zero = true
            break
          end
        end
        assert.is_false(has_div_zero)
      end)

    end)

    describe("WLS-EXP-004: Undefined function", function()

      it("should detect unknown function calls", function()
        local diagnostics = checker:check({
          type = "call_expression",
          callee = { type = "identifier", name = "unknown_function" },
          arguments = {}
        })
        assert.is_true(#diagnostics > 0)
        assert.equals("WLS-EXP-004", diagnostics[1].code)
        assert.is_truthy(diagnostics[1].message:find("unknown_function"))
      end)

      it("should allow known WLS functions", function()
        local diagnostics = checker:check({
          type = "call_expression",
          callee = { type = "identifier", name = "visited" },
          arguments = { { type = "literal", value = "passage1" } }
        })
        -- Should not have undefined function error
        local has_undefined = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-004" then
            has_undefined = true
            break
          end
        end
        assert.is_false(has_undefined)
      end)

      it("should allow math functions", function()
        local diagnostics = checker:check({
          type = "call_expression",
          callee = {
            type = "member_expression",
            object = { type = "identifier", name = "math" },
            property = "floor"
          },
          arguments = { { type = "literal", value = 3.7 } }
        })
        local has_undefined = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-004" then
            has_undefined = true
            break
          end
        end
        assert.is_false(has_undefined)
      end)

      it("should allow custom functions when registered", function()
        local ctx = { custom_functions = { myFunc = { return_type = "number" } } }
        checker = ExpressionChecker.new(ctx)

        local diagnostics = checker:check({
          type = "call_expression",
          callee = { type = "identifier", name = "myFunc" },
          arguments = {}
        })
        local has_undefined = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-004" then
            has_undefined = true
            break
          end
        end
        assert.is_false(has_undefined)
      end)

    end)

    describe("WLS-EXP-005: Property on non-object", function()

      it("should detect property access on number", function()
        local diagnostics = checker:check({
          type = "member_expression",
          object = { type = "literal", value = 42, value_type = "number" },
          property = "length"
        })
        assert.is_true(#diagnostics > 0)
        assert.equals("WLS-EXP-005", diagnostics[1].code)
      end)

      it("should detect property access on boolean", function()
        local diagnostics = checker:check({
          type = "member_expression",
          object = { type = "literal", value = true, value_type = "boolean" },
          property = "value"
        })
        assert.is_true(#diagnostics > 0)
        assert.equals("WLS-EXP-005", diagnostics[1].code)
      end)

      it("should allow property access on unknown type", function()
        checker:set_variables({ player = { inferred_type = "unknown" } })
        local diagnostics = checker:check({
          type = "member_expression",
          object = { type = "variable", name = "player" },
          property = "name"
        })
        -- Unknown types should not cause errors
        local has_prop_error = false
        for _, d in ipairs(diagnostics) do
          if d.code == "WLS-EXP-005" then
            has_prop_error = true
            break
          end
        end
        assert.is_false(has_prop_error)
      end)

    end)

  end)

  describe("type inference", function()
    local checker

    before_each(function()
      checker = ExpressionChecker.new({})
    end)

    it("should infer number type from numeric literal", function()
      local node = { type = "literal", value = 42 }
      local t = checker:infer_type(node)
      assert.equals("number", t)
    end)

    it("should infer string type from string literal", function()
      local node = { type = "literal", value = "hello" }
      local t = checker:infer_type(node)
      assert.equals("string", t)
    end)

    it("should infer boolean type from boolean literal", function()
      local node = { type = "literal", value = true }
      local t = checker:infer_type(node)
      assert.equals("boolean", t)
    end)

    it("should infer number from arithmetic expression", function()
      local node = {
        type = "binary_expression",
        operator = "+",
        left = { type = "literal", value = 1 },
        right = { type = "literal", value = 2 }
      }
      local t = checker:infer_type(node)
      assert.equals("number", t)
    end)

    it("should infer boolean from comparison expression", function()
      local node = {
        type = "binary_expression",
        operator = ">",
        left = { type = "literal", value = 5 },
        right = { type = "literal", value = 3 }
      }
      local t = checker:infer_type(node)
      assert.equals("boolean", t)
    end)

    it("should infer string from concatenation", function()
      local node = {
        type = "binary_expression",
        operator = "..",
        left = { type = "literal", value = "a" },
        right = { type = "literal", value = "b" }
      }
      local t = checker:infer_type(node)
      assert.equals("string", t)
    end)

    it("should use variable info for type inference", function()
      checker:set_variables({
        gold = { inferred_type = "number" }
      })
      local node = { type = "variable", name = "gold" }
      local t = checker:infer_type(node)
      assert.equals("number", t)
    end)

  end)

  describe("error code constants", function()
    local Analyzer = require("lib.whisker.validation.analyzer")

    it("should define WLS-EXP-001 (type mismatch)", function()
      assert.equals("WLS-EXP-001", Analyzer.ERROR_CODES.TYPE_MISMATCH)
    end)

    it("should define WLS-EXP-002 (invalid operator)", function()
      assert.equals("WLS-EXP-002", Analyzer.ERROR_CODES.INVALID_OPERATOR)
    end)

    it("should define WLS-EXP-003 (division by zero)", function()
      assert.equals("WLS-EXP-003", Analyzer.ERROR_CODES.DIVISION_BY_ZERO)
    end)

    it("should define WLS-EXP-004 (undefined function)", function()
      assert.equals("WLS-EXP-004", Analyzer.ERROR_CODES.UNDEFINED_FUNCTION)
    end)

    it("should define WLS-EXP-005 (property on non-object)", function()
      assert.equals("WLS-EXP-005", Analyzer.ERROR_CODES.PROPERTY_ON_NON_OBJECT)
    end)

  end)

end)
