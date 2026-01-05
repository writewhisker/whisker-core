--- Testing Module
-- Cross-platform test runner for Whisker stories
-- @module whisker.testing
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

-- Export submodules
M.TestRunner = require("whisker.testing.test_runner")
M.TestScenario = require("whisker.testing.test_scenario")
M.TestReporter = require("whisker.testing.test_reporter")

-- Step types
M.STEP_TYPES = {
  START = "start",
  CHOICE = "choice",
  CHECK_PASSAGE = "check_passage",
  CHECK_VARIABLE = "check_variable",
  CHECK_TEXT = "check_text",
  SET_VARIABLE = "set_variable",
  WAIT = "wait",
}

-- Operators for variable checks
M.OPERATORS = {
  EQUALS = "equals",
  NOT_EQUALS = "not_equals",
  GREATER_THAN = "greater_than",
  LESS_THAN = "less_than",
  GREATER_OR_EQUAL = "greater_or_equal",
  LESS_OR_EQUAL = "less_or_equal",
  CONTAINS = "contains",
}

-- Text match modes
M.TEXT_MATCH = {
  EXACT = "exact",
  CONTAINS = "contains",
  PATTERN = "pattern", -- Lua pattern matching
}

return M
