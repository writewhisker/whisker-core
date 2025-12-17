-- whisker/formats/ink/report.lua
-- Generates conversion reports for Ink to Whisker conversion

local Report = {}
Report.__index = Report

-- Module metadata
Report._whisker = {
  name = "ConversionReport",
  version = "1.0.0",
  description = "Generates conversion reports",
  depends = {},
  capability = "formats.ink.report"
}

-- Create a new Report instance
function Report.new()
  local instance = {
    title = "Ink Conversion Report",
    timestamp = os.time(),
    source_info = {},
    conversion_stats = {},
    validation_result = nil,
    feature_support = {}
  }
  setmetatable(instance, Report)
  return instance
end

-- Set source information
-- @param info table - Source story info (path, version, etc.)
function Report:set_source(info)
  self.source_info = info or {}
end

-- Set conversion statistics
-- @param stats table - Conversion statistics
function Report:set_stats(stats)
  self.conversion_stats = stats or {}
end

-- Set validation result
-- @param result table - Validation result from Validator
function Report:set_validation(result)
  self.validation_result = result
end

-- Add feature support info
-- @param feature string - Feature name
-- @param level string - Support level: "full", "partial", "none"
-- @param notes string|nil - Additional notes
function Report:add_feature(feature, level, notes)
  table.insert(self.feature_support, {
    feature = feature,
    level = level,
    notes = notes
  })
end

-- Generate summary table
-- @return table - Summary statistics
function Report:get_summary()
  local summary = {
    source = self.source_info,
    timestamp = self.timestamp,
    conversion = self.conversion_stats,
    validation = {
      success = self.validation_result and self.validation_result.success or false,
      errors = self.validation_result and #self.validation_result.errors or 0,
      warnings = self.validation_result and #self.validation_result.warnings or 0
    },
    features_full = 0,
    features_partial = 0,
    features_none = 0
  }

  for _, f in ipairs(self.feature_support) do
    if f.level == "full" then
      summary.features_full = summary.features_full + 1
    elseif f.level == "partial" then
      summary.features_partial = summary.features_partial + 1
    else
      summary.features_none = summary.features_none + 1
    end
  end

  return summary
end

-- Generate plain text report
-- @return string - Formatted report text
function Report:to_text()
  local lines = {}

  table.insert(lines, "=" .. string.rep("=", 50))
  table.insert(lines, self.title)
  table.insert(lines, "=" .. string.rep("=", 50))
  table.insert(lines, "")

  -- Source info
  table.insert(lines, "Source Information")
  table.insert(lines, "-" .. string.rep("-", 30))
  if self.source_info.path then
    table.insert(lines, "  Path: " .. self.source_info.path)
  end
  if self.source_info.ink_version then
    table.insert(lines, "  Ink Version: " .. self.source_info.ink_version)
  end
  table.insert(lines, "  Converted: " .. os.date("%Y-%m-%d %H:%M:%S", self.timestamp))
  table.insert(lines, "")

  -- Conversion stats
  table.insert(lines, "Conversion Statistics")
  table.insert(lines, "-" .. string.rep("-", 30))
  for key, value in pairs(self.conversion_stats) do
    table.insert(lines, string.format("  %s: %s", key, tostring(value)))
  end
  table.insert(lines, "")

  -- Validation result
  if self.validation_result then
    table.insert(lines, "Validation Result")
    table.insert(lines, "-" .. string.rep("-", 30))
    table.insert(lines, "  Status: " .. (self.validation_result.success and "PASSED" or "FAILED"))
    table.insert(lines, string.format("  Errors: %d", #self.validation_result.errors))
    table.insert(lines, string.format("  Warnings: %d", #self.validation_result.warnings))
    table.insert(lines, "")

    -- List errors
    if #self.validation_result.errors > 0 then
      table.insert(lines, "  Errors:")
      for i, err in ipairs(self.validation_result.errors) do
        table.insert(lines, string.format("    %d. %s", i, err.message))
      end
      table.insert(lines, "")
    end

    -- List warnings (first 10)
    if #self.validation_result.warnings > 0 then
      table.insert(lines, "  Warnings:")
      local max_warnings = math.min(10, #self.validation_result.warnings)
      for i = 1, max_warnings do
        local warn = self.validation_result.warnings[i]
        table.insert(lines, string.format("    %d. %s", i, warn.message))
      end
      if #self.validation_result.warnings > 10 then
        table.insert(lines, string.format("    ... and %d more", #self.validation_result.warnings - 10))
      end
      table.insert(lines, "")
    end
  end

  -- Feature support
  if #self.feature_support > 0 then
    table.insert(lines, "Feature Support")
    table.insert(lines, "-" .. string.rep("-", 30))
    for _, f in ipairs(self.feature_support) do
      local level_str = f.level == "full" and "[FULL]" or (f.level == "partial" and "[PARTIAL]" or "[NONE]")
      table.insert(lines, string.format("  %s %s%s", level_str, f.feature, f.notes and (" - " .. f.notes) or ""))
    end
  end

  return table.concat(lines, "\n")
end

-- Generate JSON-serializable report
-- @return table - Report data suitable for JSON encoding
function Report:to_table()
  return {
    title = self.title,
    timestamp = self.timestamp,
    source = self.source_info,
    conversion = self.conversion_stats,
    validation = self.validation_result,
    features = self.feature_support,
    summary = self:get_summary()
  }
end

-- Create a report from conversion result
-- @param source_info table - Source information
-- @param conversion_stats table - Conversion statistics
-- @param validation_result table - Validation result
-- @return Report - New report instance
function Report.from_conversion(source_info, conversion_stats, validation_result)
  local report = Report.new()
  report:set_source(source_info)
  report:set_stats(conversion_stats)
  report:set_validation(validation_result)

  -- Add default feature support info
  report:add_feature("Knots", "full")
  report:add_feature("Stitches", "full")
  report:add_feature("Choices", "full")
  report:add_feature("Variables", "full")
  report:add_feature("Logic", "full")
  report:add_feature("Tunnels", "full")
  report:add_feature("Threads", "partial", "Basic gathering supported")
  report:add_feature("Tags", "full")
  report:add_feature("Gathers", "full")

  return report
end

return Report
