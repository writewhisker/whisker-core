-- tests/validation/gap052_developer_errors_spec.lua
-- Tests for GAP-052: Developer Errors

describe("GAP-052: Developer Errors", function()
    local DeveloperErrors

    setup(function()
        DeveloperErrors = require("whisker.validation.developer_errors")
    end)

    describe("DeveloperErrors module", function()
        it("creates new instance", function()
            local errors = DeveloperErrors.new()
            assert.is_not_nil(errors)
        end)

        it("accepts configuration", function()
            local errors = DeveloperErrors.new({
                show_stack_traces = false,
                collect_mode = true,
                max_errors = 50
            })

            assert.is_false(errors.config.show_stack_traces)
            assert.is_true(errors.config.collect_mode)
            assert.are.equal(50, errors.config.max_errors)
        end)
    end)

    describe("severity levels", function()
        it("has all severity levels", function()
            assert.are.equal("debug", DeveloperErrors.SEVERITY.DEBUG)
            assert.are.equal("info", DeveloperErrors.SEVERITY.INFO)
            assert.are.equal("warning", DeveloperErrors.SEVERITY.WARNING)
            assert.are.equal("error", DeveloperErrors.SEVERITY.ERROR)
            assert.are.equal("fatal", DeveloperErrors.SEVERITY.FATAL)
        end)
    end)

    describe("error categories", function()
        it("has all categories", function()
            assert.are.equal("syntax", DeveloperErrors.CATEGORIES.SYNTAX)
            assert.are.equal("semantic", DeveloperErrors.CATEGORIES.SEMANTIC)
            assert.are.equal("runtime", DeveloperErrors.CATEGORIES.RUNTIME)
            assert.are.equal("type", DeveloperErrors.CATEGORIES.TYPE)
            assert.are.equal("reference", DeveloperErrors.CATEGORIES.REFERENCE)
            assert.are.equal("validation", DeveloperErrors.CATEGORIES.VALIDATION)
            assert.are.equal("internal", DeveloperErrors.CATEGORIES.INTERNAL)
        end)
    end)

    describe("error codes", function()
        it("has syntax error codes", function()
            assert.is_string(DeveloperErrors.CODES.UNEXPECTED_TOKEN)
            assert.is_string(DeveloperErrors.CODES.UNTERMINATED_STRING)
            assert.is_string(DeveloperErrors.CODES.MALFORMED_DIRECTIVE)
        end)

        it("has semantic error codes", function()
            assert.is_string(DeveloperErrors.CODES.UNDEFINED_VARIABLE)
            assert.is_string(DeveloperErrors.CODES.UNDEFINED_FUNCTION)
            assert.is_string(DeveloperErrors.CODES.DUPLICATE_DEFINITION)
        end)

        it("has type error codes", function()
            assert.is_string(DeveloperErrors.CODES.TYPE_MISMATCH)
            assert.is_string(DeveloperErrors.CODES.INVALID_ARGUMENT)
        end)

        it("has runtime error codes", function()
            assert.is_string(DeveloperErrors.CODES.STACK_OVERFLOW)
            assert.is_string(DeveloperErrors.CODES.RECURSION_LIMIT)
            assert.is_string(DeveloperErrors.CODES.DIVISION_BY_ZERO)
        end)
    end)

    describe("creating errors", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ show_stack_traces = false })
        end)

        it("creates error with all fields", function()
            local err = errors:create(
                DeveloperErrors.CODES.UNEXPECTED_TOKEN,
                "Expected ')' but found 'end'",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.SYNTAX,
                { file = "test.wls", line = 10, column = 5 },
                { token = "end" }
            )

            assert.are.equal(DeveloperErrors.CODES.UNEXPECTED_TOKEN, err.code)
            assert.are.equal("Expected ')' but found 'end'", err.message)
            assert.are.equal(DeveloperErrors.SEVERITY.ERROR, err.severity)
            assert.are.equal(DeveloperErrors.CATEGORIES.SYNTAX, err.category)
            assert.are.equal("test.wls", err.location.file)
            assert.are.equal(10, err.location.line)
            assert.are.equal("end", err.context.token)
            assert.is_number(err.timestamp)
        end)

        it("includes stack trace when enabled", function()
            errors = DeveloperErrors.new({ show_stack_traces = true })

            local err = errors:create(
                DeveloperErrors.CODES.INTERNAL_ERROR,
                "Test error",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.INTERNAL
            )

            assert.is_string(err.stack_trace)
        end)
    end)

    describe("reporting errors in collect mode", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({
                collect_mode = true,
                show_stack_traces = false
            })
        end)

        it("collects errors", function()
            errors:report(
                DeveloperErrors.CODES.UNDEFINED_VARIABLE,
                "Variable 'x' is not defined",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.SEMANTIC
            )

            errors:report(
                DeveloperErrors.CODES.TYPE_MISMATCH,
                "Expected number",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.TYPE
            )

            local all = errors:get_all()
            assert.are.equal(2, #all)
        end)

        it("enforces max errors limit", function()
            errors = DeveloperErrors.new({
                collect_mode = true,
                max_errors = 3,
                show_stack_traces = false
            })

            for i = 1, 3 do
                errors:report(
                    DeveloperErrors.CODES.INTERNAL_ERROR,
                    "Error " .. i,
                    DeveloperErrors.SEVERITY.ERROR,
                    DeveloperErrors.CATEGORIES.INTERNAL
                )
            end

            -- Fourth error should cause exception
            local success, err = pcall(function()
                errors:report(
                    DeveloperErrors.CODES.INTERNAL_ERROR,
                    "Error 4",
                    DeveloperErrors.SEVERITY.ERROR,
                    DeveloperErrors.CATEGORIES.INTERNAL
                )
            end)

            assert.is_false(success)
            assert.matches("Maximum error limit", err)
        end)

        it("calls error callback", function()
            local called = false

            errors:set_error_callback(function(err)
                called = true
            end)

            errors:report(
                DeveloperErrors.CODES.UNDEFINED_FUNCTION,
                "Function 'foo' not found",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.SEMANTIC
            )

            assert.is_true(called)
        end)
    end)

    describe("filtering errors", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ collect_mode = true, show_stack_traces = false })

            errors:report("C1", "msg1", DeveloperErrors.SEVERITY.WARNING, DeveloperErrors.CATEGORIES.SYNTAX,
                { file = "a.wls" })
            errors:report("C2", "msg2", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.SYNTAX,
                { file = "b.wls" })
            errors:report("C3", "msg3", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.TYPE,
                { file = "a.wls" })
        end)

        it("filters by severity", function()
            local result = errors:get_all({ severity = DeveloperErrors.SEVERITY.ERROR })
            assert.are.equal(2, #result)
        end)

        it("filters by category", function()
            local result = errors:get_all({ category = DeveloperErrors.CATEGORIES.SYNTAX })
            assert.are.equal(2, #result)
        end)

        it("filters by file", function()
            local result = errors:get_all({ file = "a.wls" })
            assert.are.equal(2, #result)
        end)

        it("filters by code", function()
            local result = errors:get_all({ code = "C2" })
            assert.are.equal(1, #result)
        end)
    end)

    describe("error counts", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ collect_mode = true, show_stack_traces = false })
        end)

        it("counts by severity", function()
            errors:report("C", "m", DeveloperErrors.SEVERITY.DEBUG, DeveloperErrors.CATEGORIES.INTERNAL)
            errors:report("C", "m", DeveloperErrors.SEVERITY.INFO, DeveloperErrors.CATEGORIES.INTERNAL)
            errors:report("C", "m", DeveloperErrors.SEVERITY.WARNING, DeveloperErrors.CATEGORIES.INTERNAL)
            errors:report("C", "m", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.INTERNAL)
            errors:report("C", "m", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.INTERNAL)

            local counts = errors:get_counts()

            assert.are.equal(1, counts[DeveloperErrors.SEVERITY.DEBUG])
            assert.are.equal(1, counts[DeveloperErrors.SEVERITY.INFO])
            assert.are.equal(1, counts[DeveloperErrors.SEVERITY.WARNING])
            assert.are.equal(2, counts[DeveloperErrors.SEVERITY.ERROR])
            assert.are.equal(5, counts.total)
        end)

        it("checks has_errors correctly", function()
            errors:report("C", "m", DeveloperErrors.SEVERITY.WARNING, DeveloperErrors.CATEGORIES.INTERNAL)

            assert.is_false(errors:has_errors())
            assert.is_true(errors:has_errors(DeveloperErrors.SEVERITY.WARNING))
        end)
    end)

    describe("convenience methods", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ collect_mode = true, show_stack_traces = false })
        end)

        it("reports syntax error", function()
            errors:syntax_error("Unexpected token", { file = "test.wls", line = 1 })

            local all = errors:get_all()
            assert.are.equal(1, #all)
            assert.are.equal(DeveloperErrors.CATEGORIES.SYNTAX, all[1].category)
        end)

        it("reports undefined reference", function()
            errors:undefined_reference("function", "myFunc", { line = 5 })

            local all = errors:get_all()
            assert.are.equal(1, #all)
            assert.matches("myFunc", all[1].message)
        end)

        it("reports type error", function()
            errors:type_error("number", "string", { line = 10 })

            local all = errors:get_all()
            assert.are.equal(1, #all)
            assert.are.equal(DeveloperErrors.CODES.TYPE_MISMATCH, all[1].code)
        end)
    end)

    describe("format_error", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ show_stack_traces = false })
        end)

        it("formats error message", function()
            local err = errors:create(
                DeveloperErrors.CODES.UNDEFINED_VARIABLE,
                "Variable 'count' is not defined",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.SEMANTIC,
                { file = "game.wls", line = 42, column = 10 }
            )

            local formatted = errors:format_error(err)

            assert.matches("ERROR", formatted)
            assert.matches("WLS%-DEV%-200", formatted)  -- Error code format
            assert.matches("count", formatted)
            assert.matches("game.wls", formatted)
            assert.matches("42", formatted)
        end)

        it("includes context", function()
            local err = errors:create(
                DeveloperErrors.CODES.TYPE_MISMATCH,
                "Type mismatch",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.TYPE,
                nil,
                { expected = "number", got = "string" }
            )

            local formatted = errors:format_error(err)

            assert.matches("expected", formatted)
            assert.matches("number", formatted)
        end)
    end)

    describe("generate_report", function()
        local errors

        before_each(function()
            errors = DeveloperErrors.new({ collect_mode = true, show_stack_traces = false })
        end)

        it("generates diagnostic report", function()
            errors:report(
                DeveloperErrors.CODES.UNDEFINED_VARIABLE,
                "Variable not found",
                DeveloperErrors.SEVERITY.ERROR,
                DeveloperErrors.CATEGORIES.SEMANTIC
            )
            errors:report(
                DeveloperErrors.CODES.TYPE_MISMATCH,
                "Type mismatch",
                DeveloperErrors.SEVERITY.WARNING,
                DeveloperErrors.CATEGORIES.TYPE
            )

            local report = errors:generate_report()

            assert.is_string(report)
            assert.matches("Developer Error Report", report)
            assert.matches("Summary", report)
            assert.matches("Total: 2", report)
        end)
    end)

    describe("clear", function()
        it("clears all errors", function()
            local errors = DeveloperErrors.new({ collect_mode = true, show_stack_traces = false })
            errors:report("C", "m", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.INTERNAL)
            errors:report("C", "m", DeveloperErrors.SEVERITY.ERROR, DeveloperErrors.CATEGORIES.INTERNAL)

            errors:clear()

            assert.are.equal(0, #errors:get_all())
            assert.are.equal(0, errors.error_count)
        end)
    end)
end)
