-- whisker Client Hooks
-- Provides abstraction layer for client-specific functionality
-- Enables client-agnostic integration through event-driven hooks

local ClientHooks = {}
ClientHooks.__index = ClientHooks

-- Dependencies for DI pattern
ClientHooks._dependencies = { "event_bus" }

--- Create a new ClientHooks instance via DI container
-- @param deps table Dependencies from container
-- @return ClientHooks instance
function ClientHooks.create(deps)
    return ClientHooks.new(deps)
end

--- Create a new ClientHooks instance
-- @param deps table Optional dependencies
-- @return ClientHooks instance
function ClientHooks.new(deps)
    deps = deps or {}
    local self = setmetatable({}, ClientHooks)

    self._event_bus = deps.event_bus

    -- Handler storage
    self._handlers = {
        renderer = nil,
        input = nil,
        audio = nil,
        effect = nil,
        dialog = nil,
        timer = nil,
    }

    -- Handler metadata
    self._handler_info = {}

    return self
end

-- ============================================================================
-- Handler Registration
-- ============================================================================

--- Register a renderer handler
-- @param handler function The render function(content, options) -> rendered_content
-- @param info table Optional handler info (name, version, etc.)
-- @return boolean Success
function ClientHooks:register_renderer(handler, info)
    if type(handler) ~= "function" then
        error("Renderer handler must be a function")
    end
    self._handlers.renderer = handler
    self._handler_info.renderer = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "renderer", info = info })
    return true
end

--- Register an input handler
-- @param handler function The input function(input_type, options) -> result
-- @param info table Optional handler info
-- @return boolean Success
function ClientHooks:register_input_handler(handler, info)
    if type(handler) ~= "function" then
        error("Input handler must be a function")
    end
    self._handlers.input = handler
    self._handler_info.input = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "input", info = info })
    return true
end

--- Register an audio handler
-- @param handler function The audio function(action, resource, options) -> result
-- @param info table Optional handler info
-- @return boolean Success
function ClientHooks:register_audio_handler(handler, info)
    if type(handler) ~= "function" then
        error("Audio handler must be a function")
    end
    self._handlers.audio = handler
    self._handler_info.audio = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "audio", info = info })
    return true
end

--- Register an effect handler
-- @param handler function The effect function(effect_type, target, options) -> result
-- @param info table Optional handler info
-- @return boolean Success
function ClientHooks:register_effect_handler(handler, info)
    if type(handler) ~= "function" then
        error("Effect handler must be a function")
    end
    self._handlers.effect = handler
    self._handler_info.effect = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "effect", info = info })
    return true
end

--- Register a dialog handler
-- @param handler function The dialog function(dialog_type, content, options) -> result
-- @param info table Optional handler info
-- @return boolean Success
function ClientHooks:register_dialog_handler(handler, info)
    if type(handler) ~= "function" then
        error("Dialog handler must be a function")
    end
    self._handlers.dialog = handler
    self._handler_info.dialog = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "dialog", info = info })
    return true
end

--- Register a timer handler
-- @param handler function The timer function(action, duration, callback) -> timer_id
-- @param info table Optional handler info
-- @return boolean Success
function ClientHooks:register_timer_handler(handler, info)
    if type(handler) ~= "function" then
        error("Timer handler must be a function")
    end
    self._handlers.timer = handler
    self._handler_info.timer = info or {}
    self:_emit_event("HANDLER_REGISTERED", { handler_type = "timer", info = info })
    return true
end

--- Unregister a handler
-- @param handler_type string The type of handler to unregister
-- @return boolean Success
function ClientHooks:unregister_handler(handler_type)
    if self._handlers[handler_type] then
        self._handlers[handler_type] = nil
        self._handler_info[handler_type] = nil
        self:_emit_event("HANDLER_UNREGISTERED", { handler_type = handler_type })
        return true
    end
    return false
end

-- ============================================================================
-- Handler Queries
-- ============================================================================

--- Check if a handler is registered
-- @param handler_type string The type of handler
-- @return boolean
function ClientHooks:has_handler(handler_type)
    return self._handlers[handler_type] ~= nil
end

--- Get handler info
-- @param handler_type string The type of handler
-- @return table|nil Handler info or nil
function ClientHooks:get_handler_info(handler_type)
    return self._handler_info[handler_type]
end

--- Get all registered handler types
-- @return table List of registered handler types
function ClientHooks:get_registered_handlers()
    local registered = {}
    for handler_type, handler in pairs(self._handlers) do
        if handler then
            table.insert(registered, handler_type)
        end
    end
    return registered
end

-- ============================================================================
-- Event Emission (Internal Use by Engine/Runtime)
-- ============================================================================

--- Emit a render request
-- @param content string The content to render
-- @param options table Render options (passage_name, tags, etc.)
-- @return any Rendered content or original content if no handler
function ClientHooks:emit_render(content, options)
    options = options or {}

    self:_emit_event("RENDER_REQUESTED", {
        content = content,
        options = options,
    })

    local result = content
    if self._handlers.renderer then
        local success, rendered = pcall(self._handlers.renderer, content, options)
        if success then
            result = rendered
        else
            self:_emit_event("ERROR_OCCURRED", {
                source = "renderer",
                error = rendered,
            })
        end
    end

    self:_emit_event("RENDER_COMPLETE", {
        content = content,
        result = result,
        options = options,
    })

    return result
end

--- Emit an input request
-- @param input_type string Type of input ("text", "choice", "confirm", etc.)
-- @param options table Input options
-- @return any Input result or nil if no handler
function ClientHooks:emit_input_request(input_type, options)
    options = options or {}

    self:_emit_event("INPUT_REQUESTED", {
        input_type = input_type,
        options = options,
    })

    if self._handlers.input then
        local success, result = pcall(self._handlers.input, input_type, options)
        if success then
            self:_emit_event("INPUT_RECEIVED", {
                input_type = input_type,
                result = result,
            })
            return result
        else
            self:_emit_event("ERROR_OCCURRED", {
                source = "input",
                error = result,
            })
            self:_emit_event("INPUT_CANCELLED", {
                input_type = input_type,
                reason = result,
            })
        end
    end

    return nil
end

--- Emit an audio action
-- @param action string Audio action ("play", "stop", "pause", "resume")
-- @param resource string Audio resource identifier
-- @param options table Audio options (volume, loop, etc.)
-- @return any Result from audio handler
function ClientHooks:emit_audio(action, resource, options)
    options = options or {}
    local event_type = "AUDIO_" .. string.upper(action)

    self:_emit_event(event_type, {
        action = action,
        resource = resource,
        options = options,
    })

    if self._handlers.audio then
        local success, result = pcall(self._handlers.audio, action, resource, options)
        if success then
            if action == "play" then
                -- For play, we might emit a complete event later via callback
            end
            return result
        else
            self:_emit_event("ERROR_OCCURRED", {
                source = "audio",
                action = action,
                error = result,
            })
        end
    end

    return nil
end

--- Emit an effect request
-- @param effect_type string Type of effect ("typewriter", "fade_in", etc.)
-- @param target any Target element/content
-- @param options table Effect options (duration, delay, etc.)
-- @return any Effect result or id
function ClientHooks:emit_effect(effect_type, target, options)
    options = options or {}

    self:_emit_event("EFFECT_START", {
        effect_type = effect_type,
        target = target,
        options = options,
    })

    if self._handlers.effect then
        local success, result = pcall(self._handlers.effect, effect_type, target, options)
        if success then
            self:_emit_event("EFFECT_COMPLETE", {
                effect_type = effect_type,
                result = result,
            })
            return result
        else
            self:_emit_event("EFFECT_CANCELLED", {
                effect_type = effect_type,
                reason = result,
            })
            self:_emit_event("ERROR_OCCURRED", {
                source = "effect",
                effect_type = effect_type,
                error = result,
            })
        end
    end

    return nil
end

--- Emit a dialog request
-- @param dialog_type string Type of dialog ("alert", "confirm", "prompt", "custom")
-- @param content any Dialog content
-- @param options table Dialog options (title, buttons, etc.)
-- @return any Dialog result
function ClientHooks:emit_dialog(dialog_type, content, options)
    options = options or {}

    self:_emit_event("DIALOG_OPEN", {
        dialog_type = dialog_type,
        content = content,
        options = options,
    })

    local result = nil
    if self._handlers.dialog then
        local success, dialog_result = pcall(self._handlers.dialog, dialog_type, content, options)
        if success then
            result = dialog_result
            self:_emit_event("DIALOG_RESPONSE", {
                dialog_type = dialog_type,
                result = result,
            })
        else
            self:_emit_event("ERROR_OCCURRED", {
                source = "dialog",
                dialog_type = dialog_type,
                error = dialog_result,
            })
        end
    end

    self:_emit_event("DIALOG_CLOSE", {
        dialog_type = dialog_type,
        result = result,
    })

    return result
end

--- Emit a timer request
-- @param action string Timer action ("timeout", "interval", "clear")
-- @param duration number Duration in milliseconds
-- @param callback function Callback function for timer
-- @return any Timer ID or result
function ClientHooks:emit_timer(action, duration, callback)
    local event_type = "TIMER_" .. string.upper(action == "timeout" and "CREATED" or
                                                action == "interval" and "CREATED" or
                                                action == "clear" and "CANCELLED" or "CREATED")

    self:_emit_event(event_type, {
        action = action,
        duration = duration,
    })

    if self._handlers.timer then
        local success, result = pcall(self._handlers.timer, action, duration, callback)
        if success then
            return result
        else
            self:_emit_event("ERROR_OCCURRED", {
                source = "timer",
                action = action,
                error = result,
            })
        end
    end

    return nil
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Internal event emission helper
-- @param event_type string The event type
-- @param data table Event data
function ClientHooks:_emit_event(event_type, data)
    if self._event_bus then
        self._event_bus:emit(event_type, data)
    end
end

--- Set event bus (for late binding)
-- @param event_bus EventSystem The event bus instance
function ClientHooks:set_event_bus(event_bus)
    self._event_bus = event_bus
end

return ClientHooks
