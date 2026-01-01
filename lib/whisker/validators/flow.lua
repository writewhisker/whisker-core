--- WLS 1.0 Flow Validators
-- Validates story flow: dead ends, cycles, navigation
-- @module whisker.validators.flow

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Create a validation issue
local function create_issue(code, context, extra)
  local def = error_codes.get_error_code(code)
  if not def then
    return nil
  end

  local issue = {
    id = (extra and extra.id) or (def.name .. '_' .. os.time()),
    code = code,
    severity = def.severity,
    category = def.category,
    message = error_codes.format_message(code, context),
    description = def.description,
    context = context,
    fixable = (extra and extra.fixable) or false,
  }

  if extra then
    for k, v in pairs(extra) do
      if k ~= 'id' and k ~= 'fixable' then
        issue[k] = v
      end
    end
  end

  return issue
end

--- Special targets that are valid endings
local SPECIAL_TARGETS = {
  END = true,
  BACK = true,
  RESTART = true,
}

--- Check if a passage has a valid exit
-- A passage has a valid exit if it has choices or if it's a terminal passage
-- @param passage table The passage to check
-- @return boolean True if passage has valid exit
local function has_valid_exit(passage)
  -- Has choices with targets
  if passage.choices and #passage.choices > 0 then
    for _, choice in ipairs(passage.choices) do
      if choice.target and choice.target ~= '' then
        return true
      end
    end
  end
  return false
end

--- Validate dead ends (passages with no choices/exits)
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_dead_ends(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for id, passage in pairs(story.passages) do
    if not has_valid_exit(passage) then
      table.insert(issues, create_issue('WLS-FLW-001', {
        passageName = passage.title or id,
      }, {
        id = 'dead_end_' .. id,
        passageId = id,
        passageTitle = passage.title,
      }))
    end
  end

  return issues
end

--- Validate bottleneck passages (all paths must pass through)
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_bottlenecks(story)
  local issues = {}

  if not story.passages or not story.start_passage then
    return issues
  end

  -- Build adjacency list
  local adj = {}
  local all_ids = {}
  for id, passage in pairs(story.passages) do
    all_ids[id] = true
    adj[id] = {}
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target and choice.target ~= '' then
          if choice.target ~= 'END' and choice.target ~= 'BACK' and choice.target ~= 'RESTART' then
            if story.passages[choice.target] then
              table.insert(adj[id], choice.target)
            end
          end
        end
      end
    end
  end

  -- Find terminal passages
  local terminals = {}
  for id, passage in pairs(story.passages) do
    if not passage.choices or #passage.choices == 0 then
      terminals[id] = true
    else
      for _, choice in ipairs(passage.choices) do
        if choice.target == 'END' then
          terminals[id] = true
          break
        end
      end
    end
  end

  -- For each non-start, non-terminal passage, check if removing it disconnects start from terminals
  for passage_id, passage in pairs(story.passages) do
    if passage_id ~= story.start_passage and not terminals[passage_id] then
      -- BFS from start without this passage
      local visited = { [passage_id] = true }
      local queue = { story.start_passage }
      visited[story.start_passage] = true

      while #queue > 0 do
        local current = table.remove(queue, 1)
        for _, neighbor in ipairs(adj[current] or {}) do
          if not visited[neighbor] then
            visited[neighbor] = true
            table.insert(queue, neighbor)
          end
        end
      end

      -- Check if any terminal is unreachable
      local all_terminals_unreachable = true
      for term_id, _ in pairs(terminals) do
        if visited[term_id] then
          all_terminals_unreachable = false
          break
        end
      end

      if all_terminals_unreachable and next(terminals) then
        table.insert(issues, create_issue('WLS-FLW-002', {
          passageName = passage.title or passage_id,
        }, {
          id = 'bottleneck_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
        }))
      end
    end
  end

  return issues
end

--- Validate cycles in story
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_cycles(story)
  local issues = {}

  if not story.passages or not story.start_passage then
    return issues
  end

  -- DFS to detect cycles
  local visited = {}
  local in_stack = {}
  local has_cycle = false

  local function dfs(passage_id)
    if has_cycle then return end
    if in_stack[passage_id] then
      has_cycle = true
      return
    end
    if visited[passage_id] then return end

    visited[passage_id] = true
    in_stack[passage_id] = true

    local passage = story.passages[passage_id]
    if passage and passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target and choice.target ~= '' then
          if choice.target ~= 'END' and choice.target ~= 'BACK' and choice.target ~= 'RESTART' then
            if story.passages[choice.target] then
              dfs(choice.target)
            end
          end
        end
      end
    end

    in_stack[passage_id] = nil
  end

  dfs(story.start_passage)

  if has_cycle then
    table.insert(issues, create_issue('WLS-FLW-003', {}, {
      id = 'cycle_detected',
    }))
  end

  return issues
end

--- Validate potential infinite loops
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_infinite_loops(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Look for passages that only link back to themselves without state change
  for passage_id, passage in pairs(story.passages) do
    if passage.choices and #passage.choices > 0 then
      local all_self_links = true
      local has_state_change = false

      for _, choice in ipairs(passage.choices) do
        if choice.target ~= passage_id and choice.target ~= passage.title then
          all_self_links = false
        end
        if choice.action then
          has_state_change = true
        end
      end

      -- Check onEnterScript for state changes
      if passage.onEnterScript and passage.onEnterScript:match('=') then
        has_state_change = true
      end

      if all_self_links and not has_state_change then
        table.insert(issues, create_issue('WLS-FLW-004', {
          passageName = passage.title or passage_id,
        }, {
          id = 'infinite_loop_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
        }))
      end
    end
  end

  return issues
end

--- Validate unreachable choices (condition always false)
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unreachable_choices(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if choice.condition then
          -- Check for obvious always-false conditions
          local cond = choice.condition:lower()
          if cond == 'false' or cond == 'nil' or cond == '0' then
            table.insert(issues, create_issue('WLS-FLW-005', {}, {
              id = 'unreachable_choice_' .. passage_id .. '_' .. i,
              passageId = passage_id,
              passageTitle = passage.title,
              choiceIndex = i,
              choiceText = choice.text,
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Validate always-true conditions
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_always_true(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if choice.condition then
          -- Check for obvious always-true conditions
          local cond = choice.condition:lower()
          if cond == 'true' or cond == '1' then
            table.insert(issues, create_issue('WLS-FLW-006', {}, {
              id = 'always_true_' .. passage_id .. '_' .. i,
              passageId = passage_id,
              passageTitle = passage.title,
              choiceIndex = i,
              choiceText = choice.text,
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Run all flow validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_dead_ends,
    M.validate_bottlenecks,
    M.validate_cycles,
    M.validate_infinite_loops,
    M.validate_unreachable_choices,
    M.validate_always_true,
  }

  for _, validator in ipairs(validators) do
    local issues = validator(story)
    for _, issue in ipairs(issues) do
      table.insert(all_issues, issue)
    end
  end

  return all_issues
end

return M
