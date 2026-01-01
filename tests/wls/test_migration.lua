-- tests/wls/test_migration.lua
-- WLS 1.0 Migration Tool Tests

describe("WLS 1.0 Migration", function()
    local Migrator = require("whisker.migration.migrator")
    local migrator

    before_each(function()
        migrator = Migrator.new()
    end)

    describe("Operator Migration", function()
        it("should convert && to 'and'", function()
            local result = migrator:migrate("if x && y then")
            assert.is_not_nil(result:match(" and "))
            assert.is_nil(result:match("&&"))
        end)

        it("should convert || to 'or'", function()
            local result = migrator:migrate("if x || y then")
            assert.is_not_nil(result:match(" or "))
            assert.is_nil(result:match("||"))
        end)

        it("should convert != to ~=", function()
            local result = migrator:migrate("if x != y then")
            assert.is_not_nil(result:match("~="))
            assert.is_nil(result:match("!="))
        end)

        it("should convert ! to 'not'", function()
            local result = migrator:migrate("if !hasKey then")
            assert.is_not_nil(result:match("not hasKey"))
        end)

        it("should handle multiple operators", function()
            local result = migrator:migrate("if x && y || !z then")
            assert.is_not_nil(result:match(" and "))
            assert.is_not_nil(result:match(" or "))
            assert.is_not_nil(result:match("not z"))
        end)

        it("should track changes", function()
            local result, changes = migrator:migrate("x && y != z")
            assert.is_true(#changes > 0)
            local has_and_change = false
            local has_neq_change = false
            for _, change in ipairs(changes) do
                if change.rule == "and_operator" then has_and_change = true end
                if change.rule == "not_equal_operator" then has_neq_change = true end
            end
            assert.is_true(has_and_change)
            assert.is_true(has_neq_change)
        end)
    end)

    describe("API Colon to Dot Migration", function()
        it("should convert whisker.state:get() to whisker.state.get()", function()
            local result = migrator:migrate('whisker.state:get("gold")')
            assert.equals('whisker.state.get("gold")', result)
        end)

        it("should convert whisker.state:set() to whisker.state.set()", function()
            local result = migrator:migrate('whisker.state:set("gold", 100)')
            assert.equals('whisker.state.set("gold", 100)', result)
        end)

        it("should convert whisker.state:has() to whisker.state.has()", function()
            local result = migrator:migrate('whisker.state:has("key")')
            assert.equals('whisker.state.has("key")', result)
        end)

        it("should convert whisker.state:delete() to whisker.state.delete()", function()
            local result = migrator:migrate('whisker.state:delete("key")')
            assert.equals('whisker.state.delete("key")', result)
        end)

        it("should convert whisker.state:inc() to whisker.state.inc()", function()
            local result = migrator:migrate('whisker.state:inc("counter")')
            assert.equals('whisker.state.inc("counter")', result)
        end)

        it("should convert whisker.state:dec() to whisker.state.dec()", function()
            local result = migrator:migrate('whisker.state:dec("counter")')
            assert.equals('whisker.state.dec("counter")', result)
        end)

        it("should convert whisker.passage:go() to whisker.passage.go()", function()
            local result = migrator:migrate('whisker.passage:go("Target")')
            assert.equals('whisker.passage.go("Target")', result)
        end)

        it("should convert whisker.history:back() to whisker.history.back()", function()
            local result = migrator:migrate('whisker.history:back()')
            assert.equals('whisker.history.back()', result)
        end)
    end)

    describe("Legacy API Migration", function()
        it("should convert whisker.goto() to whisker.passage.go()", function()
            local result = migrator:migrate('whisker.goto("Target")')
            assert.equals('whisker.passage.go("Target")', result)
        end)

        it("should convert whisker.current_passage to whisker.passage.current()", function()
            local result = migrator:migrate('local p = whisker.current_passage;')
            assert.is_not_nil(result:match("whisker%.passage%.current%(%)"))
        end)
    end)

    describe("Expression Interpolation Migration", function()
        it("should convert {{expr}} to ${expr}", function()
            local result = migrator:migrate_interpolation("You have {{gold}} coins.")
            assert.equals("You have ${gold} coins.", result)
        end)

        it("should handle complex expressions", function()
            local result = migrator:migrate_interpolation("Total: {{gold * 2 + bonus}}")
            assert.equals("Total: ${gold * 2 + bonus}", result)
        end)

        it("should not convert template control keywords", function()
            local result = migrator:migrate_interpolation("{{#if x}}...{{else}}...{{/if}}")
            -- Template keywords should remain unchanged
            assert.equals("{{#if x}}...{{else}}...{{/if}}", result)
        end)

        it("should handle multiple interpolations", function()
            local result = migrator:migrate_interpolation("{{a}} and {{b}} and {{c}}")
            assert.equals("${a} and ${b} and ${c}", result)
        end)
    end)

    describe("Story Migration", function()
        it("should apply all migrations to story content", function()
            local content = [[
:: Start
@onEnter: whisker.state:set("visited", true)

{ gold > 10 && hasKey }
  You can proceed.
{/}

{{ playerName }}, you have {{gold}} coins.

+ { gold != 0 } [Buy item] -> Shop
]]
            local result = migrator:migrate_story(content)

            -- Check operator migration
            assert.is_not_nil(result:match(" and "))
            assert.is_nil(result:match("&&"))

            -- Check API migration
            assert.is_not_nil(result:match("whisker%.state%.set"))

            -- Check interpolation migration
            assert.is_not_nil(result:match("%${playerName}"))
            assert.is_not_nil(result:match("%${gold}"))
        end)

        it("should return all changes", function()
            local content = "x && y || z"
            local result, changes = migrator:migrate_story(content)
            assert.is_true(#changes >= 2)
        end)
    end)

    describe("Validation", function()
        it("should detect C-style && operator", function()
            local result = migrator:validate("if x && y then")
            assert.is_false(result.valid)
            assert.equals(1, #result.issues)
            assert.equals("operator", result.issues[1].type)
        end)

        it("should detect C-style || operator", function()
            local result = migrator:validate("if x || y then")
            assert.is_false(result.valid)
        end)

        it("should detect C-style != operator", function()
            local result = migrator:validate("if x != y then")
            assert.is_false(result.valid)
        end)

        it("should detect colon notation", function()
            local result = migrator:validate('whisker.state:get("key")')
            assert.is_false(result.valid)
            assert.equals("api", result.issues[1].type)
        end)

        it("should detect legacy whisker.goto()", function()
            local result = migrator:validate('whisker.goto("Target")')
            assert.is_false(result.valid)
        end)

        it("should detect legacy whisker.current_passage", function()
            local result = migrator:validate('local p = whisker.current_passage;')
            assert.is_false(result.valid)
        end)

        it("should pass valid WLS 1.0 content", function()
            local content = [[
{ gold > 10 and hasKey }
  whisker.state.set("bought", true)
{/}

$playerName has ${gold} coins.
]]
            local result = migrator:validate(content)
            assert.is_true(result.valid)
            assert.equals(0, #result.issues)
        end)
    end)

    describe("Report Generation", function()
        it("should generate accurate report", function()
            local content = "x && y && z || a"
            local _, changes = migrator:migrate_story(content)
            local report = migrator:get_report(changes)

            assert.is_not_nil(report.total_changes)
            assert.is_true(report.total_changes > 0)
            assert.is_not_nil(report.by_rule.and_operator)
            assert.is_not_nil(report.by_rule.or_operator)
        end)
    end)

    describe("Skip Rules Option", function()
        it("should skip specified rules", function()
            local content = "x && y"
            local result = migrator:migrate(content, {
                skip_rules = { and_operator = true }
            })
            assert.is_not_nil(result:match("&&"))
        end)
    end)

    describe("Static Methods", function()
        it("should provide quick_migrate", function()
            local result = Migrator.quick_migrate("x && y")
            assert.is_not_nil(result:match(" and "))
        end)

        it("should provide quick_validate", function()
            local result = Migrator.quick_validate("x && y")
            assert.is_false(result.valid)
        end)
    end)
end)
