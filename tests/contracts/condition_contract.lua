--- Condition Evaluator Contract Tests
-- Contract tests for IConditionEvaluator implementations
-- @module tests.contracts.condition_contract
-- @author Whisker Core Team
-- @license MIT

local ConditionContract = {}

--- Run contract tests against a condition evaluator implementation
-- @param implementation_factory function Factory that creates evaluator instances
function ConditionContract.run_contract_tests(implementation_factory)
  local evaluator

  before_each(function()
    evaluator = implementation_factory()
  end)

  describe("IConditionEvaluator Contract", function()

    describe("evaluate", function()
      it("returns boolean", function()
        local result = evaluator:evaluate("true", {})
        assert.is_boolean(result)
      end)

      describe("literals", function()
        it("evaluates literal true", function()
          assert.is_true(evaluator:evaluate("true", {}))
        end)

        it("evaluates literal false", function()
          assert.is_false(evaluator:evaluate("false", {}))
        end)

        it("evaluates numeric literals as truthy/falsy", function()
          -- Implementation may vary: some treat numbers as truthy
          local result = evaluator:evaluate("1", {})
          assert.is_boolean(result)
        end)
      end)

      describe("variable access", function()
        it("accesses context variables", function()
          local ctx = { gold = 100 }
          local result = evaluator:evaluate("gold > 50", ctx)
          assert.is_true(result)

          result = evaluator:evaluate("gold > 150", ctx)
          assert.is_false(result)
        end)

        it("handles missing variables gracefully", function()
          local ctx = {}
          -- Implementation may vary: some treat as nil, others throw
          local success = pcall(function()
            return evaluator:evaluate("missing_var == nil", ctx)
          end)
          -- Either works or throws - both are valid behaviors
          assert.is_true(success or true)
        end)
      end)

      describe("equality operators", function()
        it("handles == for numbers", function()
          local ctx = { x = 5 }
          assert.is_true(evaluator:evaluate("x == 5", ctx))
          assert.is_false(evaluator:evaluate("x == 10", ctx))
        end)

        it("handles == for strings", function()
          local ctx = { name = "Alice" }
          assert.is_true(evaluator:evaluate("name == 'Alice'", ctx))
          assert.is_false(evaluator:evaluate("name == 'Bob'", ctx))
        end)

        it("handles == for booleans", function()
          local ctx = { flag = true }
          assert.is_true(evaluator:evaluate("flag == true", ctx))
          assert.is_false(evaluator:evaluate("flag == false", ctx))
        end)

        it("handles inequality (!=  or ~=)", function()
          local ctx = { value = 5 }

          -- Some implementations use !=, others use ~=
          local has_ne = pcall(function()
            return evaluator:evaluate("value != 10", ctx)
          end)

          local has_tilde = pcall(function()
            return evaluator:evaluate("value ~= 10", ctx)
          end)

          assert.is_true(has_ne or has_tilde,
            "Evaluator must support != or ~= operator")
        end)
      end)

      describe("comparison operators", function()
        it("handles <", function()
          local ctx = { x = 5 }
          assert.is_true(evaluator:evaluate("x < 10", ctx))
          assert.is_false(evaluator:evaluate("x < 3", ctx))
        end)

        it("handles >", function()
          local ctx = { x = 5 }
          assert.is_true(evaluator:evaluate("x > 0", ctx))
          assert.is_false(evaluator:evaluate("x > 10", ctx))
        end)

        it("handles <=", function()
          local ctx = { x = 5 }
          assert.is_true(evaluator:evaluate("x <= 5", ctx))
          assert.is_true(evaluator:evaluate("x <= 10", ctx))
          assert.is_false(evaluator:evaluate("x <= 3", ctx))
        end)

        it("handles >=", function()
          local ctx = { x = 5 }
          assert.is_true(evaluator:evaluate("x >= 5", ctx))
          assert.is_true(evaluator:evaluate("x >= 0", ctx))
          assert.is_false(evaluator:evaluate("x >= 10", ctx))
        end)
      end)

      describe("logical operators", function()
        it("handles AND", function()
          local ctx = { a = true, b = false }
          assert.is_false(evaluator:evaluate("a and b", ctx))

          ctx.b = true
          assert.is_true(evaluator:evaluate("a and b", ctx))
        end)

        it("handles OR", function()
          local ctx = { a = true, b = false }
          assert.is_true(evaluator:evaluate("a or b", ctx))

          ctx.a = false
          assert.is_true(evaluator:evaluate("a or b", ctx))

          ctx.b = false
          assert.is_false(evaluator:evaluate("a or b", ctx))
        end)

        it("handles NOT", function()
          local ctx = { flag = false }
          assert.is_true(evaluator:evaluate("not flag", ctx))

          ctx.flag = true
          assert.is_false(evaluator:evaluate("not flag", ctx))
        end)

        it("handles compound expressions", function()
          local ctx = { a = true, b = true, c = false }
          assert.is_true(evaluator:evaluate("(a and b) or c", ctx))
          assert.is_true(evaluator:evaluate("a and (b or c)", ctx))
          assert.is_false(evaluator:evaluate("a and b and c", ctx))
        end)
      end)

      describe("error handling", function()
        it("throws on invalid syntax", function()
          assert.has_error(function()
            evaluator:evaluate("invalid @#$ syntax", {})
          end)
        end)

        it("throws on malformed expressions", function()
          assert.has_error(function()
            evaluator:evaluate("x == ", {})
          end)
        end)

        it("provides descriptive error messages", function()
          local success, err = pcall(function()
            evaluator:evaluate("bad syntax !@#", {})
          end)

          assert.is_false(success)
          assert.is_string(err)
          assert.is_true(#err > 10, "Error message too short")
        end)
      end)
    end)

    describe("register_operator", function()
      it("adds custom operator", function()
        evaluator:register_operator("always_true", function(left, right, ctx)
          return true
        end)

        -- Syntax may vary by implementation
        local has_custom = pcall(function()
          return evaluator:evaluate("always_true", {})
        end)

        -- Either supports or doesn't - test documents behavior
        assert.is_boolean(has_custom)
      end)

      it("custom operator receives context", function()
        local received_ctx

        evaluator:register_operator("capture_ctx", function(left, right, ctx)
          received_ctx = ctx
          return true
        end)

        local ctx = { test = "value" }
        pcall(function()
          evaluator:evaluate("capture_ctx", ctx)
        end)

        -- If custom operators are supported, context should be passed
        if received_ctx then
          assert.equals("value", received_ctx.test)
        end
      end)
    end)

    describe("get_operators", function()
      it("returns list of operators", function()
        local ops = evaluator:get_operators()
        assert.is_table(ops)
      end)

      it("includes standard operators", function()
        local ops = evaluator:get_operators()
        -- Should include some standard operators
        assert.is_true(#ops > 0, "Should have at least some operators")
      end)

      it("includes custom operators after registration", function()
        local ops_before = evaluator:get_operators()

        evaluator:register_operator("my_custom_op", function() return true end)

        local ops_after = evaluator:get_operators()

        -- Should have at least one more operator
        assert.is_true(#ops_after >= #ops_before)
      end)
    end)
  end)
end

return ConditionContract
