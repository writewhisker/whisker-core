--- WLS 1.0 Structural Validators
-- Validates story structure: start passage, unreachable passages, duplicates
-- @module whisker.validators.structural

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Create a validation issue
local function create_issue(code, context, extra)
  local def = error_codes.get_error_code(code)
  if not def then
    return nil
  end

  local issue = {
    id = (extra and extra.id) or (def.name .. '_' .. (context.passageId or os.time())),
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

--- Validate start passage exists
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_start_passage(story)
  local issues = {}

  if not story.start_passage or story.start_passage == '' then
    table.insert(issues, create_issue('WLS-STR-001', {}, {
      id = 'missing_start_passage',
    }))
    return issues
  end

  -- Check if start passage exists
  local found = false
  for id, _ in pairs(story.passages or {}) do
    if id == story.start_passage then
      found = true
      break
    end
  end

  if not found then
    table.insert(issues, create_issue('WLS-STR-001', {
      passageName = story.start_passage,
    }, {
      id = 'invalid_start_passage',
    }))
  end

  return issues
end

--- Validate no unreachable passages
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unreachable(story)
  local issues = {}

  if not story.start_passage or not story.passages then
    return issues
  end

  -- Build a map of reachable passage names (for duplicate checking)
  local reachable_names = {}

  -- Mark start passage as reachable
  local reachable = {}
  local queue = {}

  -- Find start passage and mark it reachable
  local start_passage = story.passages[story.start_passage]
  if start_passage then
    reachable[story.start_passage] = true
    table.insert(queue, story.start_passage)
    local name = (start_passage.title or start_passage.name or story.start_passage):lower()
    reachable_names[name] = true
  end

  -- BFS to find reachable passages
  while #queue > 0 do
    local current_id = table.remove(queue, 1)
    local passage = story.passages[current_id]

    if passage and passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target and not reachable[choice.target] then
          -- Skip special targets
          if choice.target ~= 'END' and choice.target ~= 'BACK' and choice.target ~= 'RESTART' then
            reachable[choice.target] = true
            table.insert(queue, choice.target)
            -- Track reachable names
            local target_passage = story.passages[choice.target]
            if target_passage then
              local name = (target_passage.title or target_passage.name or choice.target):lower()
              reachable_names[name] = true
            end
          end
        end
      end
    end
  end

  -- Find unreachable passages (skip duplicates of reachable passages by name)
  for id, passage in pairs(story.passages) do
    if not reachable[id] then
      -- Check if this passage's name matches a reachable passage's name (duplicate)
      local passage_name = (passage.title or passage.name or id):lower()
      local is_dup_of_reachable = reachable_names[passage_name]

      if not is_dup_of_reachable then
        table.insert(issues, create_issue('WLS-STR-002', {
          passageName = passage.title or passage.name or id,
        }, {
          id = 'unreachable_' .. id,
          passageId = id,
          passageTitle = passage.title,
          fixable = true,
          fixDescription = 'Delete this passage or add a link to it',
        }))
      end
    end
  end

  return issues
end

--- Validate no duplicate passage names
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_duplicates(story)
  local issues = {}
  local reported_names = {}

  -- Check duplicate_passages from parser (exact duplicates)
  if story.duplicate_passages then
    for name, count in pairs(story.duplicate_passages) do
      table.insert(issues, create_issue('WLS-STR-003', {
        passageName = name,
        count = count,
      }, {
        id = 'duplicate_passage_' .. name,
        passageId = name,
        passageTitle = name,
      }))
      reported_names[name:lower()] = true
    end
  end

  -- Also check for case-insensitive duplicates in passages table
  -- Skip names already reported from duplicate_passages
  if story.passages then
    local by_lower = {}
    for id, passage in pairs(story.passages) do
      local title = passage.title or passage.name or id
      local title_lower = title:lower()
      if not by_lower[title_lower] then
        by_lower[title_lower] = {}
      end
      table.insert(by_lower[title_lower], { id = id, passage = passage, title = title })
    end

    for title_lower, passages in pairs(by_lower) do
      -- Only report if not already reported and has multiple passages with different exact names
      if #passages > 1 and not reported_names[title_lower] then
        -- Check if these are actually different names (case-insensitive duplicates)
        local first_title = passages[1].title
        local has_different_names = false
        for i = 2, #passages do
          if passages[i].title ~= first_title then
            has_different_names = true
            break
          end
        end

        if has_different_names then
          local first = passages[1]
          table.insert(issues, create_issue('WLS-STR-003', {
            passageName = first.title,
            count = #passages,
          }, {
            id = 'duplicate_passage_case_' .. first.id,
            passageId = first.id,
            passageTitle = first.title,
          }))
        end
      end
    end
  end

  return issues
end

--- Validate empty passages
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_empty(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for id, passage in pairs(story.passages) do
    local content = passage.content or ''
    local has_content = content:match('%S') ~= nil

    if not has_content then
      table.insert(issues, create_issue('WLS-STR-004', {
        passageName = passage.title or id,
      }, {
        id = 'empty_content_' .. id,
        passageId = id,
        passageTitle = passage.title,
      }))
    end
  end

  return issues
end

--- Validate orphan passages (no incoming links except start)
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_orphans(story)
  local issues = {}

  if not story.passages or not story.start_passage then
    return issues
  end

  -- Build set of passages that have incoming links
  local has_incoming = {}
  has_incoming[story.start_passage] = true -- Start is not orphan

  for _, passage in pairs(story.passages) do
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target and choice.target ~= '' then
          -- Skip special targets
          if choice.target ~= 'END' and choice.target ~= 'BACK' and choice.target ~= 'RESTART' then
            has_incoming[choice.target] = true
          end
        end
      end
    end
  end

  -- Find orphans
  for id, passage in pairs(story.passages) do
    if not has_incoming[id] and id ~= story.start_passage then
      table.insert(issues, create_issue('WLS-STR-005', {
        passageName = passage.title or passage.name or id,
      }, {
        id = 'orphan_' .. id,
        passageId = id,
        passageTitle = passage.title,
      }))
    end
  end

  return issues
end

--- Special targets that are valid exits
local SPECIAL_TARGETS = {
  END = true,
  BACK = true,
  RESTART = true,
}

--- Validate story has terminal passages
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_terminals(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  local has_terminal = false

  for _, passage in pairs(story.passages) do
    -- Check if passage is terminal (no choices or has END)
    if not passage.choices or #passage.choices == 0 then
      has_terminal = true
      break
    end

    -- Check for END target
    for _, choice in ipairs(passage.choices) do
      if choice.target == 'END' then
        has_terminal = true
        break
      end
    end

    if has_terminal then
      break
    end
  end

  if not has_terminal then
    table.insert(issues, create_issue('WLS-STR-006', {}, {
      id = 'no_terminal',
    }))
  end

  return issues
end

--- Run all structural validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_start_passage,
    M.validate_duplicates,
    M.validate_unreachable,
    M.validate_empty,
    M.validate_orphans,
    M.validate_terminals,
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
