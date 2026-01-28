-- Hook Manager for WLS 2.0 Hooks System
-- Manages hook registry, operations, and lifecycle

local HookManager = {}
HookManager.__index = HookManager

--- Create a new HookManager instance
-- @return HookManager instance
function HookManager.new()
  local self = setmetatable({}, HookManager)
  self._hooks = {}           -- id -> Hook table
  self._passage_hooks = {}   -- passage_id -> hook_ids[]
  return self
end

--- Register a new hook
-- @param passage_id string Parent passage identifier
-- @param hook_name string Hook name from definition
-- @param content string Initial hook content
-- @return string Hook ID
function HookManager:register_hook(passage_id, hook_name, content)
  local hook_id = passage_id .. "_" .. hook_name
  
  self._hooks[hook_id] = {
    id = hook_id,
    name = hook_name,
    content = content,
    current_content = content,
    visible = true,
    passage_id = passage_id,
    created_at = os.time(),
    modified_count = 0
  }
  
  -- Track passage association
  if not self._passage_hooks[passage_id] then
    self._passage_hooks[passage_id] = {}
  end
  table.insert(self._passage_hooks[passage_id], hook_id)
  
  return hook_id
end

--- Get hook by full ID
-- @param hook_id string Full hook identifier
-- @return table|nil Hook table or nil if not found
function HookManager:get_hook(hook_id)
  return self._hooks[hook_id]
end

--- Get hook by name in passage context
-- @param passage_id string Passage identifier
-- @param hook_name string Hook name
-- @return table|nil Hook table or nil if not found
function HookManager:get_hook_by_name(passage_id, hook_name)
  local hook_id = passage_id .. "_" .. hook_name
  return self._hooks[hook_id]
end

--- Replace hook content entirely
-- @param hook_id string Hook identifier
-- @param new_content string New content
-- @return boolean, string Success status and error message if failed
function HookManager:replace_hook(hook_id, new_content)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end

  hook.current_content = new_content
  hook.cleared = false  -- GAP-019: Content restored, no longer cleared
  hook.modified_count = hook.modified_count + 1
  return true
end

--- Append content to hook
-- @param hook_id string Hook identifier
-- @param additional_content string Content to append
-- @return boolean, string Success status and error message if failed
function HookManager:append_hook(hook_id, additional_content)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end
  
  hook.current_content = hook.current_content .. additional_content
  hook.modified_count = hook.modified_count + 1
  return true
end

--- Prepend content to hook
-- @param hook_id string Hook identifier
-- @param content_before string Content to prepend
-- @return boolean, string Success status and error message if failed
function HookManager:prepend_hook(hook_id, content_before)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end
  
  hook.current_content = content_before .. hook.current_content
  hook.modified_count = hook.modified_count + 1
  return true
end

--- Show hidden hook
-- @param hook_id string Hook identifier
-- @return boolean, string Success status and error message if failed
function HookManager:show_hook(hook_id)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end
  
  hook.visible = true
  return true
end

--- Hide visible hook
-- @param hook_id string Hook identifier
-- @return boolean, string Success status and error message if failed
function HookManager:hide_hook(hook_id)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end

  hook.visible = false
  return true
end

-- GAP-019: Clear hook content (different from hide)

--- Clear a hook's content to empty string
-- Unlike hide(), clear() sets content to empty but keeps hook visible
-- @param hook_id string Hook identifier
-- @return boolean, string Success status and error message if failed
function HookManager:clear_hook(hook_id)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end

  -- Clear current content to empty string
  hook.current_content = ""

  -- Track that this was a clear operation (not just empty replace)
  hook.cleared = true

  -- Keep hook visible (this is the key difference from hide)
  -- hook.visible remains unchanged

  hook.modified_count = hook.modified_count + 1
  return true
end

--- Check if a hook was cleared
-- @param hook_id string Hook identifier
-- @return boolean True if hook was explicitly cleared
function HookManager:is_cleared(hook_id)
  local hook = self._hooks[hook_id]
  return hook and hook.cleared == true
end

--- Check if a hook is visible
-- @param hook_id string Hook identifier
-- @return boolean True if hook exists and is visible
function HookManager:is_visible(hook_id)
  local hook = self._hooks[hook_id]
  if not hook then
    return false
  end
  return hook.visible ~= false
end

--- Clear all hooks for a passage (on navigation)
-- @param passage_id string Passage identifier
function HookManager:clear_passage_hooks(passage_id)
  local hook_ids = self._passage_hooks[passage_id] or {}
  
  for _, hook_id in ipairs(hook_ids) do
    self._hooks[hook_id] = nil
  end
  
  self._passage_hooks[passage_id] = nil
end

--- Get all hooks in a passage
-- @param passage_id string Passage identifier
-- @return table Array of hook tables
function HookManager:get_passage_hooks(passage_id)
  local hook_ids = self._passage_hooks[passage_id] or {}
  local hooks = {}
  
  for _, hook_id in ipairs(hook_ids) do
    table.insert(hooks, self._hooks[hook_id])
  end
  
  return hooks
end

--- Serialize state for save/load
-- @return table Serialized state
function HookManager:serialize()
  return {
    hooks = self._hooks,
    passage_hooks = self._passage_hooks
  }
end

--- Deserialize state
-- @param data table Serialized state
function HookManager:deserialize(data)
  self._hooks = data.hooks or {}
  self._passage_hooks = data.passage_hooks or {}
end

-- ============================================================================
-- GAP-073: Dedicated hook.clear() and hook.reset()
-- ============================================================================

--- Reset hook to original content
-- @param hook_id string Hook identifier
-- @return boolean, string Success status and error message if failed
function HookManager:reset_hook(hook_id)
  local hook = self._hooks[hook_id]
  if not hook then
    return false, "Hook not found: " .. hook_id
  end

  hook.current_content = hook.content  -- Original content
  hook.modified_count = 0
  hook.cleared = false
  return true
end

-- ============================================================================
-- GAP-072: Hook All Implementation - Bulk Operations
-- ============================================================================

--- Hide all hooks in a passage
-- @param passage_id string Passage identifier
-- @param pattern string|nil Optional name pattern to match
-- @return number Count of hooks hidden
function HookManager:hide_all(passage_id, pattern)
  local hooks = self:get_passage_hooks(passage_id)
  local count = 0

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      if hook.visible then
        hook.visible = false
        count = count + 1
      end
    end
  end

  return count
end

--- Show all hooks in a passage
-- @param passage_id string Passage identifier
-- @param pattern string|nil Optional name pattern to match
-- @return number Count of hooks shown
function HookManager:show_all(passage_id, pattern)
  local hooks = self:get_passage_hooks(passage_id)
  local count = 0

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      if not hook.visible then
        hook.visible = true
        count = count + 1
      end
    end
  end

  return count
end

--- Replace content of all hooks in a passage
-- @param passage_id string Passage identifier
-- @param new_content string New content for all hooks
-- @param pattern string|nil Optional name pattern to match
-- @return number Count of hooks replaced
function HookManager:replace_all(passage_id, new_content, pattern)
  local hooks = self:get_passage_hooks(passage_id)
  local count = 0

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      hook.current_content = new_content
      hook.modified_count = hook.modified_count + 1
      hook.cleared = false
      count = count + 1
    end
  end

  return count
end

--- Clear all hooks in a passage (set to empty string)
-- @param passage_id string Passage identifier
-- @param pattern string|nil Optional name pattern
-- @return number Count of hooks cleared
function HookManager:clear_all(passage_id, pattern)
  local hooks = self:get_passage_hooks(passage_id)
  local count = 0

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      hook.current_content = ""
      hook.modified_count = hook.modified_count + 1
      hook.cleared = true
      count = count + 1
    end
  end

  return count
end

--- Reset all hooks in a passage to original content
-- @param passage_id string Passage identifier
-- @param pattern string|nil Optional name pattern
-- @return number Count of hooks reset
function HookManager:reset_all(passage_id, pattern)
  local hooks = self:get_passage_hooks(passage_id)
  local count = 0

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      hook.current_content = hook.content
      hook.modified_count = 0
      hook.cleared = false
      count = count + 1
    end
  end

  return count
end

--- Iterate over all hooks with callback
-- @param passage_id string Passage identifier
-- @param callback function Function(hook) to call for each hook
-- @param pattern string|nil Optional name pattern to match
function HookManager:each(passage_id, callback, pattern)
  local hooks = self:get_passage_hooks(passage_id)

  for _, hook in ipairs(hooks) do
    if not pattern or hook.name:match(pattern) then
      callback(hook)
    end
  end
end

--- Get hooks matching criteria
-- @param passage_id string Passage identifier
-- @param criteria table { pattern, visible, content_pattern }
-- @return table Array of matching hooks
function HookManager:find_hooks(passage_id, criteria)
  local hooks = self:get_passage_hooks(passage_id)
  local results = {}
  criteria = criteria or {}

  for _, hook in ipairs(hooks) do
    local matches = true

    if criteria.pattern and not hook.name:match(criteria.pattern) then
      matches = false
    end

    if criteria.visible ~= nil and hook.visible ~= criteria.visible then
      matches = false
    end

    if criteria.content_pattern and not hook.current_content:match(criteria.content_pattern) then
      matches = false
    end

    if matches then
      table.insert(results, hook)
    end
  end

  return results
end

return HookManager
