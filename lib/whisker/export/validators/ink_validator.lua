--- Ink Validator
-- Enhanced validation for Ink JSON exports
-- @module whisker.export.validators.ink_validator
-- @author Whisker Core Team
-- @license MIT

local InkValidator = {}

--- Validate Ink JSON export bundle
-- @param bundle table Export bundle
-- @return table Validation result {valid, errors, warnings}
function InkValidator.validate(bundle)
  local errors = {}
  local warnings = {}

  local json = bundle.content

  if not json or #json == 0 then
    table.insert(errors, {
      message = "Ink JSON content is empty",
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Basic structure checks
  if not json:match("^%s*{") then
    table.insert(errors, {
      message = "Invalid JSON: expected object at root",
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Check for required fields
  if not json:match('"inkVersion"') then
    table.insert(errors, {
      message = "Missing inkVersion field",
      severity = "error",
    })
  end

  if not json:match('"root"') then
    table.insert(errors, {
      message = "Missing root field",
      severity = "error",
    })
  end

  -- Check inkVersion value
  local version = json:match('"inkVersion"%s*:%s*(%d+)')
  if version then
    version = tonumber(version)
    if version < 19 then
      table.insert(warnings, {
        message = string.format("inkVersion %d is deprecated, recommend 20+", version),
        severity = "warning",
      })
    end
  end

  -- Check for common issues
  if json:match("function%(") then
    table.insert(warnings, {
      message = "JSON contains function-like patterns (may be invalid)",
      severity = "warning",
    })
  end

  -- Check JSON structure balance
  local open_braces = 0
  local open_brackets = 0
  for char in json:gmatch(".") do
    if char == "{" then open_braces = open_braces + 1
    elseif char == "}" then open_braces = open_braces - 1
    elseif char == "[" then open_brackets = open_brackets + 1
    elseif char == "]" then open_brackets = open_brackets - 1
    end
  end

  if open_braces ~= 0 then
    table.insert(errors, {
      message = "Unbalanced braces in JSON",
      severity = "error",
    })
  end

  if open_brackets ~= 0 then
    table.insert(errors, {
      message = "Unbalanced brackets in JSON",
      severity = "error",
    })
  end

  -- Check file size
  local size_kb = #json / 1024
  if size_kb > 10000 then
    table.insert(warnings, {
      message = string.format("Ink JSON is large (%.1f KB), may affect load time", size_kb),
      severity = "warning",
    })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

return InkValidator
