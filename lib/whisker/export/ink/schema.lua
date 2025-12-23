--- Ink Schema Validator
-- Validates Ink JSON structure
-- @module whisker.export.ink.schema
-- @author Whisker Core Team
-- @license MIT

local InkSchema = {}

--- Validate Ink JSON structure
-- @param ink_data table Parsed Ink JSON
-- @return table Array of validation errors
function InkSchema.validate(ink_data)
  local errors = {}

  if type(ink_data) ~= "table" then
    table.insert(errors, {
      message = "Ink data must be a table",
      severity = "error",
    })
    return errors
  end

  -- Check required fields
  if ink_data.inkVersion == nil then
    table.insert(errors, {
      message = "Missing inkVersion field",
      severity = "error",
    })
  end

  if ink_data.root == nil then
    table.insert(errors, {
      message = "Missing root field",
      severity = "error",
    })
  end

  -- Validate inkVersion
  if ink_data.inkVersion ~= nil then
    if type(ink_data.inkVersion) ~= "number" then
      table.insert(errors, {
        message = "inkVersion must be a number",
        severity = "error",
      })
    elseif ink_data.inkVersion < 19 then
      table.insert(errors, {
        message = "inkVersion " .. ink_data.inkVersion .. " is deprecated, consider using 20+",
        severity = "warning",
      })
    end
  end

  -- Validate root structure
  if ink_data.root ~= nil then
    if type(ink_data.root) ~= "table" then
      table.insert(errors, {
        message = "root must be a table (array)",
        severity = "error",
      })
    end
  end

  -- Check for at least one content element (besides root)
  local has_content = false
  for key, _ in pairs(ink_data) do
    if key ~= "inkVersion" and key ~= "root" and key ~= "listDefs" then
      has_content = true
      break
    end
  end

  if not has_content and ink_data.root and #ink_data.root == 0 then
    table.insert(errors, {
      message = "Story has no content",
      severity = "warning",
    })
  end

  return errors
end

--- Check if ink JSON is valid
-- @param ink_data table Parsed Ink JSON
-- @return boolean True if valid
function InkSchema.is_valid(ink_data)
  local errors = InkSchema.validate(ink_data)

  for _, err in ipairs(errors) do
    if err.severity == "error" then
      return false
    end
  end

  return true
end

return InkSchema
