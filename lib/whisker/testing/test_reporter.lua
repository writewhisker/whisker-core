--- Test Reporter
-- Formats and outputs test results in various formats
-- @module whisker.testing.test_reporter
-- @author Whisker Core Team
-- @license MIT

local TestReporter = {}
TestReporter.__index = TestReporter
TestReporter._dependencies = {}

--- Output formats
local FORMATS = {
  TEXT = "text",
  JSON = "json",
  TAP = "tap", -- Test Anything Protocol
  JUNIT = "junit",
}

--- Create a new test reporter
-- @param options table Reporter options
-- @return TestReporter Reporter instance
function TestReporter.new(options)
  options = options or {}
  local self = setmetatable({}, TestReporter)

  self._format = options.format or FORMATS.TEXT
  self._verbose = options.verbose or false
  self._colors = options.colors ~= false -- default true
  self._output = options.output -- optional output function

  return self
end

--- ANSI color codes
local COLORS = {
  reset = "\27[0m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  gray = "\27[90m",
}

--- Apply color if enabled
-- @param self TestReporter
-- @param text string Text to color
-- @param color string Color name
-- @return string Colored or plain text
local function colorize(self, text, color)
  if self._colors and COLORS[color] then
    return COLORS[color] .. text .. COLORS.reset
  end
  return text
end

--- Format a single step result
-- @param self TestReporter
-- @param result table Step result
-- @return string Formatted step
local function format_step_text(self, result)
  local status = result.passed and "PASS" or "FAIL"
  local color = result.passed and "green" or "red"

  local line = string.format("    [%s] Step %d: %s",
    colorize(self, status, color),
    result.step_index,
    result.message or "")

  if self._verbose and not result.passed then
    if result.expected_value ~= nil then
      line = line .. string.format("\n      Expected: %s", tostring(result.expected_value))
    end
    if result.actual_value ~= nil then
      line = line .. string.format("\n      Actual: %s", tostring(result.actual_value))
    end
  end

  return line
end

--- Format a single test result as text
-- @param self TestReporter
-- @param result table Test result
-- @return string Formatted result
local function format_test_text(self, result)
  local lines = {}

  local status = result.passed and "PASS" or "FAIL"
  local color = result.passed and "green" or "red"

  table.insert(lines, string.format("  %s %s",
    colorize(self, status, color),
    result.scenario_name or result.scenario_id))

  if self._verbose then
    table.insert(lines, string.format("    Duration: %dms", result.duration or 0))
    table.insert(lines, string.format("    Steps: %d/%d passed",
      result.passed_steps or 0, result.total_steps or 0))

    if result.step_results then
      for _, step_result in ipairs(result.step_results) do
        if not step_result.passed or self._verbose then
          table.insert(lines, format_step_text(self, step_result))
        end
      end
    end
  elseif not result.passed and result.step_results then
    -- Show failed step even in non-verbose mode
    for _, step_result in ipairs(result.step_results) do
      if not step_result.passed then
        table.insert(lines, format_step_text(self, step_result))
        break
      end
    end
  end

  if result.error then
    table.insert(lines, colorize(self, "    Error: " .. result.error, "red"))
  end

  return table.concat(lines, "\n")
end

--- Format summary as text
-- @param summary table Summary data
-- @return string Formatted summary
function TestReporter:format_summary_text(summary)
  local lines = {}

  table.insert(lines, "\n" .. string.rep("=", 50))
  table.insert(lines, "Test Summary")
  table.insert(lines, string.rep("=", 50))

  local status_color = summary.success and "green" or "red"
  local status_text = summary.success and "ALL PASSED" or "SOME FAILED"

  table.insert(lines, string.format("  Total:    %d", summary.total))
  table.insert(lines, string.format("  Passed:   %s",
    colorize(self, tostring(summary.passed), "green")))
  table.insert(lines, string.format("  Failed:   %s",
    colorize(self, tostring(summary.failed), summary.failed > 0 and "red" or "green")))
  table.insert(lines, string.format("  Duration: %dms", summary.duration or 0))
  table.insert(lines, "")
  table.insert(lines, colorize(self, status_text, status_color))

  return table.concat(lines, "\n")
end

--- Format results as plain text
-- @param summary table Summary with results
-- @return string Formatted text
function TestReporter:format_text(summary)
  local lines = {}

  table.insert(lines, "\nRunning Tests...")
  table.insert(lines, string.rep("-", 50))

  for _, result in ipairs(summary.results or {}) do
    table.insert(lines, format_test_text(self, result))
  end

  table.insert(lines, self:format_summary_text(summary))

  return table.concat(lines, "\n")
end

--- Escape a string for JSON
-- @param s string String to escape
-- @return string Escaped string
local function json_escape(s)
  if type(s) ~= "string" then return tostring(s) end
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return s
end

--- Simple JSON encoder for test results
-- @param value any Value to encode
-- @param indent number Current indent level
-- @return string JSON string
local function encode_json(value, indent)
  indent = indent or 0
  local spaces = string.rep("  ", indent)

  if value == nil then
    return "null"
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "string" then
    return '"' .. json_escape(value) .. '"'
  elseif type(value) == "table" then
    -- Check if array
    local is_array = #value > 0 or next(value) == nil
    if is_array then
      local items = {}
      for _, v in ipairs(value) do
        table.insert(items, spaces .. "  " .. encode_json(v, indent + 1))
      end
      if #items == 0 then
        return "[]"
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "]"
    else
      local items = {}
      for k, v in pairs(value) do
        table.insert(items, spaces .. '  "' .. json_escape(k) .. '": ' .. encode_json(v, indent + 1))
      end
      if #items == 0 then
        return "{}"
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "}"
    end
  else
    return '"' .. json_escape(tostring(value)) .. '"'
  end
end

--- Format results as JSON
-- @param summary table Summary with results
-- @return string JSON string
function TestReporter:format_json(summary)
  return encode_json(summary)
end

--- Format results as TAP (Test Anything Protocol)
-- @param summary table Summary with results
-- @return string TAP output
function TestReporter:format_tap(summary)
  local lines = {}
  local test_num = 0

  table.insert(lines, "TAP version 13")
  table.insert(lines, string.format("1..%d", summary.total))

  for _, result in ipairs(summary.results or {}) do
    test_num = test_num + 1
    local status = result.passed and "ok" or "not ok"
    local name = result.scenario_name or result.scenario_id

    table.insert(lines, string.format("%s %d - %s", status, test_num, name))

    if not result.passed then
      table.insert(lines, "  ---")
      table.insert(lines, "  message: Test failed")
      if result.step_results then
        for _, step in ipairs(result.step_results) do
          if not step.passed then
            table.insert(lines, string.format("  failed_step: %d", step.step_index))
            table.insert(lines, string.format("  step_message: %s", step.message or ""))
            break
          end
        end
      end
      table.insert(lines, "  ...")
    end
  end

  return table.concat(lines, "\n")
end

--- Escape XML special characters
-- @param s string String to escape
-- @return string Escaped string
local function xml_escape(s)
  if type(s) ~= "string" then return tostring(s) end
  s = s:gsub("&", "&amp;")
  s = s:gsub("<", "&lt;")
  s = s:gsub(">", "&gt;")
  s = s:gsub('"', "&quot;")
  s = s:gsub("'", "&apos;")
  return s
end

--- Format results as JUnit XML
-- @param summary table Summary with results
-- @return string JUnit XML
function TestReporter:format_junit(summary)
  local lines = {}

  table.insert(lines, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(lines, string.format(
    '<testsuite name="whisker-tests" tests="%d" failures="%d" time="%.3f">',
    summary.total, summary.failed, (summary.duration or 0) / 1000))

  for _, result in ipairs(summary.results or {}) do
    local name = xml_escape(result.scenario_name or result.scenario_id)
    local time = (result.duration or 0) / 1000

    if result.passed then
      table.insert(lines, string.format(
        '  <testcase name="%s" time="%.3f"/>', name, time))
    else
      table.insert(lines, string.format(
        '  <testcase name="%s" time="%.3f">', name, time))

      local failure_message = "Test failed"
      if result.step_results then
        for _, step in ipairs(result.step_results) do
          if not step.passed then
            failure_message = step.message or failure_message
            break
          end
        end
      end

      table.insert(lines, string.format(
        '    <failure message="%s"/>', xml_escape(failure_message)))
      table.insert(lines, '  </testcase>')
    end
  end

  table.insert(lines, '</testsuite>')

  return table.concat(lines, "\n")
end

--- Format results in the configured format
-- @param summary table Summary with results
-- @return string Formatted output
function TestReporter:format(summary)
  if self._format == FORMATS.JSON then
    return self:format_json(summary)
  elseif self._format == FORMATS.TAP then
    return self:format_tap(summary)
  elseif self._format == FORMATS.JUNIT then
    return self:format_junit(summary)
  else
    return self:format_text(summary)
  end
end

--- Report results
-- @param summary table Summary with results
-- @return string Formatted output
function TestReporter:report(summary)
  local output = self:format(summary)

  if self._output then
    self._output(output)
  else
    print(output)
  end

  return output
end

--- Export formats constant
TestReporter.FORMATS = FORMATS

return TestReporter
