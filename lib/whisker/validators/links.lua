--- WLS 1.0 Link Validators
-- Validates choice links: dead links, self-links, special targets
-- @module whisker.validators.links

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Special targets for navigation
local SPECIAL_TARGETS = {
  END = true,
  BACK = true,
  RESTART = true,
}

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

--- Validate dead links
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_dead_links(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Collect all passage IDs
  local passage_ids = {}
  for id, _ in pairs(story.passages) do
    passage_ids[id] = true
  end

  -- Check all choices
  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if choice.target and choice.target ~= '' then
          -- Skip special targets (exact case)
          if SPECIAL_TARGETS[choice.target] then
            -- Valid special target
          -- Skip wrong-case special targets (handled by validate_special_target_case)
          elseif SPECIAL_TARGETS[choice.target:upper()] then
            -- Will be flagged as WLS-LNK-003 instead
          elseif not passage_ids[choice.target] then
            table.insert(issues, create_issue('WLS-LNK-001', {
              targetPassage = choice.target,
              passageName = passage.title or passage_id,
              choiceText = choice.text or ('Choice ' .. i),
            }, {
              id = 'dead_link_' .. passage_id .. '_' .. i,
              passageId = passage_id,
              passageTitle = passage.title,
              choiceId = choice.id or i,
              fixable = true,
              fixDescription = 'Remove this choice or create the target passage',
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Validate self-links without state change
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_self_links(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if choice.target == passage_id then
          -- Check if there's any state change
          local has_action = choice.action and choice.action:match('%S')

          if not has_action then
            table.insert(issues, create_issue('WLS-LNK-002', {
              passageName = passage.title or passage_id,
              choiceText = choice.text or ('Choice ' .. i),
            }, {
              id = 'self_link_' .. passage_id .. '_' .. i,
              passageId = passage_id,
              passageTitle = passage.title,
              choiceId = choice.id or i,
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Validate empty choice targets
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_empty_targets(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if not choice.target or choice.target == '' then
          table.insert(issues, create_issue('WLS-LNK-005', {
            passageName = passage.title or passage_id,
            choiceText = choice.text or ('Choice ' .. i),
          }, {
            id = 'empty_target_' .. passage_id .. '_' .. i,
            passageId = passage_id,
            passageTitle = passage.title,
            choiceId = choice.id or i,
          }))
        end
      end
    end
  end

  return issues
end

--- Validate special target case
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_special_target_case(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Collect all passage IDs to avoid false positives
  local passage_ids = {}
  for id, _ in pairs(story.passages) do
    passage_ids[id] = true
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for i, choice in ipairs(passage.choices) do
        if choice.target then
          -- If target is a valid passage, don't flag it
          if passage_ids[choice.target] then
            -- This is a link to an actual passage, not a special target
          else
            local upper = choice.target:upper()
            if SPECIAL_TARGETS[upper] and not SPECIAL_TARGETS[choice.target] then
              table.insert(issues, create_issue('WLS-LNK-003', {
                actual = choice.target,
                expected = upper,
              }, {
                id = 'special_target_case_' .. passage_id .. '_' .. i,
                passageId = passage_id,
                passageTitle = passage.title,
                choiceId = choice.id or i,
                fixable = true,
                fixDescription = 'Change to "' .. upper .. '"',
              }))
            end
          end
        end
      end
    end
  end

  return issues
end

--- Validate BACK on start passage
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_back_on_start(story)
  local issues = {}

  if not story.start_passage or not story.passages then
    return issues
  end

  local start_passage = story.passages[story.start_passage]
  if not start_passage or not start_passage.choices then
    return issues
  end

  for i, choice in ipairs(start_passage.choices) do
    if choice.target == 'BACK' and #start_passage.choices == 1 then
      table.insert(issues, create_issue('WLS-LNK-004', {
        passageName = start_passage.title or story.start_passage,
      }, {
        id = 'back_on_start_' .. story.start_passage .. '_' .. i,
        passageId = story.start_passage,
        passageTitle = start_passage.title,
        choiceId = choice.id or i,
      }))
    end
  end

  return issues
end

--- Run all link validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_dead_links,
    M.validate_self_links,
    M.validate_empty_targets,
    M.validate_special_target_case,
    M.validate_back_on_start,
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
