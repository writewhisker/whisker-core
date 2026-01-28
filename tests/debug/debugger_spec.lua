-- tests/debug/debugger_spec.lua
-- Tests for WLS 1.0.0 GAP-055: Debug Runtime

local Debugger = require("lib.whisker.debug.debugger")
local Breakpoints = require("lib.whisker.debug.breakpoints")
local Stepper = require("lib.whisker.debug.stepper")

describe("Debugger", function()

    describe("Debugger.new()", function()
        it("should create a new Debugger instance", function()
            local debugger = Debugger.new()
            assert.is_not_nil(debugger)
            assert.is_not_nil(debugger.breakpoints)
            assert.is_not_nil(debugger.stepper)
        end)

        it("should accept engine option", function()
            local mock_engine = { name = "test" }
            local debugger = Debugger.new({ engine = mock_engine })
            assert.equals(mock_engine, debugger.engine)
        end)

        it("should accept game_state option", function()
            local mock_state = { name = "state" }
            local debugger = Debugger.new({ game_state = mock_state })
            assert.equals(mock_state, debugger.game_state)
        end)
    end)

    describe("Set Engine/State", function()
        it("should set engine after creation", function()
            local debugger = Debugger.new()
            local mock_engine = { name = "engine" }
            debugger:set_engine(mock_engine)
            assert.equals(mock_engine, debugger.engine)
        end)

        it("should set game_state after creation", function()
            local debugger = Debugger.new()
            local mock_state = { name = "state" }
            debugger:set_game_state(mock_state)
            assert.equals(mock_state, debugger.game_state)
        end)
    end)

    describe("Breakpoint Management", function()
        it("should set a line breakpoint", function()
            local debugger = Debugger.new()
            local result = debugger:set_breakpoint("story.wlk", 10, nil)

            assert.is_not_nil(result)
            assert.is_true(result.verified)
            assert.equals(10, result.line)
            assert.is_number(result.id)
        end)

        it("should set a conditional breakpoint", function()
            local debugger = Debugger.new()
            local result = debugger:set_breakpoint("story.wlk", 10, "x > 5")

            assert.is_not_nil(result)
            local bp = debugger.breakpoints:get(result.id)
            assert.equals("x > 5", bp.condition)
        end)

        it("should set a passage breakpoint", function()
            local debugger = Debugger.new()
            local result = debugger:set_passage_breakpoint("Start", nil)

            assert.is_not_nil(result)
            assert.is_true(result.verified)
            assert.equals("Start", result.passage)
        end)

        it("should remove a breakpoint", function()
            local debugger = Debugger.new()
            local result = debugger:set_breakpoint("story.wlk", 10, nil)
            local removed = debugger:remove_breakpoint(result.id)

            assert.is_true(removed)
        end)

        it("should clear file breakpoints", function()
            local debugger = Debugger.new()
            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger:set_breakpoint("story.wlk", 20, nil)
            debugger:set_breakpoint("other.wlk", 5, nil)

            debugger:clear_file_breakpoints("story.wlk")

            local all_bps = debugger:get_breakpoints()
            assert.equals(1, #all_bps)
        end)

        it("should get all breakpoints", function()
            local debugger = Debugger.new()
            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger:set_breakpoint("story.wlk", 20, nil)

            local all = debugger:get_breakpoints()
            assert.equals(2, #all)
        end)
    end)

    describe("Breakpoint Checking", function()
        it("should check line breakpoint", function()
            local stopped = false
            local stop_reason = nil

            local debugger = Debugger.new()
            debugger.on_stopped = function(reason, details)
                stopped = true
                stop_reason = reason
            end

            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger:start()

            local hit = debugger:check_breakpoint("story.wlk", 10)
            assert.is_true(hit)
            assert.is_true(stopped)
            assert.equals("breakpoint", stop_reason)
        end)

        it("should check passage breakpoint", function()
            local stopped = false

            local debugger = Debugger.new()
            debugger.on_stopped = function(reason, details)
                stopped = true
            end

            debugger:set_passage_breakpoint("Start", nil)
            debugger:start()

            local hit = debugger:check_passage_breakpoint("Start")
            assert.is_true(hit)
            assert.is_true(stopped)
        end)

        it("should not hit breakpoint at wrong location", function()
            local debugger = Debugger.new()
            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger:start()

            local hit = debugger:check_breakpoint("story.wlk", 20)
            assert.is_false(hit)
        end)
    end)

    describe("Execution Control", function()
        it("should start debugging", function()
            local debugger = Debugger.new()
            debugger:start(false)
            assert.is_true(debugger.stepper:is_running())
        end)

        it("should start paused with stop_on_entry", function()
            local stopped = false
            local debugger = Debugger.new()
            debugger.on_stopped = function() stopped = true end

            debugger:start(true)
            assert.is_true(stopped)
        end)

        it("should pause execution", function()
            local stopped = false
            local debugger = Debugger.new()
            debugger.on_stopped = function() stopped = true end

            debugger:start(false)
            debugger:pause()

            assert.is_true(stopped)
            assert.is_true(debugger:is_paused())
        end)

        it("should continue execution", function()
            local debugger = Debugger.new()
            debugger:start(true)
            debugger:continue()

            assert.equals(Stepper.MODE_CONTINUE, debugger.stepper:get_mode())
        end)

        it("should step over (next)", function()
            local debugger = Debugger.new()
            debugger:start(true)
            debugger:next()

            assert.equals(Stepper.MODE_STEP_OVER, debugger.stepper:get_mode())
        end)

        it("should step into", function()
            local debugger = Debugger.new()
            debugger:start(true)
            debugger:step_in()

            assert.equals(Stepper.MODE_STEP_INTO, debugger.stepper:get_mode())
        end)

        it("should step out", function()
            local debugger = Debugger.new()
            debugger:start(true)
            debugger:step_out()

            assert.equals(Stepper.MODE_STEP_OUT, debugger.stepper:get_mode())
        end)

        it("should step back with history", function()
            local undone = false
            local mock_state = {
                can_undo = function() return true end,
                undo = function() undone = true end
            }

            local debugger = Debugger.new({ game_state = mock_state })
            debugger:start()

            local success = debugger:step_back()
            assert.is_true(success)
            assert.is_true(undone)
        end)
    end)

    describe("Stack Trace", function()
        it("should return stack trace with current passage", function()
            local mock_state = {
                get_current_passage = function() return "TestPassage" end,
                tunnel_stack = {}
            }

            local debugger = Debugger.new({ game_state = mock_state })
            debugger.source_path = "story.wlk"

            local frames = debugger:get_stack_trace()
            assert.is_not_nil(frames)
            assert.equals(1, #frames)
            assert.equals("TestPassage", frames[1].name)
        end)

        it("should include tunnel stack in stack trace", function()
            local mock_state = {
                get_current_passage = function() return "Current" end,
                tunnel_stack = {
                    { passage_id = "Level1", position = 5 },
                    { passage_id = "Level2", position = 10 }
                }
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local frames = debugger:get_stack_trace()

            assert.equals(3, #frames)  -- Current + 2 tunnel entries
        end)
    end)

    describe("Scopes", function()
        it("should return scopes for frame", function()
            local debugger = Debugger.new()
            local scopes = debugger:get_scopes(1)

            assert.is_not_nil(scopes)
            assert.equals(3, #scopes)

            local names = {}
            for _, s in ipairs(scopes) do
                names[s.name] = true
            end

            assert.is_true(names["Local"])
            assert.is_true(names["Story Variables"])
            assert.is_true(names["Collections"])
        end)
    end)

    describe("Variables", function()
        it("should return story variables", function()
            local mock_state = {
                get_all_variables = function()
                    return { health = 100, gold = 50 }
                end,
                temp_variables = {}
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            -- Find story variables scope
            local story_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Story Variables" then
                    story_ref = s.variablesReference
                end
            end

            local vars = debugger:get_variables(story_ref)
            assert.is_not_nil(vars.health)
            assert.equals(100, vars.health.value)
            assert.is_not_nil(vars.gold)
            assert.equals(50, vars.gold.value)
        end)

        it("should return temp variables in local scope", function()
            local mock_state = {
                temp_variables = { temp_x = 42 },
                get_all_variables = function() return {} end
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            local local_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Local" then
                    local_ref = s.variablesReference
                end
            end

            local vars = debugger:get_variables(local_ref)
            assert.is_not_nil(vars.temp_x)
            assert.equals(42, vars.temp_x.value)
        end)

        it("should return collections", function()
            local mock_state = {
                lists = { MyList = { values = {"a", "b"}, active = {} } },
                arrays = { MyArray = {1, 2, 3} },
                maps = { MyMap = { key = "value" } },
                get_all_variables = function() return {} end
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            local coll_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Collections" then
                    coll_ref = s.variablesReference
                end
            end

            local vars = debugger:get_variables(coll_ref)
            assert.is_not_nil(vars["LIST:MyList"])
            assert.is_not_nil(vars["ARRAY:MyArray"])
            assert.is_not_nil(vars["MAP:MyMap"])
        end)

        it("should handle nested table expansion", function()
            local mock_state = {
                get_all_variables = function()
                    return { nested = { a = 1, b = 2 } }
                end,
                temp_variables = {}
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            local story_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Story Variables" then
                    story_ref = s.variablesReference
                end
            end

            local vars = debugger:get_variables(story_ref)
            assert.is_true(vars.nested.has_children)
            assert.is_true(vars.nested.ref > 0)

            -- Expand nested table
            local nested_vars = debugger:get_variables(vars.nested.ref)
            assert.is_not_nil(nested_vars.a)
            assert.equals(1, nested_vars.a.value)
        end)
    end)

    describe("Evaluate", function()
        it("should evaluate simple expression", function()
            local debugger = Debugger.new()
            local success, result = debugger:evaluate("1 + 2", 1)

            assert.is_true(success)
            assert.equals(3, result)
        end)

        it("should evaluate table expression", function()
            local debugger = Debugger.new()
            local success, result = debugger:evaluate("{x=1}", 1)

            assert.is_true(success)
            assert.equals("table", type(result))
        end)

        it("should return error for invalid expression", function()
            local debugger = Debugger.new()
            local success, result = debugger:evaluate("invalid@@@@", 1)

            assert.is_false(success)
        end)
    end)

    describe("Set Variable", function()
        it("should set variable in global scope", function()
            local stored = {}
            local mock_state = {
                set = function(self, name, value)
                    stored[name] = value
                end,
                get_all_variables = function() return {} end
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            local global_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Story Variables" then
                    global_ref = s.variablesReference
                end
            end

            local success = debugger:set_variable("health", 50, global_ref)
            assert.is_true(success)
            assert.equals(50, stored.health)
        end)

        it("should set variable in local scope", function()
            local stored = {}
            local mock_state = {
                set_temp = function(self, name, value)
                    stored[name] = value
                end,
                temp_variables = {}
            }

            local debugger = Debugger.new({ game_state = mock_state })
            local scopes = debugger:get_scopes(1)

            local local_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Local" then
                    local_ref = s.variablesReference
                end
            end

            local success = debugger:set_variable("temp_x", 42, local_ref)
            assert.is_true(success)
            assert.equals(42, stored.temp_x)
        end)
    end)

    describe("Threads", function()
        it("should return single thread", function()
            local debugger = Debugger.new()
            local threads = debugger:get_threads()

            assert.equals(1, #threads)
            assert.equals(1, threads[1].id)
            assert.equals("Main Story", threads[1].name)
        end)
    end)

    describe("Serialization", function()
        it("should serialize debugger state", function()
            local debugger = Debugger.new()
            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger.source_path = "test.wlk"

            local data = debugger:serialize()
            assert.is_not_nil(data)
            assert.is_not_nil(data.breakpoints)
            assert.is_not_nil(data.stepper)
            assert.equals("test.wlk", data.source_path)
        end)

        it("should deserialize debugger state", function()
            local debugger1 = Debugger.new()
            debugger1:set_breakpoint("story.wlk", 10, nil)
            debugger1.source_path = "test.wlk"

            local data = debugger1:serialize()

            local debugger2 = Debugger.new()
            debugger2:deserialize(data)

            assert.equals("test.wlk", debugger2.source_path)
            local bps = debugger2:get_breakpoints()
            assert.equals(1, #bps)
        end)
    end)

    describe("Reset", function()
        it("should reset debugger state", function()
            local debugger = Debugger.new()
            debugger:set_breakpoint("story.wlk", 10, nil)
            debugger:start()

            debugger:reset()

            assert.is_true(debugger.stepper:is_stopped())
            assert.equals(1, debugger.next_ref)
        end)
    end)

    describe("Callbacks", function()
        it("should call on_output for logpoints", function()
            local output_category = nil
            local output_message = nil

            local mock_state = {
                get = function(self, key)
                    if key == "x" then return 42 end
                    return nil
                end
            }

            local debugger = Debugger.new({ game_state = mock_state })
            debugger.on_output = function(category, message)
                output_category = category
                output_message = message
            end

            -- Create a logpoint via breakpoints directly
            debugger.breakpoints:add({
                type = Breakpoints.TYPE_LOGPOINT,
                file = "story.wlk",
                line = 10,
                log_message = "Value: {x}"
            })

            debugger:start()
            debugger:check_breakpoint("story.wlk", 10)

            assert.equals("console", output_category)
            assert.equals("Value: 42", output_message)
        end)
    end)

end)
