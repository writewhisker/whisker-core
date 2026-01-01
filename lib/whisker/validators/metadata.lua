--- WLS 1.0 Metadata Validators
-- Validates metadata: IFID, dimensions, reserved keys
-- @module whisker.validators.metadata

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Default thresholds
M.THRESHOLDS = {
  max_metadata_size = 64 * 1024, -- 64KB
}

--- Reserved metadata keys that conflict with built-in properties
M.RESERVED_KEYS = {
  'id', 'name', 'title', 'content', 'choices', 'tags',
  'position', 'size', 'start_passage', 'startPassage',
  'passages', 'variables', 'assets', 'scripts', 'stylesheets',
  'format', 'formatVersion', 'creator', 'creatorVersion',
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

--- Format bytes as human readable
local function format_size(bytes)
  if bytes < 1024 then
    return bytes .. ' B'
  elseif bytes < 1024 * 1024 then
    return string.format('%.1f KB', bytes / 1024)
  else
    return string.format('%.1f MB', bytes / (1024 * 1024))
  end
end

--- Validate UUID v4 format
-- @param uuid string The UUID to validate
-- @return boolean True if valid UUID v4
local function is_valid_uuid4(uuid)
  if not uuid or type(uuid) ~= 'string' then
    return false
  end

  -- UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  -- where y is 8, 9, A, or B
  local pattern = '^[0-9a-fA-F]%x%x%x%x%x%x%x%-[0-9a-fA-F]%x%x%x%-4[0-9a-fA-F]%x%x%-[89aAbB][0-9a-fA-F]%x%x%-[0-9a-fA-F]%x%x%x%x%x%x%x%x%x%x%x$'

  return uuid:match(pattern) ~= nil
end

--- Estimate size of a value in bytes
-- @param value any The value to estimate
-- @return number Approximate size in bytes
local function estimate_size(value)
  local t = type(value)
  if t == 'string' then
    return #value
  elseif t == 'number' then
    return 8
  elseif t == 'boolean' then
    return 1
  elseif t == 'table' then
    local size = 0
    for k, v in pairs(value) do
      size = size + estimate_size(k) + estimate_size(v)
    end
    return size
  else
    return 0
  end
end

--- Validate IFID presence
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_ifid_presence(story)
  local issues = {}

  -- Check for IFID in metadata or as direct property
  local ifid = story.ifid or (story.metadata and story.metadata.ifid)

  if not ifid then
    table.insert(issues, create_issue('WLS-META-001', {}, {
      id = 'missing_ifid',
      fixable = true,
      fixDescription = 'Generate and add an IFID (Interactive Fiction ID)',
    }))
  end

  return issues
end

--- Validate IFID format
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_ifid_format(story)
  local issues = {}

  local ifid = story.ifid or (story.metadata and story.metadata.ifid)

  if ifid and not is_valid_uuid4(ifid) then
    table.insert(issues, create_issue('WLS-META-002', {}, {
      id = 'invalid_ifid',
      ifid = ifid,
    }))
  end

  return issues
end

--- Validate passage dimensions
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_dimensions(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    -- Check position
    if passage.position then
      if type(passage.position.x) == 'number' and passage.position.x < 0 then
        table.insert(issues, create_issue('WLS-META-003', {}, {
          id = 'invalid_dim_pos_x_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
          field = 'position.x',
          value = passage.position.x,
        }))
      end
      if type(passage.position.y) == 'number' and passage.position.y < 0 then
        table.insert(issues, create_issue('WLS-META-003', {}, {
          id = 'invalid_dim_pos_y_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
          field = 'position.y',
          value = passage.position.y,
        }))
      end
    end

    -- Check size
    if passage.size then
      if type(passage.size.width) == 'number' and passage.size.width <= 0 then
        table.insert(issues, create_issue('WLS-META-003', {}, {
          id = 'invalid_dim_width_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
          field = 'size.width',
          value = passage.size.width,
        }))
      end
      if type(passage.size.height) == 'number' and passage.size.height <= 0 then
        table.insert(issues, create_issue('WLS-META-003', {}, {
          id = 'invalid_dim_height_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
          field = 'size.height',
          value = passage.size.height,
        }))
      end
    end
  end

  return issues
end

--- Validate reserved metadata keys
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_reserved_keys(story)
  local issues = {}

  -- Build lookup table
  local reserved = {}
  for _, key in ipairs(M.RESERVED_KEYS) do
    reserved[key] = true
  end

  -- Check story metadata
  if story.metadata then
    for key, _ in pairs(story.metadata) do
      if reserved[key] then
        table.insert(issues, create_issue('WLS-META-004', {
          key = key,
        }, {
          id = 'reserved_key_story_' .. key,
          key = key,
          level = 'story',
        }))
      end
    end
  end

  -- Check passage metadata
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if passage.metadata then
        for key, _ in pairs(passage.metadata) do
          if reserved[key] then
            table.insert(issues, create_issue('WLS-META-004', {
              key = key,
            }, {
              id = 'reserved_key_' .. passage_id .. '_' .. key,
              passageId = passage_id,
              passageTitle = passage.title,
              key = key,
              level = 'passage',
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Validate metadata size
-- @param story table The story to validate
-- @param threshold number Maximum metadata size in bytes
-- @return table Array of validation issues
function M.validate_metadata_size(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_metadata_size

  -- Check story metadata
  if story.metadata then
    local size = estimate_size(story.metadata)
    if size > threshold then
      table.insert(issues, create_issue('WLS-META-005', {
        size = format_size(size),
      }, {
        id = 'large_metadata_story',
        size = size,
        threshold = threshold,
      }))
    end
  end

  -- Check passage metadata
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if passage.metadata then
        local size = estimate_size(passage.metadata)
        if size > threshold then
          table.insert(issues, create_issue('WLS-META-005', {
            size = format_size(size),
          }, {
            id = 'large_metadata_' .. passage_id,
            passageId = passage_id,
            passageTitle = passage.title,
            size = size,
            threshold = threshold,
          }))
        end
      end
    end
  end

  return issues
end

--- Run all metadata validators
-- @param story table The story to validate
-- @param options table Optional thresholds
-- @return table Array of validation issues
function M.validate(story, options)
  options = options or {}
  local all_issues = {}

  local validators = {
    M.validate_ifid_presence,
    M.validate_ifid_format,
    M.validate_dimensions,
    M.validate_reserved_keys,
    function(s) return M.validate_metadata_size(s, options.max_metadata_size) end,
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
