-- lib/whisker/i18n/tools/status.lua
-- Translation status report tool
-- Stage 8: Translation Workflow

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Count keys in translation data (recursive)
-- @param data table Translation data
-- @return number Key count
function M.countKeys(data)
  local count = 0

  if type(data) ~= "table" then
    return 1  -- Single value
  end

  for _, value in pairs(data) do
    if type(value) == "table" then
      count = count + M.countKeys(value)
    else
      count = count + 1
    end
  end

  return count
end

--- Calculate translation coverage
-- @param baseData table Base locale data
-- @param targetData table Target locale data
-- @return number Coverage percentage (0-100)
function M.calculateCoverage(baseData, targetData)
  local baseCount = M.countKeys(baseData)
  if baseCount == 0 then
    return 100
  end

  local matchCount = M.countMatchingKeys(baseData, targetData)
  return (matchCount / baseCount) * 100
end

--- Count matching keys between base and target
-- @param base table Base locale data
-- @param target table Target locale data
-- @param path string Current path (for recursion)
-- @return number Matching key count
function M.countMatchingKeys(base, target, path)
  if type(base) ~= "table" then
    return 0
  end

  target = target or {}
  local count = 0

  for key, value in pairs(base) do
    if type(value) == "table" then
      if type(target[key]) == "table" then
        count = count + M.countMatchingKeys(value, target[key], path)
      end
    else
      if target[key] ~= nil then
        count = count + 1
      end
    end
  end

  return count
end

--- Get locale status
-- @param baseData table Base locale data
-- @param targetData table Target locale data
-- @param localeName string Locale name
-- @return table Status info
function M.getLocaleStatus(baseData, targetData, localeName)
  local baseCount = M.countKeys(baseData)
  local targetCount = M.countKeys(targetData)
  local matchingCount = M.countMatchingKeys(baseData, targetData)
  local coverage = baseCount > 0 and (matchingCount / baseCount) * 100 or 100

  return {
    locale = localeName,
    baseKeys = baseCount,
    targetKeys = targetCount,
    matchingKeys = matchingCount,
    coverage = coverage,
    status = M.getCoverageStatus(coverage),
    complete = coverage >= 100
  }
end

--- Get status icon/text for coverage level
-- @param coverage number Coverage percentage
-- @return string Status indicator
function M.getCoverageStatus(coverage)
  if coverage >= 100 then
    return "complete"
  elseif coverage >= 80 then
    return "good"
  elseif coverage >= 50 then
    return "partial"
  else
    return "incomplete"
  end
end

--- Generate status report for multiple locales
-- @param baseLocale string Base locale name
-- @param localesData table Map of locale name to data
-- @return string Report text
function M.report(baseLocale, localesData)
  local lines = {}
  local baseData = localesData[baseLocale]

  if not baseData then
    return "Error: Base locale '" .. baseLocale .. "' not found"
  end

  local baseKeyCount = M.countKeys(baseData)

  table.insert(lines, "Translation Status Report")
  table.insert(lines, string.rep("=", 60))
  table.insert(lines, string.format("Base locale: %s (%d keys)", baseLocale, baseKeyCount))
  table.insert(lines, "")

  -- Collect and sort locales
  local locales = {}
  for locale, _ in pairs(localesData) do
    if locale ~= baseLocale then
      table.insert(locales, locale)
    end
  end
  table.sort(locales)

  if #locales == 0 then
    table.insert(lines, "No other locales found.")
  else
    for _, locale in ipairs(locales) do
      local status = M.getLocaleStatus(baseData, localesData[locale], locale)
      local icon = M.getStatusIcon(status.status)

      table.insert(lines, string.format(
        "%s %s: %d/%d keys (%.1f%%)",
        icon, locale, status.matchingKeys, status.baseKeys, status.coverage
      ))
    end
  end

  return table.concat(lines, "\n")
end

--- Get status icon for display
-- @param status string Status string
-- @return string Icon character
function M.getStatusIcon(status)
  local icons = {
    complete = "[OK]",
    good = "[!!]",
    partial = "[--]",
    incomplete = "[XX]"
  }
  return icons[status] or "[??]"
end

--- Get detailed status with missing keys
-- @param baseData table Base locale data
-- @param targetData table Target locale data
-- @param path string Current path
-- @return table Missing keys list
function M.getMissingKeys(baseData, targetData, path)
  path = path or ""
  local missing = {}

  if type(baseData) ~= "table" then
    return missing
  end

  targetData = targetData or {}

  for key, value in pairs(baseData) do
    local fullPath = path == "" and key or (path .. "." .. key)

    if type(value) == "table" then
      local nested = M.getMissingKeys(value, targetData[key], fullPath)
      for _, entry in ipairs(nested) do
        table.insert(missing, entry)
      end
    else
      if targetData[key] == nil then
        table.insert(missing, fullPath)
      end
    end
  end

  return missing
end

--- Generate detailed status with missing keys
-- @param baseData table Base locale data
-- @param targetData table Target locale data
-- @param localeName string Locale name
-- @param maxMissing number Maximum missing keys to show (default 10)
-- @return string Detailed report
function M.detailedReport(baseData, targetData, localeName, maxMissing)
  maxMissing = maxMissing or 10
  local lines = {}
  local status = M.getLocaleStatus(baseData, targetData, localeName)

  table.insert(lines, string.format("Locale: %s", localeName))
  table.insert(lines, string.format("Status: %s (%.1f%% complete)", status.status, status.coverage))
  table.insert(lines, string.format("Keys: %d/%d", status.matchingKeys, status.baseKeys))
  table.insert(lines, "")

  local missing = M.getMissingKeys(baseData, targetData)
  if #missing > 0 then
    table.insert(lines, "Missing translations:")
    for i, key in ipairs(missing) do
      if i > maxMissing then
        table.insert(lines, string.format("  ... and %d more", #missing - maxMissing))
        break
      end
      table.insert(lines, "  - " .. key)
    end
  else
    table.insert(lines, "No missing translations.")
  end

  return table.concat(lines, "\n")
end

--- Get summary statistics for all locales
-- @param baseLocale string Base locale name
-- @param localesData table Map of locale name to data
-- @return table Summary statistics
function M.getSummary(baseLocale, localesData)
  local baseData = localesData[baseLocale]
  if not baseData then
    return nil
  end

  local summary = {
    baseLocale = baseLocale,
    baseKeys = M.countKeys(baseData),
    locales = {},
    averageCoverage = 0,
    completeCount = 0,
    totalLocales = 0
  }

  local totalCoverage = 0
  for locale, data in pairs(localesData) do
    if locale ~= baseLocale then
      local status = M.getLocaleStatus(baseData, data, locale)
      summary.locales[locale] = status
      summary.totalLocales = summary.totalLocales + 1
      totalCoverage = totalCoverage + status.coverage
      if status.complete then
        summary.completeCount = summary.completeCount + 1
      end
    end
  end

  if summary.totalLocales > 0 then
    summary.averageCoverage = totalCoverage / summary.totalLocales
  end

  return summary
end

return M
