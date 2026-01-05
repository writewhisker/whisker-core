--- Story Diff Algorithm
-- Provides passage-level change detection and human-readable diff output
-- @module whisker.vcs.diff
-- @author Whisker Core Team
-- @license MIT

local diff = {}
diff._dependencies = {}

--- Change types
diff.CHANGE_TYPES = {
  ADDED = "added",
  REMOVED = "removed",
  MODIFIED = "modified",
  UNCHANGED = "unchanged",
}

--- Diff options
-- @field ignore_positions boolean Ignore position changes (default: true)
-- @field ignore_timestamps boolean Ignore timestamp changes (default: true)
-- @field ignore_whitespace boolean Normalize whitespace (default: false)

--- Compute the diff between two Story versions
-- @param base table Base story data
-- @param modified table Modified story data
-- @param options table Diff options (optional)
-- @return table Diff result
function diff.diff_stories(base, modified, options)
  options = options or {}
  local ignore_positions = options.ignore_positions ~= false
  local ignore_timestamps = options.ignore_timestamps ~= false
  local ignore_whitespace = options.ignore_whitespace or false

  local result = {
    metadata_changes = {},
    passage_changes = {},
    variable_changes = {},
    settings_changes = {},
    summary = {
      passages_added = 0,
      passages_removed = 0,
      passages_modified = 0,
      passages_unchanged = 0,
      variables_added = 0,
      variables_removed = 0,
      variables_modified = 0,
      choices_added = 0,
      choices_removed = 0,
      choices_modified = 0,
    },
    -- Statistics for base and modified versions
    base_stats = {
      passage_count = 0,
      variable_count = 0,
      total_words = 0,
      total_choices = 0,
    },
    modified_stats = {
      passage_count = 0,
      variable_count = 0,
      total_words = 0,
      total_choices = 0,
    },
    has_changes = false,
  }

  -- Calculate statistics
  result.base_stats = diff._calculate_stats(base)
  result.modified_stats = diff._calculate_stats(modified)

  -- Diff metadata
  result.metadata_changes = diff._diff_metadata(base.metadata or {}, modified.metadata or {})

  -- Diff passages
  result.passage_changes = diff._diff_passages(
    base.passages or {},
    modified.passages or {},
    { ignore_positions = ignore_positions, ignore_timestamps = ignore_timestamps, ignore_whitespace = ignore_whitespace }
  )

  -- Diff variables
  result.variable_changes = diff._diff_variables(base.variables or {}, modified.variables or {})

  -- Diff settings
  result.settings_changes = diff._diff_settings(base.settings or {}, modified.settings or {})

  -- Calculate summary
  for _, change in ipairs(result.passage_changes) do
    if change.type == diff.CHANGE_TYPES.ADDED then
      result.summary.passages_added = result.summary.passages_added + 1
    elseif change.type == diff.CHANGE_TYPES.REMOVED then
      result.summary.passages_removed = result.summary.passages_removed + 1
    elseif change.type == diff.CHANGE_TYPES.MODIFIED then
      result.summary.passages_modified = result.summary.passages_modified + 1
    else
      result.summary.passages_unchanged = result.summary.passages_unchanged + 1
    end

    if change.choice_changes then
      for _, cc in ipairs(change.choice_changes) do
        if cc.type == diff.CHANGE_TYPES.ADDED then
          result.summary.choices_added = result.summary.choices_added + 1
        elseif cc.type == diff.CHANGE_TYPES.REMOVED then
          result.summary.choices_removed = result.summary.choices_removed + 1
        elseif cc.type == diff.CHANGE_TYPES.MODIFIED then
          result.summary.choices_modified = result.summary.choices_modified + 1
        end
      end
    end
  end

  for _, change in ipairs(result.variable_changes) do
    if change.type == diff.CHANGE_TYPES.ADDED then
      result.summary.variables_added = result.summary.variables_added + 1
    elseif change.type == diff.CHANGE_TYPES.REMOVED then
      result.summary.variables_removed = result.summary.variables_removed + 1
    elseif change.type == diff.CHANGE_TYPES.MODIFIED then
      result.summary.variables_modified = result.summary.variables_modified + 1
    end
  end

  -- Check for any changes
  result.has_changes = #result.metadata_changes > 0 or
    result.summary.passages_added > 0 or
    result.summary.passages_removed > 0 or
    result.summary.passages_modified > 0 or
    result.summary.variables_added > 0 or
    result.summary.variables_removed > 0 or
    result.summary.variables_modified > 0 or
    #result.settings_changes > 0

  return result
end

--- Diff metadata
-- @param base table Base metadata
-- @param modified table Modified metadata
-- @return table Array of changes
function diff._diff_metadata(base, modified)
  local changes = {}
  local fields = { "title", "author", "version", "description", "ifid" }

  for _, field in ipairs(fields) do
    local old_val = base[field]
    local new_val = modified[field]
    if old_val ~= new_val then
      table.insert(changes, {
        field = field,
        old_value = old_val,
        new_value = new_val,
      })
    end
  end

  -- Check tags
  local old_tags = table.concat(base.tags or {}, ",")
  local new_tags = table.concat(modified.tags or {}, ",")
  if old_tags ~= new_tags then
    table.insert(changes, {
      field = "tags",
      old_value = base.tags,
      new_value = modified.tags,
    })
  end

  return changes
end

--- Diff passages
-- @param base table Base passages
-- @param modified table Modified passages
-- @param options table Diff options
-- @return table Array of passage changes
function diff._diff_passages(base, modified, options)
  local changes = {}
  local all_ids = {}

  -- Collect all IDs
  for id in pairs(base) do all_ids[id] = true end
  for id in pairs(modified) do all_ids[id] = true end

  for id in pairs(all_ids) do
    local base_passage = base[id]
    local modified_passage = modified[id]

    if not base_passage then
      -- Added
      table.insert(changes, {
        type = diff.CHANGE_TYPES.ADDED,
        passage_id = id,
        passage_title = modified_passage.title or modified_passage.name or id,
      })
    elseif not modified_passage then
      -- Removed
      table.insert(changes, {
        type = diff.CHANGE_TYPES.REMOVED,
        passage_id = id,
        passage_title = base_passage.title or base_passage.name or id,
      })
    else
      -- Check for modifications
      local field_changes = diff._diff_passage_fields(base_passage, modified_passage, options)
      local choice_changes = diff._diff_choices(
        base_passage.choices or {},
        modified_passage.choices or {},
        options.ignore_whitespace
      )

      local has_changes = #field_changes > 0
      for _, cc in ipairs(choice_changes) do
        if cc.type ~= diff.CHANGE_TYPES.UNCHANGED then
          has_changes = true
          break
        end
      end

      if has_changes then
        table.insert(changes, {
          type = diff.CHANGE_TYPES.MODIFIED,
          passage_id = id,
          passage_title = modified_passage.title or modified_passage.name or id,
          fields = field_changes,
          choice_changes = choice_changes,
        })
      else
        table.insert(changes, {
          type = diff.CHANGE_TYPES.UNCHANGED,
          passage_id = id,
          passage_title = modified_passage.title or modified_passage.name or id,
        })
      end
    end
  end

  return changes
end

--- Diff passage fields
-- @param base table Base passage
-- @param modified table Modified passage
-- @param options table Diff options
-- @return table Array of field changes
function diff._diff_passage_fields(base, modified, options)
  local changes = {}

  -- Title
  local base_title = base.title or base.name
  local mod_title = modified.title or modified.name
  if base_title ~= mod_title then
    table.insert(changes, { field = "title", old_value = base_title, new_value = mod_title })
  end

  -- Content
  local base_content = base.content or ""
  local mod_content = modified.content or ""
  if options.ignore_whitespace then
    base_content = diff._normalize_whitespace(base_content)
    mod_content = diff._normalize_whitespace(mod_content)
  end
  if base_content ~= mod_content then
    table.insert(changes, { field = "content", old_value = base.content, new_value = modified.content })
  end

  -- Position (unless ignored)
  if not options.ignore_positions then
    local base_pos = base.position or {}
    local mod_pos = modified.position or {}
    if base_pos.x ~= mod_pos.x or base_pos.y ~= mod_pos.y then
      table.insert(changes, { field = "position", old_value = base_pos, new_value = mod_pos })
    end
  end

  -- Scripts
  if base.onEnterScript ~= modified.onEnterScript then
    table.insert(changes, { field = "onEnterScript", old_value = base.onEnterScript, new_value = modified.onEnterScript })
  end
  if base.onExitScript ~= modified.onExitScript then
    table.insert(changes, { field = "onExitScript", old_value = base.onExitScript, new_value = modified.onExitScript })
  end

  -- Tags
  local old_tags = table.concat(base.tags or {}, ",")
  local new_tags = table.concat(modified.tags or {}, ",")
  if old_tags ~= new_tags then
    table.insert(changes, { field = "tags", old_value = base.tags, new_value = modified.tags })
  end

  -- Color
  if base.color ~= modified.color then
    table.insert(changes, { field = "color", old_value = base.color, new_value = modified.color })
  end

  -- Notes
  if base.notes ~= modified.notes then
    table.insert(changes, { field = "notes", old_value = base.notes, new_value = modified.notes })
  end

  return changes
end

--- Diff choices within a passage
-- @param base table Base choices array
-- @param modified table Modified choices array
-- @param ignore_whitespace boolean Whether to ignore whitespace
-- @return table Array of choice changes
function diff._diff_choices(base, modified, ignore_whitespace)
  local changes = {}
  local base_by_id = {}
  local modified_by_id = {}
  local all_ids = {}

  for _, c in ipairs(base) do
    base_by_id[c.id] = c
    all_ids[c.id] = true
  end
  for _, c in ipairs(modified) do
    modified_by_id[c.id] = c
    all_ids[c.id] = true
  end

  for id in pairs(all_ids) do
    local base_choice = base_by_id[id]
    local modified_choice = modified_by_id[id]

    if not base_choice then
      table.insert(changes, {
        type = diff.CHANGE_TYPES.ADDED,
        choice_id = id,
        choice_text = modified_choice.text or "",
      })
    elseif not modified_choice then
      table.insert(changes, {
        type = diff.CHANGE_TYPES.REMOVED,
        choice_id = id,
        choice_text = base_choice.text or "",
      })
    else
      local field_changes = diff._diff_choice_fields(base_choice, modified_choice)
      if #field_changes > 0 then
        table.insert(changes, {
          type = diff.CHANGE_TYPES.MODIFIED,
          choice_id = id,
          choice_text = modified_choice.text or "",
          fields = field_changes,
        })
      else
        table.insert(changes, {
          type = diff.CHANGE_TYPES.UNCHANGED,
          choice_id = id,
          choice_text = modified_choice.text or "",
        })
      end
    end
  end

  return changes
end

--- Diff choice fields
-- @param base table Base choice
-- @param modified table Modified choice
-- @return table Array of field changes
function diff._diff_choice_fields(base, modified)
  local changes = {}

  if base.text ~= modified.text then
    table.insert(changes, { field = "text", old_value = base.text, new_value = modified.text })
  end
  if base.target ~= modified.target then
    table.insert(changes, { field = "target", old_value = base.target, new_value = modified.target })
  end
  if base.condition ~= modified.condition then
    table.insert(changes, { field = "condition", old_value = base.condition, new_value = modified.condition })
  end
  if base.action ~= modified.action then
    table.insert(changes, { field = "action", old_value = base.action, new_value = modified.action })
  end
  if base.choiceType ~= modified.choiceType then
    table.insert(changes, { field = "choiceType", old_value = base.choiceType, new_value = modified.choiceType })
  end

  return changes
end

--- Diff variables
-- @param base table Base variables
-- @param modified table Modified variables
-- @return table Array of variable changes
function diff._diff_variables(base, modified)
  local changes = {}
  local all_names = {}

  for name in pairs(base) do all_names[name] = true end
  for name in pairs(modified) do all_names[name] = true end

  for name in pairs(all_names) do
    local base_var = base[name]
    local mod_var = modified[name]

    if not base_var then
      table.insert(changes, { type = diff.CHANGE_TYPES.ADDED, name = name })
    elseif not mod_var then
      table.insert(changes, { type = diff.CHANGE_TYPES.REMOVED, name = name })
    else
      local field_changes = {}
      if base_var.type ~= mod_var.type then
        table.insert(field_changes, { field = "type", old_value = base_var.type, new_value = mod_var.type })
      end
      if tostring(base_var.initial) ~= tostring(mod_var.initial) then
        table.insert(field_changes, { field = "initial", old_value = base_var.initial, new_value = mod_var.initial })
      end
      if base_var.scope ~= mod_var.scope then
        table.insert(field_changes, { field = "scope", old_value = base_var.scope, new_value = mod_var.scope })
      end

      if #field_changes > 0 then
        table.insert(changes, { type = diff.CHANGE_TYPES.MODIFIED, name = name, fields = field_changes })
      else
        table.insert(changes, { type = diff.CHANGE_TYPES.UNCHANGED, name = name })
      end
    end
  end

  return changes
end

--- Diff settings
-- @param base table Base settings
-- @param modified table Modified settings
-- @return table Array of setting changes
function diff._diff_settings(base, modified)
  local changes = {}
  local all_keys = {}

  for key in pairs(base) do all_keys[key] = true end
  for key in pairs(modified) do all_keys[key] = true end

  for key in pairs(all_keys) do
    local old_val = base[key]
    local new_val = modified[key]

    -- Simple comparison (use JSON for complex types in production)
    local old_str = type(old_val) == "table" and "table" or tostring(old_val)
    local new_str = type(new_val) == "table" and "table" or tostring(new_val)

    if old_str ~= new_str then
      table.insert(changes, { field = key, old_value = old_val, new_value = new_val })
    end
  end

  return changes
end

--- Normalize whitespace
-- @param text string Text to normalize
-- @return string Normalized text
function diff._normalize_whitespace(text)
  if not text then return "" end
  return text:gsub("%s+", " "):match("^%s*(.-)%s*$")
end

--- Count words in text
-- @param text string Text to count words in
-- @return number Word count
function diff._count_words(text)
  if not text or text == "" then return 0 end
  local count = 0
  for _ in text:gmatch("%S+") do
    count = count + 1
  end
  return count
end

--- Calculate statistics for a story
-- @param story table Story data
-- @return table Statistics
function diff._calculate_stats(story)
  local stats = {
    passage_count = 0,
    variable_count = 0,
    total_words = 0,
    total_choices = 0,
  }

  -- Count passages and their content
  if story.passages then
    for _, passage in pairs(story.passages) do
      stats.passage_count = stats.passage_count + 1
      stats.total_words = stats.total_words + diff._count_words(passage.content)
      if passage.choices then
        stats.total_choices = stats.total_choices + #passage.choices
      end
    end
  end

  -- Count variables
  if story.variables then
    for _ in pairs(story.variables) do
      stats.variable_count = stats.variable_count + 1
    end
  end

  return stats
end

--- Format a value for display
-- @param value any Value to format
-- @return string Formatted string
function diff._format_value(value)
  if value == nil then return "(nil)" end
  if type(value) == "string" then return '"' .. value .. '"' end
  if type(value) == "table" then
    if value[1] ~= nil then
      return "[" .. table.concat(value, ", ") .. "]"
    else
      -- Simple key-value format
      local parts = {}
      for k, v in pairs(value) do
        table.insert(parts, k .. "=" .. tostring(v))
      end
      return "{" .. table.concat(parts, ", ") .. "}"
    end
  end
  return tostring(value)
end

--- Generate human-readable diff output
-- @param diff_result table Result from diff_stories
-- @param options table Format options (color: boolean)
-- @return string Formatted diff output
function diff.format_diff(diff_result, options)
  options = options or {}
  local lines = {}
  local use_color = options.color or false

  -- Color helpers
  local function red(s) return use_color and ("\27[31m" .. s .. "\27[0m") or s end
  local function green(s) return use_color and ("\27[32m" .. s .. "\27[0m") or s end
  local function yellow(s) return use_color and ("\27[33m" .. s .. "\27[0m") or s end
  local function cyan(s) return use_color and ("\27[36m" .. s .. "\27[0m") or s end
  local function bold(s) return use_color and ("\27[1m" .. s .. "\27[0m") or s end

  -- Summary
  table.insert(lines, bold("=== Story Diff Summary ==="))
  table.insert(lines, "")

  if not diff_result.has_changes then
    table.insert(lines, "No changes detected.")
    return table.concat(lines, "\n")
  end

  local s = diff_result.summary
  table.insert(lines, string.format("Passages: %s %s %s",
    green("+" .. s.passages_added),
    red("-" .. s.passages_removed),
    yellow("~" .. s.passages_modified)))
  table.insert(lines, string.format("Variables: %s %s %s",
    green("+" .. s.variables_added),
    red("-" .. s.variables_removed),
    yellow("~" .. s.variables_modified)))
  table.insert(lines, string.format("Choices: %s %s %s",
    green("+" .. s.choices_added),
    red("-" .. s.choices_removed),
    yellow("~" .. s.choices_modified)))
  table.insert(lines, "")

  -- Metadata changes
  if #diff_result.metadata_changes > 0 then
    table.insert(lines, bold("--- Metadata ---"))
    for _, change in ipairs(diff_result.metadata_changes) do
      table.insert(lines, "  " .. cyan(change.field) .. ":")
      table.insert(lines, "    " .. red("-") .. " " .. diff._format_value(change.old_value))
      table.insert(lines, "    " .. green("+") .. " " .. diff._format_value(change.new_value))
    end
    table.insert(lines, "")
  end

  -- Passage changes
  local passage_changes = {}
  for _, p in ipairs(diff_result.passage_changes) do
    if p.type ~= diff.CHANGE_TYPES.UNCHANGED then
      table.insert(passage_changes, p)
    end
  end

  if #passage_changes > 0 then
    table.insert(lines, bold("--- Passages ---"))
    for _, change in ipairs(passage_changes) do
      if change.type == diff.CHANGE_TYPES.ADDED then
        table.insert(lines, green("+ [" .. change.passage_title .. "]"))
      elseif change.type == diff.CHANGE_TYPES.REMOVED then
        table.insert(lines, red("- [" .. change.passage_title .. "]"))
      elseif change.type == diff.CHANGE_TYPES.MODIFIED then
        table.insert(lines, yellow("~ [" .. change.passage_title .. "]"))

        if change.fields then
          for _, field in ipairs(change.fields) do
            if field.field == "content" then
              table.insert(lines, "    " .. cyan("content") .. ": (changed)")
            else
              table.insert(lines, string.format("    %s: %s -> %s",
                cyan(field.field),
                red(diff._format_value(field.old_value)),
                green(diff._format_value(field.new_value))))
            end
          end
        end

        if change.choice_changes then
          local non_unchanged = {}
          for _, cc in ipairs(change.choice_changes) do
            if cc.type ~= diff.CHANGE_TYPES.UNCHANGED then
              table.insert(non_unchanged, cc)
            end
          end

          if #non_unchanged > 0 then
            table.insert(lines, "    Choices:")
            for _, cc in ipairs(non_unchanged) do
              if cc.type == diff.CHANGE_TYPES.ADDED then
                table.insert(lines, green('      + "' .. cc.choice_text .. '"'))
              elseif cc.type == diff.CHANGE_TYPES.REMOVED then
                table.insert(lines, red('      - "' .. cc.choice_text .. '"'))
              elseif cc.type == diff.CHANGE_TYPES.MODIFIED then
                table.insert(lines, yellow('      ~ "' .. cc.choice_text .. '"'))
              end
            end
          end
        end
      end
    end
    table.insert(lines, "")
  end

  -- Variable changes
  local var_changes = {}
  for _, v in ipairs(diff_result.variable_changes) do
    if v.type ~= diff.CHANGE_TYPES.UNCHANGED then
      table.insert(var_changes, v)
    end
  end

  if #var_changes > 0 then
    table.insert(lines, bold("--- Variables ---"))
    for _, change in ipairs(var_changes) do
      if change.type == diff.CHANGE_TYPES.ADDED then
        table.insert(lines, green("+ " .. change.name))
      elseif change.type == diff.CHANGE_TYPES.REMOVED then
        table.insert(lines, red("- " .. change.name))
      elseif change.type == diff.CHANGE_TYPES.MODIFIED then
        table.insert(lines, yellow("~ " .. change.name))
        if change.fields then
          for _, f in ipairs(change.fields) do
            table.insert(lines, string.format("    %s: %s -> %s",
              f.field,
              red(diff._format_value(f.old_value)),
              green(diff._format_value(f.new_value))))
          end
        end
      end
    end
    table.insert(lines, "")
  end

  -- Settings changes
  if #diff_result.settings_changes > 0 then
    table.insert(lines, bold("--- Settings ---"))
    for _, change in ipairs(diff_result.settings_changes) do
      table.insert(lines, "  " .. cyan(change.field) .. ":")
      table.insert(lines, "    " .. red("-") .. " " .. diff._format_value(change.old_value))
      table.insert(lines, "    " .. green("+") .. " " .. diff._format_value(change.new_value))
    end
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

--- Get a summary of changes suitable for commit messages
-- @param diff_result table Result from diff_stories
-- @return string Summary string
function diff.get_summary(diff_result)
  local parts = {}
  local s = diff_result.summary

  if s.passages_added > 0 then
    local plural = s.passages_added > 1 and "s" or ""
    table.insert(parts, "added " .. s.passages_added .. " passage" .. plural)
  end
  if s.passages_removed > 0 then
    local plural = s.passages_removed > 1 and "s" or ""
    table.insert(parts, "removed " .. s.passages_removed .. " passage" .. plural)
  end
  if s.passages_modified > 0 then
    local plural = s.passages_modified > 1 and "s" or ""
    table.insert(parts, "modified " .. s.passages_modified .. " passage" .. plural)
  end

  local var_total = s.variables_added + s.variables_removed + s.variables_modified
  if var_total > 0 then
    local plural = var_total > 1 and "s" or ""
    table.insert(parts, var_total .. " variable change" .. plural)
  end

  if #parts == 0 then
    return "No changes"
  end

  return table.concat(parts, ", ")
end

return diff
