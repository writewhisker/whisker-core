--- WLS 2.0 Module
-- Re-exports all WLS 2.0 components.
--
-- @module whisker.wls2
-- @author Whisker Team
-- @license MIT

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

-- Import all components
M.thread_scheduler = require("whisker.wls2.thread_scheduler")
M.timed_content = require("whisker.wls2.timed_content")
M.text_effects = require("whisker.wls2.text_effects")
M.external_functions = require("whisker.wls2.external_functions")
M.integration = require("whisker.wls2.wls2_integration")

-- Re-export main integration constructor
M.new = M.integration.new

-- Re-export constants
M.THREAD_STATUS = M.thread_scheduler.STATUS
M.EFFECT_TYPES = M.text_effects.EFFECTS

-- Convenience constructors
function M.new_scheduler(options)
  return M.thread_scheduler.new(options)
end

function M.new_timers()
  return M.timed_content.new()
end

function M.new_effects()
  return M.text_effects.new()
end

function M.new_externals()
  return M.external_functions.new()
end

return M
