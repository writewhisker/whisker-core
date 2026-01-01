--- WLS 1.0 Semantic Validators
-- Main validator module that provides semantic validation for WLS stories.
-- @module whisker.validators

local M = {}

local error_codes = require("whisker.validators.error_codes")

-- Core validators (always run)
local structural = require("whisker.validators.structural")
local links = require("whisker.validators.links")
local variables = require("whisker.validators.variables")
local flow = require("whisker.validators.flow")

-- Extended validators (optional, loaded on demand)
local expressions = require("whisker.validators.expressions")
local quality = require("whisker.validators.quality")
local syntax = require("whisker.validators.syntax")
local assets = require("whisker.validators.assets")
local metadata = require("whisker.validators.metadata")
local scripts = require("whisker.validators.scripts")

--- Special targets for navigation
M.SPECIAL_TARGETS = {
  END = true,
  BACK = true,
  RESTART = true,
}

--- Check if a target is a special target
-- @param target string The target to check
-- @return boolean True if target is a special target
function M.is_special_target(target)
  return M.SPECIAL_TARGETS[target] == true
end

--- Create a validation issue
-- @param code string WLS error code
-- @param context table Context values for message formatting
-- @param extra table Additional fields (passageId, passageTitle, etc.)
-- @return table Validation issue
function M.create_issue(code, context, extra)
  local def = error_codes.get_error_code(code)
  if not def then
    return {
      id = 'unknown_' .. os.time(),
      code = code,
      severity = 'error',
      category = 'unknown',
      message = 'Unknown error: ' .. code,
      description = '',
      context = context,
      fixable = false,
    }
  end

  local issue = {
    id = (extra and extra.id) or (def.name .. '_' .. os.time()),
    code = code,
    severity = def.severity,
    category = def.category,
    message = error_codes.format_message(code, context),
    description = def.description,
    context = context,
    fixable = (extra and extra.fixable) or false,
  }

  -- Add extra fields
  if extra then
    for k, v in pairs(extra) do
      if k ~= 'id' and k ~= 'fixable' then
        issue[k] = v
      end
    end
  end

  return issue
end

--- Validate a story
-- @param story table The parsed story object
-- @param options table Validation options
--   - extended: boolean Run extended validators (expressions, quality, syntax, assets, metadata, scripts)
--   - quality: boolean|table Run quality validators (or pass thresholds)
--   - syntax: boolean Run syntax validators
--   - assets: boolean Run asset validators
--   - metadata: boolean Run metadata validators
--   - scripts: boolean Run script validators
--   - expressions: boolean Run expression validators
-- @return table Validation result with issues array
function M.validate(story, options)
  options = options or {}

  local issues = {}

  -- Helper to add issues
  local function add_issues(validator_issues)
    for _, issue in ipairs(validator_issues) do
      table.insert(issues, issue)
    end
  end

  -- Core validators (always run)
  add_issues(structural.validate(story))
  add_issues(links.validate(story))
  add_issues(variables.validate(story))
  add_issues(flow.validate(story))

  -- Extended validators (optional)
  local run_extended = options.extended

  if run_extended or options.expressions then
    add_issues(expressions.validate(story))
  end

  if run_extended or options.syntax then
    add_issues(syntax.validate(story))
  end

  if run_extended or options.assets then
    add_issues(assets.validate(story, options.assets_options))
  end

  if run_extended or options.metadata then
    add_issues(metadata.validate(story, options.metadata_options))
  end

  if run_extended or options.scripts then
    add_issues(scripts.validate(story, options.scripts_options))
  end

  if options.quality then
    local quality_opts = type(options.quality) == 'table' and options.quality or {}
    add_issues(quality.validate(story, quality_opts))
  end

  -- Count by severity
  local counts = {
    errors = 0,
    warnings = 0,
    info = 0,
  }

  for _, issue in ipairs(issues) do
    if issue.severity == 'error' then
      counts.errors = counts.errors + 1
    elseif issue.severity == 'warning' then
      counts.warnings = counts.warnings + 1
    else
      counts.info = counts.info + 1
    end
  end

  return {
    valid = counts.errors == 0,
    issues = issues,
    counts = counts,
  }
end

-- Re-export modules for direct access
M.error_codes = error_codes
M.structural = structural
M.links = links
M.variables = variables
M.flow = flow
M.expressions = expressions
M.quality = quality
M.syntax = syntax
M.assets = assets
M.metadata = metadata
M.scripts = scripts

return M
