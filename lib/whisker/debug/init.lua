-- lib/whisker/debug/init.lua
-- WLS 1.0.0 Debug Module
-- Provides Debug Adapter Protocol support for VS Code integration

local Breakpoints = require("lib.whisker.debug.breakpoints")
local Stepper = require("lib.whisker.debug.stepper")
local Debugger = require("lib.whisker.debug.debugger")
local DAPServer = require("lib.whisker.debug.dap_server")

return {
    -- Core classes
    Breakpoints = Breakpoints,
    Stepper = Stepper,
    Debugger = Debugger,
    DAPServer = DAPServer,

    -- Convenience constructors
    new_breakpoints = Breakpoints.new,
    new_stepper = Stepper.new,
    new_debugger = Debugger.new,
    new_dap_server = DAPServer.new,

    -- Module info
    _VERSION = "1.0.0",
    _DESCRIPTION = "WLS 1.0.0 Debug Adapter Protocol support"
}
