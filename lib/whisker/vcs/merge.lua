--- Story Merge Algorithm
-- Provides three-way merge capabilities for Whisker stories
-- @module whisker.vcs.merge
-- @author Whisker Core Team
-- @license MIT

local merge = {}

-- Load diff module
local ok_diff, diff_module = pcall(require, "whisker.vcs.diff")
if not ok_diff then
  diff_module = { diff_stories = function() return { passage_changes = {}, variable_changes = {}, metadata_changes = {} } end }
end

--- Conflict types
merge.CONFLICT_TYPES = {
  PASSAGE_CONTENT = "passage-content",
  PASSAGE_TITLE = "passage-title",
  PASSAGE_SCRIPT = "passage-script",
  PASSAGE_DELETED = "passage-deleted",
  CHOICE_MODIFIED = "choice-modified",
  CHOICE_DELETED = "choice-deleted",
  VARIABLE_VALUE = "variable-value",
  VARIABLE_TYPE = "variable-type",
  VARIABLE_DELETED = "variable-deleted",
  METADATA = "metadata",
  SETTINGS = "settings",
}

--- Resolution strategies
merge.STRATEGIES = {
  LOCAL = "local",
  REMOTE = "remote",
  BASE = "base",
  MANUAL = "manual",
}

--- Deep copy a table
-- @param orig table Original table
-- @return table Deep copy
local function deep_copy(orig)
  if type(orig) ~= "table" then
    return orig
  end
  local copy = {}
  for k, v in pairs(orig) do
    copy[deep_copy(k)] = deep_copy(v)
  end
  return copy
end

--- Perform a three-way merge of stories
-- @param base table Common ancestor version
-- @param local_version table Local version
-- @param remote table Remote version
-- @param options table Merge options
-- @return table Merge result with conflicts
function merge.merge_stories(base, local_version, remote, options)
  options = options or {}
  local strategy = options.strategy or merge.STRATEGIES.MANUAL
  local ignore_positions = options.ignore_positions ~= false
  local ignore_timestamps = options.ignore_timestamps ~= false
  local auto_resolve_non_content = options.auto_resolve_non_content ~= false

  local conflicts = {}
  local auto_resolved = 0

  -- Compute diffs from base
  local local_diff = diff_module.diff_stories(base, local_version, {
    ignore_positions = ignore_positions,
    ignore_timestamps = ignore_timestamps,
  })
  local remote_diff = diff_module.diff_stories(base, remote, {
    ignore_positions = ignore_positions,
    ignore_timestamps = ignore_timestamps,
  })

  -- Start with base as foundation
  local merged = deep_copy(base)

  -- Merge metadata
  local meta_result = merge._merge_metadata(
    base.metadata or {},
    local_version.metadata or {},
    remote.metadata or {},
    local_diff, remote_diff
  )
  merged.metadata = meta_result.merged
  for _, c in ipairs(meta_result.conflicts) do table.insert(conflicts, c) end

  -- Merge passages
  local passages_result = merge._merge_passages(
    base.passages or {},
    local_version.passages or {},
    remote.passages or {},
    local_diff, remote_diff
  )
  merged.passages = passages_result.merged
  for _, c in ipairs(passages_result.conflicts) do table.insert(conflicts, c) end

  -- Merge variables
  local vars_result = merge._merge_variables(
    base.variables or {},
    local_version.variables or {},
    remote.variables or {},
    local_diff, remote_diff
  )
  merged.variables = vars_result.merged
  for _, c in ipairs(vars_result.conflicts) do table.insert(conflicts, c) end

  -- Merge settings
  local settings_result = merge._merge_settings(
    base.settings or {},
    local_version.settings or {},
    remote.settings or {}
  )
  merged.settings = settings_result.merged
  for _, c in ipairs(settings_result.conflicts) do table.insert(conflicts, c) end

  -- Merge start passage
  if local_version.startPassage ~= base.startPassage and remote.startPassage ~= base.startPassage then
    if local_version.startPassage ~= remote.startPassage then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.METADATA,
        path = "startPassage",
        description = "Both versions changed the start passage",
        base = base.startPassage,
        local_val = local_version.startPassage,
        remote = remote.startPassage,
      })
      merged.startPassage = local_version.startPassage
    else
      merged.startPassage = local_version.startPassage
      auto_resolved = auto_resolved + 1
    end
  elseif local_version.startPassage ~= base.startPassage then
    merged.startPassage = local_version.startPassage
  elseif remote.startPassage ~= base.startPassage then
    merged.startPassage = remote.startPassage
  end

  -- Auto-resolve based on strategy
  if strategy ~= merge.STRATEGIES.MANUAL then
    for _, conflict in ipairs(conflicts) do
      if strategy == merge.STRATEGIES.LOCAL then
        merge._apply_resolution(merged, conflict, merge.STRATEGIES.LOCAL)
        auto_resolved = auto_resolved + 1
      elseif strategy == merge.STRATEGIES.REMOTE then
        merge._apply_resolution(merged, conflict, merge.STRATEGIES.REMOTE)
        auto_resolved = auto_resolved + 1
      elseif strategy == merge.STRATEGIES.BASE then
        merge._apply_resolution(merged, conflict, merge.STRATEGIES.BASE)
        auto_resolved = auto_resolved + 1
      end
    end
  end

  -- Auto-resolve non-content conflicts if enabled
  if auto_resolve_non_content and strategy == merge.STRATEGIES.MANUAL then
    for _, conflict in ipairs(conflicts) do
      if merge._is_non_content_conflict(conflict) then
        merge._apply_resolution(merged, conflict, merge.STRATEGIES.LOCAL)
        auto_resolved = auto_resolved + 1
      end
    end
  end

  -- Count conflicts requiring resolution
  local requires_resolution = 0
  if strategy == merge.STRATEGIES.MANUAL then
    for _, conflict in ipairs(conflicts) do
      if not merge._is_non_content_conflict(conflict) or not auto_resolve_non_content then
        requires_resolution = requires_resolution + 1
      end
    end
  end

  return {
    success = requires_resolution == 0,
    merged = merged,
    conflicts = conflicts,
    auto_resolved = auto_resolved,
    requires_resolution = requires_resolution,
  }
end

--- Merge metadata
function merge._merge_metadata(base, local_version, remote, local_diff, remote_diff)
  local conflicts = {}
  local merged = deep_copy(base)

  -- Simple fields
  for _, field in ipairs({ "title", "author", "version", "description" }) do
    local local_changed = false
    local remote_changed = false

    for _, m in ipairs(local_diff.metadata_changes or {}) do
      if m.field == field then local_changed = true break end
    end
    for _, m in ipairs(remote_diff.metadata_changes or {}) do
      if m.field == field then remote_changed = true break end
    end

    if local_changed and remote_changed and local_version[field] ~= remote[field] then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.METADATA,
        path = "metadata." .. field,
        description = "Both versions changed " .. field,
        base = base[field],
        local_val = local_version[field],
        remote = remote[field],
      })
      merged[field] = local_version[field]
    elseif local_changed then
      merged[field] = local_version[field]
    elseif remote_changed then
      merged[field] = remote[field]
    end
  end

  -- Tags (merge arrays)
  local base_tags = {}
  local local_tags = {}
  local remote_tags = {}
  local merged_tags = {}

  for _, tag in ipairs(base.tags or {}) do base_tags[tag] = true end
  for _, tag in ipairs(local_version.tags or {}) do local_tags[tag] = true end
  for _, tag in ipairs(remote.tags or {}) do remote_tags[tag] = true end

  -- Start with base
  for tag in pairs(base_tags) do merged_tags[tag] = true end

  -- Add tags added in local
  for tag in pairs(local_tags) do
    if not base_tags[tag] then merged_tags[tag] = true end
  end

  -- Add tags added in remote
  for tag in pairs(remote_tags) do
    if not base_tags[tag] then merged_tags[tag] = true end
  end

  -- Remove tags removed in local
  for tag in pairs(base_tags) do
    if not local_tags[tag] then merged_tags[tag] = nil end
  end

  -- Remove tags removed in remote
  for tag in pairs(base_tags) do
    if not remote_tags[tag] then merged_tags[tag] = nil end
  end

  merged.tags = {}
  for tag in pairs(merged_tags) do
    table.insert(merged.tags, tag)
  end

  -- Update modified timestamp
  merged.modified = os.date("!%Y-%m-%dT%H:%M:%SZ")

  return { merged = merged, conflicts = conflicts }
end

--- Merge passages
function merge._merge_passages(base, local_version, remote, local_diff, remote_diff)
  local conflicts = {}
  local merged = {}
  local all_ids = {}

  for id in pairs(base) do all_ids[id] = true end
  for id in pairs(local_version) do all_ids[id] = true end
  for id in pairs(remote) do all_ids[id] = true end

  for id in pairs(all_ids) do
    local base_p = base[id]
    local local_p = local_version[id]
    local remote_p = remote[id]

    local local_change = nil
    local remote_change = nil

    for _, p in ipairs(local_diff.passage_changes or {}) do
      if p.passage_id == id then local_change = p break end
    end
    for _, p in ipairs(remote_diff.passage_changes or {}) do
      if p.passage_id == id then remote_change = p break end
    end

    -- Both added (add-add)
    if not base_p and local_p and remote_p then
      -- Check if identical
      local local_str = type(local_p.content) == "string" and local_p.content or ""
      local remote_str = type(remote_p.content) == "string" and remote_p.content or ""
      if local_str ~= remote_str then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.PASSAGE_CONTENT,
          path = "passages." .. id,
          description = "Both versions added passage \"" .. (local_p.title or id) .. "\"",
          base = nil,
          local_val = local_p,
          remote = remote_p,
          passage_id = id,
        })
      end
      merged[id] = local_p
    -- Only local added
    elseif not base_p and local_p and not remote_p then
      merged[id] = local_p
    -- Only remote added
    elseif not base_p and not local_p and remote_p then
      merged[id] = remote_p
    -- Local deleted, remote modified
    elseif base_p and not local_p and remote_change and remote_change.type == "modified" then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.PASSAGE_DELETED,
        path = "passages." .. id,
        description = "Local deleted passage but remote modified it",
        base = base_p,
        local_val = nil,
        remote = remote_p,
        passage_id = id,
      })
      -- Default: keep deleted
    -- Remote deleted, local modified
    elseif base_p and local_change and local_change.type == "modified" and not remote_p then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.PASSAGE_DELETED,
        path = "passages." .. id,
        description = "Remote deleted passage but local modified it",
        base = base_p,
        local_val = local_p,
        remote = nil,
        passage_id = id,
      })
      merged[id] = local_p
    -- Both deleted
    elseif base_p and not local_p and not remote_p then
      -- Don't add
    -- Only local deleted
    elseif base_p and not local_p then
      -- Don't add
    -- Only remote deleted
    elseif base_p and not remote_p then
      -- Don't add
    -- Both modified
    elseif local_change and local_change.type == "modified" and remote_change and remote_change.type == "modified" then
      local passage_result = merge._merge_passage_fields(base_p, local_p, remote_p)
      merged[id] = passage_result.merged
      for _, c in ipairs(passage_result.conflicts) do
        c.passage_id = id
        table.insert(conflicts, c)
      end
    elseif local_change and local_change.type == "modified" then
      merged[id] = local_p
    elseif remote_change and remote_change.type == "modified" then
      merged[id] = remote_p
    else
      merged[id] = base_p
    end
  end

  return { merged = merged, conflicts = conflicts }
end

--- Merge passage fields
function merge._merge_passage_fields(base, local_version, remote)
  local conflicts = {}
  local merged = deep_copy(base)

  -- Title
  if local_version.title ~= base.title and remote.title ~= base.title then
    if local_version.title ~= remote.title then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.PASSAGE_TITLE,
        path = "passages." .. base.id .. ".title",
        description = "Both versions changed passage title",
        base = base.title,
        local_val = local_version.title,
        remote = remote.title,
      })
    end
    merged.title = local_version.title
  elseif local_version.title ~= base.title then
    merged.title = local_version.title
  elseif remote.title ~= base.title then
    merged.title = remote.title
  end

  -- Content
  if local_version.content ~= base.content and remote.content ~= base.content then
    if local_version.content ~= remote.content then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.PASSAGE_CONTENT,
        path = "passages." .. base.id .. ".content",
        description = "Both versions changed passage content",
        base = base.content,
        local_val = local_version.content,
        remote = remote.content,
      })
    end
    merged.content = local_version.content
  elseif local_version.content ~= base.content then
    merged.content = local_version.content
  elseif remote.content ~= base.content then
    merged.content = remote.content
  end

  -- Scripts
  for _, script in ipairs({ "onEnterScript", "onExitScript" }) do
    local base_val = base[script]
    local local_val = local_version[script]
    local remote_val = remote[script]

    if local_val ~= base_val and remote_val ~= base_val then
      if local_val ~= remote_val then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.PASSAGE_SCRIPT,
          path = "passages." .. base.id .. "." .. script,
          description = "Both versions changed " .. script,
          base = base_val,
          local_val = local_val,
          remote = remote_val,
        })
      end
      merged[script] = local_val
    elseif local_val ~= base_val then
      merged[script] = local_val
    elseif remote_val ~= base_val then
      merged[script] = remote_val
    end
  end

  -- Position (take local by default)
  local base_pos = base.position or {}
  local local_pos = local_version.position or {}
  local remote_pos = remote.position or {}

  if local_pos.x ~= base_pos.x or local_pos.y ~= base_pos.y then
    merged.position = local_pos
  elseif remote_pos.x ~= base_pos.x or remote_pos.y ~= base_pos.y then
    merged.position = remote_pos
  end

  -- Merge choices
  local choices_result = merge._merge_choices(
    base.choices or {},
    local_version.choices or {},
    remote.choices or {}
  )
  merged.choices = choices_result.merged
  for _, c in ipairs(choices_result.conflicts) do
    c.path = "passages." .. base.id .. ".choices." .. (c.choice_id or "?")
    table.insert(conflicts, c)
  end

  return { merged = merged, conflicts = conflicts }
end

--- Merge choices
function merge._merge_choices(base, local_version, remote)
  local conflicts = {}
  local merged = {}

  local base_by_id = {}
  local local_by_id = {}
  local remote_by_id = {}
  local all_ids = {}

  for _, c in ipairs(base) do base_by_id[c.id] = c all_ids[c.id] = true end
  for _, c in ipairs(local_version) do local_by_id[c.id] = c all_ids[c.id] = true end
  for _, c in ipairs(remote) do remote_by_id[c.id] = c all_ids[c.id] = true end

  for id in pairs(all_ids) do
    local base_c = base_by_id[id]
    local local_c = local_by_id[id]
    local remote_c = remote_by_id[id]

    -- New in local only
    if not base_c and local_c and not remote_c then
      table.insert(merged, local_c)
    -- New in remote only
    elseif not base_c and not local_c and remote_c then
      table.insert(merged, remote_c)
    -- New in both
    elseif not base_c and local_c and remote_c then
      local local_str = local_c.text or ""
      local remote_str = remote_c.text or ""
      if local_str ~= remote_str or local_c.target ~= remote_c.target then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.CHOICE_MODIFIED,
          description = "Both versions added the same choice differently",
          base = nil,
          local_val = local_c,
          remote = remote_c,
          choice_id = id,
        })
      end
      table.insert(merged, local_c)
    -- Deleted in local, modified in remote
    elseif base_c and not local_c and remote_c then
      local base_str = base_c.text or ""
      local remote_str = remote_c.text or ""
      if base_str ~= remote_str or base_c.target ~= remote_c.target then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.CHOICE_DELETED,
          description = "Local deleted choice but remote modified it",
          base = base_c,
          local_val = nil,
          remote = remote_c,
          choice_id = id,
        })
      end
      -- Default: keep deleted
    -- Deleted in remote, modified in local
    elseif base_c and local_c and not remote_c then
      local base_str = base_c.text or ""
      local local_str = local_c.text or ""
      if base_str ~= local_str or base_c.target ~= local_c.target then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.CHOICE_DELETED,
          description = "Remote deleted choice but local modified it",
          base = base_c,
          local_val = local_c,
          remote = nil,
          choice_id = id,
        })
        table.insert(merged, local_c)
      end
    -- Both deleted
    elseif base_c and not local_c and not remote_c then
      -- Don't add
    -- Both exist
    elseif base_c and local_c and remote_c then
      local base_str = base_c.text or ""
      local local_str = local_c.text or ""
      local remote_str = remote_c.text or ""

      local local_changed = base_str ~= local_str or base_c.target ~= local_c.target
      local remote_changed = base_str ~= remote_str or base_c.target ~= remote_c.target

      if local_changed and remote_changed and (local_str ~= remote_str or local_c.target ~= remote_c.target) then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.CHOICE_MODIFIED,
          description = "Both versions modified the choice",
          base = base_c,
          local_val = local_c,
          remote = remote_c,
          choice_id = id,
        })
        table.insert(merged, local_c)
      elseif local_changed then
        table.insert(merged, local_c)
      elseif remote_changed then
        table.insert(merged, remote_c)
      else
        table.insert(merged, base_c)
      end
    end
  end

  return { merged = merged, conflicts = conflicts }
end

--- Merge variables
function merge._merge_variables(base, local_version, remote, local_diff, remote_diff)
  local conflicts = {}
  local merged = {}
  local all_names = {}

  for name in pairs(base) do all_names[name] = true end
  for name in pairs(local_version) do all_names[name] = true end
  for name in pairs(remote) do all_names[name] = true end

  for name in pairs(all_names) do
    local base_v = base[name]
    local local_v = local_version[name]
    local remote_v = remote[name]

    local local_change = nil
    local remote_change = nil

    for _, v in ipairs(local_diff.variable_changes or {}) do
      if v.name == name then local_change = v break end
    end
    for _, v in ipairs(remote_diff.variable_changes or {}) do
      if v.name == name then remote_change = v break end
    end

    -- Both added
    if not base_v and local_v and remote_v then
      if tostring(local_v.initial) ~= tostring(remote_v.initial) or local_v.type ~= remote_v.type then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.VARIABLE_VALUE,
          path = "variables." .. name,
          description = "Both versions added variable \"" .. name .. "\" with different values",
          base = nil,
          local_val = local_v,
          remote = remote_v,
          variable_name = name,
        })
      end
      merged[name] = local_v
    -- Only local added
    elseif not base_v and local_v and not remote_v then
      merged[name] = local_v
    -- Only remote added
    elseif not base_v and not local_v and remote_v then
      merged[name] = remote_v
    -- Delete-modify conflicts
    elseif base_v and not local_v and remote_change and remote_change.type == "modified" then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.VARIABLE_DELETED,
        path = "variables." .. name,
        description = "Local deleted variable but remote modified it",
        base = base_v,
        local_val = nil,
        remote = remote_v,
        variable_name = name,
      })
      -- Default: keep deleted
    elseif base_v and local_change and local_change.type == "modified" and not remote_v then
      table.insert(conflicts, {
        type = merge.CONFLICT_TYPES.VARIABLE_DELETED,
        path = "variables." .. name,
        description = "Remote deleted variable but local modified it",
        base = base_v,
        local_val = local_v,
        remote = nil,
        variable_name = name,
      })
      merged[name] = local_v
    -- Both deleted
    elseif base_v and not local_v and not remote_v then
      -- Don't add
    -- Only local deleted
    elseif base_v and not local_v then
      -- Don't add
    -- Only remote deleted
    elseif base_v and not remote_v then
      -- Don't add
    -- Both modified
    elseif local_change and local_change.type == "modified" and remote_change and remote_change.type == "modified" then
      if tostring(local_v.initial) ~= tostring(remote_v.initial) or local_v.type ~= remote_v.type then
        if local_v.type ~= remote_v.type then
          table.insert(conflicts, {
            type = merge.CONFLICT_TYPES.VARIABLE_TYPE,
            path = "variables." .. name .. ".type",
            description = "Both versions changed variable type",
            base = base_v and base_v.type,
            local_val = local_v.type,
            remote = remote_v.type,
            variable_name = name,
          })
        end
        if tostring(local_v.initial) ~= tostring(remote_v.initial) then
          table.insert(conflicts, {
            type = merge.CONFLICT_TYPES.VARIABLE_VALUE,
            path = "variables." .. name .. ".initial",
            description = "Both versions changed variable initial value",
            base = base_v and base_v.initial,
            local_val = local_v.initial,
            remote = remote_v.initial,
            variable_name = name,
          })
        end
      end
      merged[name] = local_v
    elseif local_change and local_change.type == "modified" then
      merged[name] = local_v
    elseif remote_change and remote_change.type == "modified" then
      merged[name] = remote_v
    else
      merged[name] = base_v
    end
  end

  return { merged = merged, conflicts = conflicts }
end

--- Merge settings
function merge._merge_settings(base, local_version, remote)
  local conflicts = {}
  local merged = deep_copy(base)
  local all_keys = {}

  for key in pairs(base) do all_keys[key] = true end
  for key in pairs(local_version) do all_keys[key] = true end
  for key in pairs(remote) do all_keys[key] = true end

  for key in pairs(all_keys) do
    local base_val = base[key]
    local local_val = local_version[key]
    local remote_val = remote[key]

    local local_changed = tostring(base_val) ~= tostring(local_val)
    local remote_changed = tostring(base_val) ~= tostring(remote_val)

    if local_changed and remote_changed then
      if tostring(local_val) ~= tostring(remote_val) then
        table.insert(conflicts, {
          type = merge.CONFLICT_TYPES.SETTINGS,
          path = "settings." .. key,
          description = "Both versions changed setting \"" .. key .. "\"",
          base = base_val,
          local_val = local_val,
          remote = remote_val,
        })
      end
      merged[key] = local_val
    elseif local_changed then
      merged[key] = local_val
    elseif remote_changed then
      merged[key] = remote_val
    end
  end

  return { merged = merged, conflicts = conflicts }
end

--- Check if a conflict is a non-content conflict
function merge._is_non_content_conflict(conflict)
  return conflict.type == merge.CONFLICT_TYPES.METADATA or
         conflict.type == merge.CONFLICT_TYPES.SETTINGS
end

--- Apply a resolution to a conflict
function merge._apply_resolution(story, conflict, resolution)
  local value
  if resolution == merge.STRATEGIES.LOCAL then
    value = conflict.local_val
  elseif resolution == merge.STRATEGIES.REMOTE then
    value = conflict.remote
  else
    value = conflict.base
  end

  local parts = {}
  for part in conflict.path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local current = story
  for i = 1, #parts - 1 do
    if current[parts[i]] == nil then
      current[parts[i]] = {}
    end
    current = current[parts[i]]
  end

  local last_key = parts[#parts]
  if value == nil then
    current[last_key] = nil
  else
    current[last_key] = value
  end
end

--- Resolve conflicts with a map of resolutions
-- @param merge_result table Result from merge_stories
-- @param resolutions table Map of path -> resolution strategy
-- @return table Resolved story data
function merge.resolve_conflicts(merge_result, resolutions)
  local resolved = deep_copy(merge_result.merged)

  for _, conflict in ipairs(merge_result.conflicts) do
    local resolution = resolutions[conflict.path]
    if resolution and resolution ~= merge.STRATEGIES.MANUAL then
      merge._apply_resolution(resolved, conflict, resolution)
    end
  end

  return resolved
end

return merge
