--- Capability Checker
-- Runtime capability validation with security logging
-- @module whisker.security.capability_checker
-- @author Whisker Core Team
-- @license MIT

local Capabilities = require("whisker.security.capabilities")
local SecurityContext = require("whisker.security.security_context")

local CapabilityChecker = {}

--- Security event logger (injected)
local _logger = nil

--- Permission manager (injected)
local _permission_manager = nil

--- Set security logger
-- @param logger table Logger with log_security_event method
function CapabilityChecker.set_logger(logger)
  _logger = logger
end

--- Set permission manager
-- @param manager table Permission manager instance
function CapabilityChecker.set_permission_manager(manager)
  _permission_manager = manager
end

--- Log security event
-- @param event_type string Event type
-- @param details table Event details
local function log_event(event_type, details)
  if _logger and _logger.log_security_event then
    _logger.log_security_event(event_type, details)
  end
end

--- Check if plugin has declared a capability
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return boolean True if declared
function CapabilityChecker.has_declared_capability(plugin_id, capability_id)
  -- Check current security context
  return SecurityContext.has_capability(capability_id)
end

--- Check if user has granted permission for capability
-- @param plugin_id string Plugin ID
-- @param capability_id string Capability ID
-- @return boolean True if granted
function CapabilityChecker.has_permission(plugin_id, capability_id)
  if not _permission_manager then
    -- No permission manager means running in trusted mode
    return true
  end

  return _permission_manager.is_granted(plugin_id, capability_id)
end

--- Full capability check (declared + permitted)
-- @param capability_id string Capability ID
-- @return boolean allowed
-- @return string|nil reason Denial reason if not allowed
function CapabilityChecker.check_capability(capability_id)
  -- Validate capability exists
  if not Capabilities.is_valid(capability_id) then
    return false, string.format("Unknown capability: %s", capability_id)
  end

  -- Get current context
  local plugin_id = SecurityContext.get_plugin_id()

  if not plugin_id then
    -- No plugin context = core code = allowed
    return true
  end

  -- Check declared capability
  if not CapabilityChecker.has_declared_capability(plugin_id, capability_id) then
    log_event("CAPABILITY_NOT_DECLARED", {
      plugin_id = plugin_id,
      capability = capability_id,
    })
    return false, string.format(
      "Plugin '%s' did not declare capability '%s' in manifest",
      plugin_id,
      capability_id
    )
  end

  -- Check user permission
  if not CapabilityChecker.has_permission(plugin_id, capability_id) then
    log_event("CAPABILITY_NOT_PERMITTED", {
      plugin_id = plugin_id,
      capability = capability_id,
    })
    return false, string.format(
      "User has not granted '%s' permission to plugin '%s'",
      capability_id,
      plugin_id
    )
  end

  -- Log successful access for high-risk capabilities
  if Capabilities.is_high_risk(capability_id) then
    log_event("HIGH_RISK_CAPABILITY_USED", {
      plugin_id = plugin_id,
      capability = capability_id,
    })
  end

  return true
end

--- Require capability - throws error if not allowed
-- @param capability_id string Capability ID
-- @error If capability check fails
function CapabilityChecker.require_capability(capability_id)
  local allowed, reason = CapabilityChecker.check_capability(capability_id)
  if not allowed then
    error(reason, 2)
  end
end

--- Check multiple capabilities at once
-- @param capability_ids table Array of capability IDs
-- @return boolean allowed
-- @return string|nil reason Denial reason for first failed capability
function CapabilityChecker.check_capabilities(capability_ids)
  for _, cap_id in ipairs(capability_ids) do
    local allowed, reason = CapabilityChecker.check_capability(cap_id)
    if not allowed then
      return false, reason
    end
  end
  return true
end

--- Require multiple capabilities - throws error if any not allowed
-- @param capability_ids table Array of capability IDs
-- @error If any capability check fails
function CapabilityChecker.require_capabilities(capability_ids)
  for _, cap_id in ipairs(capability_ids) do
    CapabilityChecker.require_capability(cap_id)
  end
end

--- Validate plugin manifest capabilities
-- @param manifest table Plugin manifest with capabilities field
-- @return boolean valid
-- @return string|nil error Error message if invalid
function CapabilityChecker.validate_manifest(manifest)
  if not manifest.capabilities then
    -- No capabilities declared = valid (plugin requests nothing)
    return true
  end

  if type(manifest.capabilities) ~= "table" then
    return false, "Manifest capabilities must be array"
  end

  -- Validate each capability
  local valid, err = Capabilities.validate(manifest.capabilities)
  if not valid then
    return false, err
  end

  -- Check for conflicting capabilities
  local cap_set = Capabilities.to_set(manifest.capabilities)

  -- WRITE_STATE requires READ_STATE
  if cap_set.WRITE_STATE and not cap_set.READ_STATE then
    return false, "WRITE_STATE capability requires READ_STATE"
  end

  return true
end

--- Get capabilities that would be missing for an operation
-- @param required_capabilities table Array of required capability IDs
-- @return table Array of missing capability IDs
function CapabilityChecker.get_missing_capabilities(required_capabilities)
  local missing = {}
  local plugin_id = SecurityContext.get_plugin_id()

  if not plugin_id then
    -- Core code has all capabilities
    return {}
  end

  for _, cap_id in ipairs(required_capabilities) do
    if not CapabilityChecker.has_declared_capability(plugin_id, cap_id) then
      table.insert(missing, cap_id)
    elseif not CapabilityChecker.has_permission(plugin_id, cap_id) then
      table.insert(missing, cap_id)
    end
  end

  return missing
end

--- Create a capability-checked wrapper function
-- @param capability_id string Required capability
-- @param fn function Function to wrap
-- @return function Wrapped function that checks capability
function CapabilityChecker.with_capability(capability_id, fn)
  return function(...)
    CapabilityChecker.require_capability(capability_id)
    return fn(...)
  end
end

--- Create a multi-capability-checked wrapper function
-- @param capability_ids table Required capabilities
-- @param fn function Function to wrap
-- @return function Wrapped function that checks capabilities
function CapabilityChecker.with_capabilities(capability_ids, fn)
  return function(...)
    CapabilityChecker.require_capabilities(capability_ids)
    return fn(...)
  end
end

--- Execute function only if capability check passes
-- @param capability_id string Required capability
-- @param fn function Function to execute
-- @param ... any Arguments
-- @return boolean success
-- @return any result Function result or error message
function CapabilityChecker.if_capable(capability_id, fn, ...)
  local allowed, reason = CapabilityChecker.check_capability(capability_id)
  if not allowed then
    return false, reason
  end

  local results = {pcall(fn, ...)}
  if results[1] then
    return true, select(2, table.unpack(results))
  else
    return false, results[2]
  end
end

--- Get current plugin's capabilities (for introspection)
-- @return table Array of capability IDs
function CapabilityChecker.get_current_capabilities()
  local cap_set = SecurityContext.get_capabilities()
  return Capabilities.from_set(cap_set)
end

--- Check if running in trusted mode (no restrictions)
-- @return boolean True if in trusted mode
function CapabilityChecker.is_trusted_mode()
  return not SecurityContext.in_plugin_context()
end

return CapabilityChecker
