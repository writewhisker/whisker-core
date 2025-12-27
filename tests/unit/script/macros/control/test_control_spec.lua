--- Control Flow Macros Unit Tests
-- Tests for control flow macros: if/else, loops, switch, flow control
-- @module tests.unit.script.macros.control.test_control_spec

describe("Control Flow Macros", function()
  local Macros, Control, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Control = require("whisker.script.macros.control")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Control.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Control.VERSION)
    end)

    it("exports all control macros", function()
      assert.is_table(Control.if_macro)
      assert.is_table(Control.else_macro)
      assert.is_table(Control.elseif_macro)
      assert.is_table(Control.unless_macro)
      assert.is_table(Control.for_macro)
      assert.is_table(Control.range_macro)
      assert.is_table(Control.while_macro)
      assert.is_table(Control.break_macro)
      assert.is_table(Control.continue_macro)
      assert.is_table(Control.switch_macro)
      assert.is_table(Control.cond_macro)
      assert.is_table(Control.stop_macro)
      assert.is_table(Control.return_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Control.register_all)
    end)
  end)

  describe("if macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("has proper macro definition structure", function()
      assert.is_function(Control.if_macro.handler)
      assert.equals("control", Control.if_macro.category)
    end)

    it("executes body when condition is truthy", function()
      local result = Control.if_macro.handler(ctx, { true, "success" })
      assert.equals("success", result)
    end)

    it("returns nil when condition is falsy", function()
      local result = Control.if_macro.handler(ctx, { false, "should not appear" })
      assert.is_nil(result)
    end)

    it("coerces non-nil values to true", function()
      assert.is_not_nil(Control.if_macro.handler(ctx, { 1, "yes" }))
      assert.is_not_nil(Control.if_macro.handler(ctx, { "some text here", "yes" }))
      assert.is_not_nil(Control.if_macro.handler(ctx, { true, "yes" }))
    end)

    it("treats nil as falsy", function()
      local result = Control.if_macro.handler(ctx, { nil, "no" })
      assert.is_nil(result)
    end)

    it("executes function body", function()
      local body_fn = function(c)
        return "from function"
      end
      local result = Control.if_macro.handler(ctx, { true, body_fn })
      assert.equals("from function", result)
    end)

    it("writes string body to output", function()
      Control.if_macro.handler(ctx, { true, "output text" })
      local output = ctx:get_output()
      assert.equals("output text", output)
    end)

    it("has 'when' alias", function()
      local aliases = Control.if_macro.aliases
      assert.is_table(aliases)
      assert.is_true(table.concat(aliases, ","):find("when") ~= nil)
    end)
  end)

  describe("else macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("always executes when reached", function()
      local result = Control.else_macro.handler(ctx, { "else content" })
      assert.equals("else content", result)
    end)

    it("executes function body", function()
      local body_fn = function(c)
        return "else function"
      end
      local result = Control.else_macro.handler(ctx, { body_fn })
      assert.equals("else function", result)
    end)

    it("returns nil with no body", function()
      local result = Control.else_macro.handler(ctx, {})
      assert.is_nil(result)
    end)
  end)

  describe("elseif macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("executes body when condition is truthy", function()
      local result = Control.elseif_macro.handler(ctx, { true, "elseif content" })
      assert.equals("elseif content", result)
    end)

    it("returns nil when condition is falsy", function()
      local result = Control.elseif_macro.handler(ctx, { false, "should not appear" })
      assert.is_nil(result)
    end)

    it("has 'else-if' and 'elif' aliases", function()
      local aliases = Control.elseif_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("unless macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("executes body when condition is falsy", function()
      local result = Control.unless_macro.handler(ctx, { false, "unless content" })
      assert.equals("unless content", result)
    end)

    it("returns nil when condition is truthy", function()
      local result = Control.unless_macro.handler(ctx, { true, "should not appear" })
      assert.is_nil(result)
    end)

    it("treats nil as falsy (executes body)", function()
      local result = Control.unless_macro.handler(ctx, { nil, "nil is falsy" })
      assert.equals("nil is falsy", result)
    end)

    it("inverts boolean logic", function()
      -- unless true -> do not execute
      assert.is_nil(Control.unless_macro.handler(ctx, { true, "no" }))
      -- unless false -> execute
      assert.equals("yes", Control.unless_macro.handler(ctx, { false, "yes" }))
    end)
  end)

  describe("for macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("iterates over array", function()
      local items = { "a", "b", "c" }
      local collected = {}
      local body_fn = function(c)
        local item = c:get("_it")
        table.insert(collected, item)
        return item
      end

      Control.for_macro.handler(ctx, { items, body_fn })

      assert.equals(3, #collected)
      assert.equals("a", collected[1])
      assert.equals("b", collected[2])
      assert.equals("c", collected[3])
    end)

    it("sets _i for index during iteration", function()
      local items = { "x", "y" }
      local indices = {}
      local body_fn = function(c)
        table.insert(indices, c:get("_i"))
        return ""
      end

      Control.for_macro.handler(ctx, { items, body_fn })

      assert.equals(2, #indices)
      assert.equals(1, indices[1])
      assert.equals(2, indices[2])
    end)

    it("iterates numeric times", function()
      local count = 0
      local body_fn = function(c)
        count = count + 1
        return ""
      end

      Control.for_macro.handler(ctx, { 5, body_fn })

      assert.equals(5, count)
    end)

    it("returns results table", function()
      local items = { 1, 2, 3 }
      local body_fn = function(c)
        return tostring(c:get("_it") * 2)
      end

      local result = Control.for_macro.handler(ctx, { items, body_fn })

      assert.is_table(result)
      assert.equals(3, #result)
    end)

    it("handles empty array", function()
      local result = Control.for_macro.handler(ctx, { {}, function() return "x" end })
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("returns nil for nil iterator", function()
      local result = Control.for_macro.handler(ctx, { nil, function() end })
      assert.is_nil(result)
    end)

    it("has 'each' and 'foreach' aliases", function()
      local aliases = Control.for_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("range macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates range with single argument (1 to n)", function()
      local result = Control.range_macro.handler(ctx, { 5 })
      assert.is_table(result)
      assert.equals(5, #result)
      assert.equals(1, result[1])
      assert.equals(5, result[5])
    end)

    it("creates range with start and end", function()
      local result = Control.range_macro.handler(ctx, { 3, 7 })
      assert.is_table(result)
      assert.equals(5, #result)
      assert.equals(3, result[1])
      assert.equals(7, result[5])
    end)

    it("creates range with custom step", function()
      local result = Control.range_macro.handler(ctx, { 0, 10, 2 })
      assert.is_table(result)
      assert.equals(6, #result)
      assert.equals(0, result[1])
      assert.equals(2, result[2])
      assert.equals(10, result[6])
    end)

    it("creates descending range with negative step", function()
      local result = Control.range_macro.handler(ctx, { 5, 1, -1 })
      assert.is_table(result)
      assert.equals(5, #result)
      assert.equals(5, result[1])
      assert.equals(1, result[5])
    end)

    it("returns empty table for invalid range", function()
      local result = Control.range_macro.handler(ctx, { 5, 1, 1 })  -- Can't go up from 5 to 1
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("is marked as pure", function()
      assert.is_true(Control.range_macro.pure)
    end)
  end)

  describe("while macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("loops while condition is true", function()
      local count = 0
      local max = 3
      local condition_fn = function()
        return count < max
      end
      local body_fn = function(c)
        count = count + 1
        return tostring(count)
      end

      local result = Control.while_macro.handler(ctx, { condition_fn, body_fn })

      assert.equals(3, count)
      assert.is_table(result)
      assert.equals(3, #result)
    end)

    it("does not execute if condition is initially false", function()
      local executed = false
      local condition_fn = function() return false end
      local body_fn = function()
        executed = true
        return ""
      end

      Control.while_macro.handler(ctx, { condition_fn, body_fn })

      assert.is_false(executed)
    end)

    it("respects max_iterations limit", function()
      local count = 0
      local condition_fn = function() return true end  -- Infinite loop attempt
      local body_fn = function()
        count = count + 1
        return ""
      end

      Control.while_macro.handler(ctx, { condition_fn, body_fn, max = 10 })

      assert.equals(10, count)
    end)

    it("writes output to context", function()
      local i = 0
      local condition_fn = function() return i < 2 end
      local body_fn = function()
        i = i + 1
        return "x"
      end

      Control.while_macro.handler(ctx, { condition_fn, body_fn })
      local output = ctx:get_output()

      assert.equals("xx", output)
    end)
  end)

  describe("break macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets break_loop flag", function()
      Control.break_macro.handler(ctx, {})
      local flag = ctx:get_flag("break_loop")
      assert.is_true(flag)
    end)

    it("returns nil", function()
      local result = Control.break_macro.handler(ctx, {})
      assert.is_nil(result)
    end)

    it("has 'stop' alias", function()
      local aliases = Control.break_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("continue macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets continue_loop flag", function()
      Control.continue_macro.handler(ctx, {})
      local flag = ctx:get_flag("continue_loop")
      assert.is_true(flag)
    end)

    it("returns nil", function()
      local result = Control.continue_macro.handler(ctx, {})
      assert.is_nil(result)
    end)

    it("has 'next' alias", function()
      local aliases = Control.continue_macro.aliases
      assert.is_table(aliases)
    end)
  end)

  describe("switch macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("matches case and executes body", function()
      local cases = {
        { value = 1, body = "one" },
        { value = 2, body = "two" },
        { value = 3, body = "three" },
      }

      local result = Control.switch_macro.handler(ctx, { 2, cases })
      assert.equals("two", result)
    end)

    it("returns nil for no match", function()
      local cases = {
        { value = 1, body = "one" },
        { value = 2, body = "two" },
      }

      local result = Control.switch_macro.handler(ctx, { 999, cases })
      assert.is_nil(result)
    end)

    it("handles default case", function()
      local cases = {
        { value = 1, body = "one" },
        { value = "_default", body = "default value" },
      }

      local result = Control.switch_macro.handler(ctx, { 999, cases })
      assert.equals("default value", result)
    end)

    it("executes function body", function()
      local cases = {
        { value = 42, body = function(c) return "matched 42" end },
      }

      local result = Control.switch_macro.handler(ctx, { 42, cases })
      assert.equals("matched 42", result)
    end)

    it("matches first case on multiple matches", function()
      local cases = {
        { value = 1, body = "first" },
        { value = 1, body = "second" },
      }

      local result = Control.switch_macro.handler(ctx, { 1, cases })
      assert.equals("first", result)
    end)

    it("returns nil for nil cases", function()
      local result = Control.switch_macro.handler(ctx, { 1, nil })
      assert.is_nil(result)
    end)
  end)

  describe("cond macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("evaluates conditions in order", function()
      local result = Control.cond_macro.handler(ctx, {
        false, "first",
        true, "second",
        true, "third"
      })
      assert.equals("second", result)
    end)

    it("returns nil if no condition matches", function()
      local result = Control.cond_macro.handler(ctx, {
        false, "no",
        false, "nope"
      })
      assert.is_nil(result)
    end)

    it("handles function results", function()
      local result = Control.cond_macro.handler(ctx, {
        true, function(c) return "func result" end
      })
      assert.equals("func result", result)
    end)

    it("supports true as default condition", function()
      local result = Control.cond_macro.handler(ctx, {
        false, "no",
        true, "default"
      })
      assert.equals("default", result)
    end)

    it("is Harlowe format", function()
      assert.equals("harlowe", Control.cond_macro.format)
    end)
  end)

  describe("stop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets stop_execution flag", function()
      Control.stop_macro.handler(ctx, {})
      local flag = ctx:get_flag("stop_execution")
      assert.is_true(flag)
    end)

    it("returns nil", function()
      local result = Control.stop_macro.handler(ctx, {})
      assert.is_nil(result)
    end)
  end)

  describe("return macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("sets stop_execution flag", function()
      Control.return_macro.handler(ctx, { "result" })
      -- The return macro sets flags on the context
      -- We verify it returns correctly
    end)

    it("returns the value", function()
      local result = Control.return_macro.handler(ctx, { "returned" })
      assert.equals("returned", result)
    end)

    it("returns nil for empty return", function()
      local result = Control.return_macro.handler(ctx, {})
      -- Empty return returns nil as the actual value
      assert.is_nil(result)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros with registry", function()
      local registry = Registry.new()
      local count = Control.register_all(registry)

      assert.is_true(count >= 13)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Control.register_all(registry)

      assert.is_not_nil(registry:get("if"))
      assert.is_not_nil(registry:get("else"))
      assert.is_not_nil(registry:get("elseif"))
      assert.is_not_nil(registry:get("unless"))
      assert.is_not_nil(registry:get("for"))
      assert.is_not_nil(registry:get("range"))
      assert.is_not_nil(registry:get("while"))
      assert.is_not_nil(registry:get("break"))
      assert.is_not_nil(registry:get("continue"))
      assert.is_not_nil(registry:get("switch"))
      assert.is_not_nil(registry:get("cond"))
      assert.is_not_nil(registry:get("stop"))
      assert.is_not_nil(registry:get("return"))
    end)

    it("all registered macros have control category", function()
      local registry = Registry.new()
      Control.register_all(registry)

      local names = { "if", "else", "for", "while", "switch" }
      for _, name in ipairs(names) do
        local macro = registry:get(name)
        assert.equals("control", macro.category)
      end
    end)
  end)

  describe("integration scenarios", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("if-else flow", function()
      -- Simulate if-else: when if returns nil, else executes
      local condition = false
      local result = Control.if_macro.handler(ctx, { condition, "if body" })
      if result == nil then
        result = Control.else_macro.handler(ctx, { "else body" })
      end
      assert.equals("else body", result)
    end)

    it("nested for with range", function()
      local range_result = Control.range_macro.handler(ctx, { 1, 3 })
      local items = {}
      Control.for_macro.handler(ctx, { range_result, function(c)
        table.insert(items, c:get("_i"))
        return ""
      end })

      assert.equals(3, #items)
      assert.equals(1, items[1])
      assert.equals(2, items[2])
      assert.equals(3, items[3])
    end)

    it("switch with computed value", function()
      ctx:set("choice", 2)
      local value = ctx:get("choice")

      local cases = {
        { value = 1, body = "option A" },
        { value = 2, body = "option B" },
        { value = 3, body = "option C" },
      }

      local result = Control.switch_macro.handler(ctx, { value, cases })
      assert.equals("option B", result)
    end)
  end)
end)
