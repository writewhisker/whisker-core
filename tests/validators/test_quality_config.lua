-- tests/validators/test_quality_config.lua
-- Tests for quality validator threshold customization

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("Quality Validator Configuration", function()
    local quality

    before_each(function()
        quality = require("whisker.validators.quality")
    end)

    describe("default thresholds", function()
        it("has expected default values", function()
            assert.equals(1.5, quality.THRESHOLDS.min_branching_factor)
            assert.equals(100, quality.THRESHOLDS.max_complexity)
            assert.equals(1000, quality.THRESHOLDS.max_passage_words)
            assert.equals(5, quality.THRESHOLDS.max_nesting_depth)
            assert.equals(50, quality.THRESHOLDS.max_variable_count)
            assert.equals(10, quality.THRESHOLDS.max_choices_per_passage)
        end)
    end)

    describe("validate_branching with custom threshold", function()
        it("respects custom min_branching_factor", function()
            local story = {
                passages = {
                    p1 = { choices = { {}, {} } },  -- 2 choices
                    p2 = { choices = { {} } },       -- 1 choice
                }
            }

            -- Default threshold 1.5, branching = 3/2 = 1.5, no issue
            local issues = quality.validate_branching(story)
            assert.equals(0, #issues)

            -- Custom higher threshold 2.0, branching = 1.5 < 2.0, issue
            issues = quality.validate_branching(story, 2.0)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-001', issues[1].code)
        end)
    end)

    describe("validate_complexity with custom threshold", function()
        it("respects custom max_complexity", function()
            local story = {
                passages = {
                    p1 = { choices = { {}, {} } },
                    p2 = { choices = { {}, {} } },
                },
                variables = {}
            }
            -- 2 passages * 2 avg_choices * (1 + 0/10) = 4

            -- Default threshold 100, no issue
            local issues = quality.validate_complexity(story)
            assert.equals(0, #issues)

            -- Custom lower threshold 3, 4 > 3, issue
            issues = quality.validate_complexity(story, 3)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-002', issues[1].code)
        end)
    end)

    describe("validate_passage_length with custom threshold", function()
        it("respects custom max_passage_words", function()
            local story = {
                passages = {
                    p1 = { content = "one two three four five" }  -- 5 words
                }
            }

            -- Default threshold 1000, no issue
            local issues = quality.validate_passage_length(story)
            assert.equals(0, #issues)

            -- Custom lower threshold 3, 5 > 3, issue
            issues = quality.validate_passage_length(story, 3)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-003', issues[1].code)
        end)
    end)

    describe("validate_nesting with custom threshold", function()
        it("respects custom max_nesting_depth", function()
            local story = {
                passages = {
                    p1 = { content = "{$a {$b nested {/} {/}" }  -- 2 levels
                }
            }

            -- Default threshold 5, no issue
            local issues = quality.validate_nesting(story)
            assert.equals(0, #issues)

            -- Custom lower threshold 1, 2 > 1, issue
            issues = quality.validate_nesting(story, 1)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-004', issues[1].code)
        end)
    end)

    describe("validate_variable_count with custom threshold", function()
        it("respects custom max_variable_count", function()
            local story = {
                variables = {
                    a = { type = 'number' },
                    b = { type = 'number' },
                    c = { type = 'number' }
                }
            }

            -- Default threshold 50, no issue
            local issues = quality.validate_variable_count(story)
            assert.equals(0, #issues)

            -- Custom lower threshold 2, 3 > 2, issue
            issues = quality.validate_variable_count(story, 2)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-005', issues[1].code)
        end)
    end)

    describe("validate_choices_per_passage with custom threshold", function()
        it("respects custom max_choices_per_passage", function()
            local story = {
                passages = {
                    p1 = {
                        title = "Test",
                        choices = { {}, {}, {}, {}, {} }  -- 5 choices
                    }
                }
            }

            -- Default threshold 10, no issue
            local issues = quality.validate_choices_per_passage(story)
            assert.equals(0, #issues)

            -- Custom lower threshold 3, 5 > 3, issue
            issues = quality.validate_choices_per_passage(story, 3)
            assert.equals(1, #issues)
            assert.equals('WLS-QUA-006', issues[1].code)
        end)
    end)

    describe("validate with options", function()
        it("passes all custom thresholds to validators", function()
            local story = {
                passages = {
                    p1 = {
                        content = "word",
                        choices = { {} }
                    }
                },
                variables = { a = {} }
            }

            -- With defaults, might have low_branching issue
            local default_issues = quality.validate(story)

            -- With very permissive thresholds, no issues
            local custom_issues = quality.validate(story, {
                min_branching_factor = 0.5,
                max_complexity = 1000,
                max_passage_words = 10000,
                max_nesting_depth = 100,
                max_variable_count = 1000,
                max_choices_per_passage = 100,
            })
            assert.equals(0, #custom_issues)
        end)
    end)
end)
