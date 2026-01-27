-- lib/whisker/cli/formatter.lua
-- CLI output formatting utilities
-- WLS 1.0 GAP-059: Standardized CLI output formatting

local json = require("lib.whisker.utils.json")

local Formatter = {}
Formatter.__index = Formatter

-- ANSI color codes
Formatter.COLORS = {
    reset = "\27[0m",
    bold = "\27[1m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    gray = "\27[90m",
}

--- Create a new Formatter instance
---@param options table|nil Options { format = "plain"|"json"|"compact", colors = boolean, verbose = boolean }
---@return Formatter
function Formatter.new(options)
    options = options or {}
    local self = setmetatable({}, Formatter)
    self.format = options.format or "plain"
    self.colors = options.colors ~= false
    self.verbose = options.verbose or false
    return self
end

--- Apply color if enabled
---@param text string Text to colorize
---@param color string Color name from COLORS table
---@return string
function Formatter:color(text, color)
    if not self.colors then
        return text
    end
    local code = self.COLORS[color]
    if code then
        return code .. text .. self.COLORS.reset
    end
    return text
end

--- Format a diagnostic for CLI output
---@param diag table Diagnostic { code, message, severity, location?, passage_id?, suggestion? }
---@return string
function Formatter:format_diagnostic(diag)
    if self.format == "json" then
        return self:format_diagnostic_json(diag)
    elseif self.format == "compact" then
        return self:format_diagnostic_compact(diag)
    else
        return self:format_diagnostic_plain(diag)
    end
end

--- Plain format (multi-line, human readable)
---@param diag table Diagnostic
---@return string
function Formatter:format_diagnostic_plain(diag)
    local lines = {}

    -- Severity icon and color
    local icon, color
    if diag.severity == "error" then
        icon = "X"
        color = "red"
    elseif diag.severity == "warning" then
        icon = "!"
        color = "yellow"
    else
        icon = "i"
        color = "blue"
    end

    -- First line: icon, code, message
    local header = string.format("%s %s: %s",
        self:color(icon, color),
        self:color(diag.code or "UNKNOWN", "gray"),
        diag.message or "No message"
    )
    table.insert(lines, header)

    -- Location
    if diag.location then
        local loc = self:format_location(diag.location)
        if loc ~= "" then
            table.insert(lines, "    " .. self:color("at", "gray") .. " " .. loc)
        end
    elseif diag.passage_id then
        table.insert(lines, "    " .. self:color("in passage", "gray") .. " " .. diag.passage_id)
    end

    -- Suggestion
    if diag.suggestion then
        table.insert(lines, "    " .. self:color("hint:", "cyan") .. " " .. diag.suggestion)
    end

    return table.concat(lines, "\n")
end

--- Compact format (single line)
---@param diag table Diagnostic
---@return string
function Formatter:format_diagnostic_compact(diag)
    local loc = ""
    if diag.location then
        loc = self:format_location(diag.location) .. ": "
    elseif diag.passage_id then
        loc = diag.passage_id .. ": "
    end

    local severity = (diag.severity or "info"):sub(1, 1):upper()  -- E, W, I
    return string.format("%s %s%s %s", severity, loc, diag.code or "UNKNOWN", diag.message or "")
end

--- JSON format
---@param diag table Diagnostic
---@return string
function Formatter:format_diagnostic_json(diag)
    return json.encode(diag)
end

--- Format location string
---@param loc table Location { file?, line?, column? }
---@return string
function Formatter:format_location(loc)
    local parts = {}
    if loc.file then
        table.insert(parts, loc.file)
    end
    if loc.line then
        table.insert(parts, tostring(loc.line))
        if loc.column then
            table.insert(parts, tostring(loc.column))
        end
    end
    return table.concat(parts, ":")
end

--- Format multiple diagnostics
---@param diagnostics table Array of diagnostics
---@return string
function Formatter:format_diagnostics(diagnostics)
    if self.format == "json" then
        return json.encode(diagnostics, 2)
    end

    local lines = {}
    for _, diag in ipairs(diagnostics) do
        table.insert(lines, self:format_diagnostic(diag))
    end
    return table.concat(lines, "\n")
end

--- Format summary
---@param errors number Error count
---@param warnings number Warning count
---@return string
function Formatter:format_summary(errors, warnings)
    if self.format == "json" then
        return ""  -- Summary in JSON is part of the structure
    end

    local parts = {}
    if errors > 0 then
        table.insert(parts, self:color(errors .. " error(s)", "red"))
    end
    if warnings > 0 then
        table.insert(parts, self:color(warnings .. " warning(s)", "yellow"))
    end

    if #parts == 0 then
        return self:color("No issues found", "green")
    end

    return "Found " .. table.concat(parts, ", ")
end

--- Format success message
---@param message string Message to format
---@return string
function Formatter:success(message)
    if self.format == "json" then
        return json.encode({ success = true, message = message })
    end
    return self:color("[OK] ", "green") .. message
end

--- Format error message
---@param message string Message to format
---@return string
function Formatter:error(message)
    if self.format == "json" then
        return json.encode({ success = false, error = message })
    end
    return self:color("[ERROR] ", "red") .. message
end

--- Format info message
---@param message string Message to format
---@return string
function Formatter:info(message)
    if self.format == "json" then
        return json.encode({ info = message })
    end
    return self:color("[INFO] ", "blue") .. message
end

--- Format progress message
---@param message string Message to format
---@return string
function Formatter:progress(message)
    if self.format == "json" then
        return ""  -- Skip progress in JSON
    end
    return self:color("-> ", "cyan") .. message
end

--- Format a section header
---@param title string Section title
---@return string
function Formatter:section(title)
    if self.format == "json" then
        return ""
    end
    return "\n" .. self:color(title, "bold") .. "\n" .. string.rep("-", #title)
end

--- Format a key-value pair
---@param key string Key name
---@param value any Value
---@return string
function Formatter:keyval(key, value)
    if self.format == "json" then
        return json.encode({ [key] = value })
    end
    return self:color(key .. ":", "gray") .. " " .. tostring(value)
end

return Formatter
