--- Parity Reporter
-- Generates detailed parity reports comparing Lua and TypeScript execution
-- @module whisker.testing.parity_reporter
-- @author Whisker Core Team
-- @license MIT

local ParityReporter = {}
ParityReporter.__index = ParityReporter
ParityReporter._dependencies = {}

--- Report formats
local FORMATS = {
  TEXT = "text",
  JSON = "json",
  MARKDOWN = "markdown",
  HTML = "html",
}

--- Create a new parity reporter
-- @param options table Reporter options
-- @return ParityReporter Reporter instance
function ParityReporter.new(options)
  options = options or {}
  local self = setmetatable({}, ParityReporter)

  self._format = options.format or FORMATS.TEXT
  self._verbose = options.verbose or false
  self._colors = options.colors ~= false
  self._output = options.output
  self._include_details = options.include_details ~= false

  return self
end

--- ANSI color codes
local COLORS = {
  reset = "\27[0m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  cyan = "\27[36m",
  gray = "\27[90m",
  bold = "\27[1m",
}

--- Apply color if enabled
local function colorize(self, text, color)
  if self._colors and COLORS[color] then
    return COLORS[color] .. text .. COLORS.reset
  end
  return text
end

--- Format parity score with color
local function format_score(self, score)
  local color
  if score >= 100 then
    color = "green"
  elseif score >= 90 then
    color = "yellow"
  else
    color = "red"
  end
  return colorize(self, string.format("%.1f%%", score), color)
end

--- Format a single difference
local function format_difference(self, diff, indent)
  indent = indent or "    "
  local lines = {}

  table.insert(lines, indent .. colorize(self, "Path: ", "gray") .. diff.path)

  if diff.type == "mismatch" then
    table.insert(lines, indent .. colorize(self, "Lua:  ", "cyan") .. tostring(diff.lua_value))
    table.insert(lines, indent .. colorize(self, "Ref:  ", "yellow") .. tostring(diff.reference))
  elseif diff.type == "missing_lua" then
    table.insert(lines, indent .. colorize(self, "Missing in Lua, Reference: ", "red") .. tostring(diff.reference))
  elseif diff.type == "missing_ref" then
    table.insert(lines, indent .. colorize(self, "Missing in Reference, Lua: ", "yellow") .. tostring(diff.lua_value))
  elseif diff.type == "type_mismatch" then
    table.insert(lines, indent .. colorize(self, "Type mismatch - Lua: ", "red") ..
      diff.lua_type .. ", Ref: " .. diff.reference_type)
  end

  if diff.message then
    table.insert(lines, indent .. colorize(self, "Message: ", "gray") .. diff.message)
  end

  return table.concat(lines, "\n")
end

--- Format comparison for a single scenario
local function format_comparison_text(self, comparison)
  local lines = {}

  local status = comparison.passed and "MATCH" or "DIFF"
  local status_color = comparison.passed and "green" or "red"

  table.insert(lines, string.format("  %s %s (%s)",
    colorize(self, status, status_color),
    comparison.scenario_name or comparison.scenario_id,
    comparison.scenario_id))

  if not comparison.passed then
    -- Show pass/fail status for each platform
    local lua_status = comparison.lua_passed == nil and "N/A" or
      (comparison.lua_passed and "PASS" or "FAIL")
    local ref_status = comparison.ref_passed == nil and "N/A" or
      (comparison.ref_passed and "PASS" or "FAIL")

    table.insert(lines, string.format("    Lua: %s | Reference: %s",
      colorize(self, lua_status, comparison.lua_passed and "green" or "red"),
      colorize(self, ref_status, comparison.ref_passed and "green" or "red")))

    if self._verbose and comparison.differences then
      table.insert(lines, "    Differences:")
      for i, diff in ipairs(comparison.differences) do
        if i <= 5 or self._include_details then
          table.insert(lines, format_difference(self, diff, "      "))
        end
      end
      if #comparison.differences > 5 and not self._include_details then
        table.insert(lines, string.format("      ... and %d more differences",
          #comparison.differences - 5))
      end
    end
  end

  return table.concat(lines, "\n")
end

--- Format summary as text
-- @param summary table Parity summary from ParityRunner
-- @return string Formatted text report
function ParityReporter:format_text(summary)
  local lines = {}

  -- Header
  table.insert(lines, "")
  table.insert(lines, colorize(self, string.rep("=", 60), "bold"))
  table.insert(lines, colorize(self, "  PARITY REPORT", "bold"))
  table.insert(lines, colorize(self, string.rep("=", 60), "bold"))
  table.insert(lines, "")

  -- Summary statistics
  table.insert(lines, colorize(self, "Summary:", "bold"))
  table.insert(lines, string.format("  Parity Score: %s", format_score(self, summary.parity_score)))
  table.insert(lines, string.format("  Total Scenarios: %d", summary.total))
  table.insert(lines, string.format("  Matched: %s",
    colorize(self, tostring(summary.matched), "green")))
  table.insert(lines, string.format("  Mismatched: %s",
    colorize(self, tostring(summary.mismatched), summary.mismatched > 0 and "red" or "green")))
  table.insert(lines, string.format("  Missing Reference: %s",
    colorize(self, tostring(summary.missing_ref), summary.missing_ref > 0 and "yellow" or "green")))
  table.insert(lines, string.format("  Missing Lua: %s",
    colorize(self, tostring(summary.missing_lua), summary.missing_lua > 0 and "yellow" or "green")))
  table.insert(lines, "")

  -- Detailed results
  if summary.comparisons and #summary.comparisons > 0 then
    table.insert(lines, colorize(self, "Scenario Results:", "bold"))

    -- Group by status
    local matched = {}
    local mismatched = {}

    for _, comp in ipairs(summary.comparisons) do
      if comp.passed then
        table.insert(matched, comp)
      else
        table.insert(mismatched, comp)
      end
    end

    -- Show mismatched first
    if #mismatched > 0 then
      table.insert(lines, colorize(self, "\n  Mismatched:", "red"))
      for _, comp in ipairs(mismatched) do
        table.insert(lines, format_comparison_text(self, comp))
      end
    end

    -- Show matched (condensed unless verbose)
    if #matched > 0 then
      table.insert(lines, colorize(self, "\n  Matched:", "green"))
      if self._verbose then
        for _, comp in ipairs(matched) do
          table.insert(lines, format_comparison_text(self, comp))
        end
      else
        table.insert(lines, string.format("    %d scenarios matched perfectly",
          #matched))
      end
    end
  end

  -- Final status
  table.insert(lines, "")
  table.insert(lines, string.rep("-", 60))
  local final_status = summary.passed and "PARITY CHECK PASSED" or "PARITY CHECK FAILED"
  local final_color = summary.passed and "green" or "red"
  table.insert(lines, colorize(self, "  " .. final_status, final_color))
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

--- Format summary as JSON
-- @param summary table Parity summary
-- @return string JSON string
function ParityReporter:format_json(summary)
  local json = require("whisker.utils.json")
  return json.encode(summary, 0)  -- 0 = starting indent level for pretty output
end

--- Format summary as Markdown
-- @param summary table Parity summary
-- @return string Markdown report
function ParityReporter:format_markdown(summary)
  local lines = {}

  table.insert(lines, "# Parity Report")
  table.insert(lines, "")
  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, string.format("| Metric | Value |"))
  table.insert(lines, "|--------|-------|")
  table.insert(lines, string.format("| Parity Score | %.1f%% |", summary.parity_score))
  table.insert(lines, string.format("| Total Scenarios | %d |", summary.total))
  table.insert(lines, string.format("| Matched | %d |", summary.matched))
  table.insert(lines, string.format("| Mismatched | %d |", summary.mismatched))
  table.insert(lines, string.format("| Missing Reference | %d |", summary.missing_ref))
  table.insert(lines, string.format("| Missing Lua | %d |", summary.missing_lua))
  table.insert(lines, "")

  -- Status badge
  if summary.passed then
    table.insert(lines, "**Status:** :white_check_mark: PASSED")
  else
    table.insert(lines, "**Status:** :x: FAILED")
  end
  table.insert(lines, "")

  -- Detailed results
  if summary.comparisons and #summary.comparisons > 0 then
    table.insert(lines, "## Scenario Results")
    table.insert(lines, "")

    -- Mismatched scenarios
    local has_mismatched = false
    for _, comp in ipairs(summary.comparisons) do
      if not comp.passed then
        if not has_mismatched then
          table.insert(lines, "### Mismatched Scenarios")
          table.insert(lines, "")
          has_mismatched = true
        end

        table.insert(lines, string.format("#### %s", comp.scenario_name or comp.scenario_id))
        table.insert(lines, "")
        table.insert(lines, string.format("- **Scenario ID:** `%s`", comp.scenario_id))
        table.insert(lines, string.format("- **Lua Result:** %s",
          comp.lua_passed == nil and "N/A" or (comp.lua_passed and "PASS" or "FAIL")))
        table.insert(lines, string.format("- **Reference Result:** %s",
          comp.ref_passed == nil and "N/A" or (comp.ref_passed and "PASS" or "FAIL")))
        table.insert(lines, string.format("- **Differences:** %d", comp.difference_count))

        if comp.differences and #comp.differences > 0 and self._include_details then
          table.insert(lines, "")
          table.insert(lines, "<details>")
          table.insert(lines, "<summary>View Differences</summary>")
          table.insert(lines, "")
          table.insert(lines, "```")
          for _, diff in ipairs(comp.differences) do
            table.insert(lines, string.format("Path: %s", diff.path))
            if diff.lua_value ~= nil then
              table.insert(lines, string.format("  Lua: %s", tostring(diff.lua_value)))
            end
            if diff.reference ~= nil then
              table.insert(lines, string.format("  Ref: %s", tostring(diff.reference)))
            end
            table.insert(lines, "")
          end
          table.insert(lines, "```")
          table.insert(lines, "</details>")
        end
        table.insert(lines, "")
      end
    end

    -- Matched scenarios (summary only)
    local matched_count = summary.matched
    if matched_count > 0 then
      table.insert(lines, "### Matched Scenarios")
      table.insert(lines, "")
      table.insert(lines, string.format("%d scenarios matched perfectly.", matched_count))
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

--- Format summary as HTML
-- @param summary table Parity summary
-- @return string HTML report
function ParityReporter:format_html(summary)
  local lines = {}

  table.insert(lines, "<!DOCTYPE html>")
  table.insert(lines, "<html>")
  table.insert(lines, "<head>")
  table.insert(lines, "  <title>Parity Report</title>")
  table.insert(lines, "  <style>")
  table.insert(lines, "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }")
  table.insert(lines, "    h1 { color: #333; }")
  table.insert(lines, "    .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }")
  table.insert(lines, "    .score { font-size: 2em; font-weight: bold; }")
  table.insert(lines, "    .score.pass { color: #22c55e; }")
  table.insert(lines, "    .score.warn { color: #eab308; }")
  table.insert(lines, "    .score.fail { color: #ef4444; }")
  table.insert(lines, "    .status { padding: 10px 20px; border-radius: 4px; display: inline-block; font-weight: bold; }")
  table.insert(lines, "    .status.pass { background: #dcfce7; color: #166534; }")
  table.insert(lines, "    .status.fail { background: #fee2e2; color: #991b1b; }")
  table.insert(lines, "    table { width: 100%; border-collapse: collapse; margin: 20px 0; }")
  table.insert(lines, "    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }")
  table.insert(lines, "    th { background: #f5f5f5; }")
  table.insert(lines, "    .match { color: #22c55e; }")
  table.insert(lines, "    .mismatch { color: #ef4444; }")
  table.insert(lines, "  </style>")
  table.insert(lines, "</head>")
  table.insert(lines, "<body>")

  table.insert(lines, "  <h1>Parity Report</h1>")

  -- Summary
  local score_class = summary.parity_score >= 100 and "pass" or
    (summary.parity_score >= 90 and "warn" or "fail")
  table.insert(lines, "  <div class=\"summary\">")
  table.insert(lines, string.format("    <div class=\"score %s\">%.1f%% Parity</div>",
    score_class, summary.parity_score))
  table.insert(lines, string.format("    <p>Total: %d | Matched: %d | Mismatched: %d</p>",
    summary.total, summary.matched, summary.mismatched))
  table.insert(lines, string.format("    <div class=\"status %s\">%s</div>",
    summary.passed and "pass" or "fail",
    summary.passed and "PASSED" or "FAILED"))
  table.insert(lines, "  </div>")

  -- Results table
  if summary.comparisons and #summary.comparisons > 0 then
    table.insert(lines, "  <h2>Scenario Results</h2>")
    table.insert(lines, "  <table>")
    table.insert(lines, "    <thead>")
    table.insert(lines, "      <tr><th>Scenario</th><th>Status</th><th>Lua</th><th>Reference</th><th>Differences</th></tr>")
    table.insert(lines, "    </thead>")
    table.insert(lines, "    <tbody>")

    for _, comp in ipairs(summary.comparisons) do
      local status_class = comp.passed and "match" or "mismatch"
      local status_text = comp.passed and "MATCH" or "DIFF"
      local lua_text = comp.lua_passed == nil and "N/A" or (comp.lua_passed and "PASS" or "FAIL")
      local ref_text = comp.ref_passed == nil and "N/A" or (comp.ref_passed and "PASS" or "FAIL")

      table.insert(lines, "      <tr>")
      table.insert(lines, string.format("        <td>%s</td>", comp.scenario_name or comp.scenario_id))
      table.insert(lines, string.format("        <td class=\"%s\">%s</td>", status_class, status_text))
      table.insert(lines, string.format("        <td>%s</td>", lua_text))
      table.insert(lines, string.format("        <td>%s</td>", ref_text))
      table.insert(lines, string.format("        <td>%d</td>", comp.difference_count))
      table.insert(lines, "      </tr>")
    end

    table.insert(lines, "    </tbody>")
    table.insert(lines, "  </table>")
  end

  table.insert(lines, "</body>")
  table.insert(lines, "</html>")

  return table.concat(lines, "\n")
end

--- Format summary in configured format
-- @param summary table Parity summary
-- @return string Formatted report
function ParityReporter:format(summary)
  if self._format == FORMATS.JSON then
    return self:format_json(summary)
  elseif self._format == FORMATS.MARKDOWN then
    return self:format_markdown(summary)
  elseif self._format == FORMATS.HTML then
    return self:format_html(summary)
  else
    return self:format_text(summary)
  end
end

--- Generate and output report
-- @param summary table Parity summary
-- @return string Formatted report
function ParityReporter:report(summary)
  local output = self:format(summary)

  if self._output then
    self._output(output)
  else
    print(output)
  end

  return output
end

--- Save report to file
-- @param summary table Parity summary
-- @param filepath string Output file path
-- @return boolean Success
-- @return string|nil Error message
function ParityReporter:save(summary, filepath)
  local output = self:format(summary)

  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file: " .. (err or filepath)
  end

  file:write(output)
  file:close()

  return true
end

--- Export formats constant
ParityReporter.FORMATS = FORMATS

return ParityReporter
