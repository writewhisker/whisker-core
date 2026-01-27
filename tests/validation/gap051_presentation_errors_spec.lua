-- tests/validation/gap051_presentation_errors_spec.lua
-- Tests for GAP-051: Presentation Errors

describe("GAP-051: Presentation Errors", function()
    local PresentationErrors

    setup(function()
        PresentationErrors = require("whisker.validation.presentation_errors")
    end)

    describe("PresentationErrors module", function()
        it("creates new instance", function()
            local errors = PresentationErrors.new()
            assert.is_not_nil(errors)
        end)

        it("accepts configuration", function()
            local errors = PresentationErrors.new({
                log_technical = true,
                max_history = 50
            })

            assert.is_true(errors.config.log_technical)
            assert.are.equal(50, errors.config.max_history)
        end)
    end)

    describe("error codes", function()
        it("has story error codes", function()
            assert.is_string(PresentationErrors.CODES.STORY_NOT_FOUND)
            assert.is_string(PresentationErrors.CODES.PASSAGE_NOT_FOUND)
            assert.is_string(PresentationErrors.CODES.CHOICE_INVALID)
        end)

        it("has media error codes", function()
            assert.is_string(PresentationErrors.CODES.IMAGE_NOT_FOUND)
            assert.is_string(PresentationErrors.CODES.AUDIO_NOT_FOUND)
            assert.is_string(PresentationErrors.CODES.VIDEO_NOT_FOUND)
        end)

        it("has save/load error codes", function()
            assert.is_string(PresentationErrors.CODES.SAVE_FAILED)
            assert.is_string(PresentationErrors.CODES.LOAD_FAILED)
            assert.is_string(PresentationErrors.CODES.SAVE_CORRUPT)
        end)
    end)

    describe("creating errors", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("creates error with user-friendly message", function()
            local err = errors:create(
                PresentationErrors.CODES.STORY_NOT_FOUND,
                "Technical: file not found at /path/to/story"
            )

            assert.is_not_nil(err)
            assert.are.equal(PresentationErrors.CODES.STORY_NOT_FOUND, err.code)
            assert.is_string(err.message)
            assert.are_not_equal("Technical: file not found at /path/to/story", err.message)
        end)

        it("stores technical details separately", function()
            local err = errors:create(
                PresentationErrors.CODES.SAVE_FAILED,
                "IOException: disk full"
            )

            assert.are.equal("IOException: disk full", err._technical)
        end)

        it("includes timestamp", function()
            local err = errors:create(PresentationErrors.CODES.UNKNOWN_ERROR)

            assert.is_number(err.timestamp)
        end)
    end)

    describe("reporting errors", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("adds error to history", function()
            errors:report(PresentationErrors.CODES.PASSAGE_NOT_FOUND, "Missing: End")

            local recent = errors:get_recent()
            assert.are.equal(1, #recent)
        end)

        it("limits history size", function()
            errors = PresentationErrors.new({ max_history = 3 })

            for i = 1, 5 do
                errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "Error " .. i)
            end

            local recent = errors:get_recent()
            assert.are.equal(3, #recent)
        end)

        it("calls error callback", function()
            local called = false
            local received_error = nil

            errors = PresentationErrors.new({
                on_error = function(err)
                    called = true
                    received_error = err
                end
            })

            errors:report(PresentationErrors.CODES.NETWORK_ERROR, "timeout")

            assert.is_true(called)
            assert.is_not_nil(received_error)
            assert.are.equal(PresentationErrors.CODES.NETWORK_ERROR, received_error.code)
        end)
    end)

    describe("user-friendly messages", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("has default message for all codes", function()
            for name, code in pairs(PresentationErrors.CODES) do
                local msg = errors:get_message(code)
                assert.is_string(msg, "Missing message for " .. name)
                assert.is_true(#msg > 0, "Empty message for " .. name)
            end
        end)

        it("allows custom messages", function()
            errors:set_message(
                PresentationErrors.CODES.SAVE_FAILED,
                "Oops! Couldn't save your game."
            )

            local msg = errors:get_message(PresentationErrors.CODES.SAVE_FAILED)
            assert.are.equal("Oops! Couldn't save your game.", msg)
        end)
    end)

    describe("recoverability", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("identifies recoverable errors", function()
            assert.is_true(errors:is_recoverable(PresentationErrors.CODES.STORY_NOT_FOUND))
            assert.is_true(errors:is_recoverable(PresentationErrors.CODES.NETWORK_ERROR))
            assert.is_true(errors:is_recoverable(PresentationErrors.CODES.SAVE_FAILED))
        end)

        it("identifies non-recoverable errors", function()
            assert.is_false(errors:is_recoverable(PresentationErrors.CODES.SAVE_CORRUPT))
            assert.is_false(errors:is_recoverable(PresentationErrors.CODES.SAVE_VERSION_MISMATCH))
        end)
    end)

    describe("recovery suggestions", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("provides suggestions for known errors", function()
            local suggestions = errors:get_recovery_suggestions(PresentationErrors.CODES.NETWORK_ERROR)

            assert.is_table(suggestions)
            assert.is_true(#suggestions > 0)
        end)

        it("provides default suggestions for unknown errors", function()
            local suggestions = errors:get_recovery_suggestions("UNKNOWN-CODE")

            assert.is_table(suggestions)
            assert.is_true(#suggestions > 0)
        end)
    end)

    describe("from_internal", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("converts internal error with type hint", function()
            local err = errors:from_internal(
                { message = "File not found: passage.wls" },
                "passage"
            )

            assert.are.equal(PresentationErrors.CODES.PASSAGE_NOT_FOUND, err.code)
        end)

        it("converts string error", function()
            local err = errors:from_internal(
                "Connection timeout after 30s",
                "network"
            )

            assert.are.equal(PresentationErrors.CODES.NETWORK_ERROR, err.code)
        end)

        it("defaults to unknown error", function()
            local err = errors:from_internal("Something happened")

            assert.are.equal(PresentationErrors.CODES.UNKNOWN_ERROR, err.code)
        end)
    end)

    describe("format_for_display", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("formats error for UI", function()
            local err = errors:create(PresentationErrors.CODES.SAVE_FAILED)
            local display = errors:format_for_display(err)

            assert.is_string(display.message)
            assert.is_boolean(display.recoverable)
            assert.is_table(display.suggestions)
        end)

        it("optionally includes code", function()
            local err = errors:create(PresentationErrors.CODES.SAVE_FAILED)
            local display = errors:format_for_display(err, { show_code = true })

            assert.are.equal(PresentationErrors.CODES.SAVE_FAILED, display.code)
        end)

        it("optionally excludes suggestions", function()
            local err = errors:create(PresentationErrors.CODES.SAVE_FAILED)
            local display = errors:format_for_display(err, { show_suggestions = false })

            assert.is_nil(display.suggestions)
        end)
    end)

    describe("error history", function()
        local errors

        before_each(function()
            errors = PresentationErrors.new()
        end)

        it("retrieves recent errors", function()
            errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "e1")
            errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "e2")
            errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "e3")

            local recent = errors:get_recent(2)
            assert.are.equal(2, #recent)
        end)

        it("clears history", function()
            errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "e1")
            errors:report(PresentationErrors.CODES.UNKNOWN_ERROR, "e2")

            errors:clear_history()

            assert.are.equal(0, #errors:get_recent())
        end)
    end)
end)
