--- Timed Content Manager for WLS 2.0
--- Manages delayed and scheduled content delivery
--- @module whisker.wls2.timed_content

local TimedContent = {
    _VERSION = "2.0.0"
}
TimedContent.__index = TimedContent
TimedContent._dependencies = {}

--- Timer states
TimedContent.STATE = {
    PENDING = "pending",
    RUNNING = "running",
    PAUSED = "paused",
    COMPLETED = "completed",
    CANCELLED = "cancelled"
}

--- Generate a unique timer ID
local _timer_counter = 0
local function generate_timer_id()
    _timer_counter = _timer_counter + 1
    return "timer_" .. _timer_counter
end

--- Parse a time string to milliseconds
--- @param timeStr string|number Time string (e.g., "500ms", "2s") or number
--- @return number Milliseconds
function TimedContent.parseTimeString(timeStr)
    if type(timeStr) == "number" then
        return timeStr
    end

    if type(timeStr) ~= "string" then
        error("Time must be a string or number")
    end

    local num, unit = timeStr:match("^([%d.]+)(%a+)$")
    if not num then
        -- Try plain number
        num = tonumber(timeStr)
        if num then
            return num
        end
        error("Invalid time string: " .. timeStr)
    end

    num = tonumber(num)
    if not num then
        error("Invalid time value: " .. timeStr)
    end

    local multipliers = {
        ms = 1,
        s = 1000,
        m = 60000,
        h = 3600000
    }

    local mult = multipliers[unit]
    if not mult then
        error("Unknown time unit: " .. unit)
    end

    return num * mult
end

--- Create a new TimedContent manager
--- @param deps table Optional dependencies
--- @return TimedContent The new manager instance
function TimedContent.new(deps)
    local self = setmetatable({}, TimedContent)
    self._timers = {}        -- id -> timer
    self._elapsed = 0        -- Total elapsed time
    self._paused = false     -- Global pause state
    self._deps = deps or {}
    return self
end

--- Create a factory function for DI
--- @param deps table Dependencies
--- @return function Factory function
function TimedContent.create(deps)
    return function(config)
        return TimedContent.new(deps)
    end
end

--- Schedule one-shot content delivery
--- @param delay number|string Delay in ms or time string
--- @param content table Content to deliver
--- @param callback function|nil Callback when timer fires
--- @return string Timer ID
function TimedContent:schedule(delay, content, callback)
    local delay_ms = TimedContent.parseTimeString(delay)

    local timer = {
        id = generate_timer_id(),
        type = "oneshot",
        delay = delay_ms,
        elapsed = 0,
        content = content,
        callback = callback,
        state = TimedContent.STATE.PENDING,
        createdAt = self._elapsed
    }

    self._timers[timer.id] = timer
    return timer.id
end

--- Schedule repeating content delivery
--- @param interval number|string Interval in ms or time string
--- @param content table Content to deliver
--- @param maxFires number|nil Maximum number of fires (nil = unlimited)
--- @param callback function|nil Callback when timer fires
--- @return string Timer ID
function TimedContent:every(interval, content, maxFires, callback)
    local interval_ms = TimedContent.parseTimeString(interval)

    local timer = {
        id = generate_timer_id(),
        type = "repeating",
        interval = interval_ms,
        elapsed = 0,
        content = content,
        callback = callback,
        state = TimedContent.STATE.PENDING,
        maxFires = maxFires,
        fireCount = 0,
        createdAt = self._elapsed
    }

    self._timers[timer.id] = timer
    return timer.id
end

--- Cancel a timer
--- @param timerId string Timer ID
function TimedContent:cancel(timerId)
    local timer = self._timers[timerId]
    if timer then
        timer.state = TimedContent.STATE.CANCELLED
    end
end

--- Pause a specific timer
--- @param timerId string Timer ID
function TimedContent:pauseTimer(timerId)
    local timer = self._timers[timerId]
    if timer and timer.state ~= TimedContent.STATE.COMPLETED and
       timer.state ~= TimedContent.STATE.CANCELLED then
        timer.state = TimedContent.STATE.PAUSED
    end
end

--- Resume a specific timer
--- @param timerId string Timer ID
function TimedContent:resumeTimer(timerId)
    local timer = self._timers[timerId]
    if timer and timer.state == TimedContent.STATE.PAUSED then
        timer.state = TimedContent.STATE.RUNNING
    end
end

--- Pause all timers
function TimedContent:pause()
    self._paused = true
end

--- Resume all timers
function TimedContent:resume()
    self._paused = false
end

--- Check if globally paused
--- @return boolean True if paused
function TimedContent:isPaused()
    return self._paused
end

--- Update timers with elapsed time
--- @param deltaMs number Milliseconds since last update
--- @return table Array of {timerId, content} for fired timers
function TimedContent:update(deltaMs)
    if self._paused then
        return {}
    end

    self._elapsed = self._elapsed + deltaMs
    local fired = {}

    for id, timer in pairs(self._timers) do
        if timer.state == TimedContent.STATE.PENDING then
            timer.state = TimedContent.STATE.RUNNING
        end

        if timer.state == TimedContent.STATE.RUNNING then
            timer.elapsed = timer.elapsed + deltaMs

            if timer.type == "oneshot" then
                if timer.elapsed >= timer.delay then
                    -- Fire oneshot timer
                    table.insert(fired, {
                        timerId = id,
                        content = timer.content
                    })

                    if timer.callback then
                        timer.callback(timer.content)
                    end

                    timer.state = TimedContent.STATE.COMPLETED
                end
            elseif timer.type == "repeating" then
                -- Check if interval has passed
                while timer.elapsed >= timer.interval do
                    timer.elapsed = timer.elapsed - timer.interval
                    timer.fireCount = timer.fireCount + 1

                    table.insert(fired, {
                        timerId = id,
                        content = timer.content,
                        fireCount = timer.fireCount
                    })

                    if timer.callback then
                        timer.callback(timer.content, timer.fireCount)
                    end

                    -- Check max fires
                    if timer.maxFires and timer.fireCount >= timer.maxFires then
                        timer.state = TimedContent.STATE.COMPLETED
                        break
                    end
                end
            end
        end
    end

    return fired
end

--- Get a timer by ID
--- @param timerId string Timer ID
--- @return table|nil Timer object or nil
function TimedContent:getTimer(timerId)
    return self._timers[timerId]
end

--- Get all active timers
--- @return table Array of active timers
function TimedContent:getActiveTimers()
    local active = {}
    for _, timer in pairs(self._timers) do
        if timer.state == TimedContent.STATE.PENDING or
           timer.state == TimedContent.STATE.RUNNING or
           timer.state == TimedContent.STATE.PAUSED then
            table.insert(active, timer)
        end
    end
    return active
end

--- Get count of timers by state
--- @return table Map of state -> count
function TimedContent:getTimerCounts()
    local counts = {}
    for state in pairs(TimedContent.STATE) do
        counts[TimedContent.STATE[state]] = 0
    end

    for _, timer in pairs(self._timers) do
        counts[timer.state] = (counts[timer.state] or 0) + 1
    end

    return counts
end

--- Get total elapsed time
--- @return number Elapsed milliseconds
function TimedContent:getElapsed()
    return self._elapsed
end

--- Cancel all timers
function TimedContent:cancelAll()
    for id in pairs(self._timers) do
        self:cancel(id)
    end
end

--- Clear all timers
function TimedContent:clear()
    self._timers = {}
    self._elapsed = 0
    self._paused = false
end

return TimedContent
