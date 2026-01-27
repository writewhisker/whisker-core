-- lib/whisker/validation/developer_errors.lua
-- WLS 1.0 Developer Error Handling
-- Implements GAP-052: Developer Errors

local DeveloperErrors = {}
DeveloperErrors.__index = DeveloperErrors

--- Error severity levels for developer errors
DeveloperErrors.SEVERITY = {
    DEBUG = "debug",
    INFO = "info",
    WARNING = "warning",
    ERROR = "error",
    FATAL = "fatal"
}

--- Error categories for developer errors
DeveloperErrors.CATEGORIES = {
    SYNTAX = "syntax",
    SEMANTIC = "semantic",
    RUNTIME = "runtime",
    TYPE = "type",
    REFERENCE = "reference",
    VALIDATION = "validation",
    INTERNAL = "internal"
}

--- Error codes for developer errors
DeveloperErrors.CODES = {
    -- Syntax errors (100-199)
    UNEXPECTED_TOKEN = "WLS-DEV-100",
    UNTERMINATED_STRING = "WLS-DEV-101",
    INVALID_ESCAPE = "WLS-DEV-102",
    MALFORMED_DIRECTIVE = "WLS-DEV-103",
    MISSING_DELIMITER = "WLS-DEV-104",
    INVALID_IDENTIFIER = "WLS-DEV-105",

    -- Semantic errors (200-299)
    UNDEFINED_VARIABLE = "WLS-DEV-200",
    UNDEFINED_FUNCTION = "WLS-DEV-201",
    UNDEFINED_PASSAGE = "WLS-DEV-202",
    UNDEFINED_NAMESPACE = "WLS-DEV-203",
    DUPLICATE_DEFINITION = "WLS-DEV-204",
    CIRCULAR_DEPENDENCY = "WLS-DEV-205",

    -- Type errors (300-399)
    TYPE_MISMATCH = "WLS-DEV-300",
    INVALID_ARGUMENT = "WLS-DEV-301",
    INVALID_OPERATION = "WLS-DEV-302",
    NOT_CALLABLE = "WLS-DEV-303",
    NOT_ITERABLE = "WLS-DEV-304",

    -- Runtime errors (400-499)
    STACK_OVERFLOW = "WLS-DEV-400",
    RECURSION_LIMIT = "WLS-DEV-401",
    DIVISION_BY_ZERO = "WLS-DEV-402",
    INDEX_OUT_OF_BOUNDS = "WLS-DEV-403",
    NULL_REFERENCE = "WLS-DEV-404",

    -- Reference errors (500-599)
    MISSING_FILE = "WLS-DEV-500",
    INVALID_PATH = "WLS-DEV-501",
    CIRCULAR_INCLUDE = "WLS-DEV-502",
    INCLUDE_DEPTH = "WLS-DEV-503",

    -- Validation errors (600-699)
    SCHEMA_VIOLATION = "WLS-DEV-600",
    CONSTRAINT_VIOLATION = "WLS-DEV-601",
    INVALID_CONFIGURATION = "WLS-DEV-602",

    -- Internal errors (900-999)
    INTERNAL_ERROR = "WLS-DEV-900",
    NOT_IMPLEMENTED = "WLS-DEV-901",
    ASSERTION_FAILED = "WLS-DEV-902"
}

--- Create a new developer errors manager
---@param config table|nil Configuration options
---@return DeveloperErrors
function DeveloperErrors.new(config)
    config = config or {}
    local self = setmetatable({}, DeveloperErrors)

    self.config = {
        -- Show stack traces
        show_stack_traces = config.show_stack_traces ~= false,
        -- Callback when error occurs
        on_error = config.on_error or nil,
        -- Whether to collect errors or throw immediately
        collect_mode = config.collect_mode or false,
        -- Maximum errors before stopping
        max_errors = config.max_errors or 100,
        -- Minimum severity to report
        min_severity = config.min_severity or DeveloperErrors.SEVERITY.DEBUG
    }

    self.errors = {}
    self.error_count = 0

    return self
end

--- Create a detailed error object
---@param code string Error code
---@param message string Error message
---@param severity string Severity level
---@param category string Error category
---@param location table|nil Source location {file, line, column}
---@param context table|nil Additional context
---@return table Developer error object
function DeveloperErrors:create(code, message, severity, category, location, context)
    local error_obj = {
        code = code,
        message = message,
        severity = severity,
        category = category,
        location = location or {},
        context = context or {},
        timestamp = os.time()
    }

    -- Add stack trace if enabled
    if self.config.show_stack_traces then
        error_obj.stack_trace = debug.traceback("", 3)
    end

    return error_obj
end

--- Report an error
---@param code string Error code
---@param message string Error message
---@param severity string Severity level
---@param category string Error category
---@param location table|nil Source location
---@param context table|nil Additional context
---@return table The error object
function DeveloperErrors:report(code, message, severity, category, location, context)
    -- Check minimum severity
    if not self:meets_min_severity(severity) then
        return nil
    end

    local error_obj = self:create(code, message, severity, category, location, context)

    if self.config.collect_mode then
        -- Check max errors before adding
        if self.error_count >= self.config.max_errors then
            error(string.format(
                "Maximum error limit (%d) reached. Stopping.",
                self.config.max_errors
            ))
        end

        -- Store error
        table.insert(self.errors, error_obj)
        self.error_count = self.error_count + 1
    end

    -- Call error callback if set
    if self.config.on_error then
        self.config.on_error(error_obj)
    end

    -- For fatal errors, raise immediately
    if severity == DeveloperErrors.SEVERITY.FATAL then
        error(self:format_error(error_obj))
    end

    return error_obj
end

--- Check if severity meets minimum threshold
---@param severity string
---@return boolean
function DeveloperErrors:meets_min_severity(severity)
    local order = {
        [DeveloperErrors.SEVERITY.DEBUG] = 1,
        [DeveloperErrors.SEVERITY.INFO] = 2,
        [DeveloperErrors.SEVERITY.WARNING] = 3,
        [DeveloperErrors.SEVERITY.ERROR] = 4,
        [DeveloperErrors.SEVERITY.FATAL] = 5
    }

    local min_order = order[self.config.min_severity] or 1
    local sev_order = order[severity] or 1

    return sev_order >= min_order
end

--- Format an error for display
---@param error_obj table The error object
---@return string Formatted error message
function DeveloperErrors:format_error(error_obj)
    local parts = {}

    -- Header with code and severity
    table.insert(parts, string.format(
        "[%s] %s: %s",
        error_obj.severity:upper(),
        error_obj.code,
        error_obj.message
    ))

    -- Location if available
    if error_obj.location and error_obj.location.file then
        table.insert(parts, string.format(
            "  at %s:%d:%d",
            error_obj.location.file or "unknown",
            error_obj.location.line or 0,
            error_obj.location.column or 0
        ))
    end

    -- Context details
    if error_obj.context and next(error_obj.context) then
        table.insert(parts, "  Context:")
        for k, v in pairs(error_obj.context) do
            table.insert(parts, string.format("    %s: %s", k, tostring(v)))
        end
    end

    -- Stack trace if available
    if error_obj.stack_trace then
        table.insert(parts, "  Stack trace:")
        for line in error_obj.stack_trace:gmatch("[^\n]+") do
            if not line:match("^%s*$") then
                table.insert(parts, "    " .. line)
            end
        end
    end

    return table.concat(parts, "\n")
end

--- Get all collected errors
---@param filter table|nil Filter options
---@return table List of errors
function DeveloperErrors:get_all(filter)
    if not filter then
        return self.errors
    end

    local result = {}
    for _, err in ipairs(self.errors) do
        local include = true

        if filter.severity and err.severity ~= filter.severity then
            include = false
        end

        if filter.category and err.category ~= filter.category then
            include = false
        end

        if filter.code and err.code ~= filter.code then
            include = false
        end

        if filter.file and (not err.location or err.location.file ~= filter.file) then
            include = false
        end

        if include then
            table.insert(result, err)
        end
    end

    return result
end

--- Clear collected errors
function DeveloperErrors:clear()
    self.errors = {}
    self.error_count = 0
end

--- Check if there are any errors
---@param min_severity string|nil Minimum severity to count
---@return boolean
function DeveloperErrors:has_errors(min_severity)
    min_severity = min_severity or DeveloperErrors.SEVERITY.ERROR

    local order = {
        [DeveloperErrors.SEVERITY.DEBUG] = 1,
        [DeveloperErrors.SEVERITY.INFO] = 2,
        [DeveloperErrors.SEVERITY.WARNING] = 3,
        [DeveloperErrors.SEVERITY.ERROR] = 4,
        [DeveloperErrors.SEVERITY.FATAL] = 5
    }

    local min_order = order[min_severity] or 4

    for _, err in ipairs(self.errors) do
        if (order[err.severity] or 0) >= min_order then
            return true
        end
    end

    return false
end

--- Get error counts by severity
---@return table Counts by severity
function DeveloperErrors:get_counts()
    local counts = {
        [DeveloperErrors.SEVERITY.DEBUG] = 0,
        [DeveloperErrors.SEVERITY.INFO] = 0,
        [DeveloperErrors.SEVERITY.WARNING] = 0,
        [DeveloperErrors.SEVERITY.ERROR] = 0,
        [DeveloperErrors.SEVERITY.FATAL] = 0,
        total = 0
    }

    for _, err in ipairs(self.errors) do
        counts[err.severity] = (counts[err.severity] or 0) + 1
        counts.total = counts.total + 1
    end

    return counts
end

--- Generate a diagnostic report
---@param options table|nil Report options
---@return string Diagnostic report
function DeveloperErrors:generate_report(options)
    options = options or {}
    local lines = {}

    local counts = self:get_counts()

    table.insert(lines, "=== Developer Error Report ===")
    table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, "")

    table.insert(lines, "Summary:")
    table.insert(lines, string.format("  Total: %d", counts.total))
    table.insert(lines, string.format("  Fatal: %d", counts[DeveloperErrors.SEVERITY.FATAL]))
    table.insert(lines, string.format("  Errors: %d", counts[DeveloperErrors.SEVERITY.ERROR]))
    table.insert(lines, string.format("  Warnings: %d", counts[DeveloperErrors.SEVERITY.WARNING]))
    table.insert(lines, string.format("  Info: %d", counts[DeveloperErrors.SEVERITY.INFO]))
    table.insert(lines, string.format("  Debug: %d", counts[DeveloperErrors.SEVERITY.DEBUG]))
    table.insert(lines, "")

    -- Group by category
    local by_category = {}
    for _, err in ipairs(self.errors) do
        local cat = err.category
        if not by_category[cat] then
            by_category[cat] = {}
        end
        table.insert(by_category[cat], err)
    end

    for cat, errors in pairs(by_category) do
        table.insert(lines, string.format("--- %s Errors (%d) ---", cat:upper(), #errors))
        table.insert(lines, "")

        for _, err in ipairs(errors) do
            table.insert(lines, self:format_error(err))
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

--- Convenience methods for specific error types

function DeveloperErrors:syntax_error(message, location, context)
    return self:report(
        DeveloperErrors.CODES.UNEXPECTED_TOKEN,
        message,
        DeveloperErrors.SEVERITY.ERROR,
        DeveloperErrors.CATEGORIES.SYNTAX,
        location,
        context
    )
end

function DeveloperErrors:undefined_reference(type_name, name, location)
    local code_map = {
        variable = DeveloperErrors.CODES.UNDEFINED_VARIABLE,
        ["function"] = DeveloperErrors.CODES.UNDEFINED_FUNCTION,
        passage = DeveloperErrors.CODES.UNDEFINED_PASSAGE,
        namespace = DeveloperErrors.CODES.UNDEFINED_NAMESPACE
    }

    return self:report(
        code_map[type_name] or DeveloperErrors.CODES.UNDEFINED_VARIABLE,
        string.format("Undefined %s: '%s'", type_name, name),
        DeveloperErrors.SEVERITY.ERROR,
        DeveloperErrors.CATEGORIES.SEMANTIC,
        location,
        { reference_type = type_name, name = name }
    )
end

function DeveloperErrors:type_error(expected, got, location, context)
    return self:report(
        DeveloperErrors.CODES.TYPE_MISMATCH,
        string.format("Type mismatch: expected %s, got %s", expected, got),
        DeveloperErrors.SEVERITY.ERROR,
        DeveloperErrors.CATEGORIES.TYPE,
        location,
        { expected = expected, got = got, context = context }
    )
end

function DeveloperErrors:runtime_error(message, location, context)
    return self:report(
        DeveloperErrors.CODES.STACK_OVERFLOW,
        message,
        DeveloperErrors.SEVERITY.ERROR,
        DeveloperErrors.CATEGORIES.RUNTIME,
        location,
        context
    )
end

function DeveloperErrors:internal_error(message, context)
    return self:report(
        DeveloperErrors.CODES.INTERNAL_ERROR,
        message,
        DeveloperErrors.SEVERITY.FATAL,
        DeveloperErrors.CATEGORIES.INTERNAL,
        nil,
        context
    )
end

--- Enable/disable collect mode
---@param enabled boolean
function DeveloperErrors:set_collect_mode(enabled)
    self.config.collect_mode = enabled
end

--- Set error callback
---@param callback function
function DeveloperErrors:set_error_callback(callback)
    self.config.on_error = callback
end

return DeveloperErrors
