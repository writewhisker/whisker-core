-- tests/validation/gap050_quality_warnings_spec.lua
-- Tests for GAP-050: Quality Warnings

describe("GAP-050: Quality Warnings", function()
    local Warnings

    setup(function()
        Warnings = require("whisker.validation.warnings")
    end)

    describe("Warnings module", function()
        it("creates new instance", function()
            local warnings = Warnings.new()
            assert.is_not_nil(warnings)
        end)

        it("accepts configuration", function()
            local warnings = Warnings.new({
                max_passage_length = 1000,
                max_nesting_depth = 3
            })

            assert.are.equal(1000, warnings.config.max_passage_length)
            assert.are.equal(3, warnings.config.max_nesting_depth)
        end)
    end)

    describe("adding warnings", function()
        local warnings

        before_each(function()
            warnings = Warnings.new()
        end)

        it("adds a warning", function()
            warnings:add(
                Warnings.CODES.DEAD_END,
                "Test message",
                Warnings.SEVERITY.WARNING,
                Warnings.CATEGORIES.STRUCTURE
            )

            local all = warnings:get_all()
            assert.are.equal(1, #all)
            assert.are.equal(Warnings.CODES.DEAD_END, all[1].code)
        end)

        it("includes all warning fields", function()
            warnings:add(
                Warnings.CODES.LONG_PASSAGE,
                "Test message",
                Warnings.SEVERITY.HINT,
                Warnings.CATEGORIES.STYLE,
                { line = 10, file = "test.wls" },
                "Consider breaking it up"
            )

            local w = warnings:get_all()[1]

            assert.are.equal(Warnings.CODES.LONG_PASSAGE, w.code)
            assert.are.equal("Test message", w.message)
            assert.are.equal(Warnings.SEVERITY.HINT, w.severity)
            assert.are.equal(Warnings.CATEGORIES.STYLE, w.category)
            assert.are.equal(10, w.location.line)
            assert.are.equal("Consider breaking it up", w.suggestion)
            assert.is_number(w.timestamp)
        end)

        it("respects minimum severity", function()
            warnings = Warnings.new({
                min_severity = Warnings.SEVERITY.WARNING
            })

            warnings:add("CODE", "msg", Warnings.SEVERITY.HINT, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE", "msg", Warnings.SEVERITY.INFO, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE", "msg", Warnings.SEVERITY.ERROR, Warnings.CATEGORIES.STYLE)

            assert.are.equal(2, #warnings:get_all())
        end)

        it("respects enabled categories", function()
            warnings = Warnings.new({
                enabled_categories = { Warnings.CATEGORIES.STRUCTURE }
            })

            warnings:add("CODE", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STRUCTURE)
            warnings:add("CODE", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STYLE)

            assert.are.equal(1, #warnings:get_all())
        end)
    end)

    describe("filtering warnings", function()
        local warnings

        before_each(function()
            warnings = Warnings.new()
            warnings:add("CODE1", "msg1", Warnings.SEVERITY.HINT, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE2", "msg2", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STRUCTURE)
            warnings:add("CODE3", "msg3", Warnings.SEVERITY.ERROR, Warnings.CATEGORIES.STRUCTURE)
        end)

        it("filters by severity", function()
            local result = warnings:get_all({ severity = Warnings.SEVERITY.WARNING })
            assert.are.equal(1, #result)
            assert.are.equal("CODE2", result[1].code)
        end)

        it("filters by category", function()
            local result = warnings:get_all({ category = Warnings.CATEGORIES.STRUCTURE })
            assert.are.equal(2, #result)
        end)

        it("filters by code", function()
            local result = warnings:get_all({ code = "CODE1" })
            assert.are.equal(1, #result)
        end)
    end)

    describe("grouping and counting", function()
        local warnings

        before_each(function()
            warnings = Warnings.new()
            warnings:add("CODE1", "msg", Warnings.SEVERITY.HINT, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE2", "msg", Warnings.SEVERITY.INFO, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE3", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STRUCTURE)
            warnings:add("CODE4", "msg", Warnings.SEVERITY.ERROR, Warnings.CATEGORIES.ACCESSIBILITY)
        end)

        it("groups by category", function()
            local grouped = warnings:get_by_category()

            assert.are.equal(2, #grouped[Warnings.CATEGORIES.STYLE])
            assert.are.equal(1, #grouped[Warnings.CATEGORIES.STRUCTURE])
            assert.are.equal(1, #grouped[Warnings.CATEGORIES.ACCESSIBILITY])
        end)

        it("counts by severity", function()
            local counts = warnings:get_counts()

            assert.are.equal(1, counts[Warnings.SEVERITY.HINT])
            assert.are.equal(1, counts[Warnings.SEVERITY.INFO])
            assert.are.equal(1, counts[Warnings.SEVERITY.WARNING])
            assert.are.equal(1, counts[Warnings.SEVERITY.ERROR])
            assert.are.equal(4, counts.total)
        end)
    end)

    describe("story checks", function()
        local warnings

        before_each(function()
            warnings = Warnings.new()
        end)

        describe("check_dead_ends", function()
            it("detects passage without links", function()
                local story = {
                    passages = {
                        DeadEnd = {
                            name = "DeadEnd",
                            content = "No links here",
                            choices = {}
                        }
                    }
                }

                warnings:check_dead_ends(story)

                local all = warnings:get_all()
                assert.are.equal(1, #all)
                assert.are.equal(Warnings.CODES.DEAD_END, all[1].code)
            end)

            it("does not flag passages with choices", function()
                local story = {
                    passages = {
                        HasChoice = {
                            name = "HasChoice",
                            content = "Text",
                            choices = { { text = "Go", target = "Next" } }
                        }
                    }
                }

                warnings:check_dead_ends(story)

                assert.are.equal(0, #warnings:get_all())
            end)

            it("does not flag passages with ending tag", function()
                local story = {
                    passages = {
                        Ending = {
                            name = "Ending",
                            content = "The end",
                            choices = {},
                            tags = { "ending" }
                        }
                    }
                }

                warnings:check_dead_ends(story)

                assert.are.equal(0, #warnings:get_all())
            end)

            it("does not flag passages with divert links", function()
                local story = {
                    passages = {
                        HasDivert = {
                            name = "HasDivert",
                            content = "Text -> Next",
                            choices = {}
                        }
                    }
                }

                warnings:check_dead_ends(story)

                assert.are.equal(0, #warnings:get_all())
            end)
        end)

        describe("check_passage_length", function()
            it("warns for long passages", function()
                local long_content = string.rep("x", 6000)
                local story = {
                    passages = {
                        Long = {
                            name = "Long",
                            content = long_content
                        }
                    }
                }

                warnings:check_passage_length(story)

                local all = warnings:get_all()
                assert.are.equal(1, #all)
                assert.are.equal(Warnings.CODES.LONG_PASSAGE, all[1].code)
            end)

            it("does not warn for normal passages", function()
                local story = {
                    passages = {
                        Normal = {
                            name = "Normal",
                            content = "Short content"
                        }
                    }
                }

                warnings:check_passage_length(story)

                assert.are.equal(0, #warnings:get_all())
            end)
        end)

        describe("check_accessibility", function()
            it("warns for missing alt text in markdown images", function()
                local story = {
                    passages = {
                        Image = {
                            name = "Image",
                            content = "![](image.png)"
                        }
                    }
                }

                warnings:check_accessibility(story)

                local all = warnings:get_all()
                assert.are.equal(1, #all)
                assert.are.equal(Warnings.CODES.MISSING_ALT_TEXT, all[1].code)
            end)

            it("warns for missing alt in @image directive", function()
                local story = {
                    passages = {
                        Image = {
                            name = "Image",
                            content = "@image(photo.jpg)"
                        }
                    }
                }

                warnings:check_accessibility(story)

                local all = warnings:get_all()
                assert.are.equal(1, #all)
            end)

            it("does not warn when alt text is present", function()
                local story = {
                    passages = {
                        Image = {
                            name = "Image",
                            content = "![Description](image.png)"
                        }
                    }
                }

                warnings:check_accessibility(story)

                -- Should not have missing alt text warning for this one
                local found_alt_warning = false
                for _, w in ipairs(warnings:get_all()) do
                    if w.code == Warnings.CODES.MISSING_ALT_TEXT and
                       w.message:match("missing alt text") then
                        found_alt_warning = true
                    end
                end
                assert.is_false(found_alt_warning)
            end)
        end)

        describe("check_unused_variables", function()
            it("warns for unused variables", function()
                local story = {
                    variables = {
                        unused = { value = 0, name = "unused" }
                    },
                    passages = {
                        Start = {
                            content = "No variable use"
                        }
                    }
                }

                warnings:check_unused_variables(story)

                local all = warnings:get_all()
                assert.are.equal(1, #all)
                assert.are.equal(Warnings.CODES.UNUSED_VARIABLE, all[1].code)
            end)

            it("does not warn for used variables", function()
                local story = {
                    variables = {
                        used = { value = 0, name = "used" }
                    },
                    passages = {
                        Start = {
                            content = "Value is $used"
                        }
                    }
                }

                warnings:check_unused_variables(story)

                assert.are.equal(0, #warnings:get_all())
            end)
        end)
    end)

    describe("format_report", function()
        it("generates readable report", function()
            local warnings = Warnings.new()
            warnings:add(
                Warnings.CODES.DEAD_END,
                "Test dead end",
                Warnings.SEVERITY.WARNING,
                Warnings.CATEGORIES.STRUCTURE,
                nil,
                "Add a link"
            )

            local report = warnings:format_report()

            assert.is_string(report)
            assert.matches("Quality Report", report)
            assert.matches("STRUCTURE", report)
            assert.matches("WLS%-WARN%-001", report)  -- Error code format
        end)
    end)

    describe("clear", function()
        it("clears all warnings", function()
            local warnings = Warnings.new()
            warnings:add("CODE", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STYLE)
            warnings:add("CODE", "msg", Warnings.SEVERITY.WARNING, Warnings.CATEGORIES.STYLE)

            warnings:clear()

            assert.are.equal(0, #warnings:get_all())
        end)
    end)
end)
