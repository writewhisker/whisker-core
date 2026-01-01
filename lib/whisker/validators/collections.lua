--- WLS 1.0 Collection Validators
-- Validates LIST, ARRAY, and MAP declarations
-- @module whisker.validators.collections

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

--- Check if a string is a valid identifier
local function is_valid_identifier(str)
  return str and str:match('^[a-zA-Z_][a-zA-Z0-9_]*$') ~= nil
end

--- Validate LIST declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_lists(story)
  local issues = {}

  if not story.lists then
    return issues
  end

  for list_name, list_data in pairs(story.lists) do
    local values = list_data.values or {}

    -- Check for empty list
    if #values == 0 then
      table.insert(issues, create_issue('WLS-COL-002', {
        listName = list_name,
      }, {
        id = 'empty_list_' .. list_name,
        listName = list_name,
      }))
    end

    -- Check for duplicate values and invalid identifiers
    local seen_values = {}
    for _, v in ipairs(values) do
      local value_name = type(v) == "table" and v.value or v

      -- Check for duplicates
      if seen_values[value_name] then
        table.insert(issues, create_issue('WLS-COL-001', {
          value = value_name,
          listName = list_name,
        }, {
          id = 'dup_list_val_' .. list_name .. '_' .. value_name,
          listName = list_name,
          value = value_name,
        }))
      else
        seen_values[value_name] = true
      end

      -- Check for valid identifier
      if not is_valid_identifier(value_name) then
        table.insert(issues, create_issue('WLS-COL-003', {
          value = value_name,
          listName = list_name,
        }, {
          id = 'invalid_list_val_' .. list_name .. '_' .. tostring(value_name),
          listName = list_name,
          value = value_name,
        }))
      end
    end
  end

  return issues
end

--- Validate ARRAY declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_arrays(story)
  local issues = {}

  if not story.arrays then
    return issues
  end

  for array_name, array_data in pairs(story.arrays) do
    local elements = array_data.elements or array_data

    -- Check for duplicate and negative indices
    local seen_indices = {}

    if type(elements) == "table" then
      for i, elem in ipairs(elements) do
        local index = nil

        -- Handle both raw values and structured elements
        if type(elem) == "table" and elem.index ~= nil then
          index = elem.index
        end

        if index ~= nil then
          -- Check for negative index
          if index < 0 then
            table.insert(issues, create_issue('WLS-COL-005', {
              index = index,
              arrayName = array_name,
            }, {
              id = 'neg_array_idx_' .. array_name .. '_' .. index,
              arrayName = array_name,
              index = index,
            }))
          end

          -- Check for duplicate index
          if seen_indices[index] then
            table.insert(issues, create_issue('WLS-COL-004', {
              index = index,
              arrayName = array_name,
            }, {
              id = 'dup_array_idx_' .. array_name .. '_' .. index,
              arrayName = array_name,
              index = index,
            }))
          else
            seen_indices[index] = true
          end
        end
      end
    end
  end

  return issues
end

--- Validate MAP declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_maps(story)
  local issues = {}

  if not story.maps then
    return issues
  end

  for map_name, map_data in pairs(story.maps) do
    local entries = map_data.entries or map_data

    -- Check for duplicate keys and invalid key names
    local seen_keys = {}

    if type(entries) == "table" then
      -- Handle structured entries from parser
      if entries[1] and type(entries[1]) == "table" and entries[1].key then
        for _, entry in ipairs(entries) do
          local key = entry.key

          -- Check for duplicates
          if seen_keys[key] then
            table.insert(issues, create_issue('WLS-COL-006', {
              key = key,
              mapName = map_name,
            }, {
              id = 'dup_map_key_' .. map_name .. '_' .. key,
              mapName = map_name,
              key = key,
            }))
          else
            seen_keys[key] = true
          end

          -- Check for valid key (identifier or string is OK)
          if type(key) ~= "string" then
            table.insert(issues, create_issue('WLS-COL-007', {
              key = tostring(key),
              mapName = map_name,
            }, {
              id = 'invalid_map_key_' .. map_name .. '_' .. tostring(key),
              mapName = map_name,
              key = tostring(key),
            }))
          end
        end
      else
        -- Handle plain table format
        for key, _ in pairs(entries) do
          if seen_keys[key] then
            table.insert(issues, create_issue('WLS-COL-006', {
              key = key,
              mapName = map_name,
            }, {
              id = 'dup_map_key_' .. map_name .. '_' .. key,
              mapName = map_name,
              key = key,
            }))
          else
            seen_keys[key] = true
          end
        end
      end
    end
  end

  return issues
end

--- Validate undefined collection references
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_undefined_collections(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Build sets of defined collections
  local defined_lists = {}
  local defined_arrays = {}
  local defined_maps = {}

  if story.lists then
    for name, _ in pairs(story.lists) do
      defined_lists[name] = true
    end
  end

  if story.arrays then
    for name, _ in pairs(story.arrays) do
      defined_arrays[name] = true
    end
  end

  if story.maps then
    for name, _ in pairs(story.maps) do
      defined_maps[name] = true
    end
  end

  -- Search for collection API calls in passage content
  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Check for list references: list_contains("name", ...) or similar
      for list_name in passage.content:gmatch('list_[%w_]+%s*%(%s*["\']([^"\']+)["\']') do
        if not defined_lists[list_name] then
          table.insert(issues, create_issue('WLS-COL-008', {
            listName = list_name,
          }, {
            id = 'undef_list_' .. list_name .. '_' .. passage_id,
            listName = list_name,
            passageId = passage_id,
            passageTitle = passage.title,
          }))
        end
      end

      -- Check for array references
      for array_name in passage.content:gmatch('array_[%w_]+%s*%(%s*["\']([^"\']+)["\']') do
        if not defined_arrays[array_name] then
          table.insert(issues, create_issue('WLS-COL-009', {
            arrayName = array_name,
          }, {
            id = 'undef_array_' .. array_name .. '_' .. passage_id,
            arrayName = array_name,
            passageId = passage_id,
            passageTitle = passage.title,
          }))
        end
      end

      -- Check for map references
      for map_name in passage.content:gmatch('map_[%w_]+%s*%(%s*["\']([^"\']+)["\']') do
        if not defined_maps[map_name] then
          table.insert(issues, create_issue('WLS-COL-010', {
            mapName = map_name,
          }, {
            id = 'undef_map_' .. map_name .. '_' .. passage_id,
            mapName = map_name,
            passageId = passage_id,
            passageTitle = passage.title,
          }))
        end
      end
    end
  end

  return issues
end

--- Run all collection validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_lists,
    M.validate_arrays,
    M.validate_maps,
    M.validate_undefined_collections,
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
