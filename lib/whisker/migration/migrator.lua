-- lib/whisker/migration/migrator.lua
-- WLS 1.0 Migration Tool
-- Converts legacy whisker syntax to WLS 1.0 format

local Migrator = {}
Migrator.__index = Migrator
Migrator._dependencies = {}

-- Migration rules with descriptions
Migrator.RULES = {
    -- Operator migrations (C-style to Lua-style)
    {
        name = "and_operator",
        pattern = "&&",
        replacement = " and ",
        description = "Convert && to 'and'"
    },
    {
        name = "or_operator",
        pattern = "||",
        replacement = " or ",
        description = "Convert || to 'or'"
    },
    {
        name = "not_operator",
        pattern = "!([%a_])",
        replacement = "not %1",
        description = "Convert ! to 'not'"
    },
    {
        name = "not_equal_operator",
        pattern = "!=",
        replacement = "~=",
        description = "Convert != to ~="
    },
    -- API migrations (colon to dot notation)
    {
        name = "state_get_colon",
        pattern = "whisker%.state:get%(",
        replacement = "whisker.state.get(",
        description = "Convert whisker.state:get() to whisker.state.get()"
    },
    {
        name = "state_set_colon",
        pattern = "whisker%.state:set%(",
        replacement = "whisker.state.set(",
        description = "Convert whisker.state:set() to whisker.state.set()"
    },
    {
        name = "state_has_colon",
        pattern = "whisker%.state:has%(",
        replacement = "whisker.state.has(",
        description = "Convert whisker.state:has() to whisker.state.has()"
    },
    {
        name = "state_delete_colon",
        pattern = "whisker%.state:delete%(",
        replacement = "whisker.state.delete(",
        description = "Convert whisker.state:delete() to whisker.state.delete()"
    },
    {
        name = "state_inc_colon",
        pattern = "whisker%.state:inc%(",
        replacement = "whisker.state.inc(",
        description = "Convert whisker.state:inc() to whisker.state.inc()"
    },
    {
        name = "state_dec_colon",
        pattern = "whisker%.state:dec%(",
        replacement = "whisker.state.dec(",
        description = "Convert whisker.state:dec() to whisker.state.dec()"
    },
    {
        name = "passage_go_colon",
        pattern = "whisker%.passage:go%(",
        replacement = "whisker.passage.go(",
        description = "Convert whisker.passage:go() to whisker.passage.go()"
    },
    {
        name = "history_back_colon",
        pattern = "whisker%.history:back%(",
        replacement = "whisker.history.back(",
        description = "Convert whisker.history:back() to whisker.history.back()"
    },
    -- Legacy goto migration
    {
        name = "whisker_goto",
        pattern = "whisker%.goto%(",
        replacement = "whisker.passage.go(",
        description = "Convert whisker.goto() to whisker.passage.go()"
    },
    -- Legacy current_passage property
    {
        name = "current_passage_property",
        pattern = "whisker%.current_passage([^%w_])",
        replacement = "whisker.passage.current()%1",
        description = "Convert whisker.current_passage to whisker.passage.current()"
    }
}

function Migrator.new(deps)
    deps = deps or {}
    local instance = {
        changes = {},
        rules_applied = {}
    }
    setmetatable(instance, Migrator)
    return instance
end

-- Migrate a single piece of content
function Migrator:migrate(content, options)
    options = options or {}
    self.changes = {}
    self.rules_applied = {}

    local result = content
    local rules_to_apply = options.rules or Migrator.RULES

    for _, rule in ipairs(rules_to_apply) do
        if not options.skip_rules or not options.skip_rules[rule.name] then
            local new_result, count = result:gsub(rule.pattern, rule.replacement)
            if count > 0 then
                table.insert(self.changes, {
                    rule = rule.name,
                    description = rule.description,
                    count = count
                })
                self.rules_applied[rule.name] = count
            end
            result = new_result
        end
    end

    return result, self.changes
end

-- Migrate expression interpolation ({{expr}} to ${expr})
function Migrator:migrate_interpolation(content)
    local changes = {}
    local result = content

    -- Convert {{expr}} to ${expr}
    -- Be careful not to convert template control keywords
    -- Pattern: {{ followed by optional whitespace, then content, then }}
    result = result:gsub("{{%s*([^#/}][^}]-)%s*}}", function(expr)
        -- Skip template keywords
        if expr:match("^%s*else%s*$") or
           expr:match("^%s*each%s") or
           expr:match("^%s*end%s*$") then
            return "{{" .. expr .. "}}"
        end

        table.insert(changes, {
            rule = "expression_interpolation",
            description = "Convert {{" .. expr:sub(1, 20) .. "...}} to ${...}",
            count = 1
        })
        return "${" .. expr .. "}"
    end)

    return result, changes
end

-- Migrate a complete story file (combines all migrations)
function Migrator:migrate_story(content, options)
    options = options or {}
    local all_changes = {}

    -- Apply operator and API migrations
    local result, changes = self:migrate(content, options)
    for _, change in ipairs(changes) do
        table.insert(all_changes, change)
    end

    -- Apply interpolation migration if enabled
    if options.migrate_interpolation ~= false then
        result, changes = self:migrate_interpolation(result)
        for _, change in ipairs(changes) do
            table.insert(all_changes, change)
        end
    end

    return result, all_changes
end

-- Get migration report
function Migrator:get_report(changes)
    local report = {
        total_changes = 0,
        by_rule = {}
    }

    for _, change in ipairs(changes) do
        report.total_changes = report.total_changes + change.count
        report.by_rule[change.rule] = (report.by_rule[change.rule] or 0) + change.count
    end

    return report
end

-- Validate that content doesn't have legacy syntax
function Migrator:validate(content)
    local issues = {}

    -- Check for C-style operators
    if content:match("&&") then
        table.insert(issues, {
            type = "operator",
            message = "Found C-style && operator, use 'and' instead",
            severity = "error"
        })
    end

    if content:match("||") then
        table.insert(issues, {
            type = "operator",
            message = "Found C-style || operator, use 'or' instead",
            severity = "error"
        })
    end

    -- Check for != (but not in strings)
    if content:match("[^=!<>]!=[^=]") or content:match("^!=[^=]") then
        table.insert(issues, {
            type = "operator",
            message = "Found C-style != operator, use '~=' instead",
            severity = "error"
        })
    end

    -- Check for colon notation
    if content:match("whisker%.[%w_]+:[%w_]+%(") then
        table.insert(issues, {
            type = "api",
            message = "Found colon notation (e.g., whisker.state:get()), use dot notation instead",
            severity = "warning"
        })
    end

    -- Check for legacy goto
    if content:match("whisker%.goto%(") then
        table.insert(issues, {
            type = "api",
            message = "Found whisker.goto(), use whisker.passage.go() instead",
            severity = "warning"
        })
    end

    -- Check for legacy current_passage
    if content:match("whisker%.current_passage[^%w_]") then
        table.insert(issues, {
            type = "api",
            message = "Found whisker.current_passage, use whisker.passage.current() instead",
            severity = "warning"
        })
    end

    return {
        valid = #issues == 0,
        issues = issues
    }
end

-- Migrate a file (reads, migrates, optionally writes)
function Migrator:migrate_file(input_path, output_path, options)
    options = options or {}

    -- Read input file
    local file, err = io.open(input_path, "r")
    if not file then
        return nil, "Could not open input file: " .. (err or "unknown error")
    end

    local content = file:read("*a")
    file:close()

    -- Migrate content
    local result, changes = self:migrate_story(content, options)

    -- Get report
    local report = self:get_report(changes)

    -- Write output if path provided
    if output_path then
        local out_file, write_err = io.open(output_path, "w")
        if not out_file then
            return nil, "Could not open output file: " .. (write_err or "unknown error")
        end
        out_file:write(result)
        out_file:close()
    end

    return {
        success = true,
        content = result,
        changes = changes,
        report = report
    }
end

-- Static method: quick migrate
function Migrator.quick_migrate(content, options)
    local migrator = Migrator.new()
    return migrator:migrate_story(content, options)
end

-- Static method: quick validate
function Migrator.quick_validate(content)
    local migrator = Migrator.new()
    return migrator:validate(content)
end

return Migrator
