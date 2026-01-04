--- Text Effects Manager for WLS 2.0
--- Provides text presentation effects and transitions
--- @module whisker.wls2.text_effects

local TextEffects = {
    _VERSION = "2.0.0"
}
TextEffects.__index = TextEffects
TextEffects._dependencies = {}

--- Built-in effect definitions
local BUILTIN_EFFECTS = {
    typewriter = {
        type = "progressive",
        defaultOptions = { speed = 50 }  -- ms per character
    },
    shake = {
        type = "animation",
        defaultOptions = { duration = 500, intensity = 5 }
    },
    pulse = {
        type = "animation",
        defaultOptions = { duration = 1000 }
    },
    glitch = {
        type = "animation",
        defaultOptions = { duration = 500, intensity = 3 }
    },
    ["fade-in"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    },
    ["fade-out"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    },
    ["slide-left"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    },
    ["slide-right"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    },
    ["slide-up"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    },
    ["slide-down"] = {
        type = "transition",
        defaultOptions = { duration = 500 }
    }
}

--- CSS keyframes for web platform effects
TextEffects.EFFECT_CSS = [[
@keyframes wls-shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-5px); }
  75% { transform: translateX(5px); }
}

@keyframes wls-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

@keyframes wls-glitch {
  0%, 100% { transform: translate(0); filter: none; }
  20% { transform: translate(-2px, 2px); filter: hue-rotate(90deg); }
  40% { transform: translate(2px, -2px); filter: hue-rotate(180deg); }
  60% { transform: translate(-1px, -1px); filter: hue-rotate(270deg); }
  80% { transform: translate(1px, 1px); filter: hue-rotate(360deg); }
}

@keyframes wls-fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes wls-fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes wls-slide-left {
  from { transform: translateX(100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@keyframes wls-slide-right {
  from { transform: translateX(-100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@keyframes wls-slide-up {
  from { transform: translateY(100%); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes wls-slide-down {
  from { transform: translateY(-100%); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

.wls-effect-shake { animation: wls-shake 0.5s ease-in-out; }
.wls-effect-pulse { animation: wls-pulse 1s ease-in-out infinite; }
.wls-effect-glitch { animation: wls-glitch 0.5s ease-in-out; }
.wls-effect-fade-in { animation: wls-fade-in 0.5s ease-out forwards; }
.wls-effect-fade-out { animation: wls-fade-out 0.5s ease-out forwards; }
.wls-effect-slide-left { animation: wls-slide-left 0.5s ease-out forwards; }
.wls-effect-slide-right { animation: wls-slide-right 0.5s ease-out forwards; }
.wls-effect-slide-up { animation: wls-slide-up 0.5s ease-out forwards; }
.wls-effect-slide-down { animation: wls-slide-down 0.5s ease-out forwards; }
]]

--- Parse an effect declaration string
--- @param declaration string The declaration (e.g., "typewriter speed:100")
--- @return table Parsed effect with name and options
function TextEffects.parseEffectDeclaration(declaration)
    if type(declaration) ~= "string" or declaration == "" then
        error("Declaration must be a non-empty string")
    end

    local parts = {}
    for part in declaration:gmatch("%S+") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        error("Invalid declaration format: " .. declaration)
    end

    local name = parts[1]
    local options = {}

    -- Parse remaining parts as options or duration
    for i = 2, #parts do
        local part = parts[i]

        -- Check for key:value format
        local key, value = part:match("^([%w_]+):(.+)$")
        if key and value then
            -- Try to convert to number
            local num = tonumber(value)
            if num then
                options[key] = num
            elseif value == "true" then
                options[key] = true
            elseif value == "false" then
                options[key] = false
            else
                options[key] = value
            end
        else
            -- Check for time string (e.g., "500ms", "1s")
            local time_ms = TextEffects.parseTimeString(part)
            if time_ms then
                options.duration = time_ms
            end
        end
    end

    return {
        name = name,
        options = options
    }
end

--- Parse a time string to milliseconds
--- @param timeStr string Time string (e.g., "500ms", "2s", "1m")
--- @return number|nil Milliseconds or nil if invalid
function TextEffects.parseTimeString(timeStr)
    if type(timeStr) ~= "string" then
        return nil
    end

    local num, unit = timeStr:match("^([%d.]+)(%a+)$")
    if not num then
        -- Try plain number (assume ms)
        num = tonumber(timeStr)
        return num
    end

    num = tonumber(num)
    if not num then
        return nil
    end

    local multipliers = {
        ms = 1,
        s = 1000,
        m = 60000,
        h = 3600000
    }

    local mult = multipliers[unit]
    if mult then
        return num * mult
    end

    return nil
end

--- Create a new TextEffects manager
--- @param deps table Optional dependencies
--- @return TextEffects The new manager instance
function TextEffects.new(deps)
    local self = setmetatable({}, TextEffects)
    self._customEffects = {}
    self._activeControllers = {}
    self._deps = deps or {}
    return self
end

--- Register a custom effect
--- @param name string The effect name
--- @param definition table Effect definition with type and handler
function TextEffects:registerEffect(name, definition)
    if type(name) ~= "string" or name == "" then
        error("Effect name must be a non-empty string")
    end
    if type(definition) ~= "table" then
        error("Effect definition must be a table")
    end

    self._customEffects[name] = definition
end

--- Get effect definition (builtin or custom)
--- @param name string The effect name
--- @return table|nil The effect definition
function TextEffects:getEffect(name)
    return self._customEffects[name] or BUILTIN_EFFECTS[name]
end

--- Check if an effect exists
--- @param name string The effect name
--- @return boolean True if effect exists
function TextEffects:hasEffect(name)
    return self:getEffect(name) ~= nil
end

--- Apply an effect to text
--- @param effectName string The effect name
--- @param text string The text to apply effect to
--- @param options table Effect options
--- @param onFrame function Callback for each animation frame
--- @param onComplete function Callback when effect completes
--- @return table Controller with pause/resume/skip methods
function TextEffects:applyEffect(effectName, text, options, onFrame, onComplete)
    local effect = self:getEffect(effectName)
    if not effect then
        error("Unknown effect: " .. effectName)
    end

    options = options or {}

    -- Merge with default options
    if effect.defaultOptions then
        for k, v in pairs(effect.defaultOptions) do
            if options[k] == nil then
                options[k] = v
            end
        end
    end

    -- Create controller
    local controller = {
        _paused = false,
        _cancelled = false,
        _completed = false,
        _elapsed = 0
    }

    function controller:pause()
        self._paused = true
    end

    function controller:resume()
        self._paused = false
    end

    function controller:skip()
        self._cancelled = true
        if onFrame then
            onFrame({
                visibleText = text,
                progress = 1.0,
                elapsed = options.duration or 0
            })
        end
        if onComplete and not self._completed then
            self._completed = true
            onComplete()
        end
    end

    function controller:isPaused()
        return self._paused
    end

    function controller:isComplete()
        return self._completed or self._cancelled
    end

    -- Generate an ID for the controller
    local controllerId = tostring(controller):match("table: (.+)")
    self._activeControllers[controllerId] = controller

    -- Handle different effect types
    if effect.type == "progressive" then
        -- Typewriter-style effect - reveal characters over time
        self:_runProgressiveEffect(controller, text, options, onFrame, onComplete, controllerId)
    elseif effect.type == "animation" or effect.type == "transition" then
        -- Animation/transition - report progress over duration
        self:_runTimedEffect(controller, text, options, onFrame, onComplete, controllerId)
    else
        -- Unknown type - just complete immediately
        if onFrame then
            onFrame({
                visibleText = text,
                progress = 1.0,
                elapsed = 0
            })
        end
        if onComplete then
            controller._completed = true
            onComplete()
        end
    end

    return controller
end

--- Run a progressive (typewriter-style) effect
--- @private
function TextEffects:_runProgressiveEffect(controller, text, options, onFrame, onComplete, controllerId)
    local charIndex = 0
    local totalChars = #text
    local speed = options.speed or 50

    -- This would use a timer in a real runtime
    -- For now, we'll provide initial frame and require tick() calls
    controller._charIndex = 0
    controller._totalChars = totalChars
    controller._text = text
    controller._speed = speed

    -- Initial frame
    if onFrame then
        onFrame({
            visibleText = "",
            progress = 0,
            elapsed = 0
        })
    end

    -- Tick function for runtime to call
    function controller:tick(deltaMs)
        if self._paused or self._cancelled or self._completed then
            return
        end

        self._elapsed = self._elapsed + deltaMs
        local newIndex = math.floor(self._elapsed / self._speed)

        if newIndex > self._charIndex then
            self._charIndex = math.min(newIndex, self._totalChars)

            if onFrame then
                onFrame({
                    visibleText = self._text:sub(1, self._charIndex),
                    progress = self._charIndex / self._totalChars,
                    elapsed = self._elapsed
                })
            end

            if self._charIndex >= self._totalChars then
                self._completed = true
                if onComplete then
                    onComplete()
                end
            end
        end
    end
end

--- Run a timed (animation/transition) effect
--- @private
function TextEffects:_runTimedEffect(controller, text, options, onFrame, onComplete, controllerId)
    local duration = options.duration or 500

    controller._duration = duration
    controller._text = text

    -- Initial frame
    if onFrame then
        onFrame({
            visibleText = text,
            progress = 0,
            elapsed = 0
        })
    end

    -- Tick function for runtime to call
    function controller:tick(deltaMs)
        if self._paused or self._cancelled or self._completed then
            return
        end

        self._elapsed = self._elapsed + deltaMs
        local progress = math.min(self._elapsed / self._duration, 1.0)

        if onFrame then
            onFrame({
                visibleText = self._text,
                progress = progress,
                elapsed = self._elapsed
            })
        end

        if progress >= 1.0 then
            self._completed = true
            if onComplete then
                onComplete()
            end
        end
    end
end

--- Get all active effect controllers
--- @return table Map of controller IDs to controllers
function TextEffects:getActiveControllers()
    return self._activeControllers
end

--- Cancel all active effects
function TextEffects:cancelAll()
    for id, controller in pairs(self._activeControllers) do
        controller:skip()
    end
    self._activeControllers = {}
end

--- Get list of available effect names
--- @return table Array of effect names
function TextEffects:getAvailableEffects()
    local names = {}

    for name in pairs(BUILTIN_EFFECTS) do
        table.insert(names, name)
    end

    for name in pairs(self._customEffects) do
        table.insert(names, name)
    end

    table.sort(names)
    return names
end

return TextEffects
