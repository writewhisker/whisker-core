--- IConditionEvaluator Interface
-- Interface for condition evaluation services
-- @module whisker.interfaces.condition
-- @author Whisker Core Team
-- @license MIT

local IConditionEvaluator = {}

--- Evaluate a condition expression
-- @param condition string The condition expression to evaluate
-- @param context table The context containing variables for evaluation
-- @return boolean The result of the condition evaluation
-- @return string|nil Error message if evaluation failed
function IConditionEvaluator:evaluate(condition, context)
  error("IConditionEvaluator:evaluate must be implemented")
end

--- Register a custom operator
-- @param name string The operator name
-- @param handler function The operator handler function
function IConditionEvaluator:register_operator(name, handler)
  error("IConditionEvaluator:register_operator must be implemented")
end

--- Get all registered operators
-- @return table Map of operator names to handlers
function IConditionEvaluator:get_operators()
  error("IConditionEvaluator:get_operators must be implemented")
end

--- Parse a condition into an AST
-- @param condition string The condition to parse
-- @return table The parsed AST
-- @return string|nil Error message if parsing failed
function IConditionEvaluator:parse(condition)
  error("IConditionEvaluator:parse must be implemented")
end

--- Validate a condition without evaluating
-- @param condition string The condition to validate
-- @return boolean True if the condition is valid
-- @return string|nil Error message if validation failed
function IConditionEvaluator:validate(condition)
  error("IConditionEvaluator:validate must be implemented")
end

return IConditionEvaluator
