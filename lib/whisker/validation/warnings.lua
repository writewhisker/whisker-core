-- lib/whisker/validation/warnings.lua
-- WLS 1.0 Quality Warnings System
-- Implements GAP-050: Quality Warnings

local Warnings = {}
Warnings.__index = Warnings

--- Warning severity levels
Warnings.SEVERITY = {
    HINT = "hint",
    INFO = "info",
    WARNING = "warning",
    ERROR = "error"
}

--- Warning categories
Warnings.CATEGORIES = {
    STRUCTURE = "structure",
    STYLE = "style",
    ACCESSIBILITY = "accessibility",
    PERFORMANCE = "performance",
    BEST_PRACTICE = "best_practice",
    DEPRECATED = "deprecated"
}

--- Warning codes for different types of issues
Warnings.CODES = {
    -- Structure warnings
    DEAD_END = "WLS-WARN-001",
    ORPHAN_PASSAGE = "WLS-WARN-002",
    UNREACHABLE = "WLS-WARN-003",
    CIRCULAR_REFERENCE = "WLS-WARN-004",
    MISSING_START = "WLS-WARN-005",

    -- Style warnings
    LONG_PASSAGE = "WLS-WARN-010",
    DEEP_NESTING = "WLS-WARN-011",
    INCONSISTENT_NAMING = "WLS-WARN-012",
    UNUSED_VARIABLE = "WLS-WARN-013",

    -- Accessibility warnings
    MISSING_ALT_TEXT = "WLS-WARN-020",
    LOW_CONTRAST = "WLS-WARN-021",
    MISSING_ARIA = "WLS-WARN-022",

    -- Performance warnings
    LARGE_ASSET = "WLS-WARN-030",
    TOO_MANY_ASSETS = "WLS-WARN-031",
    COMPLEX_CONDITION = "WLS-WARN-032",

    -- Best practice warnings
    HARDCODED_TEXT = "WLS-WARN-040",
    MAGIC_NUMBER = "WLS-WARN-041",
    DUPLICATE_CONTENT = "WLS-WARN-042",

    -- Deprecated warnings
    DEPRECATED_SYNTAX = "WLS-WARN-050",
    DEPRECATED_DIRECTIVE = "WLS-WARN-051"
}

--- Create a new warnings manager
---@param config table|nil Configuration options
---@return Warnings
function Warnings.new(config)
    config = config or {}
    local self = setmetatable({}, Warnings)

    self.warnings = {}
    self.config = {
        max_passage_length = config.max_passage_length or 5000,
        max_nesting_depth = config.max_nesting_depth or 5,
        max_asset_size = config.max_asset_size or 5 * 1024 * 1024,  -- 5MB
        max_asset_count = config.max_asset_count or 100,
        enabled_categories = config.enabled_categories or nil,  -- nil = all
        min_severity = config.min_severity or Warnings.SEVERITY.HINT
    }

    return self
end

--- Create a warning entry
---@param code string Warning code
---@param message string Human-readable message
---@param severity string Severity level
---@param category string Warning category
---@param location table|nil Source location
---@param suggestion string|nil Fix suggestion
---@return table Warning entry
function Warnings:create_warning(code, message, severity, category, location, suggestion)
    return {
        code = code,
        message = message,
        severity = severity,
        category = category,
        location = location,
        suggestion = suggestion,
        timestamp = os.time()
    }
end

--- Add a warning
---@param code string Warning code
---@param message string Human-readable message
---@param severity string Severity level
---@param category string Warning category
---@param location table|nil Source location
---@param suggestion string|nil Fix suggestion
function Warnings:add(code, message, severity, category, location, suggestion)
    -- Check if category is enabled
    if self.config.enabled_categories and
       not self:is_category_enabled(category) then
        return
    end

    -- Check minimum severity
    if not self:meets_min_severity(severity) then
        return
    end

    local warning = self:create_warning(code, message, severity, category, location, suggestion)
    table.insert(self.warnings, warning)
end

--- Check if a category is enabled
---@param category string
---@return boolean
function Warnings:is_category_enabled(category)
    if not self.config.enabled_categories then
        return true
    end
    for _, cat in ipairs(self.config.enabled_categories) do
        if cat == category then
            return true
        end
    end
    return false
end

--- Check if severity meets minimum threshold
---@param severity string
---@return boolean
function Warnings:meets_min_severity(severity)
    local order = {
        [Warnings.SEVERITY.HINT] = 1,
        [Warnings.SEVERITY.INFO] = 2,
        [Warnings.SEVERITY.WARNING] = 3,
        [Warnings.SEVERITY.ERROR] = 4
    }

    local min_order = order[self.config.min_severity] or 1
    local sev_order = order[severity] or 1

    return sev_order >= min_order
end

--- Get all warnings
---@param filter table|nil Filter options (severity, category)
---@return table List of warnings
function Warnings:get_all(filter)
    if not filter then
        return self.warnings
    end

    local result = {}
    for _, warning in ipairs(self.warnings) do
        local include = true

        if filter.severity and warning.severity ~= filter.severity then
            include = false
        end

        if filter.category and warning.category ~= filter.category then
            include = false
        end

        if filter.code and warning.code ~= filter.code then
            include = false
        end

        if include then
            table.insert(result, warning)
        end
    end

    return result
end

--- Get warnings grouped by category
---@return table Warnings grouped by category
function Warnings:get_by_category()
    local grouped = {}

    for _, warning in ipairs(self.warnings) do
        local cat = warning.category
        if not grouped[cat] then
            grouped[cat] = {}
        end
        table.insert(grouped[cat], warning)
    end

    return grouped
end

--- Get warning count by severity
---@return table Counts by severity
function Warnings:get_counts()
    local counts = {
        [Warnings.SEVERITY.HINT] = 0,
        [Warnings.SEVERITY.INFO] = 0,
        [Warnings.SEVERITY.WARNING] = 0,
        [Warnings.SEVERITY.ERROR] = 0,
        total = 0
    }

    for _, warning in ipairs(self.warnings) do
        counts[warning.severity] = (counts[warning.severity] or 0) + 1
        counts.total = counts.total + 1
    end

    return counts
end

--- Clear all warnings
function Warnings:clear()
    self.warnings = {}
end

--- Check for dead ends (passages with no outgoing links)
---@param story table The story object
function Warnings:check_dead_ends(story)
    for name, passage in pairs(story.passages or {}) do
        local has_link = false

        -- Check for choices
        if passage.choices and #passage.choices > 0 then
            has_link = true
        end

        -- Check for divert/goto patterns in content
        if passage.content then
            if passage.content:match("%->%s*%w+") or
               passage.content:match("%[%[.-%]%]") then
                has_link = true
            end
        end

        -- Check for special passages that don't need links
        local special_names = { ["END"] = true, ["RESTART"] = true, ["Done"] = true }
        if special_names[name] or (passage.tags and self:has_tag(passage.tags, "ending")) then
            has_link = true
        end

        if not has_link then
            self:add(
                Warnings.CODES.DEAD_END,
                "Passage '" .. name .. "' has no outgoing links",
                Warnings.SEVERITY.WARNING,
                Warnings.CATEGORIES.STRUCTURE,
                passage.location,
                "Add a choice, link, or 'ending' tag if this is intentional"
            )
        end
    end
end

--- Check for orphan passages (unreachable from start)
---@param story table The story object
function Warnings:check_orphans(story)
    local start = story.start_passage_name or "Start"
    local reachable = {}
    local to_visit = { start }

    -- BFS to find all reachable passages
    while #to_visit > 0 do
        local current = table.remove(to_visit, 1)
        if not reachable[current] then
            reachable[current] = true

            local passage = story.passages[current]
            if passage then
                -- Find links from choices
                for _, choice in ipairs(passage.choices or {}) do
                    if choice.target and not reachable[choice.target] then
                        table.insert(to_visit, choice.target)
                    end
                end

                -- Find links in content
                if passage.content then
                    for target in passage.content:gmatch("%->%s*([%w_]+)") do
                        if not reachable[target] then
                            table.insert(to_visit, target)
                        end
                    end
                end
            end
        end
    end

    -- Check for unreachable passages
    for name, passage in pairs(story.passages or {}) do
        -- Skip system passages and includes
        local skip = { StoryTitle = true, StoryData = true, StoryInit = true }
        if not reachable[name] and not skip[name] then
            self:add(
                Warnings.CODES.ORPHAN_PASSAGE,
                "Passage '" .. name .. "' is not reachable from the start",
                Warnings.SEVERITY.INFO,
                Warnings.CATEGORIES.STRUCTURE,
                passage.location,
                "Add a link to this passage or remove it if unused"
            )
        end
    end
end

--- Check for long passages
---@param story table The story object
function Warnings:check_passage_length(story)
    for name, passage in pairs(story.passages or {}) do
        local content = passage.content or ""
        if #content > self.config.max_passage_length then
            self:add(
                Warnings.CODES.LONG_PASSAGE,
                string.format("Passage '%s' is very long (%d characters)", name, #content),
                Warnings.SEVERITY.HINT,
                Warnings.CATEGORIES.STYLE,
                passage.location,
                "Consider breaking this into smaller passages for readability"
            )
        end
    end
end

--- Check for missing image alt text
---@param story table The story object
function Warnings:check_accessibility(story)
    for name, passage in pairs(story.passages or {}) do
        local content = passage.content or ""

        -- Check markdown images without alt text
        for image in content:gmatch("!%[%]%([^%)]+%)") do
            self:add(
                Warnings.CODES.MISSING_ALT_TEXT,
                "Image missing alt text in passage '" .. name .. "'",
                Warnings.SEVERITY.WARNING,
                Warnings.CATEGORIES.ACCESSIBILITY,
                passage.location,
                "Add descriptive alt text: ![description](image.png)"
            )
        end

        -- Check @image directives without alt
        for directive in content:gmatch("@image%(([^%)]+)%)") do
            if not directive:match("alt%s*[:=]") then
                self:add(
                    Warnings.CODES.MISSING_ALT_TEXT,
                    "Image directive missing alt text in passage '" .. name .. "'",
                    Warnings.SEVERITY.WARNING,
                    Warnings.CATEGORIES.ACCESSIBILITY,
                    passage.location,
                    "Add alt attribute: @image(path, alt: 'description')"
                )
            end
        end
    end
end

--- Check for unused variables
---@param story table The story object
function Warnings:check_unused_variables(story)
    local defined = {}
    local used = {}

    -- Find all defined variables
    for name, _ in pairs(story.variables or {}) do
        defined[name] = true
    end

    -- Find all variable uses in passages
    for _, passage in pairs(story.passages or {}) do
        local content = passage.content or ""

        -- Pattern for variable references: $varName or {varName}
        for var in content:gmatch("%$([%w_]+)") do
            used[var] = true
        end
        for var in content:gmatch("{([%w_]+)}") do
            used[var] = true
        end
    end

    -- Report unused variables
    for var, _ in pairs(defined) do
        if not used[var] then
            self:add(
                Warnings.CODES.UNUSED_VARIABLE,
                "Variable '" .. var .. "' is defined but never used",
                Warnings.SEVERITY.HINT,
                Warnings.CATEGORIES.STYLE,
                nil,
                "Remove the variable definition or use it in your story"
            )
        end
    end
end

--- Run all quality checks on a story
---@param story table The story object
---@return table The warnings manager (for chaining)
function Warnings:check_story(story)
    self:clear()

    self:check_dead_ends(story)
    self:check_orphans(story)
    self:check_passage_length(story)
    self:check_accessibility(story)
    self:check_unused_variables(story)

    return self
end

--- Format warnings as text report
---@param options table|nil Format options
---@return string Formatted report
function Warnings:format_report(options)
    options = options or {}
    local lines = {}

    local counts = self:get_counts()
    table.insert(lines, string.format(
        "Quality Report: %d issues found",
        counts.total
    ))
    table.insert(lines, string.format(
        "  Errors: %d, Warnings: %d, Info: %d, Hints: %d",
        counts[Warnings.SEVERITY.ERROR],
        counts[Warnings.SEVERITY.WARNING],
        counts[Warnings.SEVERITY.INFO],
        counts[Warnings.SEVERITY.HINT]
    ))
    table.insert(lines, "")

    -- Group by category
    local by_cat = self:get_by_category()
    for cat, warnings in pairs(by_cat) do
        table.insert(lines, string.format("[%s] (%d)", cat:upper(), #warnings))

        for _, warning in ipairs(warnings) do
            table.insert(lines, string.format(
                "  %s [%s] %s",
                warning.severity:upper():sub(1, 4),
                warning.code,
                warning.message
            ))

            if warning.suggestion and options.show_suggestions ~= false then
                table.insert(lines, "    -> " .. warning.suggestion)
            end
        end
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

--- Helper to check if a passage has a specific tag
---@param tags table List of tags
---@param tag string Tag to find
---@return boolean
function Warnings:has_tag(tags, tag)
    for _, t in ipairs(tags) do
        if t == tag then
            return true
        end
    end
    return false
end

return Warnings
