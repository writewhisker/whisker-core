-- whisker/formats/ink/validator.lua
-- Validates converted Ink stories for completeness and correctness

local Validator = {}
Validator.__index = Validator

-- Module metadata
Validator._whisker = {
  name = "InkValidator",
  version = "1.0.0",
  description = "Validates converted Ink stories",
  depends = {},
  capability = "formats.ink.validator"
}

-- Severity levels for issues
Validator.SEVERITY = {
  ERROR = "error",
  WARNING = "warning",
  INFO = "info"
}

-- Create a new Validator instance
function Validator.new()
  local instance = {
    errors = {},
    warnings = {},
    info = {},
    stats = {}
  }
  setmetatable(instance, Validator)
  return instance
end

-- Reset validator state
function Validator:reset()
  self.errors = {}
  self.warnings = {}
  self.info = {}
  self.stats = {
    passages = 0,
    choices = 0,
    variables = 0,
    links = 0,
    orphaned = 0
  }
end

-- Add an issue to the validator
-- @param severity string - Issue severity
-- @param message string - Issue description
-- @param context table|nil - Additional context
function Validator:add_issue(severity, message, context)
  local issue = {
    message = message,
    context = context or {}
  }

  if severity == self.SEVERITY.ERROR then
    table.insert(self.errors, issue)
  elseif severity == self.SEVERITY.WARNING then
    table.insert(self.warnings, issue)
  else
    table.insert(self.info, issue)
  end
end

-- Validate a converted story
-- @param story table - The converted whisker story
-- @param options table|nil - Validation options
-- @return table - Validation result with success, errors, warnings, info
function Validator:validate(story, options)
  options = options or {}
  self:reset()

  if not story then
    self:add_issue(self.SEVERITY.ERROR, "Story is nil or missing")
    return self:get_result()
  end

  -- Build passage index
  local passage_index = self:_build_passage_index(story)

  -- Build variable index
  local variable_index = self:_build_variable_index(story)

  -- Validate passages
  self:_validate_passages(story, passage_index, variable_index, options)

  -- Validate links/diverts
  self:_validate_links(story, passage_index)

  -- Check for orphaned content
  self:_check_orphaned_content(story, passage_index)

  -- Validate variables
  self:_validate_variables(story, variable_index)

  return self:get_result()
end

-- Build index of all passages
function Validator:_build_passage_index(story)
  local index = {}
  local passages = story.passages or {}

  for id, passage in pairs(passages) do
    index[id] = passage
    self.stats.passages = self.stats.passages + 1
  end

  return index
end

-- Build index of all variables
function Validator:_build_variable_index(story)
  local index = {}
  local variables = story.variables or {}

  for name, variable in pairs(variables) do
    index[name] = variable
    self.stats.variables = self.stats.variables + 1
  end

  return index
end

-- Validate passages
function Validator:_validate_passages(story, passage_index, variable_index, options)
  local passages = story.passages or {}

  for id, passage in pairs(passages) do
    -- Validate passage has required fields
    if not passage.id then
      self:add_issue(self.SEVERITY.ERROR, "Passage missing id", { passage_key = id })
    end

    -- Validate choices
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        self.stats.choices = self.stats.choices + 1

        if not choice.text and not choice.content then
          self:add_issue(self.SEVERITY.WARNING, "Choice has no text", {
            passage = id,
            choice_index = i
          })
        end

        -- Validate choice target
        if choice.target and not passage_index[choice.target] then
          self:add_issue(self.SEVERITY.ERROR, "Choice targets non-existent passage", {
            passage = id,
            choice_index = i,
            target = choice.target
          })
        end

        -- Validate choice conditions reference valid variables
        if choice.condition and options.validate_conditions then
          self:_validate_condition_variables(choice.condition, variable_index, {
            passage = id,
            choice_index = i
          })
        end
      end
    end
  end
end

-- Validate all passage links
function Validator:_validate_links(story, passage_index)
  local passages = story.passages or {}

  for id, passage in pairs(passages) do
    -- Check next passage link
    if passage.next then
      self.stats.links = self.stats.links + 1
      if not passage_index[passage.next] then
        self:add_issue(self.SEVERITY.ERROR, "Next passage does not exist", {
          passage = id,
          target = passage.next
        })
      end
    end

    -- Check link array
    if passage.links then
      for _, link in ipairs(passage.links) do
        self.stats.links = self.stats.links + 1
        local target = type(link) == "table" and link.target or link
        if target and not passage_index[target] then
          self:add_issue(self.SEVERITY.ERROR, "Link target does not exist", {
            passage = id,
            target = target
          })
        end
      end
    end

    -- Check divert in content
    if passage.divert then
      self.stats.links = self.stats.links + 1
      if not passage_index[passage.divert] then
        self:add_issue(self.SEVERITY.ERROR, "Divert target does not exist", {
          passage = id,
          target = passage.divert
        })
      end
    end
  end
end

-- Check for orphaned content (passages not reachable from start)
function Validator:_check_orphaned_content(story, passage_index)
  local start_passage = story.start or story.metadata and story.metadata.start

  if not start_passage then
    self:add_issue(self.SEVERITY.WARNING, "No start passage defined")
    return
  end

  if not passage_index[start_passage] then
    self:add_issue(self.SEVERITY.ERROR, "Start passage does not exist", {
      start = start_passage
    })
    return
  end

  -- BFS to find reachable passages
  local visited = {}
  local queue = { start_passage }

  while #queue > 0 do
    local current = table.remove(queue, 1)

    if not visited[current] then
      visited[current] = true
      local passage = passage_index[current]

      if passage then
        -- Add choices targets
        if passage.choices then
          for _, choice in ipairs(passage.choices) do
            if choice.target and not visited[choice.target] then
              table.insert(queue, choice.target)
            end
          end
        end

        -- Add next passage
        if passage.next and not visited[passage.next] then
          table.insert(queue, passage.next)
        end

        -- Add links
        if passage.links then
          for _, link in ipairs(passage.links) do
            local target = type(link) == "table" and link.target or link
            if target and not visited[target] then
              table.insert(queue, target)
            end
          end
        end

        -- Add divert
        if passage.divert and not visited[passage.divert] then
          table.insert(queue, passage.divert)
        end
      end
    end
  end

  -- Check for orphaned passages
  for id, _ in pairs(passage_index) do
    if not visited[id] then
      self.stats.orphaned = self.stats.orphaned + 1
      self:add_issue(self.SEVERITY.WARNING, "Passage not reachable from start", {
        passage = id
      })
    end
  end
end

-- Validate variables
function Validator:_validate_variables(story, variable_index)
  local variables = story.variables or {}

  for name, variable in pairs(variables) do
    -- Check for valid type
    if variable.type then
      local valid_types = { "integer", "float", "string", "boolean", "list", "table", "nil" }
      local is_valid = false
      for _, t in ipairs(valid_types) do
        if variable.type == t then
          is_valid = true
          break
        end
      end
      if not is_valid then
        self:add_issue(self.SEVERITY.WARNING, "Unknown variable type", {
          variable = name,
          type = variable.type
        })
      end
    end

    -- Check default value matches type
    if variable.default ~= nil and variable.type then
      local lua_type = type(variable.default)
      local type_map = {
        integer = "number",
        float = "number",
        string = "string",
        boolean = "boolean",
        list = "table",
        table = "table"
      }
      if type_map[variable.type] and lua_type ~= type_map[variable.type] then
        self:add_issue(self.SEVERITY.WARNING, "Default value type mismatch", {
          variable = name,
          expected = variable.type,
          actual = lua_type
        })
      end
    end
  end
end

-- Validate condition references valid variables
function Validator:_validate_condition_variables(condition, variable_index, context)
  if type(condition) ~= "table" then
    return
  end

  -- Check for variable reference
  if condition.variable then
    if not variable_index[condition.variable] then
      self:add_issue(self.SEVERITY.WARNING, "Condition references undefined variable", {
        variable = condition.variable,
        passage = context.passage,
        choice_index = context.choice_index
      })
    end
  end

  -- Recursively check nested conditions
  if condition.left then
    self:_validate_condition_variables(condition.left, variable_index, context)
  end
  if condition.right then
    self:_validate_condition_variables(condition.right, variable_index, context)
  end
  if condition.conditions then
    for _, sub in ipairs(condition.conditions) do
      self:_validate_condition_variables(sub, variable_index, context)
    end
  end
end

-- Get validation result
-- @return table - Result with success, errors, warnings, info, stats
function Validator:get_result()
  return {
    success = #self.errors == 0,
    errors = self.errors,
    warnings = self.warnings,
    info = self.info,
    stats = self.stats
  }
end

-- Check if validation passed
-- @return boolean
function Validator:is_valid()
  return #self.errors == 0
end

-- Get error count
-- @return number
function Validator:error_count()
  return #self.errors
end

-- Get warning count
-- @return number
function Validator:warning_count()
  return #self.warnings
end

return Validator
