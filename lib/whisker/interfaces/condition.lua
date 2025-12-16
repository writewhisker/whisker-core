-- whisker/interfaces/condition.lua
-- IConditionEvaluator interface definition
-- Condition evaluators must implement this interface

local IConditionEvaluator = {
  _name = "IConditionEvaluator",
  _description = "Evaluates conditions for choice availability and logic",
  _required = {"evaluate"},
  _optional = {"register_operator", "register_function"},

  -- Evaluate a condition expression
  -- @param condition string|table - Condition to evaluate
  -- @param context table - Context with variables and state
  -- @return boolean - Result of condition evaluation
  evaluate = "function(self, condition, context) -> boolean",

  -- Register a custom operator (optional)
  -- @param name string - Operator name
  -- @param fn function - Operator implementation
  register_operator = "function(self, name, fn)",
}

return IConditionEvaluator
