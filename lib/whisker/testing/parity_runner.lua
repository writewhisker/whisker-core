--- Parity Runner
-- Cross-platform test execution and comparison engine
-- Compares Lua execution results against reference (TypeScript) results
-- @module whisker.testing.parity_runner
-- @author Whisker Core Team
-- @license MIT

local ParityRunner = {}
ParityRunner.__index = ParityRunner
ParityRunner._dependencies = {}

--- Comparison result types
local COMPARISON_TYPES = {
  MATCH = "match",
  MISMATCH = "mismatch",
  MISSING_LUA = "missing_lua",
  MISSING_REF = "missing_ref",
  TYPE_MISMATCH = "type_mismatch",
}

--- Tolerance levels for comparison
local TOLERANCE = {
  STRICT = "strict",       -- Exact match required
  LENIENT = "lenient",     -- Allow minor differences (whitespace, case)
  NUMERIC = "numeric",     -- Allow small numeric differences
}

--- Create a new parity runner
-- @param options table Runner options
-- @return ParityRunner Runner instance
function ParityRunner.new(options)
  options = options or {}
  local self = setmetatable({}, ParityRunner)

  self._tolerance = options.tolerance or TOLERANCE.STRICT
  self._numeric_epsilon = options.numeric_epsilon or 0.0001
  self._ignore_fields = options.ignore_fields or { "timestamp", "duration", "start_time", "end_time" }
  self._results = {}

  return self
end

--- Deep compare two values
-- @param lua_val any Lua execution value
-- @param ref_val any Reference (TypeScript) value
-- @param path string Current path for error reporting
-- @return table Comparison result
function ParityRunner:_compare_values(lua_val, ref_val, path)
  path = path or "root"

  -- Check if field should be ignored
  local field_name = path:match("%.([^%.]+)$") or path
  for _, ignore in ipairs(self._ignore_fields) do
    if field_name == ignore then
      return { type = COMPARISON_TYPES.MATCH, path = path }
    end
  end

  -- Handle nil cases
  if lua_val == nil and ref_val == nil then
    return { type = COMPARISON_TYPES.MATCH, path = path }
  elseif lua_val == nil then
    return {
      type = COMPARISON_TYPES.MISSING_LUA,
      path = path,
      reference = ref_val,
    }
  elseif ref_val == nil then
    return {
      type = COMPARISON_TYPES.MISSING_REF,
      path = path,
      lua_value = lua_val,
    }
  end

  -- Type comparison
  local lua_type = type(lua_val)
  local ref_type = type(ref_val)

  if lua_type ~= ref_type then
    -- Special case: number vs string comparison in lenient mode
    if self._tolerance ~= TOLERANCE.STRICT then
      if lua_type == "number" and ref_type == "string" then
        local ref_num = tonumber(ref_val)
        if ref_num and self:_compare_numbers(lua_val, ref_num) then
          return { type = COMPARISON_TYPES.MATCH, path = path }
        end
      elseif lua_type == "string" and ref_type == "number" then
        local lua_num = tonumber(lua_val)
        if lua_num and self:_compare_numbers(lua_num, ref_val) then
          return { type = COMPARISON_TYPES.MATCH, path = path }
        end
      end
    end

    return {
      type = COMPARISON_TYPES.TYPE_MISMATCH,
      path = path,
      lua_type = lua_type,
      reference_type = ref_type,
      lua_value = lua_val,
      reference = ref_val,
    }
  end

  -- Value comparison based on type
  if lua_type == "table" then
    return self:_compare_tables(lua_val, ref_val, path)
  elseif lua_type == "number" then
    if self:_compare_numbers(lua_val, ref_val) then
      return { type = COMPARISON_TYPES.MATCH, path = path }
    else
      return {
        type = COMPARISON_TYPES.MISMATCH,
        path = path,
        lua_value = lua_val,
        reference = ref_val,
      }
    end
  elseif lua_type == "string" then
    if self:_compare_strings(lua_val, ref_val) then
      return { type = COMPARISON_TYPES.MATCH, path = path }
    else
      return {
        type = COMPARISON_TYPES.MISMATCH,
        path = path,
        lua_value = lua_val,
        reference = ref_val,
      }
    end
  elseif lua_type == "boolean" then
    if lua_val == ref_val then
      return { type = COMPARISON_TYPES.MATCH, path = path }
    else
      return {
        type = COMPARISON_TYPES.MISMATCH,
        path = path,
        lua_value = lua_val,
        reference = ref_val,
      }
    end
  else
    -- For other types, use direct comparison
    if lua_val == ref_val then
      return { type = COMPARISON_TYPES.MATCH, path = path }
    else
      return {
        type = COMPARISON_TYPES.MISMATCH,
        path = path,
        lua_value = lua_val,
        reference = ref_val,
      }
    end
  end
end

--- Compare two numbers with tolerance
-- @param a number First number
-- @param b number Second number
-- @return boolean True if numbers are equal within tolerance
function ParityRunner:_compare_numbers(a, b)
  if self._tolerance == TOLERANCE.STRICT then
    return a == b
  else
    return math.abs(a - b) <= self._numeric_epsilon
  end
end

--- Compare two strings with tolerance
-- @param a string First string
-- @param b string Second string
-- @return boolean True if strings match
function ParityRunner:_compare_strings(a, b)
  if self._tolerance == TOLERANCE.STRICT then
    return a == b
  else
    -- Lenient: normalize whitespace and case
    local norm_a = a:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local norm_b = b:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    return norm_a == norm_b
  end
end

--- Compare two tables recursively
-- @param lua_tbl table Lua table
-- @param ref_tbl table Reference table
-- @param path string Current path
-- @return table Comparison result with all differences
function ParityRunner:_compare_tables(lua_tbl, ref_tbl, path)
  local differences = {}
  local all_keys = {}

  -- Collect all keys from both tables
  for k in pairs(lua_tbl) do all_keys[k] = true end
  for k in pairs(ref_tbl) do all_keys[k] = true end

  -- Check if this is an array (sequential integer keys)
  local is_array = true
  local max_index = 0
  for k in pairs(all_keys) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      is_array = false
      break
    end
    if k > max_index then max_index = k end
  end

  -- Compare each key
  for k in pairs(all_keys) do
    local key_path
    if is_array then
      key_path = path .. "[" .. k .. "]"
    else
      key_path = path .. "." .. tostring(k)
    end

    local result = self:_compare_values(lua_tbl[k], ref_tbl[k], key_path)
    if result.type ~= COMPARISON_TYPES.MATCH then
      table.insert(differences, result)
    end
  end

  if #differences == 0 then
    return { type = COMPARISON_TYPES.MATCH, path = path }
  else
    return {
      type = COMPARISON_TYPES.MISMATCH,
      path = path,
      differences = differences,
    }
  end
end

--- Compare a Lua test result against a reference result
-- @param lua_result table Result from Lua TestRunner
-- @param ref_result table Reference result (e.g., from TypeScript)
-- @return table Parity comparison result
function ParityRunner:compare_results(lua_result, ref_result)
  local comparison = self:_compare_values(lua_result, ref_result, "result")

  local passed = comparison.type == COMPARISON_TYPES.MATCH
  local differences = {}

  if comparison.differences then
    differences = comparison.differences
  elseif comparison.type ~= COMPARISON_TYPES.MATCH then
    differences = { comparison }
  end

  return {
    passed = passed,
    scenario_id = lua_result.scenario_id or ref_result.scenario_id or "unknown",
    scenario_name = lua_result.scenario_name or ref_result.scenario_name or "Unknown",
    lua_passed = lua_result.passed,
    ref_passed = ref_result.passed,
    difference_count = #differences,
    differences = differences,
    lua_result = lua_result,
    ref_result = ref_result,
  }
end

--- Run parity comparison for multiple scenarios
-- @param lua_results table Array of Lua results
-- @param ref_results table Array of reference results (keyed by scenario_id)
-- @return table Parity summary
function ParityRunner:compare_all(lua_results, ref_results)
  local comparisons = {}
  local matched = 0
  local mismatched = 0
  local missing_ref = 0
  local missing_lua = 0

  -- Index reference results by scenario_id
  local ref_by_id = {}
  for _, ref in ipairs(ref_results) do
    ref_by_id[ref.scenario_id or ref.scenarioId] = ref
  end

  -- Compare each Lua result
  for _, lua_result in ipairs(lua_results) do
    local scenario_id = lua_result.scenario_id
    local ref_result = ref_by_id[scenario_id]

    if ref_result then
      local comparison = self:compare_results(lua_result, ref_result)
      table.insert(comparisons, comparison)

      if comparison.passed then
        matched = matched + 1
      else
        mismatched = mismatched + 1
      end

      ref_by_id[scenario_id] = nil -- Mark as processed
    else
      missing_ref = missing_ref + 1
      table.insert(comparisons, {
        passed = false,
        scenario_id = scenario_id,
        scenario_name = lua_result.scenario_name,
        lua_passed = lua_result.passed,
        ref_passed = nil,
        difference_count = 1,
        differences = {{
          type = COMPARISON_TYPES.MISSING_REF,
          path = "scenario",
          message = "No reference result found for scenario: " .. scenario_id,
        }},
        lua_result = lua_result,
        ref_result = nil,
      })
    end
  end

  -- Check for reference results without Lua counterparts
  for scenario_id, ref_result in pairs(ref_by_id) do
    missing_lua = missing_lua + 1
    table.insert(comparisons, {
      passed = false,
      scenario_id = scenario_id,
      scenario_name = ref_result.scenario_name or ref_result.scenarioName,
      lua_passed = nil,
      ref_passed = ref_result.passed,
      difference_count = 1,
      differences = {{
        type = COMPARISON_TYPES.MISSING_LUA,
        path = "scenario",
        message = "No Lua result found for scenario: " .. scenario_id,
      }},
      lua_result = nil,
      ref_result = ref_result,
    })
  end

  local total = matched + mismatched + missing_ref + missing_lua
  local parity_score = total > 0 and (matched / total * 100) or 100

  return {
    total = total,
    matched = matched,
    mismatched = mismatched,
    missing_ref = missing_ref,
    missing_lua = missing_lua,
    parity_score = parity_score,
    passed = mismatched == 0 and missing_ref == 0 and missing_lua == 0,
    comparisons = comparisons,
  }
end

--- Load reference results from JSON file
-- @param filepath string Path to JSON file
-- @return table|nil Reference results or nil on error
-- @return string|nil Error message
function ParityRunner:load_reference_results(filepath)
  local file, err = io.open(filepath, "r")
  if not file then
    return nil, "Failed to open file: " .. (err or filepath)
  end

  local content = file:read("*a")
  file:close()

  -- Simple JSON parsing (for arrays and objects)
  local json = require("whisker.utils.json")
  local ok, result = pcall(json.decode, content)

  if not ok then
    return nil, "Failed to parse JSON: " .. tostring(result)
  end

  return result
end

--- Save comparison results to JSON file
-- @param results table Comparison results
-- @param filepath string Output file path
-- @return boolean Success
-- @return string|nil Error message
function ParityRunner:save_results(results, filepath)
  local json = require("whisker.utils.json")
  local content = json.encode(results, 0)  -- 0 = starting indent level for pretty output

  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file for writing: " .. (err or filepath)
  end

  file:write(content)
  file:close()

  return true
end

--- Export constants
ParityRunner.COMPARISON_TYPES = COMPARISON_TYPES
ParityRunner.TOLERANCE = TOLERANCE

return ParityRunner
