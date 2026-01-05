--- Test Runner
-- Executes automated test scenarios against Whisker stories
-- @module whisker.testing.test_runner
-- @author Whisker Core Team
-- @license MIT

local TestRunner = {}
TestRunner.__index = TestRunner
TestRunner._dependencies = {}

--- Step types
local STEP_TYPES = {
  START = "start",
  CHOICE = "choice",
  CHECK_PASSAGE = "check_passage",
  CHECK_VARIABLE = "check_variable",
  CHECK_TEXT = "check_text",
  SET_VARIABLE = "set_variable",
  WAIT = "wait",
}

--- Get current timestamp
local function get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Get time in milliseconds (best effort, falls back to seconds)
local function get_time_ms()
  local ok, socket = pcall(require, "socket")
  if ok and socket.gettime then
    return math.floor(socket.gettime() * 1000)
  end
  return os.time() * 1000
end

--- Create a step result
local function create_step_result(step_index, step, passed, message, actual, expected)
  return {
    step_index = step_index,
    step = step,
    passed = passed,
    message = message,
    actual_value = actual,
    expected_value = expected,
    timestamp = get_timestamp(),
  }
end

--- Create a new test runner
-- @param story table Story instance or story data
-- @param options table Optional runner options
-- @return TestRunner Runner instance
function TestRunner.new(story, options)
  options = options or {}
  local self = setmetatable({}, TestRunner)

  self._story = story
  self._options = options
  self._current_passage = nil
  self._variables = {}
  self._visit_history = {}
  self._choice_history = {}

  return self
end

--- Reset the runner state
function TestRunner:reset()
  self._current_passage = nil
  self._variables = {}
  self._visit_history = {}
  self._choice_history = {}

  -- Initialize variables from story
  local variables = self._story.variables or {}
  for name, var in pairs(variables) do
    local initial = var.initial
    if initial == nil then
      initial = var.value
    end
    self._variables[name] = initial
  end
end

--- Get a passage from the story
-- @param id string Passage ID
-- @return table|nil Passage or nil
function TestRunner:_get_passage(id)
  local passages = self._story.passages
  if type(passages) == "table" then
    -- Handle both map and array formats
    if passages[id] then
      return passages[id]
    end
    for _, p in pairs(passages) do
      if p.id == id or p.name == id then
        return p
      end
    end
  end
  return nil
end

--- Get the start passage
-- @return table|nil Start passage
function TestRunner:_get_start_passage()
  local start_id = self._story.startPassage or self._story.start_passage
  if start_id then
    return self:_get_passage(start_id)
  end
  -- Try to find a passage named "Start" or "start"
  local passages = self._story.passages or {}
  for id, passage in pairs(passages) do
    local title = passage.title or passage.name or id
    if title:lower() == "start" then
      return passage
    end
  end
  -- Return first passage
  for _, passage in pairs(passages) do
    return passage
  end
  return nil
end

--- Execute start step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_start(step, index)
  local passage = self:_get_start_passage()

  if not passage then
    return create_step_result(index, step, false,
      "Story has no start passage", nil, nil)
  end

  self._current_passage = passage
  table.insert(self._visit_history, {
    passage_id = passage.id or passage.name,
    timestamp = get_timestamp(),
  })

  local title = passage.title or passage.name or passage.id
  return create_step_result(index, step, true,
    "Started at passage: " .. title, title, nil)
end

--- Execute choice step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_choice(step, index)
  if not self._current_passage then
    return create_step_result(index, step, false,
      "No current passage (must start test first)", nil, nil)
  end

  local choices = self._current_passage.choices or {}

  -- Find choice by index or text
  local choice_index
  local choice

  if step.choice_index ~= nil then
    -- Lua is 1-indexed, but we accept 0-indexed for compatibility
    choice_index = step.choice_index + 1
    choice = choices[choice_index]
  elseif step.choice_text then
    for i, c in ipairs(choices) do
      if c.text == step.choice_text then
        choice_index = i
        choice = c
        break
      end
    end
    if not choice then
      local available = {}
      for _, c in ipairs(choices) do
        table.insert(available, c.text)
      end
      return create_step_result(index, step, false,
        'Choice not found: "' .. step.choice_text .. '"',
        available, step.choice_text)
    end
  else
    return create_step_result(index, step, false,
      "Choice step must specify either choice_index or choice_text", nil, nil)
  end

  if not choice then
    return create_step_result(index, step, false,
      "Invalid choice index: " .. tostring(step.choice_index) ..
      " (available: 0-" .. (#choices - 1) .. ")",
      #choices, step.choice_index)
  end

  -- Navigate to target passage
  local target = choice.target
  local next_passage = self:_get_passage(target)

  if not next_passage then
    return create_step_result(index, step, false,
      "Target passage not found: " .. tostring(target), nil, target)
  end

  -- Record choice
  table.insert(self._choice_history, {
    from_passage = self._current_passage.id or self._current_passage.name,
    choice_index = choice_index - 1,
    choice_text = choice.text,
    to_passage = target,
    timestamp = get_timestamp(),
  })

  self._current_passage = next_passage
  table.insert(self._visit_history, {
    passage_id = next_passage.id or next_passage.name,
    timestamp = get_timestamp(),
  })

  local next_title = next_passage.title or next_passage.name or target
  return create_step_result(index, step, true,
    'Chose: "' .. choice.text .. '" -> ' .. next_title,
    choice.text, nil)
end

--- Execute check passage step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_check_passage(step, index)
  if not self._current_passage then
    return create_step_result(index, step, false,
      "No current passage to check", nil, nil)
  end

  local passage = self._current_passage
  local id_match = true
  local title_match = true

  if step.expected_passage_id then
    local actual_id = passage.id or passage.name
    id_match = actual_id == step.expected_passage_id
  end

  if step.expected_passage_title then
    local actual_title = passage.title or passage.name or passage.id
    title_match = actual_title == step.expected_passage_title
  end

  local passed = id_match and title_match
  local actual_title = passage.title or passage.name or passage.id

  local message
  if passed then
    message = "At expected passage: " .. actual_title
  else
    local expected = step.expected_passage_title or step.expected_passage_id
    message = 'Expected passage "' .. expected .. '", but at "' .. actual_title .. '"'
  end

  return create_step_result(index, step, passed, message,
    { id = passage.id, title = passage.title or passage.name },
    { id = step.expected_passage_id, title = step.expected_passage_title })
end

--- Execute check variable step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_check_variable(step, index)
  if not step.variable_name then
    return create_step_result(index, step, false,
      "Variable name not specified", nil, nil)
  end

  local actual = self._variables[step.variable_name]
  local expected = step.expected_value
  local operator = step.operator or "equals"

  local passed = false
  local message = ""

  if operator == "equals" then
    passed = actual == expected
    if passed then
      message = step.variable_name .. " = " .. tostring(actual)
    else
      message = "Expected " .. step.variable_name .. " = " .. tostring(expected) ..
        ", but got " .. tostring(actual)
    end
  elseif operator == "not_equals" then
    passed = actual ~= expected
    if passed then
      message = step.variable_name .. " != " .. tostring(expected)
    else
      message = "Expected " .. step.variable_name .. " != " .. tostring(expected) ..
        ", but it equals"
    end
  elseif operator == "greater_than" then
    passed = (tonumber(actual) or 0) > (tonumber(expected) or 0)
    if passed then
      message = step.variable_name .. " > " .. tostring(expected)
    else
      message = "Expected " .. step.variable_name .. " > " .. tostring(expected) ..
        ", but got " .. tostring(actual)
    end
  elseif operator == "less_than" then
    passed = (tonumber(actual) or 0) < (tonumber(expected) or 0)
    if passed then
      message = step.variable_name .. " < " .. tostring(expected)
    else
      message = "Expected " .. step.variable_name .. " < " .. tostring(expected) ..
        ", but got " .. tostring(actual)
    end
  elseif operator == "greater_or_equal" then
    passed = (tonumber(actual) or 0) >= (tonumber(expected) or 0)
    if passed then
      message = step.variable_name .. " >= " .. tostring(expected)
    else
      message = "Expected " .. step.variable_name .. " >= " .. tostring(expected) ..
        ", but got " .. tostring(actual)
    end
  elseif operator == "less_or_equal" then
    passed = (tonumber(actual) or 0) <= (tonumber(expected) or 0)
    if passed then
      message = step.variable_name .. " <= " .. tostring(expected)
    else
      message = "Expected " .. step.variable_name .. " <= " .. tostring(expected) ..
        ", but got " .. tostring(actual)
    end
  elseif operator == "contains" then
    passed = tostring(actual):find(tostring(expected), 1, true) ~= nil
    if passed then
      message = step.variable_name .. ' contains "' .. tostring(expected) .. '"'
    else
      message = "Expected " .. step.variable_name .. ' to contain "' ..
        tostring(expected) .. '", but got "' .. tostring(actual) .. '"'
    end
  else
    return create_step_result(index, step, false,
      "Unknown operator: " .. tostring(operator), nil, nil)
  end

  return create_step_result(index, step, passed, message, actual, expected)
end

--- Execute check text step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_check_text(step, index)
  if not self._current_passage then
    return create_step_result(index, step, false,
      "No current passage to check", nil, nil)
  end

  local content = self._current_passage.content or ""
  local expected = step.expected_text or ""
  local match_mode = step.text_match or "contains"

  local passed = false
  local message = ""

  if match_mode == "exact" then
    passed = content == expected
    if passed then
      message = "Text matches exactly"
    else
      message = "Expected exact text match"
    end
  elseif match_mode == "contains" then
    passed = content:find(expected, 1, true) ~= nil
    if passed then
      message = 'Text contains "' .. expected .. '"'
    else
      message = 'Text does not contain "' .. expected .. '"'
    end
  elseif match_mode == "pattern" then
    local ok, result = pcall(function()
      return content:match(expected) ~= nil
    end)
    if not ok then
      return create_step_result(index, step, false,
        "Invalid pattern: " .. expected, nil, expected)
    end
    passed = result
    if passed then
      message = "Text matches pattern: " .. expected
    else
      message = "Text does not match pattern: " .. expected
    end
  else
    return create_step_result(index, step, false,
      "Unknown text match mode: " .. tostring(match_mode), nil, nil)
  end

  -- Truncate content for result
  local display_content = content
  if #display_content > 100 then
    display_content = display_content:sub(1, 100) .. "..."
  end

  return create_step_result(index, step, passed, message, display_content, expected)
end

--- Execute set variable step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_set_variable(step, index)
  if not step.variable_name then
    return create_step_result(index, step, false,
      "Variable name not specified", nil, nil)
  end

  self._variables[step.variable_name] = step.value
  return create_step_result(index, step, true,
    step.variable_name .. " = " .. tostring(step.value),
    step.value, nil)
end

--- Execute a single step
-- @param step table Step configuration
-- @param index number Step index
-- @return table Step result
function TestRunner:_execute_step(step, index)
  local step_type = step.type or STEP_TYPES.START

  if step_type == STEP_TYPES.START then
    return self:_execute_start(step, index)
  elseif step_type == STEP_TYPES.CHOICE then
    return self:_execute_choice(step, index)
  elseif step_type == STEP_TYPES.CHECK_PASSAGE then
    return self:_execute_check_passage(step, index)
  elseif step_type == STEP_TYPES.CHECK_VARIABLE then
    return self:_execute_check_variable(step, index)
  elseif step_type == STEP_TYPES.CHECK_TEXT then
    return self:_execute_check_text(step, index)
  elseif step_type == STEP_TYPES.SET_VARIABLE then
    return self:_execute_set_variable(step, index)
  elseif step_type == STEP_TYPES.WAIT then
    return create_step_result(index, step, true, "Wait step (skipped)", nil, nil)
  else
    return create_step_result(index, step, false,
      "Unknown step type: " .. tostring(step_type), nil, nil)
  end
end

--- Run a single test scenario
-- @param scenario table TestScenario instance or config
-- @return table Test result
function TestRunner:run_test(scenario)
  local start_time = get_time_ms()
  local start_timestamp = get_timestamp()
  local step_results = {}

  -- Handle both TestScenario instances and raw configs
  local id = scenario.id or "unknown"
  local name = scenario.name or "Unnamed"
  local steps = scenario.steps or {}

  -- Reset state
  self:reset()

  local success, error_msg = pcall(function()
    for i, step in ipairs(steps) do
      local result = self:_execute_step(step, i)
      table.insert(step_results, result)

      -- Stop on first failure
      if not result.passed then
        break
      end
    end
  end)

  local end_time = get_time_ms()
  local end_timestamp = get_timestamp()
  local duration = end_time - start_time

  local passed_steps = 0
  local failed_steps = 0
  for _, r in ipairs(step_results) do
    if r.passed then
      passed_steps = passed_steps + 1
    else
      failed_steps = failed_steps + 1
    end
  end

  -- Add error if execution failed
  if not success then
    failed_steps = failed_steps + 1
  end

  return {
    scenario_id = id,
    scenario_name = name,
    passed = failed_steps == 0,
    start_time = start_timestamp,
    end_time = end_timestamp,
    duration = duration,
    total_steps = #steps,
    passed_steps = passed_steps,
    failed_steps = failed_steps,
    step_results = step_results,
    visit_history = self._visit_history,
    choice_history = self._choice_history,
    error = not success and error_msg or nil,
  }
end

--- Run multiple test scenarios
-- @param scenarios table Array of TestScenario instances
-- @return table Array of test results
function TestRunner:run_tests(scenarios)
  local results = {}

  for _, scenario in ipairs(scenarios) do
    -- Skip disabled scenarios
    local enabled = scenario.enabled
    if enabled == nil then enabled = true end

    if enabled then
      local result = self:run_test(scenario)
      table.insert(results, result)
    end
  end

  return results
end

--- Run all tests and return a summary
-- @param scenarios table Array of TestScenario instances
-- @return table Summary with results
function TestRunner:run_all(scenarios)
  local results = self:run_tests(scenarios)

  local total = #results
  local passed = 0
  local failed = 0
  local total_duration = 0

  for _, r in ipairs(results) do
    if r.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
    total_duration = total_duration + (r.duration or 0)
  end

  return {
    total = total,
    passed = passed,
    failed = failed,
    duration = total_duration,
    results = results,
    success = failed == 0,
  }
end

return TestRunner
