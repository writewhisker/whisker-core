-- tests/debug/breakpoints_spec.lua
-- Tests for WLS 1.0.0 GAP-056: Breakpoint Management

local Breakpoints = require("lib.whisker.debug.breakpoints")

describe("Breakpoints", function()

    describe("Breakpoints.new()", function()
        it("should create a new Breakpoints instance", function()
            local bp_manager = Breakpoints.new()
            assert.is_not_nil(bp_manager)
            assert.equals(1, bp_manager.next_id)
        end)
    end)

    describe("Line Breakpoints", function()
        it("should add a line breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                type = Breakpoints.TYPE_LINE,
                file = "story.wlk",
                line = 10
            })

            assert.is_not_nil(bp)
            assert.equals(1, bp.id)
            assert.equals("line", bp.type)
            assert.equals("story.wlk", bp.file)
            assert.equals(10, bp.line)
            assert.is_true(bp.verified)
            assert.is_true(bp.enabled)
        end)

        it("should check line breakpoints", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result)
            assert.equals("break", result.type)
        end)

        it("should not trigger breakpoint at wrong line", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            local result = bp_manager:check_line("story.wlk", 15, {})
            assert.is_nil(result)
        end)

        it("should not trigger breakpoint in wrong file", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            local result = bp_manager:check_line("other.wlk", 10, {})
            assert.is_nil(result)
        end)

        it("should remove a line breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            local removed = bp_manager:remove(bp.id)
            assert.is_true(removed)

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result)
        end)
    end)

    describe("Passage Breakpoints", function()
        it("should add a passage breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                type = Breakpoints.TYPE_PASSAGE,
                passage = "Start"
            })

            assert.is_not_nil(bp)
            assert.equals("passage", bp.type)
            assert.equals("Start", bp.passage)
            assert.is_true(bp.verified)
        end)

        it("should check passage breakpoints", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                type = Breakpoints.TYPE_PASSAGE,
                passage = "Start"
            })

            local result = bp_manager:check_passage("Start", {})
            assert.is_not_nil(result)
            assert.equals("break", result.type)
        end)

        it("should not trigger at wrong passage", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                type = Breakpoints.TYPE_PASSAGE,
                passage = "Start"
            })

            local result = bp_manager:check_passage("End", {})
            assert.is_nil(result)
        end)
    end)

    describe("Conditional Breakpoints", function()
        it("should add a conditional breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                type = Breakpoints.TYPE_CONDITIONAL,
                file = "story.wlk",
                line = 10,
                condition = "x > 5"
            })

            assert.is_not_nil(bp)
            assert.equals("x > 5", bp.condition)
        end)

        it("should evaluate simple true condition", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                condition = "true"
            })

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result)
            assert.equals("break", result.type)
        end)

        it("should not trigger on false condition", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                condition = "false"
            })

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result)
        end)
    end)

    describe("Hit Count Breakpoints", function()
        it("should track hit counts", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            bp_manager:check_line("story.wlk", 10, {})
            assert.equals(1, bp.hit_count)

            bp_manager:check_line("story.wlk", 10, {})
            assert.equals(2, bp.hit_count)

            bp_manager:check_line("story.wlk", 10, {})
            assert.equals(3, bp.hit_count)
        end)

        it("should respect >= hit condition", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                file = "story.wlk",
                line = 10,
                hit_condition = ">= 3"
            })

            -- First two hits should not trigger
            local result1 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result1)

            local result2 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result2)

            -- Third hit should trigger
            local result3 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result3)
            assert.equals("break", result3.type)
        end)

        it("should respect == hit condition", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                hit_condition = "== 2"
            })

            -- First hit should not trigger
            local result1 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result1)

            -- Second hit should trigger
            local result2 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result2)

            -- Third hit should not trigger
            local result3 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result3)
        end)

        it("should respect > hit condition", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                hit_condition = "> 2"
            })

            local result1 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result1)

            local result2 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result2)

            local result3 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result3)
        end)

        it("should respect modulo hit condition", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                hit_condition = "% 3 == 0"
            })

            -- Hits 1, 2 should not trigger
            local result1 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result1)
            local result2 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result2)

            -- Hit 3 should trigger
            local result3 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result3)

            -- Hits 4, 5 should not trigger
            local result4 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result4)
            local result5 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result5)

            -- Hit 6 should trigger
            local result6 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result6)
        end)
    end)

    describe("Logpoints", function()
        it("should create a logpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                type = Breakpoints.TYPE_LOGPOINT,
                file = "story.wlk",
                line = 10,
                log_message = "Value is: {x}"
            })

            assert.is_not_nil(bp)
            assert.equals("logpoint", bp.type)
            assert.equals("Value is: {x}", bp.log_message)
        end)

        it("should return log result instead of break", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                type = Breakpoints.TYPE_LOGPOINT,
                file = "story.wlk",
                line = 10,
                log_message = "Reached line 10"
            })

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result)
            assert.equals("log", result.type)
            assert.equals("Reached line 10", result.message)
        end)

        it("should format log message with simple values", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({
                type = Breakpoints.TYPE_LOGPOINT,
                file = "story.wlk",
                line = 10,
                log_message = "Value: {test_var}"
            })

            -- Create a mock game_state
            local mock_game_state = {
                get = function(self, key)
                    if key == "test_var" then return 42 end
                    return nil
                end
            }

            local result = bp_manager:check_line("story.wlk", 10, {
                game_state = mock_game_state
            })

            assert.is_not_nil(result)
            assert.equals("Value: 42", result.message)
        end)
    end)

    describe("Enable/Disable", function()
        it("should disable a breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            bp_manager:disable(bp.id)

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_nil(result)
        end)

        it("should re-enable a breakpoint", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({
                file = "story.wlk",
                line = 10
            })

            bp_manager:disable(bp.id)
            bp_manager:enable(bp.id)

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result)
        end)
    end)

    describe("Clear Operations", function()
        it("should clear all breakpoints for a file", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({ file = "story.wlk", line = 10 })
            bp_manager:add({ file = "story.wlk", line = 20 })
            bp_manager:add({ file = "other.wlk", line = 5 })

            bp_manager:clear_file("story.wlk")

            assert.is_nil(bp_manager:check_line("story.wlk", 10, {}))
            assert.is_nil(bp_manager:check_line("story.wlk", 20, {}))
            assert.is_not_nil(bp_manager:check_line("other.wlk", 5, {}))
        end)

        it("should clear all breakpoints", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({ file = "story.wlk", line = 10 })
            bp_manager:add({ passage = "Start" })

            bp_manager:clear_all()

            assert.is_nil(bp_manager:check_line("story.wlk", 10, {}))
            assert.is_nil(bp_manager:check_passage("Start", {}))
        end)
    end)

    describe("Get Operations", function()
        it("should get all breakpoints", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({ file = "story.wlk", line = 10 })
            bp_manager:add({ file = "story.wlk", line = 20 })
            bp_manager:add({ passage = "Start" })

            local all = bp_manager:get_all()
            assert.equals(3, #all)
        end)

        it("should get breakpoints for a file", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({ file = "story.wlk", line = 10 })
            bp_manager:add({ file = "story.wlk", line = 20 })
            bp_manager:add({ file = "other.wlk", line = 5 })

            local file_bps = bp_manager:get_for_file("story.wlk")
            assert.equals(2, #file_bps)
        end)

        it("should get a breakpoint by id", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({ file = "story.wlk", line = 10 })

            local retrieved = bp_manager:get(bp.id)
            assert.is_not_nil(retrieved)
            assert.equals(bp.id, retrieved.id)
        end)
    end)

    describe("Serialization", function()
        it("should serialize breakpoints", function()
            local bp_manager = Breakpoints.new()
            bp_manager:add({ file = "story.wlk", line = 10, condition = "x > 5" })
            bp_manager:add({ passage = "Start" })

            local data = bp_manager:serialize()
            assert.is_not_nil(data)
            assert.is_not_nil(data.breakpoints)
            assert.equals(3, data.next_id)
        end)

        it("should deserialize breakpoints", function()
            local bp_manager1 = Breakpoints.new()
            bp_manager1:add({ file = "story.wlk", line = 10 })
            bp_manager1:add({ passage = "Start" })

            local data = bp_manager1:serialize()

            local bp_manager2 = Breakpoints.new()
            bp_manager2:deserialize(data)

            assert.is_not_nil(bp_manager2:check_line("story.wlk", 10, {}))
            assert.is_not_nil(bp_manager2:check_passage("Start", {}))
        end)
    end)

    describe("Reset Hit Counts", function()
        it("should reset all hit counts", function()
            local bp_manager = Breakpoints.new()
            local bp = bp_manager:add({ file = "story.wlk", line = 10 })

            bp_manager:check_line("story.wlk", 10, {})
            bp_manager:check_line("story.wlk", 10, {})
            assert.equals(2, bp.hit_count)

            bp_manager:reset_hit_counts()
            assert.equals(0, bp.hit_count)
        end)
    end)

end)
