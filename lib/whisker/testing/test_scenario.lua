--- Test Scenario
-- Defines test scenarios and steps for automated story testing
-- @module whisker.testing.test_scenario
-- @author Whisker Core Team
-- @license MIT

local TestScenario = {}
TestScenario.__index = TestScenario
TestScenario._dependencies = {}

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

--- Create a new test scenario
-- @param config table Scenario configuration
-- @return TestScenario Scenario instance
function TestScenario.new(config)
  config = config or {}
  local self = setmetatable({}, TestScenario)

  self.id = config.id or ("scenario_" .. os.time())
  self.name = config.name or "Unnamed Scenario"
  self.description = config.description or ""
  self.enabled = config.enabled ~= false
  self.tags = config.tags or {}
  self.steps = {}
  self.timeout = config.timeout or 30000 -- 30 seconds default

  -- Add initial steps if provided
  if config.steps then
    for _, step in ipairs(config.steps) do
      self:add_step(step)
    end
  end

  return self
end

--- Add a step to the scenario
-- @param step table Step configuration
-- @return TestScenario Self for chaining
function TestScenario:add_step(step)
  local normalized = {
    type = step.type or STEP_TYPES.START,
    description = step.description,
  }

  -- Copy step-specific fields
  if step.type == STEP_TYPES.CHOICE then
    normalized.choice_index = step.choice_index or step.choiceIndex
    normalized.choice_text = step.choice_text or step.choiceText
  elseif step.type == STEP_TYPES.CHECK_PASSAGE then
    normalized.expected_passage_id = step.expected_passage_id or step.expectedPassageId
    normalized.expected_passage_title = step.expected_passage_title or step.expectedPassageTitle
  elseif step.type == STEP_TYPES.CHECK_VARIABLE then
    normalized.variable_name = step.variable_name or step.variableName
    normalized.expected_value = step.expected_value or step.expectedValue
    normalized.operator = step.operator or "equals"
  elseif step.type == STEP_TYPES.CHECK_TEXT then
    normalized.expected_text = step.expected_text or step.expectedText
    normalized.text_match = step.text_match or step.textMatch or "contains"
  elseif step.type == STEP_TYPES.SET_VARIABLE then
    normalized.variable_name = step.variable_name or step.variableName
    normalized.value = step.value
  elseif step.type == STEP_TYPES.WAIT then
    normalized.duration = step.duration or 0
  end

  table.insert(self.steps, normalized)
  return self
end

--- Add a start step
-- @param description string Optional description
-- @return TestScenario Self for chaining
function TestScenario:start(description)
  return self:add_step({
    type = STEP_TYPES.START,
    description = description or "Start the story",
  })
end

--- Add a choice step by index
-- @param index number Choice index (0-based)
-- @param description string Optional description
-- @return TestScenario Self for chaining
function TestScenario:choose_by_index(index, description)
  return self:add_step({
    type = STEP_TYPES.CHOICE,
    choice_index = index,
    description = description,
  })
end

--- Add a choice step by text
-- @param text string Choice text to match
-- @param description string Optional description
-- @return TestScenario Self for chaining
function TestScenario:choose_by_text(text, description)
  return self:add_step({
    type = STEP_TYPES.CHOICE,
    choice_text = text,
    description = description,
  })
end

--- Add a check passage step
-- @param options table Check options (id, title)
-- @return TestScenario Self for chaining
function TestScenario:check_passage(options)
  return self:add_step({
    type = STEP_TYPES.CHECK_PASSAGE,
    expected_passage_id = options.id,
    expected_passage_title = options.title,
    description = options.description,
  })
end

--- Add a check variable step
-- @param name string Variable name
-- @param expected any Expected value
-- @param operator string Optional operator (default: "equals")
-- @return TestScenario Self for chaining
function TestScenario:check_variable(name, expected, operator)
  return self:add_step({
    type = STEP_TYPES.CHECK_VARIABLE,
    variable_name = name,
    expected_value = expected,
    operator = operator or "equals",
  })
end

--- Add a check text step
-- @param text string Expected text
-- @param match_mode string Optional match mode (default: "contains")
-- @return TestScenario Self for chaining
function TestScenario:check_text(text, match_mode)
  return self:add_step({
    type = STEP_TYPES.CHECK_TEXT,
    expected_text = text,
    text_match = match_mode or "contains",
  })
end

--- Add a set variable step
-- @param name string Variable name
-- @param value any Value to set
-- @return TestScenario Self for chaining
function TestScenario:set_variable(name, value)
  return self:add_step({
    type = STEP_TYPES.SET_VARIABLE,
    variable_name = name,
    value = value,
  })
end

--- Serialize the scenario to a table
-- @return table Serialized scenario
function TestScenario:serialize()
  return {
    id = self.id,
    name = self.name,
    description = self.description,
    enabled = self.enabled,
    tags = self.tags,
    steps = self.steps,
    timeout = self.timeout,
  }
end

--- Deserialize a scenario from a table
-- @param data table Serialized data
-- @return TestScenario Scenario instance
function TestScenario.deserialize(data)
  return TestScenario.new(data)
end

--- Load scenarios from a table (e.g., parsed YAML/JSON)
-- @param data table Data containing scenarios array
-- @return table Array of TestScenario instances
function TestScenario.load_many(data)
  local scenarios = {}
  local items = data.scenarios or data.tests or data

  if type(items) == "table" then
    for _, item in ipairs(items) do
      table.insert(scenarios, TestScenario.new(item))
    end
  end

  return scenarios
end

return TestScenario
