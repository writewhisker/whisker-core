--- WLS 2.0 Module for Whisker
--- Provides advanced features for interactive narrative authoring
--- @module whisker.wls2

local WLS2 = {
    _VERSION = "2.0.0",
    _DESCRIPTION = "WLS 2.0 features for Whisker"
}

-- Lazy-load submodules to avoid circular dependencies
local _modules = {}

local function lazy_require(name)
    if not _modules[name] then
        _modules[name] = require("whisker.wls2." .. name)
    end
    return _modules[name]
end

--- Thread Scheduler - parallel narrative execution
--- @return ThreadScheduler
function WLS2.ThreadScheduler()
    return lazy_require("thread_scheduler")
end

--- LIST State Machine - state machine operations on LISTs
--- @return ListStateMachine
function WLS2.ListStateMachine()
    return lazy_require("list_state_machine")
end

--- Timed Content - delayed and scheduled content delivery
--- @return TimedContent
function WLS2.TimedContent()
    return lazy_require("timed_content")
end

--- External Functions - host application function binding
--- @return ExternalFunctions
function WLS2.ExternalFunctions()
    return lazy_require("external_functions")
end

--- Audio Effects - audio management with fade effects
--- @return AudioEffects
function WLS2.AudioEffects()
    return lazy_require("audio_effects")
end

--- Text Effects - text presentation effects and transitions
--- @return TextEffects
function WLS2.TextEffects()
    return lazy_require("text_effects")
end

--- Parameterized Passages - reusable passages with parameters
--- @return ParameterizedPassages
function WLS2.ParameterizedPassages()
    return lazy_require("parameterized_passages")
end

-- Convenience aliases for direct module access
WLS2.threads = WLS2.ThreadScheduler
WLS2.lists = WLS2.ListStateMachine
WLS2.timed = WLS2.TimedContent
WLS2.external = WLS2.ExternalFunctions
WLS2.audio = WLS2.AudioEffects
WLS2.effects = WLS2.TextEffects
WLS2.passages = WLS2.ParameterizedPassages

--- Create instances of all WLS 2.0 managers
--- @param deps table Optional shared dependencies
--- @return table Map of manager instances
function WLS2.createManagers(deps)
    deps = deps or {}

    return {
        threads = WLS2.ThreadScheduler().new(deps),
        lists = WLS2.ListStateMachine().new(deps),
        timed = WLS2.TimedContent().new(deps),
        external = WLS2.ExternalFunctions().new(deps),
        audio = WLS2.AudioEffects().new({}, deps),
        effects = WLS2.TextEffects().new(deps),
        passages = WLS2.ParameterizedPassages().new(deps)
    }
end

--- Register WLS 2.0 services with a DI container
--- @param container table DI container
--- @param events table Event bus
--- @param options table Options
function WLS2.register(container, events, options)
    options = options or {}

    -- Thread Scheduler
    container:register("wls2_thread_scheduler", function(c)
        local ThreadScheduler = WLS2.ThreadScheduler()
        return ThreadScheduler.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "IThreadScheduler"
    })

    -- LIST State Machine
    container:register("wls2_list_state_machine", function(c)
        local ListStateMachine = WLS2.ListStateMachine()
        return ListStateMachine.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "IListStateMachine"
    })

    -- Timed Content
    container:register("wls2_timed_content", function(c)
        local TimedContent = WLS2.TimedContent()
        return TimedContent.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "ITimedContent"
    })

    -- External Functions
    container:register("wls2_external_functions", function(c)
        local ExternalFunctions = WLS2.ExternalFunctions()
        return ExternalFunctions.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "IExternalFunctions"
    })

    -- Audio Effects
    container:register("wls2_audio_effects", function(c)
        local AudioEffects = WLS2.AudioEffects()
        return AudioEffects.new({}, {
            audio_backend = c:resolve("audio_backend", { optional = true }),
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "IAudioEffects",
        depends = {"audio_backend"}
    })

    -- Text Effects
    container:register("wls2_text_effects", function(c)
        local TextEffects = WLS2.TextEffects()
        return TextEffects.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "ITextEffects"
    })

    -- Parameterized Passages
    container:register("wls2_parameterized_passages", function(c)
        local ParameterizedPassages = WLS2.ParameterizedPassages()
        return ParameterizedPassages.new({
            event_bus = c:resolve("events")
        })
    end, {
        singleton = true,
        implements = "IParameterizedPassages"
    })

    -- Emit registration event
    if events and events.emit then
        events:emit("wls2:registered", {
            services = {
                "wls2_thread_scheduler",
                "wls2_list_state_machine",
                "wls2_timed_content",
                "wls2_external_functions",
                "wls2_audio_effects",
                "wls2_text_effects",
                "wls2_parameterized_passages"
            }
        })
    end
end

return WLS2
