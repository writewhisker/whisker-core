-- lib/whisker/i18n/tools/validate.lua
-- Translation validation tool
-- Stage 8: Translation Workflow

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Validate translation data against base locale data
-- @param baseData table Base locale data (hierarchical)
-- @param targetData table Target locale data (hierarchical)
-- @return table Validation issues
function M.compare(baseData, targetData)
  local issues = {}

  -- Find missing keys
  M.findMissing(baseData, targetData, "", issues)

  -- Find unused keys
  M.findUnused(baseData, targetData, "", issues)

  -- Check variable consistency
  M.checkVariables(baseData, targetData, "", issues)

  return issues
end

--- Find missing keys in target
-- @param base table Base locale data
-- @param target table Target locale data
-- @param path string Current path
-- @param issues table Issues accumulator
function M.findMissing(base, target, path, issues)
  if type(base) ~= "table" then
    return
  end

  target = target or {}

  for key, value in pairs(base) do
    local fullPath = path == "" and key or (path .. "." .. key)

    if type(value) == "table" then
      if target[key] == nil then
        table.insert(issues, {
          type = "missing_section",
          path = fullPath,
          severity = "error",
          message = "Missing section: " .. fullPath
        })
      elseif type(target[key]) ~= "table" then
        table.insert(issues, {
          type = "type_mismatch",
          path = fullPath,
          severity = "error",
          message = "Expected table, got " .. type(target[key])
        })
      else
        M.findMissing(value, target[key], fullPath, issues)
      end
    else
      if target[key] == nil then
        table.insert(issues, {
          type = "missing_key",
          path = fullPath,
          severity = "error",
          message = "Missing translation key: " .. fullPath
        })
      end
    end
  end
end

--- Find unused keys in target
-- @param base table Base locale data
-- @param target table Target locale data
-- @param path string Current path
-- @param issues table Issues accumulator
function M.findUnused(base, target, path, issues)
  if type(target) ~= "table" then
    return
  end

  base = base or {}

  for key, value in pairs(target) do
    local fullPath = path == "" and key or (path .. "." .. key)

    if type(value) == "table" then
      if base[key] == nil then
        table.insert(issues, {
          type = "unused_section",
          path = fullPath,
          severity = "warning",
          message = "Unused section: " .. fullPath
        })
      elseif type(base[key]) == "table" then
        M.findUnused(base[key], value, fullPath, issues)
      end
    else
      if base[key] == nil then
        table.insert(issues, {
          type = "unused_key",
          path = fullPath,
          severity = "warning",
          message = "Unused translation key: " .. fullPath
        })
      end
    end
  end
end

--- Check variable consistency between base and target
-- @param base table Base locale data
-- @param target table Target locale data
-- @param path string Current path
-- @param issues table Issues accumulator
function M.checkVariables(base, target, path, issues)
  if type(base) ~= "table" then
    return
  end

  target = target or {}

  for key, value in pairs(base) do
    local fullPath = path == "" and key or (path .. "." .. key)

    if type(value) == "string" and type(target[key]) == "string" then
      local baseVars = M.extractVariables(value)
      local targetVars = M.extractVariables(target[key])

      -- Check for missing variables
      for _, var in ipairs(baseVars) do
        if not M.hasVariable(targetVars, var) then
          table.insert(issues, {
            type = "missing_variable",
            path = fullPath,
            variable = var,
            severity = "error",
            message = "Missing variable {" .. var .. "} in: " .. fullPath
          })
        end
      end

      -- Check for extra variables
      for _, var in ipairs(targetVars) do
        if not M.hasVariable(baseVars, var) then
          table.insert(issues, {
            type = "extra_variable",
            path = fullPath,
            variable = var,
            severity = "warning",
            message = "Extra variable {" .. var .. "} in: " .. fullPath
          })
        end
      end
    elseif type(value) == "table" and type(target[key]) == "table" then
      M.checkVariables(value, target[key], fullPath, issues)
    end
  end
end

--- Extract variables from string
-- @param str string String with {var} placeholders
-- @return table Array of variable names
function M.extractVariables(str)
  local vars = {}
  for var in str:gmatch("{(%w+)}") do
    table.insert(vars, var)
  end
  return vars
end

--- Check if variable exists in list
-- @param vars table Variable list
-- @param var string Variable to find
-- @return boolean
function M.hasVariable(vars, var)
  for _, v in ipairs(vars) do
    if v == var then
      return true
    end
  end
  return false
end

--- Count issues by severity
-- @param issues table Validation issues
-- @return number, number Error count, warning count
function M.countIssues(issues)
  local errors = 0
  local warnings = 0

  for _, issue in ipairs(issues) do
    if issue.severity == "error" then
      errors = errors + 1
    elseif issue.severity == "warning" then
      warnings = warnings + 1
    end
  end

  return errors, warnings
end

--- Generate validation report
-- @param issues table Validation issues
-- @param options table Report options (optional)
-- @return string Report text
function M.report(issues, options)
  options = options or {}
  local lines = {}

  table.insert(lines, "Translation Validation Report")
  table.insert(lines, string.rep("=", 40))
  table.insert(lines, "")

  local errors, warnings = M.countIssues(issues)

  if #issues == 0 then
    table.insert(lines, "No issues found.")
  else
    -- Group by type
    local byType = {}
    for _, issue in ipairs(issues) do
      byType[issue.type] = byType[issue.type] or {}
      table.insert(byType[issue.type], issue)
    end

    -- Report by type
    local typeOrder = {
      "missing_section", "missing_key", "missing_variable",
      "type_mismatch", "unused_section", "unused_key", "extra_variable"
    }

    for _, issueType in ipairs(typeOrder) do
      local typeIssues = byType[issueType]
      if typeIssues and #typeIssues > 0 then
        local severity = typeIssues[1].severity:upper()
        table.insert(lines, string.format("[%s] %s (%d)", severity, issueType, #typeIssues))

        if not options.summary then
          for _, issue in ipairs(typeIssues) do
            local msg = "  - " .. issue.path
            if issue.variable then
              msg = msg .. " (variable: " .. issue.variable .. ")"
            end
            table.insert(lines, msg)
          end
        end

        table.insert(lines, "")
      end
    end
  end

  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("Total: %d errors, %d warnings", errors, warnings))

  return table.concat(lines, "\n")
end

--- Validate source keys against translation data
-- @param sourceKeys table Extracted keys from source
-- @param localeData table Translation data (flat or hierarchical)
-- @param flatten boolean Whether to flatten locale data first
-- @return table Issues
function M.validateSourceKeys(sourceKeys, localeData, flatten)
  local issues = {}

  -- Build flat lookup
  local flatData = {}
  if flatten then
    flatData = M.flattenData(localeData)
  else
    flatData = localeData
  end

  for _, entry in ipairs(sourceKeys) do
    if not flatData[entry.key] then
      table.insert(issues, {
        type = "undefined_key",
        path = entry.key,
        file = entry.file,
        line = entry.line,
        severity = "error",
        message = "Undefined translation key in source: " .. entry.key
      })
    end
  end

  return issues
end

--- Flatten hierarchical data
-- @param data table Hierarchical data
-- @param prefix string Current path prefix
-- @return table Flat key-value map
function M.flattenData(data, prefix)
  local result = {}
  prefix = prefix or ""

  for key, value in pairs(data) do
    local fullKey = prefix == "" and key or (prefix .. "." .. key)

    if type(value) == "table" then
      local nested = M.flattenData(value, fullKey)
      for k, v in pairs(nested) do
        result[k] = v
      end
    else
      result[fullKey] = value
    end
  end

  return result
end

--- Check plural completeness
-- @param data table Translation data
-- @param categories table Expected plural categories
-- @param path string Current path
-- @param issues table Issues accumulator
function M.checkPluralCompleteness(data, categories, path, issues)
  categories = categories or { "one", "other" }
  path = path or ""

  for key, value in pairs(data) do
    local fullPath = path == "" and key or (path .. "." .. key)

    if type(value) == "table" then
      -- Check if this looks like a plural (has 'one' or 'other')
      local isPluralNode = value.one ~= nil or value.other ~= nil or
                          value.zero ~= nil or value.few ~= nil or
                          value.many ~= nil or value.two ~= nil

      if isPluralNode then
        -- Check that required categories exist
        for _, cat in ipairs(categories) do
          if value[cat] == nil then
            table.insert(issues, {
              type = "missing_plural",
              path = fullPath .. "." .. cat,
              category = cat,
              severity = "warning",
              message = "Missing plural category: " .. cat .. " in " .. fullPath
            })
          end
        end
      else
        -- Recurse into nested sections
        M.checkPluralCompleteness(value, categories, fullPath, issues)
      end
    end
  end
end

return M
