--- WLS 1.0 Asset Validators
-- Validates assets: IDs, paths, references, properties
-- @module whisker.validators.assets

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Default thresholds
M.THRESHOLDS = {
  max_asset_size = 5 * 1024 * 1024, -- 5MB
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

--- Extract asset references from content
-- @param content string The content to analyze
-- @return table Set of asset IDs referenced
local function extract_asset_refs(content)
  local refs = {}

  if not content then
    return refs
  end

  -- Match asset:// protocol
  for asset_id in content:gmatch('asset://([%w_%-]+)') do
    refs[asset_id] = true
  end

  -- Match [asset:id] notation
  for asset_id in content:gmatch('%[asset:([%w_%-]+)%]') do
    refs[asset_id] = true
  end

  return refs
end

--- Validate asset IDs
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_asset_ids(story)
  local issues = {}

  if not story.assets then
    return issues
  end

  for i, asset in ipairs(story.assets) do
    if not asset.id or asset.id == '' then
      table.insert(issues, create_issue('WLS-AST-001', {}, {
        id = 'missing_asset_id_' .. i,
        assetIndex = i,
      }))
    end
  end

  return issues
end

--- Validate asset paths
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_asset_paths(story)
  local issues = {}

  if not story.assets then
    return issues
  end

  for _, asset in ipairs(story.assets) do
    local asset_id = asset.id or 'unknown'
    -- Check for path or data URI
    if not asset.path and not asset.data and not asset.dataUri then
      table.insert(issues, create_issue('WLS-AST-002', {
        assetId = asset_id,
      }, {
        id = 'missing_path_' .. asset_id,
        assetId = asset_id,
      }))
    end
  end

  return issues
end

--- Validate asset references
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_asset_refs(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Collect all asset IDs
  local asset_ids = {}
  if story.assets then
    for _, asset in ipairs(story.assets) do
      if asset.id then
        asset_ids[asset.id] = true
      end
    end
  end

  -- Check references in passages
  for passage_id, passage in pairs(story.passages) do
    local refs = extract_asset_refs(passage.content)
    for asset_id, _ in pairs(refs) do
      if not asset_ids[asset_id] then
        table.insert(issues, create_issue('WLS-AST-003', {
          assetId = asset_id,
        }, {
          id = 'broken_ref_' .. asset_id .. '_' .. passage_id,
          assetId = asset_id,
          passageId = passage_id,
          passageTitle = passage.title,
        }))
      end
    end
  end

  return issues
end

--- Validate unused assets
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unused_assets(story)
  local issues = {}

  if not story.assets or not story.passages then
    return issues
  end

  -- Collect all references
  local referenced = {}
  for _, passage in pairs(story.passages) do
    local refs = extract_asset_refs(passage.content)
    for asset_id, _ in pairs(refs) do
      referenced[asset_id] = true
    end
  end

  -- Find unused
  for _, asset in ipairs(story.assets) do
    local asset_id = asset.id
    local asset_name = asset.name or asset_id or 'unknown'
    if asset_id and not referenced[asset_id] then
      table.insert(issues, create_issue('WLS-AST-004', {
        assetName = asset_name,
      }, {
        id = 'unused_asset_' .. asset_id,
        assetId = asset_id,
        assetName = asset_name,
        fixable = true,
        fixDescription = 'Remove unused asset or add reference to it',
      }))
    end
  end

  return issues
end

--- Validate asset names
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_asset_names(story)
  local issues = {}

  if not story.assets then
    return issues
  end

  for _, asset in ipairs(story.assets) do
    local asset_id = asset.id or 'unknown'
    if not asset.name or asset.name == '' then
      table.insert(issues, create_issue('WLS-AST-005', {
        assetId = asset_id,
      }, {
        id = 'missing_name_' .. asset_id,
        assetId = asset_id,
      }))
    end
  end

  return issues
end

--- Validate asset MIME types
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_asset_mimetypes(story)
  local issues = {}

  if not story.assets then
    return issues
  end

  for _, asset in ipairs(story.assets) do
    local asset_id = asset.id or 'unknown'
    if not asset.mimeType and not asset.type then
      table.insert(issues, create_issue('WLS-AST-006', {
        assetId = asset_id,
      }, {
        id = 'missing_mimetype_' .. asset_id,
        assetId = asset_id,
      }))
    end
  end

  return issues
end

--- Validate asset sizes
-- @param story table The story to validate
-- @param threshold number Maximum asset size in bytes
-- @return table Array of validation issues
function M.validate_asset_sizes(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_asset_size

  if not story.assets then
    return issues
  end

  for _, asset in ipairs(story.assets) do
    local asset_id = asset.id or 'unknown'
    local asset_name = asset.name or asset_id
    local size = asset.size or 0

    if size > threshold then
      table.insert(issues, create_issue('WLS-AST-007', {
        assetName = asset_name,
        size = format_size(size),
      }, {
        id = 'large_asset_' .. asset_id,
        assetId = asset_id,
        assetName = asset_name,
        size = size,
        threshold = threshold,
      }))
    end
  end

  return issues
end

--- Run all asset validators
-- @param story table The story to validate
-- @param options table Optional thresholds
-- @return table Array of validation issues
function M.validate(story, options)
  options = options or {}
  local all_issues = {}

  local validators = {
    M.validate_asset_ids,
    M.validate_asset_paths,
    M.validate_asset_refs,
    M.validate_unused_assets,
    M.validate_asset_names,
    M.validate_asset_mimetypes,
    function(s) return M.validate_asset_sizes(s, options.max_asset_size) end,
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
