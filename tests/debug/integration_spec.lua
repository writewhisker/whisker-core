-- tests/debug/integration_spec.lua
-- Integration tests for WLS 1.0.0 Debug Module (GAP-055, GAP-056, GAP-057)

local debug_module = require("lib.whisker.debug.init")
local DAPServer = debug_module.DAPServer
local Debugger = debug_module.Debugger
local Breakpoints = debug_module.Breakpoints
local Stepper = debug_module.Stepper

describe("Debug Module Integration", function()

    describe("Module Loading", function()
        it("should load all components", function()
            assert.is_not_nil(debug_module.Breakpoints)
            assert.is_not_nil(debug_module.Stepper)
            assert.is_not_nil(debug_module.Debugger)
            assert.is_not_nil(debug_module.DAPServer)
        end)

        it("should have convenience constructors", function()
            assert.is_function(debug_module.new_breakpoints)
            assert.is_function(debug_module.new_stepper)
            assert.is_function(debug_module.new_debugger)
            assert.is_function(debug_module.new_dap_server)
        end)

        it("should have version info", function()
            assert.equals("1.0.0", debug_module._VERSION)
        end)
    end)

    describe("Full Debug Session Simulation", function()
        it("should handle a complete debug session via DAP", function()
            -- Simulate a VS Code debug session
            local events = {}
            local server = DAPServer.new()
            server.output = function(msg)
                table.insert(events, msg)
            end

            -- 1. Initialize
            local init_response = server:handle_message({
                seq = 1,
                type = "request",
                command = "initialize",
                arguments = {}
            })
            assert.is_true(init_response.success)
            server:process_event_queue()

            -- Check for initialized event
            local found_initialized = false
            for _, ev in ipairs(events) do
                if ev.event == "initialized" then
                    found_initialized = true
                end
            end
            assert.is_true(found_initialized)

            -- 2. Set breakpoints
            local bp_response = server:handle_message({
                seq = 2,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 10 },
                        { line = 20, condition = "health > 0" },
                        { line = 30, hitCondition = ">= 3" },
                        { line = 40, logMessage = "Reached checkpoint" }
                    }
                }
            })
            assert.is_true(bp_response.success)
            assert.equals(4, #bp_response.body.breakpoints)

            -- 3. Set passage breakpoints
            local func_bp_response = server:handle_message({
                seq = 3,
                type = "request",
                command = "setFunctionBreakpoints",
                arguments = {
                    breakpoints = {
                        { name = "Start" },
                        { name = "Combat" }
                    }
                }
            })
            assert.is_true(func_bp_response.success)
            assert.equals(2, #func_bp_response.body.breakpoints)

            -- 4. Configuration done
            local config_response = server:handle_message({
                seq = 4,
                type = "request",
                command = "configurationDone",
                arguments = {}
            })
            assert.is_true(config_response.success)

            -- 5. Launch
            local launch_response = server:handle_message({
                seq = 5,
                type = "request",
                command = "launch",
                arguments = {
                    program = "test_story.wlk",
                    stopOnEntry = true
                }
            })
            assert.is_true(launch_response.success)

            -- 6. Get threads
            local threads_response = server:handle_message({
                seq = 6,
                type = "request",
                command = "threads",
                arguments = {}
            })
            assert.is_true(threads_response.success)
            assert.equals(1, #threads_response.body.threads)

            -- 7. Continue
            local continue_response = server:handle_message({
                seq = 7,
                type = "request",
                command = "continue",
                arguments = { threadId = 1 }
            })
            assert.is_true(continue_response.success)

            -- 8. Pause
            local pause_response = server:handle_message({
                seq = 8,
                type = "request",
                command = "pause",
                arguments = { threadId = 1 }
            })
            assert.is_true(pause_response.success)

            -- 9. Get scopes
            local scopes_response = server:handle_message({
                seq = 9,
                type = "request",
                command = "scopes",
                arguments = { frameId = 1 }
            })
            assert.is_true(scopes_response.success)
            assert.is_true(#scopes_response.body.scopes >= 1)

            -- 10. Step commands
            local next_response = server:handle_message({
                seq = 10,
                type = "request",
                command = "next",
                arguments = { threadId = 1 }
            })
            assert.is_true(next_response.success)

            local stepin_response = server:handle_message({
                seq = 11,
                type = "request",
                command = "stepIn",
                arguments = { threadId = 1 }
            })
            assert.is_true(stepin_response.success)

            local stepout_response = server:handle_message({
                seq = 12,
                type = "request",
                command = "stepOut",
                arguments = { threadId = 1 }
            })
            assert.is_true(stepout_response.success)

            -- 11. Evaluate expression
            local eval_response = server:handle_message({
                seq = 13,
                type = "request",
                command = "evaluate",
                arguments = {
                    expression = "1 + 2 + 3",
                    frameId = 1
                }
            })
            assert.is_true(eval_response.success)
            assert.equals("6", eval_response.body.result)

            -- 12. Disconnect
            local disconnect_response = server:handle_message({
                seq = 14,
                type = "request",
                command = "disconnect",
                arguments = {}
            })
            assert.is_true(disconnect_response.success)
        end)
    end)

    describe("Breakpoint and Stepper Integration", function()
        it("should pause at breakpoint and step through", function()
            local debugger = Debugger.new()
            local pause_reasons = {}

            debugger.on_stopped = function(reason, details)
                table.insert(pause_reasons, reason)
            end

            -- Set up mock game state
            debugger.game_state = {
                get_current_passage = function() return "TestPassage" end,
                get_all_variables = function() return { x = 10 } end,
                temp_variables = {},
                tunnel_stack = {}
            }

            -- Set breakpoint
            debugger:set_breakpoint("story.wlk", 10)

            -- Start and hit breakpoint
            debugger:start()
            debugger:check_breakpoint("story.wlk", 10)

            assert.equals(1, #pause_reasons)
            assert.equals("breakpoint", pause_reasons[1])
            assert.is_true(debugger:is_paused())

            -- Step over
            debugger:next()
            assert.equals(Stepper.MODE_STEP_OVER, debugger.stepper:get_mode())

            -- Step into
            debugger:step_in()
            assert.equals(Stepper.MODE_STEP_INTO, debugger.stepper:get_mode())

            -- Step out
            debugger:step_out()
            assert.equals(Stepper.MODE_STEP_OUT, debugger.stepper:get_mode())

            -- Continue
            debugger:continue()
            assert.equals(Stepper.MODE_CONTINUE, debugger.stepper:get_mode())
        end)
    end)

    describe("Variable Inspection Integration", function()
        it("should inspect all variable scopes", function()
            local debugger = Debugger.new()

            -- Set up comprehensive mock game state
            debugger.game_state = {
                get_all_variables = function()
                    return {
                        health = 100,
                        name = "Hero",
                        inventory = { "sword", "shield" }
                    }
                end,
                temp_variables = {
                    loop_counter = 5,
                    temp_flag = true
                },
                lists = {
                    Traits = { values = {"Brave", "Smart", "Strong"}, active = {Brave = true} }
                },
                arrays = {
                    Scores = {10, 20, 30}
                },
                maps = {
                    Stats = { strength = 10, agility = 8 }
                }
            }

            -- Get scopes
            local scopes = debugger:get_scopes(1)
            assert.equals(3, #scopes)

            -- Get story variables
            local story_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Story Variables" then
                    story_ref = s.variablesReference
                end
            end
            local story_vars = debugger:get_variables(story_ref)
            assert.is_not_nil(story_vars.health)
            assert.equals(100, story_vars.health.value)
            assert.is_not_nil(story_vars.inventory)
            assert.is_true(story_vars.inventory.has_children)

            -- Get local/temp variables
            local local_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Local" then
                    local_ref = s.variablesReference
                end
            end
            local local_vars = debugger:get_variables(local_ref)
            assert.is_not_nil(local_vars.loop_counter)
            assert.equals(5, local_vars.loop_counter.value)

            -- Get collections
            local coll_ref = nil
            for _, s in ipairs(scopes) do
                if s.name == "Collections" then
                    coll_ref = s.variablesReference
                end
            end
            local coll_vars = debugger:get_variables(coll_ref)
            assert.is_not_nil(coll_vars["LIST:Traits"])
            assert.is_not_nil(coll_vars["ARRAY:Scores"])
            assert.is_not_nil(coll_vars["MAP:Stats"])
        end)
    end)

    describe("Conditional and Hit Count Breakpoints", function()
        it("should evaluate conditional breakpoints correctly", function()
            local bp_manager = Breakpoints.new()

            -- Create conditional breakpoint
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                condition = "5 > 3"  -- Always true
            })

            local result = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result)
            assert.equals("break", result.type)

            -- False condition should not trigger
            bp_manager:add({
                file = "story.wlk",
                line = 20,
                condition = "5 < 3"  -- Always false
            })

            local result2 = bp_manager:check_line("story.wlk", 20, {})
            assert.is_nil(result2)
        end)

        it("should track and evaluate hit count breakpoints", function()
            local bp_manager = Breakpoints.new()

            -- Break on every 5th hit
            bp_manager:add({
                file = "story.wlk",
                line = 10,
                hit_condition = "% 5 == 0"
            })

            -- Hits 1-4 should not trigger
            for i = 1, 4 do
                local result = bp_manager:check_line("story.wlk", 10, {})
                assert.is_nil(result, "Hit " .. i .. " should not trigger")
            end

            -- Hit 5 should trigger
            local result5 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result5, "Hit 5 should trigger")

            -- Hits 6-9 should not trigger
            for i = 6, 9 do
                local result = bp_manager:check_line("story.wlk", 10, {})
                assert.is_nil(result, "Hit " .. i .. " should not trigger")
            end

            -- Hit 10 should trigger
            local result10 = bp_manager:check_line("story.wlk", 10, {})
            assert.is_not_nil(result10, "Hit 10 should trigger")
        end)
    end)

    describe("Logpoints Integration", function()
        it("should format and emit logpoint messages", function()
            local log_messages = {}

            local debugger = Debugger.new()
            debugger.on_output = function(category, message)
                table.insert(log_messages, { category = category, message = message })
            end

            debugger.game_state = {
                get = function(self, key)
                    if key == "playerName" then return "Hero" end
                    if key == "level" then return 5 end
                    return nil
                end
            }

            -- Create logpoint
            debugger.breakpoints:add({
                type = Breakpoints.TYPE_LOGPOINT,
                file = "story.wlk",
                line = 10,
                log_message = "Player {playerName} reached level {level}"
            })

            debugger:start()
            debugger:check_breakpoint("story.wlk", 10)

            assert.equals(1, #log_messages)
            assert.equals("console", log_messages[1].category)
            assert.equals("Player Hero reached level 5", log_messages[1].message)
        end)
    end)

    describe("Step Back Integration", function()
        it("should step back using game state undo", function()
            local undo_called = false
            local debugger = Debugger.new()

            debugger.game_state = {
                can_undo = function() return true end,
                undo = function()
                    undo_called = true
                end
            }

            debugger:start()
            local success = debugger:step_back()

            assert.is_true(success)
            assert.is_true(undo_called)
            assert.is_true(debugger:is_paused())
        end)
    end)

    describe("Serialization Round-Trip", function()
        it("should serialize and restore debugger state", function()
            -- Create and configure debugger
            local debugger1 = Debugger.new()
            debugger1:set_breakpoint("story.wlk", 10)
            debugger1:set_breakpoint("story.wlk", 20)
            debugger1:set_passage_breakpoint("Start")
            debugger1.source_path = "my_story.wlk"

            -- Serialize
            local data = debugger1:serialize()
            assert.is_not_nil(data)

            -- Create new debugger and restore
            local debugger2 = Debugger.new()
            debugger2:deserialize(data)

            -- Verify state restored
            assert.equals("my_story.wlk", debugger2.source_path)
            local bps = debugger2:get_breakpoints()
            assert.equals(3, #bps)

            -- Verify breakpoints work
            debugger2:start()
            local hit = debugger2:check_breakpoint("story.wlk", 10)
            assert.is_true(hit)
        end)
    end)

end)
