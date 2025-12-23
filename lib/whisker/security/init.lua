--- Security Module
-- Main entry point for whisker-core security hardening
-- @module whisker.security
-- @author Whisker Core Team
-- @license MIT

local Security = {}

--- Load security submodules lazily
local _capabilities = nil
local _capability_checker = nil
local _security_context = nil
local _permission_manager = nil
local _permission_storage = nil
local _sandbox = nil
local _content_sanitizer = nil
local _html_parser = nil
local _csp_generator = nil
local _security_logger = nil

--- Get capabilities registry
-- @return Capabilities
function Security.capabilities()
  if not _capabilities then
    _capabilities = require("whisker.security.capabilities")
  end
  return _capabilities
end

--- Get capability checker
-- @return CapabilityChecker
function Security.capability_checker()
  if not _capability_checker then
    _capability_checker = require("whisker.security.capability_checker")
  end
  return _capability_checker
end

--- Get security context
-- @return SecurityContext
function Security.security_context()
  if not _security_context then
    _security_context = require("whisker.security.security_context")
  end
  return _security_context
end

--- Get permission manager
-- @return PermissionManager
function Security.permission_manager()
  if not _permission_manager then
    _permission_manager = require("whisker.security.permission_manager")
  end
  return _permission_manager
end

--- Get permission storage
-- @return PermissionStorage
function Security.permission_storage()
  if not _permission_storage then
    _permission_storage = require("whisker.security.permission_storage")
  end
  return _permission_storage
end

--- Get sandbox
-- @return Sandbox
function Security.sandbox()
  if not _sandbox then
    _sandbox = require("whisker.security.sandbox")
  end
  return _sandbox
end

--- Get content sanitizer
-- @return ContentSanitizer
function Security.content_sanitizer()
  if not _content_sanitizer then
    _content_sanitizer = require("whisker.security.content_sanitizer")
  end
  return _content_sanitizer
end

--- Get HTML parser
-- @return HTMLParser
function Security.html_parser()
  if not _html_parser then
    _html_parser = require("whisker.security.html_parser")
  end
  return _html_parser
end

--- Get CSP generator
-- @return CSPGenerator
function Security.csp_generator()
  if not _csp_generator then
    _csp_generator = require("whisker.security.csp_generator")
  end
  return _csp_generator
end

--- Get security logger
-- @return SecurityLogger
function Security.security_logger()
  if not _security_logger then
    _security_logger = require("whisker.security.security_logger")
  end
  return _security_logger
end

--- Initialize all security modules
-- @param config table|nil Configuration options
function Security.init(config)
  config = config or {}

  -- Initialize security logger first
  local logger = Security.security_logger()
  if config.log_path then
    logger.init(config.log_path)
  end

  -- Initialize permission storage
  local storage = Security.permission_storage()
  if config.preferences_path then
    storage.init(config.preferences_path)
  else
    storage.init()
  end

  -- Initialize sandbox
  local sandbox = Security.sandbox()
  sandbox.init()

  return Security
end

--- Check if security is enabled
-- @return boolean
function Security.is_enabled()
  return true -- Security is always enabled
end

--- Get security version
-- @return string
function Security.get_version()
  return "1.0.0"
end

return Security
