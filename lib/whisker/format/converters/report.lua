-- Conversion Report Module
-- Tracks conversion quality, approximations, and lost features

local M = {}
M._dependencies = {"json_codec"}

-- ConversionReport class
local ConversionReport = {}
ConversionReport.__index = ConversionReport

--- Create a new ConversionReport instance
-- @param source_format string The source format (e.g., "harlowe")
-- @param target_format string The target format (e.g., "chapbook")
-- @return ConversionReport instance
function M.new(source_format, target_format)
  local self = setmetatable({}, ConversionReport)
  self.source_format = source_format or "unknown"
  self.target_format = target_format or "unknown"
  self.entries = {}
  self.passage_count = 0
  self.created_at = os.time()
  return self
end

--- Entry types
M.ENTRY_TYPES = {
  CONVERTED = "converted",
  APPROXIMATED = "approximated",
  LOST = "lost"
}

--- Add a converted feature to the report
-- @param feature string The feature name (e.g., "dropdown")
-- @param passage string The passage name where the feature was found
-- @param details table Optional details table
function ConversionReport:add_converted(feature, passage, details)
  details = details or {}
  table.insert(self.entries, {
    type = M.ENTRY_TYPES.CONVERTED,
    feature = feature,
    passage = passage,
    line = details.line,
    original = details.original,
    result = details.result,
    timestamp = os.time()
  })
end

--- Add an approximated feature to the report
-- @param feature string The feature name
-- @param passage string The passage name
-- @param original string The original code/text
-- @param approximation string The approximated result
-- @param details table Optional additional details
function ConversionReport:add_approximated(feature, passage, original, approximation, details)
  details = details or {}
  table.insert(self.entries, {
    type = M.ENTRY_TYPES.APPROXIMATED,
    feature = feature,
    passage = passage,
    line = details.line,
    original = original,
    result = approximation,
    severity = details.severity or "warning",
    notes = details.notes,
    timestamp = os.time()
  })
end

--- Add a lost feature to the report
-- @param feature string The feature name
-- @param passage string The passage name
-- @param reason string Why the feature was lost
-- @param details table Optional additional details
function ConversionReport:add_lost(feature, passage, reason, details)
  details = details or {}
  table.insert(self.entries, {
    type = M.ENTRY_TYPES.LOST,
    feature = feature,
    passage = passage,
    line = details.line,
    original = details.original,
    reason = reason,
    severity = details.severity or "warning",
    suggestion = details.suggestion,
    timestamp = os.time()
  })
end

--- Set the passage count for the conversion
-- @param count number The number of passages processed
function ConversionReport:set_passage_count(count)
  self.passage_count = count
end

--- Get a summary of the conversion
-- @return table Summary with converted, approximated, and lost counts
function ConversionReport:get_summary()
  local summary = {
    converted = 0,
    approximated = 0,
    lost = 0,
    total_entries = #self.entries,
    passage_count = self.passage_count,
    source_format = self.source_format,
    target_format = self.target_format
  }

  for _, entry in ipairs(self.entries) do
    if entry.type == M.ENTRY_TYPES.CONVERTED then
      summary.converted = summary.converted + 1
    elseif entry.type == M.ENTRY_TYPES.APPROXIMATED then
      summary.approximated = summary.approximated + 1
    elseif entry.type == M.ENTRY_TYPES.LOST then
      summary.lost = summary.lost + 1
    end
  end

  return summary
end

--- Get all entries, optionally filtered by type
-- @param filter_type string Optional entry type to filter by
-- @return table Array of entry details
function ConversionReport:get_details(filter_type)
  if not filter_type then
    return self.entries
  end

  local filtered = {}
  for _, entry in ipairs(self.entries) do
    if entry.type == filter_type then
      table.insert(filtered, entry)
    end
  end
  return filtered
end

--- Get entries grouped by passage
-- @return table Entries grouped by passage name
function ConversionReport:get_by_passage()
  local by_passage = {}

  for _, entry in ipairs(self.entries) do
    local passage = entry.passage or "unknown"
    if not by_passage[passage] then
      by_passage[passage] = {}
    end
    table.insert(by_passage[passage], entry)
  end

  return by_passage
end

--- Get entries grouped by feature
-- @return table Entries grouped by feature name
function ConversionReport:get_by_feature()
  local by_feature = {}

  for _, entry in ipairs(self.entries) do
    local feature = entry.feature or "unknown"
    if not by_feature[feature] then
      by_feature[feature] = {}
    end
    table.insert(by_feature[feature], entry)
  end

  return by_feature
end

--- Calculate quality score (0-100) based on conversion fidelity
-- @return number Quality score from 0 to 100
function ConversionReport:get_quality_score()
  local summary = self:get_summary()
  local total = summary.total_entries

  if total == 0 then
    return 100 -- Perfect score for empty (no special features to convert)
  end

  -- Weight: converted = 1.0, approximated = 0.5, lost = 0.0
  local weighted_sum = summary.converted * 1.0 +
                       summary.approximated * 0.5 +
                       summary.lost * 0.0

  local max_possible = total * 1.0
  local score = (weighted_sum / max_possible) * 100

  return math.floor(score + 0.5) -- Round to nearest integer
end

--- Convert report to JSON string
-- @param pretty boolean Whether to format with indentation
-- @return string JSON representation
function ConversionReport:to_json(pretty)
  local data = {
    source_format = self.source_format,
    target_format = self.target_format,
    passage_count = self.passage_count,
    created_at = self.created_at,
    summary = self:get_summary(),
    quality_score = self:get_quality_score(),
    entries = self.entries
  }

  -- Use simple JSON encoding (assumes json module available)
  local json = require("whisker.utils.json")
  if pretty then
    return json.encode(data, 1)
  else
    return json.encode(data)
  end
end

--- Create report from JSON string
-- @param json_string string The JSON to parse
-- @return ConversionReport instance
function M.from_json(json_string)
  local json = require("whisker.utils.json")
  local data, err = json.decode(json_string)

  if not data then
    return nil, "Failed to parse JSON: " .. (err or "unknown error")
  end

  local report = M.new(data.source_format, data.target_format)
  report.passage_count = data.passage_count or 0
  report.created_at = data.created_at or os.time()
  report.entries = data.entries or {}

  return report
end

--- Merge another report into this one
-- @param other ConversionReport The report to merge
function ConversionReport:merge(other)
  for _, entry in ipairs(other.entries) do
    table.insert(self.entries, entry)
  end
  self.passage_count = self.passage_count + other.passage_count
end

--- Get a human-readable text summary
-- @return string Text summary of the report
function ConversionReport:to_text()
  local lines = {}
  local summary = self:get_summary()

  table.insert(lines, string.format(
    "Conversion Report: %s -> %s",
    self.source_format, self.target_format
  ))
  table.insert(lines, string.rep("-", 40))
  table.insert(lines, string.format("Passages processed: %d", self.passage_count))
  table.insert(lines, string.format("Features converted: %d", summary.converted))
  table.insert(lines, string.format("Features approximated: %d", summary.approximated))
  table.insert(lines, string.format("Features lost: %d", summary.lost))
  table.insert(lines, string.format("Quality score: %d%%", self:get_quality_score()))

  -- Add details for approximated and lost features
  if summary.approximated > 0 or summary.lost > 0 then
    table.insert(lines, "")
    table.insert(lines, "Details:")

    for _, entry in ipairs(self.entries) do
      if entry.type == M.ENTRY_TYPES.APPROXIMATED then
        table.insert(lines, string.format(
          "  [APPROX] %s in %s%s",
          entry.feature,
          entry.passage,
          entry.line and (":" .. entry.line) or ""
        ))
        if entry.original and entry.result then
          table.insert(lines, string.format(
            "           %s -> %s",
            entry.original:sub(1, 30),
            entry.result:sub(1, 30)
          ))
        end
      elseif entry.type == M.ENTRY_TYPES.LOST then
        table.insert(lines, string.format(
          "  [LOST] %s in %s%s - %s",
          entry.feature,
          entry.passage,
          entry.line and (":" .. entry.line) or "",
          entry.reason or "no reason given"
        ))
      end
    end
  end

  return table.concat(lines, "\n")
end

--- Check if the conversion has any issues (approximations or losses)
-- @return boolean True if there are any non-converted features
function ConversionReport:has_issues()
  for _, entry in ipairs(self.entries) do
    if entry.type ~= M.ENTRY_TYPES.CONVERTED then
      return true
    end
  end
  return false
end

--- Get the most problematic features (by count of issues)
-- @param limit number Maximum number of features to return
-- @return table Array of {feature, count, issues} sorted by count
function ConversionReport:get_problematic_features(limit)
  limit = limit or 5
  local by_feature = {}

  for _, entry in ipairs(self.entries) do
    if entry.type ~= M.ENTRY_TYPES.CONVERTED then
      local feature = entry.feature
      if not by_feature[feature] then
        by_feature[feature] = {feature = feature, count = 0, issues = {}}
      end
      by_feature[feature].count = by_feature[feature].count + 1
      table.insert(by_feature[feature].issues, entry)
    end
  end

  -- Convert to array and sort
  local result = {}
  for _, data in pairs(by_feature) do
    table.insert(result, data)
  end

  table.sort(result, function(a, b)
    return a.count > b.count
  end)

  -- Limit results
  local limited = {}
  for i = 1, math.min(limit, #result) do
    table.insert(limited, result[i])
  end

  return limited
end

return M
