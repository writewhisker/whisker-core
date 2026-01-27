-- tests/debug/dap_server_spec.lua
-- Tests for WLS 1.0.0 GAP-055: DAP Server

local DAPServer = require("lib.whisker.debug.dap_server")
local Debugger = require("lib.whisker.debug.debugger")

describe("DAPServer", function()

    describe("DAPServer.new()", function()
        it("should create a new DAPServer instance", function()
            local server = DAPServer.new()
            assert.is_not_nil(server)
            assert.is_not_nil(server.debugger)
            assert.equals(0, server.seq)
            assert.is_false(server.initialized)
        end)

        it("should accept a custom debugger", function()
            local debugger = Debugger.new()
            local server = DAPServer.new({ debugger = debugger })
            assert.equals(debugger, server.debugger)
        end)
    end)

    describe("Initialize Request", function()
        it("should handle initialize request", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "initialize",
                arguments = {}
            })

            assert.is_not_nil(response)
            assert.is_true(response.success)
            assert.equals("initialize", response.command)
            assert.equals(1, response.request_seq)
            assert.is_true(server.initialized)
        end)

        it("should return capabilities", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "initialize",
                arguments = {}
            })

            assert.is_not_nil(response.body)
            assert.is_true(response.body.supportsConfigurationDoneRequest)
            assert.is_true(response.body.supportsConditionalBreakpoints)
            assert.is_true(response.body.supportsHitConditionalBreakpoints)
            assert.is_true(response.body.supportsEvaluateForHovers)
            assert.is_true(response.body.supportsStepBack)
            assert.is_true(response.body.supportsSetVariable)
            assert.is_true(response.body.supportsRestartRequest)
            assert.is_true(response.body.supportsLogPoints)
        end)
    end)

    describe("Launch Request", function()
        it("should handle launch request", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "launch",
                arguments = {
                    program = "test_story.wlk",
                    stopOnEntry = false
                }
            })

            assert.is_not_nil(response)
            assert.is_true(response.success)
            assert.is_true(server.running)
        end)

        it("should handle stopOnEntry", function()
            local events = {}
            local server = DAPServer.new()
            server.output = function(msg)
                table.insert(events, msg)
            end

            server:handle_message({
                seq = 1,
                type = "request",
                command = "launch",
                arguments = {
                    program = "test_story.wlk",
                    stopOnEntry = true
                }
            })

            -- Should have a stopped event
            local found_stopped = false
            for _, ev in ipairs(events) do
                if ev.event == "stopped" and ev.body.reason == "entry" then
                    found_stopped = true
                end
            end
            assert.is_true(found_stopped)
        end)
    end)

    describe("Set Breakpoints Request", function()
        it("should handle setBreakpoints request", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 10 },
                        { line = 20, condition = "x > 5" }
                    }
                }
            })

            assert.is_not_nil(response)
            assert.is_true(response.success)
            assert.is_not_nil(response.body.breakpoints)
            assert.equals(2, #response.body.breakpoints)

            -- Check first breakpoint
            assert.is_true(response.body.breakpoints[1].verified)
            assert.equals(10, response.body.breakpoints[1].line)

            -- Check second breakpoint
            assert.is_true(response.body.breakpoints[2].verified)
            assert.equals(20, response.body.breakpoints[2].line)
        end)

        it("should handle logpoints", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 10, logMessage = "Reached line 10" }
                    }
                }
            })

            assert.is_true(response.success)
            local bp = server.debugger.breakpoints:get(response.body.breakpoints[1].id)
            assert.equals("logpoint", bp.type)
            assert.equals("Reached line 10", bp.log_message)
        end)

        it("should handle hit conditions", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 10, hitCondition = ">= 5" }
                    }
                }
            })

            assert.is_true(response.success)
            local bp = server.debugger.breakpoints:get(response.body.breakpoints[1].id)
            assert.equals(">= 5", bp.hit_condition)
        end)

        it("should clear previous breakpoints for file", function()
            local server = DAPServer.new()

            -- Set first batch
            server:handle_message({
                seq = 1,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 10 },
                        { line = 20 }
                    }
                }
            })

            -- Set second batch (should replace)
            local response = server:handle_message({
                seq = 2,
                type = "request",
                command = "setBreakpoints",
                arguments = {
                    source = { path = "story.wlk" },
                    breakpoints = {
                        { line = 30 }
                    }
                }
            })

            assert.equals(1, #response.body.breakpoints)
            assert.equals(30, response.body.breakpoints[1].line)

            -- Verify old breakpoints are gone
            local all_bps = server.debugger:get_breakpoints()
            assert.equals(1, #all_bps)
        end)
    end)

    describe("Set Function Breakpoints Request", function()
        it("should handle setFunctionBreakpoints for passages", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "setFunctionBreakpoints",
                arguments = {
                    breakpoints = {
                        { name = "Start" },
                        { name = "End", condition = "visited > 0" }
                    }
                }
            })

            assert.is_not_nil(response)
            assert.is_true(response.success)
            assert.equals(2, #response.body.breakpoints)
        end)
    end)

    describe("Threads Request", function()
        it("should return single thread", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "threads",
                arguments = {}
            })

            assert.is_true(response.success)
            assert.is_not_nil(response.body.threads)
            assert.equals(1, #response.body.threads)
            assert.equals(1, response.body.threads[1].id)
            assert.equals("Main Story", response.body.threads[1].name)
        end)
    end)

    describe("Stack Trace Request", function()
        it("should return stack frames", function()
            local server = DAPServer.new()

            -- Set up mock game state with current passage
            server.debugger.game_state = {
                get_current_passage = function() return "TestPassage" end,
                tunnel_stack = {}
            }

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "stackTrace",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
            assert.is_not_nil(response.body.stackFrames)
            assert.is_number(response.body.totalFrames)
        end)
    end)

    describe("Scopes Request", function()
        it("should return scopes for frame", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "scopes",
                arguments = { frameId = 1 }
            })

            assert.is_true(response.success)
            assert.is_not_nil(response.body.scopes)
            assert.equals(3, #response.body.scopes)

            -- Check scope names
            local scope_names = {}
            for _, scope in ipairs(response.body.scopes) do
                scope_names[scope.name] = true
            end
            assert.is_true(scope_names["Local"])
            assert.is_true(scope_names["Story Variables"])
            assert.is_true(scope_names["Collections"])
        end)
    end)

    describe("Variables Request", function()
        it("should return variables for scope", function()
            local server = DAPServer.new()

            -- Set up mock game state
            server.debugger.game_state = {
                get_all_variables = function()
                    return { health = 100, name = "Hero" }
                end,
                temp_variables = {}
            }

            -- First get scopes
            local scopes_response = server:handle_message({
                seq = 1,
                type = "request",
                command = "scopes",
                arguments = { frameId = 1 }
            })

            -- Find story variables scope
            local story_ref = nil
            for _, scope in ipairs(scopes_response.body.scopes) do
                if scope.name == "Story Variables" then
                    story_ref = scope.variablesReference
                end
            end

            -- Get variables
            local response = server:handle_message({
                seq = 2,
                type = "request",
                command = "variables",
                arguments = { variablesReference = story_ref }
            })

            assert.is_true(response.success)
            assert.is_not_nil(response.body.variables)

            -- Check for our variables
            local var_map = {}
            for _, v in ipairs(response.body.variables) do
                var_map[v.name] = v
            end
            assert.is_not_nil(var_map.health)
            assert.equals("100", var_map.health.value)
        end)
    end)

    describe("Continue Request", function()
        it("should handle continue request", function()
            local server = DAPServer.new()
            server.debugger:start(true)  -- Start paused

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "continue",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
            assert.is_true(response.body.allThreadsContinued)
        end)
    end)

    describe("Step Requests", function()
        it("should handle next (step over) request", function()
            local server = DAPServer.new()
            server.debugger:start(true)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "next",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
        end)

        it("should handle stepIn request", function()
            local server = DAPServer.new()
            server.debugger:start(true)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "stepIn",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
        end)

        it("should handle stepOut request", function()
            local server = DAPServer.new()
            server.debugger:start(true)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "stepOut",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
        end)

        it("should handle stepBack request with history", function()
            local server = DAPServer.new()
            server.debugger.game_state = {
                can_undo = function() return true end,
                undo = function() return true end
            }
            server.debugger:start(true)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "stepBack",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)
        end)

        it("should fail stepBack when no history", function()
            local server = DAPServer.new()
            server.debugger.game_state = {
                can_undo = function() return false end
            }
            server.debugger:start(true)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "stepBack",
                arguments = { threadId = 1 }
            })

            assert.is_false(response.success)
        end)
    end)

    describe("Pause Request", function()
        it("should handle pause request", function()
            local events = {}
            local server = DAPServer.new()
            server.output = function(msg)
                table.insert(events, msg)
            end

            server.debugger:start(false)

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "pause",
                arguments = { threadId = 1 }
            })

            assert.is_true(response.success)

            -- Should emit stopped event
            local found_stopped = false
            for _, ev in ipairs(events) do
                if ev.event == "stopped" and ev.body.reason == "pause" then
                    found_stopped = true
                end
            end
            assert.is_true(found_stopped)
        end)
    end)

    describe("Evaluate Request", function()
        it("should evaluate simple expression", function()
            local server = DAPServer.new()

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "evaluate",
                arguments = {
                    expression = "1 + 2",
                    frameId = 1
                }
            })

            assert.is_true(response.success)
            assert.equals("3", response.body.result)
            assert.equals("number", response.body.type)
        end)

        it("should return table reference for table results", function()
            local server = DAPServer.new()

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "evaluate",
                arguments = {
                    expression = "{a=1, b=2}",
                    frameId = 1
                }
            })

            assert.is_true(response.success)
            assert.equals("table", response.body.type)
            assert.is_true(response.body.variablesReference > 0)
        end)

        it("should return error for invalid expression", function()
            local server = DAPServer.new()

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "evaluate",
                arguments = {
                    expression = "invalid syntax @@@@",
                    frameId = 1
                }
            })

            assert.is_false(response.success)
        end)
    end)

    describe("Set Variable Request", function()
        it("should set variable value", function()
            local server = DAPServer.new()
            local stored_value = nil

            server.debugger.game_state = {
                set = function(self, name, value)
                    stored_value = value
                end,
                get_all_variables = function() return {} end
            }

            -- Get scope reference
            local scopes_response = server:handle_message({
                seq = 1,
                type = "request",
                command = "scopes",
                arguments = { frameId = 1 }
            })

            local global_ref = nil
            for _, scope in ipairs(scopes_response.body.scopes) do
                if scope.name == "Story Variables" then
                    global_ref = scope.variablesReference
                end
            end

            local response = server:handle_message({
                seq = 2,
                type = "request",
                command = "setVariable",
                arguments = {
                    variablesReference = global_ref,
                    name = "health",
                    value = "50"
                }
            })

            assert.is_true(response.success)
            assert.equals("50", response.body.value)
        end)
    end)

    describe("Disconnect Request", function()
        it("should handle disconnect request", function()
            local server = DAPServer.new()
            server.running = true

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "disconnect",
                arguments = {}
            })

            assert.is_true(response.success)
            assert.is_false(server.running)
        end)
    end)

    describe("Restart Request", function()
        it("should handle restart request", function()
            local server = DAPServer.new()
            server.debugger.source_path = "test_story.wlk"

            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "restart",
                arguments = {}
            })

            assert.is_true(response.success)
        end)
    end)

    describe("Configuration Done Request", function()
        it("should handle configurationDone request", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "configurationDone",
                arguments = {}
            })

            assert.is_true(response.success)
        end)
    end)

    describe("Unknown Command", function()
        it("should return error for unknown command", function()
            local server = DAPServer.new()
            local response = server:handle_message({
                seq = 1,
                type = "request",
                command = "unknownCommand",
                arguments = {}
            })

            assert.is_false(response.success)
            assert.is_not_nil(response.message)
        end)
    end)

    describe("Event Queue", function()
        it("should queue and process events", function()
            local events = {}
            local server = DAPServer.new()
            server.output = function(msg)
                table.insert(events, msg)
            end

            -- Initialize queues an initialized event
            server:handle_message({
                seq = 1,
                type = "request",
                command = "initialize",
                arguments = {}
            })

            -- Process queue
            server:process_event_queue()

            -- Should have initialized event
            local found = false
            for _, ev in ipairs(events) do
                if ev.event == "initialized" then
                    found = true
                end
            end
            assert.is_true(found)
        end)
    end)

    describe("Response Sequence Numbers", function()
        it("should increment sequence numbers", function()
            local server = DAPServer.new()

            local response1 = server:handle_message({
                seq = 1,
                type = "request",
                command = "initialize",
                arguments = {}
            })

            local response2 = server:handle_message({
                seq = 2,
                type = "request",
                command = "threads",
                arguments = {}
            })

            assert.is_true(response1.seq < response2.seq)
        end)
    end)

end)
