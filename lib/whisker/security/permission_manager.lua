--- Permission Manager
-- User permission request and management
-- @module whisker.security.permission_manager
-- @author Whisker Core Team
-- @license MIT

local Capabilities = require("whisker.security.capabilities")
local PermissionStorage = require("whisker.security.permission_storage")

local PermissionManager = {}

--- Permission states
-- @table STATES
PermissionManager.STATES = {
  PENDING = "pending",     -- Not yet decided
  GRANTED = "granted",     -- User approved
  DENIED = "denied",       -- User denied
  REVOKED = "revoked",     -- User revoked after granting
}

--- UI handler for permission requests (injected)
local _ui_handler = nil

--- Security logger (injected)
local _logger = nil

--- Set UI handler for permission dialogs
-- @param handler function(plugin_id, capabilities, callback)
function PermissionManager.set_ui_handler(handler)
  _ui_handler = handler
end

--- Set security logger
-- @param logger table Logger instance
function PermissionManager.set_logger(logger)
  _logger = logger
end

--- Log security event
-- @param event_type string Event type
-- @param details table Event details
local function log_event(event_type, details)
  if _logger and _logger.log_security_event then
    _logger.log_security_event(event_type, details)
  end
end

--- Check if permission is granted
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return boolean True if granted
function PermissionManager.is_granted(plugin_id, capability_id)
  local state = PermissionStorage.get(plugin_id, capability_id)
  return state == PermissionManager.STATES.GRANTED
end

--- Check if permission is denied
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return boolean True if denied or revoked
function PermissionManager.is_denied(plugin_id, capability_id)
  local state = PermissionStorage.get(plugin_id, capability_id)
  return state == PermissionManager.STATES.DENIED or state == PermissionManager.STATES.REVOKED
end

--- Check if permission is pending (not yet decided)
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return boolean True if no decision made
function PermissionManager.is_pending(plugin_id, capability_id)
  local state = PermissionStorage.get(plugin_id, capability_id)
  return state == nil or state == PermissionManager.STATES.PENDING
end

--- Grant permission
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @param metadata table|nil Additional metadata
function PermissionManager.grant(plugin_id, capability_id, metadata)
  -- Validate capability
  if not Capabilities.is_valid(capability_id) then
    error("Invalid capability: " .. capability_id)
  end

  PermissionStorage.set(plugin_id, capability_id, PermissionManager.STATES.GRANTED, metadata)

  log_event("PERMISSION_GRANTED", {
    plugin_id = plugin_id,
    capability = capability_id,
  })

  -- Save immediately
  PermissionStorage.save()
end

--- Deny permission
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @param metadata table|nil Additional metadata
function PermissionManager.deny(plugin_id, capability_id, metadata)
  if not Capabilities.is_valid(capability_id) then
    error("Invalid capability: " .. capability_id)
  end

  PermissionStorage.set(plugin_id, capability_id, PermissionManager.STATES.DENIED, metadata)

  log_event("PERMISSION_DENIED", {
    plugin_id = plugin_id,
    capability = capability_id,
  })

  PermissionStorage.save()
end

--- Revoke permission
-- @param plugin_id string Plugin ID
-- @param capability_id string|nil Capability ID (nil = all)
function PermissionManager.revoke(plugin_id, capability_id)
  if capability_id then
    PermissionStorage.set(plugin_id, capability_id, PermissionManager.STATES.REVOKED)

    log_event("PERMISSION_REVOKED", {
      plugin_id = plugin_id,
      capability = capability_id,
    })
  else
    -- Revoke all for plugin
    local perms = PermissionStorage.get_plugin_permissions(plugin_id)
    for cap_id in pairs(perms) do
      PermissionStorage.set(plugin_id, cap_id, PermissionManager.STATES.REVOKED)

      log_event("PERMISSION_REVOKED", {
        plugin_id = plugin_id,
        capability = cap_id,
      })
    end
  end

  PermissionStorage.save()
end

--- Reset permission (remove decision, back to pending)
-- @param plugin_id string Plugin ID
-- @param capability_id string|nil Capability ID (nil = all)
function PermissionManager.reset(plugin_id, capability_id)
  PermissionStorage.remove(plugin_id, capability_id)

  log_event("PERMISSION_RESET", {
    plugin_id = plugin_id,
    capability = capability_id or "ALL",
  })

  PermissionStorage.save()
end

--- Request permissions from user
-- @param plugin_id string Plugin ID
-- @param capabilities table Array of capability IDs
-- @param callback function(granted_caps, denied_caps) Called with result
function PermissionManager.request(plugin_id, capabilities, callback)
  -- Validate capabilities
  local valid, err = Capabilities.validate(capabilities)
  if not valid then
    callback({}, capabilities)
    return
  end

  -- Expand to include required capabilities
  capabilities = Capabilities.expand(capabilities)

  -- Check which are already decided
  local pending = {}
  local already_granted = {}
  local already_denied = {}

  for _, cap_id in ipairs(capabilities) do
    if PermissionManager.is_granted(plugin_id, cap_id) then
      table.insert(already_granted, cap_id)
    elseif PermissionManager.is_denied(plugin_id, cap_id) then
      table.insert(already_denied, cap_id)
    else
      table.insert(pending, cap_id)
    end
  end

  -- If nothing pending, return current state
  if #pending == 0 then
    callback(already_granted, already_denied)
    return
  end

  log_event("PERMISSION_REQUEST", {
    plugin_id = plugin_id,
    capabilities = pending,
  })

  -- If no UI handler, auto-deny (fail-secure)
  if not _ui_handler then
    for _, cap_id in ipairs(pending) do
      PermissionManager.deny(plugin_id, cap_id, {reason = "no_ui_handler"})
      table.insert(already_denied, cap_id)
    end
    callback(already_granted, already_denied)
    return
  end

  -- Get permission prompts for UI
  local prompts = Capabilities.get_permission_prompts(pending)

  -- Call UI handler
  _ui_handler(plugin_id, prompts, function(decisions)
    local granted = {}
    local denied = {}

    for _, cap_id in ipairs(pending) do
      if decisions[cap_id] == true then
        PermissionManager.grant(plugin_id, cap_id)
        table.insert(granted, cap_id)
      else
        PermissionManager.deny(plugin_id, cap_id)
        table.insert(denied, cap_id)
      end
    end

    -- Combine with existing decisions
    for _, cap_id in ipairs(already_granted) do
      table.insert(granted, cap_id)
    end
    for _, cap_id in ipairs(already_denied) do
      table.insert(denied, cap_id)
    end

    callback(granted, denied)
  end)
end

--- Request permissions synchronously (blocking)
-- @param plugin_id string Plugin ID
-- @param capabilities table Array of capability IDs
-- @return table granted Array of granted capability IDs
-- @return table denied Array of denied capability IDs
function PermissionManager.request_sync(plugin_id, capabilities)
  local granted_result, denied_result

  PermissionManager.request(plugin_id, capabilities, function(granted, denied)
    granted_result = granted
    denied_result = denied
  end)

  return granted_result or {}, denied_result or capabilities
end

--- Get all permissions for a plugin
-- @param plugin_id string Plugin ID
-- @return table Map of capability_id -> state
function PermissionManager.get_all(plugin_id)
  local perms = PermissionStorage.get_plugin_permissions(plugin_id)
  local result = {}

  for cap_id, data in pairs(perms) do
    result[cap_id] = data.state
  end

  return result
end

--- Get permission summary for UI
-- @param plugin_id string Plugin ID
-- @return table {granted: [], denied: [], pending: []}
function PermissionManager.get_summary(plugin_id)
  local perms = PermissionStorage.get_plugin_permissions(plugin_id)
  local summary = {
    granted = {},
    denied = {},
    revoked = {},
  }

  for cap_id, data in pairs(perms) do
    if data.state == PermissionManager.STATES.GRANTED then
      table.insert(summary.granted, cap_id)
    elseif data.state == PermissionManager.STATES.DENIED then
      table.insert(summary.denied, cap_id)
    elseif data.state == PermissionManager.STATES.REVOKED then
      table.insert(summary.revoked, cap_id)
    end
  end

  return summary
end

--- Check if all capabilities are granted
-- @param plugin_id string Plugin ID
-- @param capabilities table Array of capability IDs
-- @return boolean True if all granted
function PermissionManager.all_granted(plugin_id, capabilities)
  for _, cap_id in ipairs(capabilities) do
    if not PermissionManager.is_granted(plugin_id, cap_id) then
      return false
    end
  end
  return true
end

--- Get granted capabilities for a plugin
-- @param plugin_id string Plugin ID
-- @return table Array of granted capability IDs
function PermissionManager.get_granted(plugin_id)
  local perms = PermissionStorage.get_plugin_permissions(plugin_id)
  local granted = {}

  for cap_id, data in pairs(perms) do
    if data.state == PermissionManager.STATES.GRANTED then
      table.insert(granted, cap_id)
    end
  end

  return granted
end

--- Auto-grant all permissions for a plugin (trusted mode)
-- @param plugin_id string Plugin ID
-- @param capabilities table Array of capability IDs
function PermissionManager.grant_all(plugin_id, capabilities)
  for _, cap_id in ipairs(capabilities) do
    PermissionManager.grant(plugin_id, cap_id, {auto = true})
  end
end

--- Default console UI handler
-- @param plugin_id string Plugin ID
-- @param prompts table Array of permission prompts
-- @param callback function(decisions) Called with decisions map
function PermissionManager.default_console_handler(plugin_id, prompts, callback)
  print(string.format("\n=== Permission Request: %s ===", plugin_id))

  local decisions = {}

  for _, prompt in ipairs(prompts) do
    print(string.format("\n[%s] %s", prompt.risk_level, prompt.name))
    print("  " .. prompt.prompt)

    if prompt.warnings then
      for _, warning in ipairs(prompt.warnings) do
        print("  WARNING: " .. warning)
      end
    end

    io.write("Grant permission? (y/n): ")
    local input = io.read()
    decisions[prompt.id] = (input == "y" or input == "Y")
  end

  print("")
  callback(decisions)
end

return PermissionManager
