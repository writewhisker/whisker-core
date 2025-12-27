-- whisker Async Event
-- Promise-like pattern using Lua coroutines for async operations
-- Enables non-blocking operations in client-agnostic architecture

local AsyncEvent = {}
AsyncEvent.__index = AsyncEvent

-- State constants
AsyncEvent.STATE = {
    PENDING = "pending",
    RESOLVED = "resolved",
    REJECTED = "rejected",
}

--- Create a new AsyncEvent
-- @param event_type string Optional event type identifier
-- @return AsyncEvent instance
function AsyncEvent.new(event_type)
    local self = setmetatable({}, AsyncEvent)

    self.event_type = event_type or "async"
    self.state = AsyncEvent.STATE.PENDING
    self.result = nil
    self.error = nil

    self._then_callbacks = {}
    self._catch_callbacks = {}
    self._finally_callbacks = {}
    self._waiting_coroutine = nil

    return self
end

-- ============================================================================
-- Promise-like Interface
-- ============================================================================

--- Register a callback for when the event resolves
-- @param callback function Callback function(result)
-- @return AsyncEvent self for chaining
function AsyncEvent:then_do(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end

    if self.state == AsyncEvent.STATE.RESOLVED then
        -- Already resolved, call immediately
        local success, err = pcall(callback, self.result)
        if not success then
            -- If callback throws, don't propagate here
            -- Could emit to error handler
        end
    elseif self.state == AsyncEvent.STATE.PENDING then
        table.insert(self._then_callbacks, callback)
    end
    -- If rejected, don't call then callbacks

    return self
end

--- Register a callback for when the event rejects
-- @param error_handler function Error handler function(error)
-- @return AsyncEvent self for chaining
function AsyncEvent:catch(error_handler)
    if type(error_handler) ~= "function" then
        error("Error handler must be a function")
    end

    if self.state == AsyncEvent.STATE.REJECTED then
        -- Already rejected, call immediately
        pcall(error_handler, self.error)
    elseif self.state == AsyncEvent.STATE.PENDING then
        table.insert(self._catch_callbacks, error_handler)
    end

    return self
end

--- Register a callback that runs regardless of outcome
-- @param callback function Callback function()
-- @return AsyncEvent self for chaining
function AsyncEvent:finally(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end

    if self.state ~= AsyncEvent.STATE.PENDING then
        -- Already settled, call immediately
        pcall(callback)
    else
        table.insert(self._finally_callbacks, callback)
    end

    return self
end

--- Resolve the event with a result
-- @param result any The result value
-- @return AsyncEvent self
function AsyncEvent:resolve(result)
    if self.state ~= AsyncEvent.STATE.PENDING then
        -- Already settled, ignore
        return self
    end

    self.state = AsyncEvent.STATE.RESOLVED
    self.result = result

    -- Call then callbacks
    for _, callback in ipairs(self._then_callbacks) do
        pcall(callback, result)
    end

    -- Call finally callbacks
    for _, callback in ipairs(self._finally_callbacks) do
        pcall(callback)
    end

    -- Resume waiting coroutine if any
    if self._waiting_coroutine then
        local co = self._waiting_coroutine
        self._waiting_coroutine = nil
        coroutine.resume(co, result, nil)
    end

    return self
end

--- Reject the event with an error
-- @param err any The error value
-- @return AsyncEvent self
function AsyncEvent:reject(err)
    if self.state ~= AsyncEvent.STATE.PENDING then
        -- Already settled, ignore
        return self
    end

    self.state = AsyncEvent.STATE.REJECTED
    self.error = err

    -- Call catch callbacks
    for _, handler in ipairs(self._catch_callbacks) do
        pcall(handler, err)
    end

    -- Call finally callbacks
    for _, callback in ipairs(self._finally_callbacks) do
        pcall(callback)
    end

    -- Resume waiting coroutine if any
    if self._waiting_coroutine then
        local co = self._waiting_coroutine
        self._waiting_coroutine = nil
        coroutine.resume(co, nil, err)
    end

    return self
end

--- Block until the event is settled (must be called from a coroutine)
-- @return any, any Result and error (result is nil if rejected, error is nil if resolved)
function AsyncEvent:await()
    if self.state == AsyncEvent.STATE.RESOLVED then
        return self.result, nil
    elseif self.state == AsyncEvent.STATE.REJECTED then
        return nil, self.error
    end

    -- Must be in a coroutine
    local co = coroutine.running()
    if not co then
        error("await() must be called from within a coroutine")
    end

    -- Store the coroutine to resume later
    self._waiting_coroutine = co

    -- Yield and wait for resolve/reject
    return coroutine.yield()
end

-- ============================================================================
-- State Queries
-- ============================================================================

--- Check if event is pending
-- @return boolean
function AsyncEvent:is_pending()
    return self.state == AsyncEvent.STATE.PENDING
end

--- Check if event is resolved
-- @return boolean
function AsyncEvent:is_resolved()
    return self.state == AsyncEvent.STATE.RESOLVED
end

--- Check if event is rejected
-- @return boolean
function AsyncEvent:is_rejected()
    return self.state == AsyncEvent.STATE.REJECTED
end

--- Check if event is settled (resolved or rejected)
-- @return boolean
function AsyncEvent:is_settled()
    return self.state ~= AsyncEvent.STATE.PENDING
end

--- Get the current state
-- @return string State constant
function AsyncEvent:get_state()
    return self.state
end

--- Get the result (only valid if resolved)
-- @return any Result or nil
function AsyncEvent:get_result()
    return self.result
end

--- Get the error (only valid if rejected)
-- @return any Error or nil
function AsyncEvent:get_error()
    return self.error
end

-- ============================================================================
-- Static Utility Methods
-- ============================================================================

--- Run an async function (wraps in coroutine)
-- @param fn function The async function to run
-- @return any Result of the function or nil on error
function AsyncEvent.run(fn)
    local co = coroutine.create(fn)
    local success, result = coroutine.resume(co)

    if not success then
        error(result)
    end

    return result
end

--- Wait for all events to resolve
-- @param events table Array of AsyncEvent instances
-- @return AsyncEvent A new event that resolves with array of results
function AsyncEvent.all(events)
    local all_event = AsyncEvent.new("all")

    if #events == 0 then
        all_event:resolve({})
        return all_event
    end

    local results = {}
    local pending = #events
    local has_rejected = false

    for i, event in ipairs(events) do
        event:then_do(function(result)
            if has_rejected then return end

            results[i] = result
            pending = pending - 1

            if pending == 0 then
                all_event:resolve(results)
            end
        end):catch(function(err)
            if has_rejected then return end

            has_rejected = true
            all_event:reject(err)
        end)
    end

    return all_event
end

--- Wait for first event to settle
-- @param events table Array of AsyncEvent instances
-- @return AsyncEvent A new event that settles with first result
function AsyncEvent.race(events)
    local race_event = AsyncEvent.new("race")

    if #events == 0 then
        -- Never settles for empty array (matches Promise.race behavior)
        return race_event
    end

    local has_settled = false

    for _, event in ipairs(events) do
        event:then_do(function(result)
            if has_settled then return end
            has_settled = true
            race_event:resolve(result)
        end):catch(function(err)
            if has_settled then return end
            has_settled = true
            race_event:reject(err)
        end)
    end

    return race_event
end

--- Wait for all events to settle (never rejects)
-- @param events table Array of AsyncEvent instances
-- @return AsyncEvent A new event that resolves with array of {status, value/reason}
function AsyncEvent.all_settled(events)
    local settled_event = AsyncEvent.new("all_settled")

    if #events == 0 then
        settled_event:resolve({})
        return settled_event
    end

    local results = {}
    local pending = #events

    for i, event in ipairs(events) do
        event:then_do(function(result)
            results[i] = { status = "fulfilled", value = result }
            pending = pending - 1
            if pending == 0 then
                settled_event:resolve(results)
            end
        end):catch(function(err)
            results[i] = { status = "rejected", reason = err }
            pending = pending - 1
            if pending == 0 then
                settled_event:resolve(results)
            end
        end)
    end

    return settled_event
end

--- Create a resolved AsyncEvent
-- @param value any The resolved value
-- @return AsyncEvent Already resolved event
function AsyncEvent.resolved(value)
    local event = AsyncEvent.new("resolved")
    event:resolve(value)
    return event
end

--- Create a rejected AsyncEvent
-- @param err any The rejection error
-- @return AsyncEvent Already rejected event
function AsyncEvent.rejected(err)
    local event = AsyncEvent.new("rejected")
    event:reject(err)
    return event
end

--- Create an AsyncEvent that resolves after a delay
-- Note: This requires a timer handler to be provided
-- @param ms number Delay in milliseconds
-- @param timer_fn function Timer function(callback, delay)
-- @return AsyncEvent Event that resolves after delay
function AsyncEvent.delay(ms, timer_fn)
    local event = AsyncEvent.new("delay")

    if timer_fn then
        timer_fn(function()
            event:resolve(true)
        end, ms)
    else
        -- Without a timer, resolve immediately (for testing)
        event:resolve(true)
    end

    return event
end

return AsyncEvent
