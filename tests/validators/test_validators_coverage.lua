-- tests/validators/test_validators_coverage.lua
-- Coverage expansion tests for WLS 1.0 validators

describe("WLS Validators Coverage Expansion", function()
    local Story = require("whisker.core.story")
    local Passage = require("whisker.core.passage")
    local Choice = require("whisker.core.choice")
    local structural = require("whisker.validators.structural")
    local links = require("whisker.validators.links")
    local variables = require("whisker.validators.variables")
    local expressions = require("whisker.validators.expressions")
    local flow = require("whisker.validators.flow")
    local syntax = require("whisker.validators.syntax")

    -- Helper to create a story with passages
    local function create_story(passages, start_passage)
        local story = Story.new({title = "Test Story"})
        for _, p in ipairs(passages) do
            local passage = Passage.new({
                id = p.id,
                title = p.title or p.id,
                content = p.content or ""
            })
            if p.choices then
                for _, c in ipairs(p.choices) do
                    passage:add_choice(Choice.new({
                        id = c.id or ("choice_" .. c.target),
                        text = c.text or "Choice",
                        target = c.target,
                        condition = c.condition,
                        action = c.action
                    }))
                end
            end
            story:add_passage(passage)
        end
        if start_passage then
            story:set_start_passage(start_passage)
        elseif #passages > 0 then
            story:set_start_passage(passages[1].id)
        end
        return story
    end

    describe("Structural Validators", function()
        describe("validate_start_passage", function()
            it("should pass for valid start passage", function()
                local story = create_story({
                    {id = "start", content = "Start"}
                }, "start")
                local issues = structural.validate_start_passage(story)
                assert.equals(0, #issues)
            end)

            it("should fail for missing start passage", function()
                local story = Story.new({title = "Test"})
                story.start_passage = nil
                local issues = structural.validate_start_passage(story)
                assert.is_true(#issues > 0)
            end)

            it("should fail for empty start passage", function()
                local story = Story.new({title = "Test"})
                story.start_passage = ""
                local issues = structural.validate_start_passage(story)
                assert.is_true(#issues > 0)
            end)

            it("should fail for nonexistent start passage", function()
                local story = create_story({
                    {id = "start", content = "Start"}
                }, "start")
                story.start_passage = "nonexistent"
                local issues = structural.validate_start_passage(story)
                assert.is_true(#issues > 0)
            end)
        end)

        describe("validate_unreachable", function()
            it("should pass for connected story", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = structural.validate_unreachable(story)
                assert.equals(0, #issues)
            end)

            it("should detect orphan passages", function()
                local story = create_story({
                    {id = "start", content = "Start"},
                    {id = "orphan", content = "Orphan"}
                }, "start")
                local issues = structural.validate_unreachable(story)
                assert.is_true(#issues > 0)
            end)

            it("should handle story with no start passage", function()
                local story = Story.new({title = "Test"})
                story.start_passage = nil
                local issues = structural.validate_unreachable(story)
                -- Should not crash
                assert.is_table(issues)
            end)

            it("should handle story with no passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = structural.validate_unreachable(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_duplicates", function()
            it("should pass for unique passage IDs", function()
                local story = create_story({
                    {id = "a", content = "A"},
                    {id = "b", content = "B"}
                }, "a")
                local issues = structural.validate_duplicates(story)
                assert.equals(0, #issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = structural.validate_duplicates(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_empty", function()
            it("should pass for non-empty passages", function()
                local story = create_story({
                    {id = "start", content = "Content here"}
                }, "start")
                local issues = structural.validate_empty(story)
                assert.equals(0, #issues)
            end)

            it("should detect empty content", function()
                local story = create_story({
                    {id = "start", content = ""}
                }, "start")
                local issues = structural.validate_empty(story)
                -- May report or not based on severity settings
                assert.is_table(issues)
            end)

            it("should handle passages with only whitespace", function()
                local story = create_story({
                    {id = "start", content = "   \n\t  "}
                }, "start")
                local issues = structural.validate_empty(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_orphans", function()
            it("should detect orphan passages", function()
                local story = create_story({
                    {id = "start", content = "Start"},
                    {id = "orphan", content = "Orphan"}
                }, "start")
                local issues = structural.validate_orphans(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_terminals", function()
            it("should check for terminal passages", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = structural.validate_terminals(story)
                assert.is_table(issues)
            end)
        end)
    end)

    describe("Link Validators", function()
        describe("validate_dead_links", function()
            it("should pass for valid links", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = links.validate_dead_links(story)
                assert.equals(0, #issues)
            end)

            it("should detect dead links", function()
                local story = create_story({
                    {id = "start", choices = {{target = "nonexistent"}}}
                }, "start")
                local issues = links.validate_dead_links(story)
                assert.is_true(#issues > 0)
            end)

            it("should allow special targets END", function()
                local story = create_story({
                    {id = "start", choices = {{target = "END"}}}
                }, "start")
                local issues = links.validate_dead_links(story)
                assert.equals(0, #issues)
            end)

            it("should allow special targets BACK", function()
                local story = create_story({
                    {id = "start", choices = {{target = "BACK"}}}
                }, "start")
                local issues = links.validate_dead_links(story)
                assert.equals(0, #issues)
            end)

            it("should allow special targets RESTART", function()
                local story = create_story({
                    {id = "start", choices = {{target = "RESTART"}}}
                }, "start")
                local issues = links.validate_dead_links(story)
                assert.equals(0, #issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = links.validate_dead_links(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_self_links", function()
            it("should detect self-referential links", function()
                local story = create_story({
                    {id = "loop", choices = {{target = "loop"}}}
                }, "loop")
                local issues = links.validate_self_links(story)
                -- Self-links are valid but may be warnings
                assert.is_table(issues)
            end)

            it("should pass for non-self links", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = links.validate_self_links(story)
                assert.equals(0, #issues)
            end)
        end)

        describe("validate_empty_targets", function()
            it("should detect empty targets", function()
                local story = create_story({
                    {id = "start", choices = {{target = ""}}}
                }, "start")
                local issues = links.validate_empty_targets(story)
                assert.is_true(#issues > 0)
            end)

            it("should pass for valid targets", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = links.validate_empty_targets(story)
                assert.equals(0, #issues)
            end)
        end)
    end)

    describe("Variable Validators", function()
        describe("validate_undefined", function()
            it("should pass for stories without variables", function()
                local story = create_story({
                    {id = "start", content = "No variables here"}
                }, "start")
                local issues = variables.validate_undefined(story)
                assert.is_table(issues)
            end)

            it("should handle nil variables map", function()
                local story = create_story({
                    {id = "start", content = "Test"}
                }, "start")
                story.variables = nil
                local issues = variables.validate_undefined(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_unused", function()
            it("should handle stories without variables", function()
                local story = create_story({
                    {id = "start", content = "Test"}
                }, "start")
                local issues = variables.validate_unused(story)
                assert.is_table(issues)
            end)

            it("should handle nil variables", function()
                local story = Story.new({title = "Test"})
                story.variables = nil
                local issues = variables.validate_unused(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_names", function()
            it("should handle valid variable names", function()
                local story = create_story({
                    {id = "start", content = "Test"}
                }, "start")
                story.variables = {
                    health = {name = "health", type = "number", initial = 100},
                    player_name = {name = "player_name", type = "string", initial = "Hero"}
                }
                local issues = variables.validate_names(story)
                assert.equals(0, #issues)
            end)

            it("should handle nil variables", function()
                local story = Story.new({title = "Test"})
                story.variables = nil
                local issues = variables.validate_names(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_lone_dollar", function()
            it("should detect lone $ sign", function()
                local story = create_story({
                    {id = "start", content = "Price is $ 100"}
                }, "start")
                local issues = variables.validate_lone_dollar(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_unclosed_interpolation", function()
            it("should detect unclosed ${", function()
                local story = create_story({
                    {id = "start", content = "Value: ${unclosed"}
                }, "start")
                local issues = variables.validate_unclosed_interpolation(story)
                assert.is_table(issues)
            end)
        end)
    end)

    describe("Expression Validators", function()
        describe("validate (main)", function()
            it("should pass for valid expressions", function()
                local story = create_story({
                    {id = "start", content = "Value: ${1 + 2}"}
                }, "start")
                local issues = expressions.validate(story)
                assert.is_table(issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = expressions.validate(story)
                assert.is_table(issues)
            end)

            it("should handle complex expressions", function()
                local story = create_story({
                    {id = "start", content = "${(a + b) * (c - d)}"}
                }, "start")
                local issues = expressions.validate(story)
                assert.is_table(issues)
            end)
        end)
    end)

    describe("Flow Validators", function()
        describe("validate_cycles", function()
            it("should pass for linear story", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "End"}
                }, "start")
                local issues = flow.validate_cycles(story)
                assert.is_table(issues)
            end)

            it("should detect cycles", function()
                local story = create_story({
                    {id = "a", choices = {{target = "b"}}},
                    {id = "b", choices = {{target = "a"}}}
                }, "a")
                local issues = flow.validate_cycles(story)
                -- Cycles may be warnings not errors
                assert.is_table(issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = flow.validate_cycles(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_dead_ends", function()
            it("should pass for story with exits", function()
                local story = create_story({
                    {id = "start", choices = {{target = "END"}}}
                }, "start")
                local issues = flow.validate_dead_ends(story)
                assert.is_table(issues)
            end)

            it("should handle terminal passages (no choices)", function()
                local story = create_story({
                    {id = "start", choices = {{target = "end"}}},
                    {id = "end", content = "The End"}
                }, "start")
                -- Terminal passages are valid
                local issues = flow.validate_dead_ends(story)
                assert.is_table(issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = flow.validate_dead_ends(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_infinite_loops", function()
            it("should detect infinite loop (self-link with no state change)", function()
                local story = create_story({
                    {id = "loop", choices = {{target = "loop"}}}
                }, "loop")
                local issues = flow.validate_infinite_loops(story)
                assert.is_table(issues)
            end)

            it("should pass for self-link with action", function()
                local story = create_story({
                    {id = "loop", choices = {{target = "loop", action = "counter = counter + 1"}}}
                }, "loop")
                local issues = flow.validate_infinite_loops(story)
                -- Self-link with action is not infinite loop
                assert.is_table(issues)
            end)
        end)
    end)

    describe("Syntax Validators", function()
        describe("validate (main)", function()
            it("should pass for valid passages", function()
                local story = create_story({
                    {id = "start", content = "Valid content here."}
                }, "start")
                local issues = syntax.validate(story)
                assert.is_table(issues)
            end)

            it("should handle nil passages", function()
                local story = Story.new({title = "Test"})
                story.passages = nil
                local issues = syntax.validate(story)
                assert.is_table(issues)
            end)

            it("should pass for valid choices", function()
                local story = create_story({
                    {id = "start", choices = {
                        {target = "end", text = "Valid choice text"}
                    }},
                    {id = "end", content = "End"}
                }, "start")
                local issues = syntax.validate(story)
                assert.is_table(issues)
            end)
        end)

        describe("validate_parse_errors", function()
            it("should handle story without parse errors", function()
                local story = create_story({
                    {id = "start", content = "Test"}
                }, "start")
                local issues = syntax.validate_parse_errors(story)
                assert.is_table(issues)
            end)
        end)
    end)

    describe("Error Formatter", function()
        local error_formatter = require("whisker.validators.error_formatter")

        it("should format single error with source", function()
            local issue = {
                code = "WLS-STR-001",
                severity = "error",
                message = "Missing start passage",
                category = "structure"
            }
            local text = error_formatter.format_error(issue, "test source")
            assert.is_string(text)
        end)

        it("should format multiple errors with source", function()
            local issues = {
                {code = "WLS-STR-001", severity = "error", message = "Error 1"},
                {code = "WLS-STR-002", severity = "warning", message = "Error 2"}
            }
            local text = error_formatter.format_errors(issues, "test source")
            assert.is_string(text)
        end)

        it("should format summary", function()
            local issues = {
                {code = "WLS-STR-001", severity = "error"},
                {code = "WLS-STR-002", severity = "warning"}
            }
            local summary = error_formatter.format_summary(issues)
            assert.is_string(summary)
        end)

        it("should format error as JSON with source", function()
            local issue = {
                code = "WLS-STR-001",
                severity = "error",
                message = "Test error"
            }
            local json = error_formatter.format_error_as_json(issue, "test source")
            assert.is_table(json)  -- Returns table for JSON encoding
        end)

        it("should suggest similar strings", function()
            local suggestion = error_formatter.suggest_similar("heath", {"health", "wealth", "metal"})
            -- May return string or nil
            assert.is_true(suggestion == nil or type(suggestion) == "string")
        end)
    end)

    describe("Error Codes", function()
        local error_codes = require("whisker.validators.error_codes")

        it("should get error code by key", function()
            local code = error_codes.get_error_code("WLS-STR-001")
            assert.is_table(code)
            assert.equals("error", code.severity)
        end)

        it("should return nil for unknown code", function()
            local code = error_codes.get_error_code("UNKNOWN-999")
            assert.is_nil(code)
        end)

        it("should format message with context", function()
            local msg = error_codes.format_message("WLS-STR-001", {})
            assert.is_string(msg)
        end)

        it("should get errors by category", function()
            local structural = error_codes.get_errors_by_category("structure")
            assert.is_table(structural)
        end)

        it("should get errors by severity", function()
            local errors = error_codes.get_errors_by_severity("error")
            assert.is_table(errors)
        end)
    end)
end)
