--- Diagnostic - Standardized Error Message Format
-- WLS 1.0 Gap 29: Error Message Format
-- @module whisker.validation.diagnostic

local Diagnostic = {}
Diagnostic.__index = Diagnostic

--- Severity levels
Diagnostic.SEVERITY = {
    ERROR = "error",
    WARNING = "warning",
    INFO = "info",
    HINT = "hint"
}

--- Create a new diagnostic
---@param code string Error code (e.g., "WLS-VAR-001")
---@param message string Error message
---@param options table Optional: severity, location, suggestion, context, passage_id
---@return table Diagnostic object
function Diagnostic.new(code, message, options)
    options = options or {}

    return {
        code = code,
        message = message,
        severity = options.severity or Diagnostic.SEVERITY.ERROR,
        location = options.location,
        passage_id = options.passage_id,
        suggestion = options.suggestion,
        context = options.context,
        related = options.related,  -- Related diagnostics/locations
        target = options.target,
        line = options.line,
        column = options.column,
        length = options.length,
    }
end

--- Format diagnostic for display
---@param diag table Diagnostic object
---@param options table Formatting options
---@return string Formatted diagnostic
function Diagnostic.format(diag, options)
    options = options or {}
    local lines = {}

    -- Header: CODE: Message
    local severity_prefix = ""
    if diag.severity == "warning" then
        severity_prefix = "Warning "
    elseif diag.severity == "info" then
        severity_prefix = "Info "
    elseif diag.severity == "hint" then
        severity_prefix = "Hint "
    end

    table.insert(lines, string.format("%s%s: %s", severity_prefix, diag.code, diag.message))

    -- Location
    if diag.location then
        local loc = diag.location
        local loc_str = ""

        if loc.file then
            loc_str = loc.file
        elseif diag.passage_id then
            loc_str = "passage " .. diag.passage_id
        end

        if loc.line then
            loc_str = loc_str .. ":" .. loc.line
            if loc.column then
                loc_str = loc_str .. ":" .. loc.column
            end
        end

        if loc_str ~= "" then
            table.insert(lines, "  Location: " .. loc_str)
        end
    elseif diag.passage_id then
        table.insert(lines, "  Passage: " .. diag.passage_id)
    elseif diag.line then
        local loc_str = "line " .. diag.line
        if diag.column then
            loc_str = loc_str .. ", column " .. diag.column
        end
        table.insert(lines, "  Location: " .. loc_str)
    end

    -- Context (code snippet)
    if diag.context and options.show_context ~= false then
        table.insert(lines, "  Context: " .. diag.context)
    end

    -- Suggestion
    if diag.suggestion then
        table.insert(lines, "  Suggestion: " .. diag.suggestion)
    end

    -- Related diagnostics
    if diag.related and #diag.related > 0 and options.show_related then
        table.insert(lines, "  Related:")
        for _, rel in ipairs(diag.related) do
            table.insert(lines, "    - " .. Diagnostic.format(rel, { show_context = false }))
        end
    end

    return table.concat(lines, "\n")
end

--- Format multiple diagnostics
---@param diagnostics table Array of diagnostics
---@param options table Formatting options
---@return string Formatted output
function Diagnostic.format_all(diagnostics, options)
    options = options or {}

    -- Group by severity
    local errors = {}
    local warnings = {}
    local infos = {}

    for _, diag in ipairs(diagnostics) do
        if diag.severity == "error" then
            table.insert(errors, diag)
        elseif diag.severity == "warning" then
            table.insert(warnings, diag)
        else
            table.insert(infos, diag)
        end
    end

    local lines = {}

    -- Format errors first
    if #errors > 0 then
        if options.show_headers then
            table.insert(lines, string.format("Errors (%d):", #errors))
        end
        for _, diag in ipairs(errors) do
            table.insert(lines, Diagnostic.format(diag, options))
        end
    end

    -- Then warnings
    if #warnings > 0 and options.show_warnings ~= false then
        if #errors > 0 then
            table.insert(lines, "")
        end
        if options.show_headers then
            table.insert(lines, string.format("Warnings (%d):", #warnings))
        end
        for _, diag in ipairs(warnings) do
            table.insert(lines, Diagnostic.format(diag, options))
        end
    end

    -- Then info
    if #infos > 0 and options.show_info then
        if #errors > 0 or #warnings > 0 then
            table.insert(lines, "")
        end
        if options.show_headers then
            table.insert(lines, string.format("Info (%d):", #infos))
        end
        for _, diag in ipairs(infos) do
            table.insert(lines, Diagnostic.format(diag, options))
        end
    end

    -- Summary
    if options.show_summary then
        table.insert(lines, "")
        table.insert(lines, string.format(
            "Found %d error(s), %d warning(s)",
            #errors, #warnings
        ))
    end

    return table.concat(lines, "\n")
end

--- Convert diagnostic to LSP-compatible format
---@param diag table Diagnostic object
---@return table LSP diagnostic
function Diagnostic.to_lsp(diag)
    local severity_map = {
        error = 1,
        warning = 2,
        info = 3,
        hint = 4
    }

    local range = {
        start = { line = 0, character = 0 },
        ["end"] = { line = 0, character = 0 }
    }

    if diag.location then
        if diag.location.line then
            range.start.line = diag.location.line - 1  -- LSP is 0-indexed
            range["end"].line = diag.location.line - 1
        end
        if diag.location.column then
            range.start.character = diag.location.column - 1
            range["end"].character = diag.location.column
        end
    elseif diag.line then
        range.start.line = diag.line - 1
        range["end"].line = diag.line - 1
        if diag.column then
            range.start.character = diag.column - 1
            range["end"].character = diag.column
        end
    end

    return {
        range = range,
        severity = severity_map[diag.severity] or 1,
        code = diag.code,
        source = "whisker",
        message = diag.message,
    }
end

--- Count diagnostics by severity
---@param diagnostics table Array of diagnostics
---@return table counts {errors=n, warnings=n, info=n}
function Diagnostic.count_by_severity(diagnostics)
    local counts = { errors = 0, warnings = 0, info = 0, hints = 0 }

    for _, diag in ipairs(diagnostics) do
        if diag.severity == "error" then
            counts.errors = counts.errors + 1
        elseif diag.severity == "warning" then
            counts.warnings = counts.warnings + 1
        elseif diag.severity == "info" then
            counts.info = counts.info + 1
        elseif diag.severity == "hint" then
            counts.hints = counts.hints + 1
        end
    end

    return counts
end

--- Filter diagnostics by severity
---@param diagnostics table Array of diagnostics
---@param severity string Severity to filter by
---@return table Filtered diagnostics
function Diagnostic.filter_by_severity(diagnostics, severity)
    local result = {}
    for _, diag in ipairs(diagnostics) do
        if diag.severity == severity then
            table.insert(result, diag)
        end
    end
    return result
end

--- Filter diagnostics by code prefix
---@param diagnostics table Array of diagnostics
---@param prefix string Code prefix (e.g., "WLS-VAR")
---@return table Filtered diagnostics
function Diagnostic.filter_by_code_prefix(diagnostics, prefix)
    local result = {}
    for _, diag in ipairs(diagnostics) do
        if diag.code and diag.code:sub(1, #prefix) == prefix then
            table.insert(result, diag)
        end
    end
    return result
end

return Diagnostic
