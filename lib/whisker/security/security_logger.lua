--- Security Logger
-- Audit logging for security events
-- @module whisker.security.security_logger
-- @author Whisker Core Team
-- @license MIT

local SecurityLogger = {}

--- Log levels
SecurityLogger.LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  SECURITY = 5,
}

--- Event types
SecurityLogger.EVENTS = {
  -- Capability events
  CAPABILITY_NOT_DECLARED = "CAPABILITY_NOT_DECLARED",
  CAPABILITY_NOT_PERMITTED = "CAPABILITY_NOT_PERMITTED",
  HIGH_RISK_CAPABILITY_USED = "HIGH_RISK_CAPABILITY_USED",

  -- Permission events
  PERMISSION_REQUEST = "PERMISSION_REQUEST",
  PERMISSION_GRANTED = "PERMISSION_GRANTED",
  PERMISSION_DENIED = "PERMISSION_DENIED",
  PERMISSION_REVOKED = "PERMISSION_REVOKED",
  PERMISSION_RESET = "PERMISSION_RESET",

  -- Sandbox events
  SANDBOX_ESCAPE_ATTEMPT = "SANDBOX_ESCAPE_ATTEMPT",
  SANDBOX_TIMEOUT = "SANDBOX_TIMEOUT",
  SANDBOX_MEMORY_LIMIT = "SANDBOX_MEMORY_LIMIT",

  -- Content security events
  XSS_BLOCKED = "XSS_BLOCKED",
  DANGEROUS_TAG_REMOVED = "DANGEROUS_TAG_REMOVED",
  DANGEROUS_ATTRIBUTE_REMOVED = "DANGEROUS_ATTRIBUTE_REMOVED",

  -- Path security events
  PATH_TRAVERSAL_BLOCKED = "PATH_TRAVERSAL_BLOCKED",
  INVALID_PATH_BLOCKED = "INVALID_PATH_BLOCKED",

  -- General security events
  SECURITY_VIOLATION = "SECURITY_VIOLATION",
  SUSPICIOUS_ACTIVITY = "SUSPICIOUS_ACTIVITY",
}

--- Internal state
local _log_path = nil
local _log_level = SecurityLogger.LEVELS.INFO
local _memory_logs = {}
local _max_memory_logs = 1000
local _output_handler = nil

--- Initialize security logger
-- @param path string|nil Log file path
-- @param options table|nil {level, max_memory_logs}
function SecurityLogger.init(path, options)
  options = options or {}

  _log_path = path
  _log_level = options.level or SecurityLogger.LEVELS.INFO
  _max_memory_logs = options.max_memory_logs or 1000
  _memory_logs = {}
end

--- Set output handler for custom log destinations
-- @param handler function(entry) Called for each log entry
function SecurityLogger.set_output_handler(handler)
  _output_handler = handler
end

--- Set log level
-- @param level number Log level from LEVELS
function SecurityLogger.set_level(level)
  _log_level = level
end

--- Format timestamp
-- @return string ISO 8601 timestamp
local function format_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Create log entry
-- @param level number Log level
-- @param event_type string Event type
-- @param message string Log message
-- @param details table|nil Additional details
-- @return table Log entry
local function create_entry(level, event_type, message, details)
  return {
    timestamp = format_timestamp(),
    level = level,
    event = event_type,
    message = message,
    details = details or {},
  }
end

--- Write log entry to file
-- @param entry table Log entry
local function write_to_file(entry)
  if not _log_path then
    return
  end

  local file = io.open(_log_path, "a")
  if not file then
    return
  end

  local line = string.format(
    "[%s] [%s] %s: %s",
    entry.timestamp,
    entry.event,
    entry.message,
    SecurityLogger.serialize_details(entry.details)
  )

  file:write(line .. "\n")
  file:close()
end

--- Store log entry in memory
-- @param entry table Log entry
local function store_in_memory(entry)
  table.insert(_memory_logs, entry)

  -- Trim if over limit
  while #_memory_logs > _max_memory_logs do
    table.remove(_memory_logs, 1)
  end
end

--- Serialize details for logging
-- @param details table Details to serialize
-- @return string Serialized string
function SecurityLogger.serialize_details(details)
  if not details or next(details) == nil then
    return ""
  end

  local parts = {}
  for k, v in pairs(details) do
    if type(v) == "table" then
      table.insert(parts, k .. "=[...]")
    else
      table.insert(parts, k .. "=" .. tostring(v))
    end
  end

  return table.concat(parts, ", ")
end

--- Log a security event
-- @param event_type string Event type from EVENTS
-- @param details table Event details
function SecurityLogger.log_security_event(event_type, details)
  local message = event_type

  -- Add context from details
  if details.plugin_id then
    message = message .. " [plugin:" .. details.plugin_id .. "]"
  end
  if details.capability then
    message = message .. " [cap:" .. details.capability .. "]"
  end

  local entry = create_entry(
    SecurityLogger.LEVELS.SECURITY,
    event_type,
    message,
    details
  )

  store_in_memory(entry)
  write_to_file(entry)

  if _output_handler then
    _output_handler(entry)
  end
end

--- Log debug message
-- @param message string Message
-- @param details table|nil Details
function SecurityLogger.debug(message, details)
  if _log_level > SecurityLogger.LEVELS.DEBUG then
    return
  end

  local entry = create_entry(SecurityLogger.LEVELS.DEBUG, "DEBUG", message, details)
  store_in_memory(entry)

  if _output_handler then
    _output_handler(entry)
  end
end

--- Log info message
-- @param message string Message
-- @param details table|nil Details
function SecurityLogger.info(message, details)
  if _log_level > SecurityLogger.LEVELS.INFO then
    return
  end

  local entry = create_entry(SecurityLogger.LEVELS.INFO, "INFO", message, details)
  store_in_memory(entry)
  write_to_file(entry)

  if _output_handler then
    _output_handler(entry)
  end
end

--- Log warning message
-- @param message string Message
-- @param details table|nil Details
function SecurityLogger.warn(message, details)
  if _log_level > SecurityLogger.LEVELS.WARN then
    return
  end

  local entry = create_entry(SecurityLogger.LEVELS.WARN, "WARN", message, details)
  store_in_memory(entry)
  write_to_file(entry)

  if _output_handler then
    _output_handler(entry)
  end
end

--- Log error message
-- @param message string Message
-- @param details table|nil Details
function SecurityLogger.error(message, details)
  local entry = create_entry(SecurityLogger.LEVELS.ERROR, "ERROR", message, details)
  store_in_memory(entry)
  write_to_file(entry)

  if _output_handler then
    _output_handler(entry)
  end
end

--- Get recent security events
-- @param count number|nil Number of events (default 100)
-- @param event_type string|nil Filter by event type
-- @return table Array of log entries
function SecurityLogger.get_recent(count, event_type)
  count = count or 100
  local result = {}

  -- Iterate in reverse (newest first)
  for i = #_memory_logs, 1, -1 do
    local entry = _memory_logs[i]

    if not event_type or entry.event == event_type then
      table.insert(result, entry)

      if #result >= count then
        break
      end
    end
  end

  return result
end

--- Get security events for a plugin
-- @param plugin_id string Plugin ID
-- @param count number|nil Max count
-- @return table Array of log entries
function SecurityLogger.get_plugin_events(plugin_id, count)
  count = count or 100
  local result = {}

  for i = #_memory_logs, 1, -1 do
    local entry = _memory_logs[i]

    if entry.details and entry.details.plugin_id == plugin_id then
      table.insert(result, entry)

      if #result >= count then
        break
      end
    end
  end

  return result
end

--- Get all security violations
-- @return table Array of violation entries
function SecurityLogger.get_violations()
  local violations = {}

  local violation_events = {
    SecurityLogger.EVENTS.CAPABILITY_NOT_DECLARED,
    SecurityLogger.EVENTS.CAPABILITY_NOT_PERMITTED,
    SecurityLogger.EVENTS.SANDBOX_ESCAPE_ATTEMPT,
    SecurityLogger.EVENTS.XSS_BLOCKED,
    SecurityLogger.EVENTS.PATH_TRAVERSAL_BLOCKED,
    SecurityLogger.EVENTS.SECURITY_VIOLATION,
  }

  local violation_set = {}
  for _, event in ipairs(violation_events) do
    violation_set[event] = true
  end

  for _, entry in ipairs(_memory_logs) do
    if violation_set[entry.event] then
      table.insert(violations, entry)
    end
  end

  return violations
end

--- Clear memory logs
function SecurityLogger.clear()
  _memory_logs = {}
end

--- Get log statistics
-- @return table Statistics
function SecurityLogger.get_stats()
  local stats = {
    total_events = #_memory_logs,
    events_by_type = {},
    security_violations = 0,
  }

  for _, entry in ipairs(_memory_logs) do
    stats.events_by_type[entry.event] = (stats.events_by_type[entry.event] or 0) + 1

    if entry.level == SecurityLogger.LEVELS.SECURITY then
      stats.security_violations = stats.security_violations + 1
    end
  end

  return stats
end

--- Export logs for audit
-- @param start_time string|nil ISO timestamp
-- @param end_time string|nil ISO timestamp
-- @return table Array of log entries
function SecurityLogger.export(start_time, end_time)
  local result = {}

  for _, entry in ipairs(_memory_logs) do
    local include = true

    if start_time and entry.timestamp < start_time then
      include = false
    end
    if end_time and entry.timestamp > end_time then
      include = false
    end

    if include then
      table.insert(result, entry)
    end
  end

  return result
end

return SecurityLogger
