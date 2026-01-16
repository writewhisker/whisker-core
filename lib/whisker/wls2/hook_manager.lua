-- Hook Manager for WLS 2.0 Hooks System
-- Manages hook registry, operations, and lifecycle

local HookManager = {}
HookManager.__index = HookManager
HookManager._dependencies = {}

--- Create a new HookManager instance
-- @param deps table Optional dependencies container for dependency injection
-- @return HookManager instance
function HookManager.new(deps)
  local self = setmetatable({}, HookManager)
  self._hooks = {}           -- id -> Hook table
  self._passage_hooks = {}   -- passage_id -> hook_ids[]
  self._deps = deps or {}    -- Store dependencies for future extensibility
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

return HookManager
