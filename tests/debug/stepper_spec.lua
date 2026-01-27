-- tests/debug/stepper_spec.lua
-- Tests for WLS 1.0.0 GAP-057: Step Commands

local Stepper = require("lib.whisker.debug.stepper")

describe("Stepper", function()

    describe("Stepper.new()", function()
        it("should create a new Stepper instance", function()
            local stepper = Stepper.new(nil)
            assert.is_not_nil(stepper)
            assert.equals(Stepper.STATE_STOPPED, stepper.state)
            assert.equals(Stepper.MODE_CONTINUE, stepper.mode)
        end)

        it("should accept an engine parameter", function()
            local mock_engine = { name = "test" }
            local stepper = Stepper.new(mock_engine)
            assert.equals(mock_engine, stepper.engine)
        end)
    end)

    describe("State Management", function()
        it("should start execution", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            assert.equals(Stepper.STATE_RUNNING, stepper.state)
        end)

        it("should pause execution", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:pause()
            assert.equals(Stepper.STATE_PAUSED, stepper.state)
        end)

        it("should resume execution", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:pause()
            stepper:resume()
            assert.equals(Stepper.STATE_RUNNING, stepper.state)
        end)

        it("should stop execution", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:stop()
            assert.equals(Stepper.STATE_STOPPED, stepper.state)
        end)

        it("should report correct state via helpers", function()
            local stepper = Stepper.new(nil)

            assert.is_true(stepper:is_stopped())
            assert.is_false(stepper:is_running())
            assert.is_false(stepper:is_paused())

            stepper:start()
            assert.is_false(stepper:is_stopped())
            assert.is_true(stepper:is_running())
            assert.is_false(stepper:is_paused())

            stepper:pause()
            assert.is_false(stepper:is_stopped())
            assert.is_false(stepper:is_running())
            assert.is_true(stepper:is_paused())
        end)
    end)

    describe("Continue Mode", function()
        it("should set continue mode", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:pause()
            stepper:continue()

            assert.equals(Stepper.MODE_CONTINUE, stepper.mode)
            assert.equals(Stepper.STATE_RUNNING, stepper.state)
        end)

        it("should not pause at any location in continue mode", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:continue()

            assert.is_false(stepper:should_pause_at("file.wlk", 10, "content_line"))
            assert.is_false(stepper:should_pause_at("file.wlk", 20, "passage_enter"))
        end)
    end)

    describe("Step Into Mode", function()
        it("should set step into mode", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:pause()
            stepper:step_into()

            assert.equals(Stepper.MODE_STEP_INTO, stepper.mode)
            assert.equals(Stepper.STATE_RUNNING, stepper.state)
        end)

        it("should pause at any new line in step into mode", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:step_into()

            assert.is_true(stepper:should_pause_at("file.wlk", 10, "content_line"))
            assert.is_true(stepper:should_pause_at("file.wlk", 20, "passage_enter"))
            assert.is_true(stepper:should_pause_at("other.wlk", 5, "function_enter"))
        end)
    end)

    describe("Step Over Mode", function()
        it("should set step over mode and capture depth", function()
            local mock_engine = {
                tunnel_stack = {},
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper:start()
            stepper:pause()
            stepper:step_over()

            assert.equals(Stepper.MODE_STEP_OVER, stepper.mode)
            assert.equals(0, stepper.step_depth)
        end)

        it("should pause at same depth in step over mode", function()
            local mock_engine = {
                tunnel_stack = {},
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper:start()
            stepper:step_over()

            assert.is_true(stepper:should_pause_at("file.wlk", 10, "content_line"))
        end)

        it("should not pause at deeper level in step over mode", function()
            local mock_engine = {
                tunnel_stack = { { passage_id = "test" } },  -- Depth 1
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper.step_depth = 0  -- We want to step over at depth 0
            stepper.mode = Stepper.MODE_STEP_OVER
            stepper.state = Stepper.STATE_RUNNING

            -- With depth 1, should not pause
            assert.is_false(stepper:should_pause_at("file.wlk", 10, "content_line"))
        end)

        it("should pause at lower depth in step over mode", function()
            local mock_engine = {
                tunnel_stack = {},  -- Depth 0
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper.step_depth = 1  -- We're stepping over from depth 1
            stepper.mode = Stepper.MODE_STEP_OVER
            stepper.state = Stepper.STATE_RUNNING

            -- At depth 0, should pause
            assert.is_true(stepper:should_pause_at("file.wlk", 10, "content_line"))
        end)
    end)

    describe("Step Out Mode", function()
        it("should set step out mode with lower depth target", function()
            local mock_engine = {
                tunnel_stack = { { passage_id = "test" } },  -- Depth 1
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper:start()
            stepper:pause()
            stepper:step_out()

            assert.equals(Stepper.MODE_STEP_OUT, stepper.mode)
            assert.equals(0, stepper.step_depth)  -- Target depth is 1 - 1 = 0
        end)

        it("should not pause until reaching target depth", function()
            local mock_engine = {
                tunnel_stack = { { passage_id = "test" } },  -- Depth 1
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper.step_depth = 0
            stepper.mode = Stepper.MODE_STEP_OUT
            stepper.state = Stepper.STATE_RUNNING

            -- At depth 1, should not pause
            assert.is_false(stepper:should_pause_at("file.wlk", 10, "content_line"))
        end)

        it("should pause when returning to target depth", function()
            local mock_engine = {
                tunnel_stack = {},  -- Depth 0
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper.step_depth = 0
            stepper.mode = Stepper.MODE_STEP_OUT
            stepper.state = Stepper.STATE_RUNNING

            -- At depth 0, should pause
            assert.is_true(stepper:should_pause_at("file.wlk", 10, "content_line"))
        end)
    end)

    describe("Step Back", function()
        it("should step back using game_state undo", function()
            local undone = false
            local mock_engine = {
                game_state = {
                    can_undo = function() return true end,
                    undo = function() undone = true end
                }
            }
            local stepper = Stepper.new(mock_engine)
            stepper:start()

            local success = stepper:step_back()
            assert.is_true(success)
            assert.is_true(undone)
            assert.equals(Stepper.STATE_PAUSED, stepper.state)
        end)

        it("should fail step back when no history", function()
            local mock_engine = {
                game_state = {
                    can_undo = function() return false end
                }
            }
            local stepper = Stepper.new(mock_engine)
            stepper:start()

            local success = stepper:step_back()
            assert.is_false(success)
        end)
    end)

    describe("Event Handlers", function()
        it("should handle passage entry and pause in step into", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:step_into()

            local paused = stepper:on_passage_enter({
                name = "TestPassage",
                file = "story.wlk",
                location = { line = 10 }
            })

            assert.is_true(paused)
            assert.equals(Stepper.STATE_PAUSED, stepper.state)
        end)

        it("should not pause passage entry in continue mode", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:continue()

            local paused = stepper:on_passage_enter({
                name = "TestPassage",
                file = "story.wlk",
                location = { line = 10 }
            })

            assert.is_false(paused)
            assert.equals(Stepper.STATE_RUNNING, stepper.state)
        end)

        it("should handle content line and pause in step into", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:step_into()

            local paused = stepper:on_content_line("story.wlk", 15)
            assert.is_true(paused)
        end)

        it("should handle function entry and pause in step into", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:step_into()

            local paused = stepper:on_function_enter("test_func", "story.wlk", 20)
            assert.is_true(paused)
        end)

        it("should handle function return in step out mode", function()
            local mock_engine = {
                tunnel_stack = {},
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            stepper.mode = Stepper.MODE_STEP_OUT
            stepper.step_depth = 0
            stepper.state = Stepper.STATE_RUNNING

            local paused = stepper:on_function_return("test_func")
            assert.is_true(paused)
        end)
    end)

    describe("Callbacks", function()
        it("should call on_pause callback when pausing", function()
            local callback_called = false
            local callback_reason = nil
            local callback_info = nil

            local stepper = Stepper.new(nil)
            stepper:set_on_pause(function(reason, info)
                callback_called = true
                callback_reason = reason
                callback_info = info
            end)

            stepper:start()
            stepper:step_into()
            stepper:on_content_line("story.wlk", 10)

            assert.is_true(callback_called)
            assert.equals("step", callback_reason)
            assert.equals("story.wlk", callback_info.file)
            assert.equals(10, callback_info.line)
        end)
    end)

    describe("Depth Calculation", function()
        it("should calculate depth from tunnel stack", function()
            local mock_engine = {
                tunnel_stack = {
                    { passage_id = "p1" },
                    { passage_id = "p2" }
                },
                lua_interpreter = { call_stack = {} }
            }
            local stepper = Stepper.new(mock_engine)
            assert.equals(2, stepper:get_current_depth())
        end)

        it("should calculate depth from game_state tunnel stack", function()
            local mock_engine = {
                game_state = {
                    tunnel_stack = {
                        { passage_id = "p1" },
                        { passage_id = "p2" },
                        { passage_id = "p3" }
                    }
                }
            }
            local stepper = Stepper.new(mock_engine)
            assert.equals(3, stepper:get_current_depth())
        end)

        it("should combine tunnel and call stack depths", function()
            local mock_engine = {
                tunnel_stack = { { passage_id = "p1" } },
                lua_interpreter = {
                    call_stack = { {}, {} }  -- 2 function calls
                }
            }
            local stepper = Stepper.new(mock_engine)
            assert.equals(3, stepper:get_current_depth())  -- 1 + 2
        end)

        it("should return 0 for no stacks", function()
            local stepper = Stepper.new(nil)
            assert.equals(0, stepper:get_current_depth())
        end)
    end)

    describe("Serialization", function()
        it("should serialize stepper state", function()
            local stepper = Stepper.new(nil)
            stepper:start()
            stepper:step_over()

            local data = stepper:serialize()
            assert.is_not_nil(data)
            assert.equals(Stepper.STATE_RUNNING, data.state)
            assert.equals(Stepper.MODE_STEP_OVER, data.mode)
        end)

        it("should deserialize stepper state", function()
            local data = {
                state = Stepper.STATE_PAUSED,
                mode = Stepper.MODE_STEP_INTO,
                step_depth = 2
            }

            local stepper = Stepper.new(nil)
            stepper:deserialize(data)

            assert.equals(Stepper.STATE_PAUSED, stepper.state)
            assert.equals(Stepper.MODE_STEP_INTO, stepper.mode)
            assert.equals(2, stepper.step_depth)
        end)
    end)

    describe("Mode Constants", function()
        it("should have all mode constants", function()
            assert.is_not_nil(Stepper.MODE_CONTINUE)
            assert.is_not_nil(Stepper.MODE_STEP_OVER)
            assert.is_not_nil(Stepper.MODE_STEP_INTO)
            assert.is_not_nil(Stepper.MODE_STEP_OUT)
        end)

        it("should have all state constants", function()
            assert.is_not_nil(Stepper.STATE_RUNNING)
            assert.is_not_nil(Stepper.STATE_PAUSED)
            assert.is_not_nil(Stepper.STATE_STOPPED)
        end)
    end)

end)
